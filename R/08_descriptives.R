make_descriptives <- function(panel, cfg) {
  coverage <- panel |>
    dplyr::summarise(
      origins = dplyr::n_distinct(.data$origin_iso3),
      first_month = min(.data$date),
      last_month = max(.data$date),
      observations = dplyr::n(),
      zero_share = mean(.data$arrivals == 0),
      arrivals = sum(.data$arrivals, na.rm = TRUE)
    )
  origin_summary <- panel |>
    dplyr::group_by(.data$origin_iso3, .data$origin_country, .data$origin_region) |>
    dplyr::summarise(
      first_month = min(.data$date), last_month = max(.data$date),
      months = dplyr::n(), total_arrivals = sum(.data$arrivals),
      zero_share = mean(.data$arrivals == 0), .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$total_arrivals))
  annual <- panel |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(arrivals = sum(.data$arrivals), .groups = "drop")

  files <- c(
    write_csv_safe(coverage, fs::path(cfg$paths$tables, "data_coverage.csv")),
    write_csv_safe(origin_summary, fs::path(cfg$paths$tables, "origin_summary.csv")),
    write_csv_safe(annual, fs::path(cfg$paths$tables, "annual_arrivals.csv"))
  )

  p1 <- ggplot2::ggplot(annual, ggplot2::aes(.data$year, .data$arrivals)) +
    ggplot2::geom_line(linewidth = 0.8, colour = "#0B5D7A") +
    ggplot2::geom_vline(xintercept = c(2014, 2016, 2020), linetype = 3, colour = "grey50") +
    ggplot2::scale_y_continuous(labels = scales::label_number_si()) +
    ggplot2::labs(x = NULL, y = "International arrivals", title = "International tourist arrivals to Brazil") +
    ggplot2::theme_minimal(base_size = 11)
  p2 <- origin_summary |>
    dplyr::slice_head(n = 15L) |>
    ggplot2::ggplot(ggplot2::aes(stats::reorder(.data$origin_iso3, .data$total_arrivals), .data$total_arrivals)) +
    ggplot2::geom_col(fill = "#C5542D") +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(labels = scales::label_number_si()) +
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
