source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/06_integracao_anac_painel.txt", {
  if (!requireNamespace("targets", quietly = TRUE) ||
      !requireNamespace("tidyselect", quietly = TRUE)) {
    stop("Pacotes targets/tidyselect ausentes. Execute source('renv_bootstrap.R').")
  }

  cfg <- yaml::read_yaml("config.yml")
  if (!isTRUE(cfg$data_options$use_connectivity)) {
    stop("Altere use_connectivity para true em config.yml antes desta etapa.")
  }

  anac_path <- "data/raw/anac/anac_connectivity_monthly.csv"
  if (!file.exists(anac_path) || file.info(anac_path)$size <= 100L) {
    stop("A base ANAC consolidada não foi encontrada.")
  }

  cat("Construindo o alvo panels com conectividade ANAC ativada...\n")
  cat("Os alvos válidos serão reaproveitados pelo targets.\n\n")
  targets::tar_make(names = tidyselect::any_of("panels"))

  panel_objects <- targets::tar_read_raw(name = "panels")
  connectivity <- targets::tar_read_raw(name = "connectivity")
  total <- panel_objects$total
  access <- panel_objects$access

  required_panel <- c(
    "direct", "flights", "seats", "inbound_ask", "inbound_rpk",
    "outbound_flights", "outbound_seats", "direct_l1",
    "log_seats_l1", "log_flights_l1", "log_inbound_ask_l1",
    "log_seats_ma3_l1", "log_flights_ma3_l1"
  )
  missing_panel <- setdiff(required_panel, names(total))
  if (length(missing_panel) > 0L) {
    stop("Variáveis de conectividade ausentes no painel: ", paste(missing_panel, collapse = ", "))
  }

  duplicate_total <- total |>
    dplyr::count(.data$origin_iso3, .data$date) |>
    dplyr::filter(.data$n > 1L)
  invalid_total <- total |>
    dplyr::filter(
      !.data$direct %in% c(0L, 1L) |
        .data$flights < 0 | .data$seats < 0 |
        .data$inbound_ask < 0 | .data$inbound_rpk < 0
    )

  air <- access |>
    dplyr::filter(.data$access_mode == "air")
  air_summary <- air |>
    dplyr::summarise(
      air_arrivals = sum(.data$arrivals, na.rm = TRUE),
      direct_air_arrivals = sum(.data$arrivals[.data$direct == 1L], na.rm = TRUE),
      direct_arrival_share = .data$direct_air_arrivals / .data$air_arrivals,
      air_market_months = dplyr::n(),
      direct_market_months = sum(.data$direct == 1L),
      origins = dplyr::n_distinct(.data$origin_iso3),
      origins_ever_direct = dplyr::n_distinct(.data$origin_iso3[.data$direct == 1L])
    )

  anac_without_mtur <- connectivity |>
    dplyr::distinct(.data$origin_iso3) |>
    dplyr::anti_join(
      total |> dplyr::distinct(.data$origin_iso3),
      by = "origin_iso3"
    )
  mtur_never_direct <- total |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      total_arrivals = sum(.data$arrivals, na.rm = TRUE),
      months = dplyr::n(),
      ever_direct = any(.data$direct == 1L),
      .groups = "drop"
    ) |>
    dplyr::filter(!.data$ever_direct) |>
    dplyr::arrange(dplyr::desc(.data$total_arrivals))

  summary_table <- tibble::tibble(
    indicator = c(
      "panel_total_rows", "panel_access_rows", "anac_rows", "anac_origins",
      "anac_months", "connected_panel_origins", "direct_air_arrival_share",
      "duplicate_total_keys", "invalid_total_rows"
    ),
    value = c(
      nrow(total), nrow(access), nrow(connectivity),
      dplyr::n_distinct(connectivity$origin_iso3),
      dplyr::n_distinct(connectivity$date),
      air_summary$origins_ever_direct,
      air_summary$direct_arrival_share,
      nrow(duplicate_total), nrow(invalid_total)
    )
  )

  audit_dir <- "output/audit"
  dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(summary_table, file.path(audit_dir, "connectivity_panel_integration_summary.csv"))
  readr::write_csv(anac_without_mtur, file.path(audit_dir, "anac_origins_without_mtur.csv"))
  readr::write_csv(mtur_never_direct, file.path(audit_dir, "mtur_origins_never_direct.csv"))

  cat("RESUMO DA INTEGRAÇÃO ANAC–MTUR\n")
  print(summary_table, n = Inf, width = Inf)
  cat("\nCOBERTURA DAS CHEGADAS AÉREAS\n")
  print(air_summary, n = Inf, width = Inf)
  cat("\nOrigens ANAC sem correspondência no MTur:", nrow(anac_without_mtur), "\n")
  cat("Origens MTur sem ligação direta observada:", nrow(mtur_never_direct), "\n")

  problems <- c(
    dplyr::n_distinct(connectivity$date) != 312L,
    nrow(duplicate_total) > 0L,
    nrow(invalid_total) > 0L,
    !is.finite(air_summary$direct_arrival_share),
    air_summary$direct_arrival_share < 0,
    air_summary$direct_arrival_share > 1
  )
  if (any(problems)) {
    stop("A integração ANAC–MTur encontrou problemas. Consulte output/audit.")
  }

  cat("\nINTEGRAÇÃO ANAC–MTUR APROVADA\n")
})
