# Iteration 26 — Port de Estilo basic8 (prelúdio dos scaffolds)

> Status: 📋 Planejada | Período: 2026-09-28 a 2026-10-09 | Goal: Portar TODO o delta de estilo do basic8 (helpers de contexto, partials `shared/*`, layout admin, assets/build e bibliotecas JS/UX) como pré-requisito visual dos scaffolds estilo basic8 (Sprint 25) | RFs: RF04, RF05, RF06, RF12, RF13, RF14, RNF01, RNF03, RNF05, RNF06

## Decisão de numeração (ler antes)

- Esta sprint é um **prelúdio/acompanhante da Sprint 25 (scaffolds)** do `docs/12-plano-implementacao/implementation_plan.md`. Como a Sprint 25 do plano **já está ocupada** com "Templates de scaffold + convenções de modelo", a sprint de estilo é numerada **26** (`iteration_26.md`).
- **Ordem de execução ≠ numeração:** a Fase 1 (partials `shared/*` + helpers) é **pré-requisito** dos templates de scaffold (RF04/RF05 — os templates renderizam `shared/*`). O Project Planner deve revisar o Gantt do plano (Sprints 25–28) para registrar a precedência/renumeração do piloto (**Sprint 26 atual do plano** → empurra para 27+). Sem ação de escrita no `implementation_plan.md` por parte desta sprint; reportado ao Orchestrator.
- **Dois trilhos de planejamento coexistem:** `implementation_plan.md` (canônico, Sprints 24–28) e `Frequencia/SPRINT-PLAN.md` (Sprint 24 = CSS/Estilo ✅9/9, 25 = partials layout, 26 = CRUD). Não realinhar agora; o delta entre trilhos é insumo do code review e do CTO.

## Pré-condição

- **Sprint 24 aceita** (✅ 2026-09-23) — gems basic8 (zutils, simple_form, ransack, pagy) no bundle.
- **Working tree estabilizado antes do início:** commits manuais pendentes da Sprint 24 (COMMIT_MODE=manual: branches 24.2–24.6, Bug 10) e merge/layout da 23.7 **finalizados** (ou HEAD consolidado) para as branches encadeadas da Sprint 26 partirem do estado limpo (padrão das Sprints 23/24/25).
- **Estado real verificado na investigação (2026-09-23):** `manifest.js` **sem** `link_tree ../builds` (build não entra em produção); `admin.html.erb` ainda com CDN AdminLTE 4 + OverlayScrollbars CSS + fontsource, título hardcoded "API Ponto TJPI", sidebar inline com links mortos (`href="#"`) e JS inline duplicado; `ApplicationRecord` sem `self.icon`; `breadcrumbs_on_rails` **não** está no Gemfile; `bootstrap-icons` **não** está no package.json; `application.scss` sem imports das libs do basic8 (toastr/tom-select/bootstrap-table/fileinput/ckeditor). As tarefas **começam confirmando o estado real do repo** ("investigue antes de alterar").

## Desenvolvedores

| Dev | Perfil | Foco |
|-----|--------|------|
| Code Specialist (Dev A) | Backend + UI (helpers, partials, layout, importmap/Stimulus) | Fase 1 (26.1–26.5) + 26.6 (breadcrumbs) + Fase 3 (26.10) |
| Code Specialist Assets/Build (Dev B) — **opcional** | Node/Sass/Propshaft/importmap | Fase 2 (26.7, 26.8, 26.9) em worktree paralela (arquivos disjuntos; ver skill `parallel-execution`) |

> Padrão: **1 dev (Dev A)**. Com 2 devs, Dev B assume 26.7/26.8/26.9 a partir do HEAD consolidado; **26.6 permanece com Dev A** (toca `ApplicationController`, mesma região da 26.1).

## Backlog

### FASE 1 — UI estrutural (port de partials/helpers/layout)

#### Tarefa 26.1 — Helpers de contexto do layout: `resource_human_name`, `resource_icon`, `set_configurations` + fallback `ApplicationRecord.icon`

