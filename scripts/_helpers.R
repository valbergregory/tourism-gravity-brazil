assert_project_root <- function() {
  required <- c("_targets.R", "config.yml", "R/00_setup.R")
  missing <- required[!file.exists(required)]
  if (length(missing) > 0L) {
    stop(
      "Execute este script na raiz do projeto r-project. Arquivos ausentes: ",
      paste(missing, collapse = ", "),
      ". Diretório atual: ", getwd(),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

run_with_log <- function(log_path, code) {
  dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
  connection <- file(log_path, open = "wt", encoding = "UTF-8")
  sink(connection, type = "output", split = TRUE)
  sink(connection, type = "message")

  close_log <- function() {
    sink(type = "message")
    sink(type = "output")
    close(connection)
  }
  on.exit(close_log(), add = TRUE)

  cat("Projeto:", normalizePath(getwd(), winslash = "/", mustWork = FALSE), "\n")
  cat("Início:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"), "\n\n")

  error_condition <- NULL
  result <- tryCatch(
    force(code),
    error = function(error) {
      error_condition <<- error
      cat("\nERRO CAPTURADO\n")
      cat(conditionMessage(error), "\n")
      calls <- sys.calls()
      if (length(calls) > 0L) {
        cat("\nPILHA DE CHAMADAS\n")
        print(calls)
      }
      NULL
    }
  )

  cat("\nFim:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"), "\n")
  if (!is.null(error_condition)) {
    stop(error_condition)
  }
  invisible(result)
}

read_csv_if_present <- function(path) {
  if (!file.exists(path)) return(NULL)
  readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
}

assert_targets_idle <- function(store = "_targets") {
  process_path <- file.path(store, "meta", "process")
  if (file.exists(process_path) || dir.exists(process_path)) {
    stop(
      "O targets informa que outro processo pode estar ativo em ",
      normalizePath(process_path, winslash = "/", mustWork = FALSE),
      ". Não inicie um segundo pipeline. Confirme primeiro o Background Job ",
      "em execução. Se não houver job ativo, use no Console: ",
      "targets::tar_unblock_process(store = '_targets').",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

with_pipeline_lock <- function(code, lock_dir = "logs/.targets_pipeline_lock") {
  if (!dir.create(lock_dir, recursive = TRUE, showWarnings = FALSE)) {
    owner_path <- file.path(lock_dir, "owner.txt")
    owner <- if (file.exists(owner_path)) {
      paste(readLines(owner_path, warn = FALSE), collapse = "; ")
    } else {
      "informações do processo indisponíveis"
    }
    stop(
      "Outro script do pipeline já reservou este projeto (", owner, "). ",
      "Aguarde o Background Job terminar antes de executar outro.",
      call. = FALSE
    )
  }
  on.exit(unlink(lock_dir, recursive = TRUE, force = TRUE), add = TRUE)
  writeLines(
    c(
      paste0("pid=", Sys.getpid()),
      paste0("started_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
      paste0("working_directory=", normalizePath(
        getwd(), winslash = "/", mustWork = FALSE
      ))
    ),
    file.path(lock_dir, "owner.txt"),
    useBytes = TRUE
  )
  assert_targets_idle()
  force(code)
}
