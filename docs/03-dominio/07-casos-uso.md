# Casos de Uso — Frequência (Priorizados)

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Listar e priorizar os **casos de uso** do contexto FREQUÊNCIA, derivados dos fluxos (Fase 2) e agregados (Fase 3), para **ordenar as entregas** da Fase 7 (plano de implementação) e priorizar testes da Fase 8.

> **Critério de prioridade:** P0 = crítico para a EstaçãoPonto continuar (compatibilidade ADR-0003) / coração do cálculo; P1 = essencial para fechamento; P2 = gestão/ajustes; P3 = periférico/retirada de débito.

---

## Casos de Uso

| ID | Caso de Uso | Ator | Agregado(s) | Fluxo | Prioridade |
|----|-------------|------|-------------|-------|------------|
| UC-01 | **Receber lote de batidas** (EP-05) e persistir bruto | Estação Ponto | AG-7 | A | **P0** |
| UC-02 | **Processar lote** → gerar `RegistroFrequencia` (job) | Sistema (job) | AG-7 → AG-3 | A | **P0** |
| UC-03 | **Autenticar frequentador na estação** (EP-01 `ValidarFrequentador`) | Estação Ponto | AG-1 + ACL Pessoas | (via PoC) | **P0** |
| UC-04 | **Sincronizar digitais/relógio/heartbeat** (EP-02/03/04/06) | Estação Ponto | AG-6 | (via PoC) | **P0** |
| UC-05 | **Calcular dia** (orquestra estratégia por modalidade) | Sistema (job) | AG-3 | B | **P0** |
| UC-06 | **Consolidar mês** (`RegistroMensalFrequencia` + saldo) | Sistema (job) | AG-3 → AG-4 | C | **P0** |
| UC-07 | **Gerar/atualizar relatório final** (mês seguinte, único) | Gestor | AG-4 → AG-5 | C | **P1** |
| UC-08 | **Registrar batida manual / errata** | RH/gestor | AG-3 | D | **P1** |
| UC-09 | **Desconsiderar / reconsiderar ponto** (gestor do órgão) | Gestor | AG-3 | D | **P1** |
| UC-10 | **Autorizar acúmulo de horas extras** (deferir/indeferir) | Gestor | AG-3 | D | **P1** |
| UC-11 | **Autorizar batida em prédio não permitido** (deferir/indeferir) | Gestor | AG-3 | D | **P1** |
| UC-12 | **Aplicar retificador de banco de horas** | RH | AG-4 | C | **P1** |
| UC-13 | **Cadastrar/gerir regimes e jornadas** | RH | AG-2 | B | **P1** |
| UC-14 | **Cadastrar frequentador** (sync com Pessoas) | RH | AG-1 + ACL | — | P2 |
| UC-15 | **Cadastrar/gerir estações** (incl. prédios, versão) | RH | AG-6 | A | P2 |
| UC-16 | **Registrar valores retroativos** | RH | AG-5 | C | P2 |
| UC-17 | **Recalcular todos / recalcular mês** (evento/job) | Sistema | AG-3/4 | B/C | P2 |
| UC-18 | **Apresentar frequências/relatórios** (dashboards) | Gestor/RH | AG-3/4/5 | (via UI) | P2/P3 |

---

## Prioridades de Entrega (link para Fase 7)

**Corte 1 (P0 — manter Estação Ponto + cálculo):** UC-01 a UC-06 — cobre o ciclo A (ingestão) e B (cálculo), que é o coração do domínio e o que a PoC já antecipa parcialmente.

**Corte 2 (P1 — fechamento e gestão):** UC-07 a UC-13 — fechamento mensal/definitivo, retificador e gestão de registro (fluxos C e D).

**Corte 3 (P2/P3):** UC-14 a UC-18 — cadastro/sync, estações, retroativos, reporting.

> A ordenação na Fase 7 pode mudar se gestores definirem novo valor de negócio, mas a **dependência técnica** (UC-06 precisa de UC-05; UC-07 precisa de UC-06) é fixa e deve ser respeitada.

---

## Caso de Uso chave (detalhe) — UC-02 "Processar lote"

- **Pré-condição:** lote bruto persistido (UC-01) com estação válida.
- **Fluxo principal:** job (a cada 5min) → descriptografar DES → dedup (`getRegistroByData`) → aplicar restrição de prédio (R3) → criar `RegistroFrequencia` (modo BIOMÉTRICO) → marcar lote processado.
- **Pós-condição:** `RegistroFrequencia` persistidos; **não dispara recálculo automático** (enqueue comentado — P3 do fluxo A).
- **Fluxos alternativos:** frequentador inexistente (descarta); dedup (pula); prédio não permitido (cria pendência de autorização → UC-11).

---
**Última atualização:** 2026-08-05
**Fase:** 3 — Mapeamento de Domínio (DDD)
