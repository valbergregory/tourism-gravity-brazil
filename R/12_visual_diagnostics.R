tourism_palette <- function() {
  c(
    navy = "#17324D",
    blue = "#2878B5",
    teal = "#12939A",
    green = "#4C956C",
    gold = "#E9B44C",
    coral = "#D95D39",
    red = "#B23A48",
    ink = "#263238",
    grey = "#7A8793",
    light = "#EAF0F4"
  )
}

theme_tourism <- function(base_size = 11, base_family = "sans") {
  palette <- tourism_palette()
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        colour = palette[["navy"]], face = "bold", size = base_size * 1.35,
        margin = ggplot2::margin(b = 5)
      ),
      plot.subtitle = ggplot2::element_text(
        colour = palette[["grey"]], size = base_size,
        margin = ggplot2::margin(b = 12)
      ),
      plot.caption = ggplot2::element_text(
        colour = palette[["grey"]], size = base_size * 0.78,
        hjust = 0, margin = ggplot2::margin(t = 10)
      ),
      axis.title = ggplot2::element_text(colour = palette[["ink"]]),
      axis.text = ggplot2::element_text(colour = palette[["ink"]]),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(
        colour = palette[["light"]], linewidth = 0.35
      ),
      panel.grid.major.x = ggplot2::element_line(
        colour = palette[["light"]], linewidth = 0.35
      ),
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.margin = ggplot2::margin(12, 16, 12, 12)
    )
}

save_tourism_plot <- function(plot, stem, cfg, width, height) {
  figures_dir <- cfg$paths$figures
  fs::dir_create(figures_dir, recurse = TRUE)
  pdf_path <- fs::path(figures_dir, paste0(stem, ".pdf"))
  png_path <- fs::path(figures_dir, paste0(stem, ".png"))
  ggplot2::ggsave(
    pdf_path, plot, width = width, height = height, bg = "white"
  )
  ggplot2::ggsave(
    png_path, plot, width = width, height = height, dpi = 320, bg = "white"
  )
  normalizePath(
    c(pdf_path, png_path), winslash = "/", mustWork = TRUE
  )
}

safe_model_value <- function(code, default = NA_real_) {
  value <- tryCatch(
    as.numeric(force(code)), error = function(error) default
  )
  if (length(value) != 1L || !is.finite(value)) default else value
}

wald_test_terms <- function(model, terms, test_name, model_name, family) {
  coefficients <- stats::coef(model)
  variance <- stats::vcov(model)
  available <- intersect(terms, names(coefficients))
  complete <- length(available) == length(terms) &&
    all(available %in% rownames(variance))
  if (!complete) {
    return(tibble::tibble(
      family = family, model = model_name, test = test_name,
      terms = paste(terms, collapse = "; "), restrictions = length(terms),
      estimate = NA_real_, std_error = NA_real_,
      conf_low = NA_real_, conf_high = NA_real_,
      statistic = NA_real_, df = NA_integer_, p_value = NA_real_,
      decision_5pct = "not_computed",
      note = "One or more requested coefficients were unavailable."
    ))
  }
  beta <- coefficients[terms]
  vcov_sub <- variance[terms, terms, drop = FALSE]
  solution <- tryCatch(
    solve(vcov_sub, beta),
    error = function(error) rep(NA_real_, length(beta))
  )
  statistic <- if (all(is.finite(solution))) {
    as.numeric(t(beta) %*% solution)
  } else {
    NA_real_
  }
  degrees <- length(terms)
  p_value <- if (is.finite(statistic)) {
    stats::pchisq(statistic, df = degrees, lower.tail = FALSE)
  } else {
    NA_real_
  }
  tibble::tibble(
    family = family, model = model_name, test = test_name,
    terms = paste(terms, collapse = "; "), restrictions = degrees,
    estimate = NA_real_, std_error = NA_real_,
    conf_low = NA_real_, conf_high = NA_real_,
    statistic = statistic, df = degrees, p_value = p_value,
    decision_5pct = dplyr::case_when(
      is.na(p_value) ~ "not_computed",
      p_value < 0.05 ~ "reject_joint_null",
      TRUE ~ "do_not_reject_joint_null"
    ),
    note = "Cluster-robust Wald chi-square test using the model covariance."
  )
}

