# Eventos de Domínio — Frequência

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Catalogar os **eventos de domínio** do contexto FREQUÊNCIA (fatos relevantes que ocorrem no domínio) e os gatilhos que disparam **recálculo assíncrono**. Nos alvo (Rails + events), a fila de recálculo deve ser modelada como **eventos de domínio**, não como tabela de tarefas genérica.

> **Observação:** o legado NÃO tem um barramento de eventos de domínio — ele emula com a tabela `presenca_historicotarefa` (fila de recalculos) e com intervenções (`tjpi`). A lista abaixo propõe a **semântica de eventos** que o Frequência deve adotar, com a **equivalência legada** e evidência.

---

## Eventos de Domínio Propostos

| # | Evento | Significado | Equivalente legado | Evidência |
|---|--------|-------------|--------------------|-----------|
| E1 | `BatidaRecebida` | Lote de batidas recebido da estação e armazenado (bruto) | `RegistroEstacaoPonto` criado no `SincronizarRegistrosPonto` | Fluxo A; `SincronizarRegistrosPonto.java:34-51` |
| E2 | `BatidasProcessadas` | Lote processado, gerando `RegistroFrequencia` | job `ProcessarArquivoSincronizado` marca `processado=true` | Fluxo A; `ProcessarArquivoSincronizado.java:136-138` |
| E3 | `RegistroFrequenciaSalvo` | Nova batida persistida → dispara recálculo do dia | `HistoricoTarefaServices.addTarefaRegistro` (REGISTRO_FREQUENCIA) — **ponto de chamada comentado** | Fluxo A P3; `HistoricoTarefaServices.java:526` |
| E4 | `DiaRecalculado` | `CalculoDiario` do dia (re)calculado | `CalculoDiarioServiceV2.atualizarDia` / `criaOuAtualizaDiario` | Fluxo B T1-T4 |
| E5 | `DiaAtualizado` | `CalculoDiario` criado/alterado por caminho de UI/desconsiderar | `CalculoDiarioService.INSTANCE.atualizar` (v1) nas ops de gestão | Fluxo D |
| E6 | `MesConsolidado` | `RegistroMensalFrequencia` recalculado/consolidado | `RegistroMensalFrequenciaServices.calcular` | Fluxo C |
| E7 | `RegistroDesconsiderado` / `Reconsiderado` | Batidas de um dia anuladas/restauradas | `RegistroFrequencia.desconsiderar/reconsiderar` | Fluxo D G2/G3 |
| E8 | `AutorizacaoAcumuloDeferida` / `Indeferida` | Decisão do gestor sobre acúmulo de horas | `deferir/indeferirAcumuloHorasExtras` | Fluxo D G5 |
| E9 | `AutorizacaoPredioDeferida` / `Indeferida` | Decisão sobre batida em prédio não permitido | `deferir/indeferirBaterPontoOutroPredio` | Fluxo D G6 |
| E10 | `RetificadorAplicado` | Ajuste de banco de horas criado → recalcular mês | `RetificadorServices.criarRetificador` (+`ehPraRecalcular`) | Fluxo C F9 |
| E11 | `RelatorioFinalGerado` / `Alterado` | Fechamento definitivo criado/atualizado | `RelatorioFrequenciaFinalServices.montarRelatorio/atualizarRelatorio` | Fluxo C |

---

## Eventos de domínio **de entrada** (vindos de PESSOAS) — consumidos pelo FREQUÊNCIA

| # | Evento | Significado | Contexto origem |
|---|--------|-------------|-----------------|
| P1 | `FrequentadorCadastrado` / `Atualizado` | Mudança cadastral que afeta o frequentador | PESSOAS |
| P2 | `LotacaoAlterada` | Mudança de lotação (`lotacaoEpoca` dos registros) | PESSOAS |
| P3 | `VinculoEncerrado` / `Aposentado` | Deixa de ser frequentador ativo (alimenta `CalculoDiarioAusentes`) | PESSOAS |

> Esses eventos viabilizarão o **cache local** no Frequência (ADR-0001) e a manutenção da view `presenca_frequentadorestacao` (ACL). Ver `02-bounded-contexts.md`.

---

## Barramento/Transporte no alvo

- **Recomendação:** modelar os recalculos (E2–E10) como **eventos publicados** e consumidos por **jobs (Sidekiq/Active Job)** — substituindo a fila `presenca_historicotarefa`.
- **Integração Pessoas→Frequência:** eventos P1–P3 em **barramento de eventos** (ex.: Redis/Outbox) para invalidar/atualizar cache (ADR-0001).
- **RECALCULAR_TODOS:** no legado recalcula via **v1** (`HistoricoTarefaServices.deserializarRecalcular` l.500-522) — **divergência de motor** a resolver (ver fluxo B D7).

---

## Matriz Evento → Recalculo disparado

| Evento | Agregado afetado | Recalculo | Motor legado |
|--------|------------------|-----------|--------------|
| E3 RegistroFrequenciaSalvo | AG-3 Dia | recalc do dia | (enqueue comentado — P3) |
| E5 DiaAtualizado (desconsiderar/reconsiderar) | AG-3 Dia | recalc do dia | **v1** (D G7) |
| E8/E9 Autorizações | AG-3 Dia | recalc mês | v2 (D G7) |
| E10 RetificadorAplicado | AG-4 Mensal | recalc mês | v2 (C F9) |
| E11 Relatório | AG-5 Relatório | gera/atualiza | n/a |
| P1-P3 (Pessoas) | AG-1 Frequentador / view | re-sincroniza cache | n/a |

> ⚠️ **Dívida:** a divergência v1/v2 em recalculos (E5 vs E8/E9/E10) é um problema de corretude a resolver na Fase 4/8 (testes de contraste). Ver `01-inventario/03-calculo-diario.md` §3.

---
**Última atualização:** 2026-08-05
**Fase:** 3 — Mapeamento de Domínio (DDD)