- User Story: Como dev, quero os helpers do basic8 que nomeiam/iconeiam recursos e definem o contexto do app para que os partials `shared/*` (título, header, sidebar) e os scaffolds (Sprint 25) herdem a convenção sem duplicação por tela
- Rastreabilidade: PRD RF06/D1 (convenção `Model.icon`), RNF05, RN03 (pt-BR); fontes: `basic8/app/helpers/application_helper.rb`, `basic8/app/models/application_record.rb`, `basic8/app/controllers/application_controller.rb`
- Estimativa: 2 pontos | Atribuição: Dev A
- Dependências: Sprint 24 concluída (zutils no bundle)
- Critérios de aceite:
  - [ ] `ApplicationHelper` ganha `resource_icon(controller_name)` — `constantize` → `klass.icon` se responder, senão fallback (padrão basic8 `"fa fa-circle"` com `rescue NameError`)
  - [ ] `resource_human_name(controller_name, action_name)` — `klass.model_name.human.pluralize` com fallback `controller_name.capitalize` (respeita I18n pt-BR)
  - [ ] `ApplicationRecord.icon` (e `icon_for(field)` se portado) com default `"fa fa-fw fa-cube"` (fiel ao basic8) — herdável pelos models pilotos (`EstacaoPonto`/`Regime`/`Versao`)
  - [ ] `set_configurations` (before_action no `Admin::ApplicationController`) define `@app_name` (identidade atual "API Ponto TJPI" preservada), `@app_description`, `@app_icon = ApplicationRecord.icon`, `@menu = []` e `@static_menu` refletindo a navegação atual do layout admin SEM rotas mortas (itens com `permission`/`permission_check`/`active_test`/`children` no padrão basic8)
  - [ ] Contexto API/presença (`ApplicationController` base e `Presenca::*`) intocado (RNF01/RNF06)
  - [ ] Testes: helper (fallback por NameError + override por model com `self.icon`) e controller (`@static_menu` exposto após ação admin real)
  - [ ] `rails zeitwerk:check` OK; suíte baseline sem novas falhas (731/2431/1); rubocop limpo
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

#### Tarefa 26.2 — Partial `shared/_sidebar` (menu dinâmico data-driven)

- User Story: Como admin, quero uma sidebar que reflita meu nível de permissão e destaque a tela ativa para navegar aos módulos sem links mortos
- Rastreabilidade: PRD RF05 (navegação admin), RNF05; fontes: `basic8/app/views/shared/_sidebar.html.erb` (94 linhas, suporta 3 níveis), `basic8/app/controllers/application_controller.rb` (`@static_menu`)
- Estimativa: 3 pontos | Atribuição: Dev A
- Dependências: 26.1 (`@static_menu` via `set_configurations`); usa `menu_activated?`/`eval_with_rescue` já portados (zutils)
- Critérios de aceite:
  - [ ] `app/views/shared/_sidebar.html.erb` portado do basic8 (estrutura/classes AdminLTE 4: `app-sidebar`, `sidebar-brand`, `sidebar-wrapper`, `data-lte-toggle="treeview"`, 3 níveis de profundidade), iterando `@static_menu`
  - [ ] Filtro por permissão em TODOS os níveis com `can? mi.dig(:permission), mi.dig(:permission_check)` (pai, filho, neto) — gestor/operador não veem itens fora da matriz de permissões (23.5)
  - [ ] `menu_activated?` aplicado para `active`/`menu-open` (comportamento fiel, incluindo o truthy `"error"` já documentado no helper)
  - [ ] **Nenhum item de menu com `url: "#"` SEM `children`** (remoção de links mortos); itens-pai apenas-seção mantêm o `<a href="#">` do padrão AdminLTE treeview (são headers de seção, não rotas mortas)
  - [ ] Ícones dos itens na convenção `fa-*` (Font Awesome — consistência Frequencia; as views já migraram `bi-*`→`fa-*`); `data-enable-persistence` e demais atributos AdminLTE preservados
  - [ ] Verificação estrutural/funcional: HTML renderizado em ação admin real (ex.: `estacoes_path`) com menu filtrado por role (admin vê tudo; operador só leitura)
  - [ ] Suíte baseline sem novas falhas; rubocop limpo
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

#### Tarefa 26.3 — Partial `shared/_header` (navbar com marca central + dropdown de usuário com badges de roles)

