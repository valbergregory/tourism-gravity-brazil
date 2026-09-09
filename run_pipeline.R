source("R/00_setup.R")

message("Starting the reproducible pipeline...")
targets::tar_make(callr_function = NULL)
message("Pipeline completed. Inspect output/tables and output/figures.")

