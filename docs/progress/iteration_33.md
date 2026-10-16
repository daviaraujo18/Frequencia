# Iteration 33 — Enforcement da cascata de autorização: duas camadas (runtime fail-closed + meta-teste de build)

> ## ✅ ALINHADO AO PLANO APROVADO (2026-10-15)
> Este `iteration_33.md` está **estritamente alinhado** ao artefato de aprovação único do dev —
> **`docs/progress/iteration_33_plano_autorizacao_32_O1.md`** (§0.5 reconciliação; §7 checklist;
> **§7.1 ✅ APROVAÇÃO DO DEV — REGISTRADA (2026-10-15)**). As **decisões D1–D5/Q33-C** codificadas abaixo
> vêm verbatim da **§7.1** e são **especificação vinculante**. O rascunho anterior deste arquivo (que trazia
> a tarja "RASCUNHO — NÃO É O ARTEFATO DE APROVAÇÃO") fica **superseded**. **O plano de autorização é
> frozen/aprovado e NÃO é alterado por este documento; o Code Specialist implementa o que está aqui.**

> **⚠️ GATE DE AUTORIZAÇÃO — LEIA PRIMEIRO.** Esta sprint **TOCA AUTORIZAÇÃO** (controllers de listagem de
> frequência, o concern `FrequenciaAuthorization`, o base `Admin::ApplicationController`). Pela **regra
> global do `CLAUDE.md`** (itens 9 e 12 — "não alterar autenticação, autorização … sem plano claro"), o
> **plano claro exigido JÁ FOI dado e APROVADO** (§7.1 do artefato de aprovação). Portanto o gate está
> **SATISFEITO**: o Code Specialist está **liberado** para implementar as tarefas 33.1–33.5.
> **`Ability` permanece INALTERADA** (D3 = não).

> Status: 📋 **PLANEJADA — APR. DEV REGISTRADA (2026-10-15)** | Período: a definir | Goal: tornar
> **explícito, fail-closed em runtime e verificável em build** o ponto de enforcement da cascata de
> autorização de frequência — hoje **opt-in por controller** (concern `FrequenciaAuthorization` incluído
> manualmente) — de modo que **um controller novo que leia `TimeRecord`/`CalculoDiario`/
> `RegistroMensalFrequencia`/`IntervencaoFrequencia`/`Pessoas::Vinculo` e chame `authorize! :read, :all`
> deixe de vazar silenciosamente** o roster/registros (causa-raiz do Bug 🔴1 da auditoria da Sprint 30).
> | Rastreabilidade: **ADR-0010 regra 9** + emenda 2026-10-08; `docs/progress/iteration_33_plano_autorizacao_32_O1.md`
> (§0.1/§0.2 diagnóstico; §0.5 reconciliação D1–D5; §1 Alternativa D; **§7.1 aval**); `implementation_plan.md` v2
> (risco "Enforcement opt-in da cascata" — 🟠 Alto; horizonte 33+); `iteration_32.md` §"Situação da Sprint 33"
> (escopo definido pelo dev em 2026-10-15); `iteration_30.md` §"Débito ESTRUTURAL";
> `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md` (Bug 🔴1).

---

## Contexto e escopo (definido e APROVADO pelo dev — 2026-10-15)

A Sprint 33 executa o candidato **`32.O1`** (não comprometido na Sprint 32). É uma sprint de
**HARDENING DE AUTORIZAÇÃO** — não introduz funcionalidade nova de produto.

**Causa-raiz (medida, não suposta).** A cascata de autorização de frequência (Sprint 29) é **opt-in por
controller**: o concern `FrequenciaAuthorization` (`api-ponto/app/controllers/concerns/frequencia_authorization.rb`)
é incluído controller a controller, e `authorize! :read, :all` **satisfaz** o `check_authorization` do base
`Admin::ApplicationController` (`api-ponto/app/controllers/admin/application_controller.rb:42`). O
`check_authorization` é um guarda de **presença de chamada**, não de **conteúdo** (§0.1 do plano). O que
vaza é o **símbolo `:all`** — o `can :read, :all` do baseline (`api-ponto/app/models/ability.rb:91`) **não é
revogado por nada**. Um controller novo que leia os recursos de frequência, chame `authorize! :read, :all` e
monte a listagem **sem** o concern **passa no check e vaza silenciosamente** o rol de frequentadores — em
**qualquer** valor da flag (`:off`/`:shadow`/`:on`).

**Caso concreto (Bug 🔴1 da Sprint 30).** `Admin::UsersController#index` lia
`Pessoas::Vinculo.frequentadores_ativos` (a mesma fonte restringida em `/frequentadores`) **sem** o concern
e com `authorize! :read, :all` → qualquer autenticado enumerava todos os frequentadores ativos. Corrigido no
fix pós-auditoria (`f89d312`), mas a **classe** do furo permanece.

**O que a Sprint 33 entrega (leitura de escopo APROVADA — §7.1).** Um **gate de governança + defesa em
profundidade** — **NÃO** um *default-deny* de runtime para todas as rotas (isso é a Alternativa C, bloqueada
por colidir com a migração de roles da 30.9b a 87,9%). Concretamente:
- **Camada 1 (runtime)** — declaração explícita de postura por controller + **guard fail-closed**, com
  rollout **`log` → `raise`** controlado por **flag própria `FREQUENCIA_CASCATA_ENFORCEMENT`** (separada de
  `FREQUENCIA_AUTORIZACAO_CASCATA`, que hoje roda `:shadow` em dev — `config/environments/development.rb:71`).
- **Camada 2 (build)** — **meta-teste de drift** flag-independente + **testes de conteúdo** por tela. É a
  Camada 2 que **fecha a classe** da omissão; a Camada 1 é **defesa em profundidade** (§0.5/R5).

### Decisões aprovadas (codificadas verbatim da §7.1 — especificação vinculante)

| # | Decisão | Resultado aprovado |
|---|---|---|
| **D1** | Mecanismo | ✅ **Camada 1 (runtime) + Camada 2 (build)** |
| **D2** | Estado em que o guard de runtime nega | ✅ **(a) fail-closed em TODOS os estados da flag**, com rollout **`log` → `raise`**; flag própria **`FREQUENCIA_CASCATA_ENFORCEMENT`** |
| **D3** | Tocar a `Ability`? | ✅ **Não** — o baseline `can :read, :all` permanece; o guard vive no **controller** |
| **D4** | `toca_frequencia only:[…]` por action? | ✅ **Não** no escopo inicial (postura **por controller** basta) |
| **D5** | DRY `incluir_cpfs_com_cascata` → concern | ✅ **Sim** (+1 pt, mesma superfície) |
| **Q33-C** | Incluir `Pessoas::Vinculo` no conjunto | ✅ **Sim** |
| — | Escopo | ✅ **Gate de governança + defesa em profundidade** (não é default-deny de runtime) |
| — | Sizing | ✅ **5–8 pts**; **Q15 = 1 dev, execução sequencial** |
| — | Local da doc | ✅ mantido (`docs/progress/`) |
| — | Baseline | ✅ **1222 runs / 4257 assertions / 3F+12E** (15 pré-existentes) como **piso de não-regressão** |
| — | Exclusões | ✅ Sem `:on` production-wide; sem tocar regras da cascata/roles; sem Bug 🟠2; **nenhuma ADR nova agora** |

### Fronteira explícita — o que esta sprint NÃO é

- **NÃO é feature nova.** Nenhum model/rota/entidade/regra de negócio nova. Nenhuma migration.
- **NÃO altera a semântica da cascata.** Os passos 1–6 (`AutorizacaoFrequencia`), o twin SQL
  (`FrequentadoresVisiveis`), o gate D5 (desconsiderar) e a matriz da 29.8 **não são redefinidos** — a
  sprint só torna **explícito o ponto de enforcement** (o "ONDE").
- **NÃO toca a `Ability` (D3).** O baseline `can :read, :all` permanece; a deny da classe
  (`deny_frequencia_baseline!`, `ability.rb:136-137`) **não** cobre o símbolo `:all` — e não é alterada.
- **NÃO adota `toca_frequencia only:[…]` por action (D4).** A postura é **por controller**.
- **NÃO liga a flag `:on` production-wide** (Q16 da 30: só quando TODAS as roles estiverem prontas).
- **NÃO resolve o Bug 🟠2** (`/presenca/*` sem autenticação) — **risco aceito** (dev, 2026-10-08).
- **NÃO toca as regras das roles nem a migração da 30.9b.**
- **NÃO cria ADR nova agora.** A consolidação durável (emenda à **ADR-0010 regra 9/10** **ou** **ADR-0012**)
  é decisão **POSTERIOR** à implementação (§7.1 / §8 do plano).
- **NÃO commita nem faz push** (`COMMIT_MODE=manual`) — o agente entrega no working tree.

### Pré-condições

- **Aval do dev:** ✅ **REGISTRADA em 2026-10-15** (§7.1 do artefato de aprovação) — gate satisfeito.
- **Base de código:** HEAD atual da linha da Sprint 32 (`feature/demanda-32-2-espelho-handler`
  @ `40740b3`, já em `origin`/`gitlab`; `integration/sprint-29` @ `d50f317`). A pilha 31 está contida na base.
- **Baseline da suíte a isolar (PISO de não-regressão):** **1222 runs / 4257 assertions / 3F + 12E / 0 skip**
  (**pré-sprint — valor aprovado**). ⚠️ **Atualização (2026-10-16):** o piso **CORRENTE**, medido após as
  33.1–33.3, é **1265 runs / 4434 assertions / 3F + 12E / 0 skip** (+43 runs/+177 assertivas de testes novos).
  As tarefas **33.4/33.5** usam o piso corrente; as 15 falhas pré-existentes são as mesmas.
  As **15** são **pré-existentes** (11× Devise `redirect_to` + 1× timezone em `PresencaEndpointsTest` + 1×
  order-dependent do espelho/paralelização; ver `docs/progress/_context.md`). **Toda medição deve isolar as
  15** antes de atribuir regressão.