- User Story: Como usuário logado, quero ver a marca do app no topo e meu nome/roles no dropdown para saber quem sou e qual meu nível de acesso
- Rastreabilidade: RNF05; fontes: `basic8/app/views/shared/_header.html.erb` (adaptado ao Frequencia: `logout_path`, `current_user.nome_completo`, theme toggle já existente); **decisão de convenção badges `text-bg-*`** (registrada aqui — reutilizada na 26.4)
- Estimativa: 2 pontos | Atribuição: Dev A
- Dependências: 26.1 (`@app_icon`/`@app_name`)
- Critérios de aceite:
  - [ ] `_header.html.erb` portado: toggle sidebar (`data-lte-toggle="sidebar"` + `data-controller="sidebar"` — preserva `sidebar_controller.js` do Frequencia), **marca central** (`@app_icon` + `@app_name` via `link_to root_path`), dropdown de tema (`theme_controller` — movido sem duplicar markup)
  - [ ] Dropdown do usuário: nome (`current_user.try(:nome_completo)` — model `User` do Frequencia; fallback), email quando houver, **badges de roles** iterando `(current_user.try(:roles) || [])` → `role.name` com **convenção `text-bg-*`** (ex.: `text-bg-primary`; mesma convenção no `_title`)
  - [ ] Logout via `button_to logout_path, method: :delete` (rota real do Frequencia — RN06; adaptação do `destroy_user_session_path` do basic8)
  - [ ] Sem duplicação de markup com o layout (extração limpa; o layout passa a renderizar o partial na 26.5)
  - [ ] Teste estrutural no HTML admin real (presença dos elementos-chave: marca, dropdown, badges; usuário sem roles → dropdown sem quebrar)
  - [ ] Suíte baseline sem novas falhas
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

#### Tarefa 26.4 — Partial `shared/_title` (breadcrumbs + badges de roles + box ícone 50×50 + auto-"Novo")

- User Story: Como usuário, quero um título de página consistente com breadcrumbs, ícone do recurso e atalho "Novo" automático para saber onde estou e agir rápido
- Rastreabilidade: PRD RF04 (os templates da Sprint 25 renderizam `shared/*` — o título entra na estrutura gerada), RNF05; fontes: `basic8/app/views/shared/_title.html.erb`; depende da gem `breadcrumbs_on_rails` (26.6)
- Estimativa: 3 pontos | Atribuição: Dev A
- Dependências: 26.1 (helpers), 26.3 (convenção badges), **26.6 (gem breadcrumbs + `add_breadcrumb`) — executar 26.6 antes desta na linha do tempo**
- Critérios de aceite:
  - [ ] `_title.html.erb` portado com `return if ['sessions', 'dashboard'].include?(controller_name)`
  - [ ] Breadcrumbs via `breadcrumbs.any?` (gem) com fallback `@app_name` → `resource_human_name(...)` quando vazio
  - [ ] Box ícone 50×50 (`style="width: 50px; height: 50px;"` + `resource_icon(controller_name)`) e `h1` com `resource_human_name(controller_name, action_name)` + `t("helpers.titles.#{action_name}")` quando não-index
  - [ ] Badges de roles com a MESMA convenção `text-bg-*` da 26.3 (sem duplicação de decisão)
  - [ ] Auto-"Novo": `eval_with_rescue("new_#{controller_name.singularize}_path")` → botão "Novo [recurso]" apenas quando a rota existe (`new_path.present? && new_path != "error"`)
  - [ ] Ações: `content_for(:page_actions)` respeitado; `show` renderiza `shared/btn_action_links` da zutils (`labels: false, size: 'sm', hide: ['show']`)
  - [ ] Testes: renderização em ação admin real (index com botão Novo quando rota existe; show com btn_action_links; sessions/dashboard não renderizam o título)
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

#### Tarefa 26.5 — Refatorar layout `admin.html.erb` para renderizar `shared/*` (título dinâmico + favicon + remoção do JS inline duplicado)

