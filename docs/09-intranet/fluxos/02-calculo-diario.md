# Fluxo — Cálculo Diário de Frequência (Fase 2: Engenharia Reversa)

> **[⌂ Home](../../README.md)**

## Propósito

Documentar o **fluxo de processamento de batidas → cálculo diário de frequência** no módulo `presenca`: como um conjunto de `RegistroFrequencia` de um dia é transformado em um `CalculoDiario` (horas normais/excepcionais, falta/ausência/saída antecipada, banco de horas diário), com ênfase no motor **v2** (o ativo), e como o recálculo é disparado.

> **Fase 2 (Engenharia Reversa).** Regras com **EVIDÊNCIA** (`arquivo:linha`). Fonte: `intranet/src/modules/presenca/`. Complementa o inventário estrutural em `01-inventario/03-calculo-diario.md`; aqui o foco é **fluxo + regras + disparo**, não a listagem de entidades.

**Escopo:** entrada = `RegistroFrequencia` persistido (do fluxo A) + domínios de apoio (regime, direitos, feriados, dias excepcionais); saída = `CalculoDiario` (diário) e seus reflexos no `RegistroMensalFrequencia`. Consumido pelo fluxo C (Fechamento).

> ⚠️ **Dois motores coexistem (v1 e v2).** Este documento prioriza o **v2** (usado pela maioria dos jobs), mas evidencia as **divergências v1×v2** porque reproduzir o histórico exige conhecer os cortes temporais.

---

## Mapa de Dependências

```
[disparo]
   ├─ Job RecalculoDiario (cron 21:15)  → atualizarMesNoAno
   ├─ Job ExecutaTarefas (cron 5min)    → consume fila HistoricoTarefa (REGISTRO_FREQUENCIA/DIA/DIREITO/REGISTRO_ESTACAO...)
   ├─ UI (DynMostraRegistroFrequencia, CalculoFrequenciaActions, desconsiderar/reconsiderar) → atualizarDia/corrigir
   └─ (novas batidas do fluxo A: enqueue NO addTarefaRegistro comentado → recálculo só via jobs/manual)
        │
        ▼
CalculoDiarioServiceV2.criaOuAtualizaDiario / atualizarDia
   │
   ├─> DiaServices.mapDias  (monta o "dia": registros, calculo, direitos, diasExcepcionais, regimeFrequentador, feriados)
   │      └─ BuscaPeriodosV2.mapPeriodosACumprir (NO/EXC/METAS + abonos/onerações/feriados/direitos)
   │
   ├─> calcularDia(dia) → escolhe estratégia pela Modalidade (com corte 01/12/2018)
   │      ├─ HORAS_COM_INTERVALO → EntradasESaidasV2
   │      ├─ HORAS (≥01/12/2018) → PrimeiraEntradaUltimaSaidaV2 ; (<) → PrimeiraEntradaUltimaSaidaOldV2
   │      ├─ OCORRENCIAS → OcorrenciasV2
   │      └─ sem regime → CalculoDiario.informacao="Nenhum regime ativo nesta data"
   │      └─ CalculoStrategyV2.execute() (template method)
   │
   ├─> definirLabelsParaCalculosDiarios (faltas compensadas × a descontar, limite 10)
   │
   ▼
CalculoDiario persistido (+ reflexos no RegistroMensalFrequencia) → Fluxo C (Fechamento)
```

---

## Diagrama de Sequência — Recálculo por Mês (via Job/Manual)

