# Iteration 30 — Gate D5 exposto, roles granulares, débitos S2/S3 e rollout shadow

> Status: 📋 Planejada | Período: a definir (após Sprint 29) | Goal: Dar ponto de entrada HTTP ao gate de desconsideração (D5) atrás da flag, decidir e materializar as roles granulares do legado (PRD §9 item 2 — dependência de valor real da cascata), fechar os débitos 🟡S2/🟡S3 e produzir o insumo de decisão de rollout do modo `:shadow`. | Rastreabilidade: `Frequencia/PRD-REGRAS-NEGOCIO-PRESENCA.md` §2.3, §2.5, §3, §9 itens 2 e 7; `docs/adr/0010-arquitetura-cascata-autorizacao-frequencia.md` (regras 4, 6, 7); ruling **D5** (CTO, 2026-10-01)

## Contexto e escopo (definido pelo dev)

A Sprint 30 não consta do `docs/12-plano-implementacao/implementation_plan.md` — esse plano descreve as
sprints 24–28 (stack basic8) e **não cobre a Sprint 29 nem a 30** (gap de rastreabilidade conhecido,
registrado em §"Débito de rastreabilidade" abaixo). O escopo desta sprint foi **definido explicitamente
pelo dev** em quatro frentes; **nenhuma tarefa fora delas** foi criada aqui.

| Frente | Descrição | Origem |
|--------|-----------|--------|
| **1** | Integrar o gate D5 (desconsiderar) a um controller, **sob a flag** | Gap confirmado: `ElegibilidadeDesconsideracao#pode_desconsiderar?` e `TimeRecord#desconsiderar!` sem caminho HTTP (grep: só comentário) |
| **2** | Roles granulares (PRD §9 item 2) | Quadro §9 (CTO, 2026-10-05) — "a dependência de valor real da cascata" |
| **3** | Débitos 🟡S2 (twin SQL × PORO) e 🟡S3 (`frequencia_por_orgao` fora do grão da matriz) | `iteration_29_closure.md`; **ADR-0010 regra 7** |
| **4** | Rollout do modo `:shadow` por 1 ciclo (observação/análise — **não** "ligar a flag") | Ruling D3; flag default `:off` |

## Decisão de numeração e rastreabilidade

- Última iteration com arquivo: **29** (`docs/progress/iteration_29.md`). A 29 está **COMPLETA** (29.0–29.8 commitadas, branch `integration/sprint-29` @ `b47c0ce`). Próximo número livre: **30**.
- **Gap de rastreabilidade declarado:** o `implementation_plan.md` (`docs/12-plano-implementacao/`) **não** reflete as Sprints 29/30; não é fonte de escopo desta sprint. A formalização do épico/Gantt é do **Project Planner** (fora desta sprint). Registrado em §"Débito de rastreabilidade".

## Pré-condições

- Sprint 29 **mergeada** (a 30 consome `AutorizacaoFrequencia`, `FrequentadoresVisiveis`, `ElegibilidadeDesconsideracao`, `FrequenciaAutorizacaoCascata`, `FrequenciaAuthorization` — todos da 29).
- **Aprovação explícita do dev** (regra global do `CLAUDE.md`: alterar autorização/rotas exige plano claro): a tarefa **30.2** (ponto de entrada HTTP + `Ability`) só inicia após OK do dev sobre o plano da **30.1**.
- **Ruling de produto** (CTO/PO) antes da implementação das roles: a tarefa **30.4** só inicia após o ruling da **30.3** decidir "manter simplificado × expandir".
- Baseline da suíte a isolar: **1083 runs / 3789 assertions / 1F + 11E / 0 skip** (as 12 são pré-existentes: 11× Devise `redirect_to` + 1× timezone em `presenca_endpoints_test.rb`). Isolar as pré-existentes; o 13º erro (`Pessoas::Vinculo.ativos` por `remove_method`) é order-dependent — rodar isolado antes de tratar como regressão.

## Desenvolvedores

| Dev | Perfil | Foco |
|-----|--------|------|
| Dev A (Code Specialist) | Backend Rails (controllers/Ability/tests) | 30.2, 30.6, 30.7, apoio à 30.8 |
| Dev B / CTO (rulings) + Code Specialist (impl.) | Autorização/roles/dados | 30.1 (co), 30.3, 30.4, 30.5 |
| PO | Produto | 30.3 (decisão), 30.8 (insumo de decisão) |

## Backlog

