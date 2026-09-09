source("scripts/_helpers.R")
assert_project_root()

source("R/00_setup.R")
source("R/02_clean_mtur.R")

run_with_log("logs/05c_validacao_anac_paises_datas.txt", {

  required_packages <- c(
    "flightsbr", "dplyr", "readr", "tibble", "lubridate",
    "countrycode", "stringi", "stringr"
  )

  missing_packages <- required_packages[
    !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(missing_packages) > 0L) {
    stop(
      "Pacotes ausentes: ", paste(missing_packages, collapse = ", "),
      ". Execute renv::install() para os pacotes ausentes."
    )
  }

  anac_country_to_iso3 <- function(x) {
    overrides <- c(
      "emirados arabes unidos" = "ARE",
      "etiopia" = "ETH",
      "guiana francesa" = "GUF",
      "ilhas canarias" = "ESP",
      "martinica" = "MTQ"
    )

    cleaned <- normalize_text(x)
    override_match <- unname(overrides[cleaned])
    general_match <- portuguese_country_to_iso3(x)

    dplyr::coalesce(override_match, general_match)
  }

  prepare_test_month <- function(reference_month) {
    reference_month <- as.integer(reference_month)
    reference_year <- reference_month %/% 100L
    reference_month_number <- reference_month %% 100L
    reference_date <- as.Date(sprintf(
      "%04d-%02d-01", reference_year, reference_month_number
    ))

    cat("\nBaixando e processando:", reference_month, "\n")

    raw <- flightsbr::read_flights(
      date = reference_month,
      type = "basica",
      showProgress = TRUE,
      cache = TRUE
    ) |>
      tibble::as_tibble()

    required_columns <- c(
      "dt_partida_real", "nm_pais_origem", "nm_pais_destino",
      "nr_assentos_ofertados", "nr_passag_pagos", "nr_decolagem"
    )

    missing_columns <- setdiff(required_columns, names(raw))
    if (length(missing_columns) > 0L) {
      stop(
        "Colunas ausentes em ", reference_month, ": ",
        paste(missing_columns, collapse = ", ")
      )
    }

    prepared <- raw |>
      dplyr::mutate(
        country_origin_clean = normalize_text(.data$nm_pais_origem),
        country_destination_clean = normalize_text(.data$nm_pais_destino),
        inbound = (
          .data$country_origin_clean != "brasil" &
            .data$country_destination_clean == "brasil"
        ),
        outbound = (
          .data$country_origin_clean == "brasil" &
            .data$country_destination_clean != "brasil"
        ),
        date = lubridate::floor_date(
          as.Date(.data$dt_partida_real), unit = "month"
        )
      ) |>
      dplyr::filter(.data$inbound | .data$outbound)

    off_month_rows <- sum(
      is.na(prepared$date) | prepared$date != reference_date
    )

    result <- prepared |>
      dplyr::filter(!is.na(.data$date), .data$date == reference_date) |>
      dplyr::mutate(
        direction = dplyr::if_else(.data$inbound, "inbound", "outbound"),
        foreign_country = dplyr::if_else(
          .data$inbound, .data$nm_pais_origem, .data$nm_pais_destino
        ),
        origin_iso3 = anac_country_to_iso3(.data$foreign_country),
        seats = suppressWarnings(as.numeric(.data$nr_assentos_ofertados)),
        passengers = suppressWarnings(as.numeric(.data$nr_passag_pagos)),
        flights = suppressWarnings(as.numeric(.data$nr_decolagem))
      ) |>
      dplyr::group_by(
        .data$origin_iso3, .data$foreign_country,
        .data$date, .data$direction
      ) |>
      dplyr::summarise(
        flights = if (all(is.na(.data$flights))) {
          NA_real_
        } else {
          sum(.data$flights, na.rm = TRUE)
        },
        seats = if (all(is.na(.data$seats))) {
          NA_real_
        } else {
          sum(.data$seats, na.rm = TRUE)
        },
        passengers = if (all(is.na(.data$passengers))) {
          NA_real_
        } else {
          sum(.data$passengers, na.rm = TRUE)
        },
        .groups = "drop"
      )

    cat("Linhas brutas:", nrow(raw), "\n")
    cat("Linhas internacionais antes do filtro mensal:", nrow(prepared), "\n")
    cat("Registros internacionais fora do mês ou sem data:", off_month_rows, "\n")
    cat("Linhas país-direção após agregação:", nrow(result), "\n")
    cat("Países estrangeiros:", dplyr::n_distinct(result$foreign_country), "\n")
    cat(
      "Códigos ISO3 identificados:",
      dplyr::n_distinct(stats::na.omit(result$origin_iso3)), "\n"
    )
    cat("Linhas agregadas sem código ISO3:", sum(is.na(result$origin_iso3)), "\n")

    result
  }

  anac_200001 <- prepare_test_month(200001)
  anac_202501 <- prepare_test_month(202501)
  combined <- dplyr::bind_rows(anac_200001, anac_202501)

  audit_dir <- "output/audit"
  dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

  readr::write_csv(
    combined,
    file.path(audit_dir, "anac_extreme_months_corrected.csv")
  )

  unmatched <- combined |>
    dplyr::filter(is.na(.data$origin_iso3)) |>
    dplyr::distinct(.data$foreign_country) |>
    dplyr::arrange(.data$foreign_country)

  readr::write_csv(
    unmatched,
    file.path(audit_dir, "anac_extreme_months_unmatched.csv")
  )

  cat("\nPAÍSES SEM CORRESPONDÊNCIA ISO3\n")
  print(unmatched, n = Inf)

  monthly_summary <- combined |>
    dplyr::group_by(.data$date, .data$direction) |>
    dplyr::summarise(
      countries = dplyr::n_distinct(stats::na.omit(.data$origin_iso3)),
      flights = sum(.data$flights, na.rm = TRUE),
      seats = sum(.data$seats, na.rm = TRUE),
      passengers = sum(.data$passengers, na.rm = TRUE),
      .groups = "drop"
    )

  cat("\nRESUMO CORRIGIDO POR MÊS E DIREÇÃO\n")
  print(monthly_summary, n = Inf)

  top_inbound <- combined |>
    dplyr::filter(.data$direction == "inbound") |>
    dplyr::arrange(.data$date, dplyr::desc(.data$seats)) |>
    dplyr::group_by(.data$date) |>
    dplyr::slice_head(n = 15L) |>
    dplyr::ungroup()

  cat("\nPRINCIPAIS MERCADOS DE ENTRADA\n")
  print(top_inbound, n = Inf)

  if (nrow(unmatched) > 0L) {
    stop(
      "A validação encontrou países sem ISO3. Consulte ",
      "output/audit/anac_extreme_months_unmatched.csv."
    )
  }

  if (any(is.na(combined$date))) {
    stop("Datas ausentes permaneceram após a correção.")
  }

  cat("\nVALIDAÇÃO ANAC CORRIGIDA E APROVADA\n")
})
