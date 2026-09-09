anac_source_url <- paste0(
  "https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/",
  "areas-de-atuacao/voos-e-operacoes-aereas/",
  "dados-estatisticos-do-transporte-aereo"
)

anac_country_to_iso3 <- function(x) {
  overrides <- c(
    "antigua e barbuda" = "ATG",
    "argelia" = "DZA",
    "azerbaijao" = "AZE",
    "bahrein" = "BHR",
    "benim" = "BEN",
    "camaroes" = "CMR",
    "costa do marfim" = "CIV",
    "emirados arabes unidos" = "ARE",
    "eritreia" = "ERI",
    "etiopia" = "ETH",
    "gabao" = "GAB",
    "gambia" = "GMB",
    "guadalupe" = "GLP",
    "guiana francesa" = "GUF",
    "guine" = "GIN",
    "guine equatorial" = "GNQ",
    "ilha de sao martinho" = "SXM",
    "ilhas canarias" = "ESP",
    "ilhas feroe" = "FRO",
    "islandia" = "ISL",
    "liberia" = "LBR",
    "libia" = "LBY",
    "martinica" = "MTQ",
    "mauricia" = "MUS",
    "mauritania" = "MRT",
    "namibia" = "NAM",
    "niger" = "NER",
    "serra leoa" = "SLE",
    "singapura" = "SGP",
    "sudao" = "SDN",
    "zimbabue" = "ZWE"
  )

  cleaned <- normalize_text(x)
  override_match <- unname(overrides[cleaned])
  general_match <- portuguese_country_to_iso3(x)
  dplyr::coalesce(override_match, general_match)
}

anac_reference_date <- function(reference_month) {
  reference_month <- as.integer(reference_month)
  reference_year <- reference_month %/% 100L
  reference_month_number <- reference_month %% 100L
  as.Date(sprintf("%04d-%02d-01", reference_year, reference_month_number))
}

anac_numeric <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

empty_anac_connectivity_month <- function() {
  tibble::tibble(
    origin_iso3 = character(),
    date = as.Date(character()),
    direct = integer(),
    flights = double(),
    seats = double(),
    passengers = double(),
    inbound_flights = double(),
    inbound_seats = double(),
    inbound_passengers = double(),
    inbound_ask = double(),
    inbound_rpk = double(),
    outbound_flights = double(),
    outbound_seats = double(),
    outbound_passengers = double(),
    outbound_ask = double(),
    outbound_rpk = double(),
    country_labels = character(),
    source_url = character(),
    notes = character()
  )
}

anac_sum_or_na <- function(x) {
  if (length(x) == 0L || all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE)
}

