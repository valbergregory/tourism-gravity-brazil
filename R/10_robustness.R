filter_robustness_sample <- function(panel, sample_flag, price_variable,
                                     distance_variable = "log_distw",
                                     exclude_distw_origins = character(),
                                     interaction_reference_km = 5000) {
  required <- c(
    "arrivals", "origin_iso3", "date", "year_month", sample_flag,
    "log_gdp_pc_l1y", "log_population_l1y", price_variable,
    distance_variable
  )
  require_model_columns(panel, required, "robustness panel")
  filtered <- panel |>
    dplyr::filter(
      !is.na(.data[[sample_flag]]) & .data[[sample_flag]] == 1L,
      !.data$origin_iso3 %in% exclude_distw_origins,
      !is.na(.data$arrivals) & .data$arrivals >= 0,
      is.finite(.data$log_gdp_pc_l1y),
      is.finite(.data$log_population_l1y),
      is.finite(.data[[price_variable]]),
      is.finite(.data[[distance_variable]])
    )
  add_centered_distance_interactions(filtered, interaction_reference_km)
}

robustness_twfe_formula <- function(price_variable, extra = NULL,
                                    time_effect = "year_month") {
  rhs <- c(
    "log_gdp_pc_l1y", "log_population_l1y", price_variable, extra
  )
  stats::as.formula(paste(
    "arrivals ~", paste(rhs, collapse = " + "),
    "| origin_iso3 +", time_effect
  ))
}

robustness_required <- function(price_variable, extra = NULL,
                                time_effect = "year_month") {
  c(
    "arrivals", "origin_iso3", time_effect,
    "log_gdp_pc_l1y", "log_population_l1y", price_variable, extra
  )
}

add_cre_means <- function(data, price_variable) {
  data |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::mutate(
      mean_log_gdp_pc_l1y = mean(.data$log_gdp_pc_l1y, na.rm = TRUE),
      mean_log_population_l1y = mean(.data$log_population_l1y, na.rm = TRUE),
      mean_price = mean(.data[[price_variable]], na.rm = TRUE)
    ) |>
    dplyr::ungroup()
}

fit_distance_cre_robustness <- function(name, data, price_variable,
                                        distance_variable) {
  data <- add_cre_means(data, price_variable)
  formula <- stats::as.formula(paste(
    "arrivals ~ log_gdp_pc_l1y + log_population_l1y +",
    price_variable, "+", distance_variable,
    "+ contig + common_official_language + colonial_link +",
    "mean_log_gdp_pc_l1y + mean_log_population_l1y + mean_price",
    "| origin_region + year_month"
  ))
  required <- c(
    "arrivals", "origin_iso3", "year_month", "origin_region",
    "log_gdp_pc_l1y", "log_population_l1y", price_variable,
    distance_variable, "contig", "common_official_language",
    "colonial_link", "mean_log_gdp_pc_l1y",
    "mean_log_population_l1y", "mean_price"
  )
  fit_fepois_audited(
    name, formula, data, required, family_label = "PPML-CRE"
  )
}

