source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/02_auditoria_mtur.txt", {
  required <- c("targets", "dplyr", "readr", "tibble", "yaml", "lubridate")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) stop("Pacotes ausentes: ", paste(missing, collapse = ", "))

  arrivals_data <- targets::tar_read_raw(name = "arrivals")
  cfg <- yaml::read_yaml("config.yml")
  audit_dir <- "output/audit"
  dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

  expected_start <- as.Date(sprintf("%04d-01-01", as.integer(cfg$project$start_year)))
  expected_end <- as.Date(sprintf("%04d-12-01", as.integer(cfg$project$end_year)))
  actual_start <- min(arrivals_data$date, na.rm = TRUE)
  actual_end <- max(arrivals_data$date, na.rm = TRUE)

  duplicate_keys <- arrivals_data |>
    dplyr::count(.data$origin_iso3, .data$date, .data$access_mode, name = "n") |>
    dplyr::filter(.data$n > 1L)
  missing_keys <- arrivals_data |>
    dplyr::filter(is.na(.data$origin_iso3) | is.na(.data$date) | is.na(.data$access_mode))
  negative_rows <- arrivals_data |>
    dplyr::filter(is.na(.data$arrivals) | .data$arrivals < 0)

  modal_summary <- arrivals_data |>
    dplyr::group_by(.data$access_mode) |>
    dplyr::summarise(
      rows = dplyr::n(),
      arrivals = sum(.data$arrivals, na.rm = TRUE),
      zero_imputed = sum(.data$zero_imputed, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$access_mode)

  annual_summary <- arrivals_data |>
    dplyr::mutate(year = lubridate::year(.data$date)) |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(
      rows = dplyr::n(),
      origins = dplyr::n_distinct(.data$origin_iso3),
      arrivals = sum(.data$arrivals, na.rm = TRUE),
      zero_imputed = sum(.data$zero_imputed, na.rm = TRUE),
      .groups = "drop"
    )

  origin_summary <- arrivals_data |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      first_date = min(.data$date),
      last_date = max(.data$date),
      rows = dplyr::n(),
      arrivals = sum(.data$arrivals, na.rm = TRUE),
      zero_imputed = sum(.data$zero_imputed, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$origin_iso3)

  conflict_path <- "data/interim/mtur_source_conflicts.csv"
  unmatched_path <- "data/interim/unmatched_mtur_countries.csv"
  aggregates_path <- "data/interim/excluded_mtur_aggregate_rows.csv"
  conflicts <- read_csv_if_present(conflict_path)
  unmatched <- read_csv_if_present(unmatched_path)
  aggregates <- read_csv_if_present(aggregates_path)

  problems <- character()
  if (!identical(actual_start, expected_start)) {
    problems <- c(problems, paste("Data inicial esperada", expected_start, "mas encontrada", actual_start))
  }
  if (!identical(actual_end, expected_end)) {
    problems <- c(problems, paste("Data final esperada", expected_end, "mas encontrada", actual_end))
  }
  if (nrow(duplicate_keys) > 0L) problems <- c(problems, "Há chaves origem-data-modal duplicadas")
  if (nrow(missing_keys) > 0L) problems <- c(problems, "Há chaves ausentes")
  if (nrow(negative_rows) > 0L) problems <- c(problems, "Há chegadas ausentes ou negativas")
  if (!all(arrivals_data$zero_imputed %in% c(0L, 1L))) {
    problems <- c(problems, "zero_imputed contém valores diferentes de 0 e 1")
  }
  expected_modes <- c("air", "fluvial", "land", "maritime")
  missing_modes <- setdiff(expected_modes, unique(arrivals_data$access_mode))
  if (length(missing_modes) > 0L) {
    problems <- c(problems, paste("Modais ausentes:", paste(missing_modes, collapse = ", ")))
  }
  if (!is.null(conflicts) && nrow(conflicts) > 0L) {
    problems <- c(problems, "Há conflitos entre fontes MTur")
  }

  summary_table <- tibble::tibble(
    indicator = c(
      "rows", "origins", "first_date", "last_date", "modes",
      "observed_records", "zero_imputed", "unmatched_labels",
      "excluded_aggregate_labels", "source_conflicts", "problems"
    ),
    value = c(
      as.character(nrow(arrivals_data)),
      as.character(dplyr::n_distinct(arrivals_data$origin_iso3)),
      as.character(actual_start),
      as.character(actual_end),
      paste(sort(unique(arrivals_data$access_mode)), collapse = ", "),
      as.character(sum(arrivals_data$observed_record, na.rm = TRUE)),
      as.character(sum(arrivals_data$zero_imputed, na.rm = TRUE)),
      as.character(if (is.null(unmatched)) 0L else nrow(unmatched)),
      as.character(if (is.null(aggregates)) 0L else nrow(aggregates)),
      as.character(if (is.null(conflicts)) 0L else nrow(conflicts)),
      as.character(length(problems))
    )
  )

  readr::write_csv(summary_table, file.path(audit_dir, "mtur_audit_summary.csv"))
  readr::write_csv(modal_summary, file.path(audit_dir, "mtur_by_mode.csv"))
  readr::write_csv(annual_summary, file.path(audit_dir, "mtur_by_year.csv"))
  readr::write_csv(origin_summary, file.path(audit_dir, "mtur_by_origin.csv"))
  readr::write_csv(duplicate_keys, file.path(audit_dir, "mtur_duplicate_keys.csv"))

  print(summary_table, n = Inf)
  cat("\nPOR MODAL\n")
  print(modal_summary, n = Inf)

  if (length(problems) > 0L) {
    cat("\nPROBLEMAS ENCONTRADOS\n- ", paste(problems, collapse = "\n- "), "\n", sep = "")
    stop(
      "A auditoria MTur não foi aprovada. Consulte logs/02_auditoria_mtur.txt ",
      "e execute scripts/99_coletar_diagnostico.R."
    )
  }

  cat("\nAUDITORIA MTUR APROVADA: 2000-01 a 2025-12, chaves únicas e valores válidos.\n")
})
