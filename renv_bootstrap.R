required_packages <- c(
  "arrow", "countrycode", "DBI", "duckdb", "fixest", "fs", "glue",
  "here", "httr2", "janitor", "jsonlite", "lubridate", "modelsummary",
  "patchwork", "readr", "readxl", "rlang", "scales", "stringi", "stringr", "targets",
  "tarchetypes", "tidyr", "dplyr", "ggplot2", "purrr", "tibble",
  "broom", "WDI", "yaml", "zoo"
)

options(repos = c(CRAN = "https://cloud.r-project.org"))

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

if (!file.exists("renv.lock")) {
  renv::init(bare = TRUE, restart = FALSE)
} else {
  renv::activate()
}

installed <- rownames(installed.packages())
missing <- setdiff(required_packages, installed)

if (length(missing) > 0L) {
  renv::install(missing)
}

countryname_available <- requireNamespace("countrycode", quietly = TRUE) &&
  "countryname" %in% getNamespaceExports("countrycode")

if (!countryname_available) {
  renv::install("countrycode@1.9.0")
}

countryname_available <- requireNamespace("countrycode", quietly = TRUE) &&
  "countryname" %in% getNamespaceExports("countrycode")

if (!countryname_available) {
  stop(
    "The installed countrycode package does not export countryname(). ",
    "Close RStudio, reopen the project, and run Rscript renv_bootstrap.R again."
  )
}

renv::snapshot(prompt = FALSE)

message("Environment ready. Restart R and run Rscript scripts/00_diagnostico_inicial.R.")
