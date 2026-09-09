source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/04_auditoria_painel.txt", {
  required <- c("targets", "dplyr", "readr", "tibble")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) stop("Pacotes ausentes: ", paste(missing, collapse = ", "))

  panel_objects <- targets::tar_read_raw(name = "panels")
  total <- panel_objects$total |>
    dplyr::mutate(
      baseline_complete = !is.na(.data$arrivals) &
        !is.na(.data$log_gdp_pc_l1y) &
        !is.na(.data$log_population_l1y),
      gdp_pli_price_complete = .data$baseline_complete &
        !is.na(.data$log_relative_price_gdp_pli),
      cpi_price_complete = .data$baseline_complete &
        !is.na(.data$log_relative_price_cpi),
      pli_price_complete = .data$baseline_complete &
        !is.na(.data$log_relative_price_pli),
      gravity_complete = .data$baseline_complete &
        !is.na(.data$log_distance),
      gdp_pli_gravity_complete = .data$gdp_pli_price_complete &
        !is.na(.data$log_distance),
      cpi_gravity_complete = .data$cpi_price_complete &
        !is.na(.data$log_distance),
      main_complete = .data$baseline_complete
    )

  audit_dir <- "output/audit"
  dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

  sample_flags <- c(
    core_2000 = "sample_core_2000",
    long_pre2009 = "sample_long_pre2009",
    broad_5y = "sample_broad_5y",
    full = "sample_full"
  )
  total_arrivals <- sum(total$arrivals, na.rm = TRUE)

  sample_summary <- dplyr::bind_rows(lapply(names(sample_flags), function(label) {
    flag <- sample_flags[[label]]
    data <- total[total[[flag]] == 1L, , drop = FALSE]
    sample_arrivals <- sum(data$arrivals, na.rm = TRUE)
    tibble::tibble(
      sample = label,
      origins = dplyr::n_distinct(data$origin_iso3),
      rows = nrow(data),
      arrivals = sample_arrivals,
      arrival_share = sample_arrivals / total_arrivals,
      baseline_complete_rows = sum(data$baseline_complete, na.rm = TRUE),
      baseline_complete_origins = dplyr::n_distinct(
        data$origin_iso3[data$baseline_complete]
      ),
      baseline_arrival_coverage = sum(
        data$arrivals[data$baseline_complete],
        na.rm = TRUE
      ) / sample_arrivals,
      gdp_pli_price_complete_rows = sum(data$gdp_pli_price_complete, na.rm = TRUE),
      gdp_pli_price_complete_origins = dplyr::n_distinct(
        data$origin_iso3[data$gdp_pli_price_complete]
      ),
      gdp_pli_price_arrival_coverage = sum(
        data$arrivals[data$gdp_pli_price_complete],
        na.rm = TRUE
      ) / sample_arrivals,
      cpi_price_complete_rows = sum(data$cpi_price_complete, na.rm = TRUE),
      cpi_price_complete_origins = dplyr::n_distinct(
        data$origin_iso3[data$cpi_price_complete]
      ),
      cpi_price_arrival_coverage = sum(
        data$arrivals[data$cpi_price_complete],
        na.rm = TRUE
      ) / sample_arrivals,
      pli_price_complete_rows = sum(data$pli_price_complete, na.rm = TRUE),
      pli_price_complete_origins = dplyr::n_distinct(
        data$origin_iso3[data$pli_price_complete]
      ),
      pli_price_arrival_coverage = sum(
        data$arrivals[data$pli_price_complete],
        na.rm = TRUE
      ) / sample_arrivals,
      gravity_complete_rows = sum(data$gravity_complete, na.rm = TRUE),
      gravity_complete_origins = dplyr::n_distinct(
        data$origin_iso3[data$gravity_complete]
      ),
      gdp_pli_gravity_complete_rows = sum(
        data$gdp_pli_gravity_complete,
        na.rm = TRUE
      ),
      gdp_pli_gravity_complete_origins = dplyr::n_distinct(
        data$origin_iso3[data$gdp_pli_gravity_complete]
      ),
      cpi_gravity_complete_rows = sum(data$cpi_gravity_complete, na.rm = TRUE),
      cpi_gravity_complete_origins = dplyr::n_distinct(
        data$origin_iso3[data$cpi_gravity_complete]
      )
    )
  }))

  variables <- c(
    "origin_gdp_pc",
    "origin_population",
    "origin_cpi",
    "origin_fx",
    "origin_price_level_hh",
    "origin_price_level_gdp",
    "brazil_cpi",
    "brazil_fx",
    "brazil_price_level_hh",
    "brazil_price_level_gdp",
    "relative_price_cpi",
    "relative_price_pli",
    "relative_price_gdp_pli",
    "distance_km"
  )
  missingness <- dplyr::bind_rows(lapply(variables, function(variable) {
    values <- total[[variable]]
    tibble::tibble(
      variable = variable,
      missing_rows = sum(is.na(values)),
      missing_share = mean(is.na(values)),
      affected_origins = dplyr::n_distinct(total$origin_iso3[is.na(values)])
    )
  }))

  origin_audit <- total |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      first_date = min(.data$date),
      last_date = max(.data$date),
      entry_cohort = dplyr::first(.data$origin_entry_cohort),
      sample_core_2000 = dplyr::first(.data$sample_core_2000),
      sample_long_pre2009 = dplyr::first(.data$sample_long_pre2009),
      sample_broad_5y = dplyr::first(.data$sample_broad_5y),
      total_arrivals = sum(.data$arrivals, na.rm = TRUE),
      rows = dplyr::n(),
      baseline_complete_rows = sum(.data$baseline_complete, na.rm = TRUE),
      gdp_pli_price_complete_rows = sum(
        .data$gdp_pli_price_complete,
        na.rm = TRUE
      ),
      cpi_price_complete_rows = sum(.data$cpi_price_complete, na.rm = TRUE),
      pli_price_complete_rows = sum(.data$pli_price_complete, na.rm = TRUE),
      gravity_complete_rows = sum(.data$gravity_complete, na.rm = TRUE),
      gdp_pli_gravity_complete_rows = sum(
        .data$gdp_pli_gravity_complete,
        na.rm = TRUE
      ),
      cpi_gravity_complete_rows = sum(.data$cpi_gravity_complete, na.rm = TRUE),
      cpi_interpolated_rows = sum(.data$origin_cpi_interpolated, na.rm = TRUE),
      cpi_proxy_rows = sum(.data$origin_cpi_proxy_used, na.rm = TRUE),
      fx_proxy_rows = sum(.data$origin_fx_proxy_used, na.rm = TRUE),
      price_level_proxy_rows = sum(
        .data$origin_price_level_hh_proxy_used,
        na.rm = TRUE
      ),
      price_level_gdp_proxy_rows = sum(
        .data$origin_price_level_gdp_proxy_used,
        na.rm = TRUE
      ),
      price_proxy_iso3c = dplyr::first(
        stats::na.omit(.data$origin_price_proxy_iso3c),
        default = NA_character_
      ),
      missing_distance = as.integer(all(is.na(.data$distance_km))),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      baseline_complete_share = .data$baseline_complete_rows / .data$rows,
      gdp_pli_price_complete_share =
        .data$gdp_pli_price_complete_rows / .data$rows,
      cpi_price_complete_share = .data$cpi_price_complete_rows / .data$rows,
      pli_price_complete_share = .data$pli_price_complete_rows / .data$rows,
      gravity_complete_share = .data$gravity_complete_rows / .data$rows
    ) |>
    dplyr::arrange(dplyr::desc(.data$total_arrivals))

  critical_markets <- origin_audit |>
    dplyr::filter(.data$origin_iso3 %in% c("ARG", "GUF", "PRI", "VEN")) |>
    dplyr::select(
      origin_iso3,
      total_arrivals,
      rows,
      baseline_complete_rows,
      gdp_pli_price_complete_rows,
      cpi_price_complete_rows,
      pli_price_complete_rows,
      cpi_interpolated_rows,
      cpi_proxy_rows,
      fx_proxy_rows,
      price_level_proxy_rows,
      price_level_gdp_proxy_rows,
      price_proxy_iso3c
    ) |>
    dplyr::arrange(dplyr::desc(.data$total_arrivals))

  expected <- c(core_2000 = 43L, long_pre2009 = 53L, broad_5y = 89L, full = 199L)
  observed <- stats::setNames(sample_summary$origins, sample_summary$sample)
  sample_check <- tibble::tibble(
    sample = names(expected),
    expected_origins = unname(expected),
    observed_origins = unname(observed[names(expected)]),
    matches_expected = expected_origins == observed_origins
  )

  readr::write_csv(sample_summary, file.path(audit_dir, "panel_sample_summary.csv"))
  readr::write_csv(sample_check, file.path(audit_dir, "panel_sample_check.csv"))
  readr::write_csv(missingness, file.path(audit_dir, "panel_missingness.csv"))
  readr::write_csv(origin_audit, file.path(audit_dir, "panel_origin_audit.csv"))
  readr::write_csv(critical_markets, file.path(audit_dir, "critical_market_coverage.csv"))

  cat("AMOSTRAS E COBERTURA\n")
  print(sample_summary, n = Inf, width = Inf)
  cat("\nVERIFICAÇÃO DOS TAMANHOS ESPERADOS\n")
  print(sample_check, n = Inf, width = Inf)
  cat("\nDADOS AUSENTES NO PAINEL INTEGRAL\n")
  print(missingness, n = Inf, width = Inf)
  cat("\nMERCADOS CRÍTICOS PARA A COBERTURA\n")
  print(critical_markets, n = Inf, width = Inf)

  if (!all(sample_check$matches_expected)) {
    stop(
      "Os tamanhos das amostras não coincidem com a auditoria MTur. ",
      "Consulte output/audit/panel_sample_check.csv."
    )
  }

  core_baseline_origins <- sample_summary$baseline_complete_origins[
    sample_summary$sample == "core_2000"
  ]
  if (length(core_baseline_origins) != 1L || core_baseline_origins == 0L) {
    stop("Nenhuma origem da amostra principal possui renda e população completas.")
  }

  argentina <- critical_markets[critical_markets$origin_iso3 == "ARG", , drop = FALSE]
  if (nrow(argentina) == 0L || argentina$baseline_complete_rows == 0L) {
    stop("A Argentina continua ausente da amostra PPML básica.")
  }
  if (argentina$gdp_pli_price_complete_rows == 0L) {
    warning(
      "A Argentina continua sem preço GDP-PLI. O modelo de preço amplo não ",
      "deverá ser estimado antes de nova correção."
    )
  }
  if (argentina$cpi_price_complete_rows == 0L) {
    warning(
      "A Argentina continua sem preço CPI/câmbio. O modelo básico poderá avançar, ",
      "mas o modelo de preço CPI não deverá ser estimado."
    )
  }

  cat("\nAUDITORIA DO PAINEL CONCLUÍDA\n")
  cat(
    "As coberturas básica, GDP-PLI, CPI/câmbio e PLI domiciliar foram ",
    "auditadas separadamente.\n"
  )
})
