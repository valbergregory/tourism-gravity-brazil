# Event studies are optional identification exercises, not automatic causal claims.
# Document the institutional timing and defend no anticipation and parallel trends.
estimate_ppml_event_study <- function(
    data,
    event_date_column = "event_date",
    treated_column = "treated",
    window = 24L) {
  required <- c("origin_iso3", "date", "arrivals", event_date_column, treated_column)
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) stop("Event-study data is missing: ", paste(missing, collapse = ", "))

  prepared <- data |>
    dplyr::mutate(
      event_date = lubridate::floor_date(as.Date(.data[[event_date_column]]), "month"),
      treated = as.integer(.data[[treated_column]]),
      event_time = 12L * (lubridate::year(.data$date) - lubridate::year(.data$event_date)) +
        lubridate::month(.data$date) - lubridate::month(.data$event_date),
      event_time = pmax(-window, pmin(window, .data$event_time)),
      year_month = format(.data$date, "%Y-%m")
    )

  fixest::fepois(
    arrivals ~ i(event_time, treated, ref = -1L) | origin_iso3 + year_month,
    data = prepared,
    vcov = ~origin_iso3,
    notes = FALSE
  )
}

plot_event_study <- function(model, output_path) {
  fs::dir_create(fs::path_dir(output_path), recurse = TRUE)
  grDevices::pdf(output_path, width = 7.2, height = 4.8)
  fixest::iplot(
    model, ref.line = 0,
    main = "PPML event-study coefficients",
    xlab = "Months relative to the event",
    ylab = "Coefficient relative to month -1"
  )
  grDevices::dev.off()
  normalizePath(output_path, winslash = "/", mustWork = TRUE)
}
