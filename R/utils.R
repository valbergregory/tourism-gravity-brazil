`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L || all(is.na(x))) y else x
}

ensure_project_directories <- function(cfg) {
  dirs <- unlist(cfg$paths, use.names = FALSE)
  invisible(lapply(dirs, fs::dir_create, recurse = TRUE))
}

normalize_text <- function(x) {
  x |>
    as.character() |>
    stringi::stri_trans_general("Latin-ASCII") |>
    stringr::str_to_lower() |>
    stringr::str_squish()
}

parse_number_br <- function(x) {
  readr::parse_number(
    as.character(x),
    locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
    na = c("", "NA", "N/A", "-", "..", "...")
  )
}

first_existing_column <- function(data, patterns, required = TRUE) {
  candidates <- names(data)
  hit <- purrr::detect(candidates, function(nm) {
    any(stringr::str_detect(nm, patterns))
  })

  missing_hit <- is.null(hit) || length(hit) != 1L || is.na(hit) || !nzchar(hit)
  if (missing_hit) {
    if (required) {
      stop(
        "Could not identify a column matching: ",
        paste(patterns, collapse = " | "),
        ". Available columns: ", paste(candidates, collapse = ", ")
      )
    }
    return(NULL)
  }

  as.character(hit)
}

read_delimited_flexibly <- function(path) {
  guessed <- try(
    suppressWarnings(readr::guess_encoding(path, n_max = 10000L)),
    silent = TRUE
  )
  guessed_encodings <- if (inherits(guessed, "try-error") || nrow(guessed) == 0L) {
    character()
  } else {
    guessed$encoding
  }
  encodings <- unique(c(guessed_encodings, "UTF-8", "Windows-1252", "ISO-8859-1"))
  delimiters <- c(";", ",", "\t")

  for (encoding in encodings) {
    for (delimiter in delimiters) {
      attempt <- try(
        readr::read_delim(
          path,
          delim = delimiter,
          locale = readr::locale(encoding = encoding),
          show_col_types = FALSE,
          progress = FALSE,
          trim_ws = TRUE,
          name_repair = "unique"
        ),
        silent = TRUE
      )

      invalid_names <- !inherits(attempt, "try-error") &&
        any(stringr::str_detect(names(attempt), "\uFFFD"))
      if (!inherits(attempt, "try-error") && ncol(attempt) >= 3L && !invalid_names) {
        return(janitor::clean_names(attempt))
      }
    }
  }

  stop("Unable to read file with supported delimiters/encodings: ", path)
}

read_tabular_flexibly <- function(path) {
  extension <- tolower(fs::path_ext(path))
  if (extension %in% c("xls", "xlsx")) {
    return(janitor::clean_names(readxl::read_excel(path)))
  }
  read_delimited_flexibly(path)
}

empty_connectivity_table <- function() {
  tibble::tibble(
    origin_iso3 = character(), date = as.Date(character()),
    direct = integer(), flights = double(), seats = double(), passengers = double()
  )
}

empty_visa_table <- function() {
  tibble::tibble(
    origin_iso3 = character(), date = as.Date(character()),
    visa_required = integer(), evisa = integer(), visa_free = integer()
  )
}

write_placeholder_tex <- function(path, message) {
  fs::dir_create(fs::path_dir(path), recurse = TRUE)
  escaped <- stringr::str_replace_all(message, "_", "\\\\_")
  writeLines(
    c("\\begin{center}", paste0("\\fbox{\\parbox{0.90\\linewidth}{", escaped, "}}"), "\\end{center}"),
    path,
    useBytes = TRUE
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

safe_log <- function(x) {
  ifelse(is.na(x) | x <= 0, NA_real_, log(x))
}

log1p_zero_safe <- function(x) {
  ifelse(is.na(x) | x < 0, NA_real_, log1p(x))
}

assert_unique_key <- function(data, keys, object_name = deparse(substitute(data))) {
  duplicates <- data |>
    dplyr::count(dplyr::across(dplyr::all_of(keys)), name = "n") |>
    dplyr::filter(.data$n > 1L)

  if (nrow(duplicates) > 0L) {
    stop(object_name, " has duplicate keys: ", paste(keys, collapse = " + "))
  }

  invisible(data)
}

assert_nonnegative <- function(x, name) {
  if (any(x < 0, na.rm = TRUE)) stop(name, " contains negative values.")
  invisible(x)
}

write_parquet_safe <- function(data, path) {
  fs::dir_create(fs::path_dir(path), recurse = TRUE)
  arrow::write_parquet(data, path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_csv_safe <- function(data, path) {
  fs::dir_create(fs::path_dir(path), recurse = TRUE)
  readr::write_csv(data, path, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

rebase_index <- function(x, year, base_year) {
  base <- mean(x[year == base_year], na.rm = TRUE)
  if (!is.finite(base) || base == 0) return(rep(NA_real_, length(x)))
  100 * x / base
}

month_number_pt_en <- function(x) {
  cleaned <- normalize_text(x)
  lookup <- c(
    janeiro = 1L, january = 1L, jan = 1L,
    fevereiro = 2L, february = 2L, fev = 2L, feb = 2L,
    marco = 3L, march = 3L, mar = 3L,
    abril = 4L, april = 4L, abr = 4L, apr = 4L,
    maio = 5L, may = 5L,
    junho = 6L, june = 6L, jun = 6L,
    julho = 7L, july = 7L, jul = 7L,
    agosto = 8L, august = 8L, ago = 8L, aug = 8L,
    setembro = 9L, september = 9L, set = 9L, sep = 9L,
    outubro = 10L, october = 10L, out = 10L, oct = 10L,
    novembro = 11L, november = 11L, nov = 11L,
    dezembro = 12L, december = 12L, dez = 12L, dec = 12L
  )

  numeric_month <- suppressWarnings(as.integer(cleaned))
  from_lookup <- unname(lookup[cleaned])
  dplyr::coalesce(numeric_month, as.integer(from_lookup))
}
