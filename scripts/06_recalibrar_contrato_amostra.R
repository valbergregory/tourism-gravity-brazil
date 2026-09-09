source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/06_recalibracao_contrato_amostra.txt", {
  required <- c("targets", "tidyselect", "dplyr", "readr")
  missing <- required[
    !vapply(required, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    stop("Pacotes ausentes: ", paste(missing, collapse = ", "))
  }

  with_pipeline_lock({
    cat("Reconstruindo a cobertura observada e recalibrando o contrato.\n")
    cat("Execute este script como um único Background Job.\n\n")
    targets::tar_make(
      names = tidyselect::any_of(c("panels", "econometric_sample"))
    )
  })

  sample_object <- targets::tar_read_raw(name = "econometric_sample")
  panel <- targets::tar_read_raw(name = "panels")$total
  summary <- sample_object$summary

  provenance <- panel |>
    dplyr::count(.data$observation_status, name = "rows") |>
    dplyr::mutate(
      share = .data$rows / sum(.data$rows)
    ) |>
    dplyr::arrange(dplyr::desc(.data$rows))

  excluded_completed <- panel |>
    dplyr::filter(.data$all_zero_imputed == 1L) |>
    dplyr::group_by(.data$origin_iso3) |>
    dplyr::summarise(
      first_completed_date = min(.data$date),
      last_completed_date = max(.data$date),
      completed_unobserved_months = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$completed_unobserved_months))

  dir.create("output/audit", recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(
    provenance,
    "output/audit/arrival_observation_provenance.csv",
    na = ""
  )
  readr::write_csv(
    excluded_completed,
    "output/audit/completed_unobserved_months_by_origin.csv",
    na = ""
  )
  readr::write_csv(
    summary,
    "output/audit/corrected_sample_contract_candidate.csv",
    na = ""
  )

  cat("\nPROVENIÊNCIA DO PAINEL\n")
  print(provenance, n = Inf, width = Inf)
  cat("\nCANDIDATO AO NOVO CONTRATO\n")
  print(summary, n = Inf, width = Inf)
  cat("\nORIGENS COM MESES COMPLETADOS NÃO OBSERVADOS\n")
  print(excluded_completed, n = Inf, width = Inf)

  if (!isTRUE(summary$contract_configured[[1L]])) {
    cat(
      "\nAÇÃO NECESSÁRIA\n",
      "Copie rows e origins para expected_main_rows e ",
      "expected_main_origins em config.yml. Depois execute novamente este ",
      "mesmo script. Não estime os modelos antes de contract_ok = TRUE.\n",
      sep = ""
    )
  } else if (!isTRUE(summary$contract_ok[[1L]])) {
    stop(
      "O contrato configurado não coincide com a amostra corrigida. ",
      "Atualize config.yml com os valores impressos acima.",
      call. = FALSE
    )
  } else {
    cat(
      "\nCONTRATO VALIDADO\n",
      "A amostra corrigida pode agora ser congelada e estimada por ",
      "scripts/07_estimar_modelos.R.\n",
      sep = ""
    )
  }
})
