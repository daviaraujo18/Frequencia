# Iteration 32 — Hardening e débitos herdados

> Status: 🟢 **ENCERRADA (CTO, 2026-10-14)** — o **núcleo de código** (**32.1 + 32.2 = 5 pts**) está **implementado, testado, revisado e commitado**: pilha `fe7f8ff` (32.1) → `905d8fb` (32.2), + `40740b3` (docs/32.4). **Code Reviewer: 0 blockers** em ambas; **Bug Finder: 0 bugs novos** (1 🟢 confirmado + 1 ⚪ pré-existente). Baseline final **1222/4257/3F+12E/0 skip** (as 15 pré-existentes). Os **dois espelhos** do débito **D2/17.5** (job 32.1 + handler 31.4/32.2) estão **fechados**. A **32.3** (deploy da migration) foi **reclassificada como pendência OPERACIONAL STANDALONE** (bloqueio de **rede**, fora do caminho crítico — **não** mantém a sprint aberta). **Sem ADR nova** — coberto pela **ADR-0011 regra 4** (ver §"Encerramento da Sprint 32"). **Nada de commit/push pelo agente** (`COMMIT_MODE=manual`). | Período: 2026-10-14 | Goal: **fechar os débitos herdados das Sprints 30/31 e a operação pendente, sem introduzir funcionalidade nova** — em especial a **guarda de mês finalizado no `CalcularFrequenciaJob` (D2/17.5)** e o **espelho no handler `RECALCULAR_TODOS`**, mais os itens operacional/de governança condicionados à aprovação do dev. | Rastreabilidade: `iteration_31.md` §"Débitos Técnicos" · **ADR-0011** (regra 4/consequências — D2/17.5) · `docs/12-plano-implementacao/implementation_plan.md` **v2 — Épico 7** · `SPRINT-PLAN.md:536` (17.5) · `iteration_30.md` §"Débito de rastreabilidade".

## Contexto e escopo (definido pelo dev — rulings de 2026-10-14)

Esta é uma sprint de **HARDENING / DÉBITOS HERDADOS** (não é feature). O dev fixou 4 rulings que **não devem ser reabertos**:

1. **Forma:** Sprint **STANDARD** formal, com este `iteration_32.md` (não é chore AGILE).
2. **Q16 (cauda do período do vínculo): RESOLVIDA = MANTER O LITERAL.** O `VincularDesvincularHandler` recalcula `[momento_inicial, momento_final]`; ao **encolher** o período, a "cauda" (dias após o novo `momento_final`) **NÃO** é recalculada — fica como **débito ACEITO e documentado**. **Por isso Q16 NÃO é tarefa desta sprint** — apenas fica **registrada como fechada** (ver §"Perguntas abertas").
3. **Linha basic8 (Sprints 25/27/28 do plano v1, nunca executadas): PAUSADA** (pode voltar ao horizonte depois). Registrada como **pausada** — não cancelada, não "não executada". **Não é tarefa da 32.**
4. **Q15 (quadro real de devs): 1 DEV, execução SEQUENCIAL.** A sprint é dimensionada **sem paralelismo** (sem worktrees, sem Dev A/Dev B).
5. **Q14** já está resolvida (`RegimeFrequentador` via `after_commit`) — **não reaberta** aqui.

**Escopo macro (do Épico 7 do plano v2, MENOS o Q16):** os candidatos abaixo — **não inventar outros**.

## Fronteira explícita — o que esta sprint NÃO é

- **NÃO é feature nova.** Nenhum model/rota/entidade novo. Nenhuma regra de negócio nova.
- **NÃO reabre Q14 nem Q16.** Q14 = `RegimeFrequentador`/`after_commit` (fechada na 31.5); Q16 = **literal**, cauda documentada como débito aceito.
- **NÃO retoma a linha basic8** (Sprints 25/27/28): **pausada** por ruling do dev — não é escopo aqui.
- **NÃO toca autorização/`Ability`/cascata** — exceto se o dev aprovar **explicitamente** o candidato opcional `32.O1` (ver §"Candidatos opcionais").
- **NÃO inventa** produtores/handlers para os tipos adiados (`FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` — models inexistentes; política incremental vigente, ADR-0011 regra 7).
- **NÃO reabre a filosofia do `CalcularFrequenciaJob`** (últimos 3 dias + mês corrente) — apenas **acrescenta a guarda de mês finalizado por dia** (débito D2/17.5).
- **NÃO executa deploy** (32.3) sem **aprovação explícita do dev** (regra global do `CLAUDE.md`).

## Decisão de numeração e rastreabilidade

- Última iteration com arquivo: **31** (`docs/progress/iteration_31.md`, encerrada em 2026-10-13). Próximo número livre: **32**.
- O `implementation_plan.md` **v2 (2026-10-14)** já cobre a Sprint 32 como **Épico 7 (esboço macro)** e traz a **"Reconciliação de numeração e cobertura"** — este `iteration_32.md` é o **detalhamento** desse esboço (o débito de rastreabilidade das Sprints 29–31 **já foi fechado** na v2; não se reabre aqui).
- **Não existe `iteration_17.md`** — a task **17.5** (origem do débito D2) vive em `SPRINT-PLAN.md:536`; o artefato é `api-ponto/app/jobs/calcular_frequencia_job.rb`.

## Pré-condições e bloqueadores

- **Base de código:** a Sprint 32 parte de um HEAD que **contém a pilha da Sprint 31** (fila `TarefaRecalculo`, `ExecutaTarefasJob`, os 3 handlers, a migration `create_tarefas_recalculo`). Hoje essa pilha está na branch **`chore/limpeza-rubocop-77` @ `ceaac87`** (pushada em `origin`/`gitlab`).
- ⚠️ **BLOQUEADOR PENDENTE (dev):** o **merge da pilha 31 em `integration/sprint-29` segue PENDENTE / bloqueado por decisão do dev** (`COMMIT_MODE=manual`). Consequência prática:
  - **32.1** (guarda no `CalcularFrequenciaJob`) **NÃO** depende da pilha 31 — o job 17.5 é pré-existente. **Não bloqueada.**
  - **32.2** (espelho no `RecalcularTodosHandler`) e **32.3** (deploy da migration 31.1) **dependem** de arquivos/código da pilha 31. Só rodam se a sprint for baseada numa branch que contenha a pilha (ex.: `chore/limpeza-rubocop-77`). **Se o time exigir base em `integration/sprint-29` sem o merge, 32.2 e 32.3 ficam BLOQUEADAS até o merge.**
- **Baseline da suíte a isolar:** **1214 runs / 4239 assertions / 3F + 12E / 0 skip** (medido ao fim da 31; as **15** são pré-existentes: 11× Devise `redirect_to` + 1× timezone em `PresencaEndpointsTest` + 1× order-dependent do espelho/paralelização). Toda medição deve **isolar as pré-existentes** antes de atribuir regressão.
- **Persistência:** Postgres (advisory locks + `jsonb` já no schema).

## Desenvolvedores

> **Ruling do dev (Q15, 2026-10-14):** **1 DEV, execução SEQUENCIAL.** Sem paralelismo, sem worktrees. As tarefas abaixo são numeradas por **ordem de dependência** (32.1 → 32.2).

| Dev | Perfil | Foco |
|-----|--------|------|
| **Dev 1** | Backend Rails (jobs/services/tests) | **32.1** (guarda no job), **32.2** (espelho no handler `RECALCULAR_TODOS`), itens **32.3/32.4** (operacional/governança, condicionados ao dev) — **sequencial** |

## Backlog

### Área — 1. Recálculo: débito D2/17.5 + espelho no handler

