# Iteration 31 — Fila assíncrona de recálculo por evento (PRD §5.2)

> Status: 🟢 **ENCERRADA (CTO, 2026-10-13)** — **5/5 tasks implementadas, testadas, revisadas e COMMITADAS** (Code Reviewer: **0 blockers** em todas). Pilha **LINEAR** `feature/demanda-31-1…` → `…-31-5-vincular-desvincular` (`b417fef` → `97095bc` → `b50e425` → `e13f782` → `dae631f`; +`1fa033e` = fix D2; +`4ddca3b` = docs/ADR-0011). **PUSHADA** (2026-10-14) em `origin` e `gitlab` na branch `chore/limpeza-rubocop-77` @ `ceaac87`; **merge em `integration/sprint-29` segue PENDENTE** (bloqueado por decisão do dev). Baseline final **1214/4239/3F+12E/0 skip** (as 15 defeitos pré-existentes). Consolidação durável: **ADR-0011** (ver §"Encerramento da Sprint 31"). | Período: 2026-10-13 | Goal: materializar o **mecanismo estrutural** de recálculo em lote por evento do PRD §5.2 (gap §9 #3) — uma **fila persistente** de tarefas + um **job de despacho** a cada ~5min + os **handlers dos eventos cujo domínio já existe no Frequência** (`REGISTRO_FREQUENCIA`/`REGISTRO_ESTACAO`, `VINCULAR_DESVINCULAR`, `RECALCULAR_TODOS`), deixando `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` **explicitamente adiados** (models inexistentes). | Rastreabilidade: `Frequencia/PRD-REGRAS-NEGOCIO-PRESENCA.md` **§5.2 (L139-148)** e **§9 item 3 (L201)**; contexto de §5.1 (L133-137); `docs/progress/iteration_30.md` (política incremental de roles — emenda 2026-10-07).

## Contexto e escopo (definido pelo dev)

**Decisão do dev (verbatim):** *"opcao 3"* = **PRD §5.2 — Fila assíncrona de recálculo por evento** (gap §9 #3).

O PRD §5.2 (L139-148) descreve o **mecanismo estrutural** do legado que hoje **não tem equivalente no Frequência**: uma tabela de fila (`presenca_historicotarefa`) alimentada por eventos de mudança, drenada por um job (~5min) que despacha por `TipoEntidade`:

| `TipoEntidade` | Legado recalcula | Domínio existe no Frequência? |
|---|---|---|
| `FERIADO` | mês de todos afetados pela localização do feriado | ❌ **não** (model de feriado não existe) |
| `DIAEXCEPCIONAL` | por órgão ou por frequentador | ❌ **não** |
| `DIREITO` | dias do período do direito | ❌ **não** (afastamento espelhado, sem entidade de direito) |
| `VINCULAR_DESVINCULAR` | dias do período do vínculo | ✅ vínculo/período existe (`RegimeFrequentador`) |
| `REGISTRO_FREQUENCIA` / `REGISTRO_ESTACAO` | o dia (se hoje) ou o mês | ✅ `TimeRecord` / `RegistroEstacaoPonto` existem |
| `RECALCULAR_TODOS` | força recálculo de todos com vínculo ativo | ✅ `User` + `Pessoas::Vinculo.ativos` existem |

### Fatiamento (núcleo implementável AGORA × adiados)

**ENTRA nesta sprint (núcleo §5.2):**
1. A **tabela/fila** de tarefas + o **model** + a **API de enfileiramento idempotente** (31.1).
2. O **job de despacho** `ExecutaTarefasJob` a cada ~5min, que despacha por tipo e **ignora com segurança** os tipos adiados (31.2).
3. Os **handlers dos 3 eventos cujo domínio existe** (31.3, 31.4, 31.5).

**ADIADO — tarefas futuras, NÃO nesta sprint:** `FERIADO`, `DIAEXCEPCIONAL`, `DIREITO`. Os **models desses não existem no Frequência** (brief da 30.3, §9.3). Sob a **política incremental** (ruling 30.3 = A, emendado em 2026-10-07), **cada um nasce na tarefa que implementar a seção do PRD que o consome** — ficam registrados como **dependência futura**, não são inventados aqui. O model da fila (31.1) **declara os 7 tipos** (fidelidade ao PRD), mas **nenhum produtor** é criado para os 3 adiados e o despacho **não os toca**.

### Fronteira explícita — o que esta sprint NÃO é

- **NÃO** é autorização: §5.2 é **infra de recálculo**, não a cascata. **Nenhuma** alteração de `Ability`, `AutorizacaoFrequencia`, `FrequentadoresVisiveis` ou `FrequenciaAutorizacaoCascata`.
- **NÃO** implementa a **paridade** dos jobs da §5.1 (`RecalculoDiario`, `CalculoDiarioAusentes`, `GerarRegistroMensalFrequencia`) — o PRD os cita como jobs de propósito distinto, sem equivalente fiel; aqui só se **reusa** o pipeline de recálculo já existente (`CalculoDiarioService`/`ConsolidacaoMensalService`/`CalcularFrequenciaJob`).
- **NÃO** implementa a **auto-inativação de `APOSENTADO`** (§5.3) — gap separado.
- **NÃO** cria **role** nova: §5.2 **não consome role** (a política incremental não incide aqui).
- **NÃO** implementa subsidiárias do `historico` legado sem consumidor (auditoria/dashboard de fila, retry automático sofisticado).

## Decisão de numeração e rastreabilidade

- Última iteration com arquivo: **30** (`docs/progress/iteration_30.md`). Próximo número livre: **31**.
- **Gap de rastreabilidade declarado:** o `docs/12-plano-implementacao/implementation_plan.md` **não cobre as Sprints 29/30/31** (descreve só as Sprints 24–28, stack basic8). **Não é fonte de escopo desta sprint**; a formalização do épico/Gantt é do **Project Planner** (fora desta sprint) — mesmo débito herdado da 30.
- **`docs/progress/_context.md` está DEFASADO** (registra HEAD `da26ee8`, branch `integration/sprint-29`). O **HEAD real medido nesta árvore é `8bd6755`** (`feat: semeia as 13 roles granulares do legado (guardadas/inertes) + registra a decisao`). **Não atualizar o `_context.md` nesta tarefa** (fora do escopo; o Summarizer é o dono). *[**CORRIGIDO (2026-10-14):** o `_context.md` foi regenerado; o HEAD real hoje é `ceaac87` na branch `chore/limpeza-rubocop-77`, pushada em `origin`/`gitlab`.]*

## Pré-condições

- Sprint 30 com a **infra de recálculo existente intacta** (`CalculoDiarioService`, `ConsolidacaoMensalService`, `CalcularFrequenciaJob` — 17.5) e os jobs de importação (`ImportarServidoresUnidadeJob`, `ImportarGestoresIndividuaisJob`).
- **Sem gate de aprovação de autorização** (esta sprint não toca auth — regra global do `CLAUDE.md` não incide).
- Baseline da suíte a isolar: **1110 runs / 3920 assertions / 1F + 12E / 0 skip** (medido ao fim da 30.9b; as 13 são pré-existentes: 11× Devise `redirect_to` + 1× timezone em `PresencaEndpointsTest` + 1× order-dependent `PessoasSchemaLoaderTest` sob paralelização). Toda medição deve **isolar as pré-existentes** antes de atribuir regressão.
- **Persistência:** o empilhamento da fila assume **Postgres** (o app usa `pg_try_advisory_lock` e `jsonb` — já no schema). Usar `jsonb` para `payload` (padrão já existente em `regimes.expediente`).

## Desenvolvedores

> Perfis **assumidos por padrão** (o dev não informou o quadro desta sprint; ajustar se necessário). O caminho é **sequencial na base** e só abre paralelismo após a 31.2.

| Dev | Perfil | Foco |
|-----|--------|------|
| Dev A | Backend Rails (migrations/models/jobs/service/tests) | **31.1** (fila/model), **31.2** (despacho), **31.3** (handler registro) |
| Dev B | Backend Rails (jobs/services/tests) | **31.4** (`RECALCULAR_TODOS`), **31.5** (`VINCULAR_DESVINCULAR`) — paralelos após a 31.2 |

## Backlog

### Área — Núcleo §5.2: fila assíncrona de recálculo por evento

#### Tarefa 31.1 — Fila de recálculo: tabela, model e enfileiramento idempotente
- User Story: Como sistema, quero uma **fila persistente** de tarefas de recálculo, para que mudanças que afetam a frequência sejam processadas **em lote, de forma assíncrona e idempotente**, sem recálculo síncrono no request.
- Rastreabilidade: PRD **§5.2 (L139-148)** — tabela `presenca_historicotarefa`; **§9 #3 (L201)**
- Estimativa: **3 pontos** | Atribuição: **Dev A** | Dependências: **nenhuma**
- **Escopo (o que ENTRA):**
  - Migration `create_tarefas_recalculo` (port **adaptado** da estrutura de `presenca_historicotarefa` ao domínio do Frequência — **sem** copiar campos sem consumidor).
  - Model `TarefaRecalculo` com: `tipo_entidade` (coluna string + constantes `TIPOS_ENTIDADE`), `status` (`pendente`/`processada`/`erro`), `payload` (`jsonb`, default `{}`), `referencia` (chave estável do evento/alvo → base da idempotência), `processada_em`, timestamps.
  - `TarefaRecalculo::TIPOS_ENTIDADE = %w[FERIADO DIAEXCEPCIONAL DIREITO VINCULAR_DESVINCULAR REGISTRO_FREQUENCIA REGISTRO_ESTACAO RECALCULAR_TODOS]` (os **7** do PRD §5.2) + `TIPOS_ADIADOS = %w[FERIADO DIAEXCEPCIONAL DIREITO]`.
  - API `TarefaRecalculo.enfileirar!(tipo_entidade:, referencia:, payload: {})` — **idempotente**: mesma `referencia` (por tipo) **em estado pendente** ⇒ **1** linha (não duplica); trocar o alvo/referência ⇒ nova linha.
  - Índice/constraint que sustenta a idempotência (ex.: índice único parcial em `[tipo_entidade, referencia] WHERE status = 'pendente'`).
- **Escopo (o que NÃO ENTRA):** o despacho (31.2) e os handlers (31.3–31.5); **nenhum produtor** dos tipos adiados; **nenhum** uso de `Ability`/cascata.
- Critérios de aceite:
  - [ ] Migration cria `tarefas_recalculo` com os campos acima; `db/schema.rb` atualizado; **nenhuma** tabela existente alterada.
  - [ ] `TIPOS_ENTIDADE` cobre **exatamente** os 7 tipos do PRD §5.2; `TIPOS_ADIADOS` isola os 3 sem domínio.
  - [ ] **Idempotência provada:** `enfileirar!` 2× com a mesma `referencia` (mesmo tipo, ainda pendente) = **1 linha**; referências distintas = 2 linhas.
  - [ ] **Nenhum** código de produção cria tarefa de tipo adiado (grep prova).
  - [ ] Sem regressão no baseline (as 13 pré-existentes inalteradas); RuboCop/Zeitwerk OK.
- Status: ✅ **Implementado** (Code Specialist, 2026-10-13) — aguarda Code Reviewer. Migration `20261013120000_create_tarefas_recalculo` (tabela nova + índice UNIQUE **parcial** `[tipo_entidade, referencia] WHERE status='pendente'`) + model `TarefaRecalculo` (`TIPOS_ENTIDADE`=7, `TIPOS_ADIADOS`=3, `enfileirar!` idempotente com corrida tratada) + `test/models/tarefa_recalculo_test.rb` (**20 testes**). Suíte **1157/4056/3F+12E/0 skip** (= baseline 1137/4012 + 20 runs/+44 asserts; 3F+12E pré-existentes). Mutation testing **5/5 mortas**. RuboCop/Zeitwerk OK. Branch `feature/demanda-31-1-fila-recalculo` (base `d50f317`, **não** commitado; `COMMIT_MODE=manual`).
- Riscos: portar o esquema do legado **1:1** traria campos sem consumidor no Frequência (regra global: não inventar/portar sem necessidade) → modelar **só** o necessário, documentando o recorte. Idempotência mal ancorada (referência instável) reintroduz duplicatas → a referência é **testada**.

#### Tarefa 31.2 — Job de despacho `ExecutaTarefasJob` (a cada ~5min)
- User Story: Como sistema, quero um job que roda a cada ~5min e **despacha as tarefas pendentes por tipo**, para que o recálculo em lote aconteça de forma assíncrona, isolada por item e **sem tocar os tipos ainda não implementados**.
- Rastreabilidade: PRD **§5.2 (L140-146)** — "job roda a cada 5min, despacha por `TipoEntidade`"; **§9 #3**
- Estimativa: **3 pontos** | Atribuição: **Dev A** | Dependências: **31.1**
- **Escopo (o que ENTRA):**
  - `ExecutaTarefasJob < ApplicationJob` com **advisory lock próprio** (`LOCK_KEY` **distinto** dos existentes: `837_462_915` `ImportarDadosPessoa`, `592_017_384` `ImportarServidoresUnidade`, `194_773_608` `SincronizarAfastamentos`, `451_926_073` `CalcularFrequencia`) — execução concorrente não processa a mesma tarefa 2×.
  - Entrada em `config/schedule.yml` (**production-only**, padrão do arquivo) com **cron `*/5 * * * *`**.
  - **Registry de handlers por `tipo_entidade`** (contrato simples: um callable por tipo recebe a `TarefaRecalculo` e executa o recálculo). Handlers reais são registrados nas 31.3–31.5; nesta tarefa o registry é exercitado com um **fake injetado**.
  - **Processa só os tipos implementados.** Tarefas de **tipo adiado** (`FERIADO`/`DIAEXCEPCIONAL`/`DIREITO`) ⇒ **no-op silencioso** (skip explícito, **nunca** `raise`).
  - Marcação `pendente → processada`; erro num item ⇒ tarefa marcada `erro`, **job segue** para as demais (`rescue StandardError` por tarefa).
  - **Idempotência:** reprocessar uma fila já drenada = **efeito único**.
- **Escopo (o que NÃO ENTRA):** a lógica de recálculo em si (fica nos handlers 31.3–31.5); retry automático sofisticado/backoff; dashboard/UI da fila.
- Critérios de aceite:
  - [ ] Job agendado a cada 5min **apenas em produção** (`schedule.yml`); **não** registrado em dev/test.
  - [ ] Advisory lock próprio (chave distinta das 4 existentes) — teste de lock.
  - [ ] Despacha por `tipo_entidade` ao handler do registry (teste com **handler fake injetado** prova o roteamento sem depender dos handlers reais).
  - [ ] **Tipos adiados NÃO são despachados:** tarefa de tipo adiado na fila ⇒ o job roda, **não chama handler algum** para ela, **não quebra** e a marca como processada/skip (decisão registrada no código).
  - [ ] Erro num item não derruba o lote (tarefa → `erro`; as demais seguem).
  - [ ] **Idempotência:** rodar 2× sobre a mesma fila = efeito único.
  - [ ] Testes usam **save/restore do método original — NUNCA `remove_method`** (`test/support/class_method_stub_helper.rb`).
  - [ ] Sem regressão no baseline; RuboCop/Zeitwerk OK.
- Status: ✅ **Implementado** (Code Specialist, 2026-10-13) — aguarda Code Reviewer. `ExecutaTarefasJob < ApplicationJob` com advisory lock PRÓPRIO `LOCK_KEY = 728_104_536` (distinto das 5 chaves já existentes: `837_462_915`/`592_017_384`/`471_209_336`/`194_773_608`/`451_926_073`) + registry mínimo por `tipo_entidade` (mapa `tipo → callable`, vazio de fábrica, populado via `registrar_handler` nas 31.3–31.5; exercitado com handler FAKE nos testes) + entrada `executa_tarefas` em `config/schedule.yml` (production-only, cron `*/5 * * * *`). Processa `TarefaRecalculo.pendentes` via `find_each`; tipos adiados ⇒ no-op silencioso (guard em `TIPOS_ADIADOS` **antes** de consultar o registry, marca `processada`); tipo sem handler ⇒ skip explícito (`processada`); erro por item ⇒ `erro` + job segue (`rescue StandardError` por tarefa). `test/jobs/executa_tarefas_job_test.rb` (**7 testes**): roteamento por tipo, adiado não despachado, sem-handler skip, erro isolado no lote, idempotência (2× = efeito único), lock concorrente, unicidade da `LOCK_KEY`. Suíte **1164/4079/3F+12E/0 skip** (= baseline 1157/4056 + 7 runs/+23 asserts; 3F+12E pré-existentes). Mutation testing **6/6 mortas**. RuboCop/Zeitwerk OK. Branch `feature/demanda-31-2-executa-tarefas-job` (base `b417fef` = HEAD da 31.1, **não** commitado; `COMMIT_MODE=manual`).
- Riscos: padrão de **registry** é novo no app → mantido o contrato mínimo (sem framework de plugins). Concorrência: o advisory lock + a marcação de status devem cobrir a corrida entre workers (documentar a escolha; concorrência fina é débito se necessário, no padrão S3 da 30.9b). **Débito registrado:** tipo NÃO-adiado sem handler é marcado `processada` (skip) e não retenta — nesta task nenhum produtor cria tais tipos (os produtores nascem nas 31.3–31.5 junto dos handlers), então não há tarefa órfã; se um handler falhar ao carregar no futuro, a tarefa seria drenada sem efeito (retry sofisticado está fora do escopo).
- Review: ✅ **Aprovado** (Code Reviewer, 2026-10-13) — **0 Blockers 🔴 | 3 Débitos 🟠 | 3 Sugestões 🟡 | 5 Elogios 🟢**. Evidência reproduzida: `test/jobs/executa_tarefas_job_test.rb` **7/23/0F/0E**; `test/jobs/ + test/models/tarefa_recalculo_test.rb` **62/149/0F/0E**; RuboCop 0; Zeitwerk OK. LOCK_KEY `728_104_536` varrida e única (6 chaves no repo). Ressalvas não-bloqueantes: 🟠-D2 `limpar_handlers` apaga o registry global (risco latente para 31.3–31.5), 🟠-D3 skip sem handler é silencioso, 🟡-S3 higiene de escopo no working tree (cascata em `development.rb` + `credentials.yml.enc`). Relatório completo: `docs/quality/review_report_31_2.md`.
- Correção pós-review (Code Specialist, 2026-10-13): **🟠-D2 e 🟠-D3 fechados**. D2: `limpar_handlers` **removido** da API de produção do job (ficam só `handlers`/`registrar_handler`); o teste passou a fazer **save/restore não-destrutivo** (`@handlers_backup = handlers.dup` no `setup` + `handlers.clear`; `handlers.replace(@handlers_backup)` no `teardown`) — handlers reais de outros arquivos do mesmo worker **não** se perdem. D3: skip de tipo **não-adiado** sem handler agora emite `Rails.logger.warn` (tipo + id); comportamento inalterado (segue `processada`/skip, sem `raise`); tipos adiados seguem sem warn. +3 testes (warn emitido; adiado sem warn; sobrevivência de handler de outro arquivo). Evidência: `test/jobs/executa_tarefas_job_test.rb` **10/32/0F/0E**; `test/jobs/ + test/models/tarefa_recalculo_test.rb` **65/158/0F/0E**; RuboCop 0; mutation **2/2 mortas** (remover o warn ⇒ teste do warn falha; teardown destrutivo ⇒ teste de sobrevivência falha). Sem commit (`COMMIT_MODE=manual`). **🟠-D1** (crash-window) permanece **débito documentado** (idempotência mora nos handlers das 31.3–31.5).

#### Tarefa 31.3 — Handler `REGISTRO_FREQUENCIA` / `REGISTRO_ESTACAO` (recálculo por dia ou mês)
- User Story: Como frequentador, quero que ao **criar/alterar um registro de ponto** o **dia** (se for hoje) ou o **mês** seja recalculado, para que o cálculo reflita a marcação **sem esperar o job noturno**.
- Rastreabilidade: PRD **§5.2 (L145)** — "`REGISTRO_FREQUENCIA`/`REGISTRO_ESTACAO` → recalcula o dia (se hoje) ou o mês"; `TimeRecord`, `RegistroEstacaoPonto`, `RegistroManualFrequenciaService`; `CalculoDiarioService#calcular`, `ConsolidacaoMensalService#consolidar`
- Estimativa: **3 pontos** | Atribuição: **Dev A** | Dependências: **31.2**
- **Escopo (o que ENTRA):**
  - Handler de `REGISTRO_FREQUENCIA` e `REGISTRO_ESTACAO`: dado o alvo (`user`/CPF + data) no payload, recalcula **o dia** se a data é **hoje**, senão **o mês** — reusando `CalculoDiarioService.calcular` + `ConsolidacaoMensalService.consolidar` (já idempotentes).
  - **Produtor (enfileiramento):** no ponto de **criação do registro** — `RegistroManualFrequenciaService` (batida manual) e o ponto de criação de `TimeRecord` pelo **processamento de sincronização de estação** — enfileira **1** tarefa com `referencia` estável (`tipo + user_id + data`).
  - `ConsolidacaoMensalService::MesFinalizadoError` tratado como no `CalcularFrequenciaJob` (mês fechado ⇒ **skip silencioso**, não é erro).
- **Escopo (o que NÃO ENTRA):** alterar a filosofia do `CalcularFrequenciaJob` (últimos 3 dias + mês corrente — decisão de design já tomada, **não reabrir**); reprocessar tipos adiados.
- Critérios de aceite:
  - [ ] Handler recalcula **o dia** quando a data é hoje e **o mês** quando é passada (teste dos **dois** ramos).
  - [ ] `MesFinalizadoError` ⇒ skip silencioso (não marca `erro`).
  - [ ] **Produtor idempotente:** 2 eventos do mesmo par (user, data) = **1 efeito** de recálculo (referência estável).
  - [ ] **Sem regressão no recálculo existente:** a suíte de `CalcularFrequenciaJob`/`ConsolidacaoMensalService` permanece verde.
  - [ ] Testes com stubs via `class_method_stub_helper` (save/restore; **nunca `remove_method`**).
  - [ ] Sem regressão no baseline; RuboCop/Zeitwerk OK.
- Status: ✅ **Implementado** (Code Specialist, 2026-10-13) — aguarda Code Reviewer. Handler ÚNICO `RegistroRecalculoHandler` (`app/services/registro_recalculo_handler.rb`) para `REGISTRO_FREQUENCIA`+`REGISTRO_ESTACAO`: lê `user_id`/`data` do `payload`; data = HOJE ⇒ `CalculoDiarioService.calcular` (só o dia); data passada ⇒ recalcula o dia afetado **e** `ConsolidacaoMensalService.consolidar` do mês (ordem dia→mês: a consolidação só soma `CalculoDiario` existentes); `MesFinalizadoError` ⇒ skip silencioso (mesmo tratamento do `CalcularFrequenciaJob`); alvo/payload inválido ⇒ skip. **Registro no boot** por `config/initializers/recalculo_handlers.rb` via `to_prepare` (explícito + idempotente, sem autoload lazy). **Produtores (aditivos):** `RegistroManualFrequenciaService` (só `batida_manual`, dentro da **mesma transação**) e `Presenca::SincronizarRegistrosPontoController#create` (dentro da transação do lote), ambos `TarefaRecalculo.enfileirar!` com `referencia` estável `"#{tipo}:#{user_id}:#{data}"`. Testes: `test/services/registro_recalculo_handler_test.rb` (**7**), +5 em `test/services/registro_manual_frequencia_service_test.rb`, +3 em `test/integration/presenca_endpoints_test.rb` (**15 novos**). Suíte **1182/4128/3F+12E/0 skip** (= baseline HEAD 1167 + 15; 3F+12E pré-existentes). Mutation **6/6 mortas** (ramo dia; ramo mês; rescue de `MesFinalizadoError`; idempotência do produtor manual `enfileirar!`→`create!`; remoção do enfileiramento manual; referência instável no produtor de estação). RuboCop 0 / Zeitwerk OK. Branch `feature/demanda-31-3-handler-registro` (base `97095bc` = HEAD da 31.2, **não** commitado; `COMMIT_MODE=manual`).
- Correção pós-review (Code Specialist, 2026-10-13): **2 bugs reais (A e B) fechados** no `RegistroRecalculoHandler`. **Bug A** — mês FINALIZADO era driblado: o handler recalculava o dia (`CalculoDiarioService.calcular`, que faz `save!` sem guarda de finalização) **antes** de `consolidar` levantar `MesFinalizadoError` (erro engolido depois), reescrevendo o `CalculoDiario` de um mês fechado e deixando o `RegistroMensalFrequencia` desatualizado — **burla da trava 17.2**. Correção: guard NOVO `ConsolidacaoMensalService.finalizado?(user, ano, mes)` (**predicado público MÍNIMO**, reusa a MESMA condição de `consolidar` — registro persistido && `finalizado?`; **não** altera o comportamento de `consolidar`) avaliado **antes de qualquer recálculo**: mês finalizado ⇒ **skip silencioso** (não recalcula o dia **nem** o mês) — comentário registra que a trava vale para o **DIA também** (o retificador é o caminho para mês fechado, decisão 17.2). O `rescue MesFinalizadoError` foi mantido como **salvaguarda de corrida**. **Bug B** — data **FUTURA** caía no ramo "passado ⇒ mês": guard `return if data > Date.current` ⇒ skip silencioso (fora de escopo). Testes: `test/services/registro_recalculo_handler_test.rb` **10/32/0F/0E** (+3: mês finalizado real ⇒ `CalculoDiario` do dia **e** `RegistroMensalFrequencia` assertados **inalterados** sem stub; mês finalizado com data de HOJE ⇒ `calcular` **não** chamado; futuro real ⇒ zero criação de `CalculoDiario`/`RegistroMensalFrequencia`). Regressão do recálculo **64/174/0F/0E** (`calculo_diario_service*` + `consolidacao_mensal_service*` + `calcular_frequencia_job` + `registro_manual_frequencia_service`). Mutation **2/2 mortas** (guard de finalização neutralizado ⇒ os 2 testes de finalizado falham e o dia vira 0; guard de futuro neutralizado ⇒ futuro consolida 1 mês). RuboCop 0. Sem commit (`COMMIT_MODE=manual`).
- Review: ✅ **Aprovado** (Code Reviewer, 2026-10-13) — **0 Blockers 🔴 | 2 Débitos 🟠 | 2 Sugestões 🟡 | 5 Elogios 🟢**. Correções A/B verificadas: `ConsolidacaoMensalService.finalizado?` reusa a MESMA condição de `consolidar` (sem duplicar regra; `consolidar` inalterado; nenhum outro chamador afetado); guard de futuro barra o ramo do `else`. Evidência: `registro_recalculo_handler_test.rb` + `registro_manual_frequencia_service_test.rb` **19/67/0F/0E**; job+model+regressão **81/207/0F/0E**; `presenca_endpoints_test.rb` **45/152/1F** (a falha é a de TZ **pré-existente** em `:187`, fora do diff); Zeitwerk OK; RuboCop 0. Ressalvas não-bloqueantes: 🟠-D1 janela de corrida residual do guard `finalizado?` (o `rescue` só evita propagação — corrigir o comentário que superestima a proteção); 🟠-D2 `enfileirar!` não é seguro in-transaction no caminho `RecordNotUnique` (herdado do 31.1, exposto pelos produtores); 🟡-S1 higiene de escopo (`development.rb` + `credentials.yml.enc` fora da 31.3). Relatório completo: `docs/quality/review_report_31_3.md`.
- Correção pós-review (Code Specialist, 2026-10-13): **🟠-D1 e 🟠-D2 fechados**. **D1 (só comentário, comportamento inalterado)** — o comentário do `rescue MesFinalizadoError` superestimava a proteção ("não reescreve nada de forma inconsistente"); agora descreve HONESTAMENTE a janela residual (TOCTOU): o `rescue` evita APENAS a **propagação** da exceção, **não** a reescrita do dia — se OUTRO processo finalizar o mês entre o guard `finalizado?` e o `consolidar`, o ramo "passado" já reescreveu o `CalculoDiario` do dia e só então o `consolidar` levanta (engolido). Probabilidade desprezível (finalização manual, janela ínfima); documentado como **débito conhecido, não coberto**. O bloco do guard em `recalcular` ganhou nota equivalente ("melhor esforço"). **D2** — `TarefaRecalculo.enfileirar!` agora isola o `INSERT` num **SAVEPOINT** (`ActiveRecord::Base.transaction(requires_new: true)`), mantendo os `rescue ActiveRecord::RecordNotUnique`/`RecordInvalid` **fora** do bloco. Motivo: os produtores chamam `enfileirar!` DENTRO da transação do `TimeRecord`; no caminho de corrida o `unique_violation` do PG **abortava** a transação do caller e o `pendentes.find_by!` do rescue levantava `PG::InFailedSqlTransaction` (não capturado) → perda do `TimeRecord`. O savepoint confina a violação (`ROLLBACK TO SAVEPOINT` limpa o estado abortado) e a transação do caller segue saudável. Comportamento externo inalterado (idempotência preservada; fora de transação, `requires_new` só abre transação normal). Testes: +1 em `test/models/tarefa_recalculo_test.rb` (**21/48/0F/0E**) que reproduz o estado abortado do PG (linha concorrente PENDENTE pré-existente + SELECT inicial defasado + INSERT real com violação do índice único via `save!(validate: false)`, sem stub de `remove_method` — usa `com_metodos_de_classe_stubados`) e prova que a **transação externa continua utilizável** (query subsequente DENTRO da mesma transação) além de (a) não subir `RecordNotUnique`/`PG::InFailedSqlTransaction` e (b) devolver a linha existente; os 2 testes de corrida pré-existentes foram adaptados ao savepoint (mesmo padrão de janela de corrida). **Mutation** — neutralizar o savepoint (`requires_new: false`) faz o novo teste falhar com exatamente `PG::InFailedSqlTransaction` no `rescue` (reprodução confirmada e revertida). Regressão: `tarefa_recalculo + registro_recalculo_handler + registro_manual_frequencia_service + presenca_endpoints + executa_tarefas_job` **95/299/1F/0E** (a única falha é a TZ **pré-existente** em `presenca_endpoints_test.rb:187`, fora do diff). RuboCop 0 / Zeitwerk OK. Sem commit (`COMMIT_MODE=manual`).
- Riscos: enfileirar **dentro** × **fora** da transação de criação do `TimeRecord` (decisão: enfileirar na **mesma transação** garante que um rollback não deixa tarefa órfã — documentar no código). Idempotência do produtor depende da estabilidade da referência.

#### Tarefa 31.4 — Handler `RECALCULAR_TODOS` (todos com vínculo ativo)
- User Story: Como administrador, quero **forçar o recálculo de todos os frequentadores com vínculo ativo**, para corrigir em lote depois de uma mudança global.
- Rastreabilidade: PRD **§5.2 (L146)** — "`RECALCULAR_TODOS` → força recálculo de todos os frequentadores com vínculo ativo"; `CalcularFrequenciaJob` (17.5); `Pessoas::Vinculo.ativos`
- Estimativa: **2 pontos** | Atribuição: **Dev B** | Dependências: **31.2** (paralela à 31.3 após a 31.2)
- **Escopo (o que ENTRA):**
  - Handler de `RECALCULAR_TODOS`: processa os frequentadores **com vínculo ativo** e roda o pipeline de recálculo por usuário (reuso do `CalculoDiarioService.calcular` + `ConsolidacaoMensalService.consolidar`, na mesma filosofia do `CalcularFrequenciaJob`: últimos 3 dias + mês corrente).
  - **Sem JOIN cross-database:** resolver os CPFs de vínculo ativo no Pessoas (`Pessoas::Vinculo.ativos`) e então selecionar os `User` por CPF (o `PessoasRecord` é readonly e o banco é distinto — **não** inventar join).
  - Erro por usuário **isolado** (`rescue StandardError` por usuário, sem derrubar o lote).
- **Escopo (o que NÃO ENTRA):** os jobs autônomos da §5.1 (`RecalculoDiario`, `CalculoDiarioAusentes`); o agendamento diário do `CalcularFrequenciaJob` (permanece como está).
- Critérios de aceite:
  - [ ] Handler recobre os frequentadores com **vínculo ativo**; usuário sem vínculo ativo **não** é tocado.
  - [ ] **Idempotente** (o pipeline interno usa `find_or_initialize_by`); rodar 2× = mesma saída.
  - [ ] Erro por usuário não derruba o lote (logado por usuário, mesmo padrão dos jobs existentes).
  - [ ] Teste com o conjunto de usuários/CPFs **injetado em memória** (sem tocar o Pessoas); **save/restore do método original — NUNCA `remove_method`**.
  - [ ] Sem regressão no baseline; RuboCop/Zeitwerk OK.
- Status: ✅ **Implementado** (Code Specialist, 2026-10-13) — aguarda Code Reviewer. Handler `RecalcularTodosHandler` (`app/services/recalcular_todos_handler.rb`) registrado para `RECALCULAR_TODOS` no boot por `config/initializers/recalculo_handlers.rb` (`to_prepare`, idempotente, mesmo padrão da 31.3). **Eixo "vínculo ativo" (não inventado):** resolvido com `Pessoas::Vinculo.ativos.joins(:pessoa).distinct.pluck("pessoas.cpf").compact` (o `ativos` = `vinculos_estados.nome == "em_exercicio"` + `fim` nulo/futuro; CONFIRMADO por grep `app/` = `ativos` em `pessoas/vinculo.rb` L22/106/143/171 e consumido por `frequentadores_ativos`/`FrequentadoresVisiveis`/`AutorizacaoFrequencia`), **sem JOIN cross-database** — depois `User.where(cpf: cpfs)` (o `PessoasRecord` é readonly, banco distinto). **Guard de lista vazia** (`return if cpfs.empty?`) para não varrer a base. **Pipeline por usuário = MIRROR do `CalcularFrequenciaJob`** (últimos 3 dias `CalculoDiarioService.calcular` + mês corrente `ConsolidacaoMensalService.consolidar`), sem refatorar o job. **Erro por usuário isolado** (`rescue StandardError` por usuário, `Rails.logger.error` por CPF, lote segue); `MesFinalizadoError` ⇒ skip silencioso. **NÃO há produtor** de `RECALCULAR_TODOS` nesta task (não estava no escopo): o tipo é enfileirado manualmente/console (`TarefaRecalculo.enfileirar!(tipo_entidade: "RECALCULAR_TODOS", ...)`). Testes: `test/services/recalcular_todos_handler_test.rb` (**7**) — só usuários com CPF de vínculo ativo; usuário sem vínculo não tocado; idempotência (2× = mesma saída); erro isolado + log; `MesFinalizadoError` skip silencioso; CPF de vínculo ativo sem `User` ignorado; lista vazia = nada recalculado; registry no boot. Suíte **1193/4172/3F+12E/0 skip** (= baseline REAL medido 1186/4151 + 7 runs/+21 asserts; os **mesmos** 3F+12E pré-existentes). Mutation **3/3 mortas** (filtro de vínculo ativo `User.where(cpf:cpfs)`→`User.where.not(cpf:nil)` ⇒ 3 falhas; remover `rescue MesFinalizadoError` ⇒ 1 falha; remover `rescue StandardError` ⇒ 1 erro). RuboCop **0** / Zeitwerk OK. Branch `feature/demanda-31-4-recalcular-todos` (base `1fa033e` = HEAD da 31.3, **não** commitado; `COMMIT_MODE=manual`).
- **Decisão de lock/concorrência (documentada no código):** o handler roda DENTRO do drain do `ExecutaTarefasJob`, que JÁ segura o advisory lock próprio `728_104_536`. Por isso **NÃO** pegamos um segundo lock — em especial, **NÃO** reusamos o `CalcularFrequenciaJob::LOCK_KEY` (`451_926_073`): sob concorrência um `pg_try_advisory_lock(451_926_073)` retornaria `false`, o handler sairia sem efeito e o job marcaria a tarefa `processada` (tarefa **drenada sem efeito, silenciosamente**). A sobreposição com o job noturno é **convergente** (ambos idempotentes sobre os mesmos dados) → o pior caso é trabalho duplicado, não dado incorreto. Diferente da recomendação "herdar o advisory lock": deliberadamente **não** herdamos (justificado no comentário do handler).
- Riscos: volume (executar em lote pode ser caro) → mitigado pelo **escopo temporal do pipeline** (3 dias + mês corrente, não histórico completo) + idempotência; eixo "vínculo ativo" (`Pessoas::Vinculo.ativos`) × `User.status` — **usado o MESMO eixo da cascata/`frequentadores_ativos`**, não inventado outro (o filtro de `User.status` NÃO é aplicado aqui: o PRD diz "vínculo ativo" do frequentador, não status do `User` local).
- Review: ✅ **Aprovado** (Code Reviewer, 2026-10-13) — **0 Blockers 🔴 | 0 Sugestões 🟡 | 2 Débitos 🟠 | 4 Elogios 🟢**. Eixo "vínculo ativo" confirmado FIEL a `Pessoas::Vinculo.ativos` (mesmo scope de `frequentadores_ativos`/`cpfs_por_nome`/`cpfs_por_orgao`/`FrequentadoresVisiveis`), sem JOIN cross-database; `User.status` não filtrado está CORRETO per PRD. Decisão de lock CONFIRMADA e validada contra os índices UNIQUE (`calculo_diarios[user_id,data]`, `registro_mensal_frequencias[user_id,ano,mes]`): sobreposição não corrompe (pior caso = `RecordNotUnique` logado, convergente). Evidência: `recalcular_todos_handler_test.rb` **7/21/0F/0E**; +31.3/job **27/85/0F/0E** (sem contaminação de stub); RuboCop **0**; Zeitwerk OK. Ressalvas não-bloqueantes: 🟠-D1 `cpfs_com_vinculo_ativo` (query ao Pessoas) fora de `rescue` ⇒ outage transitório marca a tarefa `erro` sem retry (divergente do fail-closed de `FrequentadoresVisiveis`); 🟠-D2 sem guard `finalizado?` prévio (herdado por design do `CalcularFrequenciaJob`; janela de limite de mês, impacto desprezível). Relatório completo: `docs/quality/review_report_31_4.md`.
- **Débitos registrados (pós-review, não bloqueantes — decisão do dev, 2026-10-13):** 🟠-**D1** `cpfs_com_vinculo_ativo` (query ao Pessoas) está FORA do `rescue` ⇒ um outage transitório do Pessoas marca a tarefa `erro`, sem retry automático — **mantido deliberadamente**: falha visível é preferível a um skip silencioso num gatilho global. 🟠-**D2** ausência de guard `finalizado?` por dia (janela de limite de mês, onde "últimos 3 dias" passa por dias de mês já fechado) é **herdada do `CalcularFrequenciaJob` (17.5)**, que já recalcula os 3 últimos dias sem esse guard toda noite — **não corrigida nesta task**: corrigir só o handler removeria o comportamento do handler e criaria **divergência handler × job**; se for para tratar, é **tarefa própria sobre a 17.5** (guard por dia lá, e o handler passa a espelhar).

#### Tarefa 31.5 — Handler `VINCULAR_DESVINCULAR` (dias do período do vínculo)
- User Story: Como administrador, quero que ao **vincular/desvincular** um frequentador (regime/período) os **dias do período** sejam recalculados, para que o cálculo reflita a mudança de vínculo retroativamente.
- Rastreabilidade: PRD **§5.2 (L144)** — "`VINCULAR_DESVINCULAR` → recalcula os dias do período"; `RegimeFrequentador` (`momento_inicial`/`momento_final`)
- Estimativa: **3 pontos** | Atribuição: **Dev B** | Dependências: **31.2** (paralela à 31.3 após a 31.2)
- **Escopo (o que ENTRA):**
  - Handler de `VINCULAR_DESVINCULAR`: recalcula **os dias do período do vínculo** afetado (por dia, via `CalculoDiarioService.calcular`; mês consolidado).
  - **Produtor (enfileiramento):** no ponto de **criação/encerramento do vínculo** (`RegimeFrequentador` — `momento_inicial`/`momento_final`) enfileira **1** tarefa com `referencia` estável (`tipo + user_id + período`).
- **✅ Q14 RESOLVIDA (dev, 2026-10-13):** a entidade que emite `VINCULAR_DESVINCULAR` é **`RegimeFrequentador`** (o vínculo de regime a frequentador, com **período** — `momento_inicial`/`momento_final`). **Produtor = CALLBACK `after_commit` no próprio model** — é o ÚNICO locus de ciclo-de-vida do vínculo que existe, porque a app **NUNCA escreve** `regime_frequentadores` (varredura confirmou: nenhum controller/rota/service/job/rake/seed — só `db/migrate` cria a tabela; as únicas referências são de LEITURA em `calculo_diario_service.rb:40` e `consolidacao_mensal_service.rb:220`). Não há ponto de CRUD de vínculo onde pendurar o enfileiramento; quando surgir, o callback já o cobre.
- **Escopo (o que NÃO ENTRA):** `DIREITO` (adiado — o legado o agrupa com `VINCULAR_DESVINCULAR`, mas a entidade de direito **não existe** aqui).
- Critérios de aceite:
  - [x] Handler recalcula os **dias do período** do vínculo (teste de período com dias conhecidos).
  - [x] **Idempotente:** rodar 2× = mesma saída; dias **fora** do período **não** são tocados.
  - [x] **Produtor idempotente:** 2 eventos do mesmo período = **1 efeito**.
  - [x] Teste com o período **injetado em memória**; **save/restore do método original — NUNCA `remove_method`**.
  - [x] Sem regressão no baseline; RuboCop/Zeitwerk OK.
- Status: ✅ **Implementado, ✅ Aprovado** (Code Specialist 2026-10-13; Code Reviewer 2026-10-13). Handler `VincularDesvincularHandler` (`app/services/vincular_desvincular_handler.rb`) registrado para `VINCULAR_DESVINCULAR` no boot por `config/initializers/recalculo_handlers.rb` (`to_prepare`, idempotente, mesmo padrão da 31.3/31.4). **Alvo:** `user_id` + período do `payload` (`momento_inicial`, `momento_final`). **Recalcula os DIAS** (`CalculoDiarioService.calcular`) e **consolida 1× por (ano,mês) distinto** do período (`ConsolidacaoMensalService.consolidar`), DEPOIS de recalcular os dias daquele mês (a ordem da 31.3 importa). **Período ABERTO** (`momento_final` nil/ausente) ⇒ fim = `Date.current`. **NUNCA dia futuro:** fim recortado em `Date.current` (lição/bug B da 31.3). **Mês finalizado (trava 17.2):** guard prévio `ConsolidacaoMensalService.finalizado?` ⇒ skip silencioso do mês (não reescreve dia nem consolida), com `rescue MesFinalizadoError` como salvaguarda de corrida. **Payload inválido** (`user` inexistente, `momento_inicial` ausente/não parseável, `momento_final` PRESENTE mas não parseável, período invertido/futuro) ⇒ skip silencioso. **Grão do isolamento de erro:** POR DIA no recálculo (`rescue StandardError` + log, os demais dias seguem) e POR MÊS na consolidação (`rescue StandardError` + log, os demais meses seguem). **PRODUTOR:** `after_commit` em `create`/`update`/`destroy` em `app/models/regime_frequentador.rb` — `create`/`destroy` sempre enfileiram; `update` só enfileira se `momento_inicial`/`momento_final` mudou (via `previous_changes`, não o `changed?` já limpo). `referencia` ESTÁVEL por período = `"VINCULAR_DESVINCULAR:#{user_id}:#{momento_inicial.to_date}:#{momento_final&.to_date}"` ⇒ 2 eventos do mesmo período = 1 pendente. `after_commit` fica FORA da transação (diferente da 31.3): um rollback não deixa tarefa órfã. Enfileiramento protegido por `rescue StandardError` + `Rails.logger.error` — uma falha aqui NUNCA derruba a persistência do vínculo (provado por teste em create/update/destroy). Testes: `test/services/vincular_desvincular_handler_test.rb` (**12**) + `test/models/regime_frequentador_produtor_test.rb` (**9**) = **21/67/0F/0E**. Suíte **1214/4239/3F+12E/0 skip** (= baseline 31.4 1193/4172 + 21 runs/+67 asserts; os MESMOS 3F+12E pré-existentes). Mutation **5/5 mortas** (recorte em `Date.current` ⇒ 2F; guard de mês finalizado ⇒ 1F; dedup por mês `group_by` ⇒ 3F; referência estável ⇒ 5F; `rescue` do callback estreitado ⇒ 3E). RuboCop **0** / Zeitwerk OK. Branch `feature/demanda-31-5-vincular-desvincular` (base `e13f782` = HEAD da 31.4, **não** commitado; `COMMIT_MODE=manual`).
- **Decisão de volume (período longo ⇒ volume, risco registrado):** a consolidação roda **1× por (ano,mês) distinto** (nunca 1× por dia) — corte principal. Os **dias em si SÃO todos recalculados** (o feature é justamente o recálculo RETROATIVO do período; truncar dias produziria dados errados e o enunciado proíbe truncar em silêncio). Mitigações: idempotência (rerodar é seguro), isolamento por dia/mês, e `warn` de observabilidade (`PERIODO_ALERTA_DIAS = 366`) para períodos anormalmente longos — **sem truncamento**.
- **Decisão `after_commit` nos testes:** confirmado EMPIRICAMENTE que o `after_commit` dispara nos testes (harness transacional padrão do Rails 7+/8) — os 9 testes do produtor provam o enfileiramento real; **NÃO** foi necessário desligar `use_transactional_tests`.
- Riscos: **mapeamento do evento (Q14)** — o maior risco desta tarefa; resolvido como **default + confirmação do dev**, nunca por suposição silenciosa. Período longo ⇒ muitos dias por tarefa → limitar/avaliar na implementação.
- **📋 Relatório de Revisão (Code Reviewer, 2026-10-13):** ✅ **Aprovado** — **0 Blockers 🔴 | 2 Sugestões 🟡 | 2 Débitos 🟠 | 5 Elogios 🟢**. Evidência executada: novos testes **21/67/0F/0E**; suíte completa **1214/4239/3F+12E** (bate o baseline; as 3F+12E são pré-existentes e não tocam 31.5); suites afetadas pelo callback **139/315/0F/0E**; Zeitwerk **OK**; RuboCop **0**. Detalhes em `docs/quality/review_report_31_5.md`. Bloqueante para commit: **NÃO**. Sugestões opcionais: 🟡-S1 (`rescue MesFinalizadoError` morto no nível de `call`); 🟡-S2 (`momento_final` `""` cai em "aberto"). Débitos não-bloqueantes: 🟠-D1 (encerrar/encolher o período não recalcula a "cauda" após o novo `momento_final` — fiel ao literal de Q14; candidato a follow-up); 🟠-D2 (TOCTOU residual de mês finalizado, herdado da 31.3, já documentado no código).
- **Correções pós-review (dev, 2026-10-13):** 🟡-**S1 RESOLVIDA** — o `rescue ConsolidacaoMensalService::MesFinalizadoError` no nível de `call` foi **removido** (era código morto: o tratamento vive no `consolidar` privado, único ponto onde o erro pode nascer; nem `finalizado?` nem `CalculoDiarioService.calcular` o levantam) — mantido apenas o comentário que aponta o lugar certo. Testes seguem **21/67/0F/0E**; RuboCop 0. 🟠-**D1 registrada como Q16** (pergunta aberta ao dev) — **não** alterada nesta task. 🟡-S2 (`momento_final` `""` cai em "aberto") mantida como está: o produtor nunca emite `""`. 🟠-D2 permanece débito conhecido (TOCTOU).

## Requisitos de teste (transversais — valem como critério de aceite de todas as tarefas)

1. **Idempotência da fila:** enfileirar **2×** a mesma referência **não duplica efeito** (1 linha pendente; 1 recálculo). Provar em 31.1 (enfileiramento) e em cada produtor (31.3/31.5).
2. **Despacho por tipo sem tocar os adiados:** o `ExecutaTarefasJob` (31.2) processa os tipos implementados e **não chama handler** para `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` — nem quebra com eles na fila.
3. **NUNCA `remove_method`:** todo stub de método de classe/produção usa **`test/support/class_method_stub_helper.rb`** (capturar `UnboundMethod` real e **reinstalar no `ensure`**). Lição da Sprint 29 (o `remove_method` mata o método real para o **processo** inteiro).
4. **Sem regressão no recálculo existente:** suíte de `CalculoDiarioService`, `ConsolidacaoMensalService`, `CalcularFrequenciaJob` e dos jobs de importação permanece verde; isolamento das 13 pré-existentes.
5. **Nada de autorização:** nenhum teste/arquivo toca `Ability`/`AutorizacaoFrequencia`/`FrequentadoresVisiveis`/`FrequenciaAutorizacaoCascata`.
6. **Mutation testing** (padrão do projeto): desligar a idempotência da fila → teste falha; remover o skip dos tipos adiados → teste do adiado falha; remover um ramo dia/mês do handler de registro → teste correspondente falha.

## Caminho Crítico

**31.1 (3) → 31.2 (3) → { 31.3 (3) ∥ 31.4 (2) ∥ 31.5 (3) }** — **9 pontos** de caminho crítico (31.1 + 31.2 + o handler mais longo). Após a 31.2, as três tarefas de handler são **independentes** e paralelizáveis (Dev A na 31.3; Dev B na 31.4/31.5).

```
31.1 ──> 31.2 ──┬──> 31.3  (Dev A)
                 ├──> 31.4  (Dev B)   [paralelas após 31.2]
                 └──> 31.5  (Dev B)
```

## Riscos

- **Mapeamento do evento `VINCULAR_DESVINCULAR` (31.5).** Qual entidade emite o evento no legado × no Frequência é **ambíguo** (ver Q14). Mitigação: default `RegimeFrequentador` **confirmado com o dev antes da implementação** — **não** inventar mapping.
- **Fidelidade do esquema da fila (31.1).** Portar `presenca_historicotarefa` 1:1 traria campos sem consumidor (regra global: não inventar/portar sem necessidade). Mitigação: recorte documentado, só o necessário ao Frequência.
- **Concorrência do despacho (31.2).** Dois workers drenando a mesma fila ⇒ duplo processamento. Mitigação: advisory lock próprio + marcação de status; concorrência fina documentada (débito aceito se necessário, no padrão S3 da 30.9b).
- **Acoplamento produtor × transação (31.3/31.5).** Enfileirar dentro/fora da transação do evento. Mitigação: enfileirar na **mesma transação** (rollback não deixa tarefa órfã), documentado e testado.
- **Volume do `RECALCULAR_TODOS` (31.4).** Recálculo de todos com vínculo ativo pode ser caro. Mitigação: reuso do pipeline idempotente + lock/escopo temporal decidido na implementação.
- **`_context.md` defasado / `implementation_plan.md` sem as Sprints 29–31.** Não é fonte de escopo; documentado como débito de rastreabilidade (herdado da 30).
- **Baseline da suíte.** Toda medição deve isolar as **13 pré-existentes** antes de atribuir regressão.

## Débitos Técnicos

- [ ] **Sprints 29/30/31 ausentes do `implementation_plan.md`** (o plano descreve só 24–28) — Severidade: 🟡 — Tarefa: (chore de planejamento / Project Planner), herdado da 30.
- [x] ~~**`docs/progress/_context.md` defasado**~~ — **FECHADO pelo CTO na virada da 31** (o `_context` foi regerado; ver §"Encerramento da Sprint 31" → atualizações doc). Convém ao **Summarizer** confirmar no próximo ciclo Guardian.
- [ ] **Concorrência fina do despacho** — coberta por advisory lock próprio (`728_104_536`) + `pendentes` via `find_each`; **crash-window** entre marcar `processada` e o efeito do handler permanece débito documentado (idempotência mora nos handlers) — Severidade: 🟢 — Tarefa: futura (se observado em produção).
- [ ] **D2 da 17.5 (pré-existente):** `CalcularFrequenciaJob` recalcula os **últimos 3 dias SEM guarda de mês finalizado** — mesmo padrão do **bug A da 31.3** (que foi corrigido só no handler de recálculo). Corrigir **só o handler** criaria divergência handler × job; o tratamento correto é **tarefa própria sobre a 17.5** (guard por dia no job; o handler passa a espelhar). Severidade: 🟠 — Tarefa: **nova** (17.x).
- [ ] **TOCTOU residual de mês finalizado** (31.3/31.5): o guard `ConsolidacaoMensalService.finalizado?` é "melhor esforço"; se OUTRO processo finalizar o mês entre o guard e o `consolidar`, o ramo "passado" já reescreveu o `CalculoDiario` do dia. Probabilidade desprezível (finalização manual); **documentado honestamente** no código (a 31.5 até removeu o `rescue` morto). Severidade: 🟢 — Tarefa: futura (se a finalização passar a ser automatizada).
- [ ] **Q16 — "cauda" do período ao encolher o vínculo** (31.5): ao **reduzir** `momento_final`, os dias após o novo fim **não** são recalculados (fiel ao literal "dias do período") ⇒ `CalculoDiario` pode ficar **stale**. Mitigação: nenhuma (decisão do dev pendente — manter literal × estender). Severidade: 🟠 — Tarefa: **decisão do dev**.
- [ ] **Migration `create_tarefas_recalculo` (31.1) só aplicada no banco de TESTE local** — falta `db:migrate` no **dev remoto** antes de qualquer uso do mecanismo fora do teste. Severidade: 🟠 (operacional) — Tarefa: **deploy**.
- [ ] **RuboCop-77** (`chore/limpeza-rubocop-77`) — deadline **2026-10-13** (hoje); gatilho binário = `rubocop` EXIT 0. Severidade: 🟡 — Tarefa: chore.

## Definição de Pronto

- [x] 31.1–31.5 com status e Linha do Tempo preenchidos.
- [x] Testes: **idempotência da fila** (2× = 1 efeito), **despacho por tipo sem tocar os adiados**, **sem `remove_method`** (helper save/restore), **sem regressão no recálculo existente**; mutation testing dos pontos críticos (5/5, 6/6, 6/6, 3/3, 5/5 mortas por task).
- [x] `db/schema.rb` atualizado (só a nova tabela `tarefas_recalculo`); `config/schedule.yml` com o job a cada 5min (**production-only**, entrada `executa_tarefas`, cron `*/5 * * * *`).
- [x] **Nenhuma** alteração de `Ability`/cascata/autorização (registro global do `CLAUDE.md` respeitado).
- [x] Commit **realizado** (manual, pelo dev — pilha linear até `dae631f`); **push/merge PENDENTES** (ver §"Encerramento da Sprint 31" → sequência de entrega).
- [x] Perguntas abertas: **Q14 resolvida**; **Q15/Q16** explicitamente abertas (decisão do dev).

## Perguntas abertas ao dev / PO

- **Q14 (31.5) — entidade que emite `VINCULAR_DESVINCULAR` no Frequência — ✅ RESOLVIDA (dev, 2026-10-13).** Decisão: **`RegimeFrequentador`** (vínculo de regime a frequentador, com `momento_inicial`/`momento_final` — o domínio que existe e casa com "dias do período"). Implementada na 31.5 com o produtor como **callback `after_commit`** no próprio model (único locus de ciclo-de-vida — a app nunca escreve `regime_frequentadores`).
- **Q15 (quadro desta sprint) — devs/perfis (NOVA, aberta; decisão do dev).** O plano assumiu **Dev A** (31.1/31.2/31.3) e **Dev B** (31.4/31.5). Ajustar se o quadro real for diferente.
- **Q16 (31.5) — recálculo da "CAUDA" ao encerrar/encolher o período (NOVA, aberta; decisão do dev).** O PRD §5.2 diz "recalcula os dias do período". Implementado literalmente: recalcula `[momento_inicial, momento_final]`. **Furo semântico identificado no review (🟠-D1):** ao **encolher** um período (novo `momento_final` anterior ao antigo), os dias **depois** do novo fim — que antes eram cobertos por um período aberto e já tinham `CalculoDiario` calculado — **não** são recalculados, podendo ficar **stale**. Mitigação atual: nenhuma (fiel ao literal). **Decisão do dev:** manter o literal (registrado como débito) ou estender o handler para recalcular também a cauda `(novo_fim, fim_anterior]`? Registrar a resposta antes de qualquer mudança.

## Linha do Tempo

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
| 2026-10-07 | Sprint Planner detalhou a **Sprint 31** a partir da escolha do dev (**opção 3 = PRD §5.2**, gap §9#3) | 5 tarefas, **14 pontos**, núcleo §5.2 (fila + despacho + 3 handlers de domínio existente); `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` **adiados**; **Q14/Q15** abertas |
| 2026-10-13 | **31.1** — fila/model `TarefaRecalculo` + `enfileirar!` idempotente (`b417fef`); **31.2** — `ExecutaTarefasJob` com lock próprio `728_104_536` + registry (`97095bc`) | Implementado, testado (20+7 testes), revisado (0 blockers); D2 do 31.1 exposto na 31.3 e corrigido (`1fa033e`, savepoint) |
| 2026-10-13 | **31.3** — `RegistroRecalculoHandler` + 2 produtores in-transaction (`b50e425`; correções A/B: trava de mês finalizado no DIA + nunca dia futuro) | Implementado, testado, revisado (0 blockers, 2 bugs reais fechados) |
| 2026-10-13 | **31.4** — `RecalcularTodosHandler` eixo `Pessoas::Vinculo.ativos` (`e13f782`); **31.5** — `VincularDesvincularHandler` + produtor `after_commit` em `RegimeFrequentador` (`dae631f`); **Q14 resolvida** | Implementado, testado, revisado (0 blockers); S1 da 31.5 corrigido; **Q16 aberta** (cauda do período) |
| 2026-10-13 | **CTO encerra a Sprint 31** — fecha rastreabilidade doc: header/DoP/Débitos/Linha do Tempo, **ADR-0011**, catalogação na inception de domínio, lições, `_context` | 🟢 **ENCERRADA** (doc-only, sem commit — `COMMIT_MODE=manual`) |

---

## Encerramento da Sprint 31 (CTO, 2026-10-13)

**Veredito:** 🟢 **SPRINT 31 ENCERRADA.** As **5 tasks** estão **implementadas, testadas, revisadas (0 blockers) e commitadas** (pilha linear `b417fef → 97095bc → b50e425 → e13f782 → dae631f`, + `1fa033e`). O **mecanismo estrutural §5.2** (fila + despacho + 3 handlers de domínio existente) **existe no app**; os 3 tipos sem domínio (`FERIADO`/`DIAEXCEPCIONAL`/`DIREITO`) ficam **declarados e adiados** (política incremental vigente). Baseline final **1214/4239/3F+12E/0 skip** (15 defeitos pré-existentes, nenhum da 31).

### O que a Sprint 31 muda no entendimento do sistema

- **Novo subsistema de infraestrutura de recálculo.** Nasce o par **fila persistente (`TarefaRecalculo`) × despachante (`ExecutaTarefasJob`, cron `*/5` production-only)** com **registry de handlers** por `tipo_entidade`. É o **"trigger" real de recálculo em lote por evento** que o PRD §5.2 aponta como *sem equivalente conhecido no Frequência* (§9 gap #3) — agora **existe**.
- **Tensão arquitetural registrada (inception).** O doc de domínio existente (`docs/03-dominio/05-eventos-dominio.md`) **propõe** modelar a fila como **eventos de domínio** ("não como tabela de tarefas genérica"). A Sprint 31 implementou deliberadamente o **oposto pragmático**: **tabela de tarefas genérica** + `tipo_entidade` (fiel ao legado `presenca_historicotarefa`). **Decisão registrada na ADR-0011** (Alternativa descartada = barramento de eventos). O doc de domínio recebe **nota de reconciliação** (ver §catalogação).
- **Fronteira com a §5.1 preservada.** O mecanismo **reusa** o pipeline existente (`CalculoDiarioService`/`ConsolidacaoMensalService`/`CalcularFrequenciaJob`) e **não** replica os jobs autônomos do legado (`RecalculoDiario` etc.).
- **Zero acoplamento com autorização.** §5.2 é infra de recálculo; nada toca a cascata/flags.

### Decisões arquiteturais consolidadas → **ADR-0011**

As 7 decisões da sprint foram consolidadas em **uma** ADR (padrão de consolidação já usado na ADR-0010 para a cascata). Mapeamento decisão → tratamento:

| # (do briefing) | Decisão | Tratamento |
|---|---|---|
| 1 | **Registry de handlers** por `tipo_entidade` (mapa `tipo→callable`, vazio de fábrica, populado por initializer `to_prepare`) | **ADR-0011 regra 1** (padrão novo, deliberadamente mínimo) |
| 2 | **Advisory lock PRÓPRIO** `728_104_536`; **NÃO** reusar o lock do `CalcularFrequenciaJob` dentro do handler (evita *drain-without-effect*) | **ADR-0011 regra 2** |
| 3 | **Produtor dentro × fora da transação** (31.3 in-transaction; 31.5 `after_commit`) | **ADR-0011 regra 3** (contrato caso a caso) |
| 4 | **Trava de mês finalizado (17.2)** aplicada ao recálculo por evento — inclusive ao DIA (correção A/31.3) + débito TOCTOU | **ADR-0011 regra 4** |
| 5 | **Nunca recalcular dia futuro** (correção B/31.3) | **ADR-0011 regra 5** |
| 6 | **Q14** — `RegimeFrequentador` emite `VINCULAR_DESVINCULAR`; produtor = callback `after_commit` | **ADR-0011 regra 6** + nota em `05-eventos-dominio.md` |
| 7 | **Tipos adiados** declarados sem produtor/handler | **ADR-0011 regra 7** (política incremental) |

**Por que uma só ADR (e não sete):** as 7 decisões são **facetas de um mesmo mecanismo** (contrato de uma fila governada por registry). Fragmentá-las em 7 ADRs infla a série e perde a coesão — o mesmo critério que a ADR-0010 aplicou à cascata. As decisões **operacionais** (5 = regra de 1 linha; 7 = política já vigente) e o **ruling de domínio** (6/Q14) entram como **regras/notas dentro da ADR-0011**, **não** como ADRs próprias. *(Candidata a ADR própria, se o dev quiser rastreabilidade de domínio isolada: a #6/Q14 — recomendo **não** abrir; fica como regra 6 + nota no doc de eventos.)*

### Riscos/decisões que exigem o dev nesta virada (checklist)

- [ ] **Q15 — quadro real de devs.** O plano assumiu **Dev A** (31.1/2/3) e **Dev B** (31.4/31.5) para dimensionar paralelismo; a execução foi **sequencial** (pilha linear). Responder se o quadro real difere (impacta retrospectiva/planejamento da próxima sprint).
- [ ] **Q16 — "cauda" do período ao encolher o vínculo (31.5).** Manter o **literal** ("dias do período" = `[início, fim]`; cauda fica como débito) **ou** estender o handler para recalcular a cauda `(novo_fim, fim_anterior]`? Registrar a decisão **antes** de qualquer mudança; hoje está fiel-ao-literal com o furo documentado.
- [ ] **D2 da 17.5 — `CalcularFrequenciaJob` recalcula os últimos 3 dias SEM guarda de mês finalizado.** É o **mesmo padrão do bug A da 31.3** (pré-existente). Corrigir só o handler criaria divergência; **abrir tarefa própria sobre a 17.5** ou aceitar explicitamente. Decisão de priorização do dev.
- [ ] **Deploy da migration `create_tarefas_recalculo` (31.1) no dev remoto.** Só foi aplicada no banco de **teste local**; sem `db:migrate` no dev remoto, o mecanismo **não opera** fora do teste.
- [x] **RuboCop-77** — ✅ **FEITO no prazo (2026-10-13):** 75→0 offenses, `bin/rubocop` EXIT 0 (chore `chore/limpeza-rubocop-77`, commit `51992e8`).
- [x] **Push da pilha** — ✅ **FEITO (2026-10-14):** branch `chore/limpeza-rubocop-77` @ `ceaac87` publicada em `origin` e `gitlab`.
- [ ] **Merge em `integration/sprint-29`** — **PENDENTE / bloqueado por decisão do dev** (`COMMIT_MODE=manual`).

### Sequência recomendada de entrega (proposta — CTO NÃO executa)

1. **Gate de CI local** (`ci-cd-pipeline`) sobre a pilha inteira: security → quality → **test** (mandatório). Baseline final **1214/4239/3F+12E** (15 pré-existentes devem ser reconhecidas, não atribuídas à sprint).
2. **Merge da pilha linear** `feature/demanda-31-5-vincular-desvincular` (que já contém 31.1→31.5) **em `integration/sprint-29`** — via `--no-ff` (preserva o agrupamento da sprint), após confirmar que a pilha está **rebased/atualizada** sobre o HEAD atual de `integration/sprint-29`.
3. **`db:migrate` no dev remoto** (item de deploy acima) — **antes** de ligar o cron na branch integrada.
4. **Push** da `integration/sprint-29` para os remotes (GitLab + fork GitHub), conforme o padrão do repo.
5. **Fechamento** já materializado: header 🟢 + Encerramento + ADR-0011 + catalogação + lições + `_context`. Commit **doc-only** do pacote do CTO (o dev commita/pusha manualmente — `COMMIT_MODE=manual`).
6. **Próxima sprint** (31+1): abrir com os débitos herdados (D2/17.5, Q16, RuboCop-77) + o **`implementation_plan.md` a formalizar** (Sprints 29–31 ausentes — Project Planner).

### Artefatos da consolidação (editados pelo CTO nesta virada)

- `docs/adr/0011-mecanismo-recalculo-por-evento.md` — **NOVO** (decisão durável do mecanismo §5.2).
- `docs/README.md` — índice de ADRs `0000–0010` → **`0000–0011`**.
- `docs/03-dominio/05-eventos-dominio.md` — **nota de reconciliação** (implementado como tabela de tarefas, não barramento de eventos).
- `docs/governance/lessons.md` — **lições novas** (savepoint/`RecordNotUnique`, lock-herdado, guard de escrita).
- `docs/progress/_context.md` — **regerado** (estava em `da26ee8`; Sprints 30/31 ausentes).
- *(Recomendado ao Summarizer no próximo Guardian: `docs/governance/_context.md` — contagem de lições 37→~~41~~ **42**, ADR 0010→0011, Sprints 30/31.)* **✅ FEITO (Summarizer, 2026-10-13):** `docs/governance/_context.md` regerado — contagem REAL medida por `grep -cE "^### [0-9]{4}-[0-9]{2}-[0-9]{2}" docs/governance/lessons.md` = **42** (a estimativa "41" desta linha estava subcontada: omitia a lição de 2026-10-06); ADRs `0000–0011` (com a ADR-0011 descrita); Sprints 30/31 refletidas; ambiente reconferido (Ruby 3.3.8 / Rails 8.1.4).