```
[Chamador: RecalculoDiario | UI | HistoricoTarefa]      CalculoDiarioServiceV2        DiaServices            RegistroMensalFreq Services
        │  atualizarMesNoAno(f, mes, ano)                    │                        │                        │
        │──────────────────────────────────────────────────▶│                        │                        │
        │                                                   │  monta Periodo(inicioMes, fim)                     │
        │                                                   │  dias = periodo.getDias()                          │
        │                                                   │                        │                        │
        │                             criaOuAtualizaDiario(f, dias)                 │                        │
        │                              agrupaPorMes → [mes]                        │                        │
        │                              mapDias = DiaServices.mapDias(f, mes, ano)   │                        │
        │                              ───────────────────────────────────────────▶│                        │
        │                              │  (monta maps: registros, calculos,        │                        │
        │                              │   direitos, diasExcepcionais,             │                        │
        │                              │   regimes, feriados)                      │                        │
        │                              │  para cada dia: new Dia(...)              │                        │
        │                              │◀──────────── map<String,Dia> ─────────────│                        │
        │                              │                                          │                        │
        │                              │  rmf = getRegistroDoFrequentadorNoMesEAno│                        │
        │                              │  se rmf == null || !rmf.isFinalizado():   │                        │
        │                              │    calculos = calcularDias(mapDias)      │                        │
        │                              │      (para cada Dia: calcularDia →        │                        │
        │                              │        estratégia V2 .execute() → Dao.save)│                        │
        │                              │    rmf = RegistroMensalFreqServices.calcular(f, mes) ──▶│                │
        │                              │    liga calculoDiario.setRegistroMensal(rmf)           │                │
        │                              │    rmf.setMomentoUltimoCalculo(agora)                    │                │
        │                              │    se dataInicio > 31/03/2017:                            │                │
        │                              │       definirLabelsParaCalculosDiarios(rmf, calculos)    │                │
        │                              │    Dao.saveOrUpdate(rmf)  ◀──────────────────────────────┘                │
        │◀─────────────────────────────────────────── fim ────────────────────────────────────────│
```

**EVIDÊNCIAS (v2 — motor ativo):**
- `CalculoDiarioServiceV2.java:25-48` — `atualizarMesNoAno` (monta `Periodo`, chama `criaOuAtualizaDiario`).
- `CalculoDiarioServiceV2.java:50-98` — `criaOuAtualizaDiario`: agrupa por mês (`agruparPorMes`), `DiaServices.mapDias`, verifica `rmf == null || !rmf.isFinalizado()`, `calcularDias`, `RegistroMensalFrequenciaServices.calcular`, `setMomentoUltimoCalculo`, `definirLabels` se `dataInicio > 31/03/2017`.
- `DiaServices.java:34-59` — `mapDias` monta o agregado `Dia` (registros, calculo prévio, direitos, diasExcepcionais, regimeFrequentador, feriados).
- `CalculoDiarioServiceV2.java:264-288` — `calcularDia` despacha pela `Modalidade` com corte em `2018-12-01`.
- `CalculoDiarioServiceV2.java:207-262` — `calcularDias` zera flags, seta configurações do regime, chama `calcularDia`, `setHorarioRecalculo`, `Dao.saveOrUpdate`.

---

## Diagrama de Atividades — Estratégia (Template Method `CalculoStrategyV2.execute`)

```
execute()
  │
  ├─ dia.setPeriodosACumprir( BuscaPeriodosV2.mapPeriodosACumprir() )   [NO/EXC/METAS]
  ├─ resetaStatusRegistrosFrequencia()   [zera Zona/Horario/Operacao de cada registro]
  ├─ temExpedienteExcepcional = !periodosExcepcionais.isEmpty()   //fixme: sempre false
  ├─ configuraCalculoDiario(temExpedienteExcepcional)
  │      • init/validação (marca ABERTO se duração < 300s)
  │      • meta do dia (base = período normal; dias especiais/GCET podem usar 99999s)
  │      • dispatcher → método concreto (calcularCom/Sem ExpedienteExcepcional)
  │           └─ define momentoParaCalculo, entradas/saídas, falhas, ausências, saída antecipada, banco diário
  ├─ definirZonaRegistros(...)   [NORMAL/ANORMAL por limites de expediente]
  └─ Dao.save(registros)
```

**EVIDÊNCIA:** `CalculoStrategyV2.java:39-48` — `execute()` (ordem dos passos). `CalculoStrategyV2.java:53+` — `definirZonaRegistros`. Constantes: `CalculoStrategyV2.java:23-30` (`LIMITE_PARA_SAIDA_EM_SEGUNDOS=300`, `MAXIMO_PERMITIDO_ACUMULAR_POR_DIA=7200` (2h), `GCET=2700` (45min), `INTERVALO_PRA_INICIAR_ACUMULAR=900` (15min), `MAX_PERMITIDO_SAIDA_ANTECIPADA_MENSAL=999`).

---

## Disparos do Cálculo (quem chama)