- User Story: Como dev, quero um layout admin enxuto composto pelos partials `shared/*` para que o visual seja único e a manutenção centralizada
- Rastreabilidade: PRD RF14 (flash local preservada), RNF05; fontes: `basic8/app/views/shared/_footer.html.erb` (port simples — incluído nesta tarefa), partials portados 26.2/26.3/26.4
- Estimativa: 2 pontos | Atribuição: Dev A
- Dependências: 26.2, 26.3, 26.4 (partials prontos para composição)
- Critérios de aceite:
  - [ ] `admin.html.erb` renderiza `shared/_header`, `shared/_sidebar`, `shared/_title` (quando aplicável) e `shared/_footer` — removendo os blocos inline equivalentes (header/sidebar/footer atuais)
  - [ ] **JS inline duplicado da sidebar removido** — persistência continua via `sidebar_controller.js` (Stimulus) + AdminLTE nativo; verificar que o colapso persiste após reload
  - [ ] Flash local **preservado (RF14)**: `flash[:notice]`→`alert-success` e `flash[:alert]`→`alert-danger` no layout (sem `shared/flash*`/`bootstrap_flash`)
  - [ ] Título dinâmico: `<title>` usa `@app_name` + sufixo da página (`content_for?(:page_title)` ou `resource_human_name`) — sem título hardcoded "API Ponto TJPI"
  - [ ] Favicon presente (`link rel="icon"` apontando para asset existente; padrão basic8)
  - [ ] Meta `theme-color` ajustada para a paleta `$primary: #2563eb` (sincronizada com a 26.8)
  - [ ] Suíte baseline sem novas falhas; verificação HTML real (dashboard/estacoes) com flash, título, menu e badges
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

### FASE 2 — Assets/build (causa raiz do estilo não reproduzido)

#### Tarefa 26.6 — Gem `breadcrumbs_on_rails` + `add_breadcrumb` no ApplicationController

- User Story: Como dev, quero a gem de breadcrumbs do basic8 para que o `_title` renderize o trilho de navegação na tela admin
- Rastreabilidade: RNF05; fontes: `basic8/Gemfile` (`gem "breadcrumbs_on_rails"`), `basic8/app/controllers/application_controller.rb` (`add_breadcrumb "Início", :root_path`)
- Estimativa: 2 pontos | Atribuição: Dev A
- Dependências: — (independente; sequenciar após 26.1 para evitar conflito de edição no `ApplicationController`)
- Critérios de aceite:
  - [ ] `gem "breadcrumbs_on_rails"` no Gemfile + `bundle install` limpo (compatibilidade Rails 8/Ruby 3.4.2 verificada — boot OK)
  - [ ] `add_breadcrumb "Início", :root_path` em `ApplicationController` (padrão basic8) — contexto API/presença não afetado (nenhuma view não-admin renderiza breadcrumbs)
  - [ ] Helper `breadcrumbs` disponível nas views admin (`_title` usa `breadcrumbs.any?` e `crumb.path`/`crumb.name`)
  - [ ] `rails zeitwerk:check` OK; suíte baseline sem novas falhas; rubocop limpo
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

#### Tarefa 26.7 — npm `bootstrap-icons` + import no `application.scss`

- User Story: Como dev, quero as classes `bi-*` disponíveis no build CSS para que partials/setores do basic8 que referenciam Bootstrap Icons (ex.: `bi bi-chevron-right` do sidebar fonte, partials zutils das telas da Sprint 25) renderizem ícones
- Rastreabilidade: PRD RF13 (sem zutils.scss — decisão), RNF05; fontes: `basic8/app/assets/stylesheets/application.scss` (`@import "bootstrap-icons/font/bootstrap-icons"`), `basic8/package.json`
- Estimativa: 2 pontos | Atribuição: Dev B (paralela)
- Dependências: — (não interfere com a Fase 1; pode rodar em worktree paralela)
- Critérios de aceite:
  - [ ] `yarn add bootstrap-icons` (dependency, não devDependency) — versão compatível com o build Sass
  - [ ] `@import "bootstrap-icons/font/bootstrap-icons";` no `application.scss` (posição equivalente ao basic8)
  - [ ] WebFonts servidos pelo Propshaft (registrar `node_modules/bootstrap-icons/font/fonts` em `config.assets.paths` se necessário — padrão da task 24.1 do fontawesome; ou copiar para builds)
  - [ ] `yarn build:css` compila sem erro; `grep ".bi-chevron-right"` presente em `app/assets/builds/application.css`
  - [ ] Convenção documentada: a Fase 1 usa `fa-*` nas partials portadas (consistência Frequencia); o bootstrap-icons cobre resíduos `bi-*` (ex.: nav-arrow do fonte) e partials zutils (Sprint 25) — NÃO reintroduz `bi-*` nas views já migradas para FA
  - [ ] Suíte baseline sem novas falhas
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

