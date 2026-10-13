# Iteration 31 — Fila assíncrona de recálculo por evento (PRD §5.2)

> Status: 📋 Planejada | Período: a definir (após Sprint 30) | Goal: materializar o **mecanismo estrutural** de recálculo em lote por evento do PRD §5.2 (gap §9 #3) — uma **fila persistente** de tarefas + um **job de despacho** a cada ~5min + os **handlers dos eventos cujo domínio já existe no Frequência** (`REGISTRO_FREQUENCIA`/`REGISTRO_ESTACAO`, `VINCULAR_DESVINCULAR`, `RECALCULAR_TODOS`), deixando `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` **explicitamente adiados** (models inexistentes). | Rastreabilidade: `Frequencia/PRD-REGRAS-NEGOCIO-PRESENCA.md` **§5.2 (L139-148)** e **§9 item 3 (L201)**; contexto de §5.1 (L133-137); `docs/progress/iteration_30.md` (política incremental de roles — emenda 2026-10-07).

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
- **`docs/progress/_context.md` está DEFASADO** (registra HEAD `da26ee8`, branch `integration/sprint-29`). O **HEAD real medido nesta árvore é `8bd6755`** (`feat: semeia as 13 roles granulares do legado (guardadas/inertes) + registra a decisao`). **Não atualizar o `_context.md` nesta tarefa** (fora do escopo; o Summarizer é o dono).

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
- Status: ⬜ Pendente
- Riscos: volume (executar em lote pode ser caro) → herdar o **advisory lock** do `CalcularFrequenciaJob` **ou** delimitar o escopo temporal (decidir na implementação; registrar). Eixo "vínculo ativo" (`Pessoas::Vinculo.ativos`) × `User.status` — usar o mesmo eixo da cascata/`frequentadores_ativos`, não inventar outro.

#### Tarefa 31.5 — Handler `VINCULAR_DESVINCULAR` (dias do período do vínculo)
- User Story: Como administrador, quero que ao **vincular/desvincular** um frequentador (regime/período) os **dias do período** sejam recalculados, para que o cálculo reflita a mudança de vínculo retroativamente.
- Rastreabilidade: PRD **§5.2 (L144)** — "`VINCULAR_DESVINCULAR` → recalcula os dias do período"; `RegimeFrequentador` (`momento_inicial`/`momento_final`)
- Estimativa: **3 pontos** | Atribuição: **Dev B** | Dependências: **31.2** (paralela à 31.3 após a 31.2)
- **Escopo (o que ENTRA):**
  - Handler de `VINCULAR_DESVINCULAR`: recalcula **os dias do período do vínculo** afetado (por dia, via `CalculoDiarioService.calcular`; mês consolidado).
  - **Produtor (enfileiramento):** no ponto de **criação/encerramento do vínculo** (`RegimeFrequentador` — `momento_inicial`/`momento_final`) enfileira **1** tarefa com `referencia` estável (`tipo + user_id + período`).
- **⚠️ Ponto a confirmar com o dev (Q14 — NÃO decidido por este plano):** qual entidade do Frequência **emite** `VINCULAR_DESVINCULAR`? **Default recomendado:** `RegimeFrequentador` (o vínculo de regime a frequentador, com **período** — o domínio que existe e casa com "recalcula os dias do período"). O plano **não inventa** outro mapping; se o dev apontar outra entidade, a tarefa é rebaseada antes da implementação.
- **Escopo (o que NÃO ENTRA):** `DIREITO` (adiado — o legado o agrupa com `VINCULAR_DESVINCULAR`, mas a entidade de direito **não existe** aqui).
- Critérios de aceite:
  - [ ] Handler recalcula os **dias do período** do vínculo (teste de período com dias conhecidos).
  - [ ] **Idempotente:** rodar 2× = mesma saída; dias **fora** do período **não** são tocados.
  - [ ] **Produtor idempotente:** 2 eventos do mesmo período = **1 efeito**.
  - [ ] Teste com o período **injetado em memória**; **save/restore do método original — NUNCA `remove_method`**.
  - [ ] Sem regressão no baseline; RuboCop/Zeitwerk OK.
- Status: ⬜ Pendente
- Riscos: **mapeamento do evento (Q14)** — o maior risco desta tarefa; resolvido como **default + confirmação do dev**, nunca por suposição silenciosa. Período longo ⇒ muitos dias por tarefa → limitar/avaliar na implementação.

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
- [ ] **`docs/progress/_context.md` defasado** (HEAD `da26ee8`; real `8bd6755`; Sprint 30 concluída não refletida) — Severidade: 🟡 — Tarefa: (Summarizer), **não** atualizar nesta tarefa.
- [ ] **Concorrência fina do despacho** (se não coberta por completo na 31.2) — Severidade: 🟢/🟡 — Tarefa: **31.2** ou futura.

## Definição de Pronto

- [ ] 31.1–31.5 com status e Linha do Tempo preenchidos.
- [ ] Testes: **idempotência da fila** (2× = 1 efeito), **despacho por tipo sem tocar os adiados**, **sem `remove_method`** (helper save/restore), **sem regressão no recálculo existente**; mutation testing dos pontos críticos.
- [ ] `db/schema.rb` atualizado (só a nova tabela `tarefas_recalculo`); `config/schedule.yml` com o job a cada 5min (production-only).
- [ ] **Nenhuma** alteração de `Ability`/cascata/autorização.
- [ ] Sem commit/push (`COMMIT_MODE=manual`); stage seletivo quando autorizado.
- [ ] Perguntas abertas (**Q14**) respondidas ou explicitamente adiadas.

## Perguntas abertas ao dev / PO

- **Q14 (31.5) — entidade que emite `VINCULAR_DESVINCULAR` no Frequência (NOVA, aberta; decisão do dev).** O PRD §5.2 diz "recalcula os dias do período", mas não nomeia a entidade. **Default recomendado:** `RegimeFrequentador` (vínculo de regime a frequentador, com `momento_inicial`/`momento_final` — o domínio que existe e casa com "dias do período"). Confirmar antes de implementar a 31.5; se for outra entidade, a tarefa é rebaseada.
- **Q15 (quadro desta sprint) — devs/perfis (NOVA, aberta; decisão do dev).** O plano assumiu **Dev A** (31.1/31.2/31.3) e **Dev B** (31.4/31.5). Ajustar se o quadro real for diferente.

## Linha do Tempo

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
| 2026-10-07 | Sprint Planner detalhou a **Sprint 31** a partir da escolha do dev (**opção 3 = PRD §5.2**, gap §9#3) | 5 tarefas, **14 pontos**, núcleo §5.2 (fila + despacho + 3 handlers de domínio existente); `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` **adiados**; **Q14/Q15** abertas |