- **Ambiente medido:** Ruby 3.3.8 / Rails 8.1.4 (ADR-0009); binstubs `bin/*` (não `bundle exec`).
- **⚠️ Arquivo que NÃO deve ser commitado:** `api-ponto/config/environments/development.rb` (onde vive o
  default de dev `FREQUENCIA_AUTORIZACAO_CASCATA=shadow`). Qualquer ajuste de ENV da nova flag em dev é
  **local e não commitado**.

## Decisão de numeração e rastreabilidade

- Última iteration com arquivo: **32** (`iteration_32.md`, encerrada em 2026-10-14). Número livre: **33**.
- A sprint **não** consta do `implementation_plan.md` v2 (que cobre 24–32) — escopo **definido pelo dev**
  (2026-10-15). Rastreabilidade via **ADR-0010 regra 9** + `iteration_32.md` §32.O1 + o artefato de
  aprovação `iteration_33_plano_autorizacao_32_O1.md`.
- O `32.O1` foi estimado em **~5 pts** no `iteration_32.md`; a §2.4 do plano registrou que "~5" era
  **otimista** e o dev **replanejou para 5–8 pts** (§7.1). Esta sprint entrega **8 pts**.

## Desenvolvedores

> **Ruling Q15 (2026-10-14, reafirmado na §7.1): 1 DEV, execução SEQUENCIAL.** Sem paralelismo, sem worktrees.

| Dev | Perfil | Foco |
|-----|--------|------|
| **Dev 1** | Backend Rails (controllers/concerns/tests) | **33.1 → 33.2 → 33.3 → 33.4 → 33.5** — **sequencial**. A ordem respeita a dependência entre Camada 1 (runtime) e Camada 2 (build). |

---

## Backlog

### Área — 1. Camada 1 (runtime): contrato de declaração de postura + guard fail-closed

#### Tarefa 33.1 — Contrato de declaração de postura + guard fail-closed no base (Camada 1, D1/D2/D3/D4)

- **User Story:** Como **time de engenharia do Frequência**, quero que **cada controller de frequência
  declare explicitamente sua postura** perante a cascata (`:coberto` ou `:dispensado` com justificativa) e
  que **quem não declarar seja barrado por padrão** em runtime, para que um controller novo que leia
  frequência **não passe silenciosamente** pelo `check_authorization` com um mero `authorize! :read, :all`.
- **Rastreabilidade:** **ADR-0010 regra 9**; artefato de aprovação §2.1 (contrato de declaração) + §7.1
  (D1/D2/D3/D4); `iteration_32.md` §32.O1; `bug_report_30_cobertura_cascata_bug-finder.md` (Bug 🔴1).
- **Estimativa:** **2 pontos** | **Atribuição:** Dev 1 | **Dependências:** **nenhuma** (primeira tarefa).
- **Arquivos tocados:**
  - `api-ponto/app/controllers/concerns/frequencia_authorization.rb` — adicionar `extend ActiveSupport::Concern`
    + hook `included do … end` que marca `self.cascata_postura = :coberto` (o `include` **é** o opt-in; os 7
    controllers que já incluem o concern passam a declarar **sem tocar seus corpos**).
  - `api-ponto/app/controllers/admin/application_controller.rb` — `class_attribute :cascata_postura, default: nil`;
    macro de classe `fora_da_cascata_justificativa(motivo)` (com `raise ArgumentError` se `motivo` blank);
    `before_action :verificar_postura_cascata` + o método do guard (fail-closed; lê a flag própria, abaixo).
  - **Novo** PORO de leitura da flag de enforcement — espelha `FrequenciaAutorizacaoCascata`
    (`api-ponto/app/models/frequencia_autorizacao_cascata.rb`), ponto **único** de leitura de
    `FREQUENCIA_CASCATA_ENFORCEMENT` (`log` | `raise`). Nome sugerido: `FrequenciaCascataEnforcement`
    (arquivo em `api-ponto/app/models/`). Default: **`raise` em test/CI** (gate duro); **`log` no 1º deploy**
    de produção.
  - Anotar a postura dos controllers `Admin::*` (ver critérios).
- **Escopo (o que ENTRA):**
  - Hook `included` no concern → `:coberto` (fonte única consumida por runtime **e** build).
  - Macro `fora_da_cascata_justificativa("…motivo…")` → `:dispensado` (motivo **obrigatório no código**).
  - Guard `verificar_postura_cascata` no `Admin::ApplicationController` (roda em toda action admin): se a
    classe **não** declarou postura → **WARN** no modo `log` ou **`raise CascataNaoDeclaradaError`** no modo
    `raise`. Se declarou (`:coberto` **ou** `:dispensado`) → **no-op**. O guard **exige DECLARAÇÃO**, não
    restringe leitura — com os controllers declarados é **no-op em produção, em qualquer estado da cascata**.
  - **Anotar todos os controllers `Admin::*`** para que o guard seja no-op: os **7 participantes** declaram
    via `include` (automático); os demais recebem `fora_da_cascata_justificativa("…")` explicitando por que
    estão fora (ex.: `dashboard` = corpo gateado por `current_user.admin?`; `estacoes`/`versoes`/`regimes`/
    `direitos_deveres`/`gestores_individuais`/`sessions` = não leem recursos de frequência). A base
    `Presenca::*` **não** herda o guard.
  - **Flag própria `FREQUENCIA_CASCATA_ENFORCEMENT`** (D2/R4) — **desacoplada** de
    `FREQUENCIA_AUTORIZACAO_CASCATA`. Família **LIGAR** (`raise`/`levantar`/`on`/`true`/`1`/`yes`/`enabled`/
    `ativo`/`strict`) → fail-closed; família **OBSERVAR** (`log`/`warn`/`avisar`/`observar`/`shadow`/`off`/
    `false`/`0`/`no`/`disabled`) → só WARN; **valor não reconhecido → fail-closed + WARN** (nunca
    fail-open silencioso). Ausente/vazio: **`raise` em test/CI** (gate duro), `log` fora. `CI` só liga se
    truthy (`1`/`true`).
- **Escopo (o que NÃO ENTRA):** tocar a `Ability` (D3); adotar `toca_frequencia only:[…]` por action (D4);
  restringir leitura de conteúdo (o guard só exige declaração); alterar regras da cascata/roles; commitar
  `config/environments/development.rb`.
- **Critérios de aceite (testáveis):**
  - [x] **Contrato:** um controller `Admin::*` que **não** declara postura, sob `FREQUENCIA_CASCATA_ENFORCEMENT=raise`,
    ao executar qualquer action → **levanta `CascataNaoDeclaradaError`**.
  - [x] **`log` ≠ `raise` (explícito):** o **mesmo** cenário sob `FREQUENCIA_CASCATA_ENFORCEMENT=log` →
    **NÃO levanta**, emite **um `Rails.logger.warn`** com o nome da classe. (É o único delta entre os dois
    modos; a mensagem é idêntica.)
  - [x] **Fail-closed em TODOS os estados da flag de cascata (D2):** o guard nega/avisa **independentemente**
    de `FREQUENCIA_AUTORIZACAO_CASCATA` (`:off`/`:shadow`/`:on`) — provado com a flag de cascata em cada um
    dos 3 estados.
  - [x] **No-op para quem declarou:** um controller `:coberto` e um `:dispensado` (com justificativa) **não**
    são afetados pelo guard em nenhum estado da flag de enforcement.
  - [x] **Macro exige justificativa:** `fora_da_cascata_justificativa("")`/`nil` → **`ArgumentError`**.
  - [x] **Cobertura de anotação:** **todo** controller `Admin::*` da árvore declara postura (nenhum deixa o
    guard levantar na suíte) — a base `Presenca::*` **não** é afetada.
  - [x] **`Ability` inalterada (D3):** `git diff` **não** mostra alteração em `api-ponto/app/models/ability.rb`.
  - [x] **Sem regressão:** suíte permanece **1235/4314/3F+12E/0 skip** (as 15 pré-existentes isoladas;
  +13 runs/+57 asserts = os testes novos da 33.1);
    RuboCop 0 offenses nos arquivos tocados; `zeitwerk:check` OK.
- **Status:** ✅ **Implementada (2026-10-15)** — Camada 1 (runtime) entregue no working tree (sem commit — `COMMIT_MODE=manual`).
  Contrato de postura (`:coberto`/`:dispensado`) + guard fail-closed (`verificar_postura_cascata`) + flag própria
  `FREQUENCIA_CASCATA_ENFORCEMENT` (`log`→`raise`); os **7** controllers participantes declaram `:coberto` via `include`
  e os **7** demais `Admin::*` recebem `fora_da_cascata_justificativa("…")`. Branch:
  `feat/sprint-33-camada-1-guard-cascata`. Arquivos: `api-ponto/app/controllers/concerns/frequencia_authorization.rb`,
  `api-ponto/app/controllers/admin/application_controller.rb`, os 7 controllers admin anotados,
  `api-ponto/app/models/frequencia_cascata_enforcement.rb` (novo),
  `api-ponto/app/models/cascata_nao_declarada_error.rb` (novo),
  `api-ponto/test/controllers/admin/cascata_enforcement_test.rb` (novo, 17 testes). Ver §"Notas de implementação (33.1)".
- **Fora do escopo desta tarefa:** o meta-teste de drift e os testes de conteúdo (33.2/33.3); o DRY (33.5).

### Área — 2. Camada 2 (build): meta-teste de drift (fecha a classe) + testes de conteúdo

#### Tarefa 33.2 — Meta-teste de drift com assert recíproco + prova do gate (Camada 2, D1/D4)

- **User Story:** Como **time de engenharia do Frequência**, quero que o **build falhe** sempre que um
  controller `Admin::*` leia um recurso de frequência **sem declarar postura**, para que a **classe** do
  Bug 🔴1 fique fechada **em qualquer estado da flag** (inclusive no `:off` de produção), onde a Camada 1
  não nega.
- **Rastreabilidade:** artefato de aprovação §2.2 (gate de CI) + §5 T1/T2/T3 + §7.1 (D1); ADR-0010 regra 9
  ("teste de conteúdo obrigatório por tela de listagem").
