# Guia de execução — econometria do turismo internacional

Projeto: *Distance, Connectivity, and Price Competitiveness: A Gravity-Based
Analysis of International Tourism Demand for Brazil*

Diretório no Windows:

    D:/R - Projetos/tourism-gravity/r-project

## 1. Natureza do pacote

Este é um pacote de atualização, não uma cópia integral do projeto. Copie os
arquivos sobre as pastas correspondentes do projeto existente, preservando os
módulos de coleta e todos os dados já construídos.

Arquivos econométricos reescritos:

- R/09_models.R;
- R/10_robustness.R;
- R/11_export.R;
- _targets.R.

Arquivos auxiliares atualizados:

- R/04_prepare_geodist.R: preserva distw, distcap e dist em colunas distintas
  e proíbe substituir distw;
- R/07_build_panel.R: torna o alias de preço compatível com GDP-PLI e cria as
  interações com distw;
- R/config.R, R/00_setup.R e config.yml;
- scripts/_helpers.R.

Novos scripts:

- scripts/00_instalar_pacotes_visuais.R;
- scripts/06_recalibrar_contrato_amostra.R;
- scripts/07_estimar_modelos.R;
- scripts/08_auditar_modelos.R;
- scripts/09_exportar_resultados.R;
- scripts/10_gerar_diagnosticos_visuais.R.

## 2. Contrato econométrico

O bloco econometrics de config.yml fixa:

- amostra principal: sample_broad_5y;
- robustez balanceada: sample_core_2000;
- preço principal: log_relative_price_gdp_pli;
- distância principal: distw;
- tamanho esperado da amostra corrigida, depois da recalibração descrita abaixo;
- exclusão de MAC em toda especificação que exige distw;
- falha obrigatória se o tamanho auditado mudar.

A camada econométrica adota 5.000 km como referência das interações entre
distância e serviço direto e exporta efeitos marginais em 1.500, 5.000 e
10.000 km. Esses padrões não alteram o contrato nem o alvo da amostra
congelada.

Não altere strict_sample_contract para fazer o pipeline avançar. Uma divergência
deve ser investigada no painel e nas auditorias.

Os totais antigos de 19.644 observações e 87 origens foram invalidados pela
identificação de meses completados artificialmente como zeros. Eles não devem
ser copiados de volta ao arquivo de configuração sem a nova reconstrução.

## 3. Reconstrução e congelamento auditável

build_econometric_sample() aplica, nesta ordem:

1. pertencimento a sample_broad_5y;
2. exclusão das origens proibidas nas especificações distw;
3. célula país–mês observada na fonte e chegadas não negativas;
4. renda per capita e população defasadas completas;
5. GDP-PLI completo;
6. distw estritamente positiva e finita.

Na primeira execução corrigida, os totais esperados permanecem `null`. Execute
`scripts/06_recalibrar_contrato_amostra.R`, copie os valores candidatos
impressos para o `config.yml` e execute o mesmo script novamente. A estimação é
bloqueada enquanto `contract_ok` não for `TRUE`.

sample_freeze_files grava:

- data/processed/econometric_sample_gdp_pli_distw.parquet;
- output/audit/econometric_sample_summary.csv;
- output/audit/econometric_sample_origin_inclusion.csv;
- output/audit/econometric_sample_row_exclusions.csv;
- output/audit/econometric_sample_manifest.csv.

O manifesto registra o MD5 do Parquet. Os modelos dependem desse alvo e não são
estimados se o congelamento ou o contrato falhar.

## 4. Modelos principais

Todos usam PPML por fixest::fepois e GDP-PLI.

Modelos com efeitos fixos de origem e mês-ano:

1. baseline_gdp_pli: renda, população e preço GDP-PLI;
2. direct_l1: adiciona serviço direto em t-1;
3. seats_l1: adiciona assentos em t-1;
4. flights_l1: adiciona voos em t-1;
5. seats_ma3_l1: média dos três meses anteriores de assentos;
6. connectivity_combined_l1: serviço direto, assentos e interação
   distw × serviço direto, todos defasados. A distância em log é centrada em
   5.000 km, de modo que o coeficiente isolado de serviço direto se refere a
   uma origem situada nessa distância.

Centralizar a distância é uma reparametrização: não muda valores ajustados,
log-verossimilhança, coeficientes de preço ou capacidade nem o coeficiente da
interação. Evita, porém, interpretar o serviço direto no ponto artificial de
1 km que surgiria com log(distw) não centrada.

Como distw não varia no tempo dentro de cada origem, seu efeito isolado é
absorvido pelos efeitos fixos de origem. O código não força um coeficiente não
identificável.

