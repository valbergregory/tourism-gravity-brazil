source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/00_diagnostico_inicial.txt", {
  required_files <- c(
    "tourism-gravity.Rproj", "config.yml", "_targets.R", "renv_bootstrap.R",
    "R/00_setup.R", "R/01_download_mtur.R", "R/02_clean_mtur.R"
  )
  missing_files <- required_files[!file.exists(required_files)]
  if (length(missing_files) > 0L) {
    stop("Arquivos obrigatórios ausentes: ", paste(missing_files, collapse = ", "))
  }

  code_files <- c(
    "renv_bootstrap.R", "_targets.R", "run_pipeline.R",
    list.files("R", pattern = "[.]R$", full.names = TRUE)
  )
  forbidden_hits <- unlist(lapply(code_files, function(path) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    hit <- grep("utils::package_version[[:space:]]*\\(|package_version[[:space:]]*\\(", lines)
    if (length(hit) == 0L) return(character())
    paste0(path, ":", hit, ": ", lines[hit])
  }), use.names = FALSE)
  if (length(forbidden_hits) > 0L) {
    stop(
      "Foi encontrada a chamada incompatível package_version no código:\n",
      paste(forbidden_hits, collapse = "\n")
    )
  }

  required_packages <- c(
    "arrow", "countrycode", "DBI", "duckdb", "fixest", "fs", "glue",
    "here", "httr2", "janitor", "jsonlite", "lubridate", "modelsummary",
    "patchwork", "readr", "readxl", "rlang", "scales", "stringi", "stringr",
    "targets", "tarchetypes", "tidyr", "dplyr", "ggplot2", "purrr", "tibble",
    "broom", "WDI", "yaml", "zoo"
  )
  installed <- rownames(installed.packages())
  missing_packages <- setdiff(required_packages, installed)
  if (length(missing_packages) > 0L) {
    stop(
      "Pacotes ausentes: ", paste(missing_packages, collapse = ", "),
      ". Execute source('renv_bootstrap.R') e reinicie o R."
    )
  }

  if (!"countryname" %in% getNamespaceExports("countrycode")) {
    stop(
      "O pacote countrycode instalado não exporta countryname(). ",
      "Execute source('renv_bootstrap.R') e reinicie o R."
    )
  }

  cfg <- yaml::read_yaml("config.yml")
  if (!identical(as.integer(cfg$project$end_year), 2025L)) {
    stop("config.yml deve terminar em 2025; valor encontrado: ", cfg$project$end_year)
  }

  raw_files <- list.files(
    cfg$paths$mtur_raw,
    pattern = "[.](csv|txt|xls|xlsx)$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  raw_bytes <- if (length(raw_files) == 0L) 0 else sum(file.info(raw_files)$size, na.rm = TRUE)

  manifest <- targets::tar_manifest()
  required_targets <- c("mtur_files", "arrivals")
  missing_targets <- setdiff(required_targets, manifest$name)
  if (length(missing_targets) > 0L) {
    stop("Alvos ausentes do manifesto: ", paste(missing_targets, collapse = ", "))
  }

  cat("R:", R.version.string, "\n")
  cat("Arquitetura:", R.version$arch, "\n")
  cat("Bibliotecas:\n", paste(.libPaths(), collapse = "\n"), "\n")
  cat("Pacotes obrigatórios:", length(required_packages), "instalados\n")
  cat("countrycode::countryname: disponível\n")
  cat("Expressão package_version incompatível: ausente\n")
  cat("Arquivos brutos MTur locais:", length(raw_files), "\n")
  cat("Tamanho bruto MTur:", round(raw_bytes / 1024^2, 2), "MB\n")
  cat("Alvos do pipeline:", paste(manifest$name, collapse = ", "), "\n")
  cat("\nDIAGNÓSTICO INICIAL APROVADO\n")
})
