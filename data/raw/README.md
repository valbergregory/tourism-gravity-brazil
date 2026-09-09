# data/raw — fontes externas brutas

Esta pasta guarda as bases de origem do projeto **tourism-gravity** exatamente
como foram obtidas das fontes. Os arquivos de dados **não são versionados no
Git** (regra `data/raw/**` no `.gitignore` da raiz); apenas este `README.md` e
os `LEIA-ME.md` de subpastas entram no repositório. Todo o conteúdo pode ser
reconstruído pelo pipeline, conforme descrito abaixo.

**Regra fixa: nenhum arquivo bruto deve ser editado manualmente.** Correções,
harmonizações e exclusões são feitas exclusivamente no código (`R/`) e ficam
registradas em `data/interim/` e `output/audit/`, de forma auditável.

## 1. Fontes utilizadas

| Subpasta | Fonte | Conteúdo | Uso no pipeline |
|---|---|---|---|
| `mtur/` | Ministério do Turismo / Embratur — dataset *Chegada de turistas internacionais* (portal de dados abertos `dados.turismo.gov.br`, pacote CKAN `chegada-de-turistas-internacionais`) | Um CSV por ano, `2000.csv` … `2025.csv` (chegadas por país de origem, via de acesso e mês) | Alvo `mtur_files` → `arrivals` (`R/01_download_mtur.R`, `R/02_clean_mtur.R`) |
| `anac/` | ANAC — *Dados Estatísticos do Transporte Aéreo* (gov.br/anac, dados abertos), acessados pelo pacote R `flightsbr` (`read_flights(type = "basica")`) | `anac_connectivity_monthly.csv`: conectividade aérea país-mês consolidada (voos, assentos, passageiros, ASK/RPK, indicador de voo direto), 2000-01 a 2025-12 | Alvo `connectivity` (`R/05_prepare_connectivity.R`) |
| `cepii/` | CEPII GeoDist (`dist_cepii`), carregado do pacote R `cepiigeodist` | `dist_cepii_cran.csv` (cache gravado pelo código a partir do pacote); `dist_cepii.zip` (cópia local opcional do arquivo original CEPII) | Alvo `geodist` (`R/04_prepare_geodist.R`); a medida principal é `distw` |
| `visa/` | Regimes de visto (compilação própria) | `visa_regimes.csv` — hoje contém **apenas o cabeçalho** (`origin_iso3, start_date, end_date, visa_required, evisa, visa_free, source_url, notes`) | Alvo `visa` (`R/06_prepare_visa.R`); só é lido se `use_visa: true` |
| `structural/` | Painel multi-destino para a extensão de gravidade estrutural | `multi_destination_panel.csv` — hoje contém **apenas o cabeçalho** | `R/12_structural_gravity_extension.R`; só é lido se `use_structural_extension: true` |

Fonte adicional que **não** passa por esta pasta: os indicadores macroeconômicos
do Banco Mundial (WDI: PIB per capita, população, CPI, câmbio, nível de preços
`PA.NUS.GDP.PLI`, câmbio Atlas `PA.NUS.ATLS`) são baixados em tempo de execução
pelo pacote `WDI` (`R/03_download_macro.R`, alvo `macro`) e gravados diretamente
em `data/interim/wdi_macro.parquet`.

## 2. O que não está no Git

Tudo em `data/raw/` exceto `README.md` e `LEIA-ME.md`. Na versão de referência:

| Arquivo(s) | Tamanho aprox. |
|---|---|
| `mtur/2000.csv` … `mtur/2025.csv` (26 arquivos) | 1,0 a 3,7 MB cada; ~55 MB no total |
| `anac/anac_connectivity_monthly.csv` | 4,1 MB (11 730 linhas país-mês, 118 países/territórios) |
| `cepii/dist_cepii_cran.csv` | 3,5 MB |
| `cepii/dist_cepii.zip` | 0,6 MB |
| `visa/visa_regimes.csv`, `structural/multi_destination_panel.csv` | apenas cabeçalho |

## 3. Scripts e flags responsáveis pelos downloads

