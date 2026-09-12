# tourism-gravity-brazil

Research compendium for the working paper:

> **Distance, Connectivity, and Price Competitiveness: A Gravity-Based Analysis
> of International Tourism Demand for Brazil**
> Valber Gregory Barbosa Costa Bezerra Santos (UFAL / TJAL)

Reproducible, R-only pipeline ({targets} + {renv}) that builds a monthly
origin-country panel of international tourist arrivals to Brazil (2000–2025,
87 origins in the estimation sample), merges it with distance, air
connectivity and relative-price indicators, and estimates gravity models by
PPML with fixed effects, plus robustness and leave-one-out diagnostics.

**Status (2026-09):** estimation completed and audited; study in
progress. The tables and figures in `output/` are the pipeline's official
and are **not** part of this repository.

![R](https://img.shields.io/badge/R-4.4-276DC3?logo=r) ![targets](https://img.shields.io/badge/pipeline-targets-1f6b73) ![License](https://img.shields.io/badge/code-MIT-green)

## Data sources (all public)

| Source | Content | Access |
|---|---|---|
| Ministério do Turismo / Embratur — *Chegada de turistas internacionais* | arrivals by origin country, access mode and month, 2000–2025 | open-data portal (CKAN), downloaded by `R/01_download_mtur.R` |
| ANAC — *Dados Estatísticos do Transporte Aéreo* | flights, seats, passengers and direct-service indicator by country-month | R package `flightsbr`, consolidated by `R/05_prepare_connectivity.R` |
| CEPII GeoDist | bilateral distances (`distw`) | R package `cepiigeodist` |
| World Bank WDI | GDP per capita, population, CPI, exchange rate, price level | R package `WDI`, `R/03_download_macro.R` |

Raw files are **not versioned** (`data/raw/**` in `.gitignore`); the pipeline
rebuilds them. See `data/raw/README.md` for the exact provenance of each file.
The processed panel (`data/processed/`) and intermediate audits are versioned
because they are small and fully reproducible.

## Structure

```
.
├── _targets.R            # pipeline definition (targets)
├── config.yml            # sample contract, paths, options
├── R/                    # pipeline functions, numbered by stage (00 → 13)
├── scripts/              # executable scripts (Console / Background Jobs)
├── data/
│   ├── raw/              # external sources (not versioned; README documents them)
│   ├── interim/          # cleaned sources and audit tables
│   └── processed/        # estimation panel
├── output/
│   ├── tables/           # .tex / .html / .csv tables consumed by the study
│   ├── figures/          # .png / .pdf figures
│   └── audit/            # sample contract, coverage and diagnostics
├── notes/                # key results with their source file and column
├── logs/                 # execution and audit reports
├── renv.lock             # locked package versions
└── GUIA_EXECUCAO_ECONOMETRIA.md, NOTA_*.md, PLANO_*.md   # working notes (pt-BR)
```

## How to reproduce

Requirements: R ≥ 4.4, RStudio (optional), internet access for the first run.

```r
# in the project root (tourism-gravity.Rproj)
renv::restore()                       # locked dependencies
source("scripts/00_diagnostico_inicial.R")   # environment check
targets::tar_make()                   # full pipeline (run as a Background Job)
targets::tar_outdated()               # should return character(0)
```

Stage-by-stage instructions (in Portuguese) are in
`GUIA_EXECUCAO_ECONOMETRIA.md`. The estimation sample is protected by an
explicit contract in `config.yml` (`expected_main_rows`, `expected_main_origins`);
the pipeline stops if the sample changes silently.

## Scientific rule

No result, significance level or elasticity is written into the study
before it is produced and audited by this pipeline. `notes/article_key_results.md`
lists every number used in the text with its source file and column.

## Licence

Code: MIT (see `LICENSE`). Data remain under their providers' terms — see
`LICENSING.md`. Please cite the working paper when using the pipeline.

Related: personal research page at <https://valbergregory.github.io/pesquisa/tourism-gravity-brazil/>.
