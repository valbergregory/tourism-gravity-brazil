source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/07_estimacao_modelos.txt", {
  required <- c("targets", "tidyselect")
  missing <- required[
    !vapply(required, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    stop("Pacotes ausentes: ", paste(missing, collapse = ", "))
  }

  with_pipeline_lock({
    cat("Congelando a amostra GDP-PLI/distw e estimando os modelos.\n")
    cat("Este script deve ser executado como um único Background Job.\n\n")
    targets::tar_make(
      names = tidyselect::any_of(c(
        "sample_freeze_files", "main_models", "robustness_models"
      ))
    )
  })

  sample_summary <- targets::tar_read_raw(name = "econometric_sample")$summary
  main_audit <- targets::tar_read_raw(name = "main_models")$audit
  robustness_audit <- targets::tar_read_raw(name = "robustness_models")$audit

  cat("\nAMOSTRA CONGELADA\n")
  print(sample_summary, n = Inf, width = Inf)
  cat("\nMODELOS PRINCIPAIS\n")
  print(main_audit, n = Inf, width = Inf)
  cat("\nROBUSTEZES\n")
  print(robustness_audit, n = Inf, width = Inf)
})