#### Tarefa 32.1 — Guarda de mês finalizado no `CalcularFrequenciaJob` (D2/17.5)
- User Story: Como sistema, quero que o job noturno **não reescreva o `CalculoDiario` de meses já finalizados** ao recalcular os últimos 3 dias, para que a **trava 17.2** valha também no recálculo automático (hoje ela é burlada pelo `save!` do dia).
- Rastreabilidade: `iteration_31.md` §"Débitos Técnicos" (**D2 da 17.5**) · **ADR-0011 regra 4** (trava de mês finalizado vale para o recálculo por evento — inclusive para o DIA) e §Consequências (D2/17.5) · `SPRINT-PLAN.md:536` (17.5) · trava **17.2** · `api-ponto/app/jobs/calcular_frequencia_job.rb`
- Estimativa: **3 pontos** | Atribuição: **Dev 1** | Dependências: **nenhuma** (job pré-existente à pilha 31)
- **Escopo (o que ENTRA):**
  - Antes de `CalculoDiarioService.calcular(user, dia)` para **cada** um dos `DIAS_RECALCULADOS` (hoje/ontem/anteontem), checar **`ConsolidacaoMensalService.finalizado?(user, dia.year, dia.month)`** e **pular o dia** quando o mês dele estiver finalizado (skip silencioso, mesmo padrão da correção A/31.3).
  - A guarda é **por dia** (não só mês corrente): os 3 últimos dias podem **cruzar a virada de mês** (ex.: 2026-11-01 recalcula 11/01, 10/31, 10/30 → 10/31 e 10/30 podem pertencer a um mês já finalizado).
  - **Reusar** o predicado `ConsolidacaoMensalService.finalizado?` (**não** criar segundo crivo) — lição 2026-10-13 ("a trava só protege se aplicada ANTES de toda escrita"; o predicado deve reusar a condição da trava).
  - Preservar o `rescue ConsolidacaoMensalService::MesFinalizadoError` como **salvaguarda de corrida** (TOCTOU) e a consolidação do mês corrente inalterada.
- **Escopo (o que NÃO ENTRA):** alterar a filosofia dos 3 dias + mês corrente (decisão já tomada, **não reabrir**); tocar no `RecalcularTodosHandler` (é a **32.2**); reabrir TOCTOU (débito aceito).
- Critérios de aceite:
  - [x] A guarda é avaliada **antes de qualquer escrita** de `CalculoDiario` para cada um dos 3 dias; mês finalizado ⇒ **o dia não é recalculado** (skip silencioso).
  - [x] Teste com **snapshot**: `CalculoDiario` de um mês finalizado **permanece inalterado** após rodar o job (sem stub — mês realmente finalizado via `ConsolidacaoMensalService.finalizar`).
  - [x] Teste cobre a **virada de mês**: 3 dias cruzando 2 meses, um finalizado e outro não ⇒ o dia do mês aberto é recalculado, o do mês fechado **não**.
  - [x] A guarda **reusa** `ConsolidacaoMensalService.finalizado?` (grep prova: nenhuma segunda condição de finalização criada).
  - [x] A consolidação do mês corrente continua rodando; `MesFinalizadoError` segue tratado como salvaguarda.
  - [x] Testes via `test/support/class_method_stub_helper.rb` (**save/restore; NUNCA `remove_method`**) quando houver stub.
  - [x] Sem regressão no baseline (as 15 pré-existentes inalteradas); RuboCop/Zeitwerk OK.
- Status: ✅ **Concluída (2026-10-14)** — guarda de mês finalizado **por dia** + guarda pré-consolidação implementadas no `CalcularFrequenciaJob`, reusando `ConsolidacaoMensalService.finalizado?`. Arquivos: `api-ponto/app/jobs/calcular_frequencia_job.rb`, `api-ponto/test/jobs/calcular_frequencia_job_test.rb`. Branch: `feature/demanda-32-1-guarda-finalizado-job` (base `chore/limpeza-rubocop-77`).

  **Evidência:** `bin/rails test test/jobs/calcular_frequencia_job_test.rb` = **8 runs / 23 assertions / 0F / 0E / 0 skips**. Suíte completa = **1217 runs / 4247 assertions / 3F+12E / 0 skips** (as 15 são as pré-existentes do baseline; +3 runs = os 3 testes novos). RuboCop = **0 offenses** nos 2 arquivos tocados; `zeitwerk:check` = "All is good!". Mutation testing: neutralizar a guarda per-dia ⇒ falham os testes de snapshot e de virada de mês (2 failures); neutralizar a guarda pré-consolidação ⇒ falha o teste "consolidar NAO e chamado" (1 failure).

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-10-14 | Branch `feature/demanda-32-1-guarda-finalizado-job` criada a partir de `chore/limpeza-rubocop-77` | OK |
  | 2026-10-14 | Guarda per-dia + guarda pré-consolidação no `CalcularFrequenciaJob#processar_usuario` | implementado |
  | 2026-10-14 | +3 testes (snapshot mês finalizado, virada de mês, consolidar não chamado) | 8 runs / 23 asserts / 0F / 0E |
  | 2026-10-14 | Mutation testing (2 pontos de decisão) | 2F/1F conforme esperado |
  | 2026-10-14 | Suíte completa + RuboCop + Zeitwerk | 1217/4247/3F+12E; 0 offenses; OK |

- Riscos: **duplicar** a regra de finalização (criar um segundo crivo que pode divergir) → mitigado por **reusar** `finalizado?`. Confundir mês do dia × mês corrente → a guarda é **por dia** e o teste cobre a virada de mês.

  **Review:** relatório em `docs/quality/review_report_32_1.md` — ✅ **Aprovado, 0 Blockers** (1 sugestão 🟡 S1). O revisor confirmou por mutation testing que os 3 testes novos são não-vacuosos, que o predicado canônico `finalizado?` é reusado (sem segundo crivo) e que os handlers não foram tocados (32.2 preservada).
  - **🟡 S1 (Melhoria) — APLICADO (2026-10-14):** memoização de `ConsolidacaoMensalService.finalizado?` por `[ano, mes]` dentro de `processar_usuario`, com um `Hash` **local à execução/usuário** (não ivar de classe, não cache global) consultado via `Hash#key?` — necessário porque o valor é booleano e o caminho comum é `false` ("mês aberto"); um `||=` simples faria o `false` reconsultar e anularia o ganho. Fora da virada de mês os 3 dias e a consolidação prévia caem no mesmo mês ⇒ os até 4 lookups por usuário passam a no máximo 2 (o corrente e, na virada, o anterior). **Comportamento externo inalterado** (otimização pura de lookups; guarda per-dia + pré-consolidação e rescues intactos). Novo teste não-vacuoso prova a memoização: cobre o mesmo mês aberto consultado **1×** (contra 4× sem memo); mutação `key?` → truthy ⇒ falha com 4 chamadas.
  - **Evidência pós-S1:** focado = **9 runs / 24 asserts / 0F / 0E**; suíte completa = **1218 runs / 4248 asserts / 3F+12E** (baseline 1217/4247 + 1 teste novo); RuboCop = **0 offenses** nos 2 arquivos tocados; `zeitwerk:check` = "All is good!".