### Frente 1 — Gate D5 (desconsiderar) sob a flag

#### Tarefa 30.1 — Plano de exposição do gate D5 e aprovação do dev (design; GATE)
- User Story: Como time, quero um plano explícito do ponto de entrada HTTP do gate de desconsideração para que a mudança de autorização/rotas só seja implementada com aprovação do dev (regra global do `CLAUDE.md`).
- Rastreabilidade: PRD §3 (ver ≠ desconsiderar), §2.5; ADR-0010 regra 6; ruling **D5** (CTO, 2026-10-01); `iteration_29.md` §"Decisão D5"
- Estimativa: 2 pontos | Atribuição: Dev B / CTO (plano) + aprovação do dev | Dependências: nenhuma (design)
- **Plano:** `docs/progress/iteration_30_task_30_1_plano_gate_d5.md` (design only — insumo exato da 30.2).
- Critérios de aceite:
  - [x] Plano define o **ponto de entrada**: tipo (**member action em `Admin::TimeRecordsController`**), verbo HTTP (`POST`), rota (**`/time_records/:id/desconsiderar`** — path real; ver divergência §1.3 do plano), params (`justificativa`), e o efeito (`TimeRecord#desconsiderar!` — assinatura **real** confirmada: `desconsiderar!(justificativa:, responsavel:)`, `app/models/time_record.rb:37`; `responsavel: current_user`).
  - [x] Comportamento especificado nos **3 estados da flag** (`FrequenciaAutorizacaoCascata`): `:off` = **404** recurso indisponível/fail-closed (sem revelar autorização); `:shadow` = só loga, **não** desconsidera; `:on` = aplica o gate D5.
  - [x] Critério de autorização explícito: **só o passo 5** (`AutorizacaoFrequencia#gestor_de_orgao_do?` → `ElegibilidadeDesconsideracao#pode_desconsiderar?`); **nunca** `pode_ver?`. Caso "`GestorIndividual` (passo 4) vê mas **não** desconsidera" registrado como critério de teste obrigatório.
  - [x] **Aprovação explícita do dev registrada** neste arquivo (data/autor) antes de a 30.2 iniciar — ver §"Aprovação do dev" abaixo.
- Status: ✅ **Concluída (plano escrito + aprovação do dev registrada; gate satisfeito)** — **desbloqueia a 30.2**. Aguarda a implementação da 30.2.

##### Aprovação do dev (gate da 30.1)
- **Decisão aprovada:** (a) ponto de entrada = **member action em `Admin::TimeRecordsController`** (não controller dedicado); (b) **`:off` → 404** (recurso indisponível). Confirmado que **não** haverá extensão ao `GestorIndividual` (ruling D5 mantido: só o passo 5).
- **Autor:** dev Davi Araujo · **Data:** **2026-10-05**.
- **Efeito:** gate da **30.1 satisfeito** → **30.2 desbloqueada**. **Q1** respondida; **Q2** confirmada. Permanecem abertas **Q7** (evento/payload do log em `:shadow` para o gate D5) e **Q8** (resposta HTTP em `:shadow` / `justificativa` em branco) — ver §5 do plano.

#### Tarefa 30.2 — Ponto de entrada HTTP do gate D5 atrás da flag (`:on`)
- User Story: Como gestor do órgão do frequentador, quero desconsiderar um dia de frequência pela tela, para corrigir o cálculo sem depender do legado (hoje o fluxo é código não-exposto).
- Rastreabilidade: PRD §3, §9 item 7; ADR-0010 regra 6; ruling D5
- Estimativa: 5 pontos | Atribuição: Dev A | Dependências: **30.1** (plano aprovado pelo dev)
- Critérios de aceite:
  - [x] Nova rota/ação acessível **apenas sob `FREQUENCIA_AUTORIZACAO_CASCATA=:on`**; em `:off`/`:shadow` o caminho não produz desconsideração (fail-closed).
  - [x] Antes de chamar `TimeRecord#desconsiderar!`, consulta `ElegibilidadeDesconsideracao#pode_desconsiderar?`; sem autorização → negação **sem efeito** (sem `update!`, sem `IntervencaoFrequencia`).
  - [x] A `Ability` restringe a ação à cascata — **não** amplia para quem só é `GestorIndividual` (passo 4); usa a hierarquia (passo 5). Proibido `pode_ver?` no gate.
  - [x] `desconsiderar!` recebe `justificativa` e `responsavel: current_user`; cria a `IntervencaoFrequencia` (comportamento atual preservado — sem mudança no motor).
  - [x] Testes de controller cobrindo: gestor do órgão (autorizado), `GestorIndividual` sem hierarquia (**negado**, mas vê), sem role (negado), flag `:off`/`:shadow` (no-op/negado), e `:on` restringindo.
  - [x] **Mutation testing**: remover o gate → teste falha; trocar passo 5 por `pode_ver?` → teste do `GestorIndividual` falha.
  - [x] Sem regressão no baseline (as 12 pré-existentes inalteradas); RuboCop/Zeitwerk OK.