wald_test_linear_combination <- function(model, terms, weights,
                                         test_name, model_name, family) {
  coefficients <- stats::coef(model)
  variance <- stats::vcov(model)
  complete <- length(terms) == length(weights) &&
    all(terms %in% names(coefficients)) &&
    all(terms %in% rownames(variance)) &&
    all(terms %in% colnames(variance))
  if (!complete) {
    return(tibble::tibble(
      family = family, model = model_name, test = test_name,
      terms = paste(terms, collapse = " + "), restrictions = 1L,
      estimate = NA_real_, std_error = NA_real_,
      conf_low = NA_real_, conf_high = NA_real_,
      statistic = NA_real_, df = NA_integer_, p_value = NA_real_,
      decision_5pct = "not_computed",
      note = "The requested linear combination could not be computed."
    ))
  }
  beta <- coefficients[terms]
  vcov_sub <- variance[terms, terms, drop = FALSE]
  estimate <- sum(weights * beta)
  combination_variance <- as.numeric(
    t(weights) %*% vcov_sub %*% weights
  )
  std_error <- if (is.finite(combination_variance) &&
                   combination_variance >= 0) {
    sqrt(combination_variance)
  } else {
    NA_real_
  }
  statistic <- if (is.finite(std_error) && std_error > 0) {
    (estimate / std_error)^2
  } else {
    NA_real_
  }
  p_value <- if (is.finite(statistic)) {
    stats::pchisq(statistic, df = 1L, lower.tail = FALSE)
  } else {
    NA_real_
  }
  critical_value <- stats::qnorm(0.975)
  tibble::tibble(
    family = family, model = model_name, test = test_name,
    terms = paste0(
      weights, " * ", terms, collapse = " + "
    ),
    restrictions = 1L,
    estimate = estimate,
    std_error = std_error,
    conf_low = estimate - critical_value * std_error,
    conf_high = estimate + critical_value * std_error,
    statistic = statistic,
    df = 1L,
    p_value = p_value,
    decision_5pct = dplyr::case_when(
      is.na(p_value) ~ "not_computed",
      p_value < 0.05 ~ "reject_joint_null",
      TRUE ~ "do_not_reject_joint_null"
    ),
    note = paste(
      "Cluster-robust Wald chi-square test of the post-reopening",
      "total slope using the model covariance."
    )
  )
}

build_formal_specification_tests <- function(main_results,
                                             robustness_results) {
  main <- main_results$models
  robust <- robustness_results$models
  tests <- list(
    wald_test_terms(
      main$baseline_gdp_pli,
      c("log_gdp_pc_l1y", "log_population_l1y"),
      "Origin macro controls jointly zero", "baseline_gdp_pli", "main"
    ),
    wald_test_terms(
      main$connectivity_combined_l1,
      c(
        "direct_l1", "log_seats_l1",
        "log_distw_centered_x_direct_l1"
      ),
      "Lagged connectivity block jointly zero",
      "connectivity_combined_l1", "main"
    ),
    wald_test_terms(
      main$gravity_distw_cre,
      c(
        "log_distw", "contig", "common_official_language",
        "colonial_link"
      ),
      "Time-invariant gravity block jointly zero",
      "gravity_distw_cre", "main"
    ),
    wald_test_terms(
      main$gravity_distw_cre,
      c(
        "mean_log_gdp_pc_l1y", "mean_log_population_l1y",
        "mean_log_relative_price_gdp_pli"
      ),
      "Mundlak means jointly zero", "gravity_distw_cre", "main"
    ),
    wald_test_terms(
      robust$air_access_mode,
      c(
        "direct_l1", "log_seats_l1",
        "log_distw_centered_x_direct_l1"
      ),
      "Air-arrival connectivity block jointly zero",
      "air_access_mode", "robustness"
    ),
    wald_test_terms(
      robust$modal_panel,
      c(
        "direct_l1", "log_seats_l1",
        "log_distw_centered_x_direct_l1"
      ),
      "Access-mode connectivity block jointly zero",
      "modal_panel", "robustness"
    )
  )
  if ("price_nonlinearity" %in% names(robust)) {
    tests <- c(tests, list(wald_test_terms(
      robust$price_nonlinearity,
      "log_relative_price_gdp_pli_centered_sq",
      "GDP-PLI price response is locally linear",
      "price_nonlinearity", "robustness"
    )))
  }
  if ("post_reopening_interactions" %in% names(robust)) {
    tests <- c(tests, list(
      wald_test_terms(
        robust$post_reopening_interactions,
        c("price_x_post_reopening", "seats_x_post_reopening"),
        "Price and capacity slopes unchanged after reopening",
        "post_reopening_interactions", "robustness"
      ),
      wald_test_terms(
        robust$post_reopening_interactions,
        "price_x_post_reopening",
        "GDP-PLI price slope unchanged after reopening",
        "post_reopening_interactions", "robustness"
      ),
      wald_test_terms(
        robust$post_reopening_interactions,
        "seats_x_post_reopening",
        "Seat-capacity slope unchanged after reopening",
        "post_reopening_interactions", "robustness"
      ),
      wald_test_linear_combination(
        robust$post_reopening_interactions,
        c("log_relative_price_gdp_pli", "price_x_post_reopening"),
        c(1, 1),
        "Post-reopening GDP-PLI price slope is zero",
        "post_reopening_interactions", "robustness"
      ),
      wald_test_linear_combination(
        robust$post_reopening_interactions,
        c("log_seats_l1", "seats_x_post_reopening"),
        c(1, 1),
        "Post-reopening seat-capacity slope is zero",
        "post_reopening_interactions", "robustness"
      )
    ))
  }
  dplyr::bind_rows(tests)
}

