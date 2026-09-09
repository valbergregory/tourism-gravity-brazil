prepare_visa <- function(origins, cfg) {
  if (!isTRUE(cfg$data_options$use_visa)) return(empty_visa_table())
  path <- fs::path(cfg$paths$visa_raw, "visa_regimes.csv")
  if (!file.exists(path)) stop("Visa data enabled, but file is missing: ", path)

  raw <- readr::read_csv(path, show_col_types = FALSE) |>
    janitor::clean_names()
  required <- c("origin_iso3", "start_date", "end_date", "visa_required", "evisa", "visa_free")
  missing <- setdiff(required, names(raw))
  if (length(missing) > 0L) stop("visa_regimes.csv is missing: ", paste(missing, collapse = ", "))

  result <- raw |>
    dplyr::mutate(
      origin_iso3 = toupper(.data$origin_iso3),
      start_date = lubridate::floor_date(as.Date(.data$start_date), "month"),
      end_date = lubridate::floor_date(as.Date(.data$end_date), "month")
    ) |>
    dplyr::filter(.data$origin_iso3 %in% origins) |>
    dplyr::mutate(date = purrr::map2(.data$start_date, .data$end_date, ~seq(.x, .y, by = "month"))) |>
    tidyr::unnest(date) |>
    dplyr::select(origin_iso3, date, visa_required, evisa, visa_free) |>
    dplyr::group_by(.data$origin_iso3, .data$date) |>
    dplyr::summarise(dplyr::across(c("visa_required", "evisa", "visa_free"), max, na.rm = TRUE), .groups = "drop")

  assert_unique_key(result, c("origin_iso3", "date"), "visa regimes")
  write_parquet_safe(result, fs::path(cfg$paths$interim, "visa_monthly.parquet"))
  result
}