- Status: ✅ **Implementado, ✅ Aprovado (Code Reviewer, 2026-10-05)** — 0 blockers 🔴; sugestões 🟡Q1/🟠D1 não-bloqueantes. Relatório: `docs/quality/review_report_30_2.md`. **Entrega:** member action `POST /time_records/:id/desconsiderar` (path real; o controller vive em `scope module: "admin"`) em `Admin::TimeRecordsController#desconsiderar`; rota com `constraints: ->(_req) { FrequenciaAutorizacaoCascata.modo != :off }` (`:off` → 404, mecanismo primário do plano §2.1); `skip_authorization_check` no `:shadow` (branch de observação); nova ação custom `:desconsiderar` na `Ability` (`grant_desconsideracao_frequencia`) concedida **só sob a cascata** e **só ao passo 5** via `ElegibilidadeDesconsideracao#pode_desconsiderar?` (nunca `pode_ver?` — D5); eventos próprios do gate D5 em `FrequenciaAutorizacaoCascata` (Q7: `EVENTO_DESCONSIDERAR_SHADOW`/`EVENTO_DESCONSIDERAR_NEGACAO`, não reusa `EVENTO_SHADOW`); respostas HTTP conforme Q8 (`:shadow` → redirect+notice; justificativa vazia → redirect+alert, sem efeito). **Achado crítico (probe):** `can :manage, :all` do admin fazia um `can` de bloco com `false` cair em fall-through (admin não-gestor desconsideraria); corrigido com `cannot :desconsiderar, TimeRecord` antes do bloco de `can` — D5 vale inclusive para admin (o legado `podeDesconsiderarFrequencia` só chama `isGestorOrgao`). **Testes:** `test/controllers/admin/time_records_desconsiderar_test.rb` (9 testes) cobrindo os 7 cenários do critério + Ability + o fall-through do admin. **Evidência medida:** arquivo-alvo **9/59/0/0**; suíte-alvo (desconsiderar + cascata + matriz + ability + elegibilidade + time_record + autorizacao + cascata-flag) **140/475/0/0**; **suíte completa = 1092/3847/1F+12E/0 skip** (sem o arquivo novo = **1083/3788/1F+12E** — mesmos F/E; +9 runs/+59 asserts; as 12/13 são pré-existentes: 11× Devise `redirect_to` + 1× timezone em `PresencaEndpointsTest` + 1× order-dependent `PessoasSchemaLoaderTest` que passa isolado); RuboCop: arquivos novos 0 offenses (controller/routes mantêm o débito legado `SpaceInsideArrayLiteralBrackets`, sem offense nova); Zeitwerk OK. **Mutation testing: 7 mutações, 7 mortas** (remover o gate; `pode_desconsiderar?`→`pode_ver?`; desligar a constraint do `:off`; desligar o no-op do `:shadow`; reusar `EVENTO_SHADOW`; remover o guard de justificativa vazia; remover o `cannot` que contém o fall-through do admin). Sem commit/push (`COMMIT_MODE=manual`).

### Frente 2 — Roles granulares (PRD §9 item 2)

