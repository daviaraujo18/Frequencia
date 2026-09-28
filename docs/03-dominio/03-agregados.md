# Agregados — Domínio Frequência

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Identificar os **agregados** do contexto FREQUÊNCIA, suas **raízes (aggregate roots)** e a **consistência** que cada um garante. Base para o design de estruturas transacionais no Rails (Fase 4).

> **Relação com fluxos (Fase 2):** cada agregado aqui surge de um fluxo documentado (A–D). Consistência forte = dentro do agregado; consistência eventual = entre agregados/contextos.

---

## Agregados Identificados

### AG-1 — `Frequentador` (raiz)
- **Raiz:** `Frequentador` (id)
- **Membros internos:** `DigitaisHash` (value object), `PrediosPermitidosParaBaterPonto` (refs a Prédio/ACL), flags de configuração (`limitarPrediosPermitidos`, `permitirManual`, `limitarAcumuloHoras`).
- **Regras de consistência:**
  - Validação de frequentador pela lotação/categoria/gestor (via Pessoas ACL).
  - Restrição de prédio ao bater ponto (referenciado no fluxo A R3).
- **Referenciado por:** quase todos os agregados (via `frequentador_id`).

### AG-2 — `Regime` (raiz) + `RegimeFrequentador` (agregado filho/vínculo)
- **Raiz:** `Regime` — contém `RegimeConfiguracao` (value object embutido: `ConfiguracaoFrequencia`), períodos/expedientes, categorias de vínculo.
- **Membro:** `RegimeFrequentador` (vínculo regime×frequentador com período de vigência e tipo).
- **Consistência:** definir qual regime vale em cada data (resolução de períodos). Base do fluxo B (períodos a cumprir).

### AG-3 — `Dia` (agregado de cálculo diário) — **núcleo do motor**
- **Raiz:** `Dia` (agregado já existe no legado como unidade de cálculo: `DiaServices.mapDias` monta `Dia` com registros+calculo+regime+direitos+excepcionais+feriados).
- **Membros internos:** lista de `RegistroFrequencia` (batidas do dia), `CalculoDiario` (resultado), referências a regime/direitos/excepcionais/feriados.
- **Consistência:** o cálculo diário **deve processar o dia como uma unidade** (entradas+saídas+meta→falta/ausência/banco). Corresponde a `DiaServices.mapDias` + `CalculoStrategyV2.execute()` (fluxo B).
- **Intervalo de consistência:** granularidade de **1 dia por frequentador**.

### AG-4 — `RegistroMensalFrequencia` (raiz, fechamento mensal)
- **Raiz:** o registro mensal **por frequentador+mês/ano**.
- **Membros:** valores consolidados (saldos, metas, trabalhado, faltas), itens de `Retificador` aplicados, `finalizado` (lock).
- **Consistência:** fechamento do mês processa **todos os `Dia` do mês** como unidade (fluxo C). Responsável pelo saldo acumulado/retido.

### AG-5 — `RelatorioFrequenciaFinal` (raiz, fechamento definitivo)
- **Raiz:** relatório final por **mês/ano**.
- **Membros:** itens `RelatorioFrequentador` (saldo bruto, valor retroativo, resultado) + valores retroativos.
- **Consistência:** relatório é gerado/alterado no **mês seguinte** e é **único** por mês/ano (fluxo C F6/F7).

### AG-6 — `EstacaoPonto` (raiz)
- **Raiz:** `EstacaoPonto` (id + `codAtivacao`).
- **Membros internos:** prédios vinculados (`EstacaoPredio`), `VersaoEstacaoPonto`, `EstacaoPing` (heartbeat).
- **Membro externo (outro agregado):** `RegistroEstacaoPonto` (lote bruto recebido) — processado assíncrono para gerar `RegistroFrequencia` (AG-3).
- **Consistência:** validar a estação pelo `codAtivacao` (fluxo A EP-05/06).

### AG-7 — `RegistroEstacaoPonto` (raiz — lote bruto de batidas)
- **Raiz:** o lote criptografado recebido (`SincronizarRegistrosPonto`).
- **Consistência:** persistido imediatamente (auditoria) e **processado em lotes** pelo job `ProcessarArquivoSincronizado` (fluxo A). Marca `processado=true`.

---

## Mapa de Agregados → Fluxos

| Agregado | Raiz | Fluxo | Consistência |
|----------|------|-------|--------------|
| AG-1 Frequentador | `Frequentador` | A, D | forte (estado+restrições) |
| AG-2 Regime | `Regime` (+ RegimeFrequentador) | B | forte (períodos) |
| AG-3 Dia | `Dia` (+ RegistroFrequencia + CalculoDiario) | B | **forte — unidade diária** |
| AG-4 Registro Mensal | `RegistroMensalFrequencia` | C | forte (mês inteiro) |
| AG-5 Relatório Final | `RelatorioFrequenciaFinal` | C | forte (mês/ano, mês+1) |
| AG-6 Estação de Ponto | `EstacaoPonto` | A | forte (cadastro+validação) |
| AG-7 Lote de Batidas | `RegistroEstacaoPonto` | A | forte (lote) |

---

## Consistência entre agregados (eventual)

```
AG-7 (lote) ──processa job──▶ AG-3 (Dia) ──fecha mês──▶ AG-4 (Mensal) ──gera──▶ AG-5 (Relatório)
      │  ingestão assíncrona (fluxo A: job 5min)   │ recálculo (fluxo B)  │ fechamento (fluxo C)
      ▼
   AG-6 (estação) valida / AG-1 (frequentador) dono dos registros
```

- **AG-7 → AG-3:** eventualmente consistente (job 5min; não-real-time p/ cálculo, ver fluxo A P3).
- **AG-3 → AG-4 → AG-5:** recalculados juntos em `criaOuAtualizaDiario` (fluxo B) — mas `finalizado` nunca efetivado (DUV-010) impede verdadeiro "congelamento".

---

## Notas / riscos para modelagem

1. **`Dia` já é um agregado no legado** (`DiaServices.mapDias`) — é a unidade correta de cálculo. Recomenda-se **manter `Dia` como agregado** no alvo.
2. **`CalculoDiario` e `RegistroFrequencia` NÃO são raízes** — são membros de AG-3 (`Dia`). Ponto importante: a persistência hoje os trata como tabelas independentes; no alvo devem ser tratados dentro do agregado `Dia`.
3. **`finalizado` (lock) inoperante** (DUV-010): o agregado AG-4 precisa de um mecanismo real de congelamento no alvo (não é apenas `finalizado`).
4. **Refs a Pessoas**: `Frequentador.lotacaoEpoca`, `Registros.lotacaoEpoca` (Orgao), `User` — viram **ACL/IDs**, não membros do agregado (ver `02-bounded-contexts.md`).

---
**Última atualização:** 2026-08-05
**Fase:** 3 — Mapeamento de Domínio (DDD)