| # | Disparo | Mecanismo | Evidência |
|---|---------|-----------|-----------|
| T1 | **Recálculo noturno** | Job `RecalculoDiario`, cron `0 15 21 * * ?` (21:15), 15 threads, recalcula **mês anterior + atual** via `atualizarMesNoAno` | `jobs/RecalculoDiario.java:29-32`, `criarListaComIdsTodosFrequentadores` + `CalculoDiarioServiceV2.atualizarMesNoAno` |
| T2 | **Fila assíncrona** | Job `ExecutaTarefas` (5min) consome `HistoricoTarefa`; despacha por `TipoEntidade` → v2 `atualizarDia`/`atualizarMesNoAno` | `HistoricoTarefaServices.executaTarefa` (l.34-58), `processarRegistroEstacao` (l.92-96) → `atualizarDia` |
| T3 | **Caminhos de UI** | `DynMostraRegistroFrequencia`, `CalculoDiarioAusentes`(desativado p/ cálculo), `desconsiderar/reconsiderarPonto` | `RegistroFrequenciaServices.java:115,123`; ver `03-calculo-diario.md` §6 |
| T4 | **HistoricoTarefa de REGISTRO** | `addTarefaRegistro` (enfileira REGISTRO_ESTACAO → recalcula) **existe** mas o ponto de chamada no sync de batidas está **comentado** | `HistoricoTarefaServices.addTarefaRegistro` (l.526); `ProcessarArquivoSincronizado.java:131` (comentado) |

> ⚠️ **DESCOBERTA-IMPORTANTE (encadeamento):** no fluxo A, o código que enfileiraria o recálculo de novas batidas (`addTarefaRegistro`) está **comentado** (`ProcessarArquivoSincronizado.java:131`). Consequentemente, as **batidas biométricas não disparam recálculo imediato** — o `CalculoDiario` para elas só é (re)computado pelos caminhos T1 (noturno), T2 (outras tarefas) ou T3 (UI). O módulo é, portanto, **não-real-time para cálculo após batida**.

---

## Regras de Negócio do Cálculo Diário

| # | Regra | Detalhe | Evidência | Tipo |
|---|-------|---------|-----------|------|
| C1 | **Seleção de estratégia por Modalidade** | HORAS_COM_INTERVALO→`EntradasESaidasV2`; HORAS→corte **01/12/2018** (`Old` antes, `New` depois); OCORRENCIAS→`OcorrenciasV2`; sem regime→`informacao="Nenhum regime ativo nesta data"` | `CalculoDiarioServiceV2.calcularDia` (l.264-288) | Regra explícita |
| C2 | **Períodos a cumprir (NO/EXC/METAS)** | `BuscaPeriodosV2` resolve conflitos entre regime, direitos, abonos, onerações e feriados → períodos a cumprir + metas | `CalculoStrategyV2.execute` (l.41); `BuscaPeriodosV2.mapPeriodosACumprir/resolverConflitos` (l.69-73) | Regra explícita |
| C3 | **Falta** | Quando `meta > 0`, `total == 0`, dia **não aberto** e **data anterior a hoje** → marca falta | `configuraFalta` (v1/v2) | Regra explícita |
| C4 | **Ausência** | `trabalhado > 0` e `< meta × percentualCargaMinima/100` → ausência | ver `03-calculo-diario.md` §5 | Regra explícita |
| C5 | **Dia aberto (incompleto)** | Marca `aberto` se a duração do expediente calculada < 300s (expediente incompleto em andamento) | `CalculoStrategyV2` init/validação; const `LIMITE_PARA_SAIDA_EM_SEGUNDOS=300` (l.23) | Regra explícita |
| C6 | **Banco de horas diário** | Acumula após **15min** de intervalo; máx **2h/dia (7200s)** ou **45min GCET (2700s)**; `verificarFrequentadorLimitado` limita pelo saldo (LIMITADO) | `CalculoStrategyV2.java:24-27,140-152` | Regra explícita |
| C7 | **Faltas compensadas × a descontar** | Percorre faltas: se `compensadas < maxFaltasPorAno` E saldo cobre a meta E `permitidoCompensarFalta` → falta compensada; senão → falta a descontar, com **limite de 10 descontos** hardcoded e exceção de estagiário não-extracurricular | `definirLabelsParaCalculosDiarios` (l.100-205); limite 10 em l.~186 | Regra explícita (limite 10 = TODO/hardcoded) |
| C8 | **Zona NORMAL/ANORMAL** | Batida antes do 1º início ou após o último fim do expediente → `ANORMAL`; senão `NORMAL` (OCORRENCIAS força NORMAL) | `CalculoStrategyV2.definirZonaRegistros` (l.53-90) | Regra explícita |
| C9 | **Momento p/ cálculo (batida ajustada)** | `momentoParaCalculo` é a batida ajustada às regras de limite (saída antecipada, turno, MUITO_TARDE etc.) — valor usado nos totais | `PrimeiraEntradaUltimaSaidaV2.definirMomentoParaCalculo` (l.228+) | Regra explícita |

