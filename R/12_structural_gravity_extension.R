# This extension is intentionally separate from the Brazil-only model. A genuine
# structural-gravity design needs flows from each origin to several destinations.
run_structural_extension <- function(cfg) {
  if (!isTRUE(cfg$data_options$use_structural_extension)) {
    return(list(status = "disabled", model = NULL, data = NULL))
  }

  path <- fs::path(cfg$paths$structural_raw, "multi_destination_panel.csv")
  if (!file.exists(path)) {
    stop("Structural extension enabled, but the canonical input is missing: ", path)
  }
  data <- readr::read_csv(path, show_col_types = FALSE) |>
    janitor::clean_names()
  required <- c(
    "origin_iso3", "destination_iso3", "date", "arrivals", "direct",
    "seats", "visa_required", "distance_km"
  )
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) stop("Structural panel is missing: ", paste(missing, collapse = ", "))

  data <- data |>
    dplyr::mutate(
      origin_iso3 = toupper(.data$origin_iso3),
      destination_iso3 = toupper(.data$destination_iso3),
      date = lubridate::floor_date(as.Date(.data$date), "month"),
      year_month = format(.data$date, "%Y-%m"),
      pair_id = interaction(.data$origin_iso3, .data$destination_iso3, drop = TRUE),
      origin_time = interaction(.data$origin_iso3, .data$year_month, drop = TRUE),
      destination_time = interaction(.data$destination_iso3, .data$year_month, drop = TRUE),
      log_seats = log1p_zero_safe(.data$seats),
      log_distance = safe_log(.data$distance_km),
      distance_x_direct = .data$log_distance * .data$direct
    ) |>
    dplyr::filter(!is.na(.data$arrivals), .data$arrivals >= 0)

  assert_unique_key(data, c("origin_iso3", "destination_iso3", "date"), "multi-destination panel")
  model <- fixest::fepois(
    arrivals ~ direct + log_seats + visa_required + distance_x_direct |
      origin_time + destination_time + pair_id,
    data = data,
    vcov = ~pair_id,
    notes = FALSE
  )

  # origin-time FE absorb income and outward demand; destination-time FE absorb
  # destination prices and attractiveness; pair FE absorb static bilateral costs.
  output <- fs::path(cfg$paths$tables, "structural_gravity_model.tex")
  modelsummary::modelsummary(
    list("Structural PPML" = model), output = output, stars = TRUE,
    gof_omit = "IC|Log|RMSE|Std.Errors",
    notes = c(
      "Origin-month, destination-month and pair fixed effects included.",
      "Standard errors clustered by origin-destination pair."
    )
  )
  list(status = "estimated", model = model, data = data, table = output)
}

structural_counterfactual <- function(structural_result, seats_multiplier = 1.10) {
  if (!identical(structural_result$status, "estimated")) {
    stop("Estimate the structural extension before requesting a counterfactual.")
  }
  model <- structural_result$model
  data <- structural_result$data
  baseline <- stats::predict(model, newdata = data, type = "response")
  scenario <- data |>
    dplyr::mutate(
      seats = .data$seats * seats_multiplier,
      log_seats = log1p_zero_safe(.data$seats)
    )
  scenario_prediction <- stats::predict(model, newdata = scenario, type = "response")
  tibble::tibble(
    baseline_arrivals = baseline,
    scenario_arrivals = scenario_prediction,
    proportional_change = scenario_prediction / baseline - 1
  )
}
