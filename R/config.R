read_project_config <- function(path = "config.yml") {
  if (!file.exists(path)) {
    stop("Configuration file not found: ", path)
  }

  cfg <- yaml::read_yaml(path)

  required_sections <- c("project", "paths", "data_options", "econometrics")
  missing_sections <- setdiff(required_sections, names(cfg))
  if (length(missing_sections) > 0L) {
    stop("Missing config sections: ", paste(missing_sections, collapse = ", "))
  }

  required_econometrics <- c(
    "main_sample_flag", "balanced_sample_flag", "main_price",
    "main_distance", "expected_main_rows", "expected_main_origins",
    "excluded_distw_origins", "strict_sample_contract"
  )
  missing_econometrics <- setdiff(required_econometrics, names(cfg$econometrics))
  if (length(missing_econometrics) > 0L) {
    stop(
      "Missing econometrics settings: ",
      paste(missing_econometrics, collapse = ", ")
    )
  }

  cfg
}

CFG <- read_project_config()