#### Tarefa 26.8 — `link_tree ../builds` no manifest.js + build CSS local servido (paleta `$primary: #2563eb`)

- User Story: Como dev, quero que o CSS compilado localmente (paleta custom) seja servido em produção para que o visual do Frequencia seja o do basic8 (e não o default do CDN AdminLTE)
- Rastreabilidade: PRD RNF05, RF13/D6; fontes: `Frequencia/api-ponto/app/assets/config/manifest.js` (hoje SEM `link_tree ../builds`), `package.json` (`build:css` já existente), `_variables.scss` (`$primary: #2563eb` — já portado no repo)
- Estimativa: 3 pontos | Atribuição: Dev B (paralela)
- Dependências: 26.7 (build final com bootstrap-icons antes da validação); 26.5 (fraca — remoção do CDN admin-lte coordenada)
- Critérios de aceite:
  - [ ] `manifest.js` com `//= link_tree ../builds` (o build `app/assets/builds/application.css` passa a entrar no precompile)
  - [ ] `RAILS_ENV=production bin/rails assets:precompile` inclui `application.css` do build (verificável no output/`public/assets` do Propshaft)
  - [ ] `yarn build:css` limpo; `$primary: #2563eb` presente no CSS servido (grep `2563eb` no build)
  - [ ] Ordem CDN→build validada: o layout `admin` não referencia mais o CDN do `admin-lte` (o build local o provê e prevalece); `fontsource`/`overlayscrollbars` CDN avaliados (manter só o necessário; registrar débito se aplicável)
  - [ ] Verificação visual funcional: página admin real com `computed style` primário `#2563eb` (browser dev — sem Capybara)
  - [ ] Suíte baseline sem novas falhas
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

#### Tarefa 26.9 — Portar CSS de bibliotecas do basic8 conforme uso real do Frequencia (decisão de escopo)

- User Story: Como dev, quero uma decisão documentada sobre quais CSS de bibliotecas do basic8 entram no build do Frequencia para não carregar CSS morto
- Rastreabilidade: PRD RF13 (não importar zutils.scss), RF12 (bootstrap-table inert), RNF03/RNF05; fontes: `basic8/app/assets/stylesheets/application.scss` (toastr, tom-select, bootstrap-table, fileinput, ckeditor5, overlayscrollbars)
- Estimativa: 2 pontos | Atribuição: Dev B
- Dependências: 26.8 (build local servido — contexto de validação)
- Critérios de aceite:
  - [ ] Levantamento das libs do basic8 × uso real do Frequencia (package.json atual: apenas bootstrap/admin-lte/fontawesome; views usam `<select>` nativo — sem tom-select; nenhum toastr/fileinput/ckeditor no Gemfile/views; bootstrap-table inert no PRD RF12)
  - [ ] Decisão por biblioteca registrada neste iteration (ou nota no `application.scss`): importar ou não, com justificativa — **default esperado: NENHUM import novo** de toastr/tom-select/bootstrap-table/fileinput/ckeditor5 (fora do escopo real); bootstrap-icons e overlayscrollbars já cobertos nas 26.7/26.10
  - [ ] `zutils.scss` NÃO importado (RF13) — confirmado por ausência no `application.scss`
  - [ ] Se algum import for adicionado: `yarn build:css` limpo + suíte sem novas falhas; se nenhum: build regenerado sem mudanças e suíte intacta
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

### FASE 3 — Bibliotecas JS/UX do layout (condicional)

#### Tarefa 26.10 — Tooltips `data-bs-toggle="tooltip"` + OverlayScrollbars JS (decisão: portar ou registrar débito)

