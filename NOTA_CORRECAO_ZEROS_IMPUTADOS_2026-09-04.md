# Correção dos zeros imputados na demanda turística

## Diagnóstico

A auditoria mostrou que longos blocos de zeros de PRI, IRQ e SAU não eram
registros mensais observados pelo MTur. Eles haviam sido criados durante a
completação do painel país–modal–mês. Somente essas três origens respondiam por
536 dos 680 zeros da antiga amostra principal.

Um zero observado é compatível com PPML. A ausência de registro na fonte não
pode, porém, ser recodificada como demanda observada igual a zero. A antiga
amostra de 19.644 linhas e 87 origens fica, portanto, metodologicamente
superada e não deve ser mantida apenas para reproduzir os resultados anteriores.

## Regra implementada

1. O painel mensal completo é preservado para manter o calendário e calcular
   defasagens sem saltar lacunas.
2. O total país–mês é considerado observado quando ao menos um componente
   modal usado na soma possui `zero_imputed == 0`.
3. Quando todos os componentes foram completados artificialmente, `arrivals`
   passa a `NA`, e não a zero.
4. Nas regressões por modal, cada célula com `zero_imputed == 1` também passa a
   `NA`.
5. A cobertura e os indicadores de pertencimento às amostras são recalculados
   somente com meses efetivamente observados.
6. A escolha entre registros agregados `all` e modais detalhados considera
   apenas registros observados, evitando que linhas artificiais façam um
   agregado observado ser descartado.
7. A amostra `sample_core_2000` somente é marcada como balanceada quando todos
   os 312 meses entre janeiro de 2000 e dezembro de 2025 foram observados.
8. O `config.yml` passa a ser uma dependência de arquivo explícita do pipeline;
   alterar o contrato invalida os alvos dependentes de forma automática.

## Novo congelamento em duas fases

O `config.yml` é entregue com os dois totais esperados definidos como `null`.
Isso é intencional e impede que resultados sejam estimados com um contrato
antigo ou ainda não auditado.

1. Execute `scripts/06_recalibrar_contrato_amostra.R` como **Background Job**.
2. Copie `rows` e `origins` impressos para `expected_main_rows` e
   `expected_main_origins` no `config.yml`.
3. Execute novamente o mesmo script e confirme `contract_ok = TRUE`.
4. Só então execute `scripts/07_estimar_modelos.R`, seguido das auditorias e
   exportações já previstas.

O script grava três arquivos de auditoria:

- `output/audit/arrival_observation_provenance.csv`;
- `output/audit/completed_unobserved_months_by_origin.csv`;
- `output/audit/corrected_sample_contract_candidate.csv`.

## Consequência para os resultados

Todos os coeficientes, erros-padrão, testes, tabelas e figuras gerados antes
desta correção devem ser tratados como resultados provisórios. Eles precisam
ser regenerados depois que o novo contrato for validado.
