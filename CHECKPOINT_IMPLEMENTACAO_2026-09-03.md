# Checkpoint — implementação econométrica

> **Checkpoint histórico, substituído quanto ao tamanho da amostra e aos
> resultados.** A correção de 04/09/2026 remove da estimação células mensais
> completadas sem observação na fonte. Veja
> `NOTA_CORRECAO_ZEROS_IMPUTADOS_2026-09-04.md`.

Artigo: *Distance, Connectivity, and Price Competitiveness: A Gravity-Based
Analysis of International Tourism Demand for Brazil*

Data: 3 de setembro de 2026.

## Estado alcançado

- contrato principal configurado para GDP-PLI, distw, 19.644 observações e 87
  países;
- Macau excluído das especificações distw, sem imputação;
- amostra auditável com Parquet, MD5, manifesto e quadros de inclusão/exclusão;
- R/09_models.R integralmente reescrito;
- R/10_robustness.R integralmente reescrito;
- R/11_export.R integralmente reescrito;
- _targets.R atualizado com dependências amostra → modelos → auditoria →
  exportação;
- conectividade principal defasada;
- CPI, PLI domiciliar, distcap, dist e conectividade contemporânea restritos às
  robustezes;
- lags corrigidos para respeitar continuidade mensal;
- scripts distintos de estimação, auditoria e exportação;
- trava adicional contra pipelines targets simultâneos;
- interação distância × serviço direto reparametrizada com distw centrada em
  5.000 km, sem alterar valores ajustados ou os demais coeficientes;
- efeitos marginais de serviço direto exportados para 1.500, 5.000 e 10.000 km;
- figuras separadas para preço, capacidade aérea e efeito de serviço direto.
- identidade visual editorial com ggdist, patchwork, gt e paleta viridis;
- sete figuras descritivas e diagnósticas adicionais;
- tabelas de estatísticas descritivas, magnitudes econômicas, testes formais,
  ajuste, concentração e influência;
- testes de Wald, não linearidade do preço e mudança de regime pós-reabertura;
- sensibilidade leave-one-origin-out com 87 reestimações em alvo separado.
- testes explícitos das inclinações totais de preço e assentos após a
  reabertura, com combinação linear e covariância agrupada;
- tabela de ajuste sem colunas vazias de log-verossimilhança e deviance;
- gráfico distância–chegadas com oito rótulos legíveis e escala compacta;
- heatmap direcionado aos vinte mercados com maior incidência de zeros.

## Revisão após a primeira estimação

A primeira execução confirmou o contrato de 19.644 observações e 87 origens,
convergência de todos os modelos e ausência de colinearidade. O painel modal
removeu somente 380 observações pertencentes a cinco células origem×modal com
chegadas sempre iguais a zero; a remoção por separação foi auditada e aceita.

A inspeção da primeira figura revelou que o coeficiente isolado de serviço
direto em modelos interagidos estava parametrizado em log(distância) = 0, ou
seja, a 1 km. A revisão centra log(distw) em 5.000 km. Essa transformação não
altera predições, log-verossimilhança, elasticidade-preço, capacidade aérea ou
o coeficiente da interação. Ela torna o coeficiente de serviço direto
interpretável na distância de referência e permite calcular seus efeitos
marginais em distâncias observáveis.

## Próxima ação

Copiar o pacote sobre o projeto existente, abrir tourism-gravity.Rproj e seguir
GUIA_EXECUCAO_ECONOMETRIA.md.

Executar, um por vez, como Background Jobs:

1. scripts/07_estimar_modelos.R;
2. scripts/08_auditar_modelos.R;
3. scripts/09_exportar_resultados.R;
4. scripts/10_gerar_diagnosticos_visuais.R.

Depois da revisão, a exportação também deve listar
direct_service_marginal_effects.csv, connectivity_capacity_plot e
direct_service_marginal_effect_plot nos formatos PDF e PNG.

Antes dos Background Jobs, execute no Terminal:

    Rscript scripts/00_instalar_pacotes_visuais.R

O quarto job gera as tabelas e figuras ampliadas e pode demorar por causa das
87 reestimações de influência.

## Revisão final de 4 de setembro de 2026

A revisão do pacote de resultados confirmou 25 modelos convergentes, ausência
de colinearidade e 87 reestimações leave-one-origin-out bem-sucedidas. A versão
final corrige quatro pontos editoriais: acrescenta os dois testes das
inclinações totais pós-reabertura, remove duas colunas não preenchidas da tabela
de ajuste, torna legíveis os rótulos do gráfico distância–chegadas e substitui
o heatmap pouco informativo dos maiores mercados por um heatmap dos mercados
mais sujeitos a fluxos mensais iguais a zero.

Como as correções afetam somente `R/12_visual_diagnostics.R`, não é necessário
reestimar os 25 modelos. Execute apenas `scripts/10_gerar_diagnosticos_visuais.R`
como Background Job, sem qualquer outro pipeline `targets` ativo.

## Resultado que deve aparecer primeiro

O resumo da amostra deve confirmar:

- rows = 19644;
- origins = 87;
- contract_ok = TRUE;
- price_measure = log_relative_price_gdp_pli;
- distance_measure = distw.

Se o contrato falhar, não flexibilizar o número esperado. Examinar os arquivos
econometric_sample_origin_inclusion.csv e
econometric_sample_row_exclusions.csv.

## Validação pendente no computador do projeto

O pacote passou por verificações estáticas de delimitadores, referências do
grafo, contrato e espaços em branco. O ambiente de preparação não possui
R/Rscript nem os dados do projeto; portanto, a validação dinâmica deve ocorrer
no renv local por meio dos três Background Jobs acima. Não houve execução
simulada nem alteração de dados.
