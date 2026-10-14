# Iteration 32 — Hardening e débitos herdados

> Status: 📋 **PLANEJADA** | Período: 2026-10-14 → (≈1 semana, execução SEQUENCIAL por 1 dev) | Goal: **fechar os débitos herdados das Sprints 30/31 e a operação pendente, sem introduzir funcionalidade nova** — em especial a **guarda de mês finalizado no `CalcularFrequenciaJob` (D2/17.5)** e o **espelho no handler `RECALCULAR_TODOS`**, mais os itens operacional/de governança condicionados à aprovação do dev. | Rastreabilidade: `iteration_31.md` §"Débitos Técnicos" · **ADR-0011** (regra 4/consequências — D2/17.5) · `docs/12-plano-implementacao/implementation_plan.md` **v2 — Épico 7** · `SPRINT-PLAN.md:536` (17.5) · `iteration_30.md` §"Débito de rastreabilidade".

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
- Status: 🟡 **BLOQUEADA POR INFRAESTRUTURA** (2026-10-14) — aprovação do dev **concedida** (`/code-specialist 32.3`), mas **não executável**: o host do dev remoto está inalcançável.

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
| **32.3** | Operação — deploy migration | **1** | pilha 31 | operacional (aprov. dev) | 🟡 Bloqueada por infra (aprovada, host inalcançável) |
| **32.4** | Governança — ponteiro docs | **1** | decisão do dev | governança (fora do repo) | ✅ Concluída (2026-10-14) |
| **32.O1** | Horizonte — enforcement cascata | *(5)* | aprov. dev | **candidato opcional** | ⛔ Não comprometido |

**Total comprometido (código + operacional/governança):** **7 pontos** (2 tarefas de código = **5 pts**; 2 itens operacional/governança = **2 pts**, ambos gated no dev).
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
- [ ] **Migration `create_tarefas_recalculo` (31.1) só no banco de TESTE local** — falta `db:migrate` no dev remoto. **Item operacional 32.3 (aprov. do dev).** Severidade: 🟠 (operacional) — Tarefa: 32.3.
- [x] **Governança de docs** — ✅ **RESOLVIDO (32.4, 2026-10-14):** o `CLAUDE.md` do workspace foi reescrito para **escopar por projeto** (`Frequência → Frequencia/docs/`; `Pessoas2 → pessoas2/docs/`; governança `<projeto>/docs/governance/`) — decisão do dev. Não conduz mais o Frequência à árvore do Pessoas2, e preserva o caminho do Pessoas2. Sem commit (arquivo fora do repo `Frequencia`). Severidade original: 🟡.
- [ ] **TOCTOU residual de mês finalizado** (31.3/31.5) — guard "melhor esforço"; documentado honestamente. Severidade: 🟢 — Tarefa: futura (se a finalização for automatizada).
- [ ] **Crash-window do despacho** (31.2) — entre `processada` e o efeito do handler; idempotência mora nos handlers. Severidade: 🟢 — Tarefa: futura (se observado em produção).
- [ ] **Enforcement opt-in da cascata** (ADR-0010 regra 9) — causa-raiz do Bug 🔴1; **candidato opcional 32.O1**, horizonte 33+. Severidade: 🟠 — Tarefa: 32.O1 (não comprometida).
- [ ] **Linha basic8 (Sprints 25/27/28)** — **PAUSADA** por ruling do dev (2026-10-14); pode voltar ao horizonte. Severidade: 🟡 — Tarefa: fora da 32.

## Definição de Pronto

- [x] 32.1 e 32.2 implementadas com Status e Linha do Tempo preenchidos; **32.3 e 32.4 refletem a decisão/aprovação do dev** — 32.4 **executada**; 32.3 **aprovada mas bloqueada por infraestrutura** (host inalcançável), registrada com o caminho de destravamento.
- [ ] Testes: **guard de mês finalizado como predicado antes da escrita** (job + handler), **virada de mês coberta**, **sem divergência handler × job**, **sem `remove_method`**, **sem regressão**; mutation testing dos pontos críticos.
- [ ] `db/schema.rb` **inalterado** por esta sprint (nenhuma migration nova) — só o `db:migrate` de deploy (32.3) sobre a migration **já existente**.
- [ ] **Nenhuma** alteração de `Ability`/cascata/autorização (salvo aprovação explícita do `32.O1`), respeitando o registro global do `CLAUDE.md`.
- [ ] Q16 registrada como **fechada (literal)**; basic8 registrada como **pausada**; Q15 = **1 dev sequencial**.
- [ ] Commit/push **manuais** (pelo dev — `COMMIT_MODE=manual`); nenhum commit/push do agente.

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
