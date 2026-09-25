# Fluxo — Gerenciamento de Registro de Frequência (Fase 2: Engenharia Reversa)

> **[⌂ Home](../../README.md)**

## Propósito

Documentar o **fluxo de gestão/correção de um `RegistroFrequencia`** no módulo `presenca`, pós-ingestão (fluxo A): **registro manual/errata**, **desconsiderar/reconsiderar** ponto, e os fluxos de **autorização** (acúmulo de horas extras e batida em prédio não permitido). Cada operação altera o estado do registro e (na maioria) **dispara recálculo**.

> **Fase 2 (Engenharia Reversa).** Regras com **EVIDÊNCIA** (`arquivo:linha`). Fonte: `intranet/src/modules/presenca/`. É o fechamento do ciclo A→B→C→D: este fluxo atua sobre registros (A) e recálcula o diário (B).

**Escopo:** adição manual e correções/validações de batidas; autorizações via intervenção. Considera o `PreVinculadoIntervencao` (módulo `tjpi`) como mecanismo de trilha de auditoria/autorização.

---

## Mapa de Dependências

```
[RegistroFrequencia bean — núcleo de estados e operações]
   ├─ manualFromForm(errata, obs, file, responsavel, ips, ressalva)   [registro manual + errata]
   ├─ desconsiderar(obs, responsavel, ips)          → Horario.DESCONSIDERADO        [+ v1 atualizar]
   ├─ desconsiderarPorPredioNaoPermitido(...)       → Horario.DESCONSIDERADO_PREDIO [+ v1 atualizar]
   ├─ reconsiderar(responsavel, ips)                → Horario.NORMAL                [+ v1 atualizar]
   ├─ solicitarBaterPontoEmPredioNaoPermitido(...)  → Horario.SOLICITADO_AUTORIZACAO_PREDIO
   ├─ preencheIntervencaoLimitado(...)              → cria intervenção de acúmulo
   └─ reconsiderar/limite: usa PreVinculadoServices.novaIntervencaoPassiva (tjpi)

[RegistroFrequenciaServices — orquestração]
   ├─ desconsiderarPonto / reconsiderarPonto        [gestor; + CalculoDiarioService.INSTANCE.atualizar = v1]
   ├─ deferirAcumuloHorasExtras / indeferirAcumuloHorasExtras   [+ v2 atualizarMesNoAno]
   └─ deferirBaterPontoOutroPredio / indeferirBaterPontoOutroPredio [+ v2 atualizarMesNoAno]

[UI/actions]
   ├─ RegistroFrequenciaActions.create/update (manual/errata)
   ├─ DynDesconsiderarPonto.submit / .reconsiderar  (@AsynchronousAction AJAX)
   └─ ajax: PermitirCompensarFaltas, LiberarLimitacaoInicioHoraExtra, LiberarBloqueioMaxHoraExtra, RetirarFaltaDescontadaEmFolha
```

---

## Diagrama de Sequência — Registro Manual / Errata

```
[UI: RegistroFrequenciaActions.create(registro, obs, file)]     RegistroFrequencia         PreVinculadoServices(tjpi)
   │  registro.manualFromForm(false, obs, file, resp, ips)          │                              │
   │────────────────────────────────────────────────────────────────▶│                              │
   │                                                                 │  setModo(MANUAL)             │
   │                                                                 │  setOperacao(INDEFINIDO)     │
   │                                                                 │  setRessalva(res salva)      │
   │                                                                 │  setEstacaoPonto(null)       │
   │                                                                 │  lotacaoAtual (vinculo)      │
   │                                                                 │  momentoSincOffline=agora    │
   │                                                                 │  !errata → Dao.save(this)    │
   │                                                                 │  novaIntervencaoPassiva(     │
   │                                                                 │    ACAO_CONTROLE_FREQUENCIA /│
   │                                                                 │    _ERRATA, file, resp, ips) ─▶│
   │                                                                 │  setIntervencao(intervencao) │
   │                                                                 │  Dao.update(this)            │
   │◀──────────────── finder para regenerar form ───────────────────│                              │
   ▼
   (fluxo B: recalculo do dia, via caminhos T1/T2/T3)
```

