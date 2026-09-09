source("scripts/_helpers.R")
assert_project_root()

source("R/00_setup.R")
source("R/02_clean_mtur.R")
source("R/anac_download_helpers.R")

run_with_log("logs/05d_download_anac_completo.txt", {

  if (!requireNamespace("flightsbr", quietly = TRUE)) {
    stop("O pacote flightsbr não está instalado.")
  }

  start_date <- as.Date("2000-01-01")
  end_date <- as.Date("2025-12-01")
  expected_dates <- seq(start_date, end_date, by = "month")
  reference_months <- as.integer(format(expected_dates, "%Y%m"))

  chunk_dir <- "data/interim/anac_monthly_chunks"
  unmatched_dir <- "output/audit/anac_unmatched_months"
  excluded_dir <- "output/audit/anac_excluded_unknown_months"
  audit_dir <- "output/audit"

  dir.create(chunk_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(unmatched_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(excluded_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

  cat("MESES ESPERADOS:", length(reference_months), "\n")
  cat("PERÍODO:", format(start_date), "a", format(end_date), "\n")
  cat("Os checkpoints válidos serão reutilizados.\n\n")

  status_rows <- vector("list", length(reference_months))
  statistics_rows <- vector("list", length(reference_months))

  for (index in seq_along(reference_months)) {
    reference_month <- reference_months[[index]]
    chunk_path <- file.path(
      chunk_dir, sprintf("anac_%06d.csv", reference_month)
    )
    unmatched_path <- file.path(
      unmatched_dir, sprintf("anac_unmatched_%06d.csv", reference_month)
    )
    excluded_path <- file.path(
      excluded_dir, sprintf("anac_excluded_%06d.csv", reference_month)
    )

    cat(
      sprintf(
        "[%03d/%03d] %06d: ",
        index, length(reference_months), reference_month
      )
    )

    if (anac_chunk_is_valid(chunk_path, reference_month)) {
      cat("checkpoint já validado.\n")
      status_rows[[index]] <- tibble::tibble(
        reference_month = reference_month,
        status = "checkpoint",
        message = ""
      )
      next
    }

    completed <- FALSE
    last_message <- ""

    for (attempt_number in 1:3) {
      cat("tentativa", attempt_number, "... ")

      attempt <- try(
        process_anac_month(reference_month),
        silent = TRUE
      )

      if (inherits(attempt, "try-error")) {
        last_message <- as.character(attempt)
        cat("falhou.\n")
        if (attempt_number < 3L) Sys.sleep(3 * attempt_number)
        next
      }

      statistics_rows[[index]] <- attempt$statistics

      if (nrow(attempt$excluded) > 0L) {
        write_csv_atomically(attempt$excluded, excluded_path)
      } else if (file.exists(excluded_path)) {
        unlink(excluded_path)
      }

      if (nrow(attempt$unmatched) > 0L) {
        readr::write_csv(attempt$unmatched, unmatched_path)
        last_message <- paste0(
          "Países sem ISO3: ",
          paste(unique(attempt$unmatched$foreign_country), collapse = " | ")
        )
        cat("país sem ISO3.\n")
        break
      }

      write_csv_atomically(attempt$data, chunk_path)
      if (!anac_chunk_is_valid(chunk_path, reference_month)) {
        last_message <- "O checkpoint gravado não passou na validação."
        cat("checkpoint inválido.\n")
        next
      }

      if (file.exists(unmatched_path)) unlink(unmatched_path)
      completed <- TRUE
      cat(
        "concluído; ", nrow(attempt$data),
        " mercados conectados.\n", sep = ""
      )
      break
    }

    status_rows[[index]] <- tibble::tibble(
      reference_month = reference_month,
      status = if (completed) "completed" else "failed",
      message = if (completed) "" else last_message
    )
  }

  status_table <- dplyr::bind_rows(status_rows)
  statistics_table <- dplyr::bind_rows(statistics_rows)

  readr::write_csv(
    status_table,
    file.path(audit_dir, "anac_download_status.csv")
  )
  readr::write_csv(
    statistics_table,
    file.path(audit_dir, "anac_download_statistics.csv")
  )

  valid_chunks <- vapply(
    seq_along(reference_months),
    function(index) {
      anac_chunk_is_valid(
        file.path(
          chunk_dir,
          sprintf("anac_%06d.csv", reference_months[[index]])
        ),
        reference_months[[index]]
      )
    },
    logical(1)
  )

  missing_months <- reference_months[!valid_chunks]

  cat("\nRESUMO DOS CHECKPOINTS\n")
  cat("Meses válidos:", sum(valid_chunks), "de", length(valid_chunks), "\n")

  if (length(missing_months) > 0L) {
    cat("Meses pendentes:", paste(missing_months, collapse = ", "), "\n")
    stop(
      "O download ainda não está completo. Execute novamente o mesmo script. ",
      "Os checkpoints concluídos serão preservados. Consulte ",
      "output/audit/anac_download_status.csv."
    )
  }

  chunk_paths <- file.path(
    chunk_dir,
    sprintf("anac_%06d.csv", reference_months)
  )

  final_data <- purrr::map_dfr(
    chunk_paths,
    ~readr::read_csv(.x, show_col_types = FALSE, progress = FALSE)
  ) |>
    dplyr::mutate(date = as.Date(.data$date)) |>
    dplyr::arrange(.data$date, .data$origin_iso3)

  assert_unique_key(
    final_data, c("origin_iso3", "date"),
    "ANAC complete connectivity data"
  )
  assert_nonnegative(final_data$flights, "ANAC complete inbound flights")
  assert_nonnegative(final_data$seats, "ANAC complete inbound seats")
  assert_nonnegative(final_data$passengers, "ANAC complete inbound passengers")

  observed_dates <- sort(unique(final_data$date))
  if (!identical(observed_dates, expected_dates)) {
    stop("O arquivo consolidado não contém todos os 312 meses esperados.")
  }

  final_path <- "data/raw/anac/anac_connectivity_monthly.csv"
  write_csv_atomically(final_data, final_path)

  cat("\nDOWNLOAD E CONSOLIDAÇÃO ANAC CONCLUÍDOS\n")
  cat("Arquivo:", normalizePath(final_path, winslash = "/"), "\n")
  cat("Linhas país-mês:", nrow(final_data), "\n")
  cat("Países/territórios:", dplyr::n_distinct(final_data$origin_iso3), "\n")
  cat("Primeiro mês:", format(min(final_data$date)), "\n")
  cat("Último mês:", format(max(final_data$date)), "\n")
  cat("Meses:", dplyr::n_distinct(final_data$date), "\n")
})
