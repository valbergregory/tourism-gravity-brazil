source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/10_diagnosticos_visuais.txt", {
  required <- c(
    "targets", "tidyselect", "readr", "ggdist", "gt", "patchwork"
  )
  missing <- required[
    !vapply(required, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    stop(
      "Pacotes ausentes: ", paste(missing, collapse = ", "),
      ". No Terminal, execute: Rscript scripts/00_instalar_pacotes_visuais.R"
    )
  }

  with_pipeline_lock({
    cat(
      "Gerando testes, tabelas e figuras adicionais.\n",
      "A análise leave-one-origin-out reestima 87 modelos e pode demorar.\n"
    )
    targets::tar_make(
      names = tidyselect::any_of("diagnostic_files")
    )
  })

  files <- targets::tar_read_raw(name = "diagnostic_files")
  formal_tests <- readr::read_csv(
    "output/tables/formal_specification_tests.csv",
    show_col_types = FALSE
  )
  fit_diagnostics <- readr::read_csv(
    "output/tables/model_fit_diagnostics.csv",
    show_col_types = FALSE
  )
  post_slopes <- formal_tests[
    grepl("^Post-reopening .* slope is zero$", formal_tests$test),
  ]
  stopifnot(
    nrow(formal_tests) == 12L,
    nrow(post_slopes) == 2L,
    all(is.finite(post_slopes$estimate)),
    all(is.finite(post_slopes$std_error)),
    all(is.finite(post_slopes$p_value)),
    !any(c("log_likelihood", "deviance") %in% names(fit_diagnostics)),
    all(file.exists(files))
  )

  cat(
    "\nVALIDAÇÃO FINAL\n",
    "- 12 testes formais, incluindo duas inclinações totais pós-reabertura.\n",
    "- tabela de ajuste sem colunas vazias.\n",
    "- todos os produtos diagnósticos existem.\n"
  )
  cat("\nDIAGNÓSTICOS E FIGURAS EXPORTADOS\n")
  cat(paste0("- ", files, collapse = "\n"), "\n")
})