#### Tarefa 32.2 — Espelho da guarda no handler `RECALCULAR_TODOS` (débito D2 da 31.4)
- User Story: Como sistema, quero que o handler `RECALCULAR_TODOS` aplique a **mesma guarda por dia** do job noturno, para que o recálculo em lote **não divirja** do `CalcularFrequenciaJob` (mesma classe de débito D2/17.5).
- Rastreabilidade: `iteration_31.md` **31.4 §"Débitos registrados" — 🟠-D2** ("ausência de guard `finalizado?` por dia ... herdada do `CalcularFrequenciaJob` (17.5) ... corrigir só o handler criaria divergência handler × job; o tratamento é tarefa própria sobre a 17.5 e o handler passa a espelhar") · **ADR-0011 regra 4** · `app/services/recalcular_todos_handler.rb`
- Estimativa: **2 pontos** | Atribuição: **Dev 1** | Dependências: **32.1** (a correção nasce no job; o handler espelha — **ordem obrigatória**)
- **Escopo (o que ENTRA):**
  - Antes de `CalculoDiarioService.calcular(user, dia)` no pipeline por usuário do `RecalcularTodosHandler`, checar **`ConsolidacaoMensalService.finalizado?(user, dia.year, dia.month)`** e pular o dia quando o mês dele estiver finalizado (skip silencioso) — **mesma semântica** da 32.1 e do `RegistroRecalculoHandler` (31.3, referência).
  - **Reusar** o predicado `finalizado?` (sem segundo crivo).
- **Escopo (o que NÃO ENTRA):** alterar o eixo `Pessoas::Vinculo.ativos` (31.4, correto per PRD); alterar a decisão de lock (31.4, correto per ADR-0011 regra 2); mexer no `RegistroRecalculoHandler` (31.3 — já tem a guarda; é a **referência**, não se altera).
- Critérios de aceite:
  - [x] Guarda por dia antes de `calcular`; mês finalizado ⇒ **skip silencioso** (não recalcula o dia).
  - [x] **Sem divergência handler × job:** a semântica de guarda do `RecalcularTodosHandler` converge com a do `CalcularFrequenciaJob` (32.1) e com o `RegistroRecalculoHandler` (31.3).
  - [x] Idempotência preservada (rodar 2× = mesma saída); erro por usuário **isolado** (`rescue StandardError` por usuário) mantido.
  - [x] Teste com o conjunto de usuários/CPFs **injetado em memória**; `class_method_stub_helper` (save/restore; nunca `remove_method`).
  - [x] Sem regressão no baseline; RuboCop/Zeitwerk OK.
- Status: ✅ **Concluída (2026-10-14)** — o `RecalcularTodosHandler#processar_usuario` passou a espelhar o `CalcularFrequenciaJob` (32.1): guarda `finalizado?` **por dia** antes de `calcular`, guarda **pré-consolidação** e **memoização por `[ano, mes]`** local à execução por usuário, reusando o predicado canônico `ConsolidacaoMensalService.finalizado?`. Rescues (`MesFinalizadoError` como salvaguarda de corrida; `StandardError` por usuário) e o guard `user.cpf.blank?` mantidos. Arquivos: `api-ponto/app/services/recalcular_todos_handler.rb`, `api-ponto/test/services/recalcular_todos_handler_test.rb`. Branch: `feature/demanda-32-2-espelho-handler` (base `fe7f8ff` = 32.1).

  **Evidência:** `bin/rails test test/services/recalcular_todos_handler_test.rb` = **11 runs / 30 assertions / 0F / 0E / 0 skips** (7 pré-existentes seguem verdes **sem mudança de expectativa**; +4 novos: snapshot mês finalizado, virada de mês, consolidar não chamado, memoização). Suíte completa = **1222 runs / 4257 assertions / 3F+12E / 0 skips** (as 15 são as pré-existentes do baseline; +4 runs / +9 asserts = os 4 testes novos). RuboCop = **0 offenses** nos 2 arquivos tocados; `zeitwerk:check` = "All is good!". Mutation testing: remover a guarda per-dia ⇒ **2 failures** (snapshot + virada); remover a guarda pré-consolidação ⇒ **1 failure** (consolidar não chamado); trocar o memo `Hash#key?` por truthiness ⇒ **1 failure** (memoização reconsulta 4×).

  **Equivalência handler × job (comparação lado a lado de `processar_usuario`):** estruturas idênticas — mesmo guard `cpf.blank?`, mesmo memo `{}` + lambda com `return ... if key?`, mesma guarda per-dia (`next if finalizado.call(dia.year, dia.month)`), mesmo `return if finalizado.call(hoje.year, hoje.month)` pré-consolidação, mesmos 2 `rescue`. Divergências **apenas não-semânticas**: indentação (o handler vive em `class << self`) e o prefixo do log (`[RecalcularTodosHandler]` × `[CalcularFrequenciaJob]`). **0 divergência de regra.**

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-10-14 | Branch `feature/demanda-32-2-espelho-handler` criada a partir de `fe7f8ff` (32.1) | OK |
  | 2026-10-14 | Guarda per-dia + pré-consolidação + memo no `RecalcularTodosHandler#processar_usuario` | implementado |
  | 2026-10-14 | +4 testes (snapshot, virada de mês, consolidar não chamado, memoização) | 11 runs / 30 asserts / 0F / 0E |
  | 2026-10-14 | Mutation testing (3 pontos de decisão) | 2F/1F/1F conforme esperado |
  | 2026-10-14 | Suíte completa + RuboCop + Zeitwerk | 1222/4257/3F+12E; 0 offenses; OK |

- Riscos: **ordem invertida** (corrigir o handler antes do job) recria a divergência que o débito D2 alerta → a dependência 32.1 → 32.2 foi respeitada (branch nasce de `fe7f8ff`). Duplicação handler × job: **intencional e registrada** (31.4) — não extraída para colaborador compartilhado; a equivalência foi conferida lado a lado.
  - **🟢 Nota de escopo:** o `RegistroRecalculoHandler` (31.3), o `VincularDesvincularHandler` (31.5/Q16) e o `CalcularFrequenciaJob` **não foram tocados** (fora de escopo).

- **📋 Relatório de Revisão — Dev 1 (Code Reviewer):** `docs/quality/review_report_32_2.md` — ✅ **Aprovado** (2026-10-14), **0 Blockers / 0 Sugestões formais**. Equivalência handler × job confirmada linha a linha; memo local por usuário (sem vazamento); 4 testes novos não-vacuosos (mutation A/B/C = 2F/1F/1F reproduzidos); suíte 1222/4257/3F+12E (15 pré-existentes em arquivos não relacionados); RuboCop/Zeitwerk OK. Escopo e ordem 32.1 → 32.2 respeitados.

- **🐞 Relatório de Bug Finder — Dev 1 (32.1 + 32.2):** `docs/quality/bug_report_32_hardening_guard_finalizado.md` — ✅ **0 bugs NOVOS** (🔴 0 / 🟠 0 / 🟡 0 / 🟢 1 / ⚪ 1). Teste adversarial (9 cenários exploratórios, motor real + 6 categorias + 88 testes relacionados): guarda correta na virada de mês / ano bissexto / fronteira de ano; predicado único (sem 2º crivo); memo sem vazamento entre usuários; handler × job semanticamente idênticos; idempotente. O 🟢 é a **confirmação** (não descoberta) do TOCTOU residual já documentado; o ⚪ é a staleness pré-existente de mês anterior aberto na virada (fora de escopo). Nenhuma correção obrigatória.

### Área — 2. Operação e governança (condicionadas à aprovação/decisão do dev)

> ⚠️ Os dois itens abaixo **não são tarefas de código** e **exigem decisão/aprovação explícita do dev**. Não avançam por iniciativa do agente (regra global do `CLAUDE.md`).