gravity_distw_cre usa PPML-CRE com log_distw, contiguidade, idioma oficial
comum, vínculo colonial, covariáveis temporais, médias de Mundlak e efeitos
fixos de região e mês-ano. Esse modelo separado não deve ser descrito como
equivalente ao TWFE principal.

## 5. Robustezes

R/10_robustness.R estima:

- período anterior a março de 2020;
- período posterior a dezembro de 2021;
- exclusão integral de março de 2020 a dezembro de 2021;
- painel balanceado core_2000;
- CPI/câmbio e PLI domiciliar;
- exclusão da Argentina;
- exclusão dos cinco maiores mercados, registrados em auditoria;
- conectividade contemporânea apenas como benchmark;
- agrupamento bidimensional origem–mês e erro robusto;
- frequência trimestral;
- distcap e dist em PPML-CRE separados;
- chegadas aéreas;
- painel modal com efeitos fixos origem×modal e modal×mês-ano.

As distâncias alternativas nunca preenchem distw. Macau só pode aparecer em uma
robustez cuja distância própria esteja disponível e cuja amostra permita sua
inclusão; continua proibido nas especificações distw.

## 6. Auditoria

model_audit_files produz:

- model_estimation_audit.csv: fórmula, N de entrada e estimado, remoções,
  convergência, separação, colinearidade e avisos;
- model_coefficient_audit.csv: estimativas, erros-padrão e intervalos;
- model_residual_diagnostics.csv: resíduos e valores ajustados;
- robustness_sample_counts.csv: N e países por amostra;
- dominant_markets_excluded.csv: mercados retirados.

A exportação final acrescenta:

- direct_service_marginal_effects.csv: efeitos percentuais de serviço direto,
  com intervalos de 95%, em 1.500, 5.000 e 10.000 km;
- main_coefficient_plot: estabilidade da elasticidade-preço GDP-PLI;
- connectivity_capacity_plot: elasticidades de assentos e voos defasados;
- direct_service_marginal_effect_plot: efeito de serviço direto por distância.

O módulo R/12_visual_diagnostics.R acrescenta tabelas de estatísticas
descritivas, magnitudes econômicas, testes de Wald, ajuste, concentração e
influência, além de sete figuras descritivas e diagnósticas. Consulte
PLANO_FIGURAS_TABELAS_TESTES_2026-09-03.md para a divisão entre texto principal
e apêndice.

Os testes formais incluem 12 hipóteses: dez testes de blocos ou mudanças de
inclinação e dois testes das inclinações totais pós-reabertura. A tabela de
ajuste omite log-verossimilhança e deviance e preserva somente medidas
preenchidas de forma consistente para todos os modelos.

Qualquer remoção, nível eliminado por separação, variável colinear, aviso ou
falha de convergência aparece no log de auditoria.

## 7. Sequência no RStudio

Abra sempre tourism-gravity.Rproj.

### 7.1 Terminal — diagnóstico e Git

No Terminal:

~~~bash
git status --short
git diff --check
git diff -- R/04_prepare_geodist.R R/07_build_panel.R R/09_models.R R/10_robustness.R R/11_export.R _targets.R config.yml
~~~

Se o ambiente não estiver restaurado:

~~~bash
Rscript -e "renv::restore(prompt = FALSE)"
~~~

Antes da nova exportação visual, instale e registre as dependências no renv:

~~~bash
Rscript scripts/00_instalar_pacotes_visuais.R
~~~

Não dispare tar_make no Terminal enquanto houver Background Job ativo.

### 7.2 Console — verificações curtas

~~~r
getwd()
targets::tar_manifest(fields = c(name, command))
targets::tar_outdated()
~~~

Confirme o diretório do projeto. Se _targets/meta/process existir, primeiro
confirme na aba Jobs que nenhum processo está ativo. Somente se não houver job:

~~~r
targets::tar_unblock_process(store = "_targets")
~~~

Nunca desbloqueie um pipeline realmente ativo.

### 7.3 Background Job 1 — recalibração da amostra

Em Jobs > Start Background Job, selecione:

    scripts/06_recalibrar_contrato_amostra.R

Na primeira execução, copie `rows` e `origins` do bloco **CANDIDATO AO NOVO
CONTRATO** para `expected_main_rows` e `expected_main_origins` no `config.yml`.
Execute o mesmo job outra vez e confirme no Console:

~~~r
s <- targets::tar_read(econometric_sample)$summary
print(s, width = Inf)
stopifnot(isTRUE(s$contract_configured), isTRUE(s$contract_ok))
~~~

### 7.4 Background Job 2 — congelamento e estimação

Em Jobs > Start Background Job, selecione:

    scripts/07_estimar_modelos.R

