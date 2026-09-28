# Domínio: Banco de Horas / Fechamento Mensal / Relatório Final / Retificador / Valores Retroativos

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## 1. Entidades / Tabelas JPA

### 1.1 `RegistroMensalFrequencia` — `presenca_registromensalfrequencia`
- `@Entity @Table(name="presenca_registromensalfrequencia")` (l.23-24).
- Campos: `data`/`dataInicio`/`dataFim` (DATE); `momentoUltimoCalculo` (TIMESTAMP); `ano`/`mes` (int); **saldo** `saldoLiquido`, `retido`, `acumulado`, `retificado` (segundos); **meta** `metaAtual`, `metaMensal`, `metaAtualDias`, `metaMensalDias`; **trabalhado** `trabalhado`, `trabalhadoExcepcional`, `trabalhadoNormal`, `trabalhadoDias`, `tempoAusenteDeFalta`, `ausentes`, `faltas`, `diasEmAberto`; descontos `faltasACompensar`, `faltasADescontar`, `creditoADevolver`; estado `finalizado` (boolean). `@ManyToOne frequentador`.
- Comentário (l.76-79): após desconto em folha, `finalizado=true` e só altera via retificador. **MAS** `setFinalizado` nunca é chamado em código (AMBIG-001) — o "lock" nunca é efetivado.

### 1.2 `RelatorioFrequenciaFinal` — `presenca_relatoriofrequenciafinal`
- `@Entity @Table` (l.21-22). Campos: `dataGeracao`, `dataAlteracao`, `mes`/`ano` (**String** — l.33-34). `@OneToMany(mappedBy, cascade=ALL) relatorioFrequentadores` (l.39-40).
- **Nota:** campo `Orgao orgao` comentado (l.36-37), mas o DAO o referencia (DIVERG-003).

### 1.3 `RelatorioFrequentador` — `presenca_relatoriofrequentador`
- `@Entity @Table` (l.16-17). Campos: `valorRetroativo`, `saldoBruto`, `resultado` (int). `@OneToOne frequentador`, `@ManyToOne relatorioFrequenciaFinal`.

### 1.4 `RetificadorDeBancoHoras` — `presenca_retificadorbancohoras`
- `@Entity @Table` (l.25-26), implementa `PresencaExcepcional`. Campos: `mes`/`ano` (usados quando não há CalculoDiario, ex. DESCONTO_EM_FOLHA), `excluido`, `tipo` (`TipoRetificadorEnum`), `segundosARetificar`, `observacao`/`informacao` (`@Lob`), `momentoRegistro`, `@ManyToOne frequentador`/`responsavel` (User).
- **Nota:** NÃO possui campo `calculoDiario`, mas o DAO o referencia (DIVERG-002).

### 1.5 `ValorRetroativo` — `presenca_valorretroativo`
- `@Entity @Table` (l.17-18). Campos: `mes`/`ano` (int), `dataGeracao`, `processo`, `numeroHora` (**em segundos** após ×3600). `@OneToOne frequentador`.

### 1.6 `DebitoRemanescenteNegociado` — `presenca_debitoremanscentenegociavel` — **CÓDIGO MORTO**
- `@Entity @Table` (l.18-19). Referencia `@OneToOne Manifestacao` (módulo `aproc`). **Sem DAO/ação/serviço utilizador; não registrado no `ModuleManager`.** → ignorar/remover na migração (DIVERG-004/DEAD-CODE-001).

### 1.7 `HistoricoTarefa` — `presenca_historicotarefa` (fila assíncrona)
- `@Entity @Table` (l.21-22). Campos: `hashTarefa` (`@Lob`, JSON serializado), `tipoEntidade` (`TipoEntidade` enum), `dtAdicao`, `dtExecucao`. Tipos: DIAEXCEPCIONAL, DIREITO, FERIADO, VINCULAR_DESVINCULAR, REGISTRO_FREQUENCIA, RECALCULAR_TODOS, REGISTRO_ESTACAO.

### 1.8 `GestorIndividual` — `presenca_gestorindividual`
- `@Entity @Table` (l.14-15). Campos: `dataCriacao`, `dataExclusao`, `ativo`, `observacao`; `@OneToOne @JoinColumn(name="vinculado_id") gestor` (Vinculado), `@OneToOne frequentador`.
- Propósito: gestão excepcional quando servidor lotado formalmente num órgão mas de fato em outro.

### 1.9 `ConfiguracaoFrequencia` — `@Embeddable` (ver `02-regime-jornada.md`)

### 1.10 `UploadEstacao` — **NÃO é entidade JPA** (POJO helper de upload por partes)

### 1.11 `FrequentadorEstacao` — **view** `presenca_frequentadorestacao`
- `@View/@Entity(name="presenca_frequentadorestacao")`. Campos: `matricula`, `nomeCompleto`, `digitalHash`, `arquivoFoto`, `sexo`, `predioId`.

## 2. Banco de horas — cálculo e armazenamento (tudo em **segundos**)
- `getSaldoBruto()` = `trabalhado − metaMensal`; `getSaldoDoMes()` = `trabalhado − metaAtual`; `getAcumuladoMesAnterior()` = `saldoLiquido − saldoBruto`; `getSaldoParaIniciarProximoMes()` = `saldoMesAnterior + saldoBruto + retificado − retido`; `getAcumuladoTotal()` = `acumuladoMesAnterior + saldoDoMes`.
- `getSaldoMesAnterior()` (l.344-355): recursivo ao mês anterior.
- **`calcularSaldoAcumulo()`** (`RegistroMensalFrequenciaServices.java:84-104`):
  1. `saldoLiquido = saldoAcumuladoMesAnterior + saldoBruto + retificado`
  2. Aplica `limiteCredito`/`limiteDebito` (horas ×3600) — excedente vira `retido`
  3. `acumulado = saldoLiquido − retido` (migra p/ mês seguinte)