#### Tarefa 32.3 — Deploy da migration `create_tarefas_recalculo` (31.1) no dev remoto
- User Story: Como operação, quero aplicar a migration `create_tarefas_recalculo` no **dev remoto**, para que o mecanismo §5.2 (fila/despacho) **opere fora do banco de teste local**.
- Rastreabilidade: `iteration_31.md` §"Débitos Técnicos" (**migration 31.1 só no TESTE local**) · **ADR-0011** §Artefatos · migration `api-ponto/db/migrate/20261013120000_create_tarefas_recalculo.rb`
- Estimativa: **1 ponto** (operacional) | Atribuição: **Dev 1 (com aprovação do dev)** | Dependências: **pilha 31 disponível** (32.1 não depende; 32.3 sim)
- **Escopo (o que ENTRA):** `db:migrate` no **dev remoto** criando `tarefas_recalculo` (tabela + índice UNIQUE **parcial** `[tipo_entidade, referencia] WHERE status='pendente'`, conforme `db/schema.rb`); verificação de que a tabela existe no dev remoto.
- **Escopo (o que NÃO ENTRA):** ligar o cron `executa_tarefas` antes da migration aplicada; qualquer alteração de schema além da migration já existente; produção.
- Critérios de aceite:
  - [ ] **Aprovação explícita do dev** registrada antes da execução (operação de deploy).
  - [ ] `tarefas_recalculo` existe no dev remoto com o índice UNIQUE parcial (`ActiveRecord::Base.connection.table_exists?(:tarefas_recalculo)` + índice).
  - [ ] O cron `executa_tarefas` **não** é ligado antes da migration aplicada.
- Status: 🔵 **RECLASSIFICADA como pendência OPERACIONAL STANDALONE (CTO, 2026-10-14)** — **NÃO** integra mais o escopo de fechamento da Sprint 32 e **não** a mantém aberta. Motivo: o bloqueio é **de REDE** (host do dev remoto inalcançável), de **duração indefinida** e **independente** do trabalho de código (que está 100% encerrado). A **aprovação** do dev foi **concedida** (`/code-specialist 32.3`), mas a **execução** segue **impossível**: `Não há rota para o host 10.150.110.174:5000`. **Nada foi migrado; cron `executa_tarefas` DESLIGADO** (correto). Perde a dependência da sprint; **segue rastreada** até o destravamento (ver "caminho de destravamento" abaixo e §Débitos).

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-10-14 | Aprovação do dev registrada (critério de aceite nº 1 satisfeito) | concedida |
  | 2026-10-14 | Teste de alcance do dev remoto (`10.150.110.174:5000`) | ❌ **`Não há rota para o host`** |
  | 2026-10-14 | `db:migrate` executado? | **NÃO** — host inalcançável; nada foi migrado |

- Riscos: aplicar antes de aprovação; ligar o cron na branch integrada **antes** do `db:migrate` ⇒ o `ExecutaTarefasJob` falha (`relation does not exist`). **Como destravar:** restaurar a rota de rede (VPN) até `10.150.110.174:5000` e rodar `cd api-ponto && bin/rails db:migrate` — só a migration `20261013120000_create_tarefas_recalculo` está pendente no dev; **ou** rodar de uma máquina com rota e trazer a evidência. **Estado atual:** cron `executa_tarefas` **desligado** (correto).

#### Tarefa 32.4 — Governança de docs: ponteiro do `CLAUDE.md` do workspace → `Frequencia/docs/`
- User Story: Como agente/dev do projeto Frequência, quero que o ponteiro de documentação aponte para a árvore correta (`Frequencia/docs/`), para não ser conduzido à árvore do **outro** projeto (`pessoas2/docs/`).
- Rastreabilidade: `implementation_plan.md` v2 — **Épico 7** (governança de docs) · `docs/progress/_context.md` (2026-10-14) · arquivo **externo ao repo Frequencia**: `workspace_integração/CLAUDE.md`
- Estimativa: **1 ponto** | Atribuição: **Dev 1 (decisão do dev)** | Dependências: **decisão do dev pendente**
- **Contexto factual:** o `CLAUDE.md` do **workspace** (`workspace_integração/CLAUDE.md`) aponta `pessoas2/docs/` e `pessoas2/docs/governance/` para **todo** o workspace (**multi-projeto**). O cabeçalho do `docs/README.md` do Frequência **já foi corrigido** (2026-10-14) — **resta apenas o ponteiro do `CLAUDE.md` do workspace**. O arquivo **não está dentro do repo `Frequencia`** (está em `workspace_integração/`).
- **Escopo (o que ENTRA):** corrigir/escopar o ponteiro de docs para o **projeto Frequência** apontar para `Frequencia/docs/` (ideal: **escopar por projeto**, de modo que o Frequência não seja conduzido à árvore do Pessoas2).
- **Escopo (o que NÃO ENTRA):** alterar a documentação do projeto Pessoas2; quebrar o carregamento para os **outros** projetos do workspace.
- Critérios de aceite:
  - [x] **Decisão do dev (2026-10-14): abordagem ESCOPADA POR PROJETO** — NÃO a correção global (uma correção global conduziria todo o workspace ao Frequência e degradaria quem trabalha no Pessoas2 na mesma pasta).
  - [x] Para o Frequência, o ponteiro de docs **não conduz mais** a `pessoas2/docs/`.
  - [x] A mudança **não** afeta os demais projetos: o Pessoas2 continua apontando para `pessoas2/docs/`.
- Status: ✅ **CONCLUÍDA** (2026-10-14) — `workspace_integração/CLAUDE.md` reescrito com ponteiro **por projeto** (`Frequência → Frequencia/docs/`; `Pessoas2 → pessoas2/docs/`; governança `<projeto>/docs/governance/`). Executado **diretamente pelo coordenador** (não por agente): é um arquivo de **configuração do workspace**, fora do repo Frequencia, e as regras pedem cuidado extra com esse tipo de arquivo. **Sem commit** (o arquivo não pertence ao repo `Frequencia`).
- Riscos: editar um arquivo **compartilhado** do workspace e quebrar outros projetos; tratar como tarefa fechada antes da decisão do dev. Nota: a alteração está **fora do repo Frequencia** — se o guia for "não tocar fora do repo", a tarefa vira apenas **recomendação** ao dev.

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-10-14 | Decisão do dev: abordagem **escopada por projeto** (não global) | decidido |
  | 2026-10-14 | `workspace_integração/CLAUDE.md` reescrito (2 seções) — ponteiro por projeto | aplicado |
  | 2026-10-14 | Verificação: Pessoas2 segue apontando `pessoas2/docs/`; Frequência → `Frequencia/docs/` | OK |
  | 2026-10-14 | Commit | **N/A** — arquivo fora do repo `Frequencia` |

## Candidatos opcionais (horizonte 33+ — **NÃO comprometidos nesta sprint**)

> Estes candidatos **não são obrigação herdada**; são **escolhas** que o dev pode puxar se quiser **preencher** a sprint (ver §"Veredito honesto sobre o tamanho"). Sem aprovação explícita, **ficam fora**.

#### Candidato 32.O1 — Enforcement opt-in da cascata (débito estrutural, ADR-0010 regra 9)
- Descrição: endurecer o enforcement da cascata de autorização — hoje **opt-in por controller** (concern `FrequenciaAuthorization`); `authorize! :read, :all` satisfaz o `check_authorization`, então **qualquer controller novo que leia `TimeRecord`/`Pessoas::Vinculo` vaza silenciosamente** (causa-raiz do Bug 🔴1 da 30). Mitigação estrutural: **central `before_action`** ou **teste de conteúdo obrigatório por tela de listagem**.
- Rastreabilidade: **ADR-0010 regra 9** · `implementation_plan.md` v2 (risco "Enforcement opt-in da cascata" — 🟠 Alto; candidata ao horizonte 33+).
- Estimativa: **5 pontos** | Atribuição: **Dev 1 (se aprovado)** | Dependências: **aprovação explícita do dev** (toca autorização — regra global do `CLAUDE.md` exige plano claro).
- Custo/risco: **toca `Ability`/controllers de listagem** — exige plano claro e teste por tela; risco de regressão em telas bespoke; a flag `:off` **não** é afetada (o vazamento ocorre em **qualquer** valor da flag). **Alto valor de hardening**, mas **fora** do escopo macro restrito do Épico 7 — por isso é **candidato**, não tarefa.
- Status: ⛔ **Não comprometido** (decisão do dev)

