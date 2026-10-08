# Iteration 30 — Gate D5 exposto, roles granulares, débitos S2/S3 e rollout shadow

> Status: 🟢 **ENCERRÁVEL (CTO, 2026-10-08)** — **30.8 re-escopada** de "7 dias em PRODUÇÃO" para **"observação em DEV"** (já realizada: 1366 eventos; ver §"Re-escopo da 30.8"); Bug 🟠2 registrado como **Risco Aceito com gatilho de revisita**; débito **estrutural** (enforcement opt-in da cascata) encaminhado à ADR-0010. Única pendência residual = **decisão do dev de virar a flag `:on`** (shelved — **não** decidida pelo CTO; ver **Q16**). Detalhamento em §"Re-escopo da 30.8 e encerramento da Sprint 30". (rulings **30.3 = A** e **D-6 = (i)** registrados, 2026-10-06; **diretiva do dev de 2026-10-07** abre a **frente 5 / tarefa 30.10**; **emenda do dev de 2026-10-07**: o ruling **30.3 = A** passa a **"A + expansão incremental dirigida pelo PRD"** — a **30.4** deixa de ser "N/A" puro e passa a **substituída pela política incremental**; ver §"Emenda do ruling A") | Período: a definir (após Sprint 29) | Goal: Dar ponto de entrada HTTP ao gate de desconsideração (D5) atrás da flag, **rulingar** as roles granulares do legado (PRD §9 item 2 — dependência de valor real da cascata), **materializar o mínimo que dá valor à cascata** (semear/atribuir as 2 roles que ela consome e **garantir o `User` local dos gestores de unidade** — furo dos 24 sem lotação vigente), fechar os débitos 🟡S2/🟡S3 e produzir o insumo de decisão de rollout do modo `:shadow`. | Rastreabilidade: `Frequencia/PRD-REGRAS-NEGOCIO-PRESENCA.md` §2.3, §2.5, §3, §9 itens 2 e 7; `docs/adr/0010-arquitetura-cascata-autorizacao-frequencia.md` (regras 4, 6, 7); ruling **D5** (CTO, 2026-10-01); rulings **30.3 = A** e **D-6 = (i)** (dev, 2026-10-06) + **emenda 30.3 = A + expansão incremental dirigida pelo PRD** (dev, 2026-10-07) + brief `iteration_30_3_brief_roles_granulares.md` (§4/§5/§8/§9)

## Contexto e escopo (definido pelo dev)

A Sprint 30 não consta do `docs/12-plano-implementacao/implementation_plan.md` — esse plano descreve as
sprints 24–28 (stack basic8) e **não cobre a Sprint 29 nem a 30** (gap de rastreabilidade conhecido,
registrado em §"Débito de rastreabilidade" abaixo). O escopo desta sprint foi **definido explicitamente
pelo dev** em quatro frentes; **nenhuma tarefa fora delas** foi criada aqui — **exceto** a **frente 5**
(cobertura do `User` local dos gestores de unidade, tarefa **30.10**), aberta por **diretiva direta do
dev em 2026-10-07** (ver §"Diretiva do dev (2026-10-07)" abaixo).

| Frente | Descrição | Origem |
|--------|-----------|--------|
| **1** | Integrar o gate D5 (desconsiderar) a um controller, **sob a flag** | Gap confirmado: `ElegibilidadeDesconsideracao#pode_desconsiderar?` e `TimeRecord#desconsiderar!` sem caminho HTTP (grep: só comentário) |
| **2** | Roles granulares (PRD §9 item 2) | Quadro §9 (CTO, 2026-10-05) — "a dependência de valor real da cascata" |
| **3** | Débitos 🟡S2 (twin SQL × PORO) e 🟡S3 (`frequencia_por_orgao` fora do grão da matriz) | `iteration_29_closure.md`; **ADR-0010 regra 7** |
| **4** | Rollout do modo `:shadow` por 1 ciclo (observação/análise — **não** "ligar a flag") | Ruling D3; flag default `:off` |
| **5** | Cobertura do `User` local dos **gestores de unidade** (furo dos **24 sem lotação vigente**) | **Diretiva do dev (2026-10-07)** — ver §"Diretiva do dev (2026-10-07)" e a **30.10** |

### Diretiva do dev (2026-10-07) — cobertura do `User` local dos gestores de unidade (frente 5 / 30.10)

**Diretiva verbatim (dev, 2026-10-07, via /orchestrator):** "vamos verificar os usuários que possuem
role de gestor e gestor geral no intranet e copiar os cadastros deles ... e vamos implementar a cascata
de permissões em cima disso".

**⚠️ Correção factual — a diretiva partia de uma premissa falsa.** **NÃO existe** role "gestor" nem
"gestor geral" no Intranet: verificado em `intranet/.../PresencaRolesEnum.java` — **13 roles,
nenhuma gestor**. "Gestor"/"gestor geral", no contexto deste projeto, significam **gestor de
unidade/órgão** (o `Orgao.gestorAtual/Substituto/Excepcional` do legado; no Pessoas =
`Pessoas::Unidade.gestor/gestor_substituto/gestor_excepcional`). Logo, a diretiva textual (role
inexistente + "copiar cadastros do Intranet") **não se aplica como escrita**; o que se executa é o seu
**intento**, com a fonte e o alvo corretos.

**RULING do dev (já resolvido em 2026-10-06/07 — NÃO reabrir):** "gestor"/"gestor geral" = **gestor de
unidade/órgão**; **fonte = Pessoas (viva)**, **NÃO o Intranet** (o Intranet será descomissionado; a
regra de negócio de gestão vive no Pessoas).

**Achados verificados (read-only, 2026-10-07; insumo — não re-medir sem necessidade):**
- O passo 5 da cascata **já lê** gestor do Pessoas (`autorizacao_frequencia.rb:189-192` →
  `Pessoas::Unidade#gestor?/#cadeia_ascendente/#elegivel?`). A parte de "implementar a cascata" sobre
  isso **já existe** (29.4) — **não há autorização nova a implementar**.
- Pessoas: **1330** unidades; **518** gestores distintos (gestor/substituto/excepcional); **494** com
  lotação vigente; **24 SEM lotação vigente** (= o **furo de desenho real**).
- O `User` local nasce por unidade de **LOTAÇÃO** (`ImportarServidoresUnidadeJob#perform(unidade_id)` →
  `unidade.servidores` → `importar_servidor(cpf)` → `criar_user_se_necessario` +
  `AtualizarFrequentadorCacheService.call`). Um gestor **sem lotação vigente nunca é importado** → não
  tem `User` local → **não consegue logar** → não exerce o passo 5 (a cascata avalia o `usuario`
  **logado**). **É esse o gap que a 30.10 fecha.**
- **Ressalva:** a cobertura real em **PROD** **não** foi medida (prod = localhost; inalcançável daqui).

## Decisão de numeração e rastreabilidade

- Última iteration com arquivo: **29** (`docs/progress/iteration_29.md`). A 29 está **COMPLETA** (29.0–29.8 commitadas, branch `integration/sprint-29` @ `b47c0ce`). Próximo número livre: **30**.
- **Gap de rastreabilidade declarado:** o `implementation_plan.md` (`docs/12-plano-implementacao/`) **não** reflete as Sprints 29/30; não é fonte de escopo desta sprint. A formalização do épico/Gantt é do **Project Planner** (fora desta sprint). Registrado em §"Débito de rastreabilidade".

## Pré-condições

- Sprint 29 **mergeada** (a 30 consome `AutorizacaoFrequencia`, `FrequentadoresVisiveis`, `ElegibilidadeDesconsideracao`, `FrequenciaAutorizacaoCascata`, `FrequenciaAuthorization` — todos da 29).
- **Aprovação explícita do dev** (regra global do `CLAUDE.md`: alterar autorização/rotas exige plano claro): a tarefa **30.2** (ponto de entrada HTTP + `Ability`) só inicia após OK do dev sobre o plano da **30.1**.
- **Ruling de produto** (CTO/PO) antes da implementação das roles — ✅ **SATISFEITO** (dev, 2026-10-06): ruling **30.3 = A** (manter simplificado + semear as 2 roles da cascata; só frequência; adiar perfis), **emendado em 2026-10-07** para **"A + expansão incremental dirigida pelo PRD"** (ver §"Emenda do ruling A"). A implementação correspondente **da Sprint 30** é a **30.9** (as 2 roles da cascata); a **expansão incremental** não é escopo desta sprint — cada role futura entra na tarefa/sprint que implementa a **seção do PRD que a consome**.
- Baseline da suíte a isolar: **1083 runs / 3789 assertions / 1F + 11E / 0 skip** (as 12 são pré-existentes: 11× Devise `redirect_to` + 1× timezone em `presenca_endpoints_test.rb`). Isolar as pré-existentes; o 13º erro (`Pessoas::Vinculo.ativos` por `remove_method`) é order-dependent — rodar isolado antes de tratar como regressão.

## Desenvolvedores

| Dev | Perfil | Foco |
|-----|--------|------|
| Dev A (Code Specialist) | Backend Rails (controllers/Ability/tests) | 30.2, 30.6, 30.7, apoio à 30.8 |
| Dev B / CTO (rulings) + Code Specialist (impl.) | Autorização/roles/dados | 30.1 (co), 30.3, **30.9** (30.9a ✅ seed; **30.9b** = migração 1:1 do legado — D-6 = (i); 30.4 = **substituída pela política incremental** (emenda 2026-10-07), 30.5 = N/A, ruling A), **30.10** (cobertura do `User` local dos gestores de unidade) |
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

> **Ruling 30.3 = A (dev, 2026-10-06) — emendado em 2026-10-07:** manter simplificado + semear/atribuir **as 2 roles da cascata**; só frequência; adiar perfis. **Emenda (dev, 2026-10-07):** passa a **"A + expansão incremental dirigida pelo PRD"** — as demais roles do legado nascem **sob demanda**, na **mesma tarefa** que implementa a seção do PRD que as consome. Sob o ruling A, **30.5 não se aplica**; a **30.4** deixa de ser "N/A" puro e fica **substituída pela política incremental** (ver §"Emenda do ruling A"). A entrega da frente **na Sprint 30** segue sendo a **30.9** (abaixo).

#### Tarefa 30.3 — Ruling/desenho de produto e mapeamento das 11 roles + 7 perfis (GATE)
- User Story: Como PO, quero decidir entre manter as roles simplificadas ou expandir para as 11 roles granulares do legado, para que a cascata tenha a atribuição de valor que hoje a deixa inoperante em produção.
- Rastreabilidade: PRD §2.3 (11 roles `PresencaRolesEnum` + 7 perfis `PresencaProfilesEnum`), §9 item 2; ruling **D1** (destino reservado à Sprint 30); Quadro §9 (CTO, 2026-10-05)
- Estimativa: 3 pontos | Atribuição: CTO/PO | Dependências: nenhuma (decisão)
- **Brief de decisão:** `docs/progress/iteration_30_3_brief_roles_granulares.md` (CTO, 2026-10-06 — insumo do ruling: mapeamento legado→Frequencia das 11+7, opções **A (manter simplificado)** × **B (expandir)**, Q3 (só frequência × todas as seções), recomendação e decisões D-1..D-6; **o ruling continua sendo do dev/PO**).
- Critérios de aceite:
  - [x] Ruling registrado decidindo **manter simplificado × expandir** (com justificativa de produto) → **A — manter simplificado** (ver §"Ruling registrado" abaixo).
  - [x] **N/A sob A** (não se expande para as 11+7 → não há tabela de mapeamento a produzir). A tabela legado→Frequencia já existe como **insumo** no brief §2 (fonte, se a expansão voltar como épico próprio).
  - [x] Definido o **escopo da integração**: **só frequência** (Q3 respondida — as 11 roles restantes gateiam seções fora do domínio e várias inexistentes → peso morto/decorativo).
  - [x] Definido o **modo de atribuição**: **residual da 30.9** — seed idempotente das 2 roles (30.9a ✅) + mecanismo de atribuição **decidido** (30.9b, **Q9 ✅ RESOLVIDA**; **D-6 = (i) migração 1:1 do legado**).
  - [x] **Aprovação do PO/dev** registrada neste arquivo (dev Davi Araujo, 2026-10-06) antes da implementação (30.9).
