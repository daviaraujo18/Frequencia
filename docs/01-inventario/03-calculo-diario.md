# Domínio: Cálculo Diário de Frequência

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## 1. Entidade/Tabela JPA `CalculoDiario` — `beans/CalculoDiario.java` → **`presenca_calculodiario`**
- `@Table(name = "presenca_calculodiario")` (l.21), `@Entity`, id `@Id @GeneratedValue(IDENTITY)` (l.23-25).
- Campos principais:
  | Campo | Tipo | Significado |
  |-------|------|-------------|
  | `normal` / `excepcional` / `total` | int | horas em segundos (normal, excepcional, total) |
  | `aberto` | boolean | dia aberto (incompleto) |
  | `ausencia` / `falta` / `faltaADescontar` / `faltaCompensada` / `descontadoEmFolha` | boolean | estado de frequência |
  | `meta` | int | meta diária (segundos) |
  | `permitidoContabilizarHorasMesmoComMetaZero`, `permitidoAcumularHoras`, `permitidoCompensarFalta`, `permitidoSaidaAntecipada` | boolean | configurações copiadas do regime |
  | `liberadoLimitacaoInicioHoraExtra`, `liberadoBloqueioMaxHoraExtra` | boolean/Boolean | |
  | `limitado` | Boolean | |
  | `saidaAntecipada` | boolean | |
  | `horarioRecalculo` | Calendar | |
  | `informacao` | String | |
  | `registroMensal` | `RegistroMensalFrequencia` | `@ManyToOne` |
  | `frequentador` | Frequentador | `@ManyToOne` |
  | `data` | Calendar | `@Temporal(DATE)` |
  | `segundosParaCompensarFalta` | int | |
- **Regra temporal:** `getMaxFaltasCompensadasPermitidasPorAno()` (l.327-333) — 12 faltas compensáveis se `data > 26/10/2022`, senão 10. Usado pelo V2.
- `getRegimeFrequentador()` recupera regime vigente na data (l.342-344).

## 2. Motor de cálculo — fluxo principal (duas linhagens: v1 e v2)

### 2.1 v1 — `services/calculo/`
- `CalculoDiarioService.criaOuAtualizaDiario` (l.97-141) — agrupa por mês; processa se `rmf == null || !rmf.isFinalizado()`.
- `calcularDia` (l.153-161) → `computaDia` (l.163-191) seleciona estratégia pela **Modalidade**:
  - `HORAS_COM_INTERVALO` → `EntradasESaidas` (l.171-172)
  - `HORAS` → corte em **01/12/2018**: antes `PrimeiraEntradaUltimaSaidaOld`, depois `PrimeiraEntradaUltimaSaida` (l.175-178)
  - `OCORRENCIAS` → `Ocorrencias` (l.181-183)
  - sem regime → `CalculoDiario(f, data, "Nenhum regime ativo nesta data")` (l.187)
- `aplicarCalculo` (l.193-208): merge com registro persistido preservando flags de gestão.

### 2.2 Algoritmo interno — `CalculoDiarioStrategy` (v1), método template `calcula()` (l.69-78)
1. `getBuscaPeriodos().periodosNaoConflitantes(regimeFrequentador, data)` (l.70) — mapa `NORMAIS`, `EXCEPCIONAIS`, `METASNORMAIS`.
2. `dao.getRegistradosByDayS(...)` (l.71) — entradas/saídas do dia.
3. `inicializaRegistros()` (l.72, l.145-151) — zera Zona/Horario/Operacao.
4. `configuraCalculoDiario(...)` (l.74) — init, validação (marca `aberto` se tempo < 300s), meta do dia, extração/ordenação de registros, dispatcher p/ estratégia concreta.
5. `definirZonaRegistros(...)` (l.75) — zona NORMAL/ANORMAL.
6. `Dao.save(registrosFrequencia)` (l.76).

### 2.3 v2 — `services/calculo/v2/`
- `CalculoDiarioServiceV2.criaOuAtualizaDiario` (l.50-98): agrupa por mês, monta `Map<String, Dia>` via `DiaServices.mapDias` (l.64), processa o mês de uma vez.
- `calcularDia` (l.264-288) seleciona estratégia V2: `EntradasESaidasV2`, `PrimeiraEntradaUltimaSaidaOldV2`/`V2` (mesmo corte 01/12/2018), `OcorrenciasV2`.
- `CalculoStrategyV2.execute()` (l.41-49): `BuscaPeriodosV2.mapPeriodosACumprir`, `resetaStatusRegistrosFrequencia`, `configuraCalculoDiario`, `definirZonaRegistros`, `Dao.save`.
- `definirLabelsParaCalculosDiarios` (l.100-205): faltas compensadas/descontos usando limite dinâmico + regra de estagiário.

