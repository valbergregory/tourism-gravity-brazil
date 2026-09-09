if (!file.exists("renv.lock") || !file.exists("_targets.R")) {
  stop(
    "Execute este script na raiz do projeto r-project.",
    call. = FALSE
  )
}

if (!requireNamespace("renv", quietly = TRUE)) {
  stop(
    "O pacote renv não está disponível. Restaure primeiro o ambiente do projeto.",
    call. = FALSE
  )
}

visual_packages <- c("ggdist", "gt", "patchwork")
missing <- visual_packages[
  !vapply(visual_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing) > 0L) {
  message("Instalando: ", paste(missing, collapse = ", "))
  renv::install(missing)
} else {
  message("ggdist, gt e patchwork já estão instalados no ambiente do projeto.")
}

renv::snapshot(prompt = FALSE)
message("Instalação e renv.lock atualizados com sucesso.")
