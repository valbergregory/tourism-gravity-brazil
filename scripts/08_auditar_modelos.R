source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/08_auditoria_modelos.txt", {
  required <- c("targets", "tidyselect", "readr", "dplyr")
  missing <- required[
    !vapply(required, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    stop("Pacotes ausentes: ", paste(missing, collapse = ", "))
  }

  with_pipeline_lock({
    cat("Gerando auditorias de estimação, convergência e resíduos.\n")
    targets::tar_make(
      names = tidyselect::any_of("model_audit_files")
    )
  })

  audit <- readr::read_csv(
    "output/audit/model_estimation_audit.csv",
    show_col_types = FALSE
  )
  problems <- audit |>
    dplyr::filter(
      .data$convergence_flag == "failed" |
        .data$collinearity_flag |
        .data$warning_flag |
        .data$removed_rows > 0L |
        .data$separation_fe_levels_removed > 0L
    )

  cat("\nRESUMO DA AUDITORIA\n")
  print(audit, n = Inf, width = Inf)
  cat("\nITENS QUE EXIGEM INSPEÇÃO\n")
  if (nrow(problems) == 0L) {
    cat("Nenhum alerta de convergência, colinearidade ou remoção.\n")
  } else {
    print(problems, n = Inf, width = Inf)
  }
})