**EVIDÊNCIAS:**
- `RegistroFrequencia.java:manualFromForm` — cria registro manual/errata: `setModo(MANUAL)`, `setOperacao(INDEFINIDO)`, `setEstacaoPonto(null)`, `setMomentoSincOffline`, `setAtivo(true)`, `novaIntervencaoPassiva(ACAO_CONTROLE_FREQUENCIA[_ERRATA])`, `Dao.save` (se !errata) / `Dao.update`.
- `RegistroFrequenciaActions.java:78-82` — `create` → `manualFromForm(false,...)` (registro novo).
- `RegistroFrequenciaActions.java:94-97` — `update` → `manualFromForm(true,...)` (**errata**).
- `RegistroFrequenciaValidator.validateUpdate` (l.83-90) — **só é possível editar ponto Manual** (`modo == MANUAL`).

---

## Diagrama de Sequência — Desconsiderar / Reconsiderar Ponto

```
[UI: DynDesconsiderarPonto.submit (diaId, motivoObs)]   RegistroFrequenciaServices       RegistroFrequencia      CalculoDiarioService(v1)
   │  validate(validateDesconsiderar)                      │                                │                            │
   │  desconsiderarPonto(calculoDiario, usuario, obs, ips) │                                │                            │
   │───────────────────────────────────────────────────────▶│                                │                            │
   │   getRegistrosByDia(f, data)                          │                                │                            │
   │   para cada registro:                                 │                                │                            │
   │     registro.desconsiderar(obs, resp, ips)  ─────────▶│                                │                            │
   │        setRessalva(true); setAtivo(true)              │                                │                            │
   │        setHorario(DESCONSIDERADO)                     │                                │                            │
   │        novaIntervencaoPassiva(ACAO_DESCONSIDERACAO)  ──▶ (tjpi)                        │                            │
   │        setIntervencao; Dao.update                     │                                │                            │
   │   CalculoDiarioService.INSTANCE.atualizar(f, data)   ──────────────────────────────────▶│ (MOTOR v1!)            │
   │◀─────────────────────────────────────────────────────│                                │                            │
   ▼
   (reconsiderarPonto: análogo, getRegistrosDesconsideradosByDia → reconsiderar → v1 atualizar)
```

**EVIDÊNCIAS:**
- `RegistroFrequenciaServices.java:110-116` — `desconsiderarPonto`: itera `getRegistrosByDia`, `registro.desconsiderar`, depois `CalculoDiarioService.INSTANCE.atualizar` (**v1**).
- `RegistroFrequenciaServices.java:118-124` — `reconsiderarPonto`: `getRegistrosDesconsideradosByDia`, `registro.reconsiderar`, `CalculoDiarioService.INSTANCE.atualizar` (**v1**).
- `RegistroFrequencia.java:desconsiderar` — `setRessalva(true)`, `setHorario(DESCONSIDERADO)`, `novaIntervencaoPassiva(ACAO_DESCONSIDERACAO_PONTO)`.
- `RegistroFrequencia.java:reconsiderar` — `setRessalva(false)`, `setHorario(NORMAL)`, `novaIntervencaoPassiva(ACAO_RECONSIDERACAO_PONTO)`.
- `DynDesconsiderarPonto.java:50-60,66-73` — `submit` (desconsidera) e `reconsiderar`, ambos `@Transactional` + `@AsynchronousAction(AJAX)`, validam `RegistroFrequenciaValidator`.
- `RegistroFrequenciaServices.java:91-108` — `podeDesconsiderarFrequencia` (regra de gestor/autorização abaixo).

> ⚠️ **RISCO (v1/v2):** o desconsiderar/reconsiderar recálcula via **`CalculoDiarioService.INSTANCE.atualizar` (motor v1)**, enquanto os caminhos usuais usam **v2** — contribui para a divergência de resultados (ver fluxo B D7).

