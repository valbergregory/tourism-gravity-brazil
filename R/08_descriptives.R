# Descriptive aggregates distinguish two kinds of panel cells. Since the
# zero-imputation correction (NOTA_CORRECAO_ZEROS_IMPUTADOS_2026-09-04), a
# country-month that the MTur source never reported carries
# observation_status == "unobserved_completed_cell" and arrivals == NA. Such
# cells count for panel coverage but never enter arrival totals or zero shares:
# an unobserved cell is neither a zero nor a positive flow. Observed cells
# ("fully_observed_cell" and "observed_with_completed_modes") keep their
# arrivals, including observed or mode-imputed zeros, exactly as stored.
unobserved_cell_status <- "unobserved_completed_cell"

is_observed_cell <- function(observation_status) {
  observation_status != unobserved_cell_status
}

observed_arrivals_total <- function(arrivals, observation_status) {
  observed <- is_observed_cell(observation_status)
  if (!any(observed)) return(NA_real_)
  sum(arrivals[observed])
}

observed_zero_share <- function(arrivals, observation_status) {
  observed <- is_observed_cell(observation_status)
  if (!any(observed)) return(NA_real_)
  mean(arrivals[observed] == 0)
}

assert_descriptive_panel <- function(panel) {
  required <- c("origin_iso3", "date", "year", "arrivals", "observation_status")
  missing <- setdiff(required, names(panel))
  if (length(missing) > 0L) {
    stop("Descriptive panel is missing: ", paste(missing, collapse = ", "))
  }
  if (any(is.na(panel$observation_status))) {
    stop("Descriptive panel contains cells without observation_status.")
  }
  observed <- is_observed_cell(panel$observation_status)
  if (any(is.na(panel$arrivals[observed]))) {
    stop(
      "Observed cells with missing arrivals: ",
      sum(is.na(panel$arrivals[observed])),
      ". Descriptives cannot silently drop them."
    )
  }
  if (any(!is.na(panel$arrivals[!observed]))) {
    stop(
      "Unobserved completed cells must carry NA arrivals; found ",
      sum(!is.na(panel$arrivals[!observed])), " with values."
    )
  }
  invisible(TRUE)
}

make_descriptives <- function(panel, cfg) {
  assert_descriptive_panel(panel)

  # Coverage keeps the full panel as denominator (all completed cells) and
  # reports how many of them were actually observed in the source.
  coverage <- panel |>
    dplyr::summarise(
      origins = dplyr::n_distinct(.data$origin_iso3),
      first_month = min(.data$date),
      last_month = max(.data$date),
      observations = dplyr::n(),
      observed_cells = sum(is_observed_cell(.data$observation_status)),
      unobserved_completed_cells = sum(
        !is_observed_cell(.data$observation_status)
      ),
      zero_share = observed_zero_share(
        .data$arrivals, .data$observation_status
      ),
      arrivals = observed_arrivals_total(
        .data$arrivals, .data$observation_status
      )
    )

  # Per-origin coverage (first/last month, months) uses every completed cell;
  # arrival totals and zero shares use observed cells only.
  origin_summary <- panel |>
    dplyr::group_by(.data$origin_iso3, .data$origin_country, .data$origin_region) |>
    dplyr::summarise(
      first_month = min(.data$date), last_month = max(.data$date),
      months = dplyr::n(),
      observed_months = sum(is_observed_cell(.data$observation_status)),
      total_arrivals = observed_arrivals_total(
        .data$arrivals, .data$observation_status
      ),
      zero_share = observed_zero_share(
        .data$arrivals, .data$observation_status
      ),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$total_arrivals))

  annual <- panel |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(
      arrivals = observed_arrivals_total(
        .data$arrivals, .data$observation_status
      ),
      observed_cells = sum(is_observed_cell(.data$observation_status)),
      unobserved_completed_cells = sum(
        !is_observed_cell(.data$observation_status)
      ),
      .groups = "drop"
    )

  files <- c(
    write_csv_safe(coverage, fs::path(cfg$paths$tables, "data_coverage.csv")),
    write_csv_safe(origin_summary, fs::path(cfg$paths$tables, "origin_summary.csv")),
    write_csv_safe(annual, fs::path(cfg$paths$tables, "annual_arrivals.csv"))
  )

  p1 <- ggplot2::ggplot(annual, ggplot2::aes(.data$year, .data$arrivals)) +
    ggplot2::geom_line(linewidth = 0.8, colour = "#0B5D7A") +
    ggplot2::geom_vline(xintercept = c(2014, 2016, 2020), linetype = 3, colour = "grey50") +
    ggplot2::scale_y_continuous(
      labels = scales::label_number(scale_cut = scales::cut_short_scale())
    ) +
    ggplot2::labs(x = NULL, y = "International arrivals", title = "International tourist arrivals to Brazil") +
    ggplot2::theme_minimal(base_size = 11)
  p2 <- origin_summary |>
    dplyr::slice_head(n = 15L) |>
    ggplot2::ggplot(ggplot2::aes(stats::reorder(.data$origin_iso3, .data$total_arrivals), .data$total_arrivals)) +
    ggplot2::geom_col(fill = "#C5542D") +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(
      labels = scales::label_number(scale_cut = scales::cut_short_scale())
    ) +
    ggplot2::labs(x = NULL, y = "Total arrivals", title = "Largest origin markets") +
    ggplot2::theme_minimal(base_size = 11)

  for (extension in c("pdf", "png")) {
    f1 <- fs::path(cfg$paths$figures, paste0("annual_arrivals.", extension))
    f2 <- fs::path(cfg$paths$figures, paste0("top_origins.", extension))
    ggplot2::ggsave(f1, p1, width = 7.2, height = 4.3, dpi = 300)
    ggplot2::ggsave(f2, p2, width = 7.2, height = 5.2, dpi = 300)
    files <- c(files, normalizePath(f1, winslash = "/", mustWork = TRUE), normalizePath(f2, winslash = "/", mustWork = TRUE))
  }
  files
}