- Status: ✅ **Concluída (ruling registrado pelo dev, 2026-10-06)** — **desbloqueia a 30.9** (residual). **30.4 = substituída pela política incremental** (emenda de 2026-10-07), **30.5 = N/A** sob o ruling A; **30.8** passa a depender da 30.9 (e não de 30.4/30.5).

##### Ruling registrado (dev, 2026-10-06)

O dev aprovou a **recomendação do brief** (`iteration_30_3_brief_roles_granulares.md` §6):

| Decisão | Resolução | Efeito |
|---|---|---|
| **D-1** (macro) | **A — manter simplificado** | **Não** expandir para as 11+7 roles/perfis do legado. **Mas semear/migrar as 2 roles que a cascata realmente usa.** |
| **D-2** (se B) | **N/A** | (não se expande) |
| **D-3** (abrangência) | **só frequência** | A expansão para estações/excepcionais/GI fica **fora** desta sprint (épico próprio, se o PO quiser). |
| **D-5** (perfis) | **adiar os 7 perfis** | Rolify não modela bundles; sem consumidor. Fora do escopo. |
| **D-4** (contagem 11×13) | **residual / prejudicada** | Sem expansão, a contagem é **moot**; só volta a importar num épico de expansão (ver **Q10**). |
| **D-6** (atribuição) | **(i) migração 1:1 do legado** | Resolvido pelo dev em **2026-10-06** (ver §"Ruling D-6" abaixo): migração 1:1 via a conexão `intranet_development` já existente (padrão `SyncDigitaisService`), read-only + `DRY_RUN` + relatório de não-resolvidos. **Não** atribuição administrativa provisória. Implementação → **30.9b** (Q9 ✅ RESOLVIDA). |

**Justificativa de produto:** a cascata consome **exatamente 2** roles; criar as outras 11+7 produziria roles **decorativas** (sem consumidor) ou exigiria **reabrir a `Ability`/controllers** por seção (alteração de autorização, fora do orçamento 3+3). Manter A dá **valor real à flag `:on`** (as 2 roles passam a existir e a ser atribuíveis) com risco **baixo e reversível** (aditivo).

**Achado factual que ancora o ruling (medido nesta árvore):**
- `db/seeds.rb:61` semeia **apenas** `%w[admin gestor operador]` — as 2 roles da cascata (`visualiza_frequentadores`/`visualiza_terceirizados`) **não são semeadas**.
- A cascata lê **exatamente** essas 2: `autorizacao_frequencia.rb:131` (passo 2) e `:139` (passo 3); espelho SQL em `frequentadores_visiveis.rb:100,109`.
- **Consequência medida:** mesmo com a flag `:on`, os passos 2/3 **não disparam para ninguém** sem atribuição manual — a flag está implementada mas **sem efeito** para os 2 caminhos de role. **É esse o gap que a 30.9 fecha.**

##### Emenda do ruling A (dev, 2026-10-07) — política de criação incremental dirigida pelo PRD

**Reabertura:** em **2026-10-07** o dev **reabriu a 30.4**. Perguntado sobre a **abrangência** da expansão (Q3 / **D-3** do brief — "só frequência" × "todas as seções"), respondeu **verbatim**:

> *"vamos criando as roles de acordo com o que for sendo implementado baseado no PRD de regras de negocio"*

**Emenda (não revogação):** o ruling **A** (2026-10-06) **não é apagado** — fica **preservado** (§"Ruling registrado" acima); esta emenda o **refina**. Sai de **"A fixo (só as 2 roles)"** para **"A + expansão incremental dirigida pelo PRD"**.

| Decisão | Antes — ruling A (2026-10-06) | Emenda (2026-10-07) |
|---|---|---|
| **D-1** (macro) | **A** — manter simplificado; **só** as 2 roles da cascata | **A + expansão incremental** — mantém o mínimo; as demais roles nascem **sob demanda**, dirigidas pelo PRD |
| **D-3** (abrangência) | **só frequência** (a expansão fica fora / épico próprio) | **dirigida pelo PRD, caso a caso** — cada seção implementada puxa a sua role; **nem** "todas de uma vez" **nem** "nada" |
| **30.4** | **"Não se aplica"** puro (ruling A) | **Substituída pela política incremental** — a criação de role vira **parte de cada tarefa futura** que implementa a seção do PRD que a consome (não há tarefa "de roles" autônoma) |

**Regra operacional (a política em uma frase):** *toda tarefa que implementar uma seção do `PRD-REGRAS-NEGOCIO-PRESENCA.md` **cria, na própria tarefa, a role que ela consome** e reabre a `Ability`/controller correspondente — com **teste de que a role SEM atribuição não muda comportamento** (inerte fora do consumidor). A **atribuição** segue o mecanismo **D-6/i** (migração 1:1 do legado) ou o que o dev definir para aquela role.*

**Justificativa de produto:** preserva o ganho do ruling A — **evita a "role decorativa"** (role sem consumidor, risco §7 do brief) **sem congelar** o sistema: as roles da expansão deixam de ser um "big-bang" orçado e passam a ser **custo da tarefa que as consome**. Detalhamento (gatilhos por seção do PRD, o que **não** existe no Frequencia) no **brief §9**.

**Efeito na frente 2:** a **30.9** (as 2 roles da cascata — 30.9a ✅ + 30.9b ✅) **permanece como a entrega desta sprint**; a expansão incremental **não** é escopo da Sprint 30. **Nenhuma tarefa nova foi criada** por esta emenda.

**Complemento (dev, 2026-10-07 — 2ª decisão: seed antecipado, opção (a)).** Em seguida o dev decidiu **semear as roles granulares desde já** ("criar as roles manualmente"), deixando-as **guardadas/inertes** até que a seção do PRD que as consome seja implementada. O **seed** das roles passa a ser **antecipado** — as 13 roles granulares foram semeadas (`db/seeds.rb`) e aplicadas ao banco. **Nada** de `Ability`/controller nem de atribuição foi criado: a role **não concede acesso por si**. Assim, a política **"incremental"** incide sobre **habilitar** (reabrir `Ability`/controller + atribuir), **não** sobre **semear** o registro da role. **Estado factual:** das **16** roles hoje no banco, **11 não têm consumidor** e são **inertes** — `visualiza_estacoes`, `controla_estacoes`, `gerencia_estacao`, `cadastra_estacao`, `gerencia_excepcionais`, `visualiza_excepcionais`, `gerencia_frequentadores`, `visualiza_gestor_individual`, `gerencia_gestor_individual`, `gerencia_retificadores`, `cadastro_digital`. **Tensão reconhecida** com o §7 do brief (risco de "role decorativa"): mitigada por serem **inertes** (efeito nulo enquanto o consumidor não existir). O **seed canônico** vive em `api-ponto/db/seeds.rb`.

##### Ruling D-6 (dev, 2026-10-06) — mecanismo de atribuição das 2 roles

O dev decidiu a **D-6** do brief (`iteration_30_3_brief_roles_granulares.md` §8):

| Decisão | Resolução | Efeito |
|---|---|---|
| **D-6** (atribuição) | **(i) migração 1:1 do legado** | As 2 roles da cascata (`visualiza_frequentadores`/`visualiza_terceirizados`) são migradas **1:1 a partir do Intranet legado**, **via a conexão direta `intranet_development` já configurada** (`config/database.yml`), no **padrão do `Intranet::SyncDigitaisService`**: **read-only**, `DRY_RUN`, **relatório de não-resolvidos**, idempotente. **Não** atribuição administrativa provisória (a opção (ii) foi **descartada**). |

**Correção factual que destrava a (i) (medida pelo CTO, 2026-10-06):**
O registro anterior deste arquivo (**Q9**, §30.9b, Riscos) afirmava que a migração não era implementável por **"dado-fonte inexistente"**. Isso é **incorreto**. O que é verdade:
- 🟢 **Correto (mantido):** a gem `SticapiClient::Intranet` (4.0.4) **não expõe** endpoint de roles/perfis (`tipo_usuario`/`grau_usuario`/`gestores_individuais`/etc., nenhum `roles`) — o **client HTTP não serve** para isto.
- 🟢 **Mas o Frequencia tem a conexão direta** ao MySQL legado: `config/database.yml` → **`intranet_development`** (host `10.254.3.6`, user `intranet`, db `intranet`), hoje usada pelo `Intranet::SyncDigitaisService` para ler digitais. A api-ponto **NUNCA escreve nesse banco** ("the api-ponto NEVER writes to this database") → a **fonte existe** pela conexão direta, em modo **read-only**.
- 🟢 **Medido na conexão (read-only):** `admin_role` tem **13** roles `presenca*`, incluindo `presencaVisualizaFrequentadores` e `presencaVisualizaFrequentadoresTerceirizados`; `admin_user` tem **9.381** usuários.
- 🟢 **Modelo do legado é por PERFIL (não role direta por usuário):** `admin_user.profileId → admin_profile →(admin_profile_role)→ admin_role`. Tabelas: `admin_user`, `admin_profile`, `admin_profile_role`, `admin_role`; a role tem coluna `roleId` (ex.: `presencaVisualizaFrequentadores`).

**Conclusão:** a 30.9b é **implementável nesta árvore** com a conexão já configurada; **Q9 RESOLVIDA (D-6 = (i))**. O registro errado ("dado-fonte inexistente") fica **retirado** (ver Q9 e Riscos).

#### Tarefa 30.4 — Implementar as roles granulares (definição + seeds)
- User Story: Como administrador, quero as roles granulares do legado definidas no Frequencia, para atribuir acesso por função em vez de pelas 3 roles genéricas.
- Rastreabilidade: PRD §2.3; ruling da 30.3; D1
- Estimativa: 3 pontos | Atribuição: Dev B | Dependências: **30.3** (ruling; se "manter simplificado", tarefa **não se aplica**)
- Critérios de aceite:
  - [ ] Roles Rolify criadas com os nomes snake_case do mapeamento da 30.3; seed **idempotente** (`add_role` já é idempotente).
  - [ ] As 3 genéricas e as 2 da 29.4 permanecem intactas (sem regressão na `Ability`/cascata).
  - [ ] Testes: seeds idempotentes (2ª execução = 0 criações); role nova não altera comportamento sob `:off`.
  - [ ] Sem alteração de schema além do que o Rolify já provê.
  - **Substituição (emenda 2026-10-07):** estes critérios passam a valer **dentro de cada tarefa futura** que implementar uma seção do `PRD-REGRAS-NEGOCIO-PRESENCA.md` (a role nasce nessa tarefa, com a `Ability`/controller reabertos e o teste da role **inerte** — sem atribuição não muda comportamento). **Não há mais tarefa "de roles" autônoma** (big-bang).
- Status: ⚠️ **Substituída pela política incremental de roles (emenda do dev, 2026-10-07; ver §"Emenda do ruling A").** A tarefa **autônoma de big-bang** (definir/semear as 11+7 de uma vez) **não se aplica** — sob o ruling **A** ela nunca criaria as 11+7, e sob a **emenda** a criação de role deixa de ser tarefa própria: vira **parte de cada tarefa futura que implementa a seção do PRD que consome a role** (ver regra operacional no brief §9.2). O que sobrevive do escopo desta tarefa (as 2 roles da cascata) foi entregue na **30.9** (30.9a seed ✅ + 30.9b migração ✅). Texto preservado para rastreabilidade.

#### Tarefa 30.5 — Atribuição/migração das roles a partir do Intranet
- User Story: Como administrador, quero migrar 1:1 as roles legadas dos usuários do Intranet, para que a atribuição real de acesso exista no Frequencia após o desligamento do legado.
- Rastreabilidade: PRD §2.3; ruling da 30.3; D1 ("migração 1:1 das 11 roles é Sprint 30")
- Estimativa: 3 pontos | Atribuição: Dev B | Dependências: **30.4** (se "manter simplificado", tarefa **não se aplica**)
- Critérios de aceite:
  - [ ] Mapeamento legado→local idempotente (upsert por chave estável); reexecução = 0 duplicações.
  - [ ] Relatório de **não-resolvidos** (usuário/CPF sem correspondência local) — nada é silenciosamente ignorado.
  - [ ] Dry-run sem escrita.
  - [ ] Testes com os mesmos padrões da 29.3 (save/restore do método original, nunca `remove_method` destrutivo).
