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
  - [ ] A guarda é avaliada **antes de qualquer escrita** de `CalculoDiario` para cada um dos 3 dias; mês finalizado ⇒ **o dia não é recalculado** (skip silencioso).
  - [ ] Teste com **snapshot**: `CalculoDiario` de um mês finalizado **permanece inalterado** após rodar o job (sem stub — mês realmente finalizado via `ConsolidacaoMensalService.finalizar`).
  - [ ] Teste cobre a **virada de mês**: 3 dias cruzando 2 meses, um finalizado e outro não ⇒ o dia do mês aberto é recalculado, o do mês fechado **não**.
  - [ ] A guarda **reusa** `ConsolidacaoMensalService.finalizado?` (grep prova: nenhuma segunda condição de finalização criada).
  - [ ] A consolidação do mês corrente continua rodando; `MesFinalizadoError` segue tratado como salvaguarda.
  - [ ] Testes via `test/support/class_method_stub_helper.rb` (**save/restore; NUNCA `remove_method`**) quando houver stub.
  - [ ] Sem regressão no baseline (as 15 pré-existentes inalteradas); RuboCop/Zeitwerk OK.
- Status: ⬜ Pendente

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  |         |                 |           |

- Riscos: **duplicar** a regra de finalização (criar um segundo crivo que pode divergir) → mitigado por **reusar** `finalizado?`. Confundir mês do dia × mês corrente → a guarda é **por dia** e o teste cobre a virada de mês.

#### Tarefa 32.2 — Espelho da guarda no handler `RECALCULAR_TODOS` (débito D2 da 31.4)
- User Story: Como sistema, quero que o handler `RECALCULAR_TODOS` aplique a **mesma guarda por dia** do job noturno, para que o recálculo em lote **não divirja** do `CalcularFrequenciaJob` (mesma classe de débito D2/17.5).
- Rastreabilidade: `iteration_31.md` **31.4 §"Débitos registrados" — 🟠-D2** ("ausência de guard `finalizado?` por dia ... herdada do `CalcularFrequenciaJob` (17.5) ... corrigir só o handler criaria divergência handler × job; o tratamento é tarefa própria sobre a 17.5 e o handler passa a espelhar") · **ADR-0011 regra 4** · `app/services/recalcular_todos_handler.rb`
- Estimativa: **2 pontos** | Atribuição: **Dev 1** | Dependências: **32.1** (a correção nasce no job; o handler espelha — **ordem obrigatória**)
- **Escopo (o que ENTRA):**
  - Antes de `CalculoDiarioService.calcular(user, dia)` no pipeline por usuário do `RecalcularTodosHandler`, checar **`ConsolidacaoMensalService.finalizado?(user, dia.year, dia.month)`** e pular o dia quando o mês dele estiver finalizado (skip silencioso) — **mesma semântica** da 32.1 e do `RegistroRecalculoHandler` (31.3, referência).
  - **Reusar** o predicado `finalizado?` (sem segundo crivo).
- **Escopo (o que NÃO ENTRA):** alterar o eixo `Pessoas::Vinculo.ativos` (31.4, correto per PRD); alterar a decisão de lock (31.4, correto per ADR-0011 regra 2); mexer no `RegistroRecalculoHandler` (31.3 — já tem a guarda; é a **referência**, não se altera).
- Critérios de aceite:
  - [ ] Guarda por dia antes de `calcular`; mês finalizado ⇒ **skip silencioso** (não recalcula o dia).
  - [ ] **Sem divergência handler × job:** a semântica de guarda do `RecalcularTodosHandler` converge com a do `CalcularFrequenciaJob` (32.1) e com o `RegistroRecalculoHandler` (31.3).
  - [ ] Idempotência preservada (rodar 2× = mesma saída); erro por usuário **isolado** (`rescue StandardError` por usuário) mantido.
  - [ ] Teste com o conjunto de usuários/CPFs **injetado em memória**; `class_method_stub_helper` (save/restore; nunca `remove_method`).
  - [ ] Sem regressão no baseline; RuboCop/Zeitwerk OK.
- Status: ⬜ Pendente

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  |         |                 |           |

- Riscos: **ordem invertida** (corrigir o handler antes do job) recria a divergência que o débito D2 alerta → a dependência 32.1 → 32.2 é **obrigatória**.

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
- Status: ⬜ Pendente — **condicionada à aprovação do dev**

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  |         |                 |           |