---

## Diagrama de Atividades — Autorizações (acúmulo de horas / prédio)

```
[Registro entra em estado pendente de autorização]
   ├─ LIMITADO (acúmulo de horas extras)            → preencheIntervencaoLimitado (UM_ACAO_ACUMULO_DE_HORAS_EXTRAS)
   └─ SOLICITADO_AUTORIZACAO_PREDIO (prédio não período) → solicitarBaterPontoEmPredioNaoPermitido (ACAO_SOLICITACAO_PERMITIR_BATER_PONTO_OUTRO_PREDIO)
        │
        ▼
   [Gestor decide]
        │
        ├─ DEFERIR
        │    ├─ acúmulo:  deferirAcumuloHorasExtras → setHorario(original), setLimitado(false) [+ v2]
        │    └─ prédio:   deferirBaterPontoOutroPredio → setHorario(NORMAL), setRessalva(false) [+ v2]
        │         └─> CalculoDiarioServiceV2.atualizarMesNoAno
        │
        └─ INDEFERIR
             ├─ acúmulo:  indeferirAcumuloHorasExtras → setHorario(LIMITADO_INDEFERIDO) [+ v2]
             └─ prédio:   indeferirBaterPontoOutroPredio → setHorario(DESCONSIDERADO_PREDIO) [+ v2]
                  └─> CalculoDiarioServiceV2.atualizarMesNoAno
```

**EVIDÊNCIAS:**
- `RegistroFrequenciaServices.java:126-156` — `deferirAcumuloHorasExtras`: cria intervenção de autorização, `setIntervencao`, `calculoDiario.setLimitado(false)`, `atualizarMesNoAno` (v2).
- `RegistroFrequenciaServices.java:158-182` — `indeferirAcumuloHorasExtras`: `setHorario(LIMITADO_INDEFERIDO)`, `atualizarMesNoAno` (v2).
- `RegistroFrequenciaServices.java:184-211` — `deferirBaterPontoOutroPredio`: `setHorario(NORMAL)`, `setRessalva(false)`, `atualizarMesNoAno` (v2).
- `RegistroFrequenciaServices.java:213-234` — `indeferirBaterPontoOutroPredio`: `setHorario(DESCONSIDERADO_PREDIO)`, `atualizarMesNoAno` (v2).
- `RegistroFrequencia.java:solicitarBaterPontoEmPredioNaoPermitido`, `preencheIntervencaoLimitado` — geram a pendência inicial.

---

## Regras de Negócio do Gerenciamento

| # | Regra | Detalhe | Evidência | Tipo |
|---|-------|---------|-----------|------|
| G1 | **Só edita registro MANUAL** | `update`/errata é permitido somente quando `modo == MANUAL` | `RegistroFrequenciaValidator.validateUpdate` (l.83-90) | Regra explícita |
| G2 | **Desconsiderar registra intervenção** | Sempre cria `PreVinculadoIntervencao` (auditoria) e marca `Horario.DESCONSIDERADO`; `ressalva=true` | `RegistroFrequencia.desconsiderar`; `RegistroFrequenciaServices.desconsiderarPonto` | Regra explícita |
| G3 | **Reconsiderar restaura NORMAL** | `setHorario(NORMAL)`, `ressalva=false`, nova intervenção de reconsideração | `RegistroFrequencia.reconsiderar` | Regra explícita |
| G4 | **Só gestor do órgão pode desconsiderar** | `podeDesconsiderarFrequencia`: exige `usuario.isGestorOrgao(lotacaoAtual)`; gestor não pode agir sobre o próprio registro; desconsiderável só se não for meta-0/falta/compensada/descontada | `RegistroFrequenciaServices.java:91-108`; `DynDesconsiderarPonto.java:36-42` | Regra explícita |
| G5 | **Deferir acúmulo libera o reg.** | `deferirAcumuloHorasExtras` zera `limitado=false` do `CalculoDiario` e recálcula (v2); indeferir seta `LIMITADO_INDEFERIDO` | `RegistroFrequenciaServices.java:126-182` | Regra explícita |
| G6 | **Deferir prédio normaliza** | `deferirBaterPontoOutroPredio` seta `NORMAL` + `ressalva=false`; indeferir seta `DESCONSIDERADO_PREDIO` | `RegistroFrequenciaServices.java:184-234` | Regra explícita |
| G7 | **Recálculo obrigatório pós-correção** | Toda operação de gestão dispara recálculo do dia/mês | `desconsiderar/reconsiderar`→**v1** `atualizar`; deferir/indeferir→**v2** `atualizarMesNoAno` | Regra explícita (motor divergente) |
| G8 | **Manual gera intervenção de controle** | Registro manual/errata cria `ACAO_CONTROLE_FREQUENCIA` (ou `_ERRATA`) | `RegistroFrequencia.manualFromForm` | Regra explícita |
| G9 | **Operação INDEFINIDO no manual** | Registro manual parte de `operacao = INDEFINIDO` (sem entrada/saída automática) | `RegistroFrequencia.manualFromForm` | Regra explícita |