## 3. Fechamento mensal — job `GerarRegistroMensalFrequencia`
- Cron **`0 10 0 2 1/1 ? *`** (2º dia do mês às 00:10): itera frequentadores ativos por `maxId`, cria `RegistroMensalFrequencia` se ausente via `CalculoDiarioServiceV2.atualizarMesNoAno`. Só CRIA; não recalcula os existentes.
- `aplicarCalculosDiarios()` (`RegistroMensalFrequenciaServices.java:106-152`): soma os `CalculoDiario` do mês.
- Recalculo contínuo (`CalculoDiarioServiceV2.criaOuAtualizaDiario` l.69): só se `rmf == null || !rmf.isFinalizado()`.

## 4. Relatório final / fechamento definitivo
- `RelatorioFrequenciaFinalActions.create()`/`update()`: monta relatório de **todos os frequentadores ativos**; `resultado` = valor retroativo (± saldo bruto).
- **Regra de negócio** (`RelatorioFrequenciaFinalValidator` l.56-62): relatório só pode ser gerado/alterado **no mês seguinte** ao do relatório; sem duplicata por mês/ano.
- `calcularValorRetroativo` (`RelatorioFrequenciaFinalServices.java:128-149`).

## 5. Retificador e valores retroativos
- **Retificador** — `TipoRetificadorEnum`: CREDITO_POR_DESCONTO_EM_FOLHA, CREDITO_POR_TRABALHO_EXCEPCIONAL, CREDITO_POR_DEBITO_INDEVIDO, DEBITO_POR_CREDITO_INDEVIDO, CREDITO/DEBITO_POR_CREDITO_EM_OUTRO_MES, DEBITO_PARA_COMPENSACAO (`isDebito`, `getFatorMultiplicacao()` ±1).
  - `RetificadorActions.adicionar()`/`excluir()` (soft delete)/`estornar()` (só créditos de DESCONTO_EM_FOLHA → débito inverso).
  - `RetificadorServices.retifica()` (l.21-49) converte horas→segundos e, se `ehPraRecalcular`, `CalculoDiarioServiceV2.atualizarMesNoAno`.
  - Aplicado no mensal via `aplicarRetificadoresDeBancoHoras()` (bean l.336-341) acumulando em `retificado`.
- **Valor retroativo** — `ValorRetroativoActions.create()` (l.29-46): `numeroHora` ×3600, nega se débito. Consumido no relatório final.

## 6. Processamento assíncrono — Histórico de Tarefas
- `HistoricoTarefaServices.addTarefaXxx(...)`: serializa alterações em JSON e enfileira; `executaTarefa` (l.34-68) despacha por tipo e reconstrói/recálcula via `CalculoDiarioServiceV2` (exceção: `deserializarRecalcular` l.499-524 recalcula TODOS usando **v1** `CalculoDiarioService.corrigir`).
- `ExecutaTarefas` (cron a cada 5 min): consome `HistoricoTarefaDao.getTarefas()` (dtExecucao IS NULL).
- `VersionamentoDao` — `presenca_versaoestacaoponto` (firmware de estação, NÃO participa do banco de horas); `apagaForadoLimite` mantém as 5 versões mais recentes.

## 7. Dúvidas / divergências confirmadas
| ID | Localização | Dúvida |
|----|-------------|--------|
| DIVERG-001 | `RegistroMensalFrequenciaDao.java:66` | `getUltimoAcumulavel` referencia campo `segsAcumulavelMensal` que **não existe** no bean — método morto (nunca chamado) |
| DIVERG-002 | `RetificadorDeBancoHorasDao.java:60` | `findByCalculoDiario` referencia `calculoDiario_id` inexistente — método morto |
| DIVERG-003 | `RelatorioFrequenciaFinalDao.java:30,40-53` | Referencia campo `orgao` (comentado no bean) e mistura `mes` String/int — divergência de esquema |
| DIVERG-004 / DEAD-CODE-001 | `beans/DebitoRemanescenteNegociado.java` | `DebitoRemanescenteNegociado` é código morto, referencia módulo `aproc` — remover na migração |
| AMBIG-001 | `RegistroMensalFrequencia.java:316` | `finalizado` nunca é setado `true` — lock de mês nunca efetivado |
| AMBIG-002 | `RegistroMensalFrequencia.java:367-379` | `getSaldoMesAnteriorTruncado` com truncamento comentado (retorna saldo completo) |
| AMBIG-003 | `RelatorioFrequenciaFinalActions.java:70` | Delete manual de relatorioFrequentadores apesar de `cascade=ALL` |
| BUG-001 | `RelatorioFrequenciaFinalServices.java:142` | `cont=+valor.getNumeroHora()` usa `=` em vez de `+=` — soma corrompida |
| DEAD-CODE-002 | `ValorRetroativoServices.java` | Serviço vazio (processamento está em Actions/Services de relatório) |

## 8. Complexidade de migração
**ALTA.** Agregação do motor de cálculo diário; cadeia recursiva de saldo entre meses; algoritmo de desconto/compensação de faltas complexo; fiação assíncrona acoplada a v1+v2; 3+ divergências de esquema (reconciliar BD × classes antes de migrar); acoplamentos cross-module (`aproc`, `tjpi`, `global`).
**Redutor de complexidade:** modelo de persistência fino e bem documentado ("tudo em segundos"); lógica em Java/Quartz (sem stored procedures no lado presença).

---
**Origem da análise:** agente de engenharia reversa sobre `intranet/src/modules/presenca/` (2026-08-04).