- Riscos: aplicar antes de aprovação; ligar o cron na branch integrada **antes** do `db:migrate` ⇒ o `ExecutaTarefasJob` falha (`relation does not exist`).

#### Tarefa 32.4 — Governança de docs: ponteiro do `CLAUDE.md` do workspace → `Frequencia/docs/`
- User Story: Como agente/dev do projeto Frequência, quero que o ponteiro de documentação aponte para a árvore correta (`Frequencia/docs/`), para não ser conduzido à árvore do **outro** projeto (`pessoas2/docs/`).
- Rastreabilidade: `implementation_plan.md` v2 — **Épico 7** (governança de docs) · `docs/progress/_context.md` (2026-10-14) · arquivo **externo ao repo Frequencia**: `workspace_integração/CLAUDE.md`
- Estimativa: **1 ponto** | Atribuição: **Dev 1 (decisão do dev)** | Dependências: **decisão do dev pendente**
- **Contexto factual:** o `CLAUDE.md` do **workspace** (`workspace_integração/CLAUDE.md`) aponta `pessoas2/docs/` e `pessoas2/docs/governance/` para **todo** o workspace (**multi-projeto**). O cabeçalho do `docs/README.md` do Frequência **já foi corrigido** (2026-10-14) — **resta apenas o ponteiro do `CLAUDE.md` do workspace**. O arquivo **não está dentro do repo `Frequencia`** (está em `workspace_integração/`).
- **Escopo (o que ENTRA):** corrigir/escopar o ponteiro de docs para o **projeto Frequência** apontar para `Frequencia/docs/` (ideal: **escopar por projeto**, de modo que o Frequência não seja conduzido à árvore do Pessoas2).
- **Escopo (o que NÃO ENTRA):** alterar a documentação do projeto Pessoas2; quebrar o carregamento para os **outros** projetos do workspace.
- Critérios de aceite:
  - [ ] **Decisão do dev** registrada: abordagem **escopada por projeto** × correção global (o arquivo é multi-projeto).
  - [ ] Para o Frequência, o ponteiro de docs não conduz a `pessoas2/docs/`.
  - [ ] A mudança **não** afeta negativamente os demais projetos do workspace.
- Status: ⬜ Pendente — **condicionada à decisão do dev** (não é tarefa fechada)
- Riscos: editar um arquivo **compartilhado** do workspace e quebrar outros projetos; tratar como tarefa fechada antes da decisão do dev. Nota: a alteração está **fora do repo Frequencia** — se o guia for "não tocar fora do repo", a tarefa vira apenas **recomendação** ao dev.

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  |         |                 |           |

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
| **32.1** | Recálculo — D2/17.5 | **3** | nenhuma | código | ⬜ Pendente |
| **32.2** | Recálculo — espelho 31.4 | **2** | **32.1** | código | ⬜ Pendente |
| **32.3** | Operação — deploy migration | **1** | pilha 31 | operacional (aprov. dev) | ⬜ Condicionada |
| **32.4** | Governança — ponteiro docs | **1** | decisão do dev | governança (fora do repo) | ⬜ Condicionada |
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

