source("scripts/_helpers.R")
assert_project_root()

source("R/00_setup.R")

run_with_log(
  "logs/05f_diagnostico_paises_ambiguos.txt",
  {

    unmatched_files <- list.files(
      "output/audit/anac_unmatched_months",
      pattern = "^anac_unmatched_[0-9]{6}\\.csv$",
      full.names = TRUE
    )

    unmatched_detail <- purrr::map_dfr(
      unmatched_files,
      function(path) {
        readr::read_csv(
          path,
          show_col_types = FALSE
        ) |>
          dplyr::mutate(
            reference_month = as.integer(
              stringr::str_extract(
                basename(path),
                "[0-9]{6}"
              )
            )
          )
      }
    )

    unidentified_months <- unmatched_detail |>
      dplyr::filter(
        foreign_country == "NÃO IDENTIFICADO"
      ) |>
      dplyr::distinct(reference_month) |>
      dplyr::pull(reference_month)

    months_to_check <- sort(
      unique(
        c(
          200012L,
          201201L,
          unidentified_months
        )
      )
    )

    labels_to_check <- c(
      "ILHA DE SÃO MARTINHO",
      "NÃO IDENTIFICADO"
    )

    cat(
      "Meses que serão examinados:",
      paste(months_to_check, collapse = ", "),
      "\n\n"
    )

    diagnostic <- purrr::map_dfr(
      months_to_check,
      function(reference_month) {

        cat(
          "Lendo",
          reference_month,
          "...\n"
        )

        reference_date <- as.Date(
          sprintf(
            "%04d-%02d-01",
            reference_month %/% 100L,
            reference_month %% 100L
          )
        )

        raw <- flightsbr::read_flights(
          date = reference_month,
          type = "basica",
          showProgress = FALSE,
          cache = TRUE
        ) |>
          tibble::as_tibble()

        raw |>
          dplyr::mutate(
            date = lubridate::floor_date(
              as.Date(dt_partida_real),
              "month"
            ),
            selected_origin =
              nm_pais_origem %in% labels_to_check,
            selected_destination =
              nm_pais_destino %in% labels_to_check
          ) |>
          dplyr::filter(
            date == reference_date,
            selected_origin |
              selected_destination
          ) |>
          dplyr::transmute(
            reference_month = reference_month,

            foreign_country = dplyr::if_else(
              selected_origin,
              nm_pais_origem,
              nm_pais_destino
            ),

            direction = dplyr::if_else(
              selected_origin,
              "inbound",
              "outbound"
            ),

            foreign_iata = dplyr::if_else(
              selected_origin,
              sg_iata_origem,
              sg_iata_destino
            ),

            foreign_icao = dplyr::if_else(
              selected_origin,
              sg_icao_origem,
              sg_icao_destino
            ),

            foreign_airport = dplyr::if_else(
              selected_origin,
              nm_aerodromo_origem,
              nm_aerodromo_destino
            ),

            foreign_city = dplyr::if_else(
              selected_origin,
              nm_municipio_origem,
              nm_municipio_destino
            ),

            seats = suppressWarnings(
              as.numeric(nr_assentos_ofertados)
            ),

            passengers = suppressWarnings(
              as.numeric(nr_passag_pagos)
            )
          )
      }
    )

    airport_summary <- diagnostic |>
      dplyr::group_by(
        foreign_country,
        foreign_iata,
        foreign_icao,
        foreign_airport,
        foreign_city
      ) |>
      dplyr::summarise(
        months = dplyr::n_distinct(
          reference_month
        ),
        first_month = min(reference_month),
        last_month = max(reference_month),
        records = dplyr::n(),
        seats = sum(seats, na.rm = TRUE),
        passengers = sum(
          passengers,
          na.rm = TRUE
        ),
        .groups = "drop"
      ) |>
      dplyr::arrange(
        foreign_country,
        dplyr::desc(seats)
      )

    dir.create(
      "output/audit",
      recursive = TRUE,
      showWarnings = FALSE
    )

    readr::write_csv(
      airport_summary,
      "output/audit/anac_ambiguous_country_airports.csv"
    )

    print(
      airport_summary,
      n = Inf,
      width = Inf
    )

    cat(
      "\nDIAGNÓSTICO DOS PAÍSES AMBÍGUOS CONCLUÍDO\n"
    )
  }
)
