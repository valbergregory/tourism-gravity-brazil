source("scripts/_helpers.R")
assert_project_root()

source("R/00_setup.R")

run_with_log("logs/05e_auditoria_anac_completo.txt", {

  path <- "data/raw/anac/anac_connectivity_monthly.csv"
  if (!file.exists(path) || file.info(path)$size <= 100L) {
    stop(
      "A base ANAC consolidada ainda não existe. Execute primeiro ",
      "scripts/05d_baixar_anac_completo.R."
    )
  }

  anac <- readr::read_csv(
    path, show_col_types = FALSE, progress = FALSE
  ) |>
    dplyr::mutate(date = as.Date(.data$date))

  excluded_paths <- list.files(
    "output/audit/anac_excluded_unknown_months",
    pattern = "^anac_excluded_[0-9]{6}\\.csv$",
    full.names = TRUE
  )

  excluded_detail <- if (length(excluded_paths) > 0L) {
    purrr::map_dfr(
      excluded_paths,
      ~readr::read_csv(.x, show_col_types = FALSE, progress = FALSE)
    )
  } else {
    tibble::tibble(
      foreign_country = character(),
      direction = character(),
      reference_month = integer(),
      rows = integer(),
      flights = double(),
      seats = double(),
      passengers = double()
    )
  }

  excluded_summary <- excluded_detail |>
    dplyr::group_by(.data$foreign_country) |>
    dplyr::summarise(
      months = dplyr::n_distinct(.data$reference_month),
      first_month = min(.data$reference_month),
      last_month = max(.data$reference_month),
      records = sum(.data$rows, na.rm = TRUE),
      flights = sum(.data$flights, na.rm = TRUE),
      seats = sum(.data$seats, na.rm = TRUE),
      passengers = sum(.data$passengers, na.rm = TRUE),
      .groups = "drop"
    )

  required <- c(
    "origin_iso3", "date", "direct", "flights", "seats", "passengers",
    "inbound_flights", "inbound_seats", "inbound_passengers",
    "outbound_flights", "outbound_seats", "outbound_passengers"
  )
  missing_columns <- setdiff(required, names(anac))
  if (length(missing_columns) > 0L) {
    stop("Colunas ausentes: ", paste(missing_columns, collapse = ", "))
  }

  expected_dates <- seq(
    as.Date("2000-01-01"), as.Date("2025-12-01"), by = "month"
  )
  observed_dates <- sort(unique(stats::na.omit(anac$date)))
  missing_dates <- setdiff(expected_dates, observed_dates)
  extra_dates <- setdiff(observed_dates, expected_dates)

  duplicated_keys <- anac |>
    dplyr::count(.data$origin_iso3, .data$date, name = "rows") |>
    dplyr::filter(.data$rows > 1L)

  invalid_values <- anac |>
    dplyr::filter(
      is.na(.data$origin_iso3) |
        is.na(.data$date) |
        !.data$direct %in% c(0L, 1L) |
        .data$flights < 0 |
        .data$seats < 0 |
        .data$passengers < 0
    )

  monthly_balance <- anac |>
    dplyr::group_by(.data$date) |>
    dplyr::summarise(
      countries = dplyr::n_distinct(.data$origin_iso3),
      inbound_flights = sum(.data$inbound_flights, na.rm = TRUE),
      outbound_flights = sum(.data$outbound_flights, na.rm = TRUE),
      inbound_seats = sum(.data$inbound_seats, na.rm = TRUE),
      outbound_seats = sum(.data$outbound_seats, na.rm = TRUE),
      inbound_passengers = sum(.data$inbound_passengers, na.rm = TRUE),
      outbound_passengers = sum(.data$outbound_passengers, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      flight_balance_ratio = dplyr::if_else(
        .data$outbound_flights > 0,
        .data$inbound_flights / .data$outbound_flights,
        NA_real_
      ),
      seat_balance_ratio = dplyr::if_else(
        .data$outbound_seats > 0,
        .data$inbound_seats / .data$outbound_seats,
        NA_real_
      )
    )

  annual_summary <- monthly_balance |>
    dplyr::mutate(year = lubridate::year(.data$date)) |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(
      months = dplyr::n_distinct(.data$date),
      mean_connected_countries = mean(.data$countries),
      inbound_flights = sum(.data$inbound_flights),
      outbound_flights = sum(.data$outbound_flights),
      inbound_seats = sum(.data$inbound_seats),
      outbound_seats = sum(.data$outbound_seats),
      inbound_passengers = sum(.data$inbound_passengers),
      outbound_passengers = sum(.data$outbound_passengers),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      flight_balance_ratio = .data$inbound_flights / .data$outbound_flights,
      seat_balance_ratio = .data$inbound_seats / .data$outbound_seats
    )

  arrivals <- targets::tar_read_raw(name = "arrivals")
  air_arrivals <- arrivals |>
    dplyr::filter(.data$access_mode == "air") |>
    dplyr::left_join(
      anac |>
        dplyr::select(origin_iso3, date, direct, seats, flights),
      by = c("origin_iso3", "date")
    ) |>
    dplyr::mutate(
      direct = dplyr::coalesce(.data$direct, 0L),
      seats = dplyr::coalesce(.data$seats, 0),
      flights = dplyr::coalesce(.data$flights, 0)
    )

  arrival_coverage <- air_arrivals |>
    dplyr::summarise(
      air_arrivals = sum(.data$arrivals, na.rm = TRUE),
      arrivals_direct_market_months = sum(
        .data$arrivals[.data$direct == 1L], na.rm = TRUE
      ),
      direct_arrival_share =
        .data$arrivals_direct_market_months / .data$air_arrivals,
      market_months = dplyr::n(),
      direct_market_months = sum(.data$direct == 1L),
      origins = dplyr::n_distinct(.data$origin_iso3),
      origins_ever_direct = dplyr::n_distinct(
        .data$origin_iso3[.data$direct == 1L]
      )
    )

  audit_dir <- "output/audit"
  dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(
    monthly_balance,
    file.path(audit_dir, "anac_monthly_balance.csv")
  )
  readr::write_csv(
    annual_summary,
    file.path(audit_dir, "anac_annual_summary.csv")
  )
  readr::write_csv(
    arrival_coverage,
    file.path(audit_dir, "anac_mtur_air_arrival_coverage.csv")
  )
  readr::write_csv(
    excluded_summary,
    file.path(audit_dir, "anac_excluded_unknown_summary.csv")
  )

  cat("RESUMO DA BASE ANAC\n")
  cat("Linhas país-mês:", nrow(anac), "\n")
  cat("Países/territórios:", dplyr::n_distinct(anac$origin_iso3), "\n")
  cat("Primeiro mês:", format(min(anac$date, na.rm = TRUE)), "\n")
  cat("Último mês:", format(max(anac$date, na.rm = TRUE)), "\n")
  cat("Meses:", length(observed_dates), "\n")
  cat("Meses ausentes:", length(missing_dates), "\n")
  cat("Meses extras:", length(extra_dates), "\n")
  cat("Chaves duplicadas:", nrow(duplicated_keys), "\n")
  cat("Linhas inválidas:", nrow(invalid_values), "\n")

  cat("\nEXCLUSÕES SEM IDENTIFICAÇÃO GEOGRÁFICA\n")
  if (nrow(excluded_summary) > 0L) {
    print(excluded_summary, n = Inf, width = Inf)
  } else {
    cat("Nenhuma exclusão registrada.\n")
  }

  cat("\nCOBERTURA DOS FLUXOS AÉREOS DO MTUR\n")
  print(arrival_coverage, n = Inf, width = Inf)

  cat("\nRESUMO ANUAL ANAC\n")
  print(annual_summary, n = Inf, width = Inf)

  problems <- c(
    length(missing_dates) > 0L,
    length(extra_dates) > 0L,
    nrow(duplicated_keys) > 0L,
    nrow(invalid_values) > 0L,
    nrow(anac) == 0L
  )

  if (any(problems)) {
    stop("A auditoria ANAC encontrou problemas. Consulte output/audit.")
  }

  cat("\nAUDITORIA ANAC COMPLETA APROVADA\n")
})
