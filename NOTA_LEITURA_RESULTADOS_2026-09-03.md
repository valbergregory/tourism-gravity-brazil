# Nota de leitura dos resultados econométricos

> **Documento histórico, não usar para a versão final.** A auditoria de
> 04/09/2026 mostrou que células país–mês não observadas haviam sido tratadas
> como zeros. Consulte `NOTA_CORRECAO_ZEROS_IMPUTADOS_2026-09-04.md` e regenere
> todos os resultados depois do novo congelamento.

Artigo: *Distance, Connectivity, and Price Competitiveness: A Gravity-Based
Analysis of International Tourism Demand for Brazil*

Data da leitura: 3 de setembro de 2026.

## 1. Situação da amostra e da auditoria

A amostra principal foi aprovada pelo contrato: 19.644 observações mensais,
87 países, janeiro de 2000 a dezembro de 2025, 680 fluxos iguais a zero e
99,2% das chegadas do painel integral. A especificação usa GDP-PLI como preço,
distw como distância e exclui Macau sem imputar a distância principal.

Todos os 23 modelos convergiram, sem aviso de colinearidade ou erro. A única
remoção por separação ocorreu no painel modal: 380 observações e cinco níveis
origem×modal. As células BGD-fluvial, CUB-fluvial, IRN-fluvial, IRQ-fluvial e
PAK-fluvial continham exclusivamente zeros. A remoção é uma consequência
esperada do PPML com efeitos fixos e deve ser declarada na nota da robustez
modal, não tratada como falha de dados.

## 2. Resultado principal de preço

No PPML de referência, a elasticidade do preço relativo GDP-PLI é -0,569
(erro-padrão 0,210; p = 0,0068; IC95% de -0,981 a -0,157). Uma elevação de
10% no preço relativo do Brasil está associada a aproximadamente 5,3% menos
chegadas, mantidas as demais variáveis e os efeitos fixos.

O coeficiente permanece perto de -0,57 quando se adicionam serviço direto,
assentos, voos ou a média móvel de assentos, e continua estatisticamente
significativo com agrupamento bidimensional origem×mês-ano. Essa estabilidade
é evidência favorável ao resultado principal.

Há duas limitações substantivas. A estimativa perde precisão quando a
Argentina é excluída (-0,127; p = 0,295) e quando os cinco maiores mercados são
retirados (-0,254; p = 0,132). Portanto, o artigo não deve afirmar que o efeito
é homogêneo entre mercados. A formulação defensável é que a competitividade de
preço é relevante para o fluxo agregado e que parte importante dessa relação
se concentra nos grandes mercados emissores.

O PLI domiciliar preserva sinal negativo e significância (-0,320; p = 0,016),
enquanto o CPI relativo não é significativo (-0,056; p = 0,296). Isso sustenta
o GDP-PLI como medida principal e o CPI apenas como contraste de robustez.

## 3. Conectividade aérea

As medidas de capacidade aérea defasada apresentam associação positiva e
estatisticamente significativa com chegadas:

- assentos em t-1: 0,061 (p = 0,0063);
- voos em t-1: 0,198 (p = 0,0027);
- média dos três meses anteriores de assentos: 0,053 (p = 0,0206);
- assentos no modelo conjunto: 0,087 (p = 0,0087).

Em termos aproximados, um aumento de 10% corresponde a 0,58% mais chegadas no
modelo de assentos, 1,90% no modelo de voos e 0,51% no modelo de média móvel.
Esses resultados são associações condicionais. Sem uma estratégia adicional
de identificação, não devem ser apresentados como efeitos causais, pois oferta
aérea e demanda turística podem responder conjuntamente.

O indicador simples de serviço direto não é significativo no modelo sem
interação (-0,048; p = 0,584). Nos modelos interagidos, seu efeito precisa ser
calculado em conjunto com a distância; o coeficiente isolado não é uma medida
geral do benefício de uma rota direta.

## 4. Correção da interação distância × serviço direto

Na primeira exportação, o termo `direct_l1` dos modelos interagidos era
avaliado em log(distw) = 0, isto é, a 1 km. Esse ponto não tem interpretação
econômica em turismo internacional e produziu coeficientes isolados grandes,
com intervalos muito amplos, na figura original.