process_anac_month <- function(reference_month) {
  reference_month <- as.integer(reference_month)
  reference_date <- anac_reference_date(reference_month)

  raw <- flightsbr::read_flights(
    date = reference_month,
    type = "basica",
    showProgress = FALSE,
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

  if (!"nr_ask" %in% names(raw)) raw$nr_ask <- NA_real_
  if (!"nr_rpk" %in% names(raw)) raw$nr_rpk <- NA_real_

  international <- raw |>
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
    is.na(international$date) | international$date != reference_date
  )

  selected <- international |>
    dplyr::filter(!is.na(.data$date), .data$date == reference_date) |>
    dplyr::mutate(
      direction = dplyr::if_else(.data$inbound, "inbound", "outbound"),
      foreign_country = dplyr::if_else(
        .data$inbound, .data$nm_pais_origem, .data$nm_pais_destino
      ),
      foreign_country_clean = normalize_text(.data$foreign_country),
      origin_iso3 = anac_country_to_iso3(.data$foreign_country),
      flights_value = anac_numeric(.data$nr_decolagem),
      seats_value = anac_numeric(.data$nr_assentos_ofertados),
      passengers_value = anac_numeric(.data$nr_passag_pagos),
      ask_value = anac_numeric(.data$nr_ask),
      rpk_value = anac_numeric(.data$nr_rpk)
    )

  excluded <- selected |>
    dplyr::filter(.data$foreign_country_clean == "nao identificado") |>
    dplyr::group_by(.data$foreign_country, .data$direction) |>
    dplyr::summarise(
      reference_month = reference_month,
      rows = dplyr::n(),
      flights = anac_sum_or_na(.data$flights_value),
      seats = anac_sum_or_na(.data$seats_value),
      passengers = anac_sum_or_na(.data$passengers_value),
      .groups = "drop"
    )

  selected <- selected |>
    dplyr::filter(
      is.na(.data$foreign_country_clean) |
        .data$foreign_country_clean != "nao identificado"
    )

  unmatched <- selected |>
    dplyr::filter(is.na(.data$origin_iso3)) |>
    dplyr::group_by(.data$foreign_country, .data$direction) |>
    dplyr::summarise(
      rows = dplyr::n(),
      seats = anac_sum_or_na(.data$seats_value),
      passengers = anac_sum_or_na(.data$passengers_value),
      .groups = "drop"
    )

  if (nrow(unmatched) > 0L) {
    return(list(
      data = NULL,
      unmatched = unmatched,
      excluded = excluded,
      statistics = tibble::tibble(
        reference_month = reference_month,
        raw_rows = nrow(raw),
        international_rows = nrow(international),
        off_month_rows = off_month_rows,
        selected_rows = nrow(selected),
        excluded_rows = sum(excluded$rows, na.rm = TRUE),
        countries = dplyr::n_distinct(stats::na.omit(selected$origin_iso3))
      )
    ))
  }

  if (nrow(selected) == 0L) {
    stop("Nenhuma etapa internacional válida em ", reference_month, ".")
  }

  directional <- selected |>
    dplyr::group_by(.data$origin_iso3, .data$date, .data$direction) |>
    dplyr::summarise(
      flights = anac_sum_or_na(.data$flights_value),
      seats = anac_sum_or_na(.data$seats_value),
      passengers = anac_sum_or_na(.data$passengers_value),
      ask = anac_sum_or_na(.data$ask_value),
      rpk = anac_sum_or_na(.data$rpk_value),
      country_labels = paste(
        sort(unique(stats::na.omit(.data$foreign_country))),
        collapse = " | "
      ),
      .groups = "drop"
    )

  inbound <- directional |>
    dplyr::filter(.data$direction == "inbound") |>
    dplyr::transmute(
      origin_iso3, date,
      inbound_flights = flights,
      inbound_seats = seats,
      inbound_passengers = passengers,
      inbound_ask = ask,
      inbound_rpk = rpk,
      inbound_labels = country_labels
    )

  outbound <- directional |>
    dplyr::filter(.data$direction == "outbound") |>
    dplyr::transmute(
      origin_iso3, date,
      outbound_flights = flights,
      outbound_seats = seats,
      outbound_passengers = passengers,
      outbound_ask = ask,
      outbound_rpk = rpk,
      outbound_labels = country_labels
    )

  result <- dplyr::full_join(
    inbound, outbound, by = c("origin_iso3", "date")
  ) |>
    dplyr::mutate(
      direct = as.integer(
        dplyr::coalesce(.data$inbound_flights, 0) > 0 |
          dplyr::coalesce(.data$outbound_flights, 0) > 0
      ),
      flights = dplyr::coalesce(.data$inbound_flights, 0),
      seats = dplyr::coalesce(.data$inbound_seats, 0),
      passengers = dplyr::coalesce(.data$inbound_passengers, 0),
      country_labels = dplyr::case_when(
        !is.na(.data$inbound_labels) & !is.na(.data$outbound_labels) ~
          paste(.data$inbound_labels, .data$outbound_labels, sep = " | "),
        !is.na(.data$inbound_labels) ~ .data$inbound_labels,
        TRUE ~ .data$outbound_labels
      ),
      source_url = anac_source_url,
      notes = paste0(
        "ANAC basic flight-stage microdata; reference month ", reference_month,
        "; main flights/seats/passengers variables use inbound stages."
      )
    ) |>
    dplyr::select(
      origin_iso3, date, direct, flights, seats, passengers,
      inbound_flights, inbound_seats, inbound_passengers,
      inbound_ask, inbound_rpk,
      outbound_flights, outbound_seats, outbound_passengers,
      outbound_ask, outbound_rpk,
      country_labels, source_url, notes
    ) |>
    dplyr::arrange(.data$origin_iso3)

  assert_unique_key(result, c("origin_iso3", "date"), "ANAC monthly chunk")
  assert_nonnegative(result$flights, "ANAC inbound flights")
  assert_nonnegative(result$seats, "ANAC inbound seats")
  assert_nonnegative(result$passengers, "ANAC inbound passengers")

  list(
    data = result,
    unmatched = unmatched,
    excluded = excluded,
    statistics = tibble::tibble(
      reference_month = reference_month,
      raw_rows = nrow(raw),
      international_rows = nrow(international),
      off_month_rows = off_month_rows,
      selected_rows = nrow(selected),
      excluded_rows = sum(excluded$rows, na.rm = TRUE),
      countries = dplyr::n_distinct(result$origin_iso3)
    )
  )
}

anac_chunk_is_valid <- function(path, reference_month) {
  if (!file.exists(path) || file.info(path)$size <= 100L) return(FALSE)

  attempt <- try(
    readr::read_csv(path, show_col_types = FALSE, progress = FALSE),
    silent = TRUE
  )
  if (inherits(attempt, "try-error") || nrow(attempt) == 0L) return(FALSE)

  required <- names(empty_anac_connectivity_month())
  if (length(setdiff(required, names(attempt))) > 0L) return(FALSE)

  expected_date <- anac_reference_date(reference_month)
  dates <- as.Date(attempt$date)
  if (any(is.na(dates)) || any(dates != expected_date)) return(FALSE)
  if (anyDuplicated(attempt[c("origin_iso3", "date")]) > 0L) return(FALSE)

  TRUE
}

write_csv_atomically <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary_path <- paste0(path, ".temporary")
  readr::write_csv(data, temporary_path, na = "")

  copied <- file.copy(temporary_path, path, overwrite = TRUE)
  unlink(temporary_path)

  if (!isTRUE(copied)) stop("Não foi possível gravar: ", path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
