require_model_columns <- function(data, columns, object_name = "data") {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0L) {
    stop(
      object_name, " is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(data)
}

econometric_contract <- function(cfg) {
  expected_integer <- function(value) {
    value <- suppressWarnings(as.integer(value %||% NA_integer_))
    if (length(value) != 1L || is.na(value) || value <= 0L) NA_integer_ else value
  }
  list(
    main_sample_flag = as.character(cfg$econometrics$main_sample_flag),
    balanced_sample_flag = as.character(cfg$econometrics$balanced_sample_flag),
    main_price = as.character(cfg$econometrics$main_price),
    main_distance = as.character(cfg$econometrics$main_distance),
    expected_rows = expected_integer(cfg$econometrics$expected_main_rows),
    expected_origins = expected_integer(cfg$econometrics$expected_main_origins),
    excluded_distw_origins = toupper(as.character(
      unlist(cfg$econometrics$excluded_distw_origins, use.names = FALSE)
    )),
    strict = isTRUE(cfg$econometrics$strict_sample_contract)
  )
}

build_econometric_sample <- function(panel, cfg) {
  contract <- econometric_contract(cfg)
  required <- c(
    "origin_iso3", "date", "year_month", "arrivals",
    "all_zero_imputed", "observation_status",
    contract$main_sample_flag,
    "log_gdp_pc_l1y", "log_population_l1y",
    "log_relative_price_gdp_pli", "distw_km", "log_distw"
  )
  require_model_columns(panel, required, "monthly tourism panel")
  assert_unique_key(panel, c("origin_iso3", "date"), "monthly tourism panel")

  eligibility <- panel |>
    dplyr::mutate(
      origin_iso3 = toupper(as.character(.data$origin_iso3)),
      in_named_sample = !is.na(.data[[contract$main_sample_flag]]) &
        .data[[contract$main_sample_flag]] == 1L,
      allowed_distw_origin = !.data$origin_iso3 %in%
        contract$excluded_distw_origins,
      outcome_complete = !is.na(.data$arrivals) & .data$arrivals >= 0,
      source_observed = .data$all_zero_imputed == 0L,
      macro_complete = is.finite(.data$log_gdp_pc_l1y) &
        is.finite(.data$log_population_l1y),
      gdp_pli_complete = is.finite(.data$log_relative_price_gdp_pli),
      distw_complete = is.finite(.data$distw_km) & .data$distw_km > 0 &
        is.finite(.data$log_distw),
      main_eligible = .data$in_named_sample & .data$allowed_distw_origin &
        .data$source_observed & .data$outcome_complete & .data$macro_complete &
        .data$gdp_pli_complete & .data$distw_complete
    )

  main <- eligibility |>
    dplyr::filter(.data$main_eligible) |>
    dplyr::arrange(.data$origin_iso3, .data$date) |>
    dplyr::select(-dplyr::any_of(c(
      "in_named_sample", "allowed_distw_origin", "outcome_complete",
      "source_observed",
      "macro_complete", "gdp_pli_complete", "distw_complete",
      "main_eligible"
    )))

  assert_unique_key(main, c("origin_iso3", "date"), "frozen main sample")
  if (any(main$origin_iso3 %in% contract$excluded_distw_origins)) {
    stop("A distw specification contains an explicitly excluded origin.")
  }
  if (any(!is.finite(main$log_distw)) ||
      any(!is.finite(main$log_relative_price_gdp_pli))) {
    stop("The frozen sample contains a non-finite main distance or price.")
  }

  observed_rows <- nrow(main)
  observed_origins <- dplyr::n_distinct(main$origin_iso3)
  contract_configured <- !is.na(contract$expected_rows) &&
    !is.na(contract$expected_origins)
  contract_ok <- contract_configured &&
    observed_rows == contract$expected_rows &&
    observed_origins == contract$expected_origins

  if (!contract_configured) {
    message(
      "The corrected sample contract is not configured. Candidate values: ",
      observed_rows, " rows and ", observed_origins, " origins. Update ",
      "expected_main_rows and expected_main_origins in config.yml before estimation."
    )
  } else if (!contract_ok) {
    message <- paste0(
      "Econometric sample contract failed: observed ", observed_rows,
      " rows and ", observed_origins, " origins; expected ",
      contract$expected_rows, " rows and ", contract$expected_origins,
      " origins. Inspect the sample audit before estimation."
    )
    if (contract$strict) stop(message, call. = FALSE) else warning(message)
  }

  origin_audit <- eligibility |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      first_date = min(.data$date),
      last_date = max(.data$date),
      total_rows = dplyr::n(),
      total_arrivals = sum(.data$arrivals, na.rm = TRUE),
      named_sample_rows = sum(.data$in_named_sample, na.rm = TRUE),
      allowed_distw_origin = all(.data$allowed_distw_origin),
      outcome_complete_rows = sum(.data$outcome_complete, na.rm = TRUE),
      source_observed_rows = sum(.data$source_observed, na.rm = TRUE),
      macro_complete_rows = sum(.data$macro_complete, na.rm = TRUE),
      gdp_pli_complete_rows = sum(.data$gdp_pli_complete, na.rm = TRUE),
      distw_complete_rows = sum(.data$distw_complete, na.rm = TRUE),
      frozen_rows = sum(.data$main_eligible, na.rm = TRUE),
      frozen_arrivals = sum(.data$arrivals[.data$main_eligible], na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      included = .data$frozen_rows > 0L,
      exclusion_reason = dplyr::case_when(
        .data$included ~ "included",
        .data$named_sample_rows == 0L ~ paste0(
          "outside_", contract$main_sample_flag
        ),
        !.data$allowed_distw_origin ~ "excluded_from_distw_specifications",
        .data$source_observed_rows == 0L ~ "no_observed_mtur_cells",
        .data$outcome_complete_rows == 0L ~ "invalid_or_missing_arrivals",
        .data$macro_complete_rows == 0L ~ "missing_income_or_population",
        .data$gdp_pli_complete_rows == 0L ~ "missing_gdp_pli",
        .data$distw_complete_rows == 0L ~ "missing_distw",
        TRUE ~ "incomplete_rows_within_eligible_window"
      )
    ) |>
    dplyr::arrange(dplyr::desc(.data$included), dplyr::desc(.data$total_arrivals))

  row_audit <- eligibility |>
    dplyr::summarise(
      panel_rows = dplyr::n(),
      outside_named_sample = sum(!.data$in_named_sample),
      excluded_distw_origin = sum(.data$in_named_sample &
        !.data$allowed_distw_origin),
      completed_cells_not_observed = sum(.data$in_named_sample &
        .data$allowed_distw_origin & !.data$source_observed),
      invalid_or_missing_arrivals = sum(.data$in_named_sample &
        .data$allowed_distw_origin & .data$source_observed &
        !.data$outcome_complete),
      missing_income_or_population = sum(.data$in_named_sample &
        .data$allowed_distw_origin & .data$outcome_complete &
        !.data$macro_complete),
      missing_gdp_pli = sum(.data$in_named_sample &
        .data$allowed_distw_origin & .data$outcome_complete &
        .data$macro_complete & !.data$gdp_pli_complete),
      missing_distw = sum(.data$in_named_sample &
        .data$allowed_distw_origin & .data$outcome_complete &
        .data$macro_complete & .data$gdp_pli_complete &
        !.data$distw_complete),
      frozen_rows = sum(.data$main_eligible)
    ) |>
    tidyr::pivot_longer(
      dplyr::everything(), names_to = "criterion", values_to = "rows"
    )

  total_arrivals <- sum(panel$arrivals, na.rm = TRUE)
  frozen_arrivals <- sum(main$arrivals, na.rm = TRUE)
  summary <- tibble::tibble(
    sample_flag = contract$main_sample_flag,
    price_measure = contract$main_price,
    distance_measure = contract$main_distance,
    rows = observed_rows,
    origins = observed_origins,
    first_date = min(main$date),
    last_date = max(main$date),
    zero_rows = sum(main$arrivals == 0),
    zero_share = mean(main$arrivals == 0),
    arrivals = frozen_arrivals,
    full_panel_arrival_coverage = frozen_arrivals / total_arrivals,
    expected_rows = contract$expected_rows,
    expected_origins = contract$expected_origins,
    contract_configured = contract_configured,
    contract_ok = contract_ok
  )

  list(
    data = main,
    origin_audit = origin_audit,
    row_audit = row_audit,
    summary = summary,
    contract = contract
  )
}

write_frozen_econometric_sample <- function(econometric_sample, cfg) {
  if (!isTRUE(econometric_sample$summary$contract_ok[[1L]])) {
    stop(
      "The corrected sample contract is not frozen. Run ",
      "scripts/06_recalibrar_contrato_amostra.R, copy the candidate row/origin ",
      "counts into config.yml, and rerun that script before estimation.",
      call. = FALSE
    )
  }
  audit_dir <- cfg$paths$audit %||% "output/audit"
  processed_dir <- cfg$paths$processed
  fs::dir_create(c(audit_dir, processed_dir), recurse = TRUE)

  sample_path <- fs::path(
    processed_dir, "econometric_sample_gdp_pli_distw.parquet"
  )
  summary_path <- fs::path(audit_dir, "econometric_sample_summary.csv")
  origin_path <- fs::path(
    audit_dir, "econometric_sample_origin_inclusion.csv"
  )
  row_path <- fs::path(audit_dir, "econometric_sample_row_exclusions.csv")
  manifest_path <- fs::path(audit_dir, "econometric_sample_manifest.csv")

  write_parquet_safe(econometric_sample$data, sample_path)
  write_csv_safe(econometric_sample$summary, summary_path)
  write_csv_safe(econometric_sample$origin_audit, origin_path)
  write_csv_safe(econometric_sample$row_audit, row_path)

  manifest <- econometric_sample$summary |>
    dplyr::mutate(
      frozen_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
      sample_file = normalizePath(sample_path, winslash = "/", mustWork = TRUE),
      sample_md5 = unname(tools::md5sum(sample_path))
    )
  write_csv_safe(manifest, manifest_path)

  normalizePath(
    c(sample_path, summary_path, origin_path, row_path, manifest_path),
    winslash = "/", mustWork = TRUE
  )
}

complete_spec_data <- function(data, required_columns) {
  require_model_columns(data, required_columns, "model input")
  keep <- stats::complete.cases(data[, required_columns, drop = FALSE])
  data[keep, , drop = FALSE]
}

add_centered_distance_interactions <- function(data, reference_km = 5000) {
  if (!is.finite(reference_km) || reference_km <= 0) {
    stop("The distance-interaction reference must be positive and finite.")
  }
  require_model_columns(data, "log_distw", "distance-interaction input")
  data <- dplyr::mutate(
    data,
    log_distw_centered = .data$log_distw - log(reference_km)
  )
  if ("direct_l1" %in% names(data)) {
    data <- dplyr::mutate(
      data,
      log_distw_centered_x_direct_l1 =
        .data$log_distw_centered * .data$direct_l1
    )
  }
  if ("direct" %in% names(data)) {
    data <- dplyr::mutate(
      data,
      log_distw_centered_x_direct =
        .data$log_distw_centered * .data$direct
    )
  }
  data
}

fit_fepois_audited <- function(name, formula, data, required_columns,
                               vcov = ~origin_iso3,
                               family_label = "PPML") {
  model_data <- complete_spec_data(data, required_columns)
  warnings <- character()
  fitted_model <- withCallingHandlers(
    fixest::fepois(
      formula,
      data = model_data,
      vcov = vcov,
      notes = FALSE,
      warn = TRUE
    ),
    warning = function(warning_condition) {
      warnings <<- c(warnings, conditionMessage(warning_condition))
      invokeRestart("muffleWarning")
    }
  )

  collinear <- fitted_model$collin.var %||% character()
  convergence <- if (is.null(fitted_model$convStatus)) {
    NA
  } else {
    isTRUE(fitted_model$convStatus)
  }
  removed_fixed_effects <- fitted_model$fixef_removed
  separation_fe_levels_removed <- if (is.null(removed_fixed_effects)) {
    0L
  } else if (is.list(removed_fixed_effects)) {
    sum(lengths(removed_fixed_effects))
  } else {
    length(removed_fixed_effects)
  }
  audit <- tibble::tibble(
    model = name,
    estimator = family_label,
    formula = paste(deparse(formula), collapse = " "),
    input_rows = nrow(model_data),
    estimation_rows = stats::nobs(fitted_model),
    removed_rows = nrow(model_data) - stats::nobs(fitted_model),
    separation_fe_levels_removed = separation_fe_levels_removed,
    origins = dplyr::n_distinct(model_data$origin_iso3),
    zero_rows = sum(model_data$arrivals == 0, na.rm = TRUE),
    converged = convergence,
    collinear_variables = paste(collinear, collapse = "; "),
    warnings = paste(unique(warnings), collapse = " | ")
  )
  list(model = fitted_model, audit = audit)
}

assemble_model_bundle <- function(fits, family) {
  models <- purrr::map(fits, "model")
  names(models) <- names(fits)
  audit <- dplyr::bind_rows(purrr::map(fits, "audit"))
  list(models = models, audit = audit, family = family)
}

run_main_models <- function(econometric_sample, sample_freeze_files, cfg) {
  # This dependency guarantees that estimation starts only after the audited,
  # checksummed sample snapshot has been written successfully.
  if (length(sample_freeze_files) == 0L ||
      any(!file.exists(sample_freeze_files))) {
    stop("The audited sample freeze is missing; models will not be estimated.")
  }
  if (!isTRUE(econometric_sample$summary$contract_ok[[1L]])) {
    stop("Model estimation requires a valid corrected sample contract.", call. = FALSE)
  }
  data <- add_centered_distance_interactions(
    econometric_sample$data,
    as.numeric(cfg$econometrics$interaction_reference_km %||% 5000)
  )
  required <- c(
    "arrivals", "origin_iso3", "year_month", "origin_region",
    "log_gdp_pc_l1y", "log_population_l1y",
    "log_relative_price_gdp_pli", "log_distw", "contig",
    "common_official_language", "colonial_link", "direct_l1",
    "log_seats_l1", "log_flights_l1", "log_seats_ma3_l1",
    "log_distw_centered_x_direct_l1"
  )
  require_model_columns(data, required, "frozen econometric sample")

  data <- data |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::mutate(
      mean_log_gdp_pc_l1y = mean(.data$log_gdp_pc_l1y, na.rm = TRUE),
      mean_log_population_l1y = mean(.data$log_population_l1y, na.rm = TRUE),
      mean_log_relative_price_gdp_pli = mean(
        .data$log_relative_price_gdp_pli, na.rm = TRUE
      )
    ) |>
    dplyr::ungroup()

  core_required <- c(
    "arrivals", "origin_iso3", "year_month", "log_gdp_pc_l1y",
    "log_population_l1y", "log_relative_price_gdp_pli"
  )
  twfe <- "origin_iso3 + year_month"
  core_rhs <- paste(
    "log_gdp_pc_l1y + log_population_l1y +",
    "log_relative_price_gdp_pli"
  )
  make_formula <- function(extra = NULL, fixed_effects = twfe) {
    rhs <- paste(c(core_rhs, extra), collapse = " + ")
    stats::as.formula(paste("arrivals ~", rhs, "|", fixed_effects))
  }

  fits <- list()
  fits$baseline_gdp_pli <- fit_fepois_audited(
    "baseline_gdp_pli", make_formula(), data, core_required
  )
  fits$direct_l1 <- fit_fepois_audited(
    "direct_l1", make_formula("direct_l1"), data,
    c(core_required, "direct_l1")
  )
  fits$seats_l1 <- fit_fepois_audited(
    "seats_l1", make_formula("log_seats_l1"), data,
    c(core_required, "log_seats_l1")
  )
  fits$flights_l1 <- fit_fepois_audited(
    "flights_l1", make_formula("log_flights_l1"), data,
    c(core_required, "log_flights_l1")
  )
  fits$seats_ma3_l1 <- fit_fepois_audited(
    "seats_ma3_l1", make_formula("log_seats_ma3_l1"), data,
    c(core_required, "log_seats_ma3_l1")
  )
  fits$connectivity_combined_l1 <- fit_fepois_audited(
    "connectivity_combined_l1",
    make_formula(
      "direct_l1 + log_seats_l1 + log_distw_centered_x_direct_l1"
    ),
    data,
    c(
      core_required, "direct_l1", "log_seats_l1",
      "log_distw_centered_x_direct_l1"
    )
  )

  gravity_required <- c(
    core_required, "origin_region", "log_distw", "contig",
    "common_official_language", "colonial_link",
    "mean_log_gdp_pc_l1y", "mean_log_population_l1y",
    "mean_log_relative_price_gdp_pli"
  )
  gravity_formula <- stats::as.formula(paste(
    "arrivals ~ log_gdp_pc_l1y + log_population_l1y +",
    "log_relative_price_gdp_pli + log_distw + contig +",
    "common_official_language + colonial_link +",
    "mean_log_gdp_pc_l1y + mean_log_population_l1y +",
    "mean_log_relative_price_gdp_pli | origin_region + year_month"
  ))
  fits$gravity_distw_cre <- fit_fepois_audited(
    "gravity_distw_cre", gravity_formula, data, gravity_required,
    family_label = "PPML-CRE"
  )

  bundle <- assemble_model_bundle(fits, "main")
  bundle$sample_summary <- econometric_sample$summary
  bundle$distance_range_km <- range(data$distw_km, na.rm = TRUE)
  bundle
}