- **Estimativa:** **2 pontos** | **Atribuição:** Dev 1 | **Dependências:** **33.1** (o meta-teste **lê a mesma
  declaração** de postura que a Camada 1 introduz — fonte única, sem lista paralela; §0.5/R2).
- **Arquivos tocados:**
  - **Novo** `api-ponto/test/controllers/admin/cascata_cobertura_test.rb`.
  - **Novo** helper testável do detector de drift (ex.: `CoberturaCascata.detectores(lista_de_arquivos)`),
    em `api-ponto/test/support/` (ou dentro do próprio teste, se o projeto preferir).
- **Escopo (o que ENTRA):**
  - **Detector de drift:** varre `api-ponto/app/controllers/admin/**/*.rb`, coleta os arquivos que casam o
    conjunto fechado de recursos sensíveis — **`TimeRecord | CalculoDiario | RegistroMensalFrequencia |
    IntervencaoFrequencia | Pessoas::Vinculo`** (Q33-C = sim) — e **falha** se algum deles **não declarar**
    postura (`:coberto` ⟺ `include FrequenciaAuthorization`; `:dispensado` via
    `fora_da_cascata_justificativa`, com justificativa **não vazia**).
  - **Assert recíproco:** todo controller declarado `:coberto` **realmente** inclui o concern (remover o
    `include` → **falha**). Garante que a declaração não mente.
  - **Prova do gate (arquivo sintético):** teste unitário que passa ao detector um **arquivo "controller novo"
    sintético** que lê `TimeRecord` **sem** declarar → **rejeitado**. Prova executável de que o §2.2(1) pega
    um controller novo (T1).
  - **Flag-independente:** o meta-teste **não** lê a flag de cascata nem a de enforcement — vale em qualquer estado.
  - **Varredura RECURSIVA + classes reais (M1 do review 33.1):** o detector usa glob **recursivo**
    (`api-ponto/app/controllers/admin/**/*_controller.rb`) — **não** o glob top-level de um nível — e/ou
    localiza os subclasses por `Admin::ApplicationController.descendants` (eager-load em test), em vez de
    derivar a constante de `File.basename(...).camelize`. Fecha o falso-verde para um controller novo em
    subpasta ou que herde a base de fora de `app/controllers/admin/`.
  - **Excluir a base abstrata e ignorar comentários (M2 do review 33.1):** o detector **exclui**
    `application_controller.rb` (base abstrata, sem rotas) e **ignora linhas de comentário** — a base casa o
    conjunto por causa do menu (`permission_check: TimeRecord`, `application_controller.rb:214`) e
    `estacoes_controller.rb:4` casa por **comentário**; nenhum dos dois "lê" o recurso. Sobre-inclusão
    intencional deve ser **documentada**, não mascarar o critério.
  - **Justificativa lida em RUNTIME (M3 do review 33.1):** o detector lê a justificativa da dispensa via
    **`cascata_justificativa`** (persistida pela macro na 33.1) — **não** por grep/regex no texto-fonte.
    Exige `present?` de forma fiável; grep (`fora_da_cascata_justificativa(MOTIVO)`, heredoc, constante) fica
    frágil e é proibido como mecanismo de verificação.
- **Escopo (o que NÃO ENTRA):** testes de conteúdo por tela (é a 33.3); tocar a `Ability`; criar manifest
  paralelo de allow-list (a allow-list **lê a mesma declaração** de postura — §0.5/R2).
- **Critérios de aceite (testáveis):**
  - [x] **Controller novo sem declaração FALHA (T1):** detector recebe o arquivo sintético que lê `TimeRecord`
    sem declarar → **rejeitado** (o teste passa ao provar a rejeição).
  - [x] **Toda a árvore real declara postura (T2):** varredura recursiva de `app/controllers` — conjunto
    dos que casam os recursos sensíveis **⊆** declarados → **verde** (14 varridos, 6 sensíveis, 0 drift);
    introduzir um controller sensível sem postura → **vermelho**.
  - [x] **Recíproco (T3):** para cada `:coberto`, assert que a classe inclui `FrequenciaAuthorization`
    (`klass.include?`, runtime); um `:coberto` que não inclui o concern → **falha**.
  - [x] **Conjunto fechado e justificado:** o detector usa exatamente `TimeRecord | CalculoDiario |
    RegistroMensalFrequencia | IntervencaoFrequencia | Pessoas::Vinculo`.
  - [x] **Recursivo e por classe (M1):** um controller sensível criado em **subpasta** (`admin/<sub>/x_controller.rb`)
    ou que herde `Admin::ApplicationController` de **fora** de `admin/` → **vermelho** (glob recursivo +
    resolução da classe pela posição relativa do caminho). Provado com arquivo sintético em `Dir.mktmpdir`.
  - [x] **Base e comentários excluídos (M2):** o detector **não** acusa `application_controller.rb` (base
    abstrata — não é subclasse de si mesma) nem um recurso citado **em comentário** (caso real:
    `estacoes_controller.rb:4`).
  - [x] **Justificativa em runtime (M3):** um `:dispensado` sem `cascata_justificativa.present?` → **vermelho**;
    a checagem **não** usa grep/regex no texto-fonte (asserta o valor runtime — um texto que menciona a macro
    com justificativa, mas sem justificativa em runtime, é reprovado).
  - [x] **Sem regressão:** suíte **1256/4387/3F+12E** (as 15 pré-existentes isoladas; **17 testes** desta
    tarefa); RuboCop 0 offenses nos arquivos tocados; `zeitwerk:check` OK.
