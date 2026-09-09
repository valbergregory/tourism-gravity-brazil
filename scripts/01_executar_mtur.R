source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/01_execucao_mtur.txt", {
  if (!requireNamespace("targets", quietly = TRUE)) {
    stop("O pacote targets não está instalado. Execute source('renv_bootstrap.R').")
  }

  cat("Projeto novo: nenhuma invalidação prévia é necessária.\n")
  cat("Construindo mtur_files e arrivals...\n")

  targets::tar_make(
    names = tidyselect::any_of("arrivals"),
    callr_function = NULL
  )

  arrivals_data <- targets::tar_read_raw(name = "arrivals")
  cat("\nRESUMO IMEDIATO\n")
  cat("Linhas:", nrow(arrivals_data), "\n")
  cat("Colunas:", ncol(arrivals_data), "\n")
  cat("Primeira data:", format(min(arrivals_data$date, na.rm = TRUE)), "\n")
  cat("Última data:", format(max(arrivals_data$date, na.rm = TRUE)), "\n")
  cat("Origens:", length(unique(stats::na.omit(arrivals_data$origin_iso3))), "\n")
  cat("Modais:", paste(sort(unique(arrivals_data$access_mode)), collapse = ", "), "\n")
  cat("\nETAPA MTUR CONCLUÍDA\n")
})
