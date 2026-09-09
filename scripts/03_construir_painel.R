source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/03_construcao_painel.txt", {
  required <- c("targets", "tidyselect")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    stop("Pacotes ausentes: ", paste(missing, collapse = ", "),
         ". Execute source('renv_bootstrap.R').")
  }

  cat("Construindo somente as dependências necessárias até o alvo panels...\n")
  cat("Esta etapa pode baixar dados WDI; o CEPII será lido do pacote R ou de arquivo local.\n\n")

  targets::tar_make(
    names = tidyselect::any_of("panels")
  )

  panel_objects <- targets::tar_read_raw(name = "panels")
  total <- panel_objects$total
  access <- panel_objects$access

  cat("\nRESUMO IMEDIATO DO PAINEL\n")
  cat("Painel total - linhas:", nrow(total), "\n")
  cat("Painel total - origens:", length(unique(total$origin_iso3)), "\n")
  cat("Painel modal - linhas:", nrow(access), "\n")
  cat("Primeira data:", format(min(total$date, na.rm = TRUE)), "\n")
  cat("Última data:", format(max(total$date, na.rm = TRUE)), "\n")
  cat("\nCONSTRUÇÃO DO PAINEL CONCLUÍDA\n")
})
