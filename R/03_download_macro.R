interpolate_positive_log <- function(x, year, maxgap) {
  x <- suppressWarnings(as.numeric(x))
  valid <- is.finite(x) & x > 0
  if (sum(valid) < 2L) return(x)

  logged <- ifelse(valid, log(x), NA_real_)
  interpolated <- zoo::na.approx(
    logged,
    x = year,
    na.rm = FALSE,
    maxgap = maxgap
  )
  ifelse(is.na(interpolated), NA_real_, exp(interpolated))
}

nearest_available_base_year <- function(x, year, preferred_year) {
  valid <- is.finite(x) & x > 0 & is.finite(year)
  if (!any(valid)) return(NA_integer_)
  available <- as.integer(year[valid])
  available[[which.min(abs(available - as.integer(preferred_year)))]]
}

rebase_index_nearest <- function(x, year, preferred_year) {
  base_year <- nearest_available_base_year(x, year, preferred_year)
  if (is.na(base_year)) return(rep(NA_real_, length(x)))
  base_values <- x[year == base_year & is.finite(x) & x > 0]
  if (length(base_values) == 0L) return(rep(NA_real_, length(x)))
  100 * x / mean(base_values)
}

download_macro_data <- function(origins, cfg) {
  indicators <- c(
    gdp_pc_real = "NY.GDP.PCAP.KD",
    gdp_pc_ppp = "NY.GDP.PCAP.PP.KD",
    population = "SP.POP.TOTL",
    cpi = "FP.CPI.TOTL",
    fx_official = "PA.NUS.FCRF",
    price_level_hh = "PA.NUS.PRVT.PLI"
  )
  gdp_price_indicator <- "PA.NUS.GDP.PLI"
  fx_alternative_indicator <- "PA.NUS.ATLS"

  first_year <- as.integer(cfg$project$start_year) - 1L
  last_year <- as.integer(cfg$project$end_year)
  auxiliary_countries <- c("FRA", "USA")
  requested_countries <- sort(unique(c(
    origins,
    cfg$project$main_destination_iso3,
    auxiliary_countries
  )))

  message("Downloading World Development Indicators and price-level data...")
  raw_download <- WDI::WDI(
    country = "all",
    indicator = unname(indicators),
    start = first_year,
    end = last_year,
    extra = TRUE,
    cache = NULL
  ) |>
    janitor::clean_names()

  message("Downloading GDP price-level data in a separate WDI request...")
  gdp_price_download <- WDI::WDI(
    country = "all",
    indicator = gdp_price_indicator,
    start = first_year,
    end = last_year,
    extra = FALSE,
    cache = NULL
  ) |>
    janitor::clean_names()

  gdp_price_column <- first_existing_column(
    gdp_price_download,
    c(normalize_text(gdp_price_indicator) |>
        stringr::str_replace_all("[^a-z0-9]+", "_")),
    required = TRUE
  )

  gdp_price_values <- gdp_price_download |>
    dplyr::transmute(
      iso3c = .data$iso3c,
      year = as.integer(.data$year),
      price_level_gdp_raw = .data[[gdp_price_column]]
    ) |>
    dplyr::distinct(.data$iso3c, .data$year, .keep_all = TRUE)

  message("Downloading Atlas exchange-rate data in a separate WDI request...")
  fx_alternative_download <- tryCatch(
    WDI::WDI(
      country = "all",
      indicator = fx_alternative_indicator,
      start = first_year,
      end = last_year,
      extra = FALSE,
      cache = NULL
    ) |>
      janitor::clean_names(),
    error = function(error) {
      warning(
        paste0(
          "The World Bank API did not return ",
          fx_alternative_indicator,
          ". The official exchange rate PA.NUS.FCRF will still be used. ",
          "Original message: ",
          conditionMessage(error)
        ),
        call. = FALSE
      )
      tibble::tibble()
    }
  )

  fx_alternative_column <- "pa_nus_atls"
  fx_alternative_required <- c(
    "iso3c",
    "year",
    fx_alternative_column
  )

  if (all(fx_alternative_required %in% names(fx_alternative_download))) {
    fx_alternative_values <- fx_alternative_download |>
      dplyr::transmute(
        iso3c = .data$iso3c,
        year = as.integer(.data$year),
        fx_alternative_raw = suppressWarnings(
          as.numeric(.data[[fx_alternative_column]])
        )
      ) |>
      dplyr::distinct(.data$iso3c, .data$year, .keep_all = TRUE)
  } else {
    warning(
      paste0(
        fx_alternative_indicator,
        " was not present in the isolated WDI response. ",
        "fx_alternative_raw will be set to NA and PA.NUS.FCRF will remain ",
        "the primary exchange-rate series."
      ),
      call. = FALSE
    )
    fx_alternative_values <- tibble::tibble(
      iso3c = character(),
      year = integer(),
      fx_alternative_raw = double()
    )
  }

  raw_download <- raw_download |>
    dplyr::left_join(gdp_price_values, by = c("iso3c", "year")) |>
    dplyr::left_join(fx_alternative_values, by = c("iso3c", "year"))

  indicator_columns <- purrr::map_chr(indicators, function(code) {
    first_existing_column(
      raw_download,
      c(normalize_text(code) |> stringr::str_replace_all("[^a-z0-9]+", "_")),
      required = TRUE
    )
  })

  metadata <- raw_download |>
    dplyr::filter(.data$iso3c %in% requested_countries) |>
    dplyr::select(
      iso3c,
      country,
      income_group = income,
      region
    ) |>
    dplyr::distinct(.data$iso3c, .keep_all = TRUE)

  values <- raw_download |>
    dplyr::filter(.data$iso3c %in% requested_countries) |>
    dplyr::transmute(
      iso3c = .data$iso3c,
      year = as.integer(.data$year),
      gdp_pc_real = .data[[indicator_columns[["gdp_pc_real"]]]],
      gdp_pc_ppp = .data[[indicator_columns[["gdp_pc_ppp"]]]],
      population = .data[[indicator_columns[["population"]]]],
      cpi_raw = .data[[indicator_columns[["cpi"]]]],
      fx_official_raw = .data[[indicator_columns[["fx_official"]]]],
      fx_alternative_raw = .data$fx_alternative_raw,
      price_level_hh_raw = .data[[indicator_columns[["price_level_hh"]]]],
      price_level_gdp_raw = .data$price_level_gdp_raw
    ) |>
    dplyr::distinct(.data$iso3c, .data$year, .keep_all = TRUE)

  raw <- tidyr::expand_grid(
    iso3c = requested_countries,
    year = seq.int(first_year, last_year)
  ) |>
    dplyr::left_join(metadata, by = "iso3c") |>
    dplyr::left_join(values, by = c("iso3c", "year")) |>
    dplyr::group_by(.data$iso3c) |>
    dplyr::arrange(.data$year, .by_group = TRUE) |>
    dplyr::mutate(
      cpi_filled = interpolate_positive_log(.data$cpi_raw, .data$year, maxgap = 3L),
      fx_official_filled = interpolate_positive_log(
        .data$fx_official_raw,
        .data$year,
        maxgap = 2L
      ),
      fx_alternative_filled = interpolate_positive_log(
        .data$fx_alternative_raw,
        .data$year,
        maxgap = 2L
      ),
      price_level_hh = interpolate_positive_log(
        .data$price_level_hh_raw,
        .data$year,
        maxgap = 2L
      ),
      price_level_gdp = interpolate_positive_log(
        .data$price_level_gdp_raw,
        .data$year,
        maxgap = 2L
      ),
      cpi_base_year = nearest_available_base_year(
        .data$cpi_filled,
        .data$year,
        cfg$project$base_cpi_year
      ),
      cpi = rebase_index_nearest(
        .data$cpi_filled,
        .data$year,
        cfg$project$base_cpi_year
      ),
      cpi_interpolated = as.integer(is.na(.data$cpi_raw) & !is.na(.data$cpi_filled)),
      fx_official_interpolated = as.integer(
        is.na(.data$fx_official_raw) & !is.na(.data$fx_official_filled)
      ),
      fx_alternative_interpolated = as.integer(
        is.na(.data$fx_alternative_raw) & !is.na(.data$fx_alternative_filled)
      ),
      price_level_hh_interpolated = as.integer(
        is.na(.data$price_level_hh_raw) & !is.na(.data$price_level_hh)
      ),
      price_level_gdp_interpolated = as.integer(
        is.na(.data$price_level_gdp_raw) & !is.na(.data$price_level_gdp)
      ),
      fx_lcu_per_usd = dplyr::coalesce(
        .data$fx_official_filled,
        .data$fx_alternative_filled
      ),
      fx_source = dplyr::case_when(
        !is.na(.data$fx_official_filled) ~ "official",
        !is.na(.data$fx_alternative_filled) ~ "dec_alternative",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::ungroup()

  price_proxies <- tibble::tribble(
    ~iso3c, ~proxy_iso3c,
    "GUF", "FRA",
    "PRI", "USA"
  )

  proxy_values <- raw |>
    dplyr::filter(.data$iso3c %in% price_proxies$proxy_iso3c) |>
    dplyr::transmute(
      proxy_iso3c = .data$iso3c,
      year = .data$year,
      proxy_cpi = .data$cpi,
      proxy_cpi_base_year = .data$cpi_base_year,
      proxy_fx = .data$fx_lcu_per_usd,
      proxy_fx_source = .data$fx_source,
      proxy_price_level_hh = .data$price_level_hh,
      proxy_price_level_gdp = .data$price_level_gdp
    )

  raw <- raw |>
    dplyr::left_join(price_proxies, by = "iso3c") |>
    dplyr::left_join(proxy_values, by = c("proxy_iso3c", "year")) |>
    dplyr::mutate(
      cpi_proxy_used = as.integer(
        is.na(.data$cpi) & !is.na(.data$proxy_cpi)
      ),
      fx_proxy_used = as.integer(
        is.na(.data$fx_lcu_per_usd) & !is.na(.data$proxy_fx)
      ),
      price_level_hh_proxy_used = as.integer(
        is.na(.data$price_level_hh) & !is.na(.data$proxy_price_level_hh)
      ),
      price_level_gdp_proxy_used = as.integer(
        is.na(.data$price_level_gdp) & !is.na(.data$proxy_price_level_gdp)
      ),
      cpi = dplyr::coalesce(.data$cpi, .data$proxy_cpi),
      cpi_base_year = dplyr::coalesce(.data$cpi_base_year, .data$proxy_cpi_base_year),
      fx_lcu_per_usd = dplyr::coalesce(.data$fx_lcu_per_usd, .data$proxy_fx),
      fx_source = dplyr::if_else(
        .data$fx_proxy_used == 1L,
        paste0("proxy_", .data$proxy_iso3c, "_", .data$proxy_fx_source),
        .data$fx_source,
        missing = .data$fx_source
      ),
      price_level_hh = dplyr::coalesce(
        .data$price_level_hh,
        .data$proxy_price_level_hh
      ),
      price_level_gdp = dplyr::coalesce(
        .data$price_level_gdp,
        .data$proxy_price_level_gdp
      ),
      price_proxy_iso3c = dplyr::if_else(
        .data$cpi_proxy_used == 1L |
          .data$fx_proxy_used == 1L |
          .data$price_level_hh_proxy_used == 1L |
          .data$price_level_gdp_proxy_used == 1L,
        .data$proxy_iso3c,
        NA_character_
      )
    ) |>
    dplyr::filter(.data$iso3c %in% unique(c(
      origins,
      cfg$project$main_destination_iso3
    ))) |>
    dplyr::select(
      iso3c,
      country,
      year,
      gdp_pc_real,
      gdp_pc_ppp,
      population,
      cpi,
      fx_lcu_per_usd,
      price_level_hh,
      price_level_gdp,
      income_group,
      region,
      cpi_base_year,
      fx_source,
      price_proxy_iso3c,
      cpi_interpolated,
      fx_official_interpolated,
      fx_alternative_interpolated,
      price_level_hh_interpolated,
      price_level_gdp_interpolated,
      cpi_proxy_used,
      fx_proxy_used,
      price_level_hh_proxy_used,
      price_level_gdp_proxy_used,
      cpi_raw,
      fx_official_raw,
      fx_alternative_raw,
      price_level_hh_raw,
      price_level_gdp_raw
    )

  if (nrow(raw) == 0L) stop("WDI returned no macroeconomic observations.")

  quality <- raw |>
    dplyr::group_by(.data$iso3c) |>
    dplyr::summarise(
      country = dplyr::first(
        stats::na.omit(.data$country),
        default = NA_character_
      ),
      rows = dplyr::n(),
      gdp_pc_available = sum(!is.na(.data$gdp_pc_real)),
      population_available = sum(!is.na(.data$population)),
      cpi_available = sum(!is.na(.data$cpi)),
      fx_available = sum(!is.na(.data$fx_lcu_per_usd)),
      price_level_hh_available = sum(!is.na(.data$price_level_hh)),
      price_level_gdp_available = sum(!is.na(.data$price_level_gdp)),
      cpi_interpolated_rows = sum(.data$cpi_interpolated, na.rm = TRUE),
      cpi_proxy_rows = sum(.data$cpi_proxy_used, na.rm = TRUE),
      fx_proxy_rows = sum(.data$fx_proxy_used, na.rm = TRUE),
      price_level_proxy_rows = sum(.data$price_level_hh_proxy_used, na.rm = TRUE),
      price_level_gdp_proxy_rows = sum(
        .data$price_level_gdp_proxy_used,
        na.rm = TRUE
      ),
      .groups = "drop"
    )

  write_csv_safe(
    quality,
    fs::path(cfg$paths$interim, "wdi_macro_quality.csv")
  )
  write_parquet_safe(raw, fs::path(cfg$paths$interim, "wdi_macro.parquet"))
  raw
}