Outros candidatos do **horizonte 33+** já documentados (apenas registrados, **sem** detalhamento aqui): tipos adiados `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` (models inexistentes — política incremental); gaps PRD §9 #4/#6/#8; revisita do **Bug 🟠2** (`/presenca/*` sem auth — risco aceito, gatilho = fim dos testes manuais da Estação); débitos 🟢 da 31 (TOCTOU de mês finalizado e crash-window do despacho — reabrir só se a finalização de mês passar a ser automatizada). **Nenhum é obrigação herdada.**

## Requisitos de teste (transversais — valem como critério de aceite de todas as tarefas)

1. **Guard de estado ANTES de toda escrita:** a checagem de mês finalizado é um **predicado lido antes da primeira escrita** — nunca um `rescue` no fim (lição 2026-10-13). Vale para 32.1 e 32.2.
2. **Reusar, não duplicar o crivo:** `ConsolidacaoMensalService.finalizado?` é o **único** predicado de finalização; nenhuma segunda condição é criada.
3. **Sem divergência handler × job:** a semântica de guarda do job (32.1) e dos handlers que o espelham (32.2; e o `RegistroRecalculoHandler`/31.3 como referência) é a **mesma**.
4. **NUNCA `remove_method`:** todo stub de método de classe/produção usa **`test/support/class_method_stub_helper.rb`** (save/restore no `ensure`).
5. **Idempotência preservada:** o pipeline continua idempotente (`find_or_initialize_by`); reprocessar = mesma saída.
6. **Sem regressão no recálculo existente:** suítes de `CalculoDiarioService`, `ConsolidacaoMensalService`, `CalcularFrequenciaJob` e handlers permanecem verdes; isolar as **15 pré-existentes**.
7. **Mutation testing** (padrão do projeto): neutralizar a guarda per-dia no job ⇒ o teste de snapshot falha; neutralizar a guarda no handler ⇒ o teste correspondente falha.
8. **Nada de autorização** (exceto se o candidato 32.O1 for aprovado): nenhum teste toca `Ability`/`AutorizacaoFrequencia`/`FrequentadoresVisiveis`/`FrequenciaAutorizacaoCascata`.

## Quadro de tarefas (resumo)

| Tarefa | Área | Pontos | Dependência | Natureza | Status |
|--------|------|--------|-------------|----------|--------|
| **32.1** | Recálculo — D2/17.5 | **3** | nenhuma | código | ✅ Concluída (2026-10-14) |
| **32.2** | Recálculo — espelho 31.4 | **2** | **32.1** | código | ✅ Implementado, ✅ Aprovado (2026-10-14) |
| **32.3** | Operação — deploy migration | **1** | pilha 31 | operacional (aprov. dev) | 🔵 **Reclassificada — pendência OPERACIONAL STANDALONE** (bloqueio de rede; fora do caminho crítico; **não** mantém a sprint aberta) |
| **32.4** | Governança — ponteiro docs | **1** | decisão do dev | governança (fora do repo) | ✅ Concluída (2026-10-14) |
| **32.O1** | Horizonte — enforcement cascata | *(5)* | aprov. dev | **candidato opcional** | ⛔ Não comprometido |

**Total comprometido e ENCERRADO nesta sprint:** **6 pontos** (32.1 = 3 + 32.2 = 2 de código; 32.4 = 1 de governança). A **32.3** (1 pt operacional) é **STANDALONE** — rastreada fora do fechamento da sprint (bloqueio de rede).
**Total com o candidato 32.O1 aprovado:** **12 pontos**.

## Caminho Crítico

**32.1 (3) → 32.2 (2)** = **5 pontos** de caminho crítico (execução **sequencial**, 1 dev). Os itens 32.3/32.4 são **operacionais/governança** e podem ocorrer em paralelo ao trabalho de código **se** aprovados pelo dev — mas **não** bloqueiam o caminho crítico.

```
32.1 ──> 32.2          (Dev 1, sequencial)
32.3 (deploy)  ∥ 32.4 (docs)   [se aprovados; fora do caminho crítico]
32.O1 (opcional) ──> só se o dev aprovar
```

## Riscos

- **Sprint curta (veredito honesto abaixo).** O núcleo real é **5 pontos de código** + 2 itens condicionados; não preenche uma semana típica sozinho. Mitigação: decisão do dev entre rodar curta × puxar `32.O1`/horizonte.
- **Merge pendente da pilha 31 em `integration/sprint-29`.** Se o time exigir base em `integration/sprint-29`, **32.2 e 32.3 ficam bloqueadas**. Mitigação: basear a sprint no HEAD que contém a pilha (`chore/limpeza-rubocop-77`) ou aguardar o merge (decisão do dev).
- **Divergência handler × job** se a ordem 32.1 → 32.2 for invertida. Mitigação: dependência obrigatória registrada.
- **Duplicação do crivo de finalização.** Mitigação: reusar `finalizado?`; grep prova.
- **TOCTOU residual de mês finalizado** (herdada; 🟢). Permanece débito aceito; reabrir só se a finalização de mês for automatizada.
- **Operação sem aprovação / cron ligado antes do migrate.** Mitigação: 32.3 explicitamente condicionada à aprovação do dev.
- **Alterar arquivo compartilhado do workspace** (32.4) e afetar outros projetos. Mitigação: escopar por projeto; decisão do dev primeiro; arquivo está **fora** do repo Frequencia.

## Débitos Técnicos

