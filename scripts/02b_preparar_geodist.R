source("scripts/_helpers.R")
assert_project_root()

run_with_log("logs/02b_preparacao_geodist.txt", {
  if (!requireNamespace("targets", quietly = TRUE)) {
    stop("O pacote targets não está instalado. Execute source('renv_bootstrap.R').")
  }
  if (!requireNamespace("cepiigeodist", quietly = TRUE)) {
    stop("O pacote cepiigeodist não está instalado. Execute source('renv_bootstrap.R').")
  }

  cat("Preparando somente o alvo geodist e suas dependências...\n")
  targets::tar_make(
    names = tidyselect::any_of("geodist")
  )

  geodist_data <- targets::tar_read_raw(name = "geodist")
  origins_data <- targets::tar_read_raw(name = "origins")
  missing_origins <- setdiff(origins_data, geodist_data$origin_iso3)

  cat("\nRESUMO GEODIST\n")
  cat("Origens MTur:", length(origins_data), "\n")
  cat("Origens com GeoDist:", nrow(geodist_data), "\n")
  cat("Origens sem GeoDist:", length(missing_origins), "\n")
  cat("Distância mínima (km):", round(min(geodist_data$distance_km, na.rm = TRUE), 1), "\n")
  cat("Distância máxima (km):", round(max(geodist_data$distance_km, na.rm = TRUE), 1), "\n")
  cat("Fronteiras comuns:", sum(geodist_data$contig == 1L, na.rm = TRUE), "\n")
  cat("Idioma oficial comum:", sum(geodist_data$common_official_language == 1L, na.rm = TRUE), "\n")
  cat("Vínculo colonial bilateral:", sum(geodist_data$colonial_link == 1L, na.rm = TRUE), "\n")
  if (length(missing_origins) > 0L) {
    cat("Códigos sem correspondência:", paste(missing_origins, collapse = ", "), "\n")
  }
  cat("\nETAPA GEODIST CONCLUÍDA\n")
})