- User Story: Como usuário, quero tooltips nos botões de ação e scrollbars customizadas consistentes para uma UX equivalente ao basic8 nas telas geradas
- Rastreabilidade: RNF05; fontes: `basic8/app/javascript/src/functions.js` (init `[data-bs-toggle="tooltip"]` + dispose turbo), `basic8/app/javascript/controllers/application_controller.js` (Stimulus `connect(){ tooltips() }`), `basic8/app/javascript/application.js` (import OverlayScrollbars)
- Estimativa: 2 pontos | Atribuição: Dev A
- Dependências: 26.3/26.4 (tooltips presentes nas partials — via zutils `btn_action_links` no `_title`), 26.8 (build local)
- Critérios de aceite:
  - [ ] Port de `tooltips()` (bootstrap.Tooltip em `[data-bs-toggle="tooltip"]` + dispose em `turbo:before-cache`/`turbo:before-visit`) integrado ao entry JS do Frequencia (via `app/javascript/controllers/application_controller.js` Stimulus com `data-controller="application"` no layout, ou equivalente compatível com importmap — sem esbuild)
  - [ ] Tooltips inicializam nas telas admin reais (verificação browser — sem Capybara); sem duplicação com o `bootstrap` já pinado no importmap
  - [ ] OverlayScrollbars JS: `yarn add overlayscrollbars` + init (fonte basic8 `application.js`); **se as telas pilotos (Sprint 25) não dependerem** → registrar débito técnico 🟢 (CSS já vem do CDN/build) e não bloquear a sprint
  - [ ] Decisão registrada no relatório da tarefa (portado vs débito + motivo)
  - [ ] Suíte baseline sem novas falhas
- Status: ⬜ Pendente

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
|         |                 |           |

## Tabela de estimativas e dependências

| Tarefa | Título | Pontos | Fase | Dev | Depende de |
|--------|--------|--------|------|-----|------------|
| 26.1 | Helpers de contexto + fallback `ApplicationRecord.icon` | 2 | 1 | A | Sprint 24 concluída |
| 26.2 | Partial `shared/_sidebar` (menu data-driven) | 3 | 1 | A | 26.1 |
| 26.3 | Partial `shared/_header` (marca central + badges) | 2 | 1 | A | 26.1 |
| 26.4 | Partial `shared/_title` (breadcrumbs + auto-Novo) | 3 | 1 | A | 26.1, 26.3, 26.6 |
| 26.5 | Refactor `admin.html.erb` (composição `shared/*`) | 2 | 1 | A | 26.2, 26.3, 26.4 |
| 26.6 | Gem `breadcrumbs_on_rails` + `add_breadcrumb` | 2 | 2 | A | após 26.1 (conflito AppController) |
| 26.7 | npm `bootstrap-icons` + import SCSS | 2 | 2 | B | — (paralela) |
| 26.8 | `link_tree ../builds` + build local + paleta `#2563eb` | 3 | 2 | B | 26.7; 26.5 (fraca) |
| 26.9 | Decisão de escopo CSS de bibliotecas | 2 | 2 | B | 26.8 |
| 26.10 | Tooltips + OverlayScrollbars JS (ou débito) | 2 | 3 | A | 26.3, 26.4, 26.8 |

**Total: 10 tarefas | 23 pontos | 1 dev (2 com Dev B) | 2 semanas (1 semana com 2 devs)**

## Caminho crítico

```
26.1 → 26.3 → 26.6 → 26.4 → 26.5 → 26.8 → 26.9 → 26.10
```

- **26.2** pode iniciar logo após a 26.1 (paralela com 26.3 na mesma branch ou worktree).
- **26.7** é independente e pode rodar em worktree paralela desde o HEAD consolidado.
- **26.8** depende fracamente da 26.5 (remoção do CDN admin-lte coordenada — não bloqueia início).
- Com Dev B: Fase 2 (26.7/26.8/26.9) em worktree própria; Dev A segue 26.1→26.3→26.6→26.4→26.5→26.10.

## Riscos