#### Tarefa 30.3 — Ruling/desenho de produto e mapeamento das 11 roles + 7 perfis (GATE)
- User Story: Como PO, quero decidir entre manter as roles simplificadas ou expandir para as 11 roles granulares do legado, para que a cascata tenha a atribuição de valor que hoje a deixa inoperante em produção.
- Rastreabilidade: PRD §2.3 (11 roles `PresencaRolesEnum` + 7 perfis `PresencaProfilesEnum`), §9 item 2; ruling **D1** (destino reservado à Sprint 30); Quadro §9 (CTO, 2026-10-05)
- Estimativa: 3 pontos | Atribuição: CTO/PO | Dependências: nenhuma (decisão)
- **Brief de decisão:** `docs/progress/iteration_30_3_brief_roles_granulares.md` (CTO, 2026-10-06 — insumo do ruling: mapeamento legado→Frequencia das 11+7, opções **A (manter simplificado)** × **B (expandir)**, Q3 (só frequência × todas as seções), recomendação e decisões D-1..D-6; **o ruling continua sendo do dev/PO**).
- Critérios de aceite:
  - [ ] Ruling registrado decidindo **manter simplificado × expandir** (com justificativa de produto).
  - [ ] Se expandir: **tabela de mapeamento** legado → Frequencia das 11 roles e dos 7 perfis (nome Rolify snake_case, efeito, seção afetada), sem tocar nas 3 genéricas (`admin`/`gestor`/`operador`) nem nas 2 da 29.4 (`visualiza_frequentadores`/`visualiza_terceirizados`).
  - [ ] Definido o **escopo da integração**: só frequência × todas as seções (estações, excepcionais, gestor individual) — ver **pergunta aberta (Q3)**.
  - [ ] Definido o modo de **atribuição** (seed manual × migração 1:1 do Intranet) e o tratamento de não-resolvidos.
  - [ ] **Aprovação do PO** registrada neste arquivo antes de a 30.4 iniciar.
- Status: ⬜ Pendente

#### Tarefa 30.4 — Implementar as roles granulares (definição + seeds)
- User Story: Como administrador, quero as roles granulares do legado definidas no Frequencia, para atribuir acesso por função em vez de pelas 3 roles genéricas.
- Rastreabilidade: PRD §2.3; ruling da 30.3; D1
- Estimativa: 3 pontos | Atribuição: Dev B | Dependências: **30.3** (ruling; se "manter simplificado", tarefa **não se aplica**)
- Critérios de aceite:
  - [ ] Roles Rolify criadas com os nomes snake_case do mapeamento da 30.3; seed **idempotente** (`add_role` já é idempotente).
  - [ ] As 3 genéricas e as 2 da 29.4 permanecem intactas (sem regressão na `Ability`/cascata).
  - [ ] Testes: seeds idempotentes (2ª execução = 0 criações); role nova não altera comportamento sob `:off`.
  - [ ] Sem alteração de schema além do que o Rolify já provê.
- Status: ⬜ Pendente

#### Tarefa 30.5 — Atribuição/migração das roles a partir do Intranet
- User Story: Como administrador, quero migrar 1:1 as roles legadas dos usuários do Intranet, para que a atribuição real de acesso exista no Frequencia após o desligamento do legado.
- Rastreabilidade: PRD §2.3; ruling da 30.3; D1 ("migração 1:1 das 11 roles é Sprint 30")
- Estimativa: 3 pontos | Atribuição: Dev B | Dependências: **30.4** (se "manter simplificado", tarefa **não se aplica**)
- Critérios de aceite:
  - [ ] Mapeamento legado→local idempotente (upsert por chave estável); reexecução = 0 duplicações.
  - [ ] Relatório de **não-resolvidos** (usuário/CPF sem correspondência local) — nada é silenciosamente ignorado.
  - [ ] Dry-run sem escrita.
  - [ ] Testes com os mesmos padrões da 29.3 (save/restore do método original, nunca `remove_method` destrutivo).
- Status: ⬜ Pendente

### Frente 3 — Débitos 🟡S2 e 🟡S3

#### Tarefa 30.6 — Fechar 🟡S2: testes PORO **e** twin SQL no passo compartilhado (ADR-0010 regra 7)
- User Story: Como time, quero um teste que exercite o PORO **e** o twin SQL com `GestorIndividual` inativo, para que mutar o passo 4 em um dos corpos derrube teste (hoje a matriz é cega ao PORO).
- Rastreabilidade: ADR-0010 **regra 7**; `iteration_29_closure.md` §"Débitos abertos"; Quadro §9 item 7
- Estimativa: 2 pontos | Atribuição: Dev A | Dependências: nenhuma (independente)
- Critérios de aceite:
  - [ ] Teste do **PORO** `AutorizacaoFrequencia#motivo` com `GestorIndividual` **inativo** → assert `:negado`.
  - [ ] Teste do **twin SQL** (`FrequentadoresVisiveis`/listagem) com o **mesmo cenário** (GI inativo) → o alvo não aparece.
  - [ ] Ambos no **baseline** (viram referência de conformidade); **mutation testing**: mutar `.ativos` do PORO derruba o teste do PORO; mutar o SQL derruba o do SQL.
  - [ ] Sem alteração de código de produção (é hardening de teste).
