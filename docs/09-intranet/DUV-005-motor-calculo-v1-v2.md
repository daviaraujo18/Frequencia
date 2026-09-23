# DUV-005 — Motor de cálculo duplicado v1 × v2 — qual é o oficial?

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

Existem **duas implementações completas e paralelas** do motor de cálculo diário de frequência no módulo `presenca`:

- **v1** — `services/calculo/` (`CalculoDiarioService`, `CalculoDiarioStrategy`, `BuscaPeriodos`, `EntradasESaidas`, `Ocorrencias`, `PrimeiraEntradaUltimaSaida[Old]`)
- **v2** — `services/calculo/v2/` (`CalculoDiarioServiceV2`, `CalculoStrategyV2`, `BuscaPeriodosV2`, `EntradasESaidasV2`, `OcorrenciasV2`, `PrimeiraEntradaUltimaSaida[Old]V2`)

Ambos estão **em uso em produção**, em caminhos distintos:
- **v2** usado pela maioria: jobs `RecalculoDiario` (`:92`), `CalculoDiarioAusentes` (`:157`), `HistoricoTarefaServices` (`:90,120,125`), `RegistroFrequenciaServices` (`:152,180,207,234`), `DynMostraRegistroFrequencia` (`:58,122,166,170`).
- **v1** ainda invocado em: `CalculoFrequenciaActions` (`:24`), `RegistroFrequenciaServices.desconsiderar/reconsiderarPonto` (`:115,123`), `HistoricoTarefaServices.deserializarRecalcular` (`:516` — recalcular TODOS usa v1).

Existem **diferenças de comportamento** confirmadas entre v1 e v2 (ex.: contagem de saídas antecipadas mensais — v1 consulta banco, v2 fixa 0; limite GCET; parametrização de banco de horas diário). Isso significa que o mesmo frequentador/dia pode gerar **resultados diferentes dependendo do caminho de recálculo**.

## Origem

- `docs/01-inventario/03-calculo-diario.md` (seções 2, 3, 7 — D3)
- `docs/01-inventario/02-regime-jornada.md` (Q7)
- `docs/01-inventario/04-direitos-afastamentos.md` (D10)

## Por que importa

- **Correção do novo sistema:** precisa consolidar em UM motor canônico.
- Não pode portar 1:1 as duas linhagens (geraria divergência).
- Resultados financeiros (banco de horas) dependem de qual motor roda.

## Hipóteses

1. v2 é a refatoração canônica atual (a maioria do código ativo usa v2); v1 seria legado residual nos caminhos de UI manual.
2. Alguns caminhos v1 foram mantidos por compatibilidade mas produzem resultados "antigos".
3. É preciso uma suíte de testes de contraste v1×v2 por modalidade e janela de data para decidir.

## Como Resolver

- [ ] Mapear e comparar todas as diferenças de comportamento v1×v2 (saída antecipada, GCET, banco diário, limites).
- [ ] Confirmar com usuário de negócio qual motor reflete a regra vigente (provavelmente v2).
- [ ] Decidir se os caminhos de UI/manual (v1) devem passar a usar v2.
- [ ] Consolidar em um único motor no Frequência.
- [ ] Criar testes de contraste com dados históricos (cortes: 01/12/2018, 01/05/2017, 26/10/2022).

## Resolução

**Resolvida por inspeção exaustiva do código (2026-08-05).**

### Confirmado: existem exatamente dois motores espelhados

- **v1** — `services/calculo/` (7 classes): `CalculoDiarioService`, `CalculoDiarioStrategy`, `BuscaPeriodos`, `EntradasESaidas`, `Ocorrencias`, `PrimeiraEntradaUltimaSaida`, `PrimeiraEntradaUltimaSaidaOld`.
- **v2** — `services/calculo/v2/` (7 classes espelhadas com sufixo `V2`). Ambas seguem o padrão singleton `INSTANCE`.

### Quem usa v1 vs v2 (chamadas confirmadas)

| Ponto de chamada (arquivo:linha) | Motor |
|----------------------------------|-------|
| `CalculoFrequenciaActions.java:24` (`corrigir`) | v1 |
| `RegistroFrequenciaServices.desconsiderarPonto:115` / `reconsiderarPonto:123` | v1 |
| `HistoricoTarefaServices.deserializarRecalcular:516` (`corrigir` — recalcular TODOS) | v1 |
| `DynMostraRegistroFrequencia.recalculaTodos:149` | v1 |
| `RecalculoDiario` (job) `:92`, `CalculoDiarioAusentes` `:157,169` | v2 |
| `RegistroFrequenciaServices` deferir/indeferir `:152,180,207,234` | v2 |
| `HistoricoTarefaServices` `:90,120,122,125,211,313` | v2 |
| `DynMostraRegistroFrequencia` `:58,122,166,170` | v2 |
| `GerarRegistroMensalFrequencia:45`, `RetificadorServices:65`, `FrequentadorServices:261,297` | v2 |

### Achados críticos

1. **v2 é o motor canônico vigente** — é o que roda nos jobs assíncronos (`RecalculoDiario`, `CalculoDiarioAusentes`) e no fechamento mensal, ou seja, o caminho que gera o resultado oficial de produção.
2. **v1 sobrevive em caminhos pontuais de UI/manual**: `CalculoFrequenciaActions` (correção manual de um dia), `desconsiderar/reconsiderarPonto` (UI de batidas) e `recalculaTodos`/`deserializarRecalcular` (recalcular em lote via UI). São justamente os caminhos que podem divergir do resultado oficial.
3. **Não são totalmente independentes**: `services/calculo/v2/PrimeiraEntradaUltimaSaidaV2.java:157` reutiliza o helper estático **do v1** `CalculoDiarioService.getSaldoAcumuladoComRetificadoresInicioMesAte(...)` — v2 ainda depende de pedaços do v1.
4. **Diferenças de comportamento confirmadas** (ver DUV-012): a janela GCET (45min) difere — v1 aplica para toda data após 01/12/2018; v2 restringe a 01/12/2018–26/10/2022 e ainda libera banco em 21–23/11/2022. Também: faltas compensáveis (v1 fixo 10; v2 dinâmico 10/12 conforme data) e saída antecipada mensal.

### Recomendação para a migração

- **Portar v2 como motor canônico** do Frequência (produz os resultados de produção).
- **Migrar os caminhos v1** (desconsiderar/reconsiderar, correção manual, recálculo em lote) para usar o motor v2, preservando a regra de negócio equivalente — para não gerar divergência entre resultado oficial e ajustes manuais.
- Criar **suíte de testes de contraste v1×v2** por modalidade e janela de data (cortes 01/12/2018, 01/05/2017, 26/10/2022) para garantir paridade antes de retirar o v1.
- Rever o acoplamento v2→v1 (`getSaldoAcumuladoComRetificadoresInicioMesAte`) ao consolidar.

> **Nota:** a confirmação definitiva de "qual regra é vigente" nos casos em que v1 e v2 divergem exige validação com o negócio, mas o fato de a maioria do código ativo (jobs/fechamento) usar v2 é forte evidência de que ele é o oficial.
