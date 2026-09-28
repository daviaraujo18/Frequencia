# Domínio: Direitos / Afastamentos / Férias / Dias Excepcionais

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## 1. Entidades / Tabelas JPA

### 1.1 `Excepcional` — `beans/Excepcional.java` — **`@MappedSuperclass`** (base abstrata, l.20-21)
- Campos herdados (materializados em cada subclasse): `id` (`@Id @GeneratedValue(IDENTITY)`), `descricao`, `responsavel` (`@ManyToOne Usuario`), `periodo` (`@Embedded Periodo` — `global/beans/Periodo.java:21`), `momentoRegistro` (`@Temporal(TIMESTAMP)`), `observacao`, `ativo`.
- **Subclasses:** `Direito` e `DiaExcepcional`. `Feriado` NÃO herda (implementa apenas a interface `PresencaExcepcional`).

### 1.2 `Direito` — `beans/Direito.java` → **`presenca_direito`**
- `@Entity @Table(name = "presenca_direito")` (l.18-19), `extends Excepcional`.
- Campos próprios: `tipoDireito` (`@Enumerated(STRING) TipoDireitoEnum`), `frequentador` (`@ManyToOne`), `manifestacao` (`@ManyToOne(LAZY) modules.aproc.beans.Manifestacao`), `intervencao` (`@OneToOne(LAZY) PreVinculadoIntervencao` do módulo `tjpi`).
- Referência `global_periodo`: `dao/DireitoDao.java:90` (`presenca_direito.periodo_id`).

### 1.3 `DiaExcepcional` — `beans/DiaExcepcional.java` → **`presenca_diaexcepcional`**
- `@Entity @Table(name = "presenca_diaexcepcional")` (l.16-17), `extends Excepcional`.
- Campos próprios (opcionais/LAZY): `setorAtingido` (`Orgao`), `frequentador`, `predio`, `tipoFrequenciaExcepcional` (`TipoFrequenciaExcepcionalEnum`).
- `isDiaTodo()` (l.79-93): período 00:00–23:59.

### 1.4 `Dia` — `beans/Dia.java` — **NÃO é entidade** (bean de cálculo/DTO)
- Agrupa `frequentador`, `regimeFrequentador`, `registros`, `calculo`, `direitos`, `diasExcepcionais`, `feriados`, `periodosACumprir`, `horariosDoDia`. `getPresencasExcepcionais()` (l.137-144) = direitos + diasExcepcionais + feriados.

### 1.5 `PresencaExcepcional` — `beans/PresencaExcepcional.java` — **interface**
- `getPeriodo()`/`getDescricao()`. Implementada por `Excepcional` e `Feriado` (`global/beans/Feriado.java:32`, tabela `global_feriado`, com `TipoFeriadoEnum` NACIONAL/ESTADUAL/MUNICIPAL).

## 2. Tipos de direito — `enums/TipoDireitoEnum.java` (grupos de `GrupoTipoDireitoEnum`)
- **LICENCA:** LICENCA_SAUDE, LICENCA_DOENCA_FAMILIA, LICENCA_ACIDENTE, LICENCA_AFASTAMENTO_CONJUGE, LICENCA_MILITAR, LICENCA_POLITICA, AFASTAMENTO_BOLSA, CAPACITACAO_A_SERVICO, LICENCA_PARTICULAR, LICENCA_CLASSISTA, LICENCA_GESTANTE, LICENCA_PREMIO (**"Não mais vigente, conferir"** — D4).
- **AFASTAMENTO:** DISPENSA_POR_SERVICO_JUSTICA_ELEITORAL, AFASTAMENTO_OUTRO, AFASTAMENTO_MANDATO_ELETIVO.
- **CONCESSAO:** CONCESSAO_SANGUE, CONCESSAO_ALISTAMENTO, CONCESSAO_CASAMENTO, CONCESSAO_FALECIMENTO.
- **OUTROS_DIREITOS_LEI:** FERIAS.
- **OUTROS (TJ):** DISPENSA_POR_GREVE, FREQUENCIA_SUSPENSA, SUSPENSAO_DISCIPLINAR, VIAGENS_SERVICO, AUSENCIA_PROGRAMADA, FOLGA_COMPENSATORIA, REGIME_TELETRABALHO, REGIME_TELETRABALHO_COVID, REGIME_ESTAGIO_REMOTO, TRANSITO_REMOCAO, PLANTAO (`dever=true`), FOLGA_EXTRA_ITINERANTE, CEDIDO_OUTRO_ORGAO.

**Como afetam o cálculo:** o `tipoDireito` **NÃO é lido individualmente** pelo motor — todo direito é tratado como **abono genérico pelo seu `Periodo`**, subtraindo carga/meta a cumprir (`BuscaPeriodos.java:51,82,98-103`). Flags `remunerado`/`dever`/`semAusencia` existem no enum mas não são consumidas no caminho de cálculo encontrado (D1/D3).