- [x] **D2 da 17.5** — `CalcularFrequenciaJob` recalcula os últimos 3 dias **sem** guarda de mês finalizado ⇒ `CalculoDiario` de mês fechado pode ser reescrito e o `RegistroMensalFrequencia` ficar stale. **TRATADO (32.1, 2026-10-14):** guarda `finalizado?` por dia + pré-consolidação. Severidade: 🟠 — Tarefa: 32.1 ✅.
- [x] **D2 da 31.4** — `RecalcularTodosHandler` sem guard `finalizado?` por dia (mesma classe de D2/17.5). **TRATADO (32.2, 2026-10-14):** guarda `finalizado?` por dia + pré-consolidação + memo, espelhando o job (32.1). Severidade: 🟠 — Tarefa: 32.2 ✅.
- [x] ~~**Q16 — "cauda" do período ao encolher o vínculo (31.5)**~~ — **FECHADO como débito ACEITO (dev, 2026-10-14): MANTER O LITERAL.** A cauda não é recalculada; decisão documentada, **não** é tarefa da 32. Severidade: 🟠 (aceito) — Tarefa: (nenhuma).
- [ ] **Migration `create_tarefas_recalculo` (31.1) só no banco de TESTE local** — falta `db:migrate` no dev remoto. **PENDÊNCIA OPERACIONAL STANDALONE** (reclassificada da 32.3 — CTO, 2026-10-14): aprovada pelo dev, **bloqueada por rede** (host inalcançável), **fora do caminho crítico**, **não** mantém a sprint aberta. **Caminho de destravamento:** restaurar a rota/VPN até `10.150.110.174:5000` → `cd api-ponto && bin/rails db:migrate` (só a migration `20261013120000_create_tarefas_recalculo` está pendente no dev) → conferir `table_exists?(:tarefas_recalculo)` + índice UNIQUE parcial → **somente então** ligar o cron. **Estado atual:** cron `executa_tarefas` **DESLIGADO** (correto). Severidade: 🟠 (operacional/rede) — Tarefa: standalone.
- [x] **Governança de docs** — ✅ **RESOLVIDO (32.4, 2026-10-14):** o `CLAUDE.md` do workspace foi reescrito para **escopar por projeto** (`Frequência → Frequencia/docs/`; `Pessoas2 → pessoas2/docs/`; governança `<projeto>/docs/governance/`) — decisão do dev. Não conduz mais o Frequência à árvore do Pessoas2, e preserva o caminho do Pessoas2. Sem commit (arquivo fora do repo `Frequencia`). Severidade original: 🟡.
- [ ] **TOCTOU residual de mês finalizado** (31.3/31.5) — guard "melhor esforço"; documentado honestamente. **Reconfirmado reproduzível pelo Bug Finder na 32 (🟢 Bug 1 do `bug_report_32_…`)** — o hardening (32.1/32.2) **reduziu** a janela (predicado→escrita) de "toda execução" para "entre o predicado e a escrita". **Nuance NOVA (introduzida pela memoização S1):** como o predicado é memoizado por `[ano, mes]` **local ao usuário**, o estado `false` é "grudento" até o fim do processamento daquele usuário ⇒ a janela **intra-usuário** passa de "por consulta" para "por usuário" (impacto prático desprezível: finalização **manual**, janela de microssegundos). Severidade: 🟢 — Tarefa: futura (reabrir com lock compartilhado — ex.: `SELECT … FOR UPDATE` no `RegistroMensalFrequencia` dentro de `consolidar` — **somente** se a finalização de mês deixar de ser manual).
- [ ] **Staleness pré-existente na virada** (⚪ Info do Bug Finder na 32) — na virada (ex.: `hoje`=01/11), o job recalcula os 3 últimos dias, podendo incluir 31/10 e 30/10. Se **outubro estiver ABERTO**, esses dias são recalculados mas **outubro não é reconsolidado** (o job só consolida o mês de `hoje`) ⇒ `RegistroMensalFrequencia` de outubro fica **stale** face ao `CalculoDiario`; o `acumulado` lido por novembro (`buscar_saldo_mes_anterior`) pode refletir o valor antigo. **NÃO é regressão da 32.1/32.2** — é a **filosofia de propósito** do `CalcularFrequenciaJob` (3 dias + mês corrente), **proibida de ser reaberta** (§"Fronteira explícita"). Registrado como observação de interação, **sem ação nesta sprint**. Severidade: ⚪ (informativo/pré-existente) — Tarefa: fora do escopo da 32.
- [ ] **Crash-window do despacho** (31.2) — entre `processada` e o efeito do handler; idempotência mora nos handlers. Severidade: 🟢 — Tarefa: futura (se observado em produção).
- [ ] **Enforcement opt-in da cascata** (ADR-0010 regra 9) — causa-raiz do Bug 🔴1; **candidato opcional 32.O1**, horizonte 33+. Severidade: 🟠 — Tarefa: 32.O1 (não comprometida).
- [ ] **Linha basic8 (Sprints 25/27/28)** — **PAUSADA** por ruling do dev (2026-10-14); pode voltar ao horizonte. Severidade: 🟡 — Tarefa: fora da 32.

## Definição de Pronto

- [x] 32.1 e 32.2 implementadas com Status e Linha do Tempo preenchidos; **32.4 executada**; **32.3 aprovada mas reclassificada como pendência OPERACIONAL STANDALONE** (bloqueio de rede; fora do caminho crítico), registrada com o caminho de destravamento e o estado correto do cron.
- [x] Testes: **guard de mês finalizado como predicado antes da escrita** (job 32.1 + handler 32.2), **virada de mês coberta**, **sem divergência handler × job**, **sem `remove_method`**, **sem regressão**; mutation testing dos pontos críticos (32.1: 2F/1F; 32.2: 2F/1F/1F).
- [x] `db/schema.rb` **inalterado** por esta sprint (nenhuma migration nova) — só o `db:migrate` de deploy (32.3, **standalone**) sobre a migration **já existente** (`20261013120000_create_tarefas_recalculo`).
- [x] **Nenhuma** alteração de `Ability`/cascata/autorização (o `32.O1` **não** foi puxado), respeitando o registro global do `CLAUDE.md`.
- [x] Q16 registrada como **fechada (literal)**; basic8 registrada como **pausada**; Q15 = **1 dev sequencial**.
- [x] Commit **realizado pelo dev** (pilha `fe7f8ff` → `905d8fb`; +`40740b3` docs); push em `origin`/`gitlab`; **o agente NÃO commita/pusha** (`COMMIT_MODE=manual`).

## Perguntas abertas ao dev / PO

- **Q15 (quadro de devs) — ✅ RESOLVIDA (dev, 2026-10-14):** **1 DEV, execução SEQUENCIAL.** Sprint dimensionada **sem paralelismo** (sem worktrees). Consequência: as tarefas são sequenciais (32.1 → 32.2).
- **Q16 (cauda do período do vínculo/31.5) — ✅ RESOLVIDA (dev, 2026-10-14):** **MANTER O LITERAL.** O `VincularDesvincularHandler` recalcula `[momento_inicial, momento_final]`; ao encolher o período, a cauda **não** é recalculada — **débito ACEITO e documentado**. **Não é tarefa da Sprint 32.**
- **basic8 (Sprints 25/27/28) — ✅ RESOLVIDA (dev, 2026-10-14):** **PAUSADA** (não cancelada; pode voltar ao horizonte). Não é tarefa da 32.
- **Q32-A — merge da pilha 31 em `integration/sprint-29` — ✅ RESOLVIDA (dev, 2026-10-14):** a Sprint 32 é **baseada na branch `chore/limpeza-rubocop-77`** (que já contém a pilha 31 inteira + os docs). Isso **desbloqueia 32.2 e 32.3** sem exigir o merge, que **segue pendente/bloqueado pelo dev**.
- **Q32-B — PARCIALMENTE RESOLVIDA (dev, 2026-10-14):** o **ponteiro de docs (32.4)** foi **decidido e executado** — abordagem **escopada por projeto** (não a global); a alteração do `CLAUDE.md` do workspace foi autorizada e aplicada. **Segue aberta apenas a parte do deploy (32.3):** a **aprovação** do dev foi dada, mas a **execução está bloqueada por INFRAESTRUTURA** — o host `10.150.110.174:5000` (dev remoto, `config/database.yml:23-30`) está **inalcançável** desta máquina (`Não há rota para o host`), a mesma condição da 31.1. **Nada foi migrado**; o cron `executa_tarefas` continua **desligado** (correto — ligá-lo antes do migrate faria o job falhar com `relation does not exist`).
- **Q32-C — tamanho da sprint — ✅ RESOLVIDA (dev, 2026-10-14):** rodar a sprint **CURTA como planejada** — **7 pts** (32.1 + 32.2 + os 2 itens condicionados). O candidato **`32.O1` (enforcement opt-in da cascata) NÃO foi puxado** — segue como candidato não comprometido (horizonte), por tocar autorização e depender da migração de roles.

## Veredito honesto sobre o tamanho da sprint

**Com o Q16 fora, sobra pouco.** O escopo **obrigatório** é essencialmente **uma correção de código real (D2/17.5 — 32.1, 3 pts)** e **seu espelho no handler `RECALCULAR_TODOS` (32.2, 2 pts)** — **5 pontos de código**, execução sequencial por 1 dev (**≈meio a 1 dia de trabalho efetivo**). Os outros dois itens (**32.3 deploy** e **32.4 governança de docs**) **não são código** e **ambos estão gated em decisão/aprovação do dev** (podem nem ser executados nesta sprint). Somando tudo, o **total comprometido é 7 pontos** (2 deles condicionados) — **abaixo** de uma sprint cheia padrão (14 pts).

