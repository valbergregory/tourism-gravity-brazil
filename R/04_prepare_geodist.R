find_local_cepii_geodist <- function(raw_dir) {
  candidates <- fs::dir_ls(
    raw_dir,
    recurse = TRUE,
    regexp = "dist[_-]?cepii.*\\.(csv|txt|tsv|xls|xlsx)$",
    type = "file",
    fail = FALSE
  )

  candidates <- candidates[file.info(candidates)$size > 1000]
  if (length(candidates) == 0L) return(character())

  preferred_names <- c(
    "dist_cepii_cran.csv",
    "dist_cepii.csv",
    "dist_cepii.xlsx",
    "dist_cepii.xls"
  )
  priority <- match(tolower(fs::path_file(candidates)), preferred_names)
  priority[is.na(priority)] <- length(preferred_names) + 1L
  candidates[order(priority, candidates)]
}

extract_local_cepii_archives <- function(raw_dir) {
  archives <- fs::dir_ls(
    raw_dir,
    recurse = FALSE,
    regexp = "\\.zip$",
    type = "file",
    fail = FALSE
  )
  archives <- archives[file.info(archives)$size > 1000]
  if (length(archives) == 0L) return(invisible(character()))

  extracted <- character()
  for (archive in archives) {
    listing <- try(utils::unzip(archive, list = TRUE), silent = TRUE)
    if (inherits(listing, "try-error") || nrow(listing) == 0L) next

    members <- listing$Name[
      stringr::str_detect(
        tolower(listing$Name),
        "dist[_-]?cepii.*\\.(csv|txt|tsv|xls|xlsx)$"
      )
    ]
    if (length(members) == 0L) next

    extract_dir <- fs::path(raw_dir, "extracted")
    fs::dir_create(extract_dir, recurse = TRUE)
    attempt <- try(
      utils::unzip(archive, files = members, exdir = extract_dir),
      silent = TRUE
    )
    if (!inherits(attempt, "try-error")) extracted <- c(extracted, attempt)
  }
  invisible(extracted)
}

load_cepii_geodist <- function(cfg) {
  raw_dir <- cfg$paths$cepii_raw
  fs::dir_create(raw_dir, recurse = TRUE)

  existing <- find_local_cepii_geodist(raw_dir)
  if (length(existing) == 0L) {
    extract_local_cepii_archives(raw_dir)
    existing <- find_local_cepii_geodist(raw_dir)
  }

  if (length(existing) > 0L) {
    message("Carregando CEPII GeoDist local: ", existing[[1]])
    return(read_tabular_flexibly(existing[[1]]))
  }

  if (!isTRUE(cfg$data_options$download_cepii)) {
    stop(
      "CEPII GeoDist não encontrado. Coloque dist_cepii.csv, .xls ou .xlsx em ",
      raw_dir, "."
    )
  }

  if (!requireNamespace("cepiigeodist", quietly = TRUE)) {
    stop(
      "O pacote R 'cepiigeodist' não está instalado. Na raiz do projeto, execute ",
      "source('renv_bootstrap.R'), reinicie o R e rode novamente ",
      "source('scripts/02b_preparar_geodist.R')."
    )
  }

  data_env <- new.env(parent = baseenv())
  suppressWarnings(
    utils::data(
      list = "dist_cepii",
      package = "cepiigeodist",
      envir = data_env
    )
  )

  if (!exists("dist_cepii", envir = data_env, inherits = FALSE)) {
    namespace_attempt <- try(
      get("dist_cepii", envir = asNamespace("cepiigeodist"), inherits = FALSE),
      silent = TRUE
    )
    if (!inherits(namespace_attempt, "try-error")) {
      assign("dist_cepii", namespace_attempt, envir = data_env)
    }
  }

  if (!exists("dist_cepii", envir = data_env, inherits = FALSE)) {
    stop(
      "O pacote 'cepiigeodist' está instalado, mas a base dist_cepii não pôde ",
      "ser carregada. Execute source('scripts/99_coletar_diagnostico.R') e envie ",
      "o arquivo logs/diagnostico_erro.txt."
    )
  }

  raw <- get("dist_cepii", envir = data_env, inherits = FALSE) |>
    tibble::as_tibble() |>
    janitor::clean_names()

  if (nrow(raw) < 1000L) {
    stop("A base dist_cepii carregada possui poucas linhas e parece inválida.")
  }

  cache_path <- fs::path(raw_dir, "dist_cepii_cran.csv")
  readr::write_csv(raw, cache_path, na = "")
  message(
    "CEPII GeoDist carregado do pacote cepiigeodist e armazenado em: ",
    cache_path
  )
  raw
}

