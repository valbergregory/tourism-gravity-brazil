source("scripts/_helpers.R")
assert_project_root()

output_path <- "logs/diagnostico_erro.txt"
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

report <- character()
add <- function(...) {
  report <<- c(report, paste0(...))
}
add_section <- function(title, expression) {
  add("", paste0("===== ", title, " ====="))
  captured <- tryCatch(
    capture.output(force(expression)),
    error = function(error) paste("Falhou ao coletar esta seção:", conditionMessage(error))
  )
  report <<- c(report, captured)
}

add("DIAGNÓSTICO DO PROJETO TOURISM-GRAVITY")
add("Gerado em: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"))
add("Diretório: ", normalizePath(getwd(), winslash = "/", mustWork = FALSE))
add("R: ", R.version.string)
add("Plataforma: ", R.version$platform)

add_section("ARQUIVOS ESSENCIAIS", {
  essential <- c(
    "tourism-gravity.Rproj", "config.yml", "_targets.R", "renv_bootstrap.R",
    "R/00_setup.R", "R/01_download_mtur.R", "R/02_clean_mtur.R"
  )
  print(data.frame(file = essential, exists = file.exists(essential)), row.names = FALSE)
})

add_section("BIBLIOTECAS DO R", print(.libPaths()))

add_section("PACOTES OBRIGATÓRIOS", {
  required <- c(
    "renv", "targets", "cepiigeodist", "countrycode", "dplyr", "readr", "readxl", "arrow",
    "httr2", "janitor", "stringr", "stringi", "yaml", "fixest"
  )
  ip <- installed.packages()
  installed_flag <- required %in% rownames(ip)
  installed_version <- rep(NA_character_, length(required))
  installed_version[installed_flag] <- ip[required[installed_flag], "Version"]
  table <- data.frame(
    package = required,
    installed = installed_flag,
    version = installed_version
  )
  print(table, row.names = FALSE)
  cat("countryname exportado: ",
      requireNamespace("countrycode", quietly = TRUE) &&
        "countryname" %in% getNamespaceExports("countrycode"), "\n", sep = "")
})

add_section("BUSCA POR PACKAGE_VERSION INCOMPATÍVEL", {
  code_files <- c(
    "renv_bootstrap.R", "_targets.R", "run_pipeline.R",
    list.files("R", pattern = "[.]R$", full.names = TRUE)
  )
  hits <- unlist(lapply(code_files, function(path) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    index <- grep("utils::package_version[[:space:]]*\\(|package_version[[:space:]]*\\(", lines)
    if (length(index) == 0L) return(character())
    paste0(path, ":", index, ": ", lines[index])
  }), use.names = FALSE)
  if (length(hits) == 0L) cat("Nenhuma ocorrência encontrada.\n") else cat(hits, sep = "\n")
})

add_section("STATUS DO RENV", {
  if (requireNamespace("renv", quietly = TRUE)) {
    renv::status()
  } else {
    cat("renv não instalado.\n")
  }
})

add_section("METADADOS DO TARGETS", {
  if (requireNamespace("targets", quietly = TRUE)) {
    meta <- targets::tar_meta()
    fields <- intersect(c("name", "type", "seconds", "warnings", "error"), names(meta))
    print(meta[fields], n = Inf)
  } else {
    cat("targets não instalado.\n")
  }
})

add_section("ÚLTIMAS LINHAS DOS LOGS", {
  logs <- c(
    "logs/00_diagnostico_inicial.txt",
    "logs/01_execucao_mtur.txt",
    "logs/02_auditoria_mtur.txt",
    "logs/02b_preparacao_geodist.txt",
    "logs/03_construcao_painel.txt",
    "logs/04_auditoria_painel.txt",
    "logs/03_execucao_pipeline.txt"
  )
  for (path in logs[file.exists(logs)]) {
    cat("\n--- ", path, " ---\n", sep = "")
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    cat(utils::tail(lines, 120L), sep = "\n")
    cat("\n")
  }
})

add_section("SESSIONINFO", print(sessionInfo()))

writeLines(report, output_path, useBytes = TRUE)
cat("Diagnóstico criado em:", normalizePath(output_path, winslash = "/", mustWork = TRUE), "\n")
