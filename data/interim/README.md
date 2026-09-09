# data/interim — produtos intermediários reproduzíveis

Esta pasta contém saídas intermediárias do pipeline `{targets}` e da rotina de
download da ANAC. **Nada aqui é resultado final**: todos os arquivos são
recriados pelo código a partir de `data/raw/` e das fontes online, por isso a
pasta **não é versionada** (regra `data/interim/**` no `.gitignore` da raiz;
apenas `README.md` e `LEIA-ME.md` entram no Git).

Os produtos **congelados** que o repositório disponibiliza ficam em
`data/processed/` (versionada):

| Arquivo em `data/processed/` | Gerado por | Alvo em `_targets.R` |
|---|---|---|
| `tourism_panel_monthly.parquet` | `build_analysis_panels()` em `R/07_build_panel.R` | `panels` |
| `tourism_panel_access_monthly.parquet` | idem | `panels` |
| `econometric_sample_gdp_pli_distw.parquet` | `write_frozen_econometric_sample()` em `R/09_models.R` | `sample_freeze_files` |

## Arquivos desta pasta e quem os gera

| Arquivo | Gerado por | Alvo | Conteúdo |
|---|---|---|---|
| `mtur_arrivals_clean.parquet` | `R/02_clean_mtur.R` | `arrivals` | Chegadas MTur limpas e harmonizadas (ISO3, mês, via de acesso) |
| `excluded_mtur_aggregate_rows.csv` | `R/02_clean_mtur.R` | `arrivals` | Linhas agregadas (totais/regiões) excluídas da base |
| `unmatched_mtur_countries.csv` | `R/02_clean_mtur.R` | `arrivals` | Rótulos de país sem correspondência ISO3 |
| `mtur_source_conflicts.csv` | `R/02_clean_mtur.R` | `arrivals` | Conflitos entre versões de um mesmo período na fonte |
| `wdi_macro.parquet` | `R/03_download_macro.R` | `macro` | Indicadores WDI brutos por país-ano |
| `wdi_macro_quality.csv` | `R/03_download_macro.R` | `macro` | Diagnóstico de cobertura/interpolação dos indicadores |
| `geodist_brazil.csv` | `R/04_prepare_geodist.R` | `geodist` | Distâncias CEPII de cada origem para o Brasil (`distw`, `dist`, `distcap`) |
| `geodist_iso_harmonization.csv` | `R/04_prepare_geodist.R` | `geodist` | Harmonização de códigos ISO entre CEPII e MTur |
| `geodist_missing_origins.csv` | `R/04_prepare_geodist.R` | `geodist` | Origens sem distância no CEPII |
| `connectivity_monthly.parquet` | `R/05_prepare_connectivity.R` | `connectivity` | Conectividade aérea país-mês validada (requer `use_connectivity: true`) |
| `visa_monthly.parquet` | `R/06_prepare_visa.R` | `visa` | Regimes de visto mensalizados; só existe se `use_visa: true` (hoje `false`) |
| `origin_sample_flags.csv` | `R/07_build_panel.R` | `panels` | Flags de amostra por origem (`sample_broad_5y`, `sample_core_2000` etc.) |
| `anac_monthly_chunks/anac_AAAAMM.csv` | `scripts/05d_baixar_anac_completo.R` (via `R/anac_download_helpers.R`) | fora do `{targets}` | Checkpoints mensais de download da ANAC (ver abaixo) |

Os três CSVs de auditoria do MTur (`excluded_*`, `unmatched_*`,
`mtur_source_conflicts.csv`) são lidos por `scripts/02_auditar_mtur.R`, que
gera o relatório em `logs/02_auditoria_mtur.txt`.

## Chunks mensais da ANAC são checkpoints de download

`data/interim/anac_monthly_chunks/` recebe um CSV por mês de referência
(`anac_200001.csv` … `anac_202512.csv`, 312 arquivos, ~5 MB no total). Cada
um é gravado atomicamente por `scripts/05d_baixar_anac_completo.R` depois de
baixar e agregar os microdados daquele mês com `flightsbr::read_flights()`.
Ao reexecutar o script, cada chunk é testado por `anac_chunk_is_valid()`;
os válidos são reutilizados e só os meses pendentes são baixados. Quando os
312 meses estão válidos, o script os consolida em
`data/raw/anac/anac_connectivity_monthly.csv`, que é o único arquivo ANAC
lido pelo pipeline. Os chunks servem apenas para retomar downloads
interrompidos e podem ser apagados sem perda, ao custo de refazer o download.

## Como recriar esta pasta

Na raiz do projeto (`r-project/`), com o ambiente restaurado por
`Rscript -e "renv::restore(prompt = FALSE)"`:

- tudo que pertence ao `{targets}`: `Rscript run_pipeline.R`
  (ou `targets::tar_make(callr_function = NULL)`), ou os scripts por etapa em
  `scripts/` (`01_executar_mtur.R`, `02b_preparar_geodist.R`,
  `03_construir_painel.R`, `06_integrar_anac_painel.R`, …);
- chunks da ANAC: `scripts/05d_baixar_anac_completo.R` como *Background Job*
  no RStudio (etapa longa), seguido de `scripts/05e_auditar_anac_completo.R`.

Os caminhos desta pasta são definidos em `config.yml` (`paths.interim`); as
funções `write_csv_safe()` e `write_parquet_safe()` em `R/utils.R` fazem as
gravações. Não edite estes arquivos manualmente: qualquer correção deve ser
feita no código e reexecutada.
