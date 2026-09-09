# Plano editorial de figuras, tabelas e testes

> A estrutura deste plano continua válida, mas quantidades, estimativas e o
> número de reestimações devem ser atualizados após o novo congelamento descrito
> em `NOTA_CORRECAO_ZEROS_IMPUTADOS_2026-09-04.md`.

Artigo: *Distance, Connectivity, and Price Competitiveness: A Gravity-Based
Analysis of International Tourism Demand for Brazil*

## 1. Princípio editorial

O artigo deve usar figuras para comunicar mecanismos e robustez, e não para
repetir integralmente as tabelas. As figuras do texto principal terão uma
identidade visual comum, paleta acessível, fundo branco, títulos curtos,
subtítulos explicativos e notas de fonte. Resultados auxiliares e diagnósticos
mais densos irão para o apêndice.

## 2. Pacotes selecionados

- `ggplot2`: gramática principal dos gráficos;
- `ggdist`: pontos, intervalos e bandas de incerteza com acabamento editorial;
- `patchwork`: composição dos painéis de resultados;
- `gt`: tabelas HTML e LaTeX com cabeçalhos, faixas e formatação consistente;
- `viridisLite` e escalas viridis do `ggplot2`: cores perceptualmente uniformes
  e adequadas para leitores com deficiência de visão de cores;
- `modelsummary`: tabelas econométricas e resumos de modelos;
- `fixest`: PPML, resíduos, matrizes de covariância e estimações auxiliares.

Foram evitadas dependências cartográficas nesta etapa. Um mapa-múndi exigiria
geometrias adicionais e não acrescentaria identificação econométrica; poderá
ser preparado depois como material de apresentação.

## 3. Figuras recomendadas para o texto principal

### Figura 1 — Evolução da demanda

`tourism_demand_timeline`: chegadas mensais e média móvel de 12 meses, com a
janela da pandemia sombreada. Estabelece tendência, sazonalidade e quebra
estrutural.

### Figura 2 — Competitividade de preço

`main_coefficient_plot`: forest plot da elasticidade GDP-PLI nas principais
especificações e robustezes. Evidencia estabilidade no núcleo e perda de
precisão quando grandes mercados são excluídos.

### Figura 3 — Capacidade aérea

`connectivity_capacity_plot`: comparação das elasticidades de assentos, voos e
média móvel defasada. Comunica que o sinal positivo não depende de uma única
proxy de capacidade.

### Figura 4 — Serviço direto condicionado à distância

`direct_service_marginal_effect_plot`: curvas contínuas, com bandas de 95%, no
intervalo de 1.200 a 18.000 km. Substitui o gráfico de apenas três pontos e
mostra onde o efeito passa a ser estatisticamente distinto de zero.

### Figura 5 — Distância e demanda acumulada

`distance_arrivals_scatter`: relação descritiva em escalas logarítmicas, por
região. Serve de ponte visual para o PPML-CRE, sem ser apresentada como
estimativa causal.

### Painel de síntese

`article_results_dashboard`: composição vertical das figuras de preço,
capacidade e serviço direto, destinada a apresentações, seminários e material
suplementar. No artigo, os painéis podem permanecer separados para preservar a
legibilidade.

## 4. Figuras recomendadas para o apêndice

- `market_concentration_top15`: ranking e participação dos maiores mercados;
- `relative_price_trend`: mediana e intervalo interquartil anual do GDP-PLI;
- `combined_model_calibration`: observado versus previsto por decis de
  previsão;
- `origin_leave_one_out_influence`: vinte exclusões nacionais que mais alteram
  a elasticidade-preço;
- `zero_flow_heatmap_top20`: frequência anual de fluxos iguais a zero nos vinte
  mercados com maior incidência de zeros. O nome do arquivo foi mantido por
  compatibilidade com o pipeline.

## 5. Tabelas do texto principal

1. `descriptive_statistics`: estatísticas da amostra congelada;
2. `main_models`: PPML-TWFE principais;
3. `gravity_distance_models`: PPML-CRE com distâncias alternativas;
4. `economic_magnitudes`: tradução dos coeficientes para mudanças de 10%;
5. `robustness_models`: períodos e exclusões de mercados.

## 6. Tabelas do apêndice

- `robustness_prices_connectivity`;
- `robustness_frequency_modes`;
- `functional_form_and_regime_tests`;
- `inference_sensitivity`;
- `formal_specification_tests`;
- `model_fit_diagnostics`;
- `market_concentration_top20`;
- `origin_leave_one_out_influence`;
- `combined_model_calibration`.

As tabelas diagnósticas são exportadas em CSV, HTML e LaTeX quando aplicável.
Os CSVs preservam valores não arredondados para auditoria; HTML e LaTeX são
formatos de apresentação.

## 7. Testes adicionais

### Wald conjunto com covariância agrupada

São testados conjuntamente:

- renda e população na linha de base;
- serviço direto, assentos e interação no modelo de conectividade;
- distância, fronteira, idioma e vínculo colonial no PPML-CRE;
- médias de Mundlak no PPML-CRE;
- blocos de conectividade nas amostras aérea e modal.

### Não linearidade do preço

`price_nonlinearity` adiciona o quadrado do GDP-PLI centrado. A hipótese nula é
de resposta localmente linear. A centralização reduz colinearidade entre os
termos linear e quadrático.

### Mudança de regime pós-reabertura

`post_reopening_interactions` exclui a janela pandêmica e testa se as
inclinações de preço e assentos mudaram depois de dezembro de 2021. O indicador
isolado de pós-reabertura é absorvido pelos efeitos fixos mês-ano.

Além dos testes de mudança, a tabela calcula e testa as duas inclinações totais
pós-reabertura: `preço + preço × pós` e `assentos + assentos × pós`. Cada linha
informa a estimativa da combinação linear, erro-padrão, intervalo de 95% e teste
de Wald com a covariância agrupada do modelo.

### Influência leave-one-origin-out

O PPML principal é reestimado 87 vezes, retirando uma origem em cada execução.
O produto identifica dependência excessiva de mercados específicos e amplia a
análise hoje limitada às exclusões da Argentina e dos cinco maiores mercados.

### Ajuste e calibração

São reportados MAE, RMSE, dispersão de Pearson, razão entre totais previsto e
observado e comparação entre zeros observados e zeros esperados sob Poisson.
As colunas de log-verossimilhança e deviance foram retiradas porque não eram
preenchidas de modo consistente na exportação serializada. A dispersão é
diagnóstica; não invalida o PPML como estimador de quase-máxima verossimilhança
com erros agrupados.

## 8. Sequência operacional

No Terminal, com nenhum pipeline ativo:

    Rscript scripts/00_instalar_pacotes_visuais.R

Depois, como Background Jobs, um por vez:

1. `scripts/07_estimar_modelos.R`;
2. `scripts/08_auditar_modelos.R`;
3. `scripts/09_exportar_resultados.R`;
4. `scripts/10_gerar_diagnosticos_visuais.R`.

O quarto job pode demorar por executar as 87 reestimações leave-one-origin-out.
Nunca inicie outro `targets` enquanto ele estiver ativo.
