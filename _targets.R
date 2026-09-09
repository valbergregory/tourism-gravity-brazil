source("R/00_setup.R")
purrr::walk(
  list.files("R", pattern = "^(0[1-9]|1[0-3])_.*\\.R$", full.names = TRUE),
  source
)

targets::tar_option_set(packages = required_packages, seed = 20260830)

list(
  targets::tar_target(config_file, "config.yml", format = "file"),
  targets::tar_target(cfg, read_project_config(config_file)),
  targets::tar_target(mtur_files, download_mtur_resources(cfg), format = "file"),
  targets::tar_target(arrivals, clean_mtur_arrivals(mtur_files, cfg)),
  targets::tar_target(origins, sort(unique(stats::na.omit(arrivals$origin_iso3)))),
  targets::tar_target(macro, download_macro_data(origins, cfg)),
  targets::tar_target(geodist, prepare_geodist(origins, cfg)),
  targets::tar_target(connectivity, prepare_connectivity(cfg)),
  targets::tar_target(visa, prepare_visa(origins, cfg)),
  targets::tar_target(panels, build_analysis_panels(arrivals, macro, geodist, connectivity, visa, cfg)),
  targets::tar_target(descriptive_files, make_descriptives(panels$total, cfg), format = "file"),
  targets::tar_target(econometric_sample, build_econometric_sample(panels$total, cfg)),
  targets::tar_target(
    sample_freeze_files,
    write_frozen_econometric_sample(econometric_sample, cfg),
    format = "file"
  ),
  targets::tar_target(
    main_models,
    run_main_models(econometric_sample, sample_freeze_files, cfg)
  ),
  targets::tar_target(
    robustness_models,
    run_robustness_models(
      panels$total, panels$access, econometric_sample,
      sample_freeze_files, cfg
    )
  ),
  targets::tar_target(
    model_audit_files,
    audit_model_results(main_models, robustness_models, cfg),
    format = "file"
  ),
  targets::tar_target(structural_extension, run_structural_extension(cfg)),
  targets::tar_target(
    model_files,
    export_model_outputs(
      main_models, robustness_models, model_audit_files, cfg
    ),
    format = "file"
  ),
  targets::tar_target(
    origin_influence,
    run_origin_leave_one_out(econometric_sample, main_models)
  ),
  targets::tar_target(
    diagnostic_files,
    export_extended_diagnostics(
      econometric_sample, main_models, robustness_models,
      origin_influence, model_audit_files, cfg
    ),
    format = "file"
  )
)
