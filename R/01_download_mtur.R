download_mtur_resources <- function(cfg) {
  raw_dir <- cfg$paths$mtur_raw
  fs::dir_create(raw_dir, recurse = TRUE)

  existing <- fs::dir_ls(
    raw_dir,
    recurse = TRUE,
    regexp = "\\.(csv|txt|xls|xlsx)$",
    type = "file",
    fail = FALSE
  )

  if (!isTRUE(cfg$data_options$download_mtur)) {
    if (length(existing) == 0L) {
      stop("No MTur files found. Put CSV/XLSX files in ", raw_dir,
           " or set data_options.download_mtur: true.")
    }
    return(existing)
  }

  api <- "https://dados.turismo.gov.br/api/3/action/package_show"
  response <- try(
    httr2::request(api) |>
      httr2::req_url_query(id = "chegada-de-turistas-internacionais") |>
      httr2::req_retry(max_tries = 3L) |>
      httr2::req_perform(),
    silent = TRUE
  )

  if (inherits(response, "try-error")) {
    if (length(existing) > 0L) {
      warning("MTur API was unavailable; using local files already present.")
      return(existing)
    }
    stop(
      "MTur API was unavailable. Download the resources manually from ",
      "https://dados.turismo.gov.br/pt_BR/dataset/chegada-de-turistas-internacionais ",
      "and save them in ", raw_dir, "."
    )
  }

  payload <- httr2::resp_body_json(response, simplifyVector = FALSE)
  resources <- payload$result$resources
  if (length(resources) == 0L) stop("The MTur CKAN package contains no resources.")

  selected <- purrr::keep(resources, function(x) {
    format <- tolower(x$format %||% fs::path_ext(x$url %||% ""))
    label <- paste(x$name %||% "", x$description %||% "", x$url %||% "")
    years <- suppressWarnings(as.integer(stringr::str_extract_all(label, "(?:19|20)\\d{2}")[[1]]))
    relevant_year <- length(years) == 0L || any(years >= cfg$project$start_year & years <= cfg$project$end_year)
    format %in% c("csv", "txt", "xls", "xlsx", "zip") && relevant_year
  })

  if (length(selected) == 0L) stop("No usable MTur tabular resources were identified.")

  purrr::walk(selected, function(resource) {
    extension <- tolower(resource$format %||% fs::path_ext(resource$url))
    if (!extension %in% c("csv", "txt", "xls", "xlsx", "zip")) extension <- "csv"
    base_name <- resource$name %||% resource$id %||% paste0("mtur_", sample.int(1e6, 1))
    safe_name <- normalize_text(base_name) |>
      stringr::str_replace_all("[^a-z0-9]+", "_") |>
      stringr::str_remove("^_+|_+$")
    destination <- fs::path(raw_dir, paste0(safe_name, ".", extension))
    if (!file.exists(destination)) {
      message("Downloading MTur resource: ", base_name)
      try(
        httr2::request(resource$url) |>
          httr2::req_retry(max_tries = 3L) |>
          httr2::req_perform(path = destination),
        silent = TRUE
      )
    }
    if (file.exists(destination) && extension == "zip") {
      utils::unzip(destination, exdir = fs::path(raw_dir, safe_name))
    }
  })

  files <- fs::dir_ls(
    raw_dir,
    recurse = TRUE,
    regexp = "\\.(csv|txt|xls|xlsx)$",
    type = "file",
    fail = FALSE
  )
  if (length(files) == 0L) stop("Downloads finished but no readable MTur table was found.")
  files
}