## 3. Diferenças v1 vs v2 (duplicação e versionamento)

**Duplicação mecânica:** dois motores completos e paralelos (`CalculoDiarioStrategy` vs `CalculoStrategyV2`, `BuscaPeriodos` vs `BuscaPeriodosV2`, etc.). Os arquivos `EntradasESaidas`, `Ocorrencias`, `PrimeiraEntradaUltimaSaidaOld` são praticamente idênticos entre v1 e v2. A diferença de arquitetura: v1 consulta DAOs por conta própria; v2 recebe um `Dia` pré-populado (`DiaServices.mapDias`).

**Cortes temporais (versionamento por data) — críticos para reproduzir histórico:**
| Regra | V1 | V2 | Corte |
|-------|----|----|-------|
| Algoritmo Old vs New (HORAS) | `CalculoDiarioService.java:175` | `CalculoDiarioServiceV2.java:273` | 01/12/2018 |
| Intervalo 15min p/ acumular horas | `CalculoDiarioStrategy.java:456-457` | `CalculoStrategyV2.java:382-383` | 01/05/2017 |
| Labels de faltas compensadas | `CalculoDiarioService.java:130-131` | `CalculoDiarioServiceV2.java:84-85` | >31/03/2017 |
| Máximo banco GCET (45min) | `CalculoDiarioStrategy.java:491-492` | `CalculoStrategyV2.java:419-421` | v1 `after 2018-12-01`; v2 `2018-12-01..2022-10-26` |
| Limite faltas compensadas/ano (10→12) | fixo 10 | `getMaxFaltasCompensadasPermitidasPorAno()` | >26/10/2022 |

**Diferenças de comportamento entre v1 e v2 (risco de divergência):**
- Saídas antecipadas mensais: v1 consulta o banco real (`PrimeiraEntradaUltimaSaida.java:276`); v2 tem a consulta **comentada** e fixa `qtdSaidasAntecipadasMensal = 0` (`PrimeiraEntradaUltimaSaidaV2.java:252-253`).
- Ponto `MUITO_TARDE`: v1 força `limiteMaximoSaida` (l.299-301); v2 respeita a hora real se `liberadoBloqueioMaxHoraExtra` (l.277-283).
- Banco diário: v2 usa `Regime.configuracao.maximoBancoHorasDiarioEmSegundos` (parametrizável) + dias especiais 21-23/11/2022 (`CalculoStrategyV2.java:414-432`); v1 usa constante fixa 7200s.

**Qual está em uso:** a MAIORIA do código ativo usa v2 (jobs `RecalculoDiario`, `CalculoDiarioAusentes`; `HistoricoTarefaServices`; `RegistroFrequenciaServices`; `DynMostraRegistroFrequencia`). v1 ainda é invocado em caminhos de UI: `CalculoFrequenciaActions.java:24`, `RegistroFrequenciaServices.desconsiderar/reconsiderarPonto` (l.115,123), `HistoricoTarefaServices.deserializarRecalcular` (l.516 — recalcular TODOS usa v1). → **Coexistência de motores = risco de resultados divergentes.**

## 4. Estratégias de cálculo

**v1** — `CalculoDiarioStrategy` (abstrata): contrato `getCalculoComExpedienteExcepcional()`/`getCalculoSemExpedienteExcepcional()`. Concretas: `EntradasESaidas` (HORAS_COM_INTERVALO), `Ocorrencias` (OCORRENCIAS), `PrimeiraEntradaUltimaSaida` (HORAS ≥ 01/12/2018), `PrimeiraEntradaUltimaSaidaOld` (HORAS < 01/12/2018).

**v2** — `CalculoStrategyV2` (abstrata): contrato `calcularComExpedienteExcepcional()`/`calcularSemExpedienteExcepcional()`. Concretas: `EntradasESaidasV2`, `OcorrenciasV2`, `PrimeiraEntradaUltimaSaidaV2`, `PrimeiraEntradaUltimaSaidaOldV2`.

## 5. Regras de negócio (destaques)

