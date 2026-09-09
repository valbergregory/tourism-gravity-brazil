# Revisão final dos diagnósticos — 4 de setembro de 2026

Esta revisão não modifica a amostra congelada nem reestima os 25 modelos. Ela
altera somente a camada de diagnóstico e apresentação.

## Correções implementadas

1. A tabela `formal_specification_tests` passa de 10 para 12 linhas. As duas
   novas linhas testam se as inclinações totais pós-reabertura são iguais a
   zero:

   - preço: `log_relative_price_gdp_pli + price_x_post_reopening`;
   - capacidade: `log_seats_l1 + seats_x_post_reopening`.

   Os cálculos usam a matriz de covariância agrupada do próprio modelo e
   exportam estimativa, erro-padrão, intervalo de 95%, estatística de Wald e
   valor-p.

2. `model_fit_diagnostics` não exporta mais as colunas vazias
   `log_likelihood` e `deviance`. Permanecem MAE, RMSE, dispersão de Pearson,
   calibração agregada e comparação dos zeros observados com os esperados sob
   Poisson.

3. `distance_arrivals_scatter` mantém os oito maiores mercados identificados,
   mas usa posições explícitas para separar Alemanha, França e Itália. A escala
   vertical agora usa unidades compactas (`k` e `M`) em vez de frações de
   milhão.

4. `zero_flow_heatmap_top20` passa a selecionar os vinte mercados com maior
   incidência de zeros, com desempate pelo volume de chegadas. O nome do arquivo
   foi mantido para não quebrar referências existentes.

5. `scripts/10_gerar_diagnosticos_visuais.R` ganhou verificações automáticas.
   A execução para imediatamente se não encontrar 12 testes, duas combinações
   lineares finitas, a tabela de ajuste corrigida ou todos os arquivos esperados.

## Execução

Com nenhum pipeline `targets` ativo, abra
`scripts/10_gerar_diagnosticos_visuais.R` no RStudio e escolha **Source as
Background Job**. Não execute os scripts 07, 08 e 09 novamente: os resultados
econométricos e a amostra não mudaram.

O job pode reutilizar o alvo `origin_influence`; se o `targets` decidir
reconstruí-lo, ocorrerão novamente as 87 reestimações e a execução será mais
demorada.

## Verificação curta no Console

```r
formal <- readr::read_csv(
  "output/tables/formal_specification_tests.csv",
  show_col_types = FALSE
)
fit <- readr::read_csv(
  "output/tables/model_fit_diagnostics.csv",
  show_col_types = FALSE
)

post <- formal |>
  dplyr::filter(grepl("^Post-reopening .* slope is zero$", .data$test))

stopifnot(
  nrow(formal) == 12L,
  nrow(post) == 2L,
  all(is.finite(post$estimate)),
  all(is.finite(post$std_error)),
  all(is.finite(post$p_value)),
  !any(c("log_likelihood", "deviance") %in% names(fit))
)

print(post, width = Inf)
```

Depois, examine:

- `output/tables/formal_specification_tests.html`;
- `output/tables/model_fit_diagnostics.html`;
- `output/figures/distance_arrivals_scatter.png`;
- `output/figures/zero_flow_heatmap_top20.png`.