| Fonte | Função / script | Flag em `config.yml` |
|---|---|---|
| MTur | `download_mtur_resources()` em `R/01_download_mtur.R`, executada pelo alvo `mtur_files` de `_targets.R`. Atalho: `scripts/01_executar_mtur.R` (constrói `mtur_files` e `arrivals`, log em `logs/01_execucao_mtur.txt`) | `data_options.download_mtur: true` |
| CEPII | `load_cepii_geodist()` em `R/04_prepare_geodist.R`, executada pelo alvo `geodist`. Atalho: `scripts/02b_preparar_geodist.R` | `data_options.download_cepii: true` (usado apenas quando não há arquivo local `dist_cepii*.csv/.xls/.xlsx` ou `.zip`) |
| ANAC | `scripts/05d_baixar_anac_completo.R` (usa `R/anac_download_helpers.R`; log em `logs/05d_download_anac_completo.txt`), seguido de `scripts/05e_auditar_anac_completo.R`. **Não** faz parte de `_targets.R`; é uma rotina separada, executada como *Background Job* no RStudio | `data_options.use_connectivity: true` para que o alvo `connectivity` leia o CSV consolidado |
| WDI | `download_macro_data()` em `R/03_download_macro.R`, alvo `macro` | nenhuma flag (sempre online) |
| Visto | não há download; o CSV é preenchido manualmente | `data_options.use_visa` (hoje `false`) |
| Estrutural | não há download | `data_options.use_structural_extension` (hoje `false`) |

Configuração vigente em `config.yml`: `download_mtur: true`, `download_cepii: true`,
`use_connectivity: true`, `use_visa: false`, `use_structural_extension: false`;
período `start_year: 2000` a `end_year: 2025`.

## 4. Como reconstruir os dados a partir de um clone limpo

Todos os comandos abaixo são executados na raiz do projeto R (`r-project/`),
com o projeto `tourism-gravity.Rproj` aberto (o `.Rprofile` ativa o `renv`).

1. Restaurar o ambiente:

   ```bash
   Rscript -e "renv::restore(prompt = FALSE)"
   ```

2. Conectividade ANAC (etapa longa; várias horas e vários GB de download).
   No RStudio, execute `scripts/05d_baixar_anac_completo.R` como *Background
   Job* com *Working Directory* na raiz do projeto. O script grava um checkpoint
   por mês em `data/interim/anac_monthly_chunks/` e só escreve
   `data/raw/anac/anac_connectivity_monthly.csv` quando os 312 meses
   (2000-01 a 2025-12) estão válidos. Se for interrompido, basta executá-lo de
   novo: os meses concluídos são reutilizados. Depois, rode
   `scripts/05e_auditar_anac_completo.R`.

3. MTur, CEPII, WDI e o restante do pipeline: com as flags acima ativas, o
   `{targets}` baixa o que falta e reconstrói tudo até as tabelas e figuras:

   ```bash
   Rscript run_pipeline.R
   ```

   (equivale a `targets::tar_make(callr_function = NULL)`). Alternativamente,
   os scripts numerados em `scripts/` executam o pipeline por etapas, cada um
   com log em `logs/`.

Se a API do MTur estiver indisponível e a pasta `mtur/` estiver vazia, o
código interrompe com a instrução de baixar manualmente os recursos em
`https://dados.turismo.gov.br/pt_BR/dataset/chegada-de-turistas-internacionais`
e salvá-los em `data/raw/mtur/` (ver também `mtur/LEIA-ME.md`).

## 5. Datas e versões das fontes na versão de referência

| Fonte | Obtida em | Versão / observação |
|---|---|---|
| MTur (26 CSVs anuais) | 2026-08-31 | Recursos vigentes no CKAN naquela data; cobertura 2000–2025 |
| ANAC (`flightsbr` 1.2.0, `type = "basica"`) | download concluído em 2026-09-02 | Módulo ANAC v1.1 (`LEIA-ME_ANAC_COMPLETO_v1.txt` na raiz); 312 meses; auditoria em `output/audit/anac_*.csv` |
| CEPII GeoDist (`cepiigeodist` 0.1) | 2026-08-31 | Cache `dist_cepii_cran.csv` gerado do pacote; `dist_cepii.zip` copiado manualmente na mesma data |
| WDI (`WDI` 2.8.0) | a cada execução do alvo `macro` | Indicadores listados em `R/03_download_macro.R` |
| R | — | R 4.4.2; demais versões de pacotes em `renv.lock` |

As datas acima vêm dos carimbos dos arquivos e dos logs em `logs/`. Fontes
online podem ser revisadas pelos órgãos; uma nova execução pode, portanto,
produzir arquivos ligeiramente diferentes. A amostra usada no artigo está
congelada em `data/processed/econometric_sample_gdp_pli_distw.parquet`, que
**é** versionada, com manifesto em `output/audit/econometric_sample_manifest.csv`.