- Status: ✅ **Implementado, ✅ Aprovado** (Code Reviewer, 2026-10-06; **0 blockers**; 🟡M1/🟠D1 não-bloqueantes. Relatório: `docs/quality/review_report_30_6.md`). **Nota de conformidade (🟡M1 do review):** a premissa da regra 7 (de que o twin era "cego" e a mutação dupla "escapava") é **parcialmente imprecisa neste arquivo** — a propriedade já pegava a mutação unilateral e a fixture pré-existente pegava a dupla; o valor incremental real é o **par EXPLÍCITO no mesmo cenário com controle positivo** (o gatilho binário da regra 7), que este teste cumpre. A cegueira do twin é da **matriz da 29.8**, não deste arquivo — registrado ao CTO. **Entrega (só teste — hardening):** novo teste em `test/models/frequentadores_visiveis_test.rb` — "S2 passo 4: GestorIndividual INATIVO nega no PORO e some do scope (mesmo cenario, com controle ativo)" — que exercita os DOIS corpos no MESMO cenário (GI **inativo**): PORO `AutorizacaoFrequencia#motivo` → `:negado` **e** twin SQL `FrequentadoresVisiveis.para` → alvo **ausente do scope**; com **controle positivo** (GI ativo liberado e presente) para o teste não ser degenerado (lição 33 — falha pela razão CERTA). **Mutation testing:** (a) remover `.ativos` do PORO (`gestor_individual?`) → novo teste falha (`Expected: :negado / Actual: :gestor_individual`); (b) remover `.ativos` de `geridos_user_ids` no twin SQL → novo teste falha (`Expected [ids] to not include <id>`); **ambas mortas pelo próprio teste do lado mutado** (antes, a mutação do SQL só era pega indiretamente pelo paralelismo scope×PORO — era o furo S2). **Evidência medida:** arquivos-alvo (`autorizacao_frequencia_test` + `frequentadores_visiveis_test`) = **63/183/0F/0E/0 skip** (baseline 62/177); suíte completa = **1093/3853/2F+12E/0 skip** — +1 run/+6 asserts do teste novo; os 14 defeitos são os conhecidos (11× Devise `redirect_to` + 1× timezone em `PresencaEndpointsTest` + 2 manifestações order-dependent de `PessoasSchemaLoaderTest` sob paralelização, que reproduzem **isoladas** por o teste fazer shell-out a `bin/rails` com o ruby do PATH — nenhum nos arquivos tocados). **ZERO código de produção alterado** (`git diff app/` vazio). Sem commit/push (`COMMIT_MODE=manual`).

#### Tarefa 30.7 — Fechar 🟡S3: estender a matriz de aceite ao grão de `frequencia_por_orgao`
- User Story: Como time, quero `frequencia_por_orgao` coberto na matriz de aceite no mesmo grão das demais telas (por CPF), para que a agregação por órgão não seja um ponto cego da cascata.
- Rastreabilidade: ADR-0010 §Consequências (🟡S3); `iteration_29_closure.md`; PRD §3
- Estimativa: 2 pontos | Atribuição: Dev A | Dependências: nenhuma (independente)
- Critérios de aceite:
  - [ ] A matriz de aceite (29.8) cobre `frequencia_por_orgao` no **grão por CPF** (denominador da negação por CPF, não por registro).
  - [ ] Cenário **sem-CPF** permanece coberto e registra **fail-closed** (não-admin sem CPF vê zero sob `:on`).
  - [ ] **Mutation testing** sobre o filtro por CPF (remover o filtro → teste falha).
  - [ ] A **decisão de produto sobre contas locais sem CPF** fica registrada como pergunta aberta ao PO (Q4) — **não** é resolvida por esta tarefa.