Use o diretório do projeto e não copie o Global Environment. Ao terminar,
verifique no Console:

~~~r
s <- targets::tar_read(econometric_sample)$summary
print(s, width = Inf)
stopifnot(
  s$rows == s$expected_rows,
  s$origins == s$expected_origins,
  isTRUE(s$contract_ok)
)

m <- targets::tar_read(main_models)$audit
print(m, n = Inf, width = Inf)
~~~

### 7.5 Background Job 3 — auditoria

Somente após o job de estimação terminar, inicie:

    scripts/08_auditar_modelos.R

Leia logs/08_auditoria_modelos.txt. No Console:

~~~r
audit <- readr::read_csv(
  "output/audit/model_estimation_audit.csv",
  show_col_types = FALSE
)
dplyr::filter(
  audit,
  convergence_flag == "failed" |
    collinearity_flag |
    warning_flag |
    removed_rows > 0 |
    separation_fe_levels_removed > 0
)
~~~

### 7.6 Background Job 4 — exportação

Depois de aprovar a auditoria, inicie:

    scripts/09_exportar_resultados.R

O job gera tabelas TeX e HTML, CSV e gráficos PDF/PNG. Se as pastas
copiados para elas.

### 7.7 Background Job 5 — diagnósticos e figuras ampliadas

Somente depois do encerramento do job de exportação, execute:

    scripts/10_gerar_diagnosticos_visuais.R

Esse job reestima o PPML principal uma vez para cada origem da nova amostra,
retirando uma origem em cada rodada. A duração maior é esperada. Não execute
outro pipeline enquanto ele estiver ativo.

## 8. Saídas do artigo

Tabelas:

- output/tables/main_models.tex;
- output/tables/robustness_models.tex;
- output/tables/robustness_prices_connectivity.tex;
- output/tables/robustness_frequency_modes.tex;
- output/tables/functional_form_and_regime_tests.tex;
- output/tables/gravity_distance_models.tex;
- output/tables/inference_sensitivity.tex;
- output/tables/coefficient_estimates.csv;
- output/tables/model_specifications.csv;
- output/tables/descriptive_statistics.{csv,html,tex};
- output/tables/economic_magnitudes.{csv,html,tex};
- output/tables/formal_specification_tests.{csv,html,tex};
- output/tables/model_fit_diagnostics.{csv,html,tex};
- output/tables/market_concentration_top20.{csv,html,tex};
- output/tables/origin_leave_one_out_influence.{csv,html,tex};
- output/tables/combined_model_calibration.csv.

Figuras:

- output/figures/main_coefficient_plot.pdf;
- output/figures/main_coefficient_plot.png;
- output/figures/connectivity_capacity_plot.{pdf,png};
- output/figures/direct_service_marginal_effect_plot.{pdf,png};
- output/figures/article_results_dashboard.{pdf,png};
- output/figures/tourism_demand_timeline.{pdf,png};
- output/figures/market_concentration_top15.{pdf,png};
- output/figures/relative_price_trend.{pdf,png};
- output/figures/distance_arrivals_scatter.{pdf,png};
- output/figures/combined_model_calibration.{pdf,png};
- output/figures/origin_leave_one_out_influence.{pdf,png};
- output/figures/zero_flow_heatmap_top20.{pdf,png}.

Apesar do nome histórico, `zero_flow_heatmap_top20` apresenta os vinte mercados
com maior incidência de fluxos mensais iguais a zero, e não os vinte maiores em
volume.

Logs:

- logs/06_recalibracao_contrato_amostra.txt;
- logs/07_estimacao_modelos.txt;
- logs/08_auditoria_modelos.txt;
- logs/09_exportacao_resultados.txt;
- logs/10_diagnosticos_visuais.txt.

## 9. Interpretação inicial

- Covariáveis em log produzem elasticidades ou semielasticidades.
- Para indicadores binários, reporte 100 × [exp(beta) - 1]. O CSV calcula esse
  efeito.
- GDP-PLI negativo indica maior demanda quando o Brasil fica relativamente
  mais barato.
- A interação distw × serviço direto mostra se a ligação direta atenua ou
  amplia a penalidade associada à distância; não é o efeito isolado de
  distância.
- A defasagem reduz, mas não elimina, simultaneidade. Evite linguagem causal sem
  estratégia adicional de identificação.

## 10. Regra de concorrência

Os scripts que executam o pipeline criam uma trava exclusiva em
logs/.targets_pipeline_lock. Se outro script já estiver executando, o novo
processo falha antes de tar_make. A trava do próprio targets também é
verificada. Execute um único Background Job de pipeline por vez.
