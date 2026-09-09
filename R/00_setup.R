options(
  stringsAsFactors = FALSE,
  scipen = 999,
  dplyr.summarise.inform = FALSE,
  width = 120
)

Sys.setenv(TZ = "UTC")

required_packages <- c(
  "arrow", "cepiigeodist", "countrycode", "DBI", "duckdb", "fixest", "fs", "glue",
  "here", "httr2", "janitor", "jsonlite", "lubridate", "modelsummary",
  "patchwork", "readr", "readxl", "rlang", "scales", "stringi", "stringr", "targets",
  "tarchetypes", "tidyr", "tidyselect", "dplyr", "ggplot2", "purrr", "tibble",
  "broom", "WDI", "yaml", "zoo"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    "Missing packages: ", paste(missing_packages, collapse = ", "),
    ". Run source('renv_bootstrap.R') first."
  )
}

if (!"countryname" %in% getNamespaceExports("countrycode")) {
  stop(
    "The installed countrycode package does not export countryname(), which is ",
    "required for multilingual country-name matching. Run Rscript renv_bootstrap.R ",
    "and restart R."
  )
}

invisible(lapply(required_packages, library, character.only = TRUE))

set.seed(20260830)

source("R/config.R")
source("R/utils.R")

ensure_project_directories(CFG)
