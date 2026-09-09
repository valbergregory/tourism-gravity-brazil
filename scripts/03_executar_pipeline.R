source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/03_execucao_pipeline.txt", {
  if (!requireNamespace("targets", quietly = TRUE)) {
    stop("O pacote targets não está instalado. Execute source('renv_bootstrap.R').")
  }
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("O pacote yaml não está instalado. Execute source('renv_bootstrap.R').")
  }

  cfg <- yaml::read_yaml("config.yml")
  cat("CONFIGURAÇÃO ATIVA\n")
  cat("Conectividade:", isTRUE(cfg$data_options$use_connectivity), "\n")
  cat("Vistos:", isTRUE(cfg$data_options$use_visa), "\n")
  cat("Extensão estrutural:", isTRUE(cfg$data_options$use_structural_extension), "\n\n")

  targets::tar_make(callr_function = NULL)

  cat("\nPIPELINE CONCLUÍDO\n")
  cat("Tabelas:", normalizePath(cfg$paths$tables, winslash = "/", mustWork = FALSE), "\n")
  cat("Figuras:", normalizePath(cfg$paths$figures, winslash = "/", mustWork = FALSE), "\n")
})
