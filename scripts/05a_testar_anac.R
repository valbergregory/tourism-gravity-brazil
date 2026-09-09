source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/05a_teste_anac.txt", {

  if (!requireNamespace("flightsbr", quietly = TRUE)) {
    stop(
      "O pacote flightsbr não está instalado. ",
      "Execute renv::install('flightsbr')."
    )
  }

  cat("Baixando um único mês da ANAC para diagnóstico...\n")
  cat("Mês testado: janeiro de 2025\n\n")

  anac_test <- flightsbr::read_flights(
    date = 202501,
    type = "basica",
    showProgress = TRUE,
    cache = TRUE
  )

  cat("\nRESUMO DO TESTE ANAC\n")
  cat("Linhas:", nrow(anac_test), "\n")
  cat("Colunas:", ncol(anac_test), "\n")
  cat("Classes:", paste(class(anac_test), collapse = ", "), "\n")

  cat("\nNOMES DAS COLUNAS\n")
  print(names(anac_test))

  cat("\nPRIMEIRAS TRÊS LINHAS\n")
  print(utils::head(anac_test, 3))

  dir.create(
    "output/audit",
    recursive = TRUE,
    showWarnings = FALSE
  )

  readr::write_csv(
    tibble::as_tibble(utils::head(anac_test, 100)),
    "output/audit/anac_test_202501_first100.csv"
  )

  cat("\nTESTE ANAC CONCLUÍDO\n")
})