## 3. Dias excepcionais — interação com cálculo
- `DiaExcepcionalDao.list(Calendar, Frequentador, tipo)` (l.117-135): busca por órgão (hierarquia de lotação), prédio ou frequentador, filtrando por período que contém a data + `ativo`.
- No motor (`BuscaPeriodos.java:50-53`): onerações = períodos **EXCEPCIONAIS** a trabalhar; abonos/feriados/direitos = **subtraídos** das metas normais.
- `calcularMetaDoDia` (`CalculoDiarioStrategy.java:153-201`): se "dia todo" usa horários do dia (ou `metaSemanal/5`); se parcial, proporcional.
- **Jobs de suporte:** `DiaExcepcionalCovid` (`TRABALHO_REMOTO_COVID.jsp`, cria ABONO individual c/ motivo "Ponto Suspenso Déc. 7411/2022") e `DiaExcepcionalPontoFacultativo` (`PONTO_FACULTATIVO.jsp`), ambos cron `0 30 7 * * ?`, disparando JSP por HTTP (`APP_HOST`) — **regras de calendário hardcoded em JSP** (D8).
- `TipoFrequenciaExcepcionalEnum` (l.11-56): `ABONO` (dispensa de trabalho) e `ONERACAO` (expediente extra). Documentação confusa (D12).

## 4. Regras de negócio
- **Direito** (`DireitoValidator.java`): exige intervenção (portaria/doc/anexo) — `validateIntervencao` (l.36-43); período obrigatório e consistente (l.45-59); frequentador e tipo obrigatórios; **conflito de períodos** de direitos ativos do mesmo frequentador (`validateConflitoDireito` l.74-80; `DireitoDao.conflitoEncontradoDireito` l.142-160).
- **DiaExcepcional** (`DiaExcepcionalValidator.java`): período obrigatório (l.40-52); descrição obrigatória; **`SetorAtingido` (órgão) obrigatório** (`validateOrgao` l.60-64) — conflita com cadastro por frequentador/prédio (D7); conflito por órgão (`DiaExcepcionalDao.conflitoEncontrado` l.169-182).
- `Direito.saveFromForm` (l.74-103): cria `PreVinculadoIntervencao` passiva (ação `ACAO_CONTROLE_FREQUENCIA`/`_ERRATA`); `setManifestacao(null)` com TODO (D2).

## 5. Ações / Endpoints
- `DireitoActions` (rota `/presenca/Direito`): `create`, `update` (errata), `inativar` (exige obs), `ativarDireito`, `explore`, `telaObsExclusaoDireito`. Permissões em `ModuleManager.java:234-259`.
- `DiaExcepcionalActions` (rota `/presenca/DiaExcepcional`): `create`, `update` (`ativo` a partir de input booleano l.102-103), `explore`, `inativar`, `ativarDiaExcepcional`. Permissões em `ModuleManager.java:266-287`.
- Recálculo assíncrono via `HistoricoTarefaServices` (`addTarefaDia`, `addTarefaDireito`) → `CalculoDiarioServiceV2.atualizarMesNoAno`.

## 6. Dúvidas / ambiguidades
| ID | Localização | Dúvida |
|----|-------------|--------|
| D1 | `BuscaPeriodos.java:98-102` | Motor ignora o `tipoDireito` — todos os tipos viram abono por período; flags não consumidas |
| D2 | `Direito.java:79-81` | `setManifestacao(null)` + TODO — associação não persistida no cadastro normal |
| D3 | `TipoDireitoEnum.java:44,50,66-77` | Significado de `dever`/`semAusencia` não consumido no cálculo |
| D4 | `TipoDireitoEnum.java:22` | `LICENCA_PREMIO` "não mais vigente" — decidir migra ou não |
| D5 | `DireitoDao.java:77-82` | `todosAnos()` usa SQL nativo inconsistente com HQL |
| D6 | `DiaExcepcionalActions.java:102-103,131-143` | `update` seta `ativo` por input; `inativar` não valida obs (diferente de Direito) |
| D7 | `DiaExcepcional.java:38-60` vs `DiaExcepcionalValidator.java:60-64` | `validateOrgao` sempre exige órgão, mas bean permite frequentador/prédio |
| D8 | `PONTO_FACULTATIVO.jsp:27-45` | Datas de ponto facultativo hardcoded (2023-2026), fora do Java |
| D9 | `DiaExcepcionalCovid.java:31-46`, `DiaExcepcionalPontoFacultativo.java:30-46` | Job dispara JSP via HTTP acoplado ao servlet |
| D10 | `services/calculo/*` vs `services/calculo/v2/*` | Motor de cálculo duplicado (ver `03-calculo-diario.md`) |
| D11 | `DiaExcepcionalDao.java:215-252` | Conflito detectado só por `setorAtingido_id`, ignora escopos frequentador/prédio |
| D12 | `TipoFrequenciaExcepcionalEnum.java:5-9` | Documentação de ABONO/ONERAÇÃO contradiz uso prático |

## 7. Complexidade de migração
**ALTA.** Herança `@MappedSuperclass` + `@Embeddable Periodo` (colunas espalhadas + FK `global_periodo`); motor de cálculo duplicado; regras de calendário em JSP; recálculo assíncrono por fila; integração cross-module (`aproc.Manifestacao`, `tjpi.PreVinculadoIntervencao`).

---
**Origem da análise:** agente de engenharia reversa sobre `intranet/src/modules/presenca/` (2026-08-04).
