portuguese_country_to_iso3 <- function(x) {
  lookup <- c(
    "alemanha" = "DEU", "argentina" = "ARG", "australia" = "AUS",
    "arabia saudita" = "SAU",
    "bielorussia" = "BLR", "macedonia" = "MKD", "malaui" = "MWI",
    "mianma" = "MMR", "micronesia" = "FSM", "oma" = "OMN",
    "republica centro africana" = "CAF", "seichelles" = "SYC",
    "austria" = "AUT", "belgica" = "BEL", "bolivia" = "BOL",
    "bulgaria" = "BGR",
    "canada" = "CAN", "chile" = "CHL", "china" = "CHN",
    "cingapura" = "SGP", "croacia" = "HRV",
    "colombia" = "COL", "coreia do sul" = "KOR", "costa rica" = "CRI",
    "dinamarca" = "DNK", "equador" = "ECU", "espanha" = "ESP",
    "egito" = "EGY", "eslovaquia" = "SVK", "eslovenia" = "SVN",
    "estonia" = "EST", "filipinas" = "PHL", "gana" = "GHA",
    "grecia" = "GRC", "guiana" = "GUY", "hungria" = "HUN",
    "indonesia" = "IDN", "ira" = "IRN",
    "estados unidos" = "USA", "estados unidos da america" = "USA",
    "finlandia" = "FIN", "franca" = "FRA", "holanda" = "NLD",
    "paises baixos" = "NLD", "india" = "IND", "irlanda" = "IRL",
    "israel" = "ISR", "italia" = "ITA", "japao" = "JPN",
    "letonia" = "LVA", "libano" = "LBN", "lituania" = "LTU",
    "malasia" = "MYS", "marrocos" = "MAR", "mocambique" = "MOZ",
    "mexico" = "MEX", "noruega" = "NOR", "nova zelandia" = "NZL",
    "nicaragua" = "NIC", "nigeria" = "NGA", "panama" = "PAN",
    "paquistao" = "PAK", "porto rico" = "PRI", "quenia" = "KEN",
    "paraguai" = "PRY", "peru" = "PER", "polonia" = "POL",
    "portugal" = "PRT", "reino unido" = "GBR", "republica dominicana" = "DOM",
    "republica da coreia" = "KOR", "republica tcheca" = "CZE",
    "romenia" = "ROU", "servia" = "SRB", "siria" = "SYR",
    "russia" = "RUS", "suecia" = "SWE", "suica" = "CHE",
    "tailandia" = "THA", "tunisia" = "TUN", "turquia" = "TUR",
    "ucrania" = "UKR", "uruguai" = "URY", "venezuela" = "VEN",
    "africa do sul" = "ZAF"
  )
  cleaned <- normalize_text(x)
  direct <- unname(lookup[cleaned])
  multilingual_match <- if ("countryname" %in% getNamespaceExports("countrycode")) {
    countrycode::countryname(x, destination = "iso3c", warn = FALSE)
  } else {
    rep(NA_character_, length(x))
  }
  english_match <- countrycode::countrycode(x, origin = "country.name", destination = "iso3c", warn = FALSE)
  iso_match <- countrycode::countrycode(toupper(as.character(x)), origin = "iso3c", destination = "iso3c", warn = FALSE)
  dplyr::coalesce(direct, multilingual_match, english_match, iso_match)
}

standardize_access_mode <- function(x) {
  cleaned <- normalize_text(x)
  dplyr::case_when(
    stringr::str_detect(cleaned, "aer") ~ "air",
    stringr::str_detect(cleaned, "terrest|rodov|land") ~ "land",
    stringr::str_detect(cleaned, "marit|sea") ~ "maritime",
    stringr::str_detect(cleaned, "fluvial|river") ~ "fluvial",
    TRUE ~ "other"
  )
}