### Regras implícitas / RISCO

| # | Implícita / Risco | Detalhe | Evidência |
|---|-------------------|---------|-----------|
| I1 | **`setManifestacao(null)` + TODOs** | Métodos de correção fazem `setManifestacao(null)` com `//TODO` — associação a manifestação do módulo `aproc` não é tratada no cadastro | `RegistroFrequencia.desconsiderar/reconsiderar` (bean) |
| I2 | **Motor de recálculo divergente** | Desconsiderar/reconsiderar usa **v1**; deferir/indeferir usa **v2** → resultados podem divergir | `RegistroFrequenciaServices.java:115,123` (v1) vs `:152,180,207,232` (v2); fluxo B D7 |
| I3 | **`deferirAcumuloHorasExtras` flag manual** | `calculoDiario.setLimitado(false)` é feito à mão, e recálculo pode sobrescrever — ver D15 do fluxo B | `RegistroFrequenciaServices.java:147` |
| I4 | **Gestão via intervenção passiva (tjpi)** | Toda autorização/desconsideração cria intervenção **passiva** que depende de fluxo externo do módulo `tjpi` — coupling cross-module | `novaIntervencaoPassiva` em todos os métodos |

---

## Mapa de Estados (resumo — transições de `Horario` via gestão)

```
NORMAL ──(desconsiderar)─▶ DESCONSIDERADO       ──(reconsiderar)──▶ NORMAL
SOLICITADO_AUTORIZACAO_PREDIO ──(deferir)──▶ NORMAL ; ──(indeferir)──▶ DESCONSIDERADO_PREDIO
LIMITADO ──(deferir acúmulo)──▶ NORMAL/LIMITADO liberado ; ──(indeferir)──▶ LIMITADO_INDEFERIDO
```
**EVIDÊNCIA (enum):** `TipoRegistroFrequenciaEnum.Horario` (l.31-41) — `{NORMAL, MUITO_CEDO, MUITO_TARDE, DESCONSIDERADO, LIMITADO, LIMITADO_INDEFERIDO, SOLICITADO_AUTORIZACAO_PREDIO, DESCONSIDERADO_PREDIO}`.

---

## Cross-reference

- **Entidade/tabela:** `01-inventario/06-tabelas-banco.md` (§4 `presenca_registrofrequencia`; §7/8 direitos - intervenção)
- **Entrada (registro):** `09-intranet/fluxos/01-batida-ponto.md` (fluxo A)
- **Recálculo:** `09-intranet/fluxos/02-calculo-diario.md` (fluxo B — v1/v2)
- **Autorização de prédio (origem):** `ProcessarArquivoSincronizado.java:97-116` (fluxo A R3)
- **Intervenção (módulo tjpi):** `PreVinculadoServices.novaIntervencaoPassiva`, `PreVinculadoAcaoEnum`

---
**Última atualização:** 2026-08-05
**Fase:** 2 — Engenharia Reversa (fluxo D: gerenciamento de registro)