run_robustness_models <- function(panel, access_panel, econometric_sample,
                                  sample_freeze_files, cfg) {
  if (length(sample_freeze_files) == 0L ||
      any(!file.exists(sample_freeze_files))) {
    stop("The audited sample freeze is missing; robustness will not run.")
  }
  contract <- econometric_sample$contract
  interaction_reference_km <- as.numeric(
    cfg$econometrics$interaction_reference_km %||% 5000
  )
  data <- add_centered_distance_interactions(
    econometric_sample$data, interaction_reference_km
  ) |>
    dplyr::mutate(
      log_relative_price_gdp_pli_centered =
        .data$log_relative_price_gdp_pli -
        mean(.data$log_relative_price_gdp_pli, na.rm = TRUE),
      log_relative_price_gdp_pli_centered_sq =
        .data$log_relative_price_gdp_pli_centered^2
    )
  covid_start <- as.Date(cfg$project$covid_start)
  covid_end <- as.Date(cfg$project$covid_end)
  main_price <- "log_relative_price_gdp_pli"
  combined_extra <- c(
    "direct_l1", "log_seats_l1", "log_distw_centered_x_direct_l1"
  )
  combined_formula <- robustness_twfe_formula(
    main_price,
    "direct_l1 + log_seats_l1 + log_distw_centered_x_direct_l1"
  )
  combined_required <- robustness_required(main_price, combined_extra)

  fits <- list()
  fits$pre_covid <- fit_fepois_audited(
    "pre_covid", combined_formula,
    dplyr::filter(data, .data$date < covid_start),
    combined_required
  )
  fits$post_reopening <- fit_fepois_audited(
    "post_reopening", combined_formula,
    dplyr::filter(data, .data$date > covid_end),
    combined_required
  )
  fits$exclude_pandemic <- fit_fepois_audited(
    "exclude_pandemic", combined_formula,
    dplyr::filter(data, .data$date < covid_start | .data$date > covid_end),
    combined_required
  )

  fits$price_nonlinearity <- fit_fepois_audited(
    "price_nonlinearity",
    stats::as.formula(paste(
      "arrivals ~ log_gdp_pc_l1y + log_population_l1y +",
      "log_relative_price_gdp_pli_centered +",
      "log_relative_price_gdp_pli_centered_sq |",
      "origin_iso3 + year_month"
    )),
    data,
    c(
      "arrivals", "origin_iso3", "year_month", "log_gdp_pc_l1y",
      "log_population_l1y", "log_relative_price_gdp_pli_centered",
      "log_relative_price_gdp_pli_centered_sq"
    )
  )

  nonpandemic_regimes <- data |>
    dplyr::filter(.data$date < covid_start | .data$date > covid_end) |>
    dplyr::mutate(
      post_reopening = as.integer(.data$date > covid_end),
      price_x_post_reopening =
        .data$log_relative_price_gdp_pli * .data$post_reopening,
      seats_x_post_reopening =
        .data$log_seats_l1 * .data$post_reopening
    )
  fits$post_reopening_interactions <- fit_fepois_audited(
    "post_reopening_interactions",
    stats::as.formula(paste(
      "arrivals ~ log_gdp_pc_l1y + log_population_l1y +",
      "log_relative_price_gdp_pli + log_seats_l1 +",
      "price_x_post_reopening + seats_x_post_reopening |",
      "origin_iso3 + year_month"
    )),
    nonpandemic_regimes,
    c(
      "arrivals", "origin_iso3", "year_month", "log_gdp_pc_l1y",
      "log_population_l1y", "log_relative_price_gdp_pli",
      "log_seats_l1", "price_x_post_reopening",
      "seats_x_post_reopening"
    )
  )

  balanced <- filter_robustness_sample(
    panel = panel,
    sample_flag = contract$balanced_sample_flag,
    price_variable = main_price,
    distance_variable = "log_distw",
    exclude_distw_origins = contract$excluded_distw_origins,
    interaction_reference_km = interaction_reference_km
  )
  fits$balanced_core_2000 <- fit_fepois_audited(
    "balanced_core_2000", combined_formula, balanced, combined_required
  )

  cpi <- filter_robustness_sample(
    panel, contract$main_sample_flag, "log_relative_price_cpi",
    "log_distw", contract$excluded_distw_origins,
    interaction_reference_km
  )
  fits$cpi_price <- fit_fepois_audited(
    "cpi_price",
    robustness_twfe_formula(
      "log_relative_price_cpi",
      "direct_l1 + log_seats_l1 + log_distw_centered_x_direct_l1"
    ),
    cpi,
    robustness_required("log_relative_price_cpi", combined_extra)
  )

  household_pli <- filter_robustness_sample(
    panel, contract$main_sample_flag, "log_relative_price_pli",
    "log_distw", contract$excluded_distw_origins,
    interaction_reference_km
  )
  fits$household_pli_price <- fit_fepois_audited(
    "household_pli_price",
    robustness_twfe_formula(
      "log_relative_price_pli",
      "direct_l1 + log_seats_l1 + log_distw_centered_x_direct_l1"
    ),
    household_pli,
    robustness_required("log_relative_price_pli", combined_extra)
  )

  fits$exclude_argentina <- fit_fepois_audited(
    "exclude_argentina", combined_formula,
    dplyr::filter(data, .data$origin_iso3 != "ARG"),
    combined_required
  )

  dominant_count <- as.integer(cfg$econometrics$dominant_market_count %||% 5L)
  dominant_origins <- data |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      total_arrivals = sum(.data$arrivals, na.rm = TRUE), .groups = "drop"
    ) |>
    dplyr::slice_max(
      .data$total_arrivals, n = dominant_count, with_ties = FALSE
    ) |>
    dplyr::pull("origin_iso3")
  fits$exclude_top_markets <- fit_fepois_audited(
    "exclude_top_markets", combined_formula,
    dplyr::filter(data, !.data$origin_iso3 %in% dominant_origins),
    combined_required
  )

  fits$contemporaneous_connectivity <- fit_fepois_audited(
    "contemporaneous_connectivity",
    robustness_twfe_formula(
      main_price, "direct + log_seats + log_distw_centered_x_direct"
    ),
    data,
    robustness_required(
      main_price,
      c("direct", "log_seats", "log_distw_centered_x_direct")
    )
  )

  fits$baseline_two_way_cluster <- fit_fepois_audited(
    "baseline_two_way_cluster",
    robustness_twfe_formula(main_price),
    data,
    robustness_required(main_price),
    vcov = ~origin_iso3 + year_month
  )
  fits$baseline_heteroskedastic <- fit_fepois_audited(
    "baseline_heteroskedastic",
    robustness_twfe_formula(main_price),
    data,
    robustness_required(main_price),
    vcov = "hetero"
  )

  quarterly <- data |>
    dplyr::mutate(
      year_quarter = paste0(.data$year, "-Q", lubridate::quarter(.data$date))
    ) |>
    dplyr::group_by(.data$origin_iso3, .data$year_quarter) |>
    dplyr::summarise(
      arrivals = sum(.data$arrivals, na.rm = TRUE),
      log_gdp_pc_l1y = mean(.data$log_gdp_pc_l1y, na.rm = TRUE),
      log_population_l1y = mean(.data$log_population_l1y, na.rm = TRUE),
      log_relative_price_gdp_pli = mean(
        .data$log_relative_price_gdp_pli, na.rm = TRUE
      ),
      .groups = "drop"
    )
  fits$quarterly <- fit_fepois_audited(
    "quarterly",
    robustness_twfe_formula(main_price, time_effect = "year_quarter"),
    quarterly,
    robustness_required(main_price, time_effect = "year_quarter")
  )

  alt_distance_specs <- c(distcap = "log_distcap", simple = "log_dist")
  for (label in names(alt_distance_specs)) {
    distance_variable <- alt_distance_specs[[label]]
    if (!distance_variable %in% names(panel)) next
    alternative <- filter_robustness_sample(
      panel, contract$main_sample_flag, main_price, distance_variable,
      interaction_reference_km = interaction_reference_km
    )
    if (nrow(alternative) == 0L) next
    model_name <- paste0("gravity_", label, "_cre")
    fits[[model_name]] <- fit_distance_cre_robustness(
      model_name, alternative, main_price, distance_variable
    )
  }

  air <- access_panel |>
    dplyr::filter(.data$access_mode == "air") |>
    filter_robustness_sample(
      sample_flag = contract$main_sample_flag,
      price_variable = main_price,
      distance_variable = "log_distw",
      exclude_distw_origins = contract$excluded_distw_origins,
      interaction_reference_km = interaction_reference_km
    )
  fits$air_access_mode <- fit_fepois_audited(
    "air_access_mode", combined_formula, air, combined_required
  )

  modal <- access_panel |>
    dplyr::filter(
      .data$access_mode %in% c("air", "land", "maritime", "fluvial")
    ) |>
    filter_robustness_sample(
      sample_flag = contract$main_sample_flag,
      price_variable = main_price,
      distance_variable = "log_distw",
      exclude_distw_origins = contract$excluded_distw_origins,
      interaction_reference_km = interaction_reference_km
    )
  modal_formula <- stats::as.formula(paste(
    "arrivals ~ log_gdp_pc_l1y + log_population_l1y +",
    "log_relative_price_gdp_pli + direct_l1 + log_seats_l1 +",
    "log_distw_centered_x_direct_l1 | origin_iso3^access_mode +",
    "access_mode^year_month"
  ))
  modal_required <- c(
    combined_required, "access_mode"
  )
  fits$modal_panel <- fit_fepois_audited(
    "modal_panel", modal_formula, modal, modal_required
  )

  bundle <- assemble_model_bundle(fits, "robustness")
  bundle$dominant_origins_excluded <- dominant_origins
  bundle$sample_counts <- tibble::tibble(
    specification = c(
      "frozen_main", "balanced_core_2000", "cpi_price",
      "household_pli_price", "air_access_mode", "modal_panel"
    ),
    rows = c(
      nrow(data), nrow(balanced), nrow(cpi), nrow(household_pli),
      nrow(air), nrow(modal)
    ),
    origins = c(
      dplyr::n_distinct(data$origin_iso3),
      dplyr::n_distinct(balanced$origin_iso3),
      dplyr::n_distinct(cpi$origin_iso3),
      dplyr::n_distinct(household_pli$origin_iso3),
      dplyr::n_distinct(air$origin_iso3),
      dplyr::n_distinct(modal$origin_iso3)
    )
  )
  bundle
}