standardize_one_mtur_file <- function(path, cfg) {
  raw <- try(read_tabular_flexibly(path), silent = TRUE)
  if (inherits(raw, "try-error")) {
    warning("Skipping unreadable MTur file: ", path)
    return(NULL)
  }

  country_col <- first_existing_column(
    raw,
    c("^pais$", "nome.*pais", "pais.*correto", "pais.*resid", "pais.*orig", "country", "residencia"),
    required = FALSE
  )
  year_col <- first_existing_column(raw, c("^ano$", "^year$"), required = FALSE)
  month_col <- first_existing_column(raw, c("^mes$", "^month$"), required = FALSE)
  access_col <- first_existing_column(
    raw,
    c("^via$", "via.*acesso", "meio.*transporte", "access", "modal"),
    required = FALSE
  )
  arrivals_col <- first_existing_column(raw, c("chegada", "arrivals", "turist", "visitantes", "^total$"), required = FALSE)

  file_year <- suppressWarnings(
    as.integer(stringr::str_extract(fs::path_file(path), "(?:19|20)\\d{2}"))
  )
  year_available <- !is.null(year_col) && length(year_col) == 1L &&
    !is.na(year_col) && nzchar(year_col)

  required_columns <- list(
    country = country_col,
    year = if (year_available || !is.na(file_year)) "available" else NULL,
    month = month_col,
    arrivals = arrivals_col
  )
  missing_required <- names(required_columns)[
    vapply(
      required_columns,
      function(x) is.null(x) || length(x) != 1L || is.na(x) || !nzchar(x),
      logical(1)
    )
  ]
  if (length(missing_required) > 0L) {
    warning(
      "Skipping incompatible MTur file: ", path,
      ". Missing fields: ", paste(missing_required, collapse = ", "),
      ". Available columns: ", paste(names(raw), collapse = ", "),
      call. = FALSE
    )
    return(NULL)
  }

  access_available <- !is.null(access_col) && length(access_col) == 1L &&
    !is.na(access_col) && nzchar(access_col)
  access_raw <- if (!access_available) rep("all", nrow(raw)) else raw[[access_col]]
  year_raw <- if (year_available) raw[[year_col]] else rep(file_year, nrow(raw))
  country_raw <- raw[[country_col]]
  country_norm <- normalize_text(country_raw)
  aggregate_label <- country_norm %in% c(
    "total", "outros", "nao especificado", "sem informacao",
    "america do sul", "america do norte", "america central", "europa", "asia",
    "africa", "oceania", "oriente medio"
  ) | stringr::str_detect(
    country_norm,
    "^(outros|demais) paises(?:$|\\s)|^paises nao especificados(?:$|\\s)"
  )

  tibble::tibble(
    country_raw = as.character(country_raw),
    origin_iso3 = portuguese_country_to_iso3(country_raw),
    year = suppressWarnings(as.integer(year_raw)),
    month = month_number_pt_en(raw[[month_col]]),
    access_mode = if (!access_available) "all" else standardize_access_mode(access_raw),
    arrivals = parse_number_br(raw[[arrivals_col]]),
    source_file = fs::path_file(path),
    aggregate_label = aggregate_label
  ) |>
    dplyr::filter(
      .data$year >= cfg$project$start_year,
      .data$year <= cfg$project$end_year,
      dplyr::between(.data$month, 1L, 12L),
      !is.na(.data$arrivals)
    ) |>
    dplyr::mutate(date = as.Date(sprintf("%04d-%02d-01", .data$year, .data$month))) |>
    dplyr::select(dplyr::all_of(c(
      "origin_iso3", "country_raw", "date", "access_mode", "arrivals",
      "source_file", "aggregate_label"
    )))
}

