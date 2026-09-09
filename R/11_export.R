tidy_model_bundle <- function(bundle, conf_level = 0.95) {
  purrr::imap_dfr(bundle$models, function(model, model_name) {
    broom::tidy(model, conf.int = TRUE, conf.level = conf_level) |>
      dplyr::mutate(model = model_name, family = bundle$family, .before = 1L)
  })
}

residual_diagnostics <- function(bundle) {
  purrr::imap_dfr(bundle$models, function(model, model_name) {
    residual <- stats::residuals(model)
    fitted <- stats::fitted(model)
    tibble::tibble(
      family = bundle$family,
      model = model_name,
      residual_mean = mean(residual, na.rm = TRUE),
      residual_sd = stats::sd(residual, na.rm = TRUE),
      residual_p01 = unname(stats::quantile(
        residual, 0.01, na.rm = TRUE
      )),
      residual_p50 = unname(stats::quantile(
        residual, 0.50, na.rm = TRUE
      )),
      residual_p99 = unname(stats::quantile(
        residual, 0.99, na.rm = TRUE
      )),
      fitted_min = min(fitted, na.rm = TRUE),
      fitted_median = stats::median(fitted, na.rm = TRUE),
      fitted_max = max(fitted, na.rm = TRUE),
      non_finite_residuals = sum(!is.finite(residual)),
      non_finite_fitted = sum(!is.finite(fitted))
    )
  })
}

audit_model_results <- function(main_results, robustness_results, cfg) {
  audit_dir <- cfg$paths$audit %||% "output/audit"
  fs::dir_create(audit_dir, recurse = TRUE)

  estimation_audit <- dplyr::bind_rows(
    dplyr::mutate(main_results$audit, family = "main", .before = 1L),
    dplyr::mutate(
      robustness_results$audit, family = "robustness", .before = 1L
    )
  ) |>
    dplyr::mutate(
      convergence_flag = dplyr::case_when(
        is.na(.data$converged) ~ "not_reported",
        .data$converged ~ "converged",
        TRUE ~ "failed"
      ),
      removal_share = dplyr::if_else(
        .data$input_rows > 0,
        .data$removed_rows / .data$input_rows,
        NA_real_
      ),
      collinearity_flag = nzchar(.data$collinear_variables),
      warning_flag = nzchar(.data$warnings)
    )

  coefficients <- dplyr::bind_rows(
    tidy_model_bundle(main_results),
    tidy_model_bundle(robustness_results)
  ) |>
    dplyr::mutate(
      finite_estimate = is.finite(.data$estimate),
      finite_std_error = is.finite(.data$std.error),
      confidence_interval_contains_zero =
        .data$conf.low <= 0 & .data$conf.high >= 0
    )

  residuals <- dplyr::bind_rows(
    residual_diagnostics(main_results),
    residual_diagnostics(robustness_results)
  )

  dominant <- tibble::tibble(
    rank = seq_along(robustness_results$dominant_origins_excluded),
    origin_iso3 = robustness_results$dominant_origins_excluded
  )

  audit_path <- write_csv_safe(
    estimation_audit,
    fs::path(audit_dir, "model_estimation_audit.csv")
  )
  coefficient_path <- write_csv_safe(
    coefficients,
    fs::path(audit_dir, "model_coefficient_audit.csv")
  )
  residual_path <- write_csv_safe(
    residuals,
    fs::path(audit_dir, "model_residual_diagnostics.csv")
  )
  sample_count_path <- write_csv_safe(
    robustness_results$sample_counts,
    fs::path(audit_dir, "robustness_sample_counts.csv")
  )
  dominant_path <- write_csv_safe(
    dominant,
    fs::path(audit_dir, "dominant_markets_excluded.csv")
  )

  normalizePath(
    c(
      audit_path, coefficient_path, residual_path, sample_count_path,
      dominant_path
    ),
    winslash = "/", mustWork = TRUE
  )
}