- **Entradas/saídas** (`beans/RegistroFrequencia.java`, `presenca_registrofrequencia`): enums `Operacao {ENTRADA,SAIDA,INDEFINIDO}`, `Horario {NORMAL,MUITO_CEDO,MUITO_TARDE,DESCONSIDERADO,LIMITADO,LIMITADO_INDEFERIDO,SOLICITADO_AUTORIZACAO_PREDIO,DESCONSIDERADO_PREDIO}`, `Zona {ANORMAL,NORMAL}`, `Modo {MANUAL,BIOMETRICO,LOGIN_SENHA}`. `momentoParaCalculo` = batida ajustada usada no cálculo.
- **Ocorrências** (`Ocorrencias.java:12-17`): registro único/dia; >1 batida → verifica diferença vs carga; se maior e permitido acumular → horas extras.
- **Falta** (`configuraFalta`): se `meta > 0`, `total == 0`, não aberto, data anterior à hoje → falta.
- **Ausência**: trabalhado > 0 e < meta × `percentualCargaMinima/100`.
- **Saída antecipada** (turno da tarde, `PrimeiraEntradaUltimaSaida.definirMomentoParaCalculo` l.251-310): regras com `MAX_PERMITIDO_SAIDA_ANTECIPADA_MENSAL = 999`.
- **Banco de horas diário**: 15min de intervalo; máx 2h/dia (7200s) ou 45min GCET (2700s); `verificarFrequentadorLimitado` limita pelo saldo.
- **Constantes mágicas** (`CalculoDiarioStrategy.java:33-44`): `LIMITE_PARA_SAIDA_EM_SEGUNDOS = 300` (5min), `NORMAIS`/`EXCEPCIONAIS`/`METASNORMAIS`.

## 6. Jobs de recálculo
- `CalculoDiarioAusentes` — cron `0 30 2 * * ?` (02:30 diário), 10 threads. **Corpo do cálculo atual comentado** (l.115-125) — hoje só inativa vínculos encerrados/aposentados.
- `RecalculoDiario` — cron `0 15 21 * * ?` (21:15 diário), 15 threads, recalcula o mês via `CalculoDiarioServiceV2.atualizarMesNoAno`.
- `ExecutaTarefas` — cron a cada 5 min, consome fila `HistoricoTarefa` (ver `05-banco-horas-fechamento.md`).

## 7. Dúvidas / ambiguidades
| ID | Localização | Dúvida |
|----|-------------|--------|
| D1 | `CalculoDiarioStrategy.java:73`, `CalculoStrategyV2.java:44` | `//fixme: não funciona (aers) sempre retorna false` — detecção de expediente excepcional pode sempre ser false |
| D2 | `PrimeiraEntradaUltimaSaidaV2.java:252-253` | Consulta de saídas antecipadas comentada, fixa em 0 — diverge do v1 (regressão ou bug?) |
| D3 | `CalculoFrequenciaActions.java:24`, `RegistroFrequenciaServices.java:115,123`, `HistoricoTarefaServices.java:516` | Coexistência v1/v2: qual é o motor "oficial"? Resultados podem divergir |
| D4 | `CalculoStrategyV2.java:419-421` vs `CalculoDiarioStrategy.java:491-492` | Limite GCET: v1 sem fim vs v2 `before(2022,10,26)` — inconsistência de período |
| D5 | `CalculoStrategyV2.java:423-429` | Datas hardcoded 21-23/11/2022 com banco 99999s — regra temporária? |
| D6 | `CalculoDiarioService.java:130-135` / v2 | Labels de falta só rodam se `rmf.dataInicio > 31/03/2017` |
| D7 | `CalculoDiarioService.java:342` | Limite de 10 descontos hardcoded (TODO) |
| D8 | `CalculoDiarioService.java:284` vs v2 `:148` | Limite de faltas compensadas: v1 fixo 10 vs v2 dinâmico 10/12 |
| D9 | `CalculoDiario.java:324` | `getRestanteACompensar` usa `Calendar.MONDAY` (dia-da-semana) como dia-do-mês — aparente bug |
| D10 | `CalculoDiarioService.java:50,68` | Método `limpaSaidasAntecipadas` comentado + SQL não usado |
| D11 | `CalculoDiarioAusentes.java:115-125` | Corpo de cálculo comentado — job desativado intencionalmente? |
| D12 | `CalculoStrategyV2.java:33`, `CalculoDiarioStrategy.java:43-44` | Constantes duplicadas v1/v2 (acoplamento por strings) |
| D15 | `RegistroFrequenciaServices.java:146-147` | `deferirAcumuloHorasExtras` marca `limitado=false` manualmente — pode ser sobrescrito no recálculo |

## 8. Complexidade de migração
**ALTA.** Justificativa: dualidade de motores (v1+v2 em produção), versionamento por datas de corte (reproduzir histórico), forte acoplamento ao framework `futurepages`/DAO/HQL/SQL nativo, muitas regras hardcoded não documentadas.
**Recomendação estratégica:** consolidar v1→v2 (v2 é a refatoração baseada em `Dia`), extrair constantes para config, e criar suíte de testes de contraste v1×v2 por modalidade e janela de data antes de tocar persistência.

---
**Origem da análise:** agente de engenharia reversa sobre `intranet/src/modules/presenca/` (2026-08-04).
