source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/05b_auditoria_anac_extremos.txt", {

  required_packages <- c(
    "flightsbr",
    "dplyr",
    "readr",
    "tibble",
    "lubridate",
    "countrycode",
    "stringi",
    "stringr"
  )

  missing_packages <- required_packages[
    !vapply(
      required_packages,
      requireNamespace,
      logical(1),
      quietly = TRUE
    )
  ]

  if (length(missing_packages) > 0L) {
    stop(
      "Pacotes ausentes: ",
      paste(missing_packages, collapse = ", ")
    )
  }

  normalize_country <- function(x) {
    x |>
      as.character() |>
      stringi::stri_trans_general("Latin-ASCII") |>
      stringr::str_to_upper() |>
      stringr::str_squish()
  }

  prepare_test_month <- function(reference_month) {

    cat(
      "\nBaixando e processando:",
      reference_month,
      "\n"
    )

    raw <- flightsbr::read_flights(
      date = reference_month,
      type = "basica",
      showProgress = TRUE,
      cache = TRUE
    ) |>
      tibble::as_tibble()

    required_columns <- c(
      "dt_partida_real",
      "nm_pais_origem",
      "nm_pais_destino",
      "nr_assentos_ofertados",
      "nr_passag_pagos",
      "nr_decolagem"
    )

    missing_columns <- setdiff(
      required_columns,
      names(raw)
    )

    if (length(missing_columns) > 0L) {
      stop(
        "Colunas ausentes em ",
        reference_month,
        ": ",
        paste(missing_columns, collapse = ", ")
      )
    }

    result <- raw |>
      dplyr::mutate(
        country_origin_clean =
          normalize_country(.data$nm_pais_origem),

        country_destination_clean =
          normalize_country(.data$nm_pais_destino),

        inbound = (
          .data$country_origin_clean != "BRASIL" &
            .data$country_destination_clean == "BRASIL"
        ),

        outbound = (
          .data$country_origin_clean == "BRASIL" &
            .data$country_destination_clean != "BRASIL"
        )
      ) |>
      dplyr::filter(.data$inbound | .data$outbound) |>
      dplyr::mutate(
        direction = dplyr::if_else(
          .data$inbound,
          "inbound",
          "outbound"
        ),

        foreign_country = dplyr::if_else(
          .data$inbound,
          .data$nm_pais_origem,
          .data$nm_pais_destino
        ),

        origin_iso3 = countrycode::countryname(
          .data$foreign_country,
          destination = "iso3c",
          warn = FALSE
        ),

        date = lubridate::floor_date(
          as.Date(.data$dt_partida_real),
          unit = "month"
        ),

        seats = suppressWarnings(
          as.numeric(.data$nr_assentos_ofertados)
        ),

        passengers = suppressWarnings(
          as.numeric(.data$nr_passag_pagos)
        ),

        flights = suppressWarnings(
          as.numeric(.data$nr_decolagem)
        )
      ) |>
      dplyr::group_by(
        .data$origin_iso3,
        .data$foreign_country,
        .data$date,
        .data$direction
      ) |>
      dplyr::summarise(
        flights = sum(.data$flights, na.rm = TRUE),
        seats = sum(.data$seats, na.rm = TRUE),
        passengers = sum(.data$passengers, na.rm = TRUE),
        .groups = "drop"
      )

    cat("Linhas brutas:", nrow(raw), "\n")
    cat("Etapas internacionais agregadas:", nrow(result), "\n")
    cat(
      "Países estrangeiros:",
      dplyr::n_distinct(result$foreign_country),
      "\n"
    )
    cat(
      "Códigos ISO3 identificados:",
      dplyr::n_distinct(
        stats::na.omit(result$origin_iso3)
      ),
      "\n"
    )
    cat(
      "Países sem código ISO3:",
      sum(is.na(result$origin_iso3)),
      "\n"
    )

    result
  }

  anac_200001 <- prepare_test_month(200001)
  anac_202501 <- prepare_test_month(202501)

  combined <- dplyr::bind_rows(
    anac_200001,
    anac_202501
  )

  dir.create(
    "output/audit",
    recursive = TRUE,
    showWarnings = FALSE
  )

  readr::write_csv(
    combined,
    "output/audit/anac_extreme_months_by_country.csv"
  )

  cat("\nPAÍSES SEM CORRESPONDÊNCIA ISO3\n")

  unmatched <- combined |>
    dplyr::filter(is.na(.data$origin_iso3)) |>
    dplyr::distinct(.data$foreign_country) |>
    dplyr::arrange(.data$foreign_country)

  print(unmatched, n = Inf)

  cat("\nRESUMO POR MÊS E DIREÇÃO\n")

  monthly_summary <- combined |>
    dplyr::group_by(.data$date, .data$direction) |>
    dplyr::summarise(
      countries = dplyr::n_distinct(
        stats::na.omit(.data$origin_iso3)
      ),
      flights = sum(.data$flights, na.rm = TRUE),
      seats = sum(.data$seats, na.rm = TRUE),
      passengers = sum(
        .data$passengers,
        na.rm = TRUE
      ),
      .groups = "drop"
    )

  print(monthly_summary, n = Inf)

  cat("\nPRINCIPAIS MERCADOS DE ENTRADA\n")

  top_inbound <- combined |>
    dplyr::filter(.data$direction == "inbound") |>
    dplyr::arrange(
      .data$date,
      dplyr::desc(.data$seats)
    ) |>
    dplyr::group_by(.data$date) |>
    dplyr::slice_head(n = 15) |>
    dplyr::ungroup()

  print(top_inbound, n = Inf)

  cat("\nAUDITORIA DOS MESES EXTREMOS CONCLUÍDA\n")
})