tourism_coefficient_map <- function() {
  c(
    log_gdp_pc_l1y = "Origin GDP per capita (log, t-1 year)",
    log_population_l1y = "Origin population (log, t-1 year)",
    log_relative_price_gdp_pli = "Brazil relative GDP price level (log)",
    log_relative_price_cpi = "Brazil relative CPI price (log)",
    log_relative_price_pli = "Brazil relative household price level (log)",
    log_distw = "Population-weighted distance (log)",
    log_distcap = "Capital distance (log)",
    log_dist = "Simple bilateral distance (log)",
    contig = "Shared border",
    common_official_language = "Common official language",
    colonial_link = "Colonial link",
    direct_l1 = "Direct service (t-1)",
    log_seats_l1 = "Seats (log1p, t-1)",
    log_flights_l1 = "Flights (log1p, t-1)",
    log_seats_ma3_l1 = "Seats (log1p, prior 3-month mean)",
    log_distw_centered_x_direct_l1 =
      "Centered distance × direct service (t-1)",
    direct = "Direct service (contemporaneous)",
    log_seats = "Seats (log1p, contemporaneous)",
    log_distw_centered_x_direct =
      "Centered distance × direct service (contemporaneous)",
    mean_log_gdp_pc_l1y = "Mean origin GDP per capita (Mundlak)",
    mean_log_population_l1y = "Mean origin population (Mundlak)",
    mean_log_relative_price_gdp_pli =
      "Mean relative GDP price level (Mundlak)",
    mean_price = "Mean relative price (Mundlak)",
    log_relative_price_gdp_pli_centered =
      "GDP-PLI price centered at its sample mean",
    log_relative_price_gdp_pli_centered_sq =
      "Squared centered GDP-PLI price",
    price_x_post_reopening = "GDP-PLI price × post-reopening",
    seats_x_post_reopening = "Seats (t-1) × post-reopening"
  )
}

