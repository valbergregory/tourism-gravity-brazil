source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/09_exportacao_resultados.txt", {
  required <- c("targets", "tidyselect")
  missing <- required[
    !vapply(required, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    stop("Pacotes ausentes: ", paste(missing, collapse = ", "))
  }

  with_pipeline_lock({
    cat("Exportando tabelas e figuras depois da auditoria dos modelos.\n")
    targets::tar_make(names = tidyselect::any_of("model_files"))
  })

  files <- targets::tar_read_raw(name = "model_files")
  cat("\nARQUIVOS EXPORTADOS\n")
  cat(paste0("- ", files, collapse = "\n"), "\n")
})