- Status: ✅ **Implementado, ✅ Aprovado** (Code Reviewer, 2026-10-06; **0 blockers**; 5/5 mutações do revisor mortas. Relatório: `docs/quality/review_report_30_7.md`). **Entrega (só teste — hardening de matriz):** estende `test/controllers/admin/frequencia_matriz_aceite_test.rb` com 3 cenários no grão por **CPF** de `frequencia_por_orgao`, exercitando a cascata **REAL** (sem stub de `cpfs_por_orgao`/`cpfs_frequentadores_visiveis`, ao contrário do que já existia em `frequencia_cascata_controller_test.rb`): **30.7a** interseção `cpfs do órgão ∩ visíveis` (visível 2 dias + negado 1 dia + visível-de-OUTRO-órgão 1 dia → sem flag=3, `:on`=2; distingue as DUAS direções erradas — sem interseção=3 e derivar só dos visíveis=3), **30.7b** sem-CPF fail-closed (sem flag=1, `:on`=0), **30.7c** log do `:on` por CPF (`EVENTO_NEGACAO` do CPF oculto; o visível NÃO é logado). Helper `presencas_do_orgao` lê a LINHA do órgão (não um `td` solto — o `assert` não passa por outro número da página). **Mutation testing: 3 mutações, 3 mortas** — (M1) neutralizar `cpfs &= frequentadores_visiveis_cpfs` → 30.7a `Expected 2 / Actual 3` **e** 30.7b `Expected 0 / Actual 1`; (M2) remover `registrar_negacoes_por_cpf(cpfs)` → 30.7c falha (sem a negação no log); (M3) `cpfs = frequentadores_visiveis_cpfs` (ignorar os cpfs do órgão) → 30.7a `Expected 2 / Actual 3`, pega pelo ator visível-de-outro-órgão. **Evidência medida:** arquivo-alvo **16/72/0F/0E/0 skip** (13 da matriz + 3 novos); suíte direcionada (matriz + `frequencia_por_orgao_controller` + `frequencia_cascata_controller`) **40/188/0/0**; suíte completa **1 worker = 1095/3865/1F+11E/0 skip** (o worktree @`987ff39` já traz os 9 testes da 30.2 → 1092; +3 meus = 1095; F/E = exatamente os pré-existentes: 11× Devise `redirect_to` + 1× timezone em `PresencaEndpointsTest`; o 12º erro `PessoasSchemaLoaderTest` só aparece sob paralelização). RuboCop: **0 offenses** no arquivo. **ZERO código de produção alterado** (`git diff app/` vazio). Sem commit/push (`COMMIT_MODE=manual`).

### Frente 4 — Rollout shadow (observação/análise)

#### Tarefa 30.8 — Rodar o modo `:shadow` por 1 ciclo e produzir o insumo de decisão do PO
- User Story: Como PO, quero um relatório das negações que a cascata faria num ciclo de shadow, para decidir (com risco medido) se a flag vira `:on` — hoje a cascata está implementada mas não vigente em produção.
- Rastreabilidade: ADR-0010 regra 4 (flag 3 estados); ruling **D3**; Quadro §9 item 1 (ressalva "flag default OFF")
- Estimativa: 3 pontos | Atribuição: CTO/Dev A (execução) + PO (decisão) | Dependências: **30.2** (gate D5, mesma flag) e **30.4/30.5** (roles — dependência de valor)
- Critérios de aceite:
  - [ ] Rodar `FREQUENCIA_AUTORIZACAO_CASCATA=shadow` por **1 ciclo** no ambiente acordado (ver **Q5**).
  - [ ] Consolidar as contagens de `EVENTO_SHADOW` (`frequencia_autorizacao_cascata.shadow`) **por motivo** (`proprio`/`role_geral`/`terceirizado`/`gestor_individual`/`hierarquia`/`negado`), destacando as que **seriam negadas**.
  - [ ] Relatório do insumo de decisão produzido em `docs/quality/` (ou `docs/progress/`), com as **limitações declaradas** — em especial: o gate D5 é `:on`-only e **não** produz sinal em shadow.
  - [ ] **NÃO** alterar a flag para `:on` — a decisão de ligar é do PO (fora desta tarefa).
  - [ ] Sem alteração de código de produção (execução/observação).
- Status: ⬜ Pendente

## Resumo

| Tarefa | Pontos | Dev | Depende de |
|---|---|---|---|
| 30.1 — Plano D5 + aprovação do dev (GATE) | 2 | Dev B/CTO | — |
| 30.2 — HTTP do gate D5 sob a flag | 5 | A | 30.1 |
| 30.3 — Ruling roles granulares (GATE) | 3 | CTO/PO | — |
| 30.4 — Implementar roles (definição + seeds) | 3 | B | 30.3 |
| 30.5 — Atribuição/migração das roles | 3 | B | 30.4 |
| 30.6 — Fechar 🟡S2 (PORO + twin SQL) | 2 | A | — |
| 30.7 — Fechar 🟡S3 (`frequencia_por_orgao`) | 2 | A | — |
| 30.8 — Rollout shadow + insumo do PO | 3 | CTO/A | 30.2, 30.4, 30.5 |
| **Total** | **23** | | |