write_model_table <- function(models, path, coef_map, notes) {
  modelsummary::modelsummary(
    models,
    output = path,
    coef_rename = coef_map,
    stars = TRUE,
    gof_omit = "IC|Log|RMSE|Std.Errors|FE",
    notes = notes,
    escape = FALSE
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

direct_service_marginal_effects <- function(
    model, model_name, family, distances_km, reference_km,
    direct_term = "direct_l1",
    interaction_term = "log_distw_centered_x_direct_l1") {
  coefficients <- stats::coef(model)
  variance <- stats::vcov(model)
  required_terms <- c(direct_term, interaction_term)
  if (!all(required_terms %in% names(coefficients)) ||
      !all(required_terms %in% rownames(variance))) {
    return(tibble::tibble())
  }
  purrr::map_dfr(distances_km, function(distance_km) {
    centered_distance <- log(distance_km / reference_km)
    weights <- c(1, centered_distance)
    names(weights) <- required_terms
    estimate <- sum(weights * coefficients[required_terms])
    variance_submatrix <- variance[required_terms, required_terms, drop = FALSE]
    standard_error <- sqrt(as.numeric(
      t(weights) %*% variance_submatrix %*% weights
    ))
    conf_low <- estimate - stats::qnorm(0.975) * standard_error
    conf_high <- estimate + stats::qnorm(0.975) * standard_error
    tibble::tibble(
      family = family,
      model = model_name,
      distance_km = distance_km,
      reference_km = reference_km,
      estimate_log_rate = estimate,
      std_error = standard_error,
      conf_low_log_rate = conf_low,
      conf_high_log_rate = conf_high,
      percent_effect = 100 * (exp(estimate) - 1),
      conf_low_percent = 100 * (exp(conf_low) - 1),
      conf_high_percent = 100 * (exp(conf_high) - 1)
    )
  })
}

export_model_outputs <- function(main_results, robustness_results,
                                 model_audit_files, cfg) {
  if (length(model_audit_files) == 0L ||
      any(!file.exists(model_audit_files))) {
    stop("Model audit files are missing; export will not proceed.")
  }
  if (!requireNamespace("ggdist", quietly = TRUE)) {
    stop(
      "Package ggdist is required for publication figures. Run ",
      "Rscript scripts/00_instalar_pacotes_visuais.R in the Terminal."
    )
  }
  tables_dir <- cfg$paths$tables
  figures_dir <- cfg$paths$figures
  fs::dir_create(c(tables_dir, figures_dir), recurse = TRUE)

  coef_map <- tourism_coefficient_map()
  interaction_reference_km <- as.numeric(
    cfg$econometrics$interaction_reference_km %||% 5000
  )
  marginal_effect_distances_km <- as.numeric(unlist(
    cfg$econometrics$marginal_effect_distances_km %||%
      c(1500, 5000, 10000),
    use.names = FALSE
  ))
  main_notes <- c(
    "PPML estimates. GDP-PLI is the principal price measure and distw is the principal distance measure.",
    "All TWFE specifications include origin and month-year fixed effects; standard errors are clustered by origin.",
    "Connectivity is lagged. The PPML-CRE gravity column uses region and month-year fixed effects plus Mundlak means.",
    paste0(
      "In interacted specifications, the direct-service coefficient is evaluated at ",
      format(interaction_reference_km, big.mark = ",", scientific = FALSE),
      " km."
    ),
    "Time-invariant distance is not entered with origin fixed effects because it would be absorbed."
  )
  robust_notes <- c(
    "PPML robustness estimates. CPI, household PLI, alternative distances and contemporaneous connectivity are not principal specifications.",
    "The pandemic window is March 2020 through December 2021.",
    paste0(
      "Distance is centered at ",
      format(interaction_reference_km, big.mark = ",", scientific = FALSE),
      " km in direct-service interactions."
    ),
    "Unless explicitly labeled otherwise, standard errors are clustered by origin."
  )

  main_tex <- write_model_table(
    main_results$models,
    fs::path(tables_dir, "main_models.tex"),
    coef_map,
    main_notes
  )
  main_html <- write_model_table(
    main_results$models,
    fs::path(tables_dir, "main_models.html"),
    coef_map,
    main_notes
  )

  robustness_periods <- robustness_results$models[c(
    "pre_covid", "post_reopening", "exclude_pandemic",
    "balanced_core_2000", "exclude_argentina", "exclude_top_markets"
  )]
  robust_tex <- write_model_table(
    robustness_periods,
    fs::path(tables_dir, "robustness_models.tex"),
    coef_map,
    robust_notes
  )
  robust_html <- write_model_table(
    robustness_results$models,
    fs::path(tables_dir, "robustness_models.html"),
    coef_map,
    robust_notes
  )

  price_connectivity_tex <- write_model_table(
    robustness_results$models[c(
      "cpi_price", "household_pli_price",
      "contemporaneous_connectivity"
    )],
    fs::path(tables_dir, "robustness_prices_connectivity.tex"),
    coef_map,
    robust_notes
  )
  frequency_modes_tex <- write_model_table(
    robustness_results$models[c(
      "quarterly", "air_access_mode", "modal_panel"
    )],
    fs::path(tables_dir, "robustness_frequency_modes.tex"),
    coef_map,
    robust_notes
  )

  functional_form_models <- robustness_results$models[intersect(
    c("price_nonlinearity", "post_reopening_interactions"),
    names(robustness_results$models)
  )]
  functional_form_tex <- write_model_table(
    functional_form_models,
    fs::path(tables_dir, "functional_form_and_regime_tests.tex"),
    coef_map,
    c(
      "The nonlinear-price column centers GDP-PLI before squaring it.",
      "The regime column excludes March 2020–December 2021 and tests slope changes after reopening.",
      "Month-year fixed effects absorb the standalone post-reopening indicator."
    )
  )
  functional_form_html <- write_model_table(
    functional_form_models,
    fs::path(tables_dir, "functional_form_and_regime_tests.html"),
    coef_map,
    c(
      "The nonlinear-price column centers GDP-PLI before squaring it.",
      "The regime column excludes March 2020–December 2021 and tests slope changes after reopening."
    )
  )

  gravity_models <- c(
    main_results$models["gravity_distw_cre"],
    robustness_results$models[
      intersect(
        c("gravity_distcap_cre", "gravity_simple_cre"),
        names(robustness_results$models)
      )
    ]
  )
  gravity_tex <- write_model_table(
    gravity_models,
    fs::path(tables_dir, "gravity_distance_models.tex"),
    coef_map,
    c(
      "PPML-CRE estimates with region and month-year fixed effects and Mundlak means.",
      "Each column uses one distance definition; distances are never filled from another measure."
    )
  )

  inference_models <- c(
    main_results$models["baseline_gdp_pli"],
    robustness_results$models[c(
      "baseline_two_way_cluster", "baseline_heteroskedastic"
    )]
  )
  inference_tex <- write_model_table(
    inference_models,
    fs::path(tables_dir, "inference_sensitivity.tex"),
    coef_map,
    c(
      "The point specification is identical across columns; only the variance estimator changes.",
      "The principal inference clusters standard errors by origin."
    )
  )

  estimates <- dplyr::bind_rows(
    tidy_model_bundle(main_results),
    tidy_model_bundle(robustness_results)
  ) |>
    dplyr::mutate(
      interpretation = dplyr::case_when(
        .data$term %in% c(
          "log_distw_centered_x_direct_l1",
          "log_distw_centered_x_direct"
        ) ~ "interaction",
        .data$term %in% c(
          "direct_l1", "direct", "contig",
          "common_official_language", "colonial_link"
        ) ~ "indicator",
        stringr::str_detect(.data$term, "^log_") ~ "elasticity_or_semi_elasticity",
        TRUE ~ "coefficient"
      ),
      percent_effect_if_indicator = dplyr::if_else(
        .data$interpretation == "indicator",
        100 * (exp(.data$estimate) - 1),
        NA_real_
      )
    )
  estimates_csv <- write_csv_safe(
    estimates,
    fs::path(tables_dir, "coefficient_estimates.csv")
  )
  specifications_csv <- write_csv_safe(
    dplyr::bind_rows(
      dplyr::mutate(main_results$audit, family = "main", .before = 1L),
      dplyr::mutate(
        robustness_results$audit, family = "robustness", .before = 1L
      )
    ),
    fs::path(tables_dir, "model_specifications.csv")
  )

  marginal_models <- c(
    main_results$models["connectivity_combined_l1"],
    robustness_results$models[intersect(
      c(
        "pre_covid", "post_reopening", "exclude_pandemic",
        "balanced_core_2000", "cpi_price", "household_pli_price",
        "exclude_argentina", "exclude_top_markets",
        "contemporaneous_connectivity", "air_access_mode", "modal_panel"
      ),
      names(robustness_results$models)
    )]
  )
  marginal_effects <- purrr::imap_dfr(
    marginal_models,
    function(model, model_name) {
      contemporaneous <- identical(model_name, "contemporaneous_connectivity")
      direct_service_marginal_effects(
        model = model,
        model_name = model_name,
        family = if (model_name %in% names(main_results$models)) {
          "main"
        } else {
          "robustness"
        },
        distances_km = marginal_effect_distances_km,
        reference_km = interaction_reference_km,
        direct_term = if (contemporaneous) "direct" else "direct_l1",
        interaction_term = if (contemporaneous) {
          "log_distw_centered_x_direct"
        } else {
          "log_distw_centered_x_direct_l1"
        }
      )
    }
  )
  marginal_effects_csv <- write_csv_safe(
    marginal_effects,
    fs::path(tables_dir, "direct_service_marginal_effects.csv")
  )

  curve_model_names <- intersect(
    c("connectivity_combined_l1", "air_access_mode", "modal_panel"),
    names(marginal_models)
  )
  distance_range_km <- as.numeric(
    main_results$distance_range_km %||% c(1200, 18000)
  )
  curve_distances_km <- exp(seq(
    log(distance_range_km[[1L]]), log(distance_range_km[[2L]]),
    length.out = 180L
  ))
  direct_effect_curve <- purrr::imap_dfr(
    marginal_models[curve_model_names],
    function(model, model_name) {
      direct_service_marginal_effects(
        model = model,
        model_name = model_name,
        family = if (model_name %in% names(main_results$models)) {
          "main"
        } else {
          "robustness"
        },
        distances_km = curve_distances_km,
        reference_km = interaction_reference_km
      )
    }
  )

  model_labels <- c(
    baseline_gdp_pli = "Baseline",
    connectivity_combined_l1 = "Combined connectivity (t-1)",
    pre_covid = "Pre-COVID-19",
    post_reopening = "Post-reopening",
    exclude_pandemic = "Pandemic months excluded",
    balanced_core_2000 = "Balanced core",
    exclude_argentina = "Argentina excluded",
    exclude_top_markets = "Five largest markets excluded",
    contemporaneous_connectivity = "Contemporaneous connectivity",
    baseline_two_way_cluster = "Two-way clustering",
    air_access_mode = "Air arrivals",
    modal_panel = "Access-mode panel",
    seats_l1 = "Seats (t-1)",
    flights_l1 = "Flights (t-1)",
    seats_ma3_l1 = "Prior 3-month mean seats",
    connectivity_combined_capacity = "Seats in combined model"
  )

  price_plot_data <- estimates |>
    dplyr::filter(
      .data$term == "log_relative_price_gdp_pli",
      .data$model %in% c(
        "baseline_gdp_pli", "connectivity_combined_l1", "pre_covid",
        "post_reopening", "exclude_pandemic", "balanced_core_2000",
        "exclude_argentina", "exclude_top_markets",
        "contemporaneous_connectivity", "baseline_two_way_cluster",
        "air_access_mode", "modal_panel"
      )
    ) |>
    dplyr::mutate(
      model_label = unname(model_labels[.data$model]),
      model_label = factor(
        .data$model_label, levels = rev(unique(.data$model_label))
      )
    )
  coefficient_plot <- ggplot2::ggplot(
    price_plot_data,
    ggplot2::aes(x = .data$estimate, y = .data$model_label)
  ) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey55", linetype = 3) +
    ggdist::geom_pointinterval(
      ggplot2::aes(xmin = .data$conf.low, xmax = .data$conf.high),
      colour = tourism_palette()[["blue"]],
      point_size = 2.0, interval_size = 0.7
    ) +
    ggplot2::labs(
      x = "GDP-PLI price elasticity and 95% confidence interval",
      y = NULL,
      title = "Price competitiveness across specifications",
      subtitle = "PPML estimates; uncertainty clustered by origin unless noted",
      caption = "GDP-PLI is the principal price measure. The dashed line marks zero."
    ) +
    theme_tourism(10.5)

  connectivity_plot_data <- estimates |>
    dplyr::filter(
      (.data$model == "seats_l1" & .data$term == "log_seats_l1") |
        (.data$model == "flights_l1" & .data$term == "log_flights_l1") |
        (.data$model == "seats_ma3_l1" &
          .data$term == "log_seats_ma3_l1") |
        (.data$model == "connectivity_combined_l1" &
          .data$term == "log_seats_l1")
    ) |>
    dplyr::mutate(
      plot_model = dplyr::if_else(
        .data$model == "connectivity_combined_l1",
        "connectivity_combined_capacity", .data$model
      ),
      model_label = unname(model_labels[.data$plot_model]),
      model_label = factor(
        .data$model_label, levels = rev(unique(.data$model_label))
      )
    )
  connectivity_plot <- ggplot2::ggplot(
    connectivity_plot_data,
    ggplot2::aes(x = .data$estimate, y = .data$model_label)
  ) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey55", linetype = 3) +
    ggdist::geom_pointinterval(
      ggplot2::aes(xmin = .data$conf.low, xmax = .data$conf.high),
      colour = tourism_palette()[["teal"]],
      point_size = 2.0, interval_size = 0.7
    ) +
    ggplot2::labs(
      x = "Connectivity elasticity and 95% confidence interval",
      y = NULL,
      title = "Lagged air-capacity estimates",
      subtitle = "Alternative capacity measures produce positive demand elasticities",
      caption = "All models include origin and month-year fixed effects."
    ) +
    theme_tourism(10.5)

  direct_plot_data <- direct_effect_curve |>
    dplyr::mutate(
      model_label = factor(
        unname(model_labels[.data$model]),
        levels = unname(model_labels[c(
          "connectivity_combined_l1", "air_access_mode", "modal_panel"
        )])
      )
    )
  direct_effect_plot <- ggplot2::ggplot(
    direct_plot_data,
    ggplot2::aes(x = .data$distance_km, y = .data$percent_effect)
  ) +
    ggplot2::geom_hline(
      yintercept = 0, colour = tourism_palette()[["grey"]], linetype = 3
    ) +
    ggplot2::geom_vline(
      xintercept = interaction_reference_km,
      colour = tourism_palette()[["gold"]], linetype = 2
    ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(
        ymin = .data$conf_low_percent, ymax = .data$conf_high_percent
      ),
      fill = tourism_palette()[["blue"]], alpha = 0.16
    ) +
    ggplot2::geom_line(
      colour = tourism_palette()[["navy"]], linewidth = 0.9
    ) +
    ggplot2::scale_x_log10(
      breaks = c(1500, 3000, 5000, 10000, 18000),
      labels = scales::label_number(big.mark = ",", suffix = " km")
    ) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(scale = 1)) +
    ggplot2::facet_wrap(~model_label, ncol = 1) +
    ggplot2::labs(
      x = "Origin distance from Brazil (log scale)",
      y = "Estimated effect of direct service",
      title = "Direct service is conditional on distance",
      subtitle = "Point estimates and 95% confidence bands across the observed distance range",
      caption = "The gold line marks the 5,000 km centering reference."
    ) +
    theme_tourism(10.5) +
    ggplot2::theme(
      strip.text = ggplot2::element_text(
        face = "bold", colour = tourism_palette()[["navy"]]
      ),
      panel.spacing = grid::unit(1.0, "lines")
    )

  figure_pdf <- fs::path(figures_dir, "main_coefficient_plot.pdf")
  figure_png <- fs::path(figures_dir, "main_coefficient_plot.png")
  ggplot2::ggsave(
    figure_pdf, coefficient_plot, width = 8.6, height = 6.4, bg = "white"
  )
  ggplot2::ggsave(
    figure_png, coefficient_plot, width = 8.6, height = 6.4,
    dpi = 320, bg = "white"
  )
  connectivity_pdf <- fs::path(figures_dir, "connectivity_capacity_plot.pdf")
  connectivity_png <- fs::path(figures_dir, "connectivity_capacity_plot.png")
  ggplot2::ggsave(
    connectivity_pdf, connectivity_plot, width = 8.2, height = 4.8,
    bg = "white"
  )
  ggplot2::ggsave(
    connectivity_png, connectivity_plot, width = 8.2, height = 4.8,
    dpi = 320, bg = "white"
  )
  direct_effect_pdf <- fs::path(
    figures_dir, "direct_service_marginal_effect_plot.pdf"
  )
  direct_effect_png <- fs::path(
    figures_dir, "direct_service_marginal_effect_plot.png"
  )
  ggplot2::ggsave(
    direct_effect_pdf, direct_effect_plot, width = 8.4, height = 8.2,
    bg = "white"
  )
  ggplot2::ggsave(
    direct_effect_png, direct_effect_plot, width = 8.4, height = 8.2,
    dpi = 320, bg = "white"
  )

  results_dashboard <- (
    coefficient_plot / connectivity_plot / direct_effect_plot
  ) + patchwork::plot_layout(heights = c(1.2, 0.9, 1.6)) +
    patchwork::plot_annotation(
      title = "Price competitiveness and air connectivity",
      subtitle = "Core empirical results for international tourism demand in Brazil",
      theme = ggplot2::theme(
        plot.title = ggplot2::element_text(
          face = "bold", colour = tourism_palette()[["navy"]], size = 18
        ),
        plot.subtitle = ggplot2::element_text(
          colour = tourism_palette()[["grey"]], size = 11
        )
      )
    )
  dashboard_pdf <- fs::path(figures_dir, "article_results_dashboard.pdf")
  dashboard_png <- fs::path(figures_dir, "article_results_dashboard.png")
  ggplot2::ggsave(
    dashboard_pdf, results_dashboard, width = 9.2, height = 18,
    limitsize = FALSE, bg = "white"
  )
  ggplot2::ggsave(
    dashboard_png, results_dashboard, width = 9.2, height = 18,
    dpi = 320, limitsize = FALSE, bg = "white"
  )

  overleaf_tables <- fs::path("..", "overleaf", "tables")
  overleaf_figures <- fs::path("..", "overleaf", "figures")
  if (fs::dir_exists(overleaf_tables)) {
    purrr::walk(
      c(
        main_tex, robust_tex, price_connectivity_tex,
        frequency_modes_tex, functional_form_tex, gravity_tex,
        inference_tex
      ),
      ~fs::file_copy(
        .x, fs::path(overleaf_tables, fs::path_file(.x)), overwrite = TRUE
      )
    )
  }
  if (fs::dir_exists(overleaf_figures)) {
    purrr::walk(
      c(
        figure_pdf, figure_png, connectivity_pdf, connectivity_png,
        direct_effect_pdf, direct_effect_png, dashboard_pdf, dashboard_png
      ),
      ~fs::file_copy(
        .x, fs::path(overleaf_figures, fs::path_file(.x)), overwrite = TRUE
      )
    )
  }

  normalizePath(
    c(
      main_tex, main_html, robust_tex, robust_html,
      price_connectivity_tex, frequency_modes_tex, functional_form_tex,
      functional_form_html, gravity_tex, inference_tex, estimates_csv,
      specifications_csv,
      marginal_effects_csv, figure_pdf, figure_png,
      connectivity_pdf, connectivity_png, direct_effect_pdf,
      direct_effect_png, dashboard_pdf, dashboard_png
    ),
    winslash = "/", mustWork = TRUE
  )
}
