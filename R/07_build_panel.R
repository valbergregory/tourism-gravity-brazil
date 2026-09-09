build_analysis_panels <- function(arrivals, macro, geodist, connectivity, visa, cfg) {
  require_provenance <- c("origin_iso3", "date", "access_mode", "arrivals", "zero_imputed")
  missing_provenance <- setdiff(require_provenance, names(arrivals))
  if (length(missing_provenance) > 0L) {
    stop(
      "MTur arrivals are missing provenance columns: ",
      paste(missing_provenance, collapse = ", "),
      call. = FALSE
    )
  }
  invalid_provenance <- is.na(arrivals$zero_imputed) |
    !arrivals$zero_imputed %in% c(0L, 1L)
  if (any(invalid_provenance)) {
    stop(
      "zero_imputed must be coded 0/1 for every MTur row; invalid rows: ",
      sum(invalid_provenance),
      call. = FALSE
    )
  }

  # A completed country-mode grid may contain artificial zero rows outside the
  # source's actual reporting spell. Such rows are useful for preserving a
  # monthly calendar, but they are not observed zero tourism demand. Prefer
  # observed detailed-mode records over an aggregate `all` record; use `all`
  # only when no detailed-mode record was observed in the country-month.
  total_components <- arrivals |>
    dplyr::group_by(.data$origin_iso3, .data$date) |>
    dplyr::mutate(
      has_observed_detailed_mode = any(
        .data$access_mode != "all" & .data$zero_imputed == 0L
      ),
      has_observed_all = any(
        .data$access_mode == "all" & .data$zero_imputed == 0L
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::filter(
      (.data$has_observed_detailed_mode & .data$access_mode != "all") |
        (!.data$has_observed_detailed_mode & .data$has_observed_all &
          .data$access_mode == "all") |
        (!.data$has_observed_detailed_mode & !.data$has_observed_all)
    )

  total <- total_components |>
    dplyr::group_by(.data$origin_iso3, .data$date) |>
    dplyr::summarise(
      arrivals_sum = sum(.data$arrivals, na.rm = TRUE),
      observed_mode_rows = sum(.data$zero_imputed == 0L),
      imputed_mode_rows = sum(.data$zero_imputed == 1L),
      any_zero_imputed = as.integer(any(.data$zero_imputed == 1L)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      all_zero_imputed = as.integer(.data$observed_mode_rows == 0L),
      observation_status = dplyr::case_when(
        .data$all_zero_imputed == 1L ~ "unobserved_completed_cell",
        .data$imputed_mode_rows > 0L ~ "observed_with_completed_modes",
        TRUE ~ "fully_observed_cell"
      ),
      arrivals = dplyr::if_else(
        .data$all_zero_imputed == 1L,
        NA_real_, as.numeric(.data$arrivals_sum)
      )
    ) |>
    dplyr::select(-dplyr::all_of("arrivals_sum"))

  project_start <- as.Date(sprintf("%04d-01-01", as.integer(cfg$project$start_year)))
  project_end <- as.Date(sprintf("%04d-12-01", as.integer(cfg$project$end_year)))
  broad_min_months <- 12L * as.integer(cfg$project$min_origin_years)
  full_project_months <- 12L * (
    lubridate::year(project_end) - lubridate::year(project_start)
  ) + lubridate::month(project_end) - lubridate::month(project_start) + 1L

  # Sample membership is based on actual MTur observations, not on rows added
  # by completion of the country-mode calendar.
  origin_coverage <- total |>
    dplyr::filter(.data$all_zero_imputed == 0L, !is.na(.data$arrivals)) |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      origin_first_date = min(.data$date),
      origin_last_date = max(.data$date),
      origin_observed_months = dplyr::n_distinct(.data$date),
      origin_total_arrivals = sum(.data$arrivals, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      origin_entry_cohort = lubridate::year(.data$origin_first_date),
      origin_span_months = 12L * (
        lubridate::year(.data$origin_last_date) - lubridate::year(.data$origin_first_date)
      ) + lubridate::month(.data$origin_last_date) -
        lubridate::month(.data$origin_first_date) + 1L,
      sample_core_2000 = as.integer(
        .data$origin_first_date == project_start &
          .data$origin_last_date == project_end &
          .data$origin_observed_months == full_project_months
      ),
      sample_long_pre2009 = as.integer(
        .data$origin_first_date <= as.Date("2008-12-01") &
          .data$origin_last_date == project_end
      ),
      sample_broad_5y = as.integer(
        .data$origin_span_months >= broad_min_months &
          .data$origin_observed_months >= broad_min_months &
          .data$origin_last_date == project_end
      ),
      sample_full = 1L
    )

  write_csv_safe(
    origin_coverage,
    fs::path(cfg$paths$interim, "origin_sample_flags.csv")
  )

  total <- total |>
    dplyr::left_join(origin_coverage, by = "origin_iso3")

  access <- arrivals |>
    dplyr::filter(.data$access_mode != "all") |>
    dplyr::transmute(
      origin_iso3 = .data$origin_iso3,
      date = .data$date,
      access_mode = .data$access_mode,
      zero_imputed = .data$zero_imputed,
      observation_status = dplyr::if_else(
        .data$zero_imputed == 1L,
        "unobserved_completed_cell", "observed_cell"
      ),
      arrivals = dplyr::if_else(
        .data$zero_imputed == 1L,
        NA_real_, as.numeric(.data$arrivals)
      )
    )

  origin_macro <- macro |>
    dplyr::rename(
      origin_iso3 = iso3c,
      macro_year = year,
      origin_country = country,
      origin_income_group = income_group,
      origin_region = region,
      origin_gdp_pc = gdp_pc_real,
      origin_gdp_pc_ppp = gdp_pc_ppp,
      origin_population = population,
      origin_cpi = cpi,
      origin_fx = fx_lcu_per_usd,
      origin_price_level_hh = price_level_hh,
      origin_price_level_gdp = price_level_gdp,
      origin_cpi_base_year = cpi_base_year,
      origin_fx_source = fx_source,
      origin_price_proxy_iso3c = price_proxy_iso3c,
      origin_cpi_interpolated = cpi_interpolated,
      origin_price_level_hh_interpolated = price_level_hh_interpolated,
      origin_price_level_gdp_interpolated = price_level_gdp_interpolated,
      origin_cpi_proxy_used = cpi_proxy_used,
      origin_fx_proxy_used = fx_proxy_used,
      origin_price_level_hh_proxy_used = price_level_hh_proxy_used,
      origin_price_level_gdp_proxy_used = price_level_gdp_proxy_used
    )

  brazil_macro <- macro |>
    dplyr::filter(.data$iso3c == cfg$project$main_destination_iso3) |>
    dplyr::transmute(
      macro_year = .data$year,
      brazil_cpi = .data$cpi,
      brazil_fx = .data$fx_lcu_per_usd,
      brazil_price_level_hh = .data$price_level_hh,
      brazil_price_level_gdp = .data$price_level_gdp
    )

  add_covariates <- function(data) {
    data |>
      dplyr::mutate(
        year = lubridate::year(.data$date),
        month = lubridate::month(.data$date),
        macro_year = .data$year - 1L,
        year_month = format(.data$date, "%Y-%m")
      ) |>
      dplyr::left_join(origin_macro, by = c("origin_iso3", "macro_year")) |>
      dplyr::left_join(brazil_macro, by = "macro_year") |>
      dplyr::left_join(geodist, by = "origin_iso3") |>
      dplyr::left_join(connectivity, by = c("origin_iso3", "date")) |>
      dplyr::left_join(visa, by = c("origin_iso3", "date")) |>
      dplyr::mutate(
        relative_price_cpi = (
          .data$brazil_cpi * (.data$origin_fx / .data$brazil_fx)
        ) / .data$origin_cpi,
        relative_price_pli = .data$brazil_price_level_hh /
          .data$origin_price_level_hh,
        relative_price_gdp_pli = .data$brazil_price_level_gdp /
          .data$origin_price_level_gdp,
        # Compatibility aliases follow the binding GDP-PLI definition. CPI and
        # household PLI remain available under their explicit robustness names.
        relative_price = .data$relative_price_gdp_pli,
        log_relative_price_cpi = safe_log(.data$relative_price_cpi),
        log_relative_price_pli = safe_log(.data$relative_price_pli),
        log_relative_price_gdp_pli = safe_log(.data$relative_price_gdp_pli),
        log_relative_price = .data$log_relative_price_gdp_pli,
        log_gdp_pc_l1y = safe_log(.data$origin_gdp_pc),
        log_gdp_pc_ppp_l1y = safe_log(.data$origin_gdp_pc_ppp),
        log_population_l1y = safe_log(.data$origin_population),
        direct = dplyr::coalesce(.data$direct, 0L),
        flights = dplyr::coalesce(.data$flights, 0),
        seats = dplyr::coalesce(.data$seats, 0),
        passengers = dplyr::coalesce(.data$passengers, 0),
        inbound_flights = dplyr::coalesce(.data$inbound_flights, 0),
        inbound_seats = dplyr::coalesce(.data$inbound_seats, 0),
        inbound_passengers = dplyr::coalesce(.data$inbound_passengers, 0),
        inbound_ask = dplyr::coalesce(.data$inbound_ask, 0),
        inbound_rpk = dplyr::coalesce(.data$inbound_rpk, 0),
        outbound_flights = dplyr::coalesce(.data$outbound_flights, 0),
        outbound_seats = dplyr::coalesce(.data$outbound_seats, 0),
        outbound_passengers = dplyr::coalesce(.data$outbound_passengers, 0),
        outbound_ask = dplyr::coalesce(.data$outbound_ask, 0),
        outbound_rpk = dplyr::coalesce(.data$outbound_rpk, 0),
        log_seats = log1p_zero_safe(.data$seats),
        log_flights = log1p_zero_safe(.data$flights),
        log_inbound_ask = log1p_zero_safe(.data$inbound_ask),
        inbound_load_factor = dplyr::if_else(
          .data$inbound_ask > 0,
          .data$inbound_rpk / .data$inbound_ask,
          NA_real_
        ),
        visa_required = dplyr::coalesce(.data$visa_required, NA_integer_),
        evisa = dplyr::coalesce(.data$evisa, NA_integer_),
        visa_free = dplyr::coalesce(.data$visa_free, NA_integer_),
        covid = as.integer(.data$date >= as.Date(cfg$project$covid_start) & .data$date <= as.Date(cfg$project$covid_end)),
        post_covid = as.integer(.data$date > as.Date(cfg$project$covid_end)),
        world_cup = as.integer(.data$date >= as.Date("2014-06-01") & .data$date <= as.Date("2014-07-01")),
        olympics = as.integer(.data$date == as.Date("2016-08-01")),
        long_haul = as.integer(.data$distance_km >= 5000),
        log_distw_x_direct = .data$log_distw * .data$direct,
        log_distance_x_direct = .data$log_distw_x_direct
      ) |>
      dplyr::group_by(.data$origin_iso3) |>
      dplyr::arrange(.data$date, .by_group = TRUE) |>
      dplyr::mutate(
        month_index = 12L * .data$year + .data$month,
        arrivals_l12 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 12L) == 12L,
          dplyr::lag(.data$arrivals, 12L), NA_real_
        ),
        direct_l1 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 1L) == 1L,
          dplyr::lag(.data$direct, 1L), NA_integer_
        ),
        direct_l3 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 3L) == 3L,
          dplyr::lag(.data$direct, 3L), NA_integer_
        ),
        direct_l6 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 6L) == 6L,
          dplyr::lag(.data$direct, 6L), NA_integer_
        ),
        direct_l12 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 12L) == 12L,
          dplyr::lag(.data$direct, 12L), NA_integer_
        ),
        log_seats_l1 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 1L) == 1L,
          dplyr::lag(.data$log_seats, 1L), NA_real_
        ),
        log_seats_l3 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 3L) == 3L,
          dplyr::lag(.data$log_seats, 3L), NA_real_
        ),
        log_seats_l6 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 6L) == 6L,
          dplyr::lag(.data$log_seats, 6L), NA_real_
        ),
        log_seats_l12 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 12L) == 12L,
          dplyr::lag(.data$log_seats, 12L), NA_real_
        ),
        log_flights_l1 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 1L) == 1L,
          dplyr::lag(.data$log_flights, 1L), NA_real_
        ),
        log_flights_l3 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 3L) == 3L,
          dplyr::lag(.data$log_flights, 3L), NA_real_
        ),
        log_flights_l6 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 6L) == 6L,
          dplyr::lag(.data$log_flights, 6L), NA_real_
        ),
        log_flights_l12 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 12L) == 12L,
          dplyr::lag(.data$log_flights, 12L), NA_real_
        ),
        log_inbound_ask_l1 = dplyr::if_else(
          .data$month_index - dplyr::lag(.data$month_index, 1L) == 1L,
          dplyr::lag(.data$log_inbound_ask, 1L), NA_real_
        ),
        consecutive_prior_3 =
          .data$month_index - dplyr::lag(.data$month_index, 1L) == 1L &
          .data$month_index - dplyr::lag(.data$month_index, 2L) == 2L &
          .data$month_index - dplyr::lag(.data$month_index, 3L) == 3L,
        seats_ma3_l1 = dplyr::if_else(.data$consecutive_prior_3, (
          dplyr::lag(.data$seats, 1L) + dplyr::lag(.data$seats, 2L) +
            dplyr::lag(.data$seats, 3L)
        ) / 3, NA_real_),
        flights_ma3_l1 = dplyr::if_else(.data$consecutive_prior_3, (
          dplyr::lag(.data$flights, 1L) + dplyr::lag(.data$flights, 2L) +
            dplyr::lag(.data$flights, 3L)
        ) / 3, NA_real_),
        log_seats_ma3_l1 = log1p_zero_safe(.data$seats_ma3_l1),
        log_flights_ma3_l1 = log1p_zero_safe(.data$flights_ma3_l1),
        log_distw_x_direct_l1 = .data$log_distw * .data$direct_l1,
        log_distance_x_direct_l1 = .data$log_distw_x_direct_l1
      ) |>
      dplyr::ungroup() |>
      dplyr::select(-dplyr::all_of("consecutive_prior_3"))
  }

  total <- add_covariates(total)
  access <- access |>
    dplyr::left_join(
      dplyr::select(
        total,
        -dplyr::any_of(c(
          "arrivals", "any_zero_imputed", "all_zero_imputed",
          "observed_mode_rows", "imputed_mode_rows", "observation_status",
          "arrivals_l12"
        ))
      ),
      by = c("origin_iso3", "date")
    ) |>
    dplyr::group_by(.data$origin_iso3, .data$access_mode) |>
    dplyr::arrange(.data$date, .by_group = TRUE) |>
    dplyr::mutate(
      arrivals_l12 = dplyr::if_else(
        .data$month_index - dplyr::lag(.data$month_index, 12L) == 12L,
        dplyr::lag(.data$arrivals, 12L), NA_real_
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::mutate(origin_access = interaction(.data$origin_iso3, .data$access_mode, drop = TRUE))

  assert_unique_key(total, c("origin_iso3", "date"), "total analysis panel")
  assert_unique_key(access, c("origin_iso3", "access_mode", "date"), "access-mode panel")
  write_parquet_safe(total, fs::path(cfg$paths$processed, "tourism_panel_monthly.parquet"))
  write_parquet_safe(access, fs::path(cfg$paths$processed, "tourism_panel_access_monthly.parquet"))
  list(total = total, access = access)
}