## Caminho Crítico

**30.3 → 30.4 → 30.5 → 30.8** (12 pontos). Em paralelo, o ramo do gate D5 (**30.1 → 30.2**, 7 pontos) precisa
**fechar antes da 30.8** porque a 30.8 observa o estado `:on` completo na mesma flag. Os débitos
**30.6** e **30.7** são independentes e rodam em paralelo (teste-hardening, sem tocar produção).

> **Ordem de dependências (explicitada pelo dev):** frente 1 (30.2) e frente 4 (30.8) tocam a **mesma flag**;
> as roles (frente 2) **precedem** o rollout — são a **dependência de valor real** da cascata. Os gates
> **30.1** (aprovação do dev) e **30.3** (ruling do PO) **travam** as implementações 30.2 e 30.4.

## Riscos

- **Alteração de autorização/rotas (30.2).** Ampliar acesso indevidamente é o risco central; mitigado por: gate **só passo 5** (`gestor_de_orgao_do?`), nunca `pode_ver?`; fail-closed em `:off`/`:shadow`; teste explícito "`GestorIndividual` vê mas não desconsidera"; aprovação do dev (30.1) antes da implementação.
- **Escopo das roles (30.3).** "Manter simplificado × expandir" e a **abrangência da integração** (só frequência × todas as seções) não estão rulingadas — sem o ruling, 30.4/30.5 não são estimáveis com precisão (ver **Q3**).
- **S3 sem decisão de produto (Q4).** Contas locais sem CPF sob `:on` perdem os próprios registros (fail-closed). A matriz cobre o comportamento, mas a **decisão de produto** é do PO e não é resolvida aqui.
- **Rollout shadow depende de ambiente/ciclo (Q5).** Sem definição de onde/como rodar 1 ciclo, a 30.8 não tem insumo confiável; declarar a limitação D5 (sem sinal em shadow).
- **Baseline da suíte.** 1083/3789/1F+11E/0 skip (12 pré-existentes + o 13º order-dependent `Pessoas::Vinculo.ativos`). Toda medição deve isolar as pré-existentes antes de atribuir regressão.
- **`implementation_plan.md` defasado** — não é fonte de escopo; a Sprint 30 não tem entrada no épico/Gantt (gap de rastreabilidade, abaixo).

## Débito de rastreabilidade

- [ ] `docs/12-plano-implementacao/implementation_plan.md` **não cobre as Sprints 29/30** (descreve só 24–28) — formalizar épico/Gantt é do **Project Planner**, fora desta sprint. — Severidade: 🟡 — Tarefa: (chore de planejamento)

## Débitos Técnicos

- [x] 🟡 **S2 — twin SQL cego ao PORO** (passo 4/GI inativo) — **FECHADO** (30.6, ✅ aprovado 2026-10-06; regra de conformidade na ADR-0010 regra 7)
- [x] 🟡 **S3 — `frequencia_por_orgao` fora do grão da matriz** — **FECHADO** (30.7, ✅ aprovado 2026-10-06; decisão de produto sobre sem-CPF permanece em **Q4**)
- [ ] **Gate D5 sem caminho HTTP** (`pode_desconsiderar?`/`desconsiderar!` sem caller de produção) — Severidade: 🟠 — Tarefa: **30.1/30.2**
- [ ] **Flag `FREQUENCIA_AUTORIZACAO_CASCATA` default `:off`** — cascata implementada/provada, **não vigente em produção** — Severidade: 🟠 — Tarefa: **30.8** (insumo; decisão do PO)

## Definição de Pronto

- [ ] 30.1–30.8 com status e Linha do Tempo preenchidos; gates (30.1, 30.3) com aprovação registrada.
- [ ] Testes: suíte direcionada verde + suíte completa sem regressão (as 12 pré-existentes inalteradas); mutation testing das tarefas 30.2/30.6/30.7.
- [ ] Sem commit/push (`COMMIT_MODE=manual`); stage seletivo quando autorizado.
- [ ] Perguntas abertas ao dev/PO (Q1–Q6) respondidas ou explicitamente adiadas.

## Perguntas abertas ao dev / PO

> Registradas em vez de virar tarefa, por não pertencerem ao escopo aprovado ou dependerem de decisão de produto.