model_fit_diagnostics <- function(main_results, robustness_results) {
  bundles <- list(main = main_results$models,
                  robustness = robustness_results$models)
  purrr::imap_dfr(bundles, function(models, family) {
    purrr::imap_dfr(models, function(model, model_name) {
      fitted <- stats::fitted(model)
      response_residual <- stats::residuals(model, type = "response")
      pearson_residual <- stats::residuals(model, type = "pearson")
      observed <- fitted + response_residual
      residual_df <- safe_model_value(stats::df.residual(model))
      if (!is.finite(residual_df) || residual_df <= 0) {
        residual_df <- max(length(observed) - length(stats::coef(model)), 1)
      }
      tibble::tibble(
        family = family,
        model = model_name,
        observations = length(observed),
        mae = mean(abs(response_residual), na.rm = TRUE),
        rmse = sqrt(mean(response_residual^2, na.rm = TRUE)),
        pearson_dispersion = sum(
          pearson_residual^2, na.rm = TRUE
        ) / residual_df,
        observed_total = sum(observed, na.rm = TRUE),
        predicted_total = sum(fitted, na.rm = TRUE),
        aggregate_prediction_ratio =
          sum(fitted, na.rm = TRUE) / sum(observed, na.rm = TRUE),
        observed_zero_share = mean(observed == 0, na.rm = TRUE),
        poisson_expected_zero_share = mean(exp(-fitted), na.rm = TRUE)
      )
    })
  })
}

model_calibration_data <- function(model, bins = 10L) {
  fitted <- stats::fitted(model)
  observed <- fitted + stats::residuals(model, type = "response")
  tibble::tibble(observed = observed, predicted = fitted) |>
    dplyr::mutate(bin = dplyr::ntile(.data$predicted, bins)) |>
    dplyr::group_by(.data$bin) |>
    dplyr::summarise(
      rows = dplyr::n(),
      observed_mean = mean(.data$observed, na.rm = TRUE),
      predicted_mean = mean(.data$predicted, na.rm = TRUE),
      observed_total = sum(.data$observed, na.rm = TRUE),
      predicted_total = sum(.data$predicted, na.rm = TRUE),
      prediction_ratio = .data$predicted_total / .data$observed_total,
      .groups = "drop"
    )
}

run_origin_leave_one_out <- function(econometric_sample, main_results) {
  data <- complete_spec_data(
    econometric_sample$data,
    c(
      "arrivals", "origin_iso3", "year_month", "log_gdp_pc_l1y",
      "log_population_l1y", "log_relative_price_gdp_pli"
    )
  )
  if (!"origin_country" %in% names(data)) {
    data$origin_country <- countrycode::countrycode(
      data$origin_iso3, "iso3c", "country.name.en"
    )
  }
  baseline <- main_results$models$baseline_gdp_pli
  baseline_tidy <- broom::tidy(baseline, conf.int = TRUE) |>
    dplyr::filter(.data$term == "log_relative_price_gdp_pli")
  full_estimate <- baseline_tidy$estimate[[1L]]
  origin_totals <- data |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      origin_country = dplyr::first(
        stats::na.omit(.data$origin_country), default = NA_character_
      ),
      excluded_arrivals = sum(.data$arrivals, na.rm = TRUE),
      .groups = "drop"
    )
  formula <- stats::as.formula(paste(
    "arrivals ~ log_gdp_pc_l1y + log_population_l1y +",
    "log_relative_price_gdp_pli | origin_iso3 + year_month"
  ))
  purrr::map_dfr(origin_totals$origin_iso3, function(excluded_origin) {
    fitted <- tryCatch(
      fixest::fepois(
        formula,
        data = dplyr::filter(data, .data$origin_iso3 != excluded_origin),
        vcov = ~origin_iso3,
        notes = FALSE,
        warn = FALSE
      ),
      error = function(error) error
    )
    metadata <- dplyr::filter(
      origin_totals, .data$origin_iso3 == excluded_origin
    )
    if (inherits(fitted, "error")) {
      return(tibble::tibble(
        excluded_origin = excluded_origin,
        origin_country = metadata$origin_country[[1L]],
        excluded_arrivals = metadata$excluded_arrivals[[1L]],
        estimate = NA_real_, std_error = NA_real_, conf_low = NA_real_,
        conf_high = NA_real_, full_estimate = full_estimate,
        change_from_full = NA_real_, relative_change_percent = NA_real_,
        converged = FALSE, error = conditionMessage(fitted)
      ))
    }
    result <- broom::tidy(fitted, conf.int = TRUE) |>
      dplyr::filter(.data$term == "log_relative_price_gdp_pli")
    estimate <- result$estimate[[1L]]
    tibble::tibble(
      excluded_origin = excluded_origin,
      origin_country = metadata$origin_country[[1L]],
      excluded_arrivals = metadata$excluded_arrivals[[1L]],
      estimate = estimate,
      std_error = result$std.error[[1L]],
      conf_low = result$conf.low[[1L]],
      conf_high = result$conf.high[[1L]],
      full_estimate = full_estimate,
      change_from_full = estimate - full_estimate,
      relative_change_percent = 100 *
        (estimate - full_estimate) / abs(full_estimate),
      converged = isTRUE(fitted$convStatus) || is.null(fitted$convStatus),
      error = ""
    )
  }) |>
    dplyr::arrange(dplyr::desc(abs(.data$change_from_full)))
}

