empty_anac_connectivity_table <- function() {
  tibble::tibble(
    origin_iso3 = character(), date = as.Date(character()), direct = integer(),
    flights = double(), seats = double(), passengers = double(),
    inbound_flights = double(), inbound_seats = double(),
    inbound_passengers = double(), inbound_ask = double(), inbound_rpk = double(),
    outbound_flights = double(), outbound_seats = double(),
    outbound_passengers = double(), outbound_ask = double(), outbound_rpk = double()
  )
}

prepare_connectivity <- function(cfg) {
  if (!isTRUE(cfg$data_options$use_connectivity)) {
    return(empty_anac_connectivity_table())
  }

  path <- fs::path(cfg$paths$anac_raw, "anac_connectivity_monthly.csv")
  if (!file.exists(path) || file.info(path)$size <= 100L) {
    stop("Connectivity is enabled, but the audited ANAC file does not exist: ", path)
  }

  raw <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE) |>
    janitor::clean_names()
  required <- c(
    "origin_iso3", "date", "direct", "flights", "seats", "passengers",
    "inbound_flights", "inbound_seats", "inbound_passengers",
    "inbound_ask", "inbound_rpk", "outbound_flights", "outbound_seats",
    "outbound_passengers", "outbound_ask", "outbound_rpk"
  )
  missing_columns <- setdiff(required, names(raw))
  if (length(missing_columns) > 0L) {
    stop("The consolidated ANAC file is missing columns: ", paste(missing_columns, collapse = ", "))
  }

  numeric_columns <- setdiff(required, c("origin_iso3", "date", "direct"))
  result <- raw |>
    dplyr::transmute(
      origin_iso3 = toupper(as.character(.data$origin_iso3)),
      date = lubridate::floor_date(as.Date(.data$date), unit = "month"),
      direct = as.integer(.data$direct),
      dplyr::across(dplyr::all_of(numeric_columns), ~suppressWarnings(as.numeric(.x)))
    ) |>
    dplyr::arrange(.data$date, .data$origin_iso3)

  assert_unique_key(result, c("origin_iso3", "date"), "audited ANAC connectivity")
  if (any(is.na(result$origin_iso3)) || any(is.na(result$date))) {
    stop("ANAC connectivity contains missing keys.")
  }
  if (any(!result$direct %in% c(0L, 1L))) {
    stop("ANAC direct indicator contains values other than zero and one.")
  }
  purrr::walk(numeric_columns, ~assert_nonnegative(result[[.x]], paste("ANAC", .x)))

  expected_dates <- seq(
    as.Date(sprintf("%04d-01-01", as.integer(cfg$project$start_year))),
    as.Date(sprintf("%04d-12-01", as.integer(cfg$project$end_year))),
    by = "month"
  )
  if (!identical(sort(unique(result$date)), expected_dates)) {
    stop("ANAC connectivity does not contain every expected project month.")
  }

  write_parquet_safe(result, fs::path(cfg$paths$interim, "connectivity_monthly.parquet"))
  result
}