### Regras implícitas / RISCO (v1 × v2 divergência)

| # | Implícita / Risco | Detalhe | Evidência |
|---|-------------------|---------|-----------|
| D1 | **Saída antecipada mensal divergente** | v2 tem a consulta de saídas antecipadas **comentada** e fixa `qtdSaidasAntecipadasMensal = 0` → diverge do v1 (que consulta o banco) | `PrimeiraEntradaUltimaSaidaV2.java:252-253` vs `PrimeiraEntradaUltimaSaida.java:276` |
| D2 | **Ponto MUITO_TARDE** | v1 força `limiteMaximoSaida`; v2 respeita hora real se `liberadoBloqueioMaxHoraExtra` | `03-calculo-diario.md` §3 |
| D3 | **Banco GCET (45min)** | v1 sem fim; v2 limitado a `before(2022,10,26)` — inconsistência de período | `CalculoStrategyV2.java:419-421` vs `CalculoDiarioStrategy.java:491-492` |
| D4 | **Dias especiais hardcoded** | Datas 21-23/11/2022 com banco 99999s — regra temporária | `CalculoStrategyV2.java:423-429` |
| D5 | **Detecção de expediente excepcional sempre false** | `//fixme: nao funciona(aers) sempre retorna false` → talvez nunca haja expediente excepcional | `CalculoStrategyV2.java:44` |
| D6 | **`getRestanteACompensar` usa `Calendar.MONDAY`** | Dia-da-semana usado como dia-do-mês (provável bug) | `CalculoDiario.java:324` |
| D7 | **Motor v1 ainda em uso** | v1 invocado em `CalculoFrequenciaActions.java:24`, `RegistroFrequenciaServices.java:115,123`, `HistoricoTarefaServices.deserializarRecalcular` (l.516 — RECALCULAR_TODOS usa **v1**) → resultados podem divergir do v2 | `HistoricoTarefaServices.deserializarRecalcular` (l.500-522) |

---

## Cortes Temporais Críticos (reprodução de histórico)

| Corte | Impacto | Evidência (v2) |
|-------|---------|----------------|
| **01/12/2018** | Troca algoritmo de `HORAS`: `PrimeiraEntradaUltimaSaidaOld` → `PrimeiraEntradaUltimaSaida` | `CalculoDiarioServiceV2.java:273` |
| **>31/03/2017** | Passa a rodar `definirLabelsParaCalculosDiarios` (faltas compensadas) | `CalculoDiarioServiceV2.java:84-85` |
| **>26/10/2022** | Limite anual de faltas compensadas 10 → **12** | `CalculoDiario.getMaxFaltasCompensadasPermitidasPorAno` (`beans/CalculoDiario.java:327-333`); `DefinirLabels` usa este método |
| **01/05/2017** (v2) | Intervalo de 15min p/ acumular horas | `CalculoStrategyV2.java:382-383` |
| **≤2022-10-26 (v2)** | Banco GCET 45min só até este corte | `CalculoStrategyV2.java:419-421` |

---

## Cross-reference

- **Entidades/tabelas:** `01-inventario/06-tabelas-banco.md` (§3 `presenca_calculodiario`, §5 `registromensalfrequencia`)
- **Domínio detalhado:** `01-inventario/03-calculo-diario.md`
- **Entrada (batidas):** `09-intranet/fluxos/01-batida-ponto.md` (fluxo A)
- **Saída (fechamento):** `09-intranet/fluxos/03-fechamento.md` (fluxo C — a diagramar)
- **DUVs relacionadas:** `DUV-005` (motor v1/v2), `DUV-012` (cortes temporais), `DUV-013` (faltas 10→12 + `Calendar.MONDAY`)

---
**Última atualização:** 2026-08-05
**Fase:** 2 — Engenharia Reversa (fluxo B: cálculo diário)