descriptive_statistics_table <- function(data) {
  variables <- c(
    arrivals = "Monthly arrivals",
    log_relative_price_gdp_pli = "GDP-PLI relative price (log)",
    log_gdp_pc_l1y = "Origin GDP per capita (log, t-1 year)",
    log_population_l1y = "Origin population (log, t-1 year)",
    log_seats_l1 = "Seats (log1p, t-1)",
    log_flights_l1 = "Flights (log1p, t-1)",
    distw_km = "Population-weighted distance (km)"
  )
  purrr::imap_dfr(variables, function(label, variable) {
    value <- data[[variable]]
    value <- value[is.finite(value)]
    tibble::tibble(
      variable = label,
      observations = length(value),
      mean = mean(value),
      std_dev = stats::sd(value),
      p25 = unname(stats::quantile(value, 0.25)),
      median = stats::median(value),
      p75 = unname(stats::quantile(value, 0.75)),
      minimum = min(value),
      maximum = max(value)
    )
  })
}

economic_magnitudes_table <- function(main_results) {
  models <- main_results$models
  specifications <- tibble::tribble(
    ~model, ~term, ~quantity, ~shock,
    "baseline_gdp_pli", "log_relative_price_gdp_pli",
    "GDP-PLI relative price", "10% increase",
    "seats_l1", "log_seats_l1", "Lagged seats", "10% increase",
    "flights_l1", "log_flights_l1", "Lagged flights", "10% increase",
    "seats_ma3_l1", "log_seats_ma3_l1",
    "Prior three-month mean seats", "10% increase",
    "gravity_distw_cre", "log_distw",
    "Population-weighted distance", "10% increase"
  )
  estimates <- purrr::imap_dfr(models, function(model, model_name) {
    broom::tidy(model, conf.int = TRUE) |>
      dplyr::mutate(model = model_name, .before = 1L)
  })
  specifications |>
    dplyr::left_join(estimates, by = c("model", "term")) |>
    dplyr::transmute(
      quantity = .data$quantity,
      model = .data$model,
      shock = .data$shock,
      coefficient = .data$estimate,
      std_error = .data$std.error,
      p_value = .data$p.value,
      implied_percent_change = 100 * (1.1^.data$estimate - 1),
      conf_low_percent = 100 * (1.1^.data$conf.low - 1),
      conf_high_percent = 100 * (1.1^.data$conf.high - 1)
    )
}

styled_gt_table <- function(data, title, subtitle = NULL,
                            numeric_columns = character(), decimals = 3L) {
  palette <- tourism_palette()
  table <- gt::gt(data) |>
    gt::tab_header(title = title, subtitle = subtitle) |>
    gt::opt_row_striping() |>
    gt::tab_style(
      style = gt::cell_text(color = "white"),
      locations = gt::cells_title(groups = c("title", "subtitle"))
    ) |>
    gt::tab_options(
      heading.background.color = palette[["navy"]],
      heading.title.font.size = gt::px(18),
      heading.subtitle.font.size = gt::px(12),
      table.font.names = c("Arial", "Helvetica", "sans-serif"),
      column_labels.background.color = palette[["light"]],
      column_labels.font.weight = "bold",
      table.border.top.color = palette[["navy"]],
      table.border.bottom.color = palette[["navy"]],
      data_row.padding = gt::px(5)
    )
  if (length(numeric_columns) > 0L) {
    table <- gt::fmt_number(
      table,
      columns = tidyselect::any_of(numeric_columns),
      decimals = decimals
    )
  }
  table
}