- **Status:** ✅ **Implementada (2026-10-15)** — Camada 2 (build) entregue no working tree (sem commit — `COMMIT_MODE=manual`).
  Detector `CoberturaCascata` (`api-ponto/test/support/cobertura_cascata.rb`) unit-testável com arquivos sintéticos +
  meta-teste `api-ponto/test/controllers/admin/cascata_cobertura_test.rb` (17 testes: T1/T2/T3, conjunto fechado,
  M1 recursivo/subpasta/**caminho**, M2 base+comentários, M3 runtime, flag-independente). Review **0 blockers**
  (`docs/quality/review_report_33_2.md`); Bug Finder **0 crítico** (`docs/quality/bug_report_33_2.md`); correções
  M1/M2/M4 + Bug 1/Bug 2 aplicadas; M3 = débito. Branch:
  `feat/sprint-33-camada-2-meta-teste-drift`. Ver §"Notas de implementação (33.2)".
- **Fora do escopo desta tarefa:** conteúdo das telas (33.3); DRY (33.5).

#### Tarefa 33.3 — Testes de conteúdo por tela (ausência do terceiro) + revisão de expectativa (Camada 2, D1)

- **User Story:** Como **time de engenharia do Frequência**, quero que as telas de listagem de frequência
  **assirtem a ausência do terceiro não-visível no corpo** de resposta (não só o HTTP 200), para que o
  furo que passou no teste de `users#index` (que sancionava o 200 sem asserir conteúdo) **não volte a passar**.
- **Rastreabilidade:** artefato de aprovação §2.2(3) + §3 (tabela de telas) + §5 T6 + §7.1 (D1).
- **Estimativa:** **2 pontos** | **Atribuição:** Dev 1 | **Dependências:** **33.1** (o concern/declaração
  precisa existir); independente da 33.2.
- **Arquivos tocados:**
  - `api-ponto/test/controllers/admin/cascata_cobertura_test.rb` (testes de conteúdo sob `:on`) e/ou
    ampliação dos testes existentes de cascata:
    `test/controllers/admin/{frequencia_cascata_controller_test,frequencia_matriz_aceite_test,authorization_matrix_test,time_records_anos_cascata_test,users_cascata_controller_test}.rb`.
  - **Revisão** de `test/controllers/admin/users_controller_test.rb` (o caso que sancionava o 200 do não-admin).
- **Escopo (o que ENTRA):** sob `:on`, com `Pessoas::Vinculo` stubado devolvendo um terceiro **não-visível**,
  assertar que `response.body` **NÃO** contém dado identificador do terceiro, tela a tela (§3 do plano):
  `/frequentadores`, `/users`, `/time_records#index`, `/frequencia`, `/frequencia_por_orgao`,
  `/relatorio_terceirizados`, `/parcial`, `/dashboard`. **Em `:off`/`:shadow` a cascata legitimamente mostra
  tudo / só loga** — as assertivas de restrição valem **apenas sob `:on`** (flag-independente é o 33.2).
- **Escopo (o que NÃO ENTRA):** alterar comportamento de runtime; ligar `:on` production-wide; testar
  `/presenca/*` (Bug 🟠2 = risco aceito).
- **Critérios de aceite (testáveis):**
  - [x] **Ausência do terceiro:** para cada tela de listagem acima, sob `:on`, o corpo de resposta **não**
    contém o identificador do terceiro não-visível (grão da matriz 29.8). Medido em
    `cascata_conteudo_test.rb` (9 testes, 40 assertivas). **Cobertura REAL por mutação** (review 33.3 —
    neutralizar `frequencia_cascata_ligada?`): **4 telas provam o filtro da cascata** —
    `/frequentadores`, `/users`, `/frequencia`, `/frequencia_por_orgao` (falham sob mutação);
    **`/time_records`** isola o terceiro pelo **escopo não-admin** (`where(user_id: current_user.id)`),
    que vale em qualquer estado da flag — **não** pela cascata (a contribuição da cascata ali é o dropdown
    de anos); **`/relatorio_terceirizados` e `/parcial`** **não têm fonte real** (`@registros = []`) — os
    asserts são **guarda de estado** (não provam a cascata; quebram quando a fonte chegar, forçando
    atualização); **`/dashboard`** guarda o **gate `current_user.admin?`**, não a cascata.
  - [x] **Contraste com `:off`/`:shadow`:** o mesmo terceiro **aparece** sob `:off` (paridade com hoje) —
    prova que a restrição é a cascata, não o stub. Medido (controle positivo dentro de cada teste) em
    `/frequentadores`, `/users` e `/frequencia` (nome presente em `:off`, ausente em `:on`); em
    `/frequencia_por_orgao`, o agregado conta o terceiro em `:off` (2) e o exclui em `:on` (1).
    **Exceção documentada (honesta):** em `/time_records` o terceiro não aparece em **nenhum** estado —
    o isolamento ali é do escopo NÃO-admin (`where(user_id: current_user.id)`), não da cascata; o teste
    registra a degenerescência em vez de forçar um contraste falso (a contribuição da cascata para essa
    tela é o dropdown de anos, coberto em `time_records_anos_cascata_test.rb`).
  - [x] **Revisão de `users_controller_test.rb`:** o caso que sancionava o **200 sem asserir conteúdo**
    (`"usuario nao-admin ainda pode listar usuarios (read baseline)"`, com stub VAZIO `stub_vinculos([])`)
    foi reescrito para `"usuario nao-admin lista usuarios mas NAO ve terceiro fora dos visiveis (conteudo
    sob :on)"` — assere conteúdo sob `:on` (`refute` do terceiro + presença do visível) **e** o contraste
    `:off`. Nenhuma expectativa antiga contraditória permanece. O helper `stub_vinculos` passou a **honrar
    `incluir_cpfs`** (espelha o contrato real), sem o que a assertiva seria degenerada.
  - [x] **Estabilidade:** os testes seguem o padrão de stub dos testes de cascata existentes (29.8/30.7);
    todo stub de método de classe usa `test/support/class_method_stub_helper.rb`
    (`com_metodo_de_classe_stubado` — **save/restore; nunca `remove_method`**); a flag
    `FREQUENCIA_AUTORIZACAO_CASCATA` é manipulada com o mesmo idioma (save/restore no `ensure`).
  - [x] **Sem regressão:** suíte medida **1265 runs / 4434 assertions / 3 failures + 12 errors / 0 skips**
    (as **15 pré-existentes** isoladas — inalteradas; **+9 runs / +47 assertivas** desta tarefa); RuboCop
    **0 offenses** nos arquivos tocados; `zeitwerk:check` **OK**.
- **Status:** ✅ **Implementada (2026-10-15)** — Camada 2 (build), testes de conteúdo por tela entregues no
  working tree (sem commit — `COMMIT_MODE=manual`). Arquivos: `api-ponto/test/controllers/admin/cascata_conteudo_test.rb`
  (novo, 9 testes / **41 assertivas** — tela a tela) e a **revisão** de
  `api-ponto/test/controllers/admin/users_controller_test.rb`. Review **0 blockers**
  (`docs/quality/review_report_33_3.md`); Bug Finder **0 crítico** (`docs/quality/bug_report_33_3.md`);
  correções A1/M1/B2 + Bug 1/Obs-2 aplicadas. Branch:
  `feat/sprint-33-camada-2-conteudo-por-tela`. Ver §"Notas de implementação (33.3)".
- **Fora do escopo desta tarefa:** o detector de drift (33.2); o DRY (33.5).

### Área — 3. Testes do guard de runtime + mutation testing

#### Tarefa 33.4 — Testes do guard runtime (`log` × `raise`) + mutation testing dos pontos de decisão

- **User Story:** Como **time de engenharia do Frequência**, quero **provas executáveis** de que o guard
  falha-closed no modo `raise` e apenas avisa no modo `log`, e que **cada mutação que neutraliza a decisão
  derruba um teste**, para que o guard não vire código morto.
- **Rastreabilidade:** artefato de aprovação §5 T4/T5 + §2.1 (fail-closed × fail-open) + §7.1 (D2).
- **Estimativa:** **1 ponto** | **Atribuição:** Dev 1 | **Dependências:** **33.1**.
- **Arquivos tocados:** **novo** `api-ponto/test/controllers/admin/cascata_enforcement_test.rb` (ou o arquivo
  do 33.2, se o projeto preferir concentrar).
- **Escopo (o que ENTRA):**
  - **T4 — fail-closed:** controller anônimo sem declaração + `FREQUENCIA_CASCATA_ENFORCEMENT=raise` → **levanta**.
  - **T5 — log:** mesmo cenário em `log` → **não levanta**, emite **WARN** (spy no `Rails.logger`).
  - **Mutation testing:** (i) neutralizar o guard (sempre no-op) ⇒ o teste T4 falha; (ii) remover o hook
    `included` do concern ⇒ os controllers `:coberto` deixam de declarar ⇒ T2/33.2 falha; (iii) trocar o
    predicado da flag (`log`/`raise`) ⇒ T5 falha.
- **Escopo (o que NÃO ENTRA):** testes de conteúdo (33.3); drift de rota/CI além do guard.
- **Critérios de aceite (testáveis):**
  - [ ] T4 e T5 verdes; reproduzem o delta `log` × `raise` (única diferença: levantar × WARN).
  - [ ] As 3 mutações acima derrubam, cada uma, o teste correspondente (não-vacuidade provada).
  - [ ] **Sem `remove_method`:** stubs de ENV/logger via `test/support/class_method_stub_helper.rb`
    (save/restore no `ensure`).
  - [ ] **Sem regressão:** suíte permanece **1265/4434/3F+12E/0 skip** (as 15 isoladas) — **piso CORRENTE**
    (o pré-sprint aprovado era 1222/4257; as 33.1–33.3 somaram +43 runs/+177 assertivas); RuboCop/Zeitwerk OK.
- **Status:** ⬜ Pendente

### Área — 4. DRY correlato (D5)

#### Tarefa 33.5 — DRY `incluir_cpfs_com_cascata` → concern `FrequenciaAuthorization` (D5)

- **User Story:** Como **time de engenharia do Frequência**, quero que o helper `incluir_cpfs_com_cascata`
  (hoje **duplicado texto-idêntico**) viva no home natural — o concern `FrequenciaAuthorization` —, para
  que o mecanismo da cascata tenha **um só lugar** (§ADR-0010 regra 9, "DRY correlato").
- **Rastreabilidade:** artefato de aprovação §2.4 (débito DRY) + §7.1 (D5); ADR-0010 regra 9;
  `review_report_fix_cascata_cobertura.md` S1; `iteration_32.md` §32.O1.
- **Estimativa:** **1 ponto** | **Atribuição:** Dev 1 | **Dependências:** **33.1** (o concern é tocado por
  ambas; mesma superfície de mudança).
- **Arquivos tocados:**
  - `api-ponto/app/controllers/concerns/frequencia_authorization.rb` — recebe o método extraído.
  - `api-ponto/app/controllers/admin/users_controller.rb` — **remover** a cópia local
    (`incluir_cpfs_com_cascata`, hoje em ~L114) e usar a do concern.
  - `api-ponto/app/controllers/admin/frequentadores_controller.rb` — **remover** a cópia local
    (`incluir_cpfs_com_cascata`, hoje em ~L88) e usar a do concern.
- **Escopo (o que ENTRA):** extrair o método privado **texto-idêntico** das duas cópias para o concern,
  **behavior-preserving** (mesma lógica de `cpfs_exigidos_pelos_filtros_locais` × `frequentadores_visiveis_cpfs`).
  Os helpers dos quais ele depende (`frequencia_cascata_ligada?`, `frequencia_visao_global?`,
  `frequentadores_visiveis_cpfs`) **já vivem no concern** — a extração é possível sem mover mais nada.
- **Escopo (o que NÃO ENTRA):** alterar a semântica do helper; mover outros métodos; tocar `cpfs_*` locais
  que não fazem parte do método.
- **Critérios de aceite (testáveis):**
  - [ ] **Behavior-preserving:** suíte de `/frequentadores` e `/users` **verde antes e depois**, com
    expectativas inalteradas; o comportamento do helper é idêntico (mesma saída para os mesmos params).
  - [ ] **Sem duplicação:** `grep -rn "def incluir_cpfs_com_cascata"` retorna **1** ocorrência (no concern).
  - [ ] **Sem regressão:** suíte permanece **1265/4434/3F+12E/0 skip** (as 15 isoladas) — **piso CORRENTE**
    (o pré-sprint aprovado era 1222/4257); RuboCop 0 offenses; `zeitwerk:check` OK.
- **Status:** ⬜ Pendente
- **Fora do escopo desta tarefa:** qualquer mudança de autorização (é refatoração pura).

---

## Requisitos de teste (transversais — valem como critério de aceite de todas as tarefas)

1. **Isolar as 15 pré-existentes** do baseline **1222/4257/3F+12E/0 skip** (11× Devise `redirect_to` +
   1× timezone em `PresencaEndpointsTest` + 1× order-dependent do espelho). **As 15 NÃO são regressão**
   desta sprint — medição serial + seeds (1/7/42/6000) quando houver order-dependence.
2. **NUNCA `remove_method`:** todo stub de método de classe/produção usa
   `test/support/class_method_stub_helper.rb` (save/restore no `ensure`) — lição herdada.
3. **Flag-independente × flag-dependente:** o **meta-teste de drift (33.2)** e o **guard (33.1)** são
   **flag-independentes** (valem em `:off`/`:shadow`/`:on`); os **testes de conteúdo (33.3)** asseguram a
   restrição **apenas sob `:on`**.
4. **O guard exige DECLARAÇÃO, não restringe conteúdo:** nenhum teste deve esperar que a Camada 1 filtre
   listagens — o filtro é da cascata (29.7/29.8); o guard só garante que a cascata **foi declarada**.
5. **`Ability` intocada (D3):** nenhum teste novo altera `ability.rb`; qualquer diff na `Ability` é blocker.
6. **Mutation testing** sobre os pontos de decisão do guard (33.4) — não-vacuidade provada.
7. **4 quadrantes de `ativo` preservados** (ativo/ativo, ativo/inativo, inativo/ativo, inativo/inativo) — a
   cascata **consome** `Pessoas::Vinculo.ativos`/`GestorIndividual.ativos` (ADR-0008; passo 4); o enforcement
   novo **não** altera essa semântica (`structural-conformity-checklist`). Referência: par explícito da 30.6
   (`frequentadores_visiveis_test.rb`, GI inativo).

## Compatibilidade e rollback

- **Default seguro:** o guard, com todos os controllers declarados, é **no-op em produção, em qualquer
  estado da cascata**. O rollout começa em **`log`** no 1º deploy (só WARN); após um ciclo sem WARN, o dev
  **flipa para `raise`**.
- **Kill-switch (runtime):** `FREQUENCIA_CASCATA_ENFORCEMENT` **rebaixa** o gate sem reverter código.
  - **LIGAR** o fail-closed: `raise`/`levantar`/`on`/`true`/`1`/`yes`/`enabled`/`ativo`/`strict` → `:raise`.
  - **OBSERVAR** (só `Rails.logger.warn`, não levanta): `log`/`warn`/`avisar`/`observar`/`shadow`/`off`/
    `false`/`0`/`no`/`disabled` → `:log`.
  - **Valor NÃO reconhecido → fail-closed** (`:raise` + um WARN alto). **Não há fail-open silencioso**: um
    valor ambíguo nunca desliga o gate por engano (corrige o `on`/`true`/`1` que antes caíam em `:log` —
    `bug_report_33_1`). Case/whitespace não importam.
  - **Ausente/vazio:** `:raise` em test/CI; `:log` nos demais ambientes (1º deploy de produção). `CI` só
    conta como ligado se **truthy** (`1`/`true`) — `CI=false`/`CI=0` não forçam `:raise`.
- **Rollback da Camada 1:** remover o `before_action`/macro + o hook `included` do concern → volta ao estado
  atual. **Reversível em um commit.**
- **Rollback da Camada 2:** `git revert` dos arquivos de teste — **zero** risco de produção.
- **Nenhuma migration/schema/rota** → sem risco de dados nem de deploy. Aditivo.

## Caminho Crítico

```
33.1 (Camada 1: contrato + guard + flag)  ──>  33.2 (Camada 2: meta-teste de drift)
        │                                             │
        ├──> 33.3 (testes de conteúdo por tela)       │
        ├──> 33.4 (testes do guard log×raise + mutation)
        └──> 33.5 (DRY D5 — mesma superfície do concern)
```
- **Sequencial (1 dev):** 33.1 precede 33.2/33.3/33.4/33.5 (todas dependem da declaração de postura
  introduzida em 33.1). 33.2 e 33.3 são independentes entre si; 33.5 é independente das demais (só o
  concern é tocado).

## Riscos

- **Guard em `raise` e um controller admin escapa da anotação → erro em produção.** Sev. 🟠. **Mitigação:**
  ship em **`log` primeiro**; anotar todos os controllers `Admin::*` na mesma tarefa (33.1); a suíte
  (33.2/T2) pega antes do deploy.
- **Meta-teste de grep evadido por indireção** (lê `TimeRecord` via service/model intermediário). Sev. 🟡.
  **Mitigação:** os testes de conteúdo (33.3) cobrem o **efeito**, não só a fonte; o limite é declarado.
- **Testes de conteúdo instáveis por stub entre 2 bancos** (Pessoas × primário). Sev. 🟡. **Mitigação:**
  seguir o padrão dos testes de cascata existentes (29.8/30.7); `class_method_stub_helper`.
- **Confundir as 15 pré-existentes com regressão.** Sev. 🟡. **Mitigação:** isolamento obrigatório (§Req. teste 1).
- **Escopo escorregar para o Bug 🟠2 / ligar `:on`.** Sev. 🟡. **Mitigação:** §"Fronteira explícita" — ambos **fora**.
- **Blast-radius de anotação "comporta" ~15 controllers `Admin::*`.** Sev. 🟢. Mecânico; 1 linha por controller; revisável.

## Débitos Técnicos

- [ ] **Enforcement opt-in da cascata** (ADR-0010 regra 9) — causa-raiz do Bug 🔴1. **TAREFA DESTA SPRINT
  (33.1–33.4).** Severidade: 🟠 — Tarefa: 33.1, 33.2, 33.3, 33.4.
- [ ] **DRY `incluir_cpfs_com_cascata`** — duplicado em `frequentadores_controller` (~L88) + `users_controller`
  (~L114); home natural = concern `FrequenciaAuthorization` (ADR-0010 regra 9; `review_report_fix_cascata_cobertura.md` S1).
  **PUXADO NESTA SPRINT (D5).** Severidade: 🟡 — Tarefa: 33.5.
- [ ] **Consolidação durável da decisão (ADR)** — a decisão de **como/onde** enforce a cascata deve virar ADR
  (**emenda à ADR-0010 regra 9/10** **ou** **ADR-0012**). **Decisão POSTERIOR à implementação** (§7.1 / §8 do
  plano) — **não criar agora**. Severidade: 🟡 — Tarefa: (pós-33).
- [ ] **Bug 🟠2 (`/presenca/*` sem autenticação)** — **risco aceito** (ADR-0010 §Notas); gatilho = fim dos
  testes manuais da Estação. **Fora do escopo da 33.** Severidade: 🟠 (aceito) — Tarefa: fora.
- [ ] **Bypass do guard via `skip_before_action :verificar_postura_cascata`** (M3 do review 33.2; Obs. 1 do
  `bug_report_33_1`) — um controller admin pode **desligar** o guard da Camada 1 numa linha, e nem a Camada 1
  nem o meta-teste de drift (33.2) **detectam** isso (a 33.2 não lê a cadeia de callbacks). Hoje **nenhum**
  controller usa esse skip (verificado). Mitigação possível: a Camada 2 passar a assertar que nenhum
  `Admin::*` faz `skip_before_action :verificar_postura_cascata`. **Severidade: 🟡 — Tarefa: 33.x / pós-33.**
- [ ] *(Herdados, NÃO reabertos nesta sprint)* TOCTOU residual de mês finalizado; staleness pré-existente na
  virada; crash-window do despacho — ver `iteration_32.md` §Débitos. Severidade: 🟢/⚪ — Tarefa: fora.

## Quadro de tarefas (resumo)

| Tarefa | Área | Pontos | Dependência | Natureza | Status |
|--------|------|--------|-------------|----------|--------|
| **33.1** | Camada 1 — contrato de postura + guard fail-closed (runtime) | **2** | nenhuma | código (toca autorização) | ✅ Implementada (2026-10-15) |
| **33.2** | Camada 2 — meta-teste de drift + assert recíproco (build) | **2** | **33.1** | testes | ✅ Implementada (2026-10-15) |
| **33.3** | Camada 2 — testes de conteúdo por tela + revisão de expectativa | **2** | **33.1** | testes | ✅ Implementada (2026-10-15) |
| **33.4** | Guard runtime `log` × `raise` + mutation testing | **1** | **33.1** | testes | ⬜ Pendente |
| **33.5** | DRY `incluir_cpfs_com_cascata` → concern (D5) | **1** | **33.1** | refatoração (behavior-preserving) | ⬜ Pendente |

**Total comprometido:** **8 pontos** (dentro da faixa aprovada **5–8 pt**). **1 dev, execução sequencial.**

## Definição de Pronto

- [ ] **Aval do dev registrado** (§7.1 do artefato de aprovação) — ✅ **SATISFEITO (2026-10-15)**; o Code
  Specialist está liberado.
- [ ] 33.1 implementada: contrato de postura (`:coberto`/`:dispensado`) + guard fail-closed + flag própria
  `FREQUENCIA_CASCATA_ENFORCEMENT` (`log`→`raise`); **todos** os controllers `Admin::*` com postura declarada.
- [ ] 33.2 implementada: meta-teste de drift (conjunto `TimeRecord | CalculoDiario | RegistroMensalFrequencia |
  IntervencaoFrequencia | Pessoas::Vinculo`), **assert recíproco** e **prova do gate** com arquivo sintético.
- [ ] 33.3 implementada: testes de conteúdo por tela (ausência do terceiro sob `:on`) + `users_controller_test.rb`
  revisado (não sanciona mais o 200 sem asserir conteúdo).
- [ ] 33.4 implementada: guard `log` × `raise` provado + mutation testing dos pontos de decisão.
- [ ] 33.5 implementada: `incluir_cpfs_com_cascata` **único** (no concern); behavior-preserving.
- [ ] **Sem regressão:** suíte **1265/4434/3F+12E/0 skip** com as **15 pré-existentes isoladas** (piso
  **CORRENTE**, medido após 33.1–33.3; o **pré-sprint aprovado** era 1222/4257/3F+12E); RuboCop 0
  offenses nos arquivos tocados; `zeitwerk:check` OK.
- [ ] **`Ability` inalterada (D3)**; **`db/schema.rb` inalterado**; **nenhuma rota alterada**; nenhuma
  migration; **nenhuma ADR nova criada**.
- [ ] **Débito estrutural registrado** como resolvido/em-resolução na governança (a consolidação em ADR fica
  **pós-implementação**).
- [ ] **Nenhuma decisão de produto reaberta** (flag de cascata continua `:off`/`:shadow`; Q16 da 30 intacta;
  Bug 🟠2 = risco aceito).
- [ ] Commit/push pelo **dev** (`COMMIT_MODE=manual`) — o agente **não** commita/pusha; **não** commitar
  `config/environments/development.rb`.

## Perguntas abertas ao dev / PO

- **Q33-A (GATE) — ✅ RESOLVIDA (dev, 2026-10-15):** design **aprovado como recomendado, integralmente**
  (§7.1 do artefato de aprovação) — D1=Camadas 1+2; D2=fail-closed em todos os estados com `log`→`raise`;
  D3=não tocar `Ability`; D4=não adotar `toca_frequencia` por action.
- **Q33-B (DRY) — ✅ RESOLVIDA (dev, 2026-10-15):** **puxar nesta sprint** (D5 = sim, +1 pt) — é a mesma
  superfície do concern. **Tarefa 33.5.**
- **Q33-C (incluir `Pessoas::Vinculo`) — ✅ RESOLVIDA (dev, 2026-10-15):** **sim** — o conjunto fechado do
  meta-teste (33.2) inclui `Pessoas::Vinculo`.
- **Q33-D (nome da classe do guard/flag):** `CascataNaoDeclaradaError` e `FrequenciaCascataEnforcement` são
  **sugestões**; o Code Specialist pode ajustar ao estilo do projeto (nomes de arquivos em `app/models/`,
  espelhando `FrequenciaAutorizacaoCascata`), sem mudar a semântica. **Não bloqueia.**

---

## Notas de reconciliação (plano aprovado × código real, 2026-10-15)

> Divergências de **caminho/símbolo** encontradas ao confirmar o código real antes de detalhar. **Nada do
> escopo/decisões é afetado** — apenas a localização dos arquivos a tocar é corrigida para o real.

1. **PORO `AutorizacaoFrequencia`:** o plano e o briefing referem `api-ponto/app/services/autorizacao_frequencia.rb`.
   **Real:** `api-ponto/app/models/autorizacao_frequencia.rb`. Idem `FrequenciaAutorizacaoCascata` →
   **`api-ponto/app/models/frequencia_autorizacao_cascata.rb`** (é de `app/models/`, não `app/services/`). A
   **nova** classe da flag de enforcement deve seguir o **mesmo diretório real** (`app/models/`).
2. **Concern `FrequenciaAuthorization`:** hoje é um **módulo simples** (`module FrequenciaAuthorization` com
   `private`), **não** um `ActiveSupport::Concern` — **não** possui o hook `included do … end`. A 33.1 precisa
   **adicionar** `extend ActiveSupport::Concern` + o hook, como o §2.1 do plano já prevê. É uma adição (aditiva),
   não uma reescrita.
3. **`incluir_cpfs_com_cascata` (D5):** confirmado duplicado **texto-idêntico** em
   `users_controller.rb:114` e `frequentadores_controller.rb:88` — exatamente o débito do §2.4. O helper
   depende de `cpfs_exigidos_pelos_filtros_locais` (local de cada controller) e de
   `frequencia_cascata_ligada?`/`frequencia_visao_global?`/`frequentadores_visiveis_cpfs` (já no concern) —
   a extração é viável **sem** mover os `cpfs_*` locais. (O método extraído para o concern pode precisar
   receber/consultar `cpfs_exigidos_pelos_filtros_locais`; o Code Specialist decide a forma no estilo do projeto.)
4. **ADR-0010 regra 9 — texto parcialmente defasado:** a regra 9 afirma que, sob `:on`, "`can?(:read,
   TimeRecord)` por CLASSE seguem `true`". O **código real** (`ability.rb:136-137`, `deny_frequencia_baseline!`)
   faz `cannot :read, recurso` para cada `RECURSOS_FREQUENCIA` — ou seja, **por CLASSE** a leitura É negada
   sob `:on`. É a **mesma correção** já registrada na **§0.1 do plano** ("o que permanece passando é o `:all`,
   o símbolo"). **Não** alteramos a ADR (frozen); a consolidação fica para a decisão pós-implementação (§8).
5. **Conjunto fechado confirmado:** `RECURSOS_FREQUENCIA` (`ability.rb:74-79`) = `TimeRecord`, `CalculoDiario`,
   `RegistroMensalFrequencia`, `IntervencaoFrequencia`; **`Pessoas::Vinculo`** entra por Q33-C (não é model
   CanCan — é o roster do espelho Pessoas).
6. **7 controllers participantes confirmados** por `grep -l "include FrequenciaAuthorization"`:
   `frequencia`, `frequencia_por_orgao`, `frequentadores`, `parcial`, `time_records`, `relatorio_terceirizados`,
   `users`. A base `Presenca::*` **não** herda o `Admin::ApplicationController` (guard não a alcança).

## Linha do Tempo

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
| 2026-10-15 | **Sprint Planner reescreve o `iteration_33.md`** estritamente alinhado ao artefato de aprovação (§7.1, D1–D5/Q33-C); código real confirmado (symbols/caminhos) | **5 tarefas**, **8 pts**, 1 dev sequencial; banner ✅ ALINHADO; rascunho anterior **superseded** |
| 2026-10-15 | **Code Specialist implementa a 33.1** (Camada 1 — contrato de postura + guard fail-closed + flag própria `FREQUENCIA_CASCATA_ENFORCEMENT`) no working tree; **sem commit** (`COMMIT_MODE=manual`) | Suíte **1235/4314/3F+12E/0 skip** (as 15 pré-existentes; +13 testes novos); RuboCop 0; zeitwerk OK; `ability.rb` intocado |
| 2026-10-15 | **Code Reviewer** na 33.1 (`docs/quality/review_report_33_1.md`) | **0 blockers / 0 high**; 4 🟡 + 1 ⚪ + 2 💡 (M1–M4; B1; S1/S2) |
| 2026-10-15 | **Bug Finder** na 33.1 (`docs/quality/bug_report_33_1.md`) | **0 crítico / 0 alto**; 2 🟡 (BF-M1 herança de postura; BF-M2 kill-switch fail-open) + 1 🟢 + 3 ⚪ |
| 2026-10-15 | **Correções aplicadas** (M3, M4, S2, BF-M1, BF-M2, BF baixo) no working tree; **sem commit** | `cascata_justificativa` persistida; postura **não herdada** (`inherited`); flag **fail-closed** p/ valor ambíguo; `CI` só truthy; doc do kill-switch alinhada — teste da 33.1 **17/87/0F/0E**; área admin **255/1363/0F/0E**; RuboCop 0 |
| 2026-10-15 | **Code Specialist implementa a 33.2** (Camada 2 — detector de drift `CoberturaCascata` + meta-teste) no working tree; **sem commit** (`COMMIT_MODE=manual`) | Detector **15/39/0F/0E**; árvore real **14 varridos / 6 sensíveis / 0 drift**; suíte **1254/4383/3F+12E/0 skip** (as 15 pré-existentes; +15 runs/+39 assertivas); RuboCop 0; zeitwerk OK; `ability.rb` intocado |
| 2026-10-15 | **Code Reviewer** na 33.2 (`docs/quality/review_report_33_2.md`) — com **teste de mutação** (removeu `include` real, criou `admin/sub/` → meta-teste falhou = não tautológico) | **0 blockers / 0 high**; 4 🟡 (M1 caminho; M2 lista paralela; M3 skip não detectado; M4 comentário inline) + 4 ⚪ + 3 💡 |
| 2026-10-15 | **Correções aplicadas** (M1, M2, M4; M3 → débito) no working tree; **sem commit** | `RECURSOS_SENSIVEIS` **deriva da Ability** (fim da lista paralela); varredura também por **caminho** (`admin/**`); comentário inline documentado; débito do `skip_before_action` registrado — meta-teste **16/51/0F/0E** |
| 2026-10-15 | **Bug Finder** na 33.2 (`docs/quality/bug_report_33_2.md`) | **0 crítico**; **1 🟠 + 1 🟡** (Bug 1: `declarado?` levantava `NoMethodError` p/ classe retida por caminho; Bug 2: o teste de caminho não exercia o critério — stub herdava a base admin) — ambos **defeitos do conserto M1** |
| 2026-10-15 | **Correções Bug 1/Bug 2 + assert não-tautológico** no working tree; **sem commit** | `declarado?` trata "sem `cascata_postura`" como drift; stub usa `::ApplicationController`; assert do conjunto fechado voltou a ser literal — **mutação provou** a cobertura do caminho; meta-teste **17/43/0F/0E**; suíte **1256/4387/3F+12E**; RuboCop 0 |
| 2026-10-15 | **Code Specialist implementa a 33.3** (Camada 2 — testes de conteúdo por tela + revisão de `users_controller_test.rb`) no working tree; **sem commit** (`COMMIT_MODE=manual`) | Novo `cascata_conteudo_test.rb` **9/37/0F/0E** tela a tela; `users_controller_test.rb` revisado (caso do 200-sem-conteúdo agora assere conteúdo sob `:on`); suíte **1265/4430/3F+12E/0 skip** (as 15 pré-existentes; +9 runs/+43 assertivas); RuboCop 0; zeitwerk OK; `ability.rb`/`schema.rb`/rotas intocados |
| 2026-10-15 | **Code Reviewer** na 33.3 (`docs/quality/review_report_33_3.md`) — **teste de mutação** por tela (neutralizou `frequencia_cascata_ligada?`) | **0 blockers**; **1 🟠** (A1: `/relatorio_terceirizados` e `/parcial` com assert **vacuamente verdadeiro**); 2 🟡 (M1 `/time_records` degenerado; M2 relato 15/52 ≠ 9/32) + 2 ⚪ + 1 💡. **Só 4/8 telas provam o filtro da cascata** |
| 2026-10-15 | **Correções A1/M1/B2 aplicadas** no working tree; **sem commit** | Placeholders renomeados + assert de estado (`/parcial` assere o *empty-state*, não-vácuo) + TO-DO; `/time_records` e `/dashboard` renomeados para o que de fato guardam; afirmação inflada "8 telas" corrigida no doc — `cascata_conteudo_test.rb` **9/40/0F/0E**; suíte **1265/4433/3F+12E**; RuboCop 0 |
| 2026-10-15 | **Bug Finder** na 33.3 (`docs/quality/bug_report_33_3.md`) | **0 crítico / 0 alto**; **1 🟡** (Bug 1: `/frequencia_por_orgao` **cego a SUBSTITUIÇÃO** — mutação `cpfs = visíveis` passava) + 3 ⚪; **corrigiu o review** (B1: `assert_select text:` é igualdade EXATA, não substring) |
| 2026-10-15 | **Correções Bug 1 + Obs-2 aplicadas** no working tree; **sem commit** | `/frequencia_por_orgao` ganha **visível de outro órgão** (mutação `cpfs = visíveis` agora **falha**: 1≠2); `/time_records` ganha ator **com CPF visível a si** (stub de login Pessoas) + assert contra empty-state — `cascata_conteudo_test.rb` **9/41/0F/0E** (estável em seeds 1/999); suíte **1265/4434/3F+12E**; RuboCop 0 |

## Notas de implementação (33.1) — plano × código real

> Divergências de **símbolo/caminho/alcance** encontradas ao implementar. **Nada do escopo/decisões D1–D5/Q33-C
> foi alterado.**

1. **O concern tem um 8º includer (host de teste).** O `iteration_33.md` e o §0.3 do plano falam só dos **7
   controllers `Admin::*`** que incluem `FrequenciaAuthorization`. O `grep` real mostra um **8º includer fora
   do contexto admin**: `Intranet::MigrarRolesCascataServiceTest::HostComCascata`
   (`api-ponto/test/services/intranet/migrar_roles_cascata_service_test.rb:68`) — host de teste que exercita
   `restringir_frequencia` sem controller. Consequência: o hook `included do … end` **declara**
   `class_attribute :cascata_postura, default: nil` **antes** de marcar `:coberto` (fiel ao esqueleto do §2.1
   do plano), tornando o concern **autossuficiente** — sem isso, o host de teste quebra com `NoMethodError`
   (`cascata_postura=` indefinido). O guard é **no-op** para o host (não é controller roteado).
2. **A base `Admin::ApplicationController` NÃO declara postura** (default `nil`) — de propósito: é abstrata
   (sem rotas/actions) e, se declarasse, o `class_attribute` herdado tornaria `:dispensado`/`:coberto`
   visível a **todos** os subclasses, anulando o guard. Cada controller concreto declara a sua.
3. **`fora_da_cascata_justificativa` PERSISTE o motivo** (`class_attribute :cascata_justificativa`) além de
   setar `:dispensado` — **correção do achado M3 do review 33.1** (o esqueleto do §2.1 só validava `blank?`).
   Com isso o meta-teste de drift (33.2) exige justificativa **não vazia** lendo o valor **em runtime**, sem
   heurística de grep no texto-fonte (`fora_da_cascata_justificativa(MOTIVO)`, heredoc, constante).
4. **Retorno do guard no modo `log`:** `return Rails.logger.warn(msg)` devolve o retorno de `Logger#warn`
   (truthy), **não** `nil`; no modo `raise` levanta; para `:coberto`/`:dispensado` retorna `nil`. Detalhe
   irrelevante para o contrato (o before_action só importa pelo efeito colateral), mas registrado.
5. **Local arquivos novos (segue o real):** PORO `FrequenciaCascataEnforcement` e o erro `CascataNaoDeclaradaError`
   vivem em `api-ponto/app/models/` (mesmo diretório real do irmão `FrequenciaAutorizacaoCascata`; **não** há
   `app/services/` nem `app/errors/` no projeto). `CascataNaoDeclaradaError` é **top-level** (não namespaced),
   como o esqueleto do §2.1 o referencia sem qualificação.
6. **Nenhum controller `Admin::*` deixa o guard levantar na suíte:** os 14 controllers concretos declaram
   postura (7 `:coberto` via `include`, 7 `:dispensado` via macro). A base `Presenca::*` **não** herda
   `Admin::ApplicationController` e **não** responde a `cascata_postura` (provado por teste).
7. **Sem alteração** em `ability.rb` (D3 — `git diff` vazio), `db/schema.rb`, rotas ou migrations; nenhuma
   dependência nova; nenhuma ADR nova. Nada commitado/pushado (`COMMIT_MODE=manual`).
8. **Postura NÃO é herdada por subclasse de concreto** (correção do achado **BF-M1** do Bug Finder 33.1). Um
   controller novo criado por `class X < Admin::AlgumConcreto` herdava a postura do pai — e, no eixo
   `:dispensado`, até a **justificativa alheia** (falso-verde; a 33.2 via `descendants` daria verde errado).
   Corrigido com `self.inherited(subclasse)` na base, que **zera** `cascata_postura`/`cascata_justificativa`
   em toda subclasse: a postura é decisão **por classe**, nunca herdada.
9. **Kill-switch passou a falhar-CLOSED para valor ambíguo** (correção do achado **BF-M2**). Antes, só
   `raise`/`levantar` ligavam — `on`/`true`/`1`/`yes`/`enabled` caíam em `:log` (fail-open **silencioso**, uma
   armadilha de confiança falsa num gate de autorização). Agora há famílias explícitas **LIGAR**/**OBSERVAR** e
   **valor não reconhecido → `:raise` + um WARN alto**. O baixo (BF) também foi corrigido: `CI` só conta como
   ligado se **truthy** (`1`/`true`) — `CI=false`/`CI=0` não forçam `:raise`. Ver §"Compatibilidade e rollback".

## Notas de implementação (33.2) — plano × código real

> Divergências de **caminho/símbolo/alcance** encontradas ao implementar. **Nada do escopo/decisões
> D1–D5/Q33-C foi alterado.**

1. **Raiz da varredura é `app/controllers/**` (superset), não `app/controllers/admin/**`.** O §2.2 do plano e o
   briefing falam em varrer `app/controllers/admin/**/*.rb`. O detector varre `app/controllers/**/*_controller.rb`
   **recursivamente** e retém um arquivo por **dois** critérios (**correção M1 do review 33.2**): (a) a classe
   **herda** `Admin::ApplicationController` (`klass < …`, ancestralidade) **ou** (b) o arquivo **vive sob
   `admin/`** (critério por **CAMINHO** — pega um controller admin que *não* herde a base e que, só por
   ancestralidade, escaparia). Arquivo que não resolve a constante também é retido (fail-safe).
   A base abstrata (`application_controller.rb`) e as bases `Presenca::*`/`Users::*` são excluídas.
2. **Resolução da classe pela POSIÇÃO relativa do caminho** (não por `File.basename(...).camelize`, como M1
   proíbe). `admin/sub/x_controller.rb` → `Admin::Sub::XController`. `descendants` foi **descartado** como
   mecanismo primário: medido no ambiente, `Admin::ApplicationController.descendants` é **vazio** em test local
   (`config.eager_load = ENV["CI"].present?` → `false` sem `CI`), o que daria **falso-verde**; a resolução por
   `safe_constantize` do caminho relativo **carrega** cada controller (determinística em qualquer ambiente).
3. **O helper vive em `test/support/cobertura_cascata.rb` e é carregado pelo `require_relative` do próprio
   meta-teste.** `test/support/` **não** é autoloaded neste projeto (só `pessoas_espelho_helper` e
   `class_method_stub_helper` são `require`-ados no `test_helper.rb`). **Não** alterei o `test_helper.rb` —
   mantive o footprint mínimo e o helper autossuficiente (não acopla a suíte inteira).
4. **Conjunto fechado confirmado na árvore real:** 14 controllers varridos; **6 sensíveis** (`frequencia`,
   `frequencia_por_orgao`, `frequentadores`, `time_records`, `users` = `:coberto`; `dashboard` = `:dispensado`,
   pois lê `TimeRecord` em código real sob o gate `current_user.admin?`); **0 drift**. `parcial` e
   `relatorio_terceirizados` são `:coberto` mas **não** sensíveis (sem fonte real hoje) — continuam cobertos pelo
   assert recíproco (T3).
5. **M2 medido:** `estacoes_controller.rb` casa o conjunto **só por comentário** → `sensivel?` = `false`;
   `dashboard_controller.rb` casa em **código** (linhas 26-28) → `sensivel?` = `true` mas **declarado**
   (`:dispensado` + justificativa) → não é drift. A base abstrata (`application_controller.rb`, menu em
   `permission_check: TimeRecord`) é excluída por não ser subclasse de si mesma.
6. **M3 medido sem grep:** um `:dispensado` cujo texto-fonte **menciona** `fora_da_cascata_justificativa("…")`
   mas cuja `cascata_justificativa` em runtime é `nil` → **reprovado** (o teste passa ao provar que a checagem lê
   o atributo runtime, não o texto). O `:dispensado` legítimo (macro da 33.1, justificativa persistida) é aceito.
7. **`RECURSOS_SENSIVEIS` agora DERIVA da fonte única** (correção **M2 do review 33.2**):
   `Ability::RECURSOS_FREQUENCIA.map(&:name) + ["Pessoas::Vinculo"]` — **nenhuma lista paralela**. Um recurso
   novo na `Ability` (regra do §0.5/R2) passa a ser coberto pelo detector **automaticamente**.
8. **Sobre-inclusão de comentário-no-fim-da-linha é INTENCIONAL** (correção **M4 do review 33.2**): só linhas
   de comentário **inteiras** são descartadas; um recurso citado em comentário no fim de uma linha de código
   conta como sensível — direção fail-closed (prefere acusar de mais a deixar passar). Redação alinhada no
   helper.
9. **Novo teste M1 por CAMINHO:** um controller sob `admin/**` que **não** herda a base admin é retido pela
   varredura (provado com diretório temporário + classe-stub). Fecha o falso-negativo que o review apontou.
   O **M3 do review** (`skip_before_action :verificar_postura_cascata` não detectado) ficou registrado como
   **débito** em §"Débitos Técnicos" (não corrigido nesta tarefa).
10. **Bug 1 e Bug 2 do Bug Finder (`bug_report_33_2`) — defeitos do conserto M1, corrigidos:**
    - **Bug 1:** `declarado?`/`detectores` levantavam `NoMethodError` quando uma classe retida pelo **critério
      de CAMINHO** não respondia a `cascata_postura` (não herda a base admin) — o build ficaria vermelho, mas
      por erro confuso. Corrigido: **sem `cascata_postura` ⇒ não declarou (drift)**, nunca exceção.
    - **Bug 2:** o stub do teste de caminho estava dentro de `module Admin`, então `ApplicationController`
      resolvia para `Admin::ApplicationController` — o stub **herdava a base admin** e a retenção vinha da
      **ancestralidade**, não do caminho (o teste não provava o M1). Corrigido com `::ApplicationController`
      e **provado por mutação**: remover `|| sob_admin` faz o teste **falhar**.
    - Assert do "conjunto fechado" volta a ser **literal** (o assert derivado era tautológico — Obs. do BF).
    - **Observações ⚪ restantes (não bloqueantes, registradas):** base abstrata **intermediária** sob `admin/`
      citando recurso no menu não é excluída (só `Admin::ApplicationController`, por identidade); o helper
      referencia `Ability` no load (autossuficiência cedida em favor do M2); `=begin/=end` não tratado
      (sobre-inclusão fail-closed); indireção/SQL cru por nome de tabela não é pego (limite declarado da Camada 2).
7. **Flag-independente:** o resultado do detector é idêntico sob `FREQUENCIA_AUTORIZACAO_CASCATA` ∈
   {off, shadow, on} × `FREQUENCIA_CASCATA_ENFORCEMENT` ∈ {log, raise} — assertado por teste; o módulo **não**
   referencia nenhuma das duas variáveis.
8. **Inicialização da tarefa adaptada ao estado real:** o `task-initialization-protocol` prevê branch a partir
   da `develop` atualizada, mas a `develop` está **89 commits atrás** do HEAD e **não contém a 33.1** (a
   dependência declarada da 33.2). Criei a branch da demanda a partir do HEAD da linha da Sprint 33
   (`feat/sprint-33-camada-1-guard-cascata` @ `ab19400`), preservando a Camada 1 — a base efetiva da sprint.
   Branch nova: `feat/sprint-33-camada-2-meta-teste-drift`.
9. **Sem alteração** em `ability.rb` (D3 — `git diff` vazio), `db/schema.rb`, rotas ou migrations; nenhuma
   dependência nova; nenhuma ADR nova; nenhum arquivo do AI Workflow tocado. Nada commitado/pushado
   (`COMMIT_MODE=manual`).
10. **Limite declarado (honestidade do gate):** o detector é **estático por conteúdo** para a sensibilidade —
    um controller que leia frequência por **indireção** (via service/model intermediário que cite o recurso, e
    não o controller) não é pego por esta camada; é o risco 🟡 já registrado em §"Riscos" e coberto pelos testes
    de conteúdo (33.3), que asseram o **efeito**. O detector também **não** detecta `skip_before_action
    :verificar_postura_cascata` (Observação 1 do Bug Finder 33.1) — limitação inerente à Camada 1.

## Notas de implementação (33.3) — plano × código real

> Divergências de **caminho/estrutura** encontradas ao implementar. **Nada do escopo/decisões
> D1–D5/Q33-C foi alterado.**

1. **Arquivo novo dedicado aos testes de conteúdo (`cascata_conteudo_test.rb`), não dentro do
   `cascata_cobertura_test.rb`.** O briefing/§2.2(3) sugerem pôr os testes de conteúdo no
   `cascata_cobertura_test.rb` (33.2) "e/ou ampliar os existentes". O `cascata_cobertura_test.rb` é um
   `ActiveSupport::TestCase` **unitário** (testa o detector com arquivos sintéticos em memória); testes de
   conteúdo exigem `ActionDispatch::IntegrationTest` (requisição HTTP + `response.body`). Misturar unidade e
   integração no mesmo arquivo acoplaria a suíte inteira e tornaria o footprint do meta-teste maior.
   Optou-se por um arquivo de integração **novo**, `test/controllers/admin/cascata_conteudo_test.rb`, que
   cobre **tela a tela** (§3 do plano) — mantendo o meta-teste de drift (33.2) intacto e unit-testável.
2. **Ator NÃO-global sem CPF (login sem stub do Pessoas).** Para os testes de conteúdo o ator é um `User`
   sem `cpf`, sem admin e sem role global (o único perfil em que a cascata de fato restringe — o passo 2
   curto-circuita admin/role geral). Sem CPF, o login não passa por `Pessoas::User.buscar_por_cpf` e não
   exige stub — mesmo padrão de `frequencia_cascata_controller_test.rb`.
3. **Stub de `Pessoas::Vinculo` por tela (sem schema do espelho).** O `Pessoas::Vinculo` é stubado
   devolvendo um terceiro NÃO-visível — como pede o §3 do plano ("com `Pessoas::Vinculo` stubado"). Duas
   fontes: `frequentadores_ativos` (honrando `incluir_cpfs`; `/frequentadores` e `/users`) e a agregação por
   órgão (`orgaos_em_uso`/`cpfs_por_orgao`/`cpfs_frequentadores_visiveis`; `/frequencia_por_orgao`). Assim o
   teste **não** depende de `test:pessoas_schema:load` (a matriz 29.8 depende; esta camada, não).
4. **Contraste `:off x :on` aplicado só onde é verdadeiro (honestidade do critério).** `/frequentadores`,
   `/users` e `/frequencia` exibem o terceiro em `:off` e o ocultam em `:on` (contraste direto);
   `/frequencia_por_orgao` conta o terceiro em `:off` e o exclui em `:on` (contraste por contagem). **Em
   `/time_records` o contraste NÃO se aplica:** o escopo NÃO-admin (`where(user_id: current_user.id)`) já
   esconde o terceiro em **qualquer** estado da flag — o teste registra explicitamente essa degenerescência
   (um teste separado prova que em `:off` o terceiro também não aparece) em vez de forçar um contraste
   falso. A contribuição da cascata para essa tela é o **dropdown de anos** (Bug 🟡3), já coberto por
   `time_records_anos_cascata_test.rb` e re-assertado sob `:on` aqui.
5. **`/relatorio_terceirizados` e `/parcial` não têm fonte real hoje** (`@registros = []`) — o assert de
   conteúdo é o trivial de ausência do identificador (não há como vazar dado inexistente). `/dashboard` é
   **admin-only** para os cards de batidas: o não-admin não vê nem o identificador do terceiro nem o card
   "Últimas Batidas" (o isolamento ali é o gate `current_user.admin?`, não a cascata — coerente com a
   dispensa justificada do controller na 33.1).
6. **Revisão de `users_controller_test.rb` (mandatória).** O caso
   `"usuario nao-admin ainda pode listar usuarios (read baseline)"` asseria **apenas** `assert_response
   :success` sobre um stub **vazio** (`stub_vinculos([])`) — exatamente o formato que deixou passar o Bug
   🔴1. Foi reescrito para `"usuario nao-admin lista usuarios mas NAO ve terceiro fora dos visiveis
   (conteudo sob :on)"`: assere o **conteúdo** (terceiro ausente sob `:on`, presente sob `:off`). Para que
   a assertiva não fosse **degenerada**, o helper local `stub_vinculos` passou a **honrar `incluir_cpfs`**
   (espelha o contrato real `scope.where(pessoas: { cpf: incluir_cpfs })`) — antes ele ignorava o filtro e
   retornava tudo, o que faria a cascata "passar" sem efeito algum. Os demais testes do arquivo usam
   `stub_vinculos([])` (lista vazia) e não mudam de resultado.
7. **Sem alteração** em `app/**` (incl. `ability.rb` — `git diff` vazio), `db/schema.rb`, rotas ou
   migrations; nenhuma dependência nova; nenhuma ADR nova; nenhum arquivo do AI Workflow tocado; nada
   commitado/pushado (`COMMIT_MODE=manual`).
8. **Nenhum bug de produção revelado.** Os testes de conteúdo **passaram** contra o código atual (não
   falharam) — a cascata, sob `:on`, filtra as telas com fonte real. **Ressalva honesta (review 33.3, 🟠
   A1):** das 8 telas citadas, apenas **4 provam o filtro da cascata** por mutação (`/frequentadores`,
   `/users`, `/frequencia`, `/frequencia_por_orgao`); 2 são **placeholders** sem fonte real
   (`/relatorio_terceirizados`, `/parcial`); `/time_records` isola por **escopo** e `/dashboard` por
   **gate admin**. Não houve necessidade de tocar `app/**`.
9. **Bug 1 e Observação 2 do Bug Finder (`bug_report_33_3`) — corrigidos:**
    - **Bug 1 (🟡) — teste cego a SUBSTITUIÇÃO.** O setup de `/frequencia_por_orgao` criava só
      frequentadores **do próprio órgão**, então `órgão ∩ visíveis == visíveis`: o teste passava mesmo com
      o controller trocando `cpfs &= frequentadores_visiveis_cpfs` por `cpfs = frequentadores_visiveis_cpfs`
      (**vazamento de agregado entre órgãos**) — confirmado por mutação (esperado 1, real 2). Corrigido
      adicionando um **visível de OUTRO órgão com batida**; a mutação agora **FALHA** o teste (prova de que
      distingue interseção de substituição).
    - **Observação 2 (⚪) — `/time_records` não provava o invariante "vê os próprios registros".** O ator era
      criado **sem CPF** e o teste só asseria ausência; como `restringir_frequencia` filtra por
      `where(user_id: frequentadores_visiveis_user_ids)` (`frequencia_authorization.rb:67`) **sem** somar
      `current_user.id`, um não-admin fora do conjunto visível veria **zero** registros — inclusive os
      próprios — e o teste passaria igual. Agora o ator tem **CPF visível a si** (com stub do login via
      `Pessoas::User.buscar_por_cpf`, pois quem tem CPF autentica pelo Pessoas) e o teste assere que **não**
      cai no empty-state. **Não foi revelado bug de produção** — o invariante se confirma para o usuário com
      CPF (o caso real de /time_records, que exige batida).

10. **Correções do review 33.3 aplicadas** (`review_report_33_3.md`): (A1) os 2 placeholders ganharam nome
    honesto + assert de estado (o de `/parcial` assere a linha de *empty-state*, não-vácuo) e um TO-DO
    para quando a fonte chegar; (M1) o teste de `/time_records` foi renomeado para explicitar que o
    isolamento vem do **escopo**, não da cascata; (B2) o de `/dashboard` explicita que guarda o **gate
    admin**. A afirmação inflada do item 8 ("filtra as 8 telas") foi corrigida.
11. **O Bug Finder CORRIGIU o review:** o B1 do review afirmava que `assert_select … text:` casa por
    **substring**; medido no `rails-dom-testing` instalado, é **igualdade exata** (`content == match_with`).
    Logo o "falso-verde silencioso" do B1 foi **superestimado** — o controle positivo `:off` denuncia o
    arquivo. A Mutação A (concern → `false`) derruba **5** testes (4 no arquivo novo + 1 em
    `users_controller_test`), confirmando o poder probatório das 4 telas reais.
12. **Inicialização da tarefa adaptada ao estado real:** a branch da demanda foi criada a partir do HEAD da
   linha da Sprint 33 (`feat/sprint-33-camada-2-meta-teste-drift` @ `86da982`, que contém a 33.1 e a 33.2 —
   a dependência declarada). A `develop` está atrás e não contém a 33.1; preservou-se a base efetiva da
   sprint. Branch nova: `feat/sprint-33-camada-2-conteudo-por-tela`.