clean_mtur_arrivals <- function(files, cfg) {
  raw_long <- purrr::map(files, standardize_one_mtur_file, cfg = cfg) |>
    purrr::compact() |>
    dplyr::bind_rows()

  if (nrow(raw_long) == 0L) stop("No valid rows were recovered from MTur resources.")
  assert_nonnegative(raw_long$arrivals, "MTur arrivals")

  aggregate_rows <- raw_long |>
    dplyr::filter(.data$aggregate_label) |>
    dplyr::mutate(year = lubridate::year(.data$date)) |>
    dplyr::group_by(.data$country_raw, .data$year) |>
    dplyr::summarise(
      rows = dplyr::n(),
      arrivals = sum(.data$arrivals, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$year, .data$country_raw)
  write_csv_safe(
    aggregate_rows,
    fs::path(cfg$paths$interim, "excluded_mtur_aggregate_rows.csv")
  )
  raw_long <- dplyr::filter(raw_long, !.data$aggregate_label)

  unknown <- raw_long |>
    dplyr::filter(is.na(.data$origin_iso3)) |>
    dplyr::group_by(.data$country_raw) |>
    dplyr::summarise(
      first_date = min(.data$date),
      last_date = max(.data$date),
      rows = dplyr::n(),
      arrivals = sum(.data$arrivals, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$country_raw)
  write_csv_safe(unknown, fs::path(cfg$paths$interim, "unmatched_mtur_countries.csv"))

  if (!isTRUE(cfg$data_options$keep_unknown_origins)) {
    raw_long <- dplyr::filter(raw_long, !is.na(.data$origin_iso3))
  }

  raw_long <- dplyr::filter(
    raw_long,
    is.na(.data$origin_iso3) | .data$origin_iso3 != cfg$project$main_destination_iso3
  )

  # CKAN packages may expose the same annual table in more than one format.
  # First aggregate legitimate subnational rows within each source file, then
  # retain one copy only when overlapping source files give identical totals.
  by_source <- raw_long |>
    dplyr::group_by(.data$origin_iso3, .data$date, .data$access_mode, .data$source_file) |>
    dplyr::summarise(arrivals = sum(.data$arrivals, na.rm = TRUE), .groups = "drop")
  conflicts <- by_source |>
    dplyr::group_by(.data$origin_iso3, .data$date, .data$access_mode) |>
    dplyr::summarise(
      n_sources = dplyr::n_distinct(.data$source_file),
      n_totals = dplyr::n_distinct(.data$arrivals),
      min_arrivals = min(.data$arrivals),
      max_arrivals = max(.data$arrivals),
      .groups = "drop"
    ) |>
    dplyr::filter(.data$n_sources > 1L, .data$n_totals > 1L)
  write_csv_safe(conflicts, fs::path(cfg$paths$interim, "mtur_source_conflicts.csv"))
  if (nrow(conflicts) > 0L) {
    stop(
      "Overlapping MTur resources disagree for the same origin-month-mode. ",
      "Inspect data/interim/mtur_source_conflicts.csv and retain one authoritative version per period."
    )
  }
  raw_long <- by_source |>
    dplyr::distinct(.data$origin_iso3, .data$date, .data$access_mode, .data$arrivals)

  collapsed <- raw_long |>
    dplyr::group_by(.data$origin_iso3, .data$date, .data$access_mode) |>
    dplyr::summarise(
      arrivals = sum(.data$arrivals, na.rm = TRUE),
      observed_record = 1L,
      .groups = "drop"
    )

  if (isTRUE(cfg$data_options$create_zero_flows)) {
    collapsed <- collapsed |>
      dplyr::group_by(.data$origin_iso3, .data$access_mode) |>
      dplyr::group_modify(function(.x, .y) {
        calendar <- tibble::tibble(date = seq(min(.x$date), max(.x$date), by = "month"))
        dplyr::left_join(calendar, .x, by = "date")
      }) |>
      dplyr::ungroup() |>
      dplyr::mutate(
        zero_imputed = as.integer(is.na(.data$observed_record)),
        arrivals = dplyr::coalesce(.data$arrivals, 0),
        observed_record = dplyr::coalesce(.data$observed_record, 0L)
      )
  } else {
    collapsed <- dplyr::mutate(collapsed, zero_imputed = 0L)
  }

  assert_unique_key(collapsed, c("origin_iso3", "date", "access_mode"), "clean MTur arrivals")
  write_parquet_safe(collapsed, fs::path(cfg$paths$interim, "mtur_arrivals_clean.parquet"))
  collapsed
}