save_diagnostic_table <- function(data, stem, title, subtitle, cfg,
                                  numeric_columns = character(),
                                  decimals = 3L) {
  tables_dir <- cfg$paths$tables
  fs::dir_create(tables_dir, recurse = TRUE)
  csv_path <- write_csv_safe(data, fs::path(tables_dir, paste0(stem, ".csv")))
  table <- styled_gt_table(
    data, title, subtitle, numeric_columns, decimals
  )
  html_path <- fs::path(tables_dir, paste0(stem, ".html"))
  tex_path <- fs::path(tables_dir, paste0(stem, ".tex"))
  gt::gtsave(table, html_path)
  writeLines(
    as.character(gt::as_latex(table)), tex_path, useBytes = TRUE
  )
  normalizePath(
    c(csv_path, html_path, tex_path), winslash = "/", mustWork = TRUE
  )
}

save_publication_model_table <- function(models, stem, title, subtitle, cfg,
                                         coefficient_map, notes) {
  tables_dir <- cfg$paths$tables
  fs::dir_create(tables_dir, recurse = TRUE)
  table <- modelsummary::modelsummary(
    models,
    output = "gt",
    coef_rename = coefficient_map,
    estimate = "{estimate}{stars}",
    statistic = "({std.error})",
    gof_omit = "IC|Log|RMSE|Std.Errors|FE",
    notes = notes,
    escape = FALSE
  ) |>
    gt::tab_header(title = title, subtitle = subtitle) |>
    gt::opt_row_striping() |>
    gt::tab_style(
      style = gt::cell_text(color = "white"),
      locations = gt::cells_title(groups = c("title", "subtitle"))
    ) |>
    gt::tab_options(
      heading.background.color = tourism_palette()[["navy"]],
      table.font.names = c("Arial", "Helvetica", "sans-serif"),
      column_labels.background.color = tourism_palette()[["light"]],
      column_labels.font.weight = "bold",
      data_row.padding = gt::px(4)
    )
  html_path <- fs::path(tables_dir, paste0(stem, ".html"))
  tex_path <- fs::path(tables_dir, paste0(stem, ".tex"))
  gt::gtsave(table, html_path)
  writeLines(as.character(gt::as_latex(table)), tex_path, useBytes = TRUE)
  normalizePath(
    c(html_path, tex_path), winslash = "/", mustWork = TRUE
  )
}