- Status: ⚠️ **Não se aplica (ruling 30.3 = A; emendado 2026-10-07)** — não há migração 1:1 das 11 roles **nesta sprint**. O subconjunto de atribuição que sobrevive **agora** (as 2 roles da cascata) é tratado na **30.9b** (**Q9**). **Sob a política incremental**, a migração 1:1 (D-6/i) passa a ser o **padrão de atribuição da role criada em cada tarefa futura** que implementa uma seção do PRD. Texto preservado para rastreabilidade.

#### Tarefa 30.9 — Semear as 2 roles da cascata e atribuí-las (residual do ruling A; substitui 30.4/30.5)
- User Story: Como administrador, quero as 2 roles que a cascata realmente consome (`visualiza_frequentadores`/`visualiza_terceirizados`) **semeadas e atribuídas**, para que os passos 2/3 da cascata passem a disparar **de fato** sob `:on` — a **30.9a** fez as 2 existirem no seed; a **30.9b** as **atribui** (sem atribuição, a flag segue sem efeito real para os 2 caminhos de role).
- Rastreabilidade: ruling **30.3 = A** (dev, 2026-10-06); brief §1 (achado: `db/seeds.rb:61` semeia só 3; cascata lê 2); `autorizacao_frequencia.rb:131,139`; `frequentadores_visiveis.rb:100,109`; PRD §2.3 (#8/#9); D1 (29.4)
- Estimativa: **5 pontos** (30.9a = **2** ✅ implementado + **30.9b = 3** — ver reestimativa em 30.9b; a antiga "reestimativa condicional" se **realizou** com **D-6 = (i)**) | Atribuição: Dev B | Dependências: **30.3** (ruling ✅) e **30.9a** (✅ aprovado — as 2 roles existem no seed antes de serem atribuídas)

##### 30.9a — Seed idempotente das 2 roles (factível aqui; sem dado externo)
- Critérios de aceite:
  - [x] Estender o seed para criar `visualiza_frequentadores` e `visualiza_terceirizados` com o **mesmo padrão idempotente** de `db/seeds.rb:61` (`Role.find_or_create_by!`) — de `%w[admin gestor operador]` para as 5 roles efetivas.
  - [x] Teste: **2ª execução = 0 criações** (idempotência) e as 3 genéricas **intactas**.
  - [x] **Sem regressão sob `:off`** (as roles só são lidas com a cascata ligada — `FrequenciaAuthorization#restringir_frequencia` retorna cedo em `:off`/`:shadow`; logo **semear é inerte fora de `:on`**).
  - [x] Sem alteração de schema além do que o Rolify já provê.
- Status: ✅ **Implementado, ✅ Aprovado** (Code Reviewer, 2026-10-06) — 0 blockers. Relatório: `docs/quality/review_report_30_9a.md`. Branch `feature/demanda-30-9a-seed-roles-cascata` @ `98c43ce`. Suíte direcionada 10/37/0F/0E; completa 1098/3876/1F+12E (13 pré-existentes).

##### 30.9b — Migração 1:1 das 2 roles do legado (D-6 = (i)) — ✅ PRONTA PARA IMPLEMENTAÇÃO
- **User Story:** Como administrador, quero migrar 1:1 do Intranet legado a atribuição das 2 roles que a cascata consome (`visualiza_frequentadores`/`visualiza_terceirizados`), para que os passos 2/3 da cascata passem a disparar **de fato** sob `:on` após o desligamento do legado — sem depender de atribuição administrativa manual.
- **Rastreabilidade:** ruling **D-6 = (i)** (dev, 2026-10-06); ruling **30.3 = A**; brief §1/§8 (D-6); `config/database.yml` (`intranet_development`); `Intranet::SyncDigitaisService` (padrão de leitura read-only do legado); `ImportarGestoresIndividuaisService` (padrão de `DRY_RUN` + `nao_resolvidos` + idempotência por chave estável); `autorizacao_frequencia.rb:131,139` (passos 2/3 — as 2 roles lidas; o `:100,109` citado antes era troca com `frequentadores_visiveis.rb`); `db/seeds.rb` (30.9a).
- **Atribuição:** Dev B | **Dependências:** **30.9a** ✅ (as 2 roles existem no seed antes de serem atribuídas) e **30.3** (ruling ✅).
- **Estimativa:** **3 pontos.** Reestimada de 2 → 3: a entrega saiu de "seed + atribuição a definir" para **migração real** — resolver `admin_user→profile→roles` para **9.381** usuários, casar com o `User` local, aplicar idempotentemente só as **2** roles, com `DRY_RUN` e relatório de não-resolvidos. Ancora entre o seed da 30.9a (2) e a importação completa da 29.3 (5 pts, `ImportarGestoresIndividuaisService`). **Não quebra em 30.10** (ver "Avaliação de quebra" abaixo).
- **Critérios de aceite:**
  - [ ] **Read-only via a conexão `intranet_development`** (`config/database.yml`), no padrão de `Intranet::SyncDigitaisService` (abre `Mysql2::Client` a partir de `config.database_configuration["intranet_#{Rails.env}"]`; **nenhum** INSERT/UPDATE/DELETE no banco legado — "a api-ponto NUNCA escreve nesse banco").
  - [ ] **Resolve `admin_user → profile → roles`**: lê a cadeia `admin_user.profileId → admin_profile →(admin_profile_role)→ admin_role` e identifica quem possui `admin_role.roleId = presencaVisualizaFrequentadores` / `presencaVisualizaFrequentadoresTerceirizados` (o modelo do legado é **por PERFIL**, não role direta por usuário).
  - [ ] **Mapeia só as 2 roles da cascata** → `visualiza_frequentadores`/`visualiza_terceirizados` (Rolify). Nenhuma das outras 11 `presenca*` é criada/atribuída (ruling A, "só frequência").
  - [ ] **Idempotente por chave estável**: casar o usuário legado com o `User` local por chave estável (ex.: CPF/matrícula — o mesmo eixo de `ImportarGestoresIndividuaisService`/`SyncDigitaisService`); `add_role` é idempotente → **2ª execução = 0 duplicações/0 alterações líquidas**.
  - [ ] **`DRY_RUN` sem escrita** + **relatório de não-resolvidos** no padrão `ImportarGestoresIndividuaisService`/`SyncDigitaisService` (resumo com `importados`/`atualizados`/`nao_resolvidos`; nada silenciosamente ignorado; em execução real, o relatório sai no log/task).
  - [ ] **Sem regressão sob `:off`**: atribuir as 2 roles não altera comportamento fora de `:on` (`FrequenciaAuthorization#restringir_frequencia` curto-circuita em `:off`/`:shadow`).
  - [ ] **Testes no padrão da 29.3**: injetar o conjunto de registros (sem tocar a rede/legado), com **save/restore do método original — NUNCA `remove_method` destrutivo** (lição herdada do 13º erro / chore de stubs destrutivos). Cobrir: dry-run não escreve; 2ª execução = 0 criações; não-resolvidos vão ao relatório; só as 2 roles são tocadas.
- **Avaliação de quebra (CTO, 2026-10-06):** **não quebrar em 30.10.** *(Nota de 2026-10-07: aqui "30.10" era só o número **hipotético** da subdivisão da 30.9b — **não** confundir com a **tarefa 30.10 real** criada em 2026-10-07, que é outra frente.)* Leitura do legado (SQL perfil→roles), casamento com o `User` local, aplicação idempotente, `DRY_RUN` e relatório são **um serviço coeso** — o mesmo desenho de `ImportarGestoresIndividuaisService` (que coube em uma tarefa). Fatiar duplicaria a leitura do legado (9.381 usuários) e criaria dependência artificial. A divisão só se justificaria se a descoberta exigisse uma **entrega intermediária** (ex.: artefato de mapeamento revisado por humano antes de aplicar) — cenário não indicado pelo ruling. Mantida como **tarefa única de 3 pts**.
- **Parâmetro a confirmar com o dev (NÃO decidido pelo CTO):** qual o **limiar de aborto** (ou de alerta) se a contagem de **não-resolvidos** for alta. Registrado como **pergunta aberta Q11** — é decisão operacional do dev, não do CTO.
- Status: ✅ **Implementado, ✅ Aprovado** (Code Specialist + Code Reviewer, 2026-10-06; 0 blockers; 3 🟡) — S1/S2 corrigidos, S3 documentado. Branch `feature/demanda-30-9b-migracao-roles-legado` @ `e79d89d`. **Entrega:** serviço `Intranet::MigrarRolesCascataService` (`app/services/intranet/migrar_roles_cascata_service.rb`) — leitura read-only da cadeia por perfil (`admin_user.profile_profileId → admin_profile → admin_profile_role → admin_role`, só SELECT), filtro fechado nas 2 roles (`MAPEAMENTO`), casamento login→`User` por `lower(username)` (fallback CPF), idempotente sequencial (`has_role?`+`add_role`; concorrência = débito S3 documentado), `DRY_RUN`, relatório `processados/atribuidos/sem_alteracao/nao_resolvidos/erros` sem PII e com **`falha_leitura` explícito** (não confunde "leitura falhou" com "nada a migrar"); rake `frequencia:migrar_roles_cascata` (`DRY_RUN=1`; `abort`/exit≠0 em falha de leitura, inclusive em DRY_RUN); teste (12 testes). **Evidência medida:** arquivo 12/44/0F/0E; direcionada 68/237/0F/0E; **suíte completa 1110/3920/1F+12E** (baseline 1098/3876/1F+12E → +12 runs/+44 asserts; mesmos 13 pré-existentes). RuboCop 0 offenses; zeitwerk OK. **Mutation testing 6/6 mortas** (mapeamento, idempotência, dry-run, case-sensitivity, guard do concern:47 via teste de inércia corrigido, ramo de `falha_leitura`). Relatório: `docs/quality/review_report_30_9b.md`. **Schema legado medido read-only:** `admin_user` PK = `login` (não há `id`), coluna de perfil = **`profile_profileId`** (o brief dizia `profileId`); cadeia perfil→role por STRING; volumes: **44** usuários em `presencaVisualizaFrequentadores` e **22** em `...Terceirizados` (~66 atribuições — bem abaixo dos 9.381 do total de `admin_user`). **Execução real pendente de `DRY_RUN=1 bin/rails frequencia:migrar_roles_cascata`** contra o legado (confirma a taxa de não-resolvidos; ver risco 1).

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

#### Tarefa 30.8 — Observação do modo `:shadow` e produção do insumo de decisão sobre a flag
- User Story: Como time da sprint, quero um relatório das negações que a cascata faria num ciclo de shadow, para **decidir** (com risco medido) se a flag vira `:on` — hoje a cascata está implementada mas não vigente.
- Rastreabilidade: ADR-0010 regra 4 (flag 3 estados); ruling **D3**; Quadro §9 item 1 (ressalva "flag default OFF"); **Q5/Q6 ✅** (dev, 2026-10-06); **re-escopo CTO 2026-10-08** (§"Re-escopo da 30.8 e encerramento da Sprint 30")
- Estimativa: 3 pontos | Atribuição: CTO/Dev A (execução + decisão); PO **consultado** (não é gate — Q6) | Dependências: **30.2** (gate D5, mesma flag), **30.9a ✅ + 30.9b** (as 2 roles semeadas e migradas) e o **Passo 1** (DRY_RUN real + aplicação das roles, Q11)

> **🔁 RE-ESCOPO (CTO, 2026-10-08) — o critério "7 dias em PRODUÇÃO" foi substituído por "observação em DEV".** O texto original é **preservado abaixo em tachado**, para rastreabilidade; o critério vigente é o **re-escopado**. Fundamento: **não existe ambiente de produção** (só `api_ponto_development`; o dev declarou "esquece produção, a app tá longa de prod") → o critério original era **inexequível**; e a **observação de shadow já foi feita em DEV** (ver §"Observação de shadow em DEV (realizada)").

- Critérios de aceite (**RE-ESCOPADOS**, 2026-10-08):
  - [x] ~~Rodar `FREQUENCIA_AUTORIZACAO_CASCATA=shadow` por **1 ciclo** = **7 dias em PRODUÇÃO** (**Q5 ✅**).~~ → **Substituído por:** **observar o modo `:shadow` em DEV** pelo ciclo possível nesse ambiente. **Realizado** (relato/medição do dev, 2026-10-08; ver §"Observação de shadow em DEV"): **1366 eventos** `frequencia_autorizacao_cascata.shadow`, **todos `:negado`**. Considerado **insumo válido** para o encerramento (com as limitações **declaradas** abaixo).
  - [x] Consolidar as contagens de `EVENTO_SHADOW` (`frequencia_autorizacao_cascata.shadow`) **por motivo** (`proprio`/`role_geral`/`terceirizado`/`gestor_individual`/`hierarquia`/`negado`), destacando as que **seriam negadas**. → Consolidado **no grão disponível**: **todos** os 1366 eventos de DEV são `:negado` (o ator observado — `davi.queiroz` id 73, **sem role**, `admin=false` — só veria a si mesmo; logo a negação para terceiros é o **resultado esperado** do shadow, não um defeito). A abertura por motivo **completa** dos passos 2/3/4/5 **não foi obtida** (ver limitação (b)).
  - [ ] Relatório do insumo de decisão produzido em `docs/quality/` (ou `docs/progress/`), com as **limitações declaradas** — em especial: o gate D5 é `:on`-only e **não** produz sinal em shadow. **NÃO PRODUZIDO COMO ARQUIVO SEPARADO:** o insumo fica **registrado neste iteration** (§"Observação de shadow em DEV (realizada)"), com as **4 limitações** declaradas (sem produção; passos 2/3 sem sinal; flag em DEV local; D5 `:on`-only). Se o dev quiser o relatório dedicado, é follow-up.
  - [ ] **DECIDIR** se a flag vira `:on` — **Q6 ✅ (dev, 2026-10-06): a decisão é DA SPRINT**, não um gate separado do PO. **⚠️ PENDENTE — decisão do dev (Q16), NÃO tomada pelo CTO.** A 30.8 **inclui a decisão** (PO como stakeholder consultado); como o insumo é **parcial** (limitações a/b), a decisão de virar `:on` fica **SHELVED** (pendente) — registrada como **pergunta ao dev** (§Q16), não resolvida aqui. Se a decisão for ligar, o registro da virada + o plano de reversão entram no relatório final.
  - [x] Sem alteração de código de produção (execução/observação). → Mantido: nenhum arquivo de `app/` foi alterado para esta tarefa.
- **Limitações declaradas (2026-10-08) — o insumo NÃO é um ciclo de produção:**
  - **(a) Sem ambiente de produção.** Só existe `api_ponto_development`; o "7 dias em PRODUÇÃO" era **inexequível**.
  - **(b) Passos 2/3 da cascata sem sinal.** As roles não são atribuíveis no DEV: a migração **30.9b** (D-6/i) está **bloqueada** com **87,9% de não-resolvidos** (muito acima do limiar de aborto de 10% — Q11) → os caminhos de role (`visualiza_frequentadores`/`visualiza_terceirizados`) **não dispararam** na observação.
  - **(c) Flag em DEV é `:shadow` local (não-commitado).** O default de `development.rb` aponta para `:shadow` localmente; **não** é configuração versionada nem de produção.
  - **(d) O gate D5 é `:on`-only.** Não produz sinal em shadow (por desenho, ADR-0010 / Q7): a observação **não** mede o gate de desconsideração.
- **Pré-condição operacional (Passo 1 do plano do Orchestrator):** rodar o `DRY_RUN=1 bin/rails frequencia:migrar_roles_cascata` **real** contra o legado, avaliar os não-resolvidos contra o limiar de **10%** (**Q11 ✅**) e **aplicar as 2 roles** no ambiente do shadow — sem isso os passos 2/3 da cascata não disparam e o ciclo de shadow fica cego justamente para os caminhos de role. **ESTADO (2026-10-08): BLOQUEADO — a execução real da 30.9b dá 87,9% de não-resolvidos (> 10%)**, logo a pré-condição **não** foi satisfeita. É a causa direta da limitação (b).
- Status: **✅ Concluída sob o re-escopo (CTO, 2026-10-08)** — observação em DEV **realizada** (1366 eventos; insumo válido com limitações (a)–(d) declaradas); **Passo 1 BLOQUEADO** (30.9b a 87,9% de não-resolvidos). **Resta a decisão do dev de virar `:on` — SHELVED (Q16), não decidida pelo CTO.** *(Status original: ⬜ Pendente — desbloqueada por Q5/Q6/Q11 em 2026-10-06; falta o Passo 1 operacional.)*

##### Observação de shadow em DEV (realizada) — insumo da 30.8

> **⚠️ Natureza do dado:** os números abaixo são **relato/medição do dev (2026-10-08)** — **não** estão em arquivo versionado (não há dump/relatório no repo). Registre-se **como tal** (medição relatada, a confirmar se necessário), **não** como métrica re-extraída pelo CTO.

- **Flag observada:** `FREQUENCIA_AUTORIZACAO_CASCATA=:shadow` — **default local em `config/environments/development.rb`**, **NÃO commitado** (working tree; ver S2 do review do fix).
- **Ator observado:** `davi.queiroz` (id **73**; **sem role**; `admin=false`) navegando em DEV.
- **Volume:** **1366 eventos** `frequencia_autorizacao_cascata.shadow` gerados.
- **Distribuição:** **todos `:negado`** (100%). **Interpretação:** resultado **esperado** — sem role, sem gestão de órgão e sem `GestorIndividual`, o único passo que poderia liberá-lo é o **passo 1 (próprio)**; qualquer alvo de **terceiro** cai em `:negado`. O shadow **não** nega de fato (só loga) — o ator seguiu vendo tudo.
- **Valor como insumo:** confirma que o **instrumental de shadow funciona** em DEV e produz trilha; **não** mede o que os passos 2/3/4/5 liberariam de fato (limitação (b)), porque o DEV não tem as roles atribuídas nem os atores representativos.
- **Decisão de ligar `:on`:** **NÃO tomada** — ver **Q16**.

### Frente 5 — Cobertura do `User` local dos gestores de unidade (diretiva do dev, 2026-10-07)

#### Tarefa 30.10 — Garantir o `User` local dos gestores de unidade a partir do Pessoas
- User Story: Como **gestor de unidade** (atual/substituto/excepcional), quero ter uma **conta local** no Frequencia **mesmo sem lotação principal vigente**, para conseguir entrar no sistema e exercer o passo 5 (hierarquia) da cascata — hoje **24 gestores** nunca são importados porque a importação nasce da lotação (`unidade.servidores`) e eles não têm lotação vigente.
- Rastreabilidade: **Diretiva do dev (2026-10-07)**; ruling de mapeamento **gestor = gestor de unidade/órgão** (não é role — ver §"Diretiva do dev"); `Pessoas::Unidade#gestor/#gestor_substituto/#gestor_excepcional`; `ImportarServidoresUnidadeJob#criar_user_se_necessario` (padrão de criação); `Intranet::MigrarRolesCascataService`/`ImportarGestoresIndividuaisService` (padrão read-only + `DRY_RUN` + relatório de não-resolvidos); ADR-0010 regra 4 (rollout) e §30.8.
- Estimativa: **3 pontos** | Atribuição: **Dev B** | Dependências: **nenhuma hard** — mas **precede a 30.8** (eleva a cobertura observada no ciclo de shadow; ver decisão de sprint abaixo).
- **Escopo (o que ENTRA):** serviço read-only no Pessoas que enumera os gestores distintos (união de `unidade.gestor`+`gestor_substituto`+`gestor_excepcional` das 1330 unidades, **deduplicados por CPF**) e **garante o `User` local** (criar se ausente, **por CPF**), reutilizando o padrão `criar_user_se_necessario` (nome_completo, `username = pessoa.username`, password placeholder) + `AtualizarFrequentadorCacheService.call`; **foco no furo dos 24 sem lotação vigente**; rake/task de execução; `DRY_RUN` + relatório de não-resolvidos. **Complementar** ao `ImportarServidoresUnidadeJob` (que segue importando por lotação). *(Exceção sancionada no review de 2026-10-07: a regra de criação do `User` foi extraída do job para o colaborador compartilhado `GarantirUserLocalService` — delegação behavior-preserving; ver Status abaixo.)*
- **Escopo (o que NÃO ENTRA):**
  - **Não** altera a **cascata** nem a `Ability` — o passo 5 já lê gestor do Pessoas (nada de autorização a implementar).
  - **Não** cria role "gestor"/"gestor geral" (inexistente — ver correção factual) nem atribui roles (isso é a **30.9b**).
  - **Não** cria `GestorIndividual` (isso é a **29.3**).
  - **Não** altera o **critério de lotação** do `ImportarServidoresUnidadeJob`. *(Exceção sancionada no review de 2026-10-07: a regra de criação do `User` foi extraída para `GarantirUserLocalService` — delegação behavior-preserving, teste do job verde.)*
  - **Não** liga a flag `:on` (decisão da **30.8**).
  - **Não** implementa autenticação/login real (password placeholder, como no job atual).
- Critérios de aceite:
  - [x] Enumera os gestores distintos do Pessoas a partir de `unidade.gestor`/`gestor_substituto`/`gestor_excepcional` (**read-only**), **deduplicados por CPF**; cobertura-alvo = os **518** gestores distintos (dos quais **24** sem lotação vigente).
  - [x] Cria o `User` local ausente **por CPF** (`find_or_initialize_by(cpf:)`) com `nome_completo`/`username` (= `pessoa.username`)/password placeholder e chama `AtualizarFrequentadorCacheService.call`; **NÃO sobrescreve** `User` existente.
  - [x] **Idempotência:** 2ª execução = **0 criações**.
  - [x] **`DRY_RUN` sem escrita:** relatório completo com **0** `User`/`FrequentadorCache` criados.
  - [x] **Relatório de não-resolvidos sem PII** (gestor sem CPF, pessoa ausente/indisponível no Pessoas) — só contagem **por motivo**; nada silenciosamente ignorado.
  - [x] **Read-only no Pessoas:** nenhuma escrita no banco espelho (contrato `PessoasRecord`).
  - [x] **Testes** com o conjunto de unidades/gestores **injetado em memória** (sem tocar o Pessoas): dry-run não escreve; 2ª execução = 0 criações; não-resolvidos vão ao relatório; só gestores são tocados. **Save/restore do método original — NUNCA `remove_method`** (usar `test/support/class_method_stub_helper.rb`; lição da chore de stubs destrutivos).
  - [x] **Sem regressão sob `:off`** (criar `User` não altera comportamento fora de `:on`); sem alteração de código de produção da cascata/`Ability`.
- **Decisão de sprint — entra na Sprint 30 como 30.10 (NÃO vai para a Sprint 31).** Justificativa pela **dependência com a 30.8** (rollout shadow): o ciclo de shadow de 7 dias só observa quem **consegue logar**; um gestor sem `User` local **não loga** e **não é observado** — os **24** sem lotação vigente seriam um **ponto cego exatamente no caminho da hierarquia (passo 5)**. Rodar a 30.10 **antes** do ciclo da 30.8 eleva a **cobertura observada** e o valor do insumo de decisão — **o mesmo raciocínio** que põe a **30.9** (cobertura de roles) antes da 30.8. É **aditiva, reversível e de baixo risco** (criação idempotente de conta; sem autorização nova). A **30.8** passa a **depender também da 30.10**.
- **Riscos:**
  - Gestores de unidades **inelegíveis/extintas** — decidir se criam `User` (**recomendado: sim** — a conta é neutra; a elegibilidade é avaliada em tempo de request pelo passo 5). Confirmar com o dev (**Q12**).
  - **Colisão de `username`/CPF** já usado por outro `User` — **não** resolver silenciosamente; entra no relatório.
  - **Volume/ruído:** criar `User`s altera contagens de FrequentadorCache/relatórios; executar em `DRY_RUN` antes da real.
  - **Cobertura de prod não medida** (localhost) — a 30.10 mede contra o Pessoas disponível; o limiar fica com o dev.
- Status: ✅ **Implementado, ✅ Aprovado (Code Reviewer, 2026-10-07; 0 blockers 🔴; 2 🟡 + 2 🟠 não-bloqueantes)** — Relatório: `docs/quality/review_report_30_10.md`. Branch `feature/demanda-30-10-user-local-gestores-unidade` (base `71e91f1`; **NÃO commitado**). **Evidência reproduzida pelo revisor:** service test **14/56/0F/0E**; job+service **24/75/0F/0E**; RuboCop **0 offenses** nos 5 arquivos. **Verificado:** comportamento externo do `ImportarServidoresUnidadeJob` **preservado** (paridade campo a campo; cache sempre chamado em `importar_servidor:70`; retorno `nil/save!`→`true/false` inócuo); **read-only** no Pessoas (`PessoasRecord`); **sem autorização nova**; **PII contida** (resumo por motivo, logs sem CPF/login/nome); **idempotência** (`find_or_initialize_by(cpf:)` + retorno antecipado ⇒ 2ª execução = 0 criações/0 escritas); `normalizar_cpf` com `.presence` **confirmado sem risco de duplicata** (mesmo `pessoa.cpf` cru do job × validação `/\A\d{11}\z/`); dedup id→CPF, FK órfã e colisão de `username` tratadas; testes não-degenerados com **save/restore, nunca `remove_method`**. **🟡/🟠 não-bloqueantes:** S1 (S2 do relatório) colisão de `username` deixa o gestor sem conta — decidir fallback/documentar; D1 (PII em log do job, pré-existente); D2 (cache write-once p/ gestores).
- **⚠️ Desvio de escopo — RESOLVIDO pelo review: opção (a) ACEITA.** O `ImportarServidoresUnidadeJob` **FOI alterado**, apesar das linhas de escopo dizerem "não o altera": o body de `criar_user_se_necessario` passou a delegar a `GarantirUserLocalService.call` (−26/+6) — extração da regra de criação do `User` para um colaborador **compartilhado** (evita duplicar a regra). O revisor **confirmou paridade de comportamento** (campos, fluxo e `AtualizarFrequentadorCacheService.call` SEMPRE — inclusive quando o `User` já existe) e os testes do job seguem verdes (24/75/0F/0E). **Mantida a extração**; recomendação: ajustar o texto de escopo acima ("não o altera") para refletir a exceção sancionada.

## Re-escopo da 30.8 e encerramento da Sprint 30 (CTO, 2026-10-08)

### Estado de encerramento — 🟢 SPRINT 30 ENCERRÁVEL

A Sprint 30 fica **encerrável** com este registro. **Não há tarefa de implementação pendente**:

| Tarefa | Status | Observação |
|---|---|---|
| 30.1 / 30.2 | ✅ Concluída / Aprovada | gate D5 HTTP sob a flag |
| 30.3 | ✅ Concluída (ruling A, emendado) | — |
| 30.4 / 30.5 | Substituída / N/A | política incremental de roles |
| 30.6 / 30.7 | ✅ Aprovadas | débitos 🟡S2/🟡S3 fechados |
| 30.9a / 30.9b | ✅ Aprovadas | 2 roles semeadas e migração implementada (execução real bloqueada — ver risco 1/Q11) |
| 30.10 | ✅ Aprovada | `User` local dos gestores |
| **30.8** | ✅ **Concluída sob re-escopo** | observação em DEV realizada; **decisão de `:on` SHELVED (Q16)** |
| **Fix cobertura da cascata** (bugs 🔴1/🟡3) | ✅ Aprovado (`f89d312`/`bcf0807`) | fora do backlog nominal; publicado |

**Único item NÃO fechado (por decisão, não por trabalho):** a **decisão do dev de virar a flag `:on`** — registrada como **Q16**, **shelved** (ver §"Re-escopo da 30.8" e §Q16). O CTO **não** decide pelo dev.

**O que faltaria para um "encerramento pleno" (opcional, não bloqueante):**
1. Decisão de **Q16** (`:on` sim/não) pelo dev — hoje shelved.
2. Desbloqueio do **Passo 1** (30.9b a **87,9%** de não-resolvidos → rever o eixo de casamento `login → username` antes de aplicar as roles; Q11).
3. Follow-up decorrente: com as roles atribuídas (Passo 1 ok), repetir a observação de shadow para obter a abertura **por motivo** (limitação (b)).

### Sprint 30 — Bug 🟠2 = RISCO ACEITO com gatilho de revisita (NÃO resolvido)

- **Origem:** `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md` (Bug 🟠 2, 2026-10-07; nota do dev em `:69`).
- **Descrição:** `/presenca/PontoDePresenca` (batidas do dia de **todos**) e `/presenca/DynFrequentadoresEstacao` (hashes biométricos + usuários) acessíveis **SEM autenticação**, a qualquer host da rede.
- **Decisão (dev, 2026-10-08):** **ADIADO** — os endpoints abertos são necessários aos **testes manuais** da Estação (JavaFX). `/presenca` é o **kiosk** do terminal; o campo de login ali **não é autenticação** — é **disparador de ponto** (digitar o login registra a batida, como a biometria).
- **⚠️ NATUREZA DO REGISTRO: é RISCO ACEITO TEMPORARIAMENTE — NÃO é "resolvido", NÃO é "falso positivo", NÃO é "por design".** A superfície **segue aberta** e é a de **maior risco** do sistema (dados biométricos de terceiros + batidas do dia).
- **Gatilho de revisita (obrigatório):** **após o término dos testes manuais da Estação** — revisitar a **distinção de host**.
- **Opções na revisita (uma deve ser escolhida):**
  - (a) **Rede/allowlist** (mTLS / IP da Estação no reverse-proxy) — **fora do código Rails**; não fere ADR-0003;
  - (b) **Gate por ativação** (`EstacaoPonto.codigo_ativacao_valido?`) — hoje **inaplicável sem quebrar o kiosk** (a Estação chama `DynFrequentadoresEstacao` **sem** `codAtivacao`; o `InicializarPonto` redireciona sem código — ver `iteration_fix_cascata_cobertura.md` §3); exigiria mudar o protocolo (**fere ADR-0003**);
  - (c) **Aceitar** como superfície de rede por design (ADR-0003) e formalizar a aceitação **permanente** (com revisão periódica).
- **Dono:** CTO (encaminhamento) + dev (decisão). **Enquanto não decidido, nenhum arquivo de `app/controllers/presenca/*`, `config/routes.rb`, `ApiController` ou Devise foi tocado.**

### Sprint 30 — DÉBITO ESTRUTURAL (causa-raiz do Bug 🔴1): enforcement opt-in da cascata

> **Este é o débito mais importante que a Sprint 30 expõe** — a causa-raiz que permitiu o Bug 🔴1 e que **pode repetir** em qualquer controller novo. Encaminhado como **nota/emenda à ADR-0010** (ver §"Emenda da ADR-0010").

- **Causa-raiz (Bug 🔴1):** a cascata é **opt-in por controller** (concern manual `FrequenciaAuthorization`). O baseline `authorize! :read, :all` **satisfaz** o `check_authorization` do base controller — então **qualquer controller novo que leia `TimeRecord`/`Pessoas::Vinculo` e chame `authorize! :read, :all` vaza silenciosamente** o roster/registros, **em qualquer valor da flag** (inclusive `:on`). O Bug 🔴1 (`/admin/users`) é o **caso concreto**; a mesma classe reaparece em `/time_records` (Bug 🟡3, corrigido) e na sidebar (Bug 🟢4).
- **Mecanismo que deixa passar:** `Ability#can?(:read, :all)` e `can?(:read, TimeRecord)` **por CLASSE** seguem `true` mesmo sob `:on`; a negação sob `:on` é **só** a filtragem de listagem + o bloco **por instância**. Tela/autorização que só pergunte por `:all`/classe continua liberada (info do Bug Finder §Info 2).
- **Débito de DRY (correlato):** `incluir_cpfs_com_cascata` **duplicado** em `frequentadores_controller` (privado) e espelhado em `users_controller`; **home natural = concern `FrequenciaAuthorization`** (compartilhado por 6 controllers). Paridade hoje 100% fiel; duas cópias **divergem** com o tempo (S1 do `review_report_fix_cascata_cobertura.md`). **Não** refatorado no fix para não tocar a cascata em produção — **sinalizado ao CTO**.
- **Onde registrar:** **emenda/nota na ADR-0010** (o "**onde** restringir", hoje ausente — a ADR cobre bem o "como restringir" e deixa implícito o "onde") + **registro de débito com dono/gatilho** (abaixo).
- **Mitigação estrutural (para tarefa futura — NÃO implementar agora):** (i) enforcement **central** (ex.: `before_action` no base que exija participação na cascata para `TimeRecord`/`Pessoas::Vinculo`), OU (ii) **teste de conteúdo obrigatório por tela de listagem** (assertar ausência do terceiro), no grão da matriz de aceite da 29.8. O teste `users_controller_test.rb` **sancionava o 200 sem assertar conteúdo** — o furo passou por isso.

**Registro de débito (dono/gatilho):**

| Débito | Severidade | Causa-raiz | Dono | Gatilho de revisita | Tarefa |
|---|---|---|---|---|---|
| **Enforcement opt-in da cascata** — novo controller que lê `TimeRecord`/`Pessoas::Vinculo` vaza silenciosamente | 🟠 Alto | concern opt-in + `authorize! :read, :all` satisfaz `check_authorization` | CTO (nota ADR-0010) + Orchestrator (agendamento) | **à primeira tela/controller que leia frequência** — ou em chore de hardening dedicada | (chore/épico — Project Planner) |
| **DRY `incluir_cpfs_com_cascata`** — duplicado em 2 controllers | 🟡 Médio | não extraído ao concern no fix `f89d312` | CTO decide extração | próxima alteração de `FrequenciaAuthorization` **ou** 3ª cópia | (chore) |

## Resumo

| Tarefa | Pontos | Dev | Depende de |
|---|---|---|---|
| 30.1 — Plano D5 + aprovação do dev (GATE) ✅ | 2 | Dev B/CTO | — |
| 30.2 — HTTP do gate D5 sob a flag ✅ | 5 | A | 30.1 |
| 30.3 — Ruling roles granulares (GATE) ✅ **A** | 3 | CTO/PO | — |
| ~~30.4 — Implementar roles (definição + seeds)~~ — **Substituída pela política incremental (emenda 2026-10-07; ver §"Emenda do ruling A")** | — | — | — |
| ~~30.5 — Atribuição/migração das roles~~ — **N/A (ruling A)**; sob a emenda, a migração 1:1 (D-6/i) é o padrão de atribuição **da role criada em cada tarefa** | — | — | — |
| 30.6 — Fechar 🟡S2 (PORO + twin SQL) ✅ | 2 | A | — |
| 30.7 — Fechar 🟡S3 (`frequencia_por_orgao`) ✅ | 2 | A | — |
| 30.9a — Seed idempotente das 2 roles da cascata ✅ | 2 | B | 30.3 ✅ |
| 30.9b — Migração 1:1 das 2 roles do legado (D-6 = (i)) ✅ | 3 | B | 30.9a ✅, 30.3 ✅ |

> **30.9a ✅ Implementado, ✅ Aprovado** (seed idempotente das 2 roles — `docs/quality/review_report_30_9a.md`). **30.9b ✅ PRONTA PARA IMPLEMENTAÇÃO** (D-6 = (i) resolvido em 2026-10-06; migração 1:1 read-only via a conexão `intranet_development`).
| 30.8 — Observação shadow (**DEV**, re-escopo 2026-10-08) + **decisão sobre `:on` (SHELVED — Q16)** | 3 | CTO/A | 30.2, **30.9a ✅ + 30.9b ✅**, **30.10**, Passo 1 (bloqueado) |
| 30.10 — Garantir o `User` local dos gestores de unidade (Pessoas) ✅ | 3 | B | — (precede 30.8) |
| **Total** | **25** | | |

> **Base do total:** 30.4 (3) + 30.5 (3) saem (**30.4 = substituída pela política incremental**; 30.5 = N/A); entra a **30.9** = 30.9a (2) + **30.9b (3)** → 23 − 6 + 5 = **22**. O "+3" antes **condicional** da 30.9b **se realizou** (D-6 = (i)). **+3** pela frente 5 (**30.10**, diretiva do dev de 2026-10-07) → **25**. A **emenda de 2026-10-07** (30.4 → política incremental) **não altera o total**: a expansão incremental **não** é escopo da Sprint 30 (cada role futura é orçada na tarefa que a consome).

## Caminho Crítico

**30.3 (✅) → 30.9a (✅) → 30.9b (3) → 30.10 (3) → 30.8 (3)** — **9 pontos residuais** (a 30.3 já fechada e a 30.9a já entregue).
**D-6 = (i) confirmado** → o "+3" antes **condicional** agora **se realizou** (a 30.9b = 3 pts entra no caminho). **30.4 = substituída pela política incremental** (emenda 2026-10-07), **30.5 = N/A**
(ruling 30.3 = A). Em paralelo, o ramo do gate D5 (**30.1 → 30.2**, 7 pontos, já implementado/aprovado) precisa
**fechar antes da 30.8** porque a 30.8 observa o estado `:on` completo na mesma flag. Os débitos
**30.6 (✅)** e **30.7 (✅)** são independentes e já rodaram em paralelo (teste-hardening, sem tocar produção).
A **30.10 (cobertura do `User` local dos gestores, 3 pts)** é a **segunda dependência de valor real** do rollout —
ao lado da **30.9** (cobertura de roles) — e por isso entra **antes** da 30.8: sem `User` local, os **24 gestores
sem lotação vigente** não logam e o shadow fica **cego no passo 5**.

> **Ordem de dependências (explicitada pelo dev):** frente 1 (30.2) e frente 4 (30.8) tocam a **mesma flag**;
> as roles (frente 2 → agora **30.9**) **precedem** o rollout — são a **dependência de valor real** da cascata.
> O gate **30.1** (aprovação do dev) **travava** a 30.2 (✅ satisfeito); o gate **30.3** (ruling do PO) **travava**
> a implementação da frente 2 — **✅ satisfeito em 2026-10-06 (ruling A), emendado em 2026-10-07 (A + expansão incremental)** → desbloqueia a **30.9** (e **não** a
> 30.4, que é **substituída pela política incremental**). **D-6 = (i) ✅ (2026-10-06)** desbloqueia a **30.9b**. A **30.8** depende agora de **30.9a ✅ + 30.9b** (as 2 roles semeadas **e atribuídas**), não de 30.4/30.5.

> **♻️ Caminho crítico ENCERRADO sob re-escopo (CTO, 2026-10-08).** Com a **30.8 re-escopada** para observação em DEV (já realizada), o caminho crítico **não tem pontos residuais de execução**. O que resta é **decisão** (virar `:on` — **Q16**, shelved) e o **desbloqueio operacional do Passo 1** (30.9b a **87,9%** de não-resolvidos — rever o eixo de casamento; Q11), **ambos fora do backlog nominal** e não bloqueantes do encerramento. Ver §"Re-escopo da 30.8 e encerramento da Sprint 30".

## Riscos

- **Alteração de autorização/rotas (30.2).** Ampliar acesso indevidamente é o risco central; mitigado por: gate **só passo 5** (`gestor_de_orgao_do?`), nunca `pode_ver?`; fail-closed em `:off`/`:shadow`; teste explícito "`GestorIndividual` vê mas não desconsidera"; aprovação do dev (30.1) antes da implementação.
- **Escopo das roles (30.3).** ✅ **Rulingado (A, 2026-10-06), emendado em 2026-10-07** — "manter simplificado × expandir" = **A + expansão incremental dirigida pelo PRD**; abrangência = **dirigida pelo PRD, caso a caso** (nem "só frequência" fixo, nem "todas de uma vez"); perfis adiados. **30.4 = substituída pela política incremental**, 30.5 = N/A; a estimativa precisa **desta sprint** é da **30.9b** (D-6 = (i), 3 pts; Q9 ✅). **Risco remanescente 🟡:** a expansão incremental exige que **cada** tarefa que implemente uma seção do PRD **crie a role e reabra a `Ability`/controller junto** — se uma tarefa implementar a seção **sem** criar a role (ou criar a role **sem** o consumidor), volta o risco da **role decorativa** (§7 do brief). Mitigação: a regra operacional do brief §9.2 + **Q13** (defaults a confirmar com o dev).
- **Atribuição das 2 roles (30.9b, Q9 ✅ RESOLVIDA).** O seed (30.9a ✅) é factível, mas **sem atribuição ele fica decorativo** — a cascata só dispara sob `:on` **com** as roles atribuídas. **Decidido D-6 = (i)**: migração 1:1 via a conexão **`intranet_development` já configurada** (read-only; a **fonte existe** pela conexão direta — retirado o registro anterior de "dado inexistente aqui"). Riscos remanescentes: (a) **não-resolvidos** (usuário legado sem `User` local correspondente, `profileId`/`roleId` inesperado) — mitigado pelo **relatório** no padrão `ImportarGestoresIndividuaisService`; o **limiar de aborto é parâmetro a confirmar com o dev (Q11)**, não decidido pelo CTO; (b) **read-only por contrato** — o serviço **não pode** escrever no banco legado ("a api-ponto NUNCA escreve nesse banco"); (c) **volume (9.381 usuários)** exige leitura eficiente (join único) e `DRY_RUN` antes da execução real.
- **Cobertura do `User` local dos gestores (30.10, diretiva do dev 2026-10-07).** O furo é de **cobertura de dados**, não de autorização (o passo 5 já lê gestor do Pessoas). Riscos: (a) gestor de unidade **inelegível/extinta** — decidir se cria `User` (**Q12**, decisão do dev; recomendado sim, é conta neutra); (b) **colisão** de `username`/CPF existente — vai a relatório, nunca resolve em silêncio; (c) criar `User`s altera **contagens** de FrequentadorCache/relatórios → `DRY_RUN` antes da real; (d) **cobertura de prod não medida** (localhost). Mitigação estrutural: idempotência por CPF + `DRY_RUN` + relatório sem PII (mesmo padrão da 29.3/30.9b).
- **S3 sem decisão de produto (Q4).** Contas locais sem CPF sob `:on` perdem os próprios registros (fail-closed). A matriz cobre o comportamento, mas a **decisão de produto** é do PO e não é resolvida aqui.
- **Rollout shadow depende de ambiente/ciclo (Q5). ✅ RESOLVIDO POR RE-ESCOPO (2026-10-08).** O critério "7 dias em PRODUÇÃO" era **inexequível** (não existe produção) → substituído por **observação em DEV**, já **realizada** (1366 eventos; insumo válido com **4 limitações declaradas** — ver §"Re-escopo da 30.8"). **Risco remanescente:** a abertura **por motivo** (passos 2/3/4/5) **não** foi obtida (limitação (b)); a **decisão de virar `:on` fica SHELVED** (Q16).
- **🔴 Bug 🟠2 = RISCO ACEITO TEMPORARIAMENTE (NÃO resolvido).** `/presenca/PontoDePresenca` + `/presenca/DynFrequentadoresEstacao` **sem autenticação** expõem batidas do dia e hashes biométricos de terceiros a qualquer host da rede. **ADIADO** (dev, 2026-10-08) para não atrapalhar os testes manuais da Estação. **Gatilho de revisita: após os testes manuais.** Opções na revisita: rede/allowlist · gate por ativação (hoje inaplicável sem ferir ADR-0003) · aceitar por design. Ver §"Bug 🟠2 = Risco Aceito".
- **🟠 Débito ESTRUTURAL — enforcement opt-in da cascata** (causa-raiz do Bug 🔴1): concern opt-in + `authorize! :read, :all` satisfaz `check_authorization` → **qualquer controller novo que leia `TimeRecord`/`Pessoas::Vinculo` vaza silenciosamente**. Mais **DRY** de `incluir_cpfs_com_cascata` (duplicado). Encaminhado à **ADR-0010** (emenda) + registro de débito com dono/gatilho. Ver §"Débito ESTRUTURAL".
- **Baseline da suíte.** 1083/3789/1F+11E/0 skip (12 pré-existentes + o 13º order-dependent `Pessoas::Vinculo.ativos`). Toda medição deve isolar as pré-existentes antes de atribuir regressão.
- **`implementation_plan.md` defasado** — não é fonte de escopo; a Sprint 30 não tem entrada no épico/Gantt (gap de rastreabilidade, abaixo).

## Débito de rastreabilidade

- [ ] `docs/12-plano-implementacao/implementation_plan.md` **não cobre as Sprints 29/30** (descreve só 24–28) — formalizar épico/Gantt é do **Project Planner**, fora desta sprint. — Severidade: 🟡 — Tarefa: (chore de planejamento)

## Débitos Técnicos

- [x] 🟡 **S2 — twin SQL cego ao PORO** (passo 4/GI inativo) — **FECHADO** (30.6, ✅ aprovado 2026-10-06; regra de conformidade na ADR-0010 regra 7)
- [x] 🟡 **S3 — `frequencia_por_orgao` fora do grão da matriz** — **FECHADO** (30.7, ✅ aprovado 2026-10-06; decisão de produto sobre sem-CPF permanece em **Q4**)
- [x] **Gate D5 sem caminho HTTP** (`pode_desconsiderar?`/`desconsiderar!` sem caller de produção) — **FECHADO** (30.1/30.2 ✅ aprovados 2026-10-05; `POST /time_records/:id/desconsiderar` sob `:on`)
- [x] **24 gestores de unidade sem `User` local** (sem lotação principal vigente → nunca importados por `ImportarServidoresUnidadeJob`; de **518** gestores distintos no Pessoas) — **FECHADO** (30.10 ✅ aprovada 2026-10-07; **resta a execução real** do serviço em `DRY_RUN` contra o Pessoas, parâmetro operacional do dev)
- [x] **As 2 roles da cascata (`visualiza_frequentadores`/`visualiza_terceirizados`) semeadas mas não atribuídas** — **seed resolvido na 30.9a ✅**; **atribuição resolvida na 30.9b ✅** (D-6 = (i) migração 1:1 do legado — commit `e79d89d`). **Resta a execução real** do `DRY_RUN=1 bin/rails frequencia:migrar_roles_cascata` contra o legado — **BLOQUEADA: 87,9% de não-resolvidos (> limiar de 10%; Q11)** → rever o eixo de casamento antes de aplicar.
- [ ] **Flag `FREQUENCIA_AUTORIZACAO_CASCATA` default `:off`** — cascata implementada/provada, **não vigente em produção** — Severidade: 🟠 — **insumo da 30.8 produzido (observação em DEV; re-escopo 2026-10-08)**; **decisão de virar `:on` = SHELVED — Q16 (dev)**
- [ ] **🔴 RISCO ACEITO — Bug 🟠2 `/presenca/*` sem autenticação** (batidas do dia + hashes biométricos de terceiros a qualquer host) — **NÃO resolvido**; ADIADO por decisão do dev (2026-10-08) até o fim dos testes manuais da Estação — **gatilho de revisita: após os testes manuais** — Dono: CTO/dev
- [ ] **🟠 DÉBITO ESTRUTURAL — enforcement opt-in da cascata** (concern opt-in + `authorize! :read, :all` satisfaz `check_authorization`) — **causa-raiz do Bug 🔴1**; qualquer controller novo que leia `TimeRecord`/`Pessoas::Vinculo` vaza silenciosamente — Encaminhado à **ADR-0010** (emenda) — Dono: CTO; tarefa: chore/épico (Project Planner)
- [ ] **🟡 DRY `incluir_cpfs_com_cascata`** — duplicado em `frequentadores_controller` + `users_controller`; home = concern `FrequenciaAuthorization` — Dono: CTO decide extração; gatilho: próxima alteração do concern ou 3ª cópia

## Definição de Pronto

> **✅ ENCERRAMENTO (CTO, 2026-10-08):** a Sprint 30 é **encerrável**. As tarefas de implementação estão concluídas/aprovadas (30.1/30.2, 30.6/30.7, 30.9a/30.9b, 30.10) ou resolvidas por substituição (30.4/30.5); a **30.8 é concluída sob o re-escopo** (observação em DEV). **Não há item de backlog em execução.** Os checkboxes abaixo ficam como **registro histórico**; o status vigente de cada um está anotado nas seções correspondentes. **Pendências (de decisão/operacional, não bloqueantes):** Q16 (`:on`) shelved; Passo 1 (30.9b) bloqueado a 87,9%; Bug 🟠2 = risco aceito com gatilho.

- [x] 30.1–30.3, 30.6–30.9 e **30.10** com status e Linha do Tempo preenchidos (**30.4 = substituída pela política incremental**; **30.5 = N/A**); gates (30.1, 30.3) com aprovação registrada.
- [ ] Testes: suíte direcionada verde + suíte completa sem regressão (as 12 pré-existentes inalteradas); mutation testing das tarefas 30.2/30.6/30.7; **30.9 com teste de idempotência do seed (2ª execução = 0 criações)**; **30.9b com teste de migração injetada (registros em memória, sem tocar o legado), `DRY_RUN` sem escrita, 2ª execução = 0 criações e relatório de não-resolvidos — save/restore, nunca `remove_method`**.
- [ ] Sem commit/push (`COMMIT_MODE=manual`); stage seletivo quando autorizado.
- [ ] Perguntas abertas ao dev/PO (Q1–**Q16**) respondidas ou explicitamente adiadas.
- [ ] **30.9b:** `DRY_RUN=1 bin/rails frequencia:migrar_roles_cascata` executado contra o legado, com a taxa de não-resolvidos avaliada contra o limiar de aborto (**Q11** — decisão do dev) antes da execução real.
- [ ] **30.10:** serviço read-only executado em **`DRY_RUN`** contra o Pessoas antes da execução real, com a cobertura dos **518** gestores (furo dos **24** sem lotação vigente) reportada; **2ª execução = 0 criações**; relatório de não-resolvidos sem PII; testes com **save/restore do método original, nunca `remove_method`**.

## Perguntas abertas ao dev / PO

> Registradas em vez de virar tarefa, por não pertencerem ao escopo aprovado ou dependerem de decisão de produto.

- **Q1 (frente 1) — ponto de entrada. ✅ RESPONDIDA (dev, 2026-10-05).** **Member action** em `Admin::TimeRecordsController` (não controller dedicado): `POST /time_records/:id/desconsiderar` (path real; o controller está sob `scope module: "admin"`). Sob `:off` = **404** (recurso indisponível). Fixada no plano da 30.1.
- **Q2 (frente 1) — extensão do D5. ✅ CONFIRMADA (dev, 2026-10-05).** **Não** haverá extensão ao `GestorIndividual`: ruling D5 mantido — **só o passo 5** desconsidera (`GestorIndividual` vê mas não desconsidera).
- **Q7 (frente 1) — evento/payload do log em `:shadow` para o gate D5 (NOVA, aberta; ver §5 do plano).** O shadow existente loga visualização (`EVENTO_SHADOW`); o gate D5 é de desconsiderar e não tem sinal em shadow (ADR-0010/30.8). Definir: reusar `EVENTO_SHADOW` (risco de poluir) × evento próprio (recomendado) × não logar. **Não** decide sozinho — pergunta ao dev.
- **Q8 (frente 1) — resposta HTTP em `:shadow` e `justificativa` em branco (NOVA, aberta).** Redirect com alerta/notice × 4xx. Recomendação registrada no plano.
- **Q3 (frente 2) — abrangência da integração das roles. ✅ RESPONDIDA (dev, 2026-10-06).** Ruling **30.3 = A**: manter simplificado; abrangência = **só frequência**. Expandir para "todas as seções" (estações/excepcionais/GI) fica **fora** desta sprint (épico próprio, se o PO quiser).
- **Q4 (frente 3/S3) — contas sem CPF.** Decisão de **produto** do PO: um não-admin sem CPF vê zero registros sob `:on` (fail-closed), perdendo os próprios. Manter assim ou criar exceção? A 30.7 apenas cobre o comportamento; **não** resolve a decisão.
- **Q5 (frente 4) — ambiente/ciclo do shadow. ✅ RESOLVIDA (dev, 2026-10-06): PRODUÇÃO, ciclo de 7 dias.** Rodar `FREQUENCIA_AUTORIZACAO_CASCATA=shadow` no ambiente real por **1 semana** e consolidar as contagens de `EVENTO_SHADOW` por motivo. Insumo da 30.8. **⚠️ RE-ESCOPADA (CTO, 2026-10-08):** a resposta "PRODUÇÃO" era **inexequível** (não existe ambiente de produção) → substituída por **observação em DEV**, já **realizada** (1366 eventos; ver §"Re-escopo da 30.8"). A consolidação **por motivo** só foi obtida no grão disponível (todas `:negado`).
- **Q6 (frente 4) — dono da decisão de ligar. ✅ RESOLVIDA (dev, 2026-10-06): NÃO — a decisão de ligar `:on` é DECIDIDA NA SPRINT** (não é gate separado do PO). **⚠️ Muda o escopo da 30.8:** ela deixa de ser "só produz o insumo" e passa a **incluir a decisão** de ligar (ou não) a flag, com base no ciclo de shadow + na matriz de aceite da 29.8. O PO permanece como stakeholder consultado, mas não é gate de aprovação. **⚠️ PENDENTE (2026-10-08):** com o insumo **parcial** (limitações a/b da 30.8), a **decisão de virar `:on` fica SHELVED** — é **decisão do dev**, registrada em **Q16**; o CTO **não** decide pelo dev.
- **Q9 (frente 2 / 30.9b) — mecanismo de atribuição das 2 roles (D-6). ✅ RESOLVIDA (dev, 2026-10-06) — D-6 = (i) migração 1:1 do legado.** O dev decidiu a **migração 1:1 a partir do Intranet legado** (opção (i)); a **(ii) atribuição administrativa foi descartada**. **Correção factual:** o registro anterior ("**dado-fonte inexistente / não implementável nesta árvore**") era **INCORRETO**. É verdade que a gem `SticapiClient::Intranet` (4.0.4) **não expõe** endpoint de roles/perfis — mas o Frequencia tem a **conexão direta `intranet_development`** (`config/database.yml`), usada hoje pelo `Intranet::SyncDigitaisService` (**read-only**), e a **fonte existe** por ela. Medido na conexão: `admin_role` = **13** roles `presenca*` (incl. `presencaVisualizaFrequentadores`/`presencaVisualizaFrequentadoresTerceirizados`), `admin_user` = **9.381** usuários; o legado modela **por PERFIL** (`admin_user.profileId → admin_profile →(admin_profile_role)→ admin_role`, tabelas `admin_user`/`admin_profile`/`admin_profile_role`/`admin_role`, coluna `roleId`). Implementação → **30.9b** (3 pts; **não quebra em 30.10**). Ver §"Ruling D-6".
- **Q10 (frente 2) — D-4 contagem 11×13. ✅ PREJUDICADA sob o ruling A.** Sem expansão, a divergência "11 roles (§2.3) × 13 nomes enumerados" é **moot**. Só volta a importar num **épico de expansão** futuro (o insumo já está no brief §2.1).
- **Q11 (frente 2 / 30.9b) — limiar de aborto de não-resolvidos. ✅ RESOLVIDA (dev, 2026-10-06): ABORTAR ACIMA DE 10%.** Se a proporção de não-resolvidos (login legado sem `User` local correspondente) passar de **10%** na execução real, a rake **aborta** (exit ≠ 0) — sinal de que o eixo de casamento `login → username` está errado e precisa ser revisto antes de aplicar. **✅ IMPLEMENTADO (2026-10-06):** `Resultado#proporcao_nao_resolvidos` + `Resultado#abortar_por_nao_resolvidos?` (constante `LIMIAR_NAO_RESOLVIDOS = 0.10`, comparação estrita `>`; guarda de divisão por zero); a rake passou a usar o predicado (o gatilho deixou de ser "qualquer não-resolvido"). O resumo exibe a proporção e o limiar. Testes: +5 (20%/10% exato/5%/vazio/resumo) → arquivo 17/54/0F/0E; **mutação 2/2 mortas** (`>`→`>=` mata o "10% exato"; remoção do guard mata "legado vazio"). Erros (exceções) seguem abortando sempre; `DRY_RUN` nunca aborta por pendência.
- **Q12 (frente 5 / 30.10) — gestores de unidades inelegíveis/extintas (NOVA, aberta; decisão do dev).** Criar `User` local também para gestores cujo **único** vínculo de gestão aponta para unidade **inelegível** (`active != true`/extinta)? **Recomendação do planejamento: SIM** — a conta é neutra (não concede autorização por si; a elegibilidade é avaliada em tempo de request pelo passo 5, `unidade.elegivel?`), e não criá-la produziria uma cobertura **parcial artificial**. **NÃO decide sozinho** — decisão operacional do dev, como a **Q11**.
- **Q13 (frente 2 / reabertura da 30.4, 2026-10-07) — defaults operacionais da política incremental (NOVA, aberta; decisão do dev).** A política **"role nasce na tarefa que consome a seção do PRD"** está fixada (verbatim do dev em §"Emenda do ruling A"); faltam **defaults operacionais** que o CTO **não** decide sozinho:
  - **(a) Atribuição na mesma tarefa?** A role de cada seção futura é criada **na própria tarefa** que a consome (confirmado). A **atribuição** dela também entra nessa tarefa (aplicando o padrão **D-6/i**), ou continua como **tarefa de migração à parte** (como foi a 30.9b vs. 30.9a)?
  - **(b) D-4 (contagem 11×13) e composição dos perfis.** Quando a expansão voltar (ex.: seção de excepcionais), a divergência **"11 roles (§2.3) × 13 nomes"** e a **composição omissa dos 7 perfis** (`PresencaProfilesEnum`) precisam ser resolvidas — de quem é a decisão (dev/PO × consulta ao legado)?
  - **(c) Aplica-se às seções já existentes admin-only?** A política vale só para seções **novas**, ou também para telas que já têm consumidor mas são **admin-only** hoje (estações, `GestorIndividual`) — isto é, **reabrir a `Ability`** para trocar "admin-only" por role granular **também** é gatilho da política?
  > **Recomendação do CTO 🟡 (o dev decide):** (a) atribuição **na mesma tarefa**, via D-6/i, salvo seção sem dado no legado; (b) **D-4/perfis** só quando a expansão de fato ocorrer — decisão do dev/PO com o insumo do brief §2; (c) **sim**, a política cobre seções existentes admin-only (é lá que a role **tem** consumidor — sem reabrir, vira decorativa).
- **Q16 (frente 4 / encerramento da Sprint 30, 2026-10-08) — virar a flag `:on`? (NOVA, aberta; decisão do dev).** Com a **30.8 re-escopada** e o insumo de DEV **parcial**, resta a decisão que a Q6 atribuiu à **sprint**: **ligar** a cascata (`:on`) ou **manter** `:off`/`:shadow`? **Estado atual: SHELVED (pendente).** **O CTO NÃO decide pelo dev.** Balanço registrado (insumo, não veredito):
  - **A favor de `:on`:** o mecanismo está provado (30 testes verdes nos 6 controllers instrumentados; matriz de aceite 29.8); o fix 🔴/🟡 fecha os furos de cobertura **sob `:on`** (em `:off`/`:shadow` permanece a paridade atual — roster visível a autenticado).
  - **Contra / a resolver antes:** (i) **Passo 1 bloqueado** (30.9b a **87,9%** de não-resolvidos) → passos 2/3 da cascata **sem efeito real** mesmo sob `:on`; (ii) **limitação (b)** — sem abertura por motivo, a **taxa de negação real** sobre a base é **desconhecida** (a observação de DEV não a mede); (iii) **débito estrutural** (enforcement opt-in) → sob `:on`, telas de terceiros ainda podem vazar por fora da cascata (mitigável, não resolvido); (iv) **Bug 🟠2** (`/presenca/*`) é **ortogonal** à flag (pré-sessão) — virar `:on` **não** o resolve.
  - **Recomendação do CTO 🟡 (o dev decide):** enquanto o **Passo 1** estiver bloqueado e a taxa de negação real **desconhecida**, **manter `:off`** (ou, no máximo, `:shadow`) em qualquer ambiente compartilhado; tratar a **virada `:on`** como decisão própria, com plano de reversão, **após** (a) o desbloqueio do Passo 1 e (b) idealmente uma segunda observação com atores representativos (roles atribuídas). Não é gate do CTO.

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
| 2026-10-05 | Sprint Planner detalhou a Sprint 30 a partir das 4 frentes aprovadas pelo dev | 8 tarefas, 23 pontos, 2 gates de ruling/aprovação, 6 perguntas abertas |
| 2026-10-05 | CTO escreveu o plano da 30.1 (`iteration_30_task_30_1_plano_gate_d5.md`) e registrou a aprovação do dev (member action; `:off`=404) | 30.1 ✅ concluída — gate satisfeito, **30.2 desbloqueada**; Q1/Q2 fechadas, Q7/Q8 abertas |
| 2026-10-05 | Code Specialist implementou a 30.2 (rota+constraint, `Ability#grant_desconsideracao_frequencia` com `cannot`+bloco, eventos D5 próprios, controller nos 3 modos, 9 testes) — worktree `wt-30.2`/branch `feature/demanda-30-2-gate-d5-http` | 30.2 ✅ implementada — aguarda Code Reviewer; 7/7 mutações mortas; suíte 1092/3847/1F+12E (pré-existentes); Q7/Q8 resolvidas na implementação |
| 2026-10-05 | Code Reviewer revisou a 30.2 (worktree `wt-30.2`): D5 conforme (só passo 5), fall-through do admin corrigido (probe CanCan confirma ordem load-bearing), 3 estados da flag OK, 5/5 mutações do reviewer mortas, suíte 1092/3847/1F+12E idêntica | 30.2 ✅ **Aprovada** (0 blockers; 🟡Q1/🟠D1 não-bloqueantes) — relatório `docs/quality/review_report_30_2.md`; entregue ao Orchestrator |
| 2026-10-06 | Code Specialist implementou a 30.6 (teste S2: PORO + twin SQL no MESMO cenário GI inativo, com controle ativo) — worktree `wt-30.6`/branch `feature/demanda-30-6-s2-twin-sql` | 30.6 ✅ implementada — aguarda Code Reviewer; 2/2 mutações mortas pelo teste do lado mutado; suíte-alvo 63/183/0F/0E; só teste (sem código de produção) |
| 2026-10-06 | **CTO formalizou o ruling da 30.3 (A)** — dev aprovou: manter simplificado + **semear/atribuir as 2 roles da cascata**; só frequência; adiar perfis. Re-escopo: **30.4/30.5 = N/A**; residual **30.9** (seed+atribuição, 2 pts; +3 se D-6 = migração 1:1); **30.8** passa a depender da 30.9 | 30.3 ✅ **concluída** — desbloqueia a 30.9; **Q3 fechada**, **Q9 aberta** (atribuição/D-6), **Q10 prejudicada**; débito "2 roles não semeadas" registrado |
| 2026-10-06 | Code Reviewer revisou a **30.9a** (worktree `wt-30.9`/branch `feature/demanda-30-9a-seed-roles-cascata`): escopo do ruling A exato (5 roles, sem as 11, sem atribuição), idempotência provada (2ª execução = 0 criações + id das 3 genéricas preservado), nomes string a string contra `autorizacao_frequencia.rb:131,139`/`frequentadores_visiveis.rb:100,109`, inerte em `:off`/`:shadow`, sem schema. Suíte-alvo 10/37/0F/0E; completa 1098/3876/1F+12E (13 pré-existentes) | 30.9a ✅ **Aprovada** (0 blockers) — relatório `docs/quality/review_report_30_9a.md`; **30.9b permanece pendente** (Q9/D-6) |
| 2026-10-06 | Code Specialist implementou a **30.9b** (`Intranet::MigrarRolesCascataService`, branch `feature/demanda-30-9b-migracao-roles-legado`) e corrigiu S1/S2 do review. **Schema legado medido read-only** pelo orquestrador: `admin_user` PK = `login`, coluna `profile_profileId` (o brief dizia `profileId`), cadeia perfil→role por string; volumes **44** + **22** usuários (~66 atribuições, não 9.381). Testes 12/44/0F/0E; direcionada 68/237/0F/0E; completa 1110/3920/1F+12E (+12/+44 = testes novos). Mutação do guard `frequencia_authorization.rb:47` reproduzida e morta | 30.9b ✅ **Aprovada** (0 blockers; `docs/quality/review_report_30_9b.md`) — commit `e79d89d`. **Caminho crítico restante: 30.8 (3 pts)** |
| 2026-10-06 | **CTO registrou o ruling D-6 do dev = (i) migração 1:1 do legado** e **corrigiu o registro factual da Q9**: a fonte **existe** pela conexão `intranet_development` já configurada (read-only, padrão `SyncDigitaisService`) — a gem continua sem endpoint de roles, mas a **conexão direta serve**; medido: 13 roles `presenca*` em `admin_role`, 9.381 usuários em `admin_user`, modelo **por perfil** (`admin_user→admin_profile→admin_profile_role→admin_role`) | **Q9 ✅ RESOLVIDA (D-6 = i)**; **30.9b reescrita como ✅ pronta para implementação** (3 pts, Dev B, depende de 30.9a ✅); riscos/caminho crítico/DoP/total atualizados (19 → **22**); débito das 2 roles → **30.9b**; **Q11 aberta** (limiar de não-resolvidos — decisão do dev) |
| 2026-10-07 | **Sprint Planner abriu a frente 5 (30.10)** por **diretiva do dev** ("verificar gestores ... e implementar a cascata sobre isso"): registrou o **ruling** (gestor = gestor de unidade/órgão; **fonte = Pessoas**; não é role), os **achados** (1330 unidades; **518** gestores distintos; **494** com lotação vigente; **24 sem lotação**) e a **correção factual** (a diretiva partia de role inexistente). Detalhou a tarefa **30.10 — Garantir o `User` local dos gestores de unidade** (3 pts, Dev B), **na Sprint 30**, precedendo a 30.8 | 30.10 registrada; total 22 → **25**; **Q12 aberta** (gestores de unidades inelegíveis); débito "24 gestores sem `User`" registrado; caminho crítico/DoP/riscos atualizados |
| 2026-10-07 | Code Specialist implementou a **30.10** (`GarantirUserLocalService` compartilhado + `ImportarGestoresDeUnidadeService` + rake + 14 testes; branch `feature/demanda-30-10-user-local-gestores-unidade`); extração DRY do job p/ o colaborador (desvio de escopo sinalizado) | 30.10 ✅ implementada — evidência 14/56/0F/0E (service), 24/75/0F/0E (job+service), RuboCop 0; aguarda Code Reviewer |
| 2026-10-07 | Code Reviewer revisou a **30.10**: reproduziu 14/56/0F/0E, 24/75/0F/0E, RuboCop 0; verificou comportamento-preservante do job, read-only no Pessoas, PII contida, idempotência (0 criações/0 escritas na 2ª), dedup/órfã/colisão, `normalizar_cpf` sem duplicata; confirmou stubs com save/restore (nunca `remove_method`). **Desvio de escopo resolvido: extração ACEITA** (paridade provada). 2 🟡 + 2 🟠 não-bloqueantes | 30.10 ✅ **Aprovada** (0 blockers 🔴) — `docs/quality/review_report_30_10.md`; entrega via Source Code Delivery (stage seletivo; sem commit/push — `COMMIT_MODE=manual`) |
| 2026-10-07 | **CTO registrou a reabertura da 30.4** pelo dev e a **emenda ao ruling 30.3 = A**: política de **criação incremental de roles dirigida pelo PRD** — a role nasce **na mesma tarefa** que implementa a seção do `PRD-REGRAS-NEGOCIO-PRESENCA.md` que a consome (verbatim do dev: *"vamos criando as roles de acordo com o que for sendo implementado baseado no PRD de regras de negocio"*). **Não é big-bang** (não cria as 11+7 de uma vez), **não é "nada"**. Histórico do ruling A **preservado** (§"Ruling registrado", 2026-10-06) | 30.4 = **Substituída pela política incremental** (não mais "N/A" puro); brief §4/§5/§8 emendados + **§9 (Desfecho e regra operacional)** adicionado; **Q13 aberta** (defaults operacionais da política); **nenhuma tarefa nova criada**, total segue **25**; **doc-only, sem commit** |
| 2026-10-07 | **Bug Finder** (adversarial) auditou a **cobertura** da cascata a pedido do dev (usuário `davi.queiroz` id 73, sem role, vê a frequência de todos em `/frequencia` sob `:shadow` — comportamento esperado do shadow). Medido por execução: `/frequencia`, `/frequentadores`, `/time_records`, `/frequencia_por_orgao` **filtram** sob `:on` (30 runs / 152 asserts / 0 falhas). **Furo de cobertura (🔴 crítico):** `admin/users_controller#index` (`authorize! :read, :all` + `Pessoas::Vinculo.frequentadores_ativos` **sem** cascata — `users_controller.rb:18-23,34`) lista TODOS os frequentadores + contas sem CPF a **qualquer autenticado**, em **qualquer** valor da flag. **🟠 Alto:** endpoints `/presenca/PontoDePresenca` e `/presenca/DynFrequentadoresEstacao` **sem autenticação** expõem batidas/usuários de terceiros. **🟡/🟢:** ano global em `time_records.rb:29`; sidebar expõe todas as seções a não-admin. **Refutado:** o dashboard **não** vaza a não-admin (corpo inteiro gateado por `current_user.admin?` no controller e na view). | Relatório: `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md` — **não corrige, não commita**; sinalização ao CTO sobre enforcement central da cascata (opt-in por controller). |
| 2026-10-07 | **Code Specialist** implementou o **fix de cobertura** (bugs 🔴1 `users#index` + 🟡3 `time_records`): concern `FrequenciaAuthorization` incluído + `incluir_cpfs_com_cascata`; `@users_sem_cpf` com gate **admin-only**; `@anos_disponiveis` movido para **depois** das restrições. **Bug 🟠2 (`/presenca/*`) PARE+reportado** (gate por ativação inaplicável sem ferir ADR-0003). +8 testes; suíte 1137/4012/3F+12E (0 regressão; 4 mutações mortas) | Fix implementado (`iteration_fix_cascata_cobertura.md`); **Bug 🟠2 pendente de decisão PO/CTO**; **dívida de DRY** (`incluir_cpfs_com_cascata`) e **achado sistêmico** (opt-in) sinalizados ao CTO |
| 2026-10-07 | **CTO registrou a DECISÃO do dev sobre o Bug 🟠2 = ADIAR** (nota em `bug_report_…:69`): os endpoints abertos de `/presenca/*` são necessários aos **testes manuais** da Estação; risco **aceito temporariamente**, **não** resolvido; **gatilho de revisita: após os testes manuais** | Bug 🟠2 = **Risco Aceito** (registrado na 30.8) |
| 2026-10-08 | **Code Reviewer** revisou o fix de cobertura: ✅ **Aprovado** (0 blockers 🔴); reproduziu novos 8/27/0F/0E, direcionada 50/224/0F/0E, cascata 55/273/0F/0E; mutations A/D mortas. Sugestões: S1 DRY, S2 stage seletivo (ruído não-commitado no working tree — inclui o `development.rb` do shadow), S3 renomear `iteration_31_fix_…`→`iteration_fix_…`, S4 confirmar gate admin-only de contas locais | `docs/quality/review_report_fix_cascata_cobertura.md`; fix **publicado** (`f89d312`, merge `bcf0807`) |
| 2026-10-08 | **CTO re-escopou a 30.8** ("7 dias em PRODUÇÃO" → **observação em DEV**, já realizada: **1366 eventos**, todos `:negado`; insumo válido com **4 limitações** declaradas), **declarou a Sprint 30 encerrável**, registrou o **Bug 🟠2 como Risco Aceito** (gatilho: após testes manuais), o **débito ESTRUTURAL** (enforcement opt-in — causa-raiz do Bug 🔴1 — + DRY `incluir_cpfs_com_cascata`) e encaminhou a **emenda à ADR-0010**; abriu **Q16** (decisão de virar `:on` — **SHELVED**, decisão do dev). **Doc-only, sem commit** | §"Re-escopo da 30.8 e encerramento da Sprint 30"; ADR-0010 (nota nova); header 🟢 **ENCERRÁVEL**; total/debris/DoP/Q16/Linha do Tempo atualizados |