- [ ] **D2 da 17.5** — `CalcularFrequenciaJob` recalcula os últimos 3 dias **sem** guarda de mês finalizado ⇒ `CalculoDiario` de mês fechado pode ser reescrito e o `RegistroMensalFrequencia` ficar stale. **Tratado nesta sprint (32.1).** Severidade: 🟠 — Tarefa: 32.1.
- [ ] **D2 da 31.4** — `RecalcularTodosHandler` sem guard `finalizado?` por dia (mesma classe de D2/17.5). **Tratado nesta sprint (32.2), espelhando o job.** Severidade: 🟠 — Tarefa: 32.2.
- [x] ~~**Q16 — "cauda" do período ao encolher o vínculo (31.5)**~~ — **FECHADO como débito ACEITO (dev, 2026-10-14): MANTER O LITERAL.** A cauda não é recalculada; decisão documentada, **não** é tarefa da 32. Severidade: 🟠 (aceito) — Tarefa: (nenhuma).
- [ ] **Migration `create_tarefas_recalculo` (31.1) só no banco de TESTE local** — falta `db:migrate` no dev remoto. **Item operacional 32.3 (aprov. do dev).** Severidade: 🟠 (operacional) — Tarefa: 32.3.
- [ ] **Governança de docs** — `CLAUDE.md` do workspace aponta para `pessoas2/docs/` (multi-projeto). **Item condicionado 32.4.** Severidade: 🟡 — Tarefa: 32.4.
- [ ] **TOCTOU residual de mês finalizado** (31.3/31.5) — guard "melhor esforço"; documentado honestamente. Severidade: 🟢 — Tarefa: futura (se a finalização for automatizada).
- [ ] **Crash-window do despacho** (31.2) — entre `processada` e o efeito do handler; idempotência mora nos handlers. Severidade: 🟢 — Tarefa: futura (se observado em produção).
- [ ] **Enforcement opt-in da cascata** (ADR-0010 regra 9) — causa-raiz do Bug 🔴1; **candidato opcional 32.O1**, horizonte 33+. Severidade: 🟠 — Tarefa: 32.O1 (não comprometida).
- [ ] **Linha basic8 (Sprints 25/27/28)** — **PAUSADA** por ruling do dev (2026-10-14); pode voltar ao horizonte. Severidade: 🟡 — Tarefa: fora da 32.

## Definição de Pronto

- [ ] 32.1 e 32.2 implementadas com Status e Linha do Tempo preenchidos; 32.3/32.4 refletem a decisão/aprovação do dev (executadas **ou** explicitamente não autorizadas).
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
- **Q32-B (aberta) — aprovação do deploy (32.3)** e **abordagem do ponteiro de docs (32.4)**: escopar por projeto × corrigir global; e se a alteração do `CLAUDE.md` do workspace (fora do repo Frequencia) é autorizada. **Aguarda decisão do dev.**
- **Q32-C — tamanho da sprint — ✅ RESOLVIDA (dev, 2026-10-14):** rodar a sprint **CURTA como planejada** — **7 pts** (32.1 + 32.2 + os 2 itens condicionados). O candidato **`32.O1` (enforcement opt-in da cascata) NÃO foi puxado** — segue como candidato não comprometido (horizonte), por tocar autorização e depender da migração de roles.

## Veredito honesto sobre o tamanho da sprint

**Com o Q16 fora, sobra pouco.** O escopo **obrigatório** é essencialmente **uma correção de código real (D2/17.5 — 32.1, 3 pts)** e **seu espelho no handler `RECALCULAR_TODOS` (32.2, 2 pts)** — **5 pontos de código**, execução sequencial por 1 dev (**≈meio a 1 dia de trabalho efetivo**). Os outros dois itens (**32.3 deploy** e **32.4 governança de docs**) **não são código** e **ambos estão gated em decisão/aprovação do dev** (podem nem ser executados nesta sprint). Somando tudo, o **total comprometido é 7 pontos** (2 deles condicionados) — **abaixo** de uma sprint cheia padrão (14 pts).

**Portanto: o escopo herdado NÃO preenche, sozinho, uma sprint de uma semana.** Esta é a avaliação honesta pedida — **não inventei escopo para engordar**. Recomendações (decisão do dev):

1. **Rodar a sprint curta como está** (5–7 pts): é um hardening legítimo e barato; a sprint termina rápido e fecha o D2/17.5 + o espelho com segurança. Legítimo para uma sprint de débito.
2. **Se quiser preencher a semana**, puxar **explicitamente** um candidato do horizonte — o único de **alto valor de hardening** é o **`32.O1` (enforcement opt-in da cascata, ADR-0010 regra 9, 5 pts)**, que **toca autorização** e por isso exige **plano claro + aprovação do dev** (é **escolha a mais, não obrigação herdada**). Os demais candidatos (tipos adiados, gaps §9 #4/#6/#8, Bug 🟠2) são de **custo alto/largo** e **não** cabem numa sprint de hardening — ficam no horizonte 33+.
3. **Ou** reagrupar: **absorver 32.1/32.2 na retomada de features** e encerrar a 32 como uma sprint operacional curta (deploy + docs), já que ambos os itens condicionados dependem do dev.

Nenhuma das opções altera o ruling do dev sobre Q16 (literal), basic8 (pausada) ou Q15 (1 dev sequencial).