- **Q1 (frente 1) — ponto de entrada. ✅ RESPONDIDA (dev, 2026-10-05).** **Member action** em `Admin::TimeRecordsController` (não controller dedicado): `POST /time_records/:id/desconsiderar` (path real; o controller está sob `scope module: "admin"`). Sob `:off` = **404** (recurso indisponível). Fixada no plano da 30.1.
- **Q2 (frente 1) — extensão do D5. ✅ CONFIRMADA (dev, 2026-10-05).** **Não** haverá extensão ao `GestorIndividual`: ruling D5 mantido — **só o passo 5** desconsidera (`GestorIndividual` vê mas não desconsidera).
- **Q7 (frente 1) — evento/payload do log em `:shadow` para o gate D5 (NOVA, aberta; ver §5 do plano).** O shadow existente loga visualização (`EVENTO_SHADOW`); o gate D5 é de desconsiderar e não tem sinal em shadow (ADR-0010/30.8). Definir: reusar `EVENTO_SHADOW` (risco de poluir) × evento próprio (recomendado) × não logar. **Não** decide sozinho — pergunta ao dev.
- **Q8 (frente 1) — resposta HTTP em `:shadow` e `justificativa` em branco (NOVA, aberta).** Redirect com alerta/notice × 4xx. Recomendação registrada no plano.
- **Q3 (frente 2) — abrangência da integração das roles.** O ruling deve decidir **manter simplificado × expandir**; se expandir, a integração das 11 roles abrange **só frequência** ou **todas as seções** (estações, excepcionais, gestor individual)? Isso muda materialmente a estimativa da 30.4/30.5.
- **Q4 (frente 3/S3) — contas sem CPF.** Decisão de **produto** do PO: um não-admin sem CPF vê zero registros sob `:on` (fail-closed), perdendo os próprios. Manter assim ou criar exceção? A 30.7 apenas cobre o comportamento; **não** resolve a decisão.
- **Q5 (frente 4) — ambiente/ciclo do shadow.** Onde e como rodar 1 ciclo de `shadow` (qual ambiente, duração de "1 ciclo", como ler o log)? Sem isso a 30.8 não tem insumo confiável.
- **Q6 (frente 4) — dono da decisão de ligar.** Confirmar que **ligar `:on`** é decisão do **PO** (não da sprint) e que a 30.8 **só** produz o insumo.

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
| 2026-10-05 | Sprint Planner detalhou a Sprint 30 a partir das 4 frentes aprovadas pelo dev | 8 tarefas, 23 pontos, 2 gates de ruling/aprovação, 6 perguntas abertas |
| 2026-10-05 | CTO escreveu o plano da 30.1 (`iteration_30_task_30_1_plano_gate_d5.md`) e registrou a aprovação do dev (member action; `:off`=404) | 30.1 ✅ concluída — gate satisfeito, **30.2 desbloqueada**; Q1/Q2 fechadas, Q7/Q8 abertas |
| 2026-10-05 | Code Specialist implementou a 30.2 (rota+constraint, `Ability#grant_desconsideracao_frequencia` com `cannot`+bloco, eventos D5 próprios, controller nos 3 modos, 9 testes) — worktree `wt-30.2`/branch `feature/demanda-30-2-gate-d5-http` | 30.2 ✅ implementada — aguarda Code Reviewer; 7/7 mutações mortas; suíte 1092/3847/1F+12E (pré-existentes); Q7/Q8 resolvidas na implementação |
| 2026-10-05 | Code Reviewer revisou a 30.2 (worktree `wt-30.2`): D5 conforme (só passo 5), fall-through do admin corrigido (probe CanCan confirma ordem load-bearing), 3 estados da flag OK, 5/5 mutações do reviewer mortas, suíte 1092/3847/1F+12E idêntica | 30.2 ✅ **Aprovada** (0 blockers; 🟡Q1/🟠D1 não-bloqueantes) — relatório `docs/quality/review_report_30_2.md`; entregue ao Orchestrator |
| 2026-10-06 | Code Specialist implementou a 30.6 (teste S2: PORO + twin SQL no MESMO cenário GI inativo, com controle ativo) — worktree `wt-30.6`/branch `feature/demanda-30-6-s2-twin-sql` | 30.6 ✅ implementada — aguarda Code Reviewer; 2/2 mutações mortas pelo teste do lado mutado; suíte-alvo 63/183/0F/0E; só teste (sem código de produção) |