- 🟡 **Dois trilhos de planejamento**: parte da Fase 2 (build local, `$primary: #2563eb`, helpers já portados, theme/sidebar controllers) consta como concluída no `Frequencia/SPRINT-PLAN.md` → as tarefas iniciam verificando o estado real (sem duplicar trabalho concluído; diferença entre trilhos é insumo do Code Reviewer/CTO).
- 🟡 **Conflito de edição**: 26.1 × 26.6 tocam `ApplicationController` (e 26.5 × 26.8 o layout admin) → mesmo dev ou sequenciar; com 2 devs, arquivos disjuntos (ver skill `parallel-execution`).
- 🟡 **`breadcrumbs_on_rails` é gem antiga**: compatibilidade Rails 8/Ruby 3.4 — se incompatível, fallback = breadcrumbs manuais no `_title`; reportar sem reabrir decisões ADR/D1-D6.
- 🟡 **`bootstrap-icons` reintroduz dependência removida na 24.1 do plano do app**: escopo limitado a CSS/classes `bi-*` residuais e partials zutils (Sprint 25); não toca views já migradas para FA.
- 🟡 **`link_tree ../builds` ausente hoje** → build fora de produção: corrigir e validar precompile; risco de ordem CDN×build (paleta `#2563eb` vs default `#007bff`) — remover CDN admin-lte.
- 🟢 **Baseline 1 falha pré-existente** de timezone (`presenca_endpoints_test.rb:187`) — aceite = sem NOVAS falhas (731/2431/1).
- 🟢 **Sem Capybara/Selenium** — verificação visual via browser manual + testes estruturais (padrão do projeto).
- 🟢 **Convenção badges `text-bg-*`** decidida na 26.3 e reutilizada na 26.4 (registrada para não divergir).
- 🟡 **Numeração/ordem**: esta sprint (26/estilo) é PRELÚDIO da Sprint 25 (scaffolds) do implementation_plan; o Gantt do plano (Sprints 25–28) aguarda revisão do Project Planner (renumerar piloto para 27+ ou registrar precedência) — reportado ao Orchestrator.

## Definição de Pronto

- [ ] Partials `shared/_header`, `shared/_title`, `shared/_sidebar`, `shared/_footer` portados e renderizados pelo layout admin; JS inline duplicado da sidebar removido; título dinâmico + favicon
- [ ] Helpers `resource_human_name`/`resource_icon`/`set_configurations` + `ApplicationRecord.icon` (fallback) testados
- [ ] Convenção badges `text-bg-*` documentada e aplicada (header + title)
- [ ] `breadcrumbs_on_rails` no Gemfile + `add_breadcrumb`; `bootstrap-icons` no build; `link_tree ../builds` no manifest; paleta `$primary: #2563eb` servida (CDN admin-lte removido)
- [ ] Decisão de escopo da 26.9 registrada (default: nenhum CSS morto importado; `zutils.scss` NÃO importado — RF13)
- [ ] Fase 3: tooltips funcionais; OverlayScrollbars portado ou débito registrado
- [ ] Suíte **731 runs / 2431 asserts / 1 falha** (timezone pré-existente) sem NOVAS falhas; `rails zeitwerk:check` OK; rubocop limpo
- [ ] Zero migrations e auth/ability intactos (RNF06/RN06)
- [ ] Rastreabilidade PRD (RF04/RF05/RF06/RF12/RF13/RF14, RNF01/RNF03/RNF05/RNF06, D1/D6) + fontes basic8 por tarefa

## Sincronização CAPTEI (opcional — sob demanda)

> ⚠️ **Não executada nesta sessão:** a skill `captei-sync-protocol` existe em `ai-workflow/src/skills/captei-sync-protocol/SKILL.md` mas **não está registrada** no registry de skills da sessão e **não há MCP tools do CAPTEI** disponíveis. Se o Orchestrator/usuário dispuser do ambiente CAPTEI, executar o espelhamento das apt-tasks abaixo (padrão da iteration_24).

| Apt-tasks | Atribuição | Tipo | Complexidade |
|-----------|------------|------|--------------|
| 26.1 | Dev A | Backend | Média |
| 26.2 | Dev A | Frontend | Alta |
| 26.3 | Dev A | Frontend | Média |
| 26.4 | Dev A | Frontend | Alta |
| 26.5 | Dev A | Frontend | Média |
| 26.6 | Dev A | Backend | Média |
| 26.7 | Dev B | Frontend | Baixa |
| 26.8 | Dev B | Frontend/Assets | Média |
| 26.9 | Dev B | Análise | Baixa |
| 26.10 | Dev A | Frontend | Média |