A revisão centra log(distw) em 5.000 km:

    log_distw_centered = log(distw_km) - log(5000)

e usa `log_distw_centered × direct_l1`. A transformação preserva exatamente os
valores ajustados, a log-verossimilhança, os coeficientes de preço e capacidade
e o coeficiente da interação. Ela muda apenas o intercepto associado ao
indicador direto: agora `direct_l1` mede o efeito a 5.000 km.

Com os coeficientes da primeira execução, a estimativa pontual do serviço
direto no modelo conjunto a 5.000 km é aproximadamente -0,260, e não 0,694.
O intervalo correto depende da covariância entre os dois termos e será
calculado automaticamente na nova exportação. O arquivo
`direct_service_marginal_effects.csv` apresentará estimativa e IC95% em 1.500,
5.000 e 10.000 km.

## 5. Distância e gravidade

No PPML-CRE, a elasticidade de distw é -3,607 (erro-padrão 0,197; p < 0,001).
O sinal e a significância permanecem com distância entre capitais (-3,593) e
com a distância bilateral simples (-2,666). O idioma oficial comum apresenta
associação positiva; contiguidade e vínculo colonial não são precisos nessa
amostra.

Esses coeficientes identificam variação entre origens no modelo CRE, não
variação dentro da origem. O texto deve chamar o resultado de associação
gravitacional e distinguir explicitamente esse modelo dos PPML-TWFE principais,
nos quais a distância invariável é absorvida pelos efeitos fixos de origem.

## 6. Robustezes que exigem cautela

- A amostra pós-reabertura é curta e produz coeficientes instáveis, inclusive
  preço próximo de zero e elasticidade de população muito negativa. Ela deve
  ser descrita como evidência de quebra de regime, não como refutação do
  resultado de longo prazo.
- A estimação trimestral reproduz os coeficientes mensais quase exatamente.
  Com covariáveis anuais e agregação de contagens, isso é uma propriedade da
  agregação do PPML; não constitui evidência independente adicional.
- Erros heteroscedásticos sem agrupamento geram inferência excessivamente
  estreita. O agrupamento por origem permanece a inferência principal; o
  agrupamento bidimensional confirma o sinal e a significância do preço.
- A robustez modal deve informar a remoção das cinco células sempre iguais a
  zero.

## 7. Figuras revisadas

A figura original misturava parâmetros de naturezas diferentes na mesma escala
e era dominada pelo intervalo do coeficiente de serviço direto avaliado a
1 km. A nova exportação separa:

1. estabilidade da elasticidade-preço GDP-PLI;
2. elasticidades de capacidade aérea defasada;
3. efeito marginal do serviço direto por distância.

Essa separação corresponde diretamente às três mensagens empíricas do artigo
e impede que um coeficiente condicional seja lido como efeito médio.

## 8. Sequência de reexecução

Substitua o pacote de atualização completo, que agora inclui
`R/12_visual_diagnostics.R`, os novos scripts e os alvos adicionais em
`_targets.R`. Não é necessário reconstruir os dados nem alterar o congelamento
aprovado.

Se os quatro jobs da versão anterior já foram concluídos com sucesso, a revisão
final de 4 de setembro afeta apenas os diagnósticos visuais e formais. Nesse
caso, execute somente `scripts/10_gerar_diagnosticos_visuais.R` como Background
Job. O próprio script exige 12 testes formais, verifica as duas combinações
lineares pós-reabertura e confirma que a tabela de ajuste não contém as colunas
vazias removidas.

Em uma instalação nova, primeiro, no Terminal e sem pipeline ativo, execute:

    Rscript scripts/00_instalar_pacotes_visuais.R

Depois, execute um Background Job por vez:

1. `scripts/07_estimar_modelos.R`;
2. `scripts/08_auditar_modelos.R`;
3. `scripts/09_exportar_resultados.R`;
4. `scripts/10_gerar_diagnosticos_visuais.R`.

Após o terceiro job, confirme que o contrato permanece em 19.644 observações e
87 origens, que a auditoria continua sem novos alertas e que os três novos
produtos de interpretação foram exportados. O quarto job pode demorar por
realizar 87 reestimações leave-one-origin-out. Somente então as tabelas e
figuras devem ser tratadas como versão pronta para a redação dos resultados.