export_extended_diagnostics <- function(econometric_sample, main_results,
                                        robustness_results,
                                        origin_influence,
                                        model_audit_files, cfg) {
  if (length(model_audit_files) == 0L ||
      any(!file.exists(model_audit_files))) {
    stop("Model audit files are missing; diagnostics will not proceed.")
  }
  if (!requireNamespace("ggdist", quietly = TRUE) ||
      !requireNamespace("gt", quietly = TRUE)) {
    stop(
      "Install the visual packages first: ggdist, gt and patchwork. ",
      "Use Rscript scripts/00_instalar_pacotes_visuais.R in the Terminal."
    )
  }
  data <- econometric_sample$data
  if (!"origin_country" %in% names(data)) {
    data$origin_country <- countrycode::countrycode(
      data$origin_iso3, "iso3c", "country.name.en"
    )
  }
  palette <- tourism_palette()

  formal_tests <- build_formal_specification_tests(
    main_results, robustness_results
  )
  fit_diagnostics <- model_fit_diagnostics(
    main_results, robustness_results
  )
  calibration <- model_calibration_data(
    main_results$models$connectivity_combined_l1
  )
  descriptives <- descriptive_statistics_table(data)
  magnitudes <- economic_magnitudes_table(main_results)

  origin_summary <- data |>
    dplyr::group_by(
      .data$origin_iso3, .data$origin_country, .data$origin_region
    ) |>
    dplyr::summarise(
      total_arrivals = sum(.data$arrivals, na.rm = TRUE),
      mean_arrivals = mean(.data$arrivals, na.rm = TRUE),
      zero_share = mean(.data$arrivals == 0, na.rm = TRUE),
      distw_km = dplyr::first(.data$distw_km),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$total_arrivals)) |>
    dplyr::mutate(
      market_share = .data$total_arrivals / sum(.data$total_arrivals),
      cumulative_share = cumsum(.data$market_share),
      rank = dplyr::row_number()
    )

  table_files <- c(
    save_publication_model_table(
      main_results$models[c(
        "baseline_gdp_pli", "seats_l1", "flights_l1",
        "connectivity_combined_l1"
      )],
      "publication_main_models",
      "Main PPML estimates",
      "Price competitiveness and lagged air connectivity",
      cfg, tourism_coefficient_map(),
      c(
        "Origin and month-year fixed effects; standard errors clustered by origin.",
        "GDP-PLI is the principal price measure."
      )
    ),
    save_publication_model_table(
      robustness_results$models[c(
        "pre_covid", "exclude_pandemic", "balanced_core_2000",
        "exclude_argentina", "exclude_top_markets",
        "baseline_two_way_cluster"
      )],
      "publication_robustness_models",
      "Selected robustness checks",
      "Periods, sample composition and inference",
      cfg, tourism_coefficient_map(),
      c(
        "PPML estimates; the principal inference clusters by origin.",
        "The two-way column clusters by origin and month-year."
      )
    ),
    save_diagnostic_table(
      descriptives, "descriptive_statistics",
      "Descriptive statistics", "Frozen GDP-PLI–distw sample",
      cfg,
      setdiff(names(descriptives), "variable"), 3L
    ),
    save_diagnostic_table(
      formal_tests, "formal_specification_tests",
      "Formal specification tests",
      "Cluster-robust Wald tests; the null hypothesis is stated in each row",
      cfg,
      c(
        "estimate", "std_error", "conf_low", "conf_high",
        "statistic", "p_value"
      ), 4L
    ),
    save_diagnostic_table(
      fit_diagnostics, "model_fit_diagnostics",
      "Model fit diagnostics",
      "PPML residual dispersion and aggregate calibration",
      cfg,
      c(
        "mae", "rmse", "pearson_dispersion",
        "aggregate_prediction_ratio",
        "observed_zero_share", "poisson_expected_zero_share"
      ), 3L
    ),
    save_diagnostic_table(
      magnitudes, "economic_magnitudes",
      "Economic magnitudes", "Exact response implied by a 10% change",
      cfg,
      c(
        "coefficient", "std_error", "p_value",
        "implied_percent_change", "conf_low_percent",
        "conf_high_percent"
      ), 3L
    ),
    save_diagnostic_table(
      dplyr::slice_head(origin_summary, n = 20L),
      "market_concentration_top20",
      "Largest origin markets",
      "Total arrivals and cumulative share in the frozen sample",
      cfg,
      c(
        "total_arrivals", "mean_arrivals", "zero_share", "distw_km",
        "market_share", "cumulative_share"
      ), 3L
    ),
    save_diagnostic_table(
      origin_influence, "origin_leave_one_out_influence",
      "Leave-one-origin-out influence",
      "Sensitivity of the GDP-PLI price elasticity to each origin",
      cfg,
      c(
        "excluded_arrivals", "estimate", "std_error", "conf_low",
        "conf_high", "full_estimate", "change_from_full",
        "relative_change_percent"
      ), 3L
    ),
    write_csv_safe(
      calibration,
      fs::path(cfg$paths$tables, "combined_model_calibration.csv")
    )
  )

  monthly <- data |>
    dplyr::group_by(.data$date) |>
    dplyr::summarise(
      arrivals = sum(.data$arrivals, na.rm = TRUE), .groups = "drop"
    ) |>
    dplyr::arrange(.data$date) |>
    dplyr::mutate(
      rolling_12m = zoo::rollmean(
        .data$arrivals, 12L, fill = NA_real_, align = "right"
      )
    )
  arrivals_plot <- ggplot2::ggplot(monthly, ggplot2::aes(.data$date)) +
    ggplot2::annotate(
      "rect", xmin = as.Date(cfg$project$covid_start),
      xmax = as.Date(cfg$project$covid_end), ymin = -Inf, ymax = Inf,
      fill = palette[["coral"]], alpha = 0.10
    ) +
    ggplot2::geom_line(
      ggplot2::aes(y = .data$arrivals),
      colour = palette[["blue"]], linewidth = 0.35, alpha = 0.45
    ) +
    ggplot2::geom_line(
      ggplot2::aes(y = .data$rolling_12m),
      colour = palette[["navy"]], linewidth = 1.0
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::label_number(scale = 1e-6, suffix = "M")
    ) +
    ggplot2::labs(
      x = NULL, y = "International arrivals",
      title = "International tourism demand for Brazil",
      subtitle = "Monthly flows and trailing 12-month average, 2000–2025",
      caption = "Shaded interval: March 2020–December 2021. Source: MTur; authors’ calculations."
    ) +
    theme_tourism(11)

  top_origins <- dplyr::slice_head(origin_summary, n = 15L) |>
    dplyr::mutate(
      origin_label = dplyr::if_else(
        is.na(.data$origin_country) | !nzchar(.data$origin_country),
        .data$origin_iso3, .data$origin_country
      ),
      origin_label = stats::reorder(
        .data$origin_label, .data$total_arrivals
      )
    )
  concentration_plot <- ggplot2::ggplot(
    top_origins,
    ggplot2::aes(x = .data$total_arrivals, y = .data$origin_label)
  ) +
    ggplot2::geom_segment(
      ggplot2::aes(x = 0, xend = .data$total_arrivals, yend = .data$origin_label),
      colour = palette[["light"]], linewidth = 2.4
    ) +
    ggplot2::geom_point(
      ggplot2::aes(colour = .data$market_share), size = 3.6
    ) +
    ggplot2::geom_text(
      ggplot2::aes(
        label = scales::percent(.data$market_share, accuracy = 0.1)
      ),
      hjust = -0.18, size = 3.1, colour = palette[["ink"]]
    ) +
    ggplot2::scale_colour_viridis_c(option = "C", end = 0.82) +
    ggplot2::scale_x_continuous(
      labels = scales::label_number(scale = 1e-6, suffix = "M"),
      expand = ggplot2::expansion(mult = c(0, 0.16))
    ) +
    ggplot2::labs(
      x = "Total arrivals", y = NULL,
      title = "Concentration of international arrivals",
      subtitle = "Fifteen largest origin markets; labels show sample shares",
      caption = "Frozen GDP-PLI–distw sample. Source: MTur; authors’ calculations."
    ) +
    theme_tourism(11) +
    ggplot2::theme(legend.position = "none")

  annual_price <- data |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(
      p25 = stats::quantile(
        .data$log_relative_price_gdp_pli, 0.25, na.rm = TRUE
      ),
      median = stats::median(
        .data$log_relative_price_gdp_pli, na.rm = TRUE
      ),
      p75 = stats::quantile(
        .data$log_relative_price_gdp_pli, 0.75, na.rm = TRUE
      ),
      .groups = "drop"
    )
  price_trend_plot <- ggplot2::ggplot(
    annual_price, ggplot2::aes(.data$year, .data$median)
  ) +
    ggplot2::geom_hline(
      yintercept = 0, colour = palette[["grey"]], linetype = 3
    ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$p25, ymax = .data$p75),
      fill = palette[["teal"]], alpha = 0.16
    ) +
    ggplot2::geom_line(colour = palette[["teal"]], linewidth = 1.0) +
    ggplot2::geom_point(colour = palette[["navy"]], size = 1.8) +
    ggplot2::labs(
      x = NULL, y = "Log relative GDP price level",
      title = "Brazil’s relative price competitiveness",
      subtitle = "Annual median and interquartile range across origin markets",
      caption = "Values above zero indicate a higher Brazilian GDP price level relative to the origin."
    ) +
    theme_tourism(11)

  scatter_data <- origin_summary
  scatter_labels <- scatter_data |>
    dplyr::filter(.data$rank <= 8L) |>
    dplyr::mutate(
      label_y = .data$total_arrivals * dplyr::case_when(
        .data$origin_iso3 == "DEU" ~ 1.40,
        .data$origin_iso3 == "FRA" ~ 1.02,
        .data$origin_iso3 == "ITA" ~ 0.72,
        TRUE ~ 1.12
      )
    )
  distance_plot <- ggplot2::ggplot(
    scatter_data,
    ggplot2::aes(
      x = .data$distw_km, y = .data$total_arrivals,
      colour = .data$origin_region
    )
  ) +
    ggplot2::geom_point(alpha = 0.78, size = 2.6) +
    ggplot2::geom_text(
      data = scatter_labels,
      ggplot2::aes(
        x = .data$distw_km, y = .data$label_y,
        label = .data$origin_iso3
      ),
      inherit.aes = FALSE, size = 3, colour = palette[["ink"]]
    ) +
    ggplot2::scale_x_log10(
      labels = scales::label_number(big.mark = ",", suffix = " km")
    ) +
    ggplot2::scale_y_log10(
      labels = scales::label_number(
        scale_cut = scales::cut_short_scale(), accuracy = 1
      )
    ) +
    ggplot2::scale_colour_viridis_d(option = "D", end = 0.88) +
    ggplot2::labs(
      x = "Population-weighted distance (log scale)",
      y = "Total arrivals (log scale)",
      title = "Distance and cumulative tourism demand",
      subtitle = "Each point is an origin market; labels identify the eight largest",
      caption = "Descriptive relationship; the PPML-CRE model provides the conditional gravity estimate."
    ) +
    theme_tourism(11)

  calibration_plot <- ggplot2::ggplot(
    calibration,
    ggplot2::aes(.data$predicted_mean, .data$observed_mean)
  ) +
    ggplot2::geom_abline(
      slope = 1, intercept = 0, linetype = 3,
      colour = palette[["grey"]]
    ) +
    ggplot2::geom_path(colour = palette[["teal"]], linewidth = 0.7) +
    ggplot2::geom_point(
      ggplot2::aes(size = .data$rows, colour = .data$bin), alpha = 0.9
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$bin), nudge_y = 0.06,
      size = 3, colour = palette[["ink"]]
    ) +
    ggplot2::scale_x_log10(labels = scales::label_number()) +
    ggplot2::scale_y_log10(labels = scales::label_number()) +
    ggplot2::scale_colour_viridis_c(option = "C") +
    ggplot2::labs(
      x = "Mean predicted arrivals (log scale)",
      y = "Mean observed arrivals (log scale)",
      title = "Calibration of the combined PPML model",
      subtitle = "Observed versus predicted arrivals across prediction deciles",
      caption = "The dashed 45-degree line represents exact calibration."
    ) +
    theme_tourism(11) +
    ggplot2::theme(legend.position = "none")

  influential <- origin_influence |>
    dplyr::filter(is.finite(.data$estimate)) |>
    dplyr::slice_max(
      abs(.data$change_from_full), n = 20L, with_ties = FALSE
    ) |>
    dplyr::mutate(
      origin_label = dplyr::if_else(
        is.na(.data$origin_country) | !nzchar(.data$origin_country),
        .data$excluded_origin,
        paste0(.data$origin_country, " (", .data$excluded_origin, ")")
      ),
      origin_label = stats::reorder(
        .data$origin_label, .data$estimate
      )
    )
  influence_plot <- ggplot2::ggplot(
    influential,
    ggplot2::aes(
      x = .data$estimate, y = .data$origin_label,
      xmin = .data$conf_low, xmax = .data$conf_high
    )
  ) +
    ggplot2::geom_vline(
      xintercept = unique(influential$full_estimate),
      colour = palette[["coral"]], linetype = 2, linewidth = 0.7
    ) +
    ggdist::geom_pointinterval(
      colour = palette[["navy"]], point_size = 1.8, interval_size = 0.7
    ) +
    ggplot2::labs(
      x = "GDP-PLI price elasticity after excluding one origin",
      y = NULL,
      title = "Which origins influence the price estimate?",
      subtitle = "Twenty largest leave-one-origin-out changes; intervals use clustered standard errors",
      caption = "The dashed coral line is the full-sample estimate."
    ) +
    theme_tourism(10.5)

  top_zero_origins <- origin_summary |>
    dplyr::arrange(
      dplyr::desc(.data$zero_share),
      dplyr::desc(.data$total_arrivals)
    ) |>
    dplyr::slice_head(n = 20L) |>
    dplyr::pull("origin_iso3")
  zero_heatmap_data <- data |>
    dplyr::filter(.data$origin_iso3 %in% top_zero_origins) |>
    dplyr::group_by(.data$origin_iso3, .data$year) |>
    dplyr::summarise(
      zero_share = mean(.data$arrivals == 0), .groups = "drop"
    ) |>
    dplyr::mutate(
      origin_iso3 = factor(
        .data$origin_iso3, levels = rev(top_zero_origins)
      )
    )
  zero_heatmap <- ggplot2::ggplot(
    zero_heatmap_data,
    ggplot2::aes(.data$year, .data$origin_iso3, fill = .data$zero_share)
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.08) +
    ggplot2::scale_fill_viridis_c(
      option = "C", labels = scales::label_percent(accuracy = 1),
      limits = c(0, 1)
    ) +
    ggplot2::labs(
      x = NULL, y = NULL, fill = "Zero-flow share",
      title = "Origin markets with the highest zero-flow incidence",
      subtitle = "Annual zero share for the twenty most zero-prone markets",
      caption = "Zeros are retained by PPML; white grid lines separate origin-years."
    ) +
    theme_tourism(10.5) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(), legend.position = "right"
    )

  plot_files <- c(
    save_tourism_plot(arrivals_plot, "tourism_demand_timeline", cfg, 9, 5),
    save_tourism_plot(
      concentration_plot, "market_concentration_top15", cfg, 8.5, 6.2
    ),
    save_tourism_plot(
      price_trend_plot, "relative_price_trend", cfg, 8.5, 5
    ),
    save_tourism_plot(
      distance_plot, "distance_arrivals_scatter", cfg, 8.5, 5.5
    ),
    save_tourism_plot(
      calibration_plot, "combined_model_calibration", cfg, 7.2, 5.5
    ),
    save_tourism_plot(
      influence_plot, "origin_leave_one_out_influence", cfg, 8.5, 7
    ),
    save_tourism_plot(
      zero_heatmap, "zero_flow_heatmap_top20", cfg, 9, 6.2
    )
  )

  overleaf_tables <- fs::path("..", "overleaf", "tables")
  overleaf_figures <- fs::path("..", "overleaf", "figures")
  if (fs::dir_exists(overleaf_tables)) {
    purrr::walk(
      table_files[stringr::str_detect(table_files, "\\.tex$")],
      ~fs::file_copy(
        .x, fs::path(overleaf_tables, fs::path_file(.x)), overwrite = TRUE
      )
    )
  }
  if (fs::dir_exists(overleaf_figures)) {
    purrr::walk(
      plot_files,
      ~fs::file_copy(
        .x, fs::path(overleaf_figures, fs::path_file(.x)), overwrite = TRUE
      )
    )
  }

  normalizePath(
    c(table_files, plot_files), winslash = "/", mustWork = TRUE
  )
}