**Portanto: o escopo herdado NÃO preenche, sozinho, uma sprint de uma semana.** Esta é a avaliação honesta pedida — **não inventei escopo para engordar**. Recomendações (decisão do dev):

1. **Rodar a sprint curta como está** (5–7 pts): é um hardening legítimo e barato; a sprint termina rápido e fecha o D2/17.5 + o espelho com segurança. Legítimo para uma sprint de débito.
2. **Se quiser preencher a semana**, puxar **explicitamente** um candidato do horizonte — o único de **alto valor de hardening** é o **`32.O1` (enforcement opt-in da cascata, ADR-0010 regra 9, 5 pts)**, que **toca autorização** e por isso exige **plano claro + aprovação do dev** (é **escolha a mais, não obrigação herdada**). Os demais candidatos (tipos adiados, gaps §9 #4/#6/#8, Bug 🟠2) são de **custo alto/largo** e **não** cabem numa sprint de hardening — ficam no horizonte 33+.
3. **Ou** reagrupar: **absorver 32.1/32.2 na retomada de features** e encerrar a 32 como uma sprint operacional curta (deploy + docs), já que ambos os itens condicionados dependem do dev.

Nenhuma das opções altera o ruling do dev sobre Q16 (literal), basic8 (pausada) ou Q15 (1 dev sequencial).

## Linha do Tempo

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
| 2026-10-14 | Planejamento da **Sprint 32** (hardening/débitos) + rulings do dev (Q16=literal, basic8=pausada, Q15=1 dev, Q32-A/B/C) — `0e55c2a`; reconciliação do plano v2 + README (Onda 1) | 4 tarefas, **7 pts** comprometidos; candidato `32.O1` **não** puxado |
| 2026-10-14 | **32.1** — guarda de mês finalizado **por dia** + guarda pré-consolidação + memo no `CalcularFrequenciaJob` (`fe7f8ff`) | implementado/testado/revisado (**0 blockers**); focado 9/24; suíte **1218/4248/3F+12E** |
| 2026-10-14 | **32.2** — espelho no `RecalcularTodosHandler` (`905d8fb`) | implementado/testado/revisado (**0 blockers, 0 sugestões**); focado 11/30; suíte **1222/4257/3F+12E** |
| 2026-10-14 | **Bug Finder** (32.1+32.2) — teste adversarial (9 cenários + 6 categorias + 88 testes relacionados) | **0 bugs novos** (🟢 1 TOCTOU **confirmado** + nuance do memo; ⚪ 1 staleness pré-existente) |
| 2026-10-14 | **32.4** — `CLAUDE.md` do workspace reescrito com ponteiro **escopado por projeto** (arquivo **fora** do repo, sem commit) — registrado no doc `40740b3` | ✅ Concluída |
| 2026-10-14 | **32.3** — deploy da migration `create_tarefas_recalculo` (31.1) no dev remoto | 🔵 **Reclassificada STANDALONE** — host `10.150.110.174:5000` inalcançável (**"Não há rota para o host"**); **nada migrado; cron desligado** |
| 2026-10-14 | **CTO encerra a Sprint 32** — header/DoD/Débitos/Linha do Tempo + §Encerramento; ADR (decisão: **nenhuma**); catalogação dos achados; lições | 🟢 **ENCERRADA** (doc-only, sem commit — `COMMIT_MODE=manual`) |

---

## Encerramento da Sprint 32 (CTO, 2026-10-14)

**Veredito:** 🟢 **SPRINT 32 ENCERRADA.** O **núcleo de código** — **32.1** (guarda de mês finalizado no `CalcularFrequenciaJob`, débito **D2/17.5**) e **32.2** (espelho no `RecalcularTodosHandler`, débito **D2 da 31.4**) — está **implementado, testado, revisado e commitado** (pilha `fe7f8ff` → `905d8fb`, sobre `chore/limpeza-rubocop-77`; + `40740b3` para 32.4/docs). **Code Reviewer: 0 blockers** em ambas; **Bug Finder: 0 bugs novos**. O **débito D2/17.5 está FECHADO nos DOIS espelhos** (job + handler). Baseline final **1222/4257/3F+12E/0 skip** (as **15** pré-existentes, nenhuma da 32). A **32.3** deixou de ser tarefa de fechamento e virou **pendência OPERACIONAL STANDALONE** (bloqueio de **rede**, duração indefinida). A **32.4** foi concluída. **Sem ADR nova** (ver §decisão).

### O que a Sprint 32 muda no entendimento do sistema

- **A trava 17.2 passa a valer no recálculo AUTOMÁTICO (noturno), não só no dirigido por evento.** Antes, o `CalcularFrequenciaJob` recalculava os últimos 3 dias direto no `save!` do `CalculoDiario` (sem passar pela trava que só "levanta erro" no `consolidar`) — **mesma classe de bug** que a correção A/31.3 já havia fechado no handler. A 32 **elimina o último caminho de escrita** que burlava a trava: agora **nenhum** recalculador (job 17.5, `RecalcularTodosHandler`, `RegistroRecalculoHandler`, `VincularDesvincularHandler`) escreve num mês finalizado.
- **Fim da divergência handler × job.** O débito D2 alertava que corrigir só o handler criaria divergência. A ordem **32.1 → 32.2** foi respeitada: a correção **nasce no job** e o handler **espelha** (semântica conferida **linha a linha** — 0 divergência de regra). O sistema passa a ter **um único entendimento** de "não recalcular mês finalizado", expresso pelo **predicado canônico único** `ConsolidacaoMensalService.finalizado?` (grep prova: **nenhum segundo crivo**).
- **A guarda é POR DIA, não por "mês corrente".** Os 3 últimos dias podem **cruzar a virada de mês**; a checagem usa `dia.year/dia.month` (não o mês de `hoje`), então cobre virada de mês, fronteira de ano e ano bissexto (provado por teste + 9 cenários adversariais).
- **Custo de lookup reduzido (S1).** A memoização por `[ano, mes]` **local ao usuário** reduz os até 4 `find_by` por usuário para no máximo 2 (o corrente e, na virada, o anterior) — otimização pura, **comportamento externo inalterado**.
- **Fronteira com a filosofia do job preservada.** Nada da "3 dias + mês corrente" foi reaberto; a única adição é a guarda prévia. A **staleness da virada** (mês anterior **aberto** recalculado sem reconsolidação) permanece **de propósito** (débito aceito — ver §achados).

### Decisão sobre ADR — **NÃO** criar ADR nova (confirmado com argumentos)

A avaliação preliminar foi **confirmada**: **não cabe ADR nova**. Três razões:

1. **A decisão arquitetural é ANTERIOR à sprint.** O guard de mês finalizado como **predicado lido antes da escrita** — inclusive aplicado ao **DIA** — já está consolidado na **ADR-0011 regra 4** ("Trava de mês finalizado (17.2) vale para o recálculo por evento — inclusive para o DIA", com o motivo explícito do `save!` sem guarda). A própria ADR-0011, em §Consequências, **prescreve** o tratamento do D2/17.5: *"o tratamento correto é tarefa própria sobre a 17.5 (guard por dia lá; o handler espelha)"*. A Sprint 32 **executou exatamente o que a ADR-0011 já mandava** — não é decisão nova, é **cumprimento** de decisão registrada.
2. **Natureza da entrega = aplicação/espelhamento, não escolha arquitetural.** Não houve nova alternativa descartada, novo trade-off estrutural nem nova regra de negócio. O que a 32 fez foi **fechar os dois espelhos** que faltavam (job 32.1 + handler 31.4/32.2) e **reusar** o predicado canônico.
3. **Consistência de série.** A última ADR é a **0011**. Criar uma "ADR-0012" para registrar a *aplicação* de uma regra da 0011 infla a série com uma decisão que **não existe** (o mesmo critério de coesão que a 0011 usou para não se fragmentar em sete).

**Ação de manutenção da ADR-0011 (defasagem):** a §Consequências da ADR-0011 ainda listava o **D2/17.5 como débito ABERTO**. Como a 32 o **fechou**, anexei à ADR-0011 uma **nota datada de resolução** (sem reescrever o texto original — preserva o histórico). Ver §Artefatos.

### Achados do Bug Finder — onde foram catalogados

O Bug Finder (`docs/quality/bug_report_32_hardening_guard_finalizado.md`) reportou **0 bugs novos** (🔴0/🟠0/🟡0/🟢1/⚪1). Catalogação:

| Achado | Origem | Onde foi catalogado | Foi para `lessons.md`? |
|---|---|---|---|
| 🟢 **TOCTOU residual** de mês finalizado (**confirmado reproduzível** pelo ATAQUE 8) + **nuance nova** da memoização (janela "grudenta" passa de *por consulta* para *por usuário*) | Débito conhecido (31.3/31.5; ADR-0011 regra 4); **reduzido** — não ampliado — pelo hardening | §**Débitos Técnicos** deste doc (linha do TOCTOU, com a nuance) + `bug_report_32_…` (Bug 1) + `review_report_32_2.md` ⚪ O2 | **NÃO** — coberto pelo ADR-0011 regra 4 + pela lição de 2026-10-13 ("guarda antes de TODA escrita") e pelo próprio bug report |
| ⚪ **Staleness pré-existente na virada** (mês anterior **aberto** recalculado sem reconsolidação; carryover pode ler valor antigo) | **Pré-existente** — filosofia do job (3 dias + mês corrente), proibida de reabrir | §**Débitos Técnicos** deste doc (entrada nova, marcada ⚪/fora de escopo) + `bug_report_32_…` (Info) | **NÃO** — é comportamento de propósito, não lição |

**Sobre a nuance da memoização merecer registro no `_context`/governança:** **não** merece entrada própria. Ela é uma consequência **de baixo impacto** (finalização **manual**, janela de microssegundos) de uma **otimização** (S1), já **precisamente registrada** no `bug_report_32_…` (Bug 1) e no §Débitos deste doc, e **coberta pela classe** do débito TOCTOU existente. Registrá-la na governança criaria duplicação sem ganho.

### Riscos/decisões que exigem o dev nesta virada (checklist)

- [ ] **Merge da pilha 31 em `integration/sprint-29`** — **PENDENTE / bloqueado por decisão do dev** (`COMMIT_MODE=manual`); `integration/sprint-29` @ `d50f317` **intacta**. A Sprint 32 **não** altera esse bloqueio.
- [ ] **Merge da branch da Sprint 32** (`feature/demanda-32-2-espelho-handler` @ `40740b3`, já em `origin`/`gitlab`) para a base escolhida — decisão do dev (via `--no-ff`, preservando o agrupamento).
- [ ] **32.3 (STANDALONE) — deploy da migration `create_tarefas_recalculo` no dev remoto.** Aprovada, **bloqueada por rede**. Destravar restaurando a rota/VPN → `cd api-ponto && bin/rails db:migrate`. **NÃO** ligar o cron `executa_tarefas` antes (hoje **desligado**, correto).
- [x] **Sprint 33 — escopo DEFINIDO pelo dev (2026-10-15): `32.O1`** (enforcement opt-in da cascata, ADR-0010 regra 9). **Toca autorização** ⇒ exige **plano claro + aprovação explícita ANTES de qualquer código** — plano a ser submetido; nada implementado. Os demais candidatos seguem rastreados (ver §"Situação da Sprint 33").
- [ ] *(Informativo)* **Commit/push do pacote doc-only do CTO** desta virada — manual, pelo dev.

### Sequência recomendada de entrega (proposta — CTO NÃO executa)

1. **Gate de CI local** (`ci-cd-pipeline`) sobre a pilha da Sprint 32: security → quality → **test** (mandatório). Baseline final **1222/4257/3F+12E** (as **15** pré-existentes devem ser reconhecidas, não atribuídas à sprint).
2. **Merge da `feature/demanda-32-2-espelho-handler`** (que já contém 32.1 → 32.2) na base escolhida — `--no-ff`, após confirmar rebase sobre o HEAD atual da base.
3. **32.3 (ao destravar a rede): `db:migrate` no dev remoto** — **antes** de ligar o cron na branch integrada.
4. **Push** da branch integrada aos remotes (GitLab + fork GitHub), conforme o padrão do repo.
5. **Fechamento** já materializado: header 🟢 + §Encerramento + Débitos/Linha do Tempo + nota de resolução na ADR-0011 + catalogação dos achados + README. Commit **doc-only** do pacote do CTO (o dev commita/pusha manualmente — `COMMIT_MODE=manual`).
6. **Sprint 33** — abrir **somente após ruling do dev** (próxima seção).

### Situação da Sprint 33 — **ESCOPO DEFINIDO pelo dev (2026-10-15): `32.O1`**

**Atualização (2026-10-15):** o dev **decidiu o escopo da Sprint 33 = `32.O1`** (enforcement opt-in da cascata, ADR-0010 regra 9, ~5 pts). Como **toca autorização**, a regra global exige **plano claro + aprovação explícita do dev ANTES de qualquer código**: o plano será submetido e, só após o aval, o `iteration_33.md` é detalhado e a implementação começa. **Nada foi implementado.** Os demais candidatos abaixo **permanecem rastreados e não comprometidos**:

_(a lista abaixo é o registro de quando a sprint estava indefinida — mantida como histórico)_

- **`32.O1` — Enforcement opt-in da cascata** (ADR-0010 regra 9; **~5 pts**; causa-raiz do Bug 🔴1 da 30). **Único candidato de ALTO valor de hardening** — mas **toca autorização** e exige **plano claro + aprovação do dev**. **Não** puxado na 32.
- **Tipos de recálculo adiados** `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` — exigem **models de domínio inexistentes** (política incremental vigente).
- **Linha basic8** (Sprints 25/27/28 do plano v1) — **PAUSADA** por ruling do dev (2026-10-14): **não cancelada**, pode voltar ao horizonte.
- **Bug 🟠2** (`/presenca/*` sem autenticação) — **risco aceito**; gatilho de revisita = fim dos testes manuais da Estação.

### Artefatos da consolidação (editados pelo CTO nesta virada)

- `docs/progress/iteration_32.md` — **header** (🟢 ENCERRADA), **§Linha do Tempo** (sprint-level), **§Encerramento da Sprint 32**, **§Débitos Técnicos** (TOCTOU + nuance da memoização; staleness; 32.3 standalone), **Quadro de tarefas** e **Definição de Pronto**.
- `docs/adr/0011-mecanismo-recalculo-por-evento.md` — **nota datada de resolução** do D2/17.5 (feito pelos espelhos 32.1/32.2), sem reescrever o texto original.
- `docs/README.md` — estado atual atualizado (última sprint implementada = **32**).
- *(NÃO editado por decisão de escopo — regeneração é do Summarizer):* `docs/progress/_context.md` (**defasado** — HEAD `ceaac87`, Sprint 32 como esboço) e `docs/governance/_context.md` (lições 42 / ADRs 0000–0011 — precisa refletir a 32).