prepare_geodist <- function(origins, cfg) {
  raw <- load_cepii_geodist(cfg)
  origin_col <- first_existing_column(raw, c("^iso_o$", "iso3_o", "origin"))
  destination_col <- first_existing_column(raw, c("^iso_d$", "iso3_d", "destination"))
  # `distw` is the binding main measure. Never replace it row by row with
  # `distcap` or `dist`; those columns are retained only for robustness tests.
  if (!"distw" %in% names(raw)) {
    stop(
      "CEPII GeoDist does not contain distw. The main distance cannot be ",
      "imputed from distcap or dist."
    )
  }
  optional_distance <- function(name) {
    if (name %in% names(raw)) {
      suppressWarnings(as.numeric(raw[[name]]))
    } else {
      rep(NA_real_, nrow(raw))
    }
  }
  contig_col <- first_existing_column(raw, c("^contig$", "border"), required = FALSE)
  language_col <- first_existing_column(raw, c("comlang_off", "comlang", "language"), required = FALSE)
  colony_col <- first_existing_column(raw, c("^colony$", "colonial"), required = FALSE)

  brazil_iso3 <- cfg$project$main_destination_iso3
  historical_iso_crosswalk <- c(
    ROM = "ROU",
    YUG = "SRB"
  )

  harmonize_geodist_iso3 <- function(x) {
    normalized <- toupper(trimws(as.character(x)))
    matched <- normalized %in% names(historical_iso_crosswalk)
    normalized[matched] <- unname(historical_iso_crosswalk[normalized[matched]])
    normalized
  }

  raw_dyads <- tibble::tibble(
    iso_o_source = toupper(trimws(as.character(raw[[origin_col]]))),
    iso_d_source = toupper(trimws(as.character(raw[[destination_col]]))),
    distw_km = optional_distance("distw"),
    distcap_km = optional_distance("distcap"),
    dist_km = optional_distance("dist"),
    contig = if (is.null(contig_col)) NA_integer_ else suppressWarnings(as.integer(raw[[contig_col]])),
    common_official_language = if (is.null(language_col)) NA_integer_ else suppressWarnings(as.integer(raw[[language_col]])),
    colonial_direction = if (is.null(colony_col)) NA_integer_ else suppressWarnings(as.integer(raw[[colony_col]]))
  ) |>
    dplyr::mutate(
      iso_o = harmonize_geodist_iso3(.data$iso_o_source),
      iso_d = harmonize_geodist_iso3(.data$iso_d_source)
    ) |>
    dplyr::filter(
      (.data$iso_o %in% origins & .data$iso_d == brazil_iso3) |
        (.data$iso_o == brazil_iso3 & .data$iso_d %in% origins)
    ) |>
    dplyr::mutate(
      origin_iso3 = dplyr::if_else(.data$iso_d == brazil_iso3, .data$iso_o, .data$iso_d),
      source_origin_iso3 = dplyr::if_else(
        .data$iso_d == brazil_iso3,
        .data$iso_o_source,
        .data$iso_d_source
      ),
      origin_to_brazil = .data$iso_o == .data$origin_iso3 & .data$iso_d == brazil_iso3
    )

  harmonization_audit <- raw_dyads |>
    dplyr::filter(.data$source_origin_iso3 != .data$origin_iso3) |>
    dplyr::distinct(
      geodist_source_iso3 = .data$source_origin_iso3,
      origin_iso3 = .data$origin_iso3
    ) |>
    dplyr::arrange(.data$origin_iso3, .data$geodist_source_iso3)

  write_csv_safe(
    harmonization_audit,
    fs::path(cfg$paths$interim, "geodist_iso_harmonization.csv")
  )

  choose_distance <- function(distance, preferred) {
    valid_preferred <- distance[preferred & is.finite(distance) & distance > 0]
    if (length(valid_preferred) > 0L) return(valid_preferred[[1]])
    valid_any <- distance[is.finite(distance) & distance > 0]
    if (length(valid_any) > 0L) return(valid_any[[1]])
    NA_real_
  }

  max_binary_or_na <- function(x) {
    if (all(is.na(x))) return(NA_integer_)
    as.integer(max(x, na.rm = TRUE))
  }

  result <- raw_dyads |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      distw_km = choose_distance(.data$distw_km, .data$origin_to_brazil),
      distcap_km = choose_distance(.data$distcap_km, .data$origin_to_brazil),
      dist_km = choose_distance(.data$dist_km, .data$origin_to_brazil),
      contig = max_binary_or_na(.data$contig),
      common_official_language = max_binary_or_na(.data$common_official_language),
      colonial_link = max_binary_or_na(.data$colonial_direction),
      geodist_directions = dplyr::n_distinct(paste(.data$iso_o, .data$iso_d)),
      geodist_source_iso3 = paste(
        sort(unique(.data$source_origin_iso3)),
        collapse = ";"
      ),
      geodist_harmonized = as.integer(
        any(.data$source_origin_iso3 != .data$origin_iso3)
      ),
      geodist_distance_measure = "distw",
      .groups = "drop"
    ) |>
    dplyr::mutate(
      log_distw = safe_log(.data$distw_km),
      log_distcap = safe_log(.data$distcap_km),
      log_dist = safe_log(.data$dist_km),
      # Backward-compatible aliases remain strict aliases of distw.
      distance_km = .data$distw_km,
      log_distance = .data$log_distw
    ) |>
    dplyr::arrange(.data$origin_iso3)

  missing_origins <- setdiff(origins, result$origin_iso3)
  missing_table <- tibble::tibble(origin_iso3 = sort(missing_origins))
  write_csv_safe(
    missing_table,
    fs::path(cfg$paths$interim, "geodist_missing_origins.csv")
  )
  if (length(missing_origins) > 0L) {
    warning("GeoDist sem correspondência para: ", paste(missing_origins, collapse = ", "))
  }
  if (nrow(result) == 0L || all(is.na(result$distw_km))) {
    stop("No valid distw between the origins and Brazil was found in GeoDist.")
  }
  assert_unique_key(result, "origin_iso3", "Brazil GeoDist slice")
  write_csv_safe(result, fs::path(cfg$paths$interim, "geodist_brazil.csv"))
  result
}
