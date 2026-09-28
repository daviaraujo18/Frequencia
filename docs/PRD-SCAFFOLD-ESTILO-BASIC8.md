# PRD — Scaffolds/CRUD no estilo basic8 (partials shared + simple_form + ransack + pagy + cancancan)

> **Feature:** Padronizar a geração de scaffolds/CRUDs administrativos do Frequencia no estilo do app de referência `basic8`.
> **Fonte:** Sessão de descoberta (Brainstorm + feature-discovery) — 2026-09-21.
> **App:** `Frequencia/api-ponto` (Rails 8.0.4, API-only base, AdminLTE 4 + Bootstrap 5.3 via CDN, importmap, kaminari→pagy).
> **Status:** 📋 PRD aprovado — aguardando planejamento (Project Planner / Sprint Planner).

---

## 1. Visão Geral

### Contexto
O Frequencia tem CRUDs administrativos **manuais e heterogêneos**: cada tela (`estacoes`, `regimes`, `versoes`, `users`, `frequentadores`) foi escrita com `form_with`/`form_tag` custom, filtros próprios e estilos ligeiramente diferentes. O app de referência `basic8` consolidou um **padrão de scaffold** que gera CRUDs homogêneos a partir de:

- **Partial `shared/*`** (engine `zutils`): `search_form`, `index`, `list`, `form`, `fields`, `show`, `pagination`, `btn_action_links`, `action_links`.
- **`simple_form`** para formulários (wrapper Bootstrap 5).
- **`ransack`** para busca (`search_form_for`, `sort_link`).
- **Controller** com `load_and_authorize_resource` (CanCanCan) + `ransack(params[:q])` + paginação + notices pt-BR.

### Objetivos de Negócio
1. **Padronizar** a geração de CRUDs administrativos a partir de um template único (o do basic8), reduzindo decisão por tela e código manual divergente.
2. **Provar o template** com a migração de 3 CRUDs manuais existentes (piloto) antes da adoção ampla.
3. **Unificar a paginação** em **pagy** (padrão real do basic8), removendo o kaminari (dual-gem causa bug nos partials da zutils).
4. Preservar as telas bespoke (users/frequentadores — agregação cross-database) como **exceção documentada**.

### Usuários afetados
- **Devs (primário):** fluxo de `rails g scaffold` + manutenção de CRUDs.
- **Admins/gestores/operadores (secundário):** telas pilotos (estacoes/regimes/versoes) ganham busca ransack e navegação padronizada; users/frequentadores só trocam a paginação (comportamento idêntico).

---

## 2. Requisitos Funcionais (RF)

| ID | Requisito | Decisão fonte |
|---|---|---|
| RF01 | Adotar a **gem `zutils` (~> 4.0)** como engine de partials `shared/*` e helpers (`display`, `bootstrap_flash` opcional) | D1 |
| RF02 | Adicionar **`simple_form` (~> 5.4)** e **`ransack` (~> 4.4)** ao Gemfile; instalar/gerar `config/initializers/simple_form.rb` com wrapper Bootstrap 5 + locale pt-BR | D2 |
| RF03 | Adicionar **`pagy` (~> 9)**; expor `Pagy::Backend` no `Admin::ApplicationController` e `Pagy::Frontend` no `ApplicationHelper` | D3, D6 |
| RF04 | Portar para `lib/templates/` os templates do basic8 **adaptados ao Frequencia**: controller herda `Admin::ApplicationController`, usa `load_and_authorize_resource` + `ransack(params[:q])` + `@pagy, @collection = pagy(...)` + notices pt-BR; `index` renderiza `shared/search_form` + `shared/index`; `new`/`edit` renderizam `shared/form`; `show` renderiza `shared/show`; partial usa helper `display` | D3, D4 |
| RF05 | `rails g scaffold Modelo` (flat) gera: controller em `Admin::` (views em `app/views/admin/`), **model flat** e rotas flat adicionadas manualmente dentro do bloco `scope module: "admin"` (com GETs explícitas de `new`/`edit`, já que `api_only=true` suprime as rotas de formulário) | D4 |
| RF06 | Adicionar **`self.icon`** (class method) nos models usados por partials `shared/*` (pilotos + scaffolds novos) — convenção exigida pela zutils | D1, D6 |
| RF07 | Definir **whitelist `ransackable_attributes`/`ransackable_associations`** nos models pilotos e scaffolds novos (consistência com basic8; default do ransack permite todas as colunas) | D2, D6 |
| RF08 | **Piloto (P2):** migrar `regimes` e `versoes` para o novo estilo **via generator** (casam com o template); `estacoes` migrado **manualmente no mesmo estilo** (controller `EstacoesController` opera model `EstacaoPonto` — naming não casado com scaffold) | D5, D6 |
| RF09 | **users/frequentadores:** trocar **somente a paginação** para pagy: `@pagy, @vinculos = pagy(...)` nos 2 controllers e `pagy_info`/`pagy_nav` nas 2 views (substituindo `paginate`, `total_count`, `offset_value`); demais recursos bespoke **preservados** | D5 |
| RF10 | **Remover kaminari** do Gemfile e apagar `app/views/kaminari/` ao final do piloto (single-gem pagy; evita branch kaminari do zutils `defined?(Kaminari)`) | D3, D5 |
| RF11 | Criar **controller Stimulus local `filtering`** (~30 linhas, padrão `sidebar_controller`) para o `data-controller="filtering"` do `shared/search_form`; **não** instalar `@zezim/zutils` (npm) | D6 |
| RF12 | Chamadas a `shared/index` no piloto passam `controller: ""` (ou equivalente) para **inert** do `bootstrap-table` (não instalar jquery/bootstrap-table) | D6 |
| RF13 | **Não importar `zutils.scss`** (só serve tom-select/fileinput — fora de escopo); o `build:css:compile` (sass/Node) permanece inalterado | D6 |
| RF14 | **Flash local mantida:** layout `admin` continua renderizando `flash[:notice]`/`flash[:alert]`; notices pt-BR do template funcionam direto; partials `shared/flash*`/`bootstrap_flash` **não** são adotados | D6 |

---

## 3. Regras de Negório / Regras do Projeto (RN)

| ID | Regra |
|---|---|
| RN01 | **Todo CRUD novo** do Frequencia deve ser gerado pelo scaffold padronizado (`rails g scaffold` + `lib/templates/`) — salvo exceção documentada. |
| RN02 | **Telas bespoke `users`/`frequentadores` são exceção documentada**: não devem ser "forçadas" aos partials genéricos (semântica cross-database por CPF não é expressável em ransack). |
| RN03 | Nomes e mensagens do template permanecem em **pt-BR estrito** (padrão do projeto). |
| RN04 | Todo model usado por `shared/*` deve definir `self.icon` e `ransackable_*` (convenção nova do Frequencia). |
| RN05 | Full CRUD (create/update/destroy) continua restrito a **admin** via `load_and_authorize_resource` + Ability existente (gestor = read-all + manage `TimeRecord`/`IntervencaoFrequencia`; operador = read); não alterar a matriz de permissões do Sprint 23. |
| RN06 | Não pode haver regressão na autenticação Pessoas2/Devise nem nas permissões CanCanCan (Sprint 23 em andamento — 23.7 a 23.10 pendentes). |

---

## 4. Requisitos Não-Funcionais (RNF)

| ID | Requisito |
|---|---|
| RNF01 | Compatibilidade com **Rails 8.0.4** e base **`ActionController::API`** (includes manuais do `ApplicationController`) — verificado na D6; sem mudança na classe base. |
| RNF02 | **Dependência única de paginação (pagy)** ao final do piloto; sem override/duplicação dos partials da zutils. |
| RNF03 | **Sem dependência npm nova** (filtering local via importmap; bootstrap-table inert); sem Node além do já usado para SCSS. |
| RNF04 | Suíte completa sem regressão: `bin/rails test` **verde** (baseline atual: ~644 testes, 1 falha pré-existente de timezone documentada); `rails zeitwerk:check` OK; rubocop limpo nos arquivos novos/alterados. |
| RNF05 | Visual coerente com **AdminLTE 4 + Bootstrap 5.3** já em uso (cards, tabelas, badges). |
| RNF06 | Sem alteração de banco, sem migrations, sem mudança em autenticação/autorização existente. |

---

## 5. Casos de Uso / Fluxos

### UC-01 — Gerar um CRUD novo com o scaffold padronizado (happy path)
1. Dev executa `rails g scaffold Modelo` (flat).
2. Template gera controller `Admin::ModelosController < Admin::ApplicationController` com `load_and_authorize_resource`, `ransack(params[:q])`, `@pagy, @collection = pagy(...)`, `Modelo_params` e notices pt-BR.
3. Views geradas em `app/views/admin/modelos/`: `index` (search_form + index), `new`/`edit` (shared/form), `show` (shared/show), partial com `display`.
4. Dev adiciona as rotas dentro do bloco `scope module: "admin"` (com GETs `new`/`edit`) seguindo o padrão já existente (estacoes/regimes/versoes).
5. Dev define `self.icon` e `ransackable_*` no model (RN04).

### UC-02 — Piloto: migrar `regimes` e `versoes` (generator)
- Regenerar controllers/views no novo estilo com o template adaptado; manter modelos `Regime`/`Versao` flat e rotas flat existentes; ajustar `self.icon`/`ransackable_*`; validar telas.

### UC-03 — Piloto: migrar `estacoes` (manual, mesmo estilo)
- `admin/estacoes` reescrito manualmente com os mesmos partials/padrões (porque o model é `EstacaoPonto`, não `Estacao`); comportamento e permissões preservados.

### UC-04 — users/frequentadores: trocar paginação para pagy
- Controllers passam a `@pagy, @vinculos = pagy(...)`; views usam `pagy_info`/`pagy_nav`; total/range exibidos via pagy; nada mais muda.

### UC-05 — Remover kaminari
- Após UC-02/03/04: remover gem `kaminari` do Gemfile, `bundle install`, apagar `app/views/kaminari/`, rodar a suíte completa.

### Fluxos alternativos / edge cases
- **Ransack em modelo sem whitelist:** sem `ransackable_*`, o ransack 4.4 permite todas as colunas (default) — mitigado por RN04 (whitelist definida).
- **Notices/erros de validação:** `shared/form` mostra erros via simple_form (`error_notification`) e o layout exibe flash local — sem duplicação.
- **Busca do scaffold genérico:** o template do basic8 hardcoda `search_fields: [name_cont]`; como nem todo model tem `name`, o template adaptado usa o default `id_eq` do zutils e o dev ajusta `search_fields` por model (detalhe de implementação).

---

## 6. Critérios de Aceite

1. `rails g scaffold Modelo` gera controller que herda `Admin::ApplicationController`, com `load_and_authorize_resource` + ransack + `@pagy, @collection = pagy(...)` + notices pt-BR, e views em `app/views/admin/modelos/` usando `shared/*`. (RF04/RF05)
2. Piloto concluído: `regimes`, `versoes` (via generator) e `estacoes` (manual) no novo estilo, com busca ransack funcionando e CRUD admin funcional (create/update/destroy restritos a admin). (RF08)
3. users/frequentadores paginados com pagy e comportamento idêntico ao anterior (filtros, badges, ações). (RF09)
4. Kaminari removido do Gemfile; nenhum `paginate`/`.page(`/`total_count` restante no código do app. (RF10)
5. `shared/search_form` funcional sem `@zezim/zutils` (controller Stimulus local `filtering`). (RF11)
6. `shared/index` renderiza nas telas pilotos sem bootstrap-table (inert) e sem erro. (RF12)
7. `bin/rails test` sem novas falhas (baseline: 1 falha pré-existente de timezone); `rails zeitwerk:check` OK; rubocop limpo. (RNF04)
8. Telas bespoke users/frequentadores documentadas como exceção (RN02) no próprio código/comentário.

---

## Registro de Decisões (D1–D6)

| # | Decisão | Escolha | Consequências |
|---|---|---|---|
| D1 | Origem dos partials `shared/*` | **Gem `zutils` 4.0.0** (engine), como no basic8 | Convenção `Model.icon`; helpers via `ActionView::Base`; JS controllers locais; sem `zutils.scss` |
| D2 | Gems de formulário/busca | **`simple_form ~> 5.4` + `ransack ~> 4.4`** + `zutils ~> 4.0`; initializer simple_form (wrapper BS5) + locale pt-BR | Whitelist `ransackable_*` nos models |
| D3 | Paginação | **`pagy ~> 9`** (padrão real do basic8) | Template adaptado para `@pagy, @collection = pagy(...)`; kaminari removido (ver D5) |
| D4 | Namespace | **Opção A — convenção atual automatizada**: scaffold flat + template customizado; controller herda `Admin::ApplicationController`; views em `admin/`; rotas flat no `scope module: "admin"`; model flat | Sem quebra de paths existentes |
| D5 | Coexistência | **P2 — Piloto**: estacoes/regimes/versoes no novo estilo; users/frequentadores só paginação pagy; **kaminari removido**; sem override da zutils; bespoke = exceção documentada | Single-gem pagy; sem dual-gem bug |
| D6 | Compatibilidade Rails 8.0.4 + API-only | **Compatível** (verificado) | `Pagy::Backend`/`Frontend`; flash local mantida; filtering local; bootstrap-table inert; não importar `zutils.scss`; estacoes migrado manual |

---

## Configuração necessária (resumo de implementação)

- **Gemfile:** `zutils ~> 4.0`, `simple_form ~> 5.4`, `ransack ~> 4.4`, `pagy ~> 9`; **remover** `kaminari` ao final do piloto.
- **Initializers:** `simple_form:install` + wrapper Bootstrap 5; locale pt-BR (`simple_form.pt-BR.yml`).
- **Controllers/Helpers:** `Admin::ApplicationController` += `include Pagy::Backend`; `ApplicationHelper` += `include Pagy::Frontend`.
- **Templates portados** (`lib/templates/`): `rails/scaffold_controller/controller.rb.tt` (adaptado: `Admin::ApplicationController`, ransack + pagy + notices pt-BR) e `erb/scaffold/*` (`index`, `new`, `edit`, `show`, `partial` → `shared/*`).
- **Stimulus local:** `app/javascript/controllers/filtering_controller.js` registrado no `index.js`.
- **Models pilotos:** `self.icon` + `ransackable_*` em `EstacaoPonto`, `Regime`, `Versao`.
- **Routes:** novas rotas adicionadas dentro do bloco `scope module: "admin"` (incl. GETs `new`/`edit`), padrão já usado.
- **Limpeza:** apagar `app/views/kaminari/`; remover `paginate`/`total_count`/`offset_value`/`.page(` das 2 views/2 controllers de users/frequentadores.

---

## Riscos

| Risco | Severidade | Mitigação |
|---|---|---|
| Regressão nas telas bespoke (users/frequentadores) na troca de paginação | 🟡 | Escopo mínimo (só paginação); suíte cobre `?page=`; validação manual |
| Divergência da migração manual de `estacoes` vs template gerado | 🟢 | Mesmos partials/padrões; revisão de conformidade |
| Gem externa `zutils` em evolução (futuros upgrades) | 🟢 | Pin `~> 4.0`; helpers já portados parcialmente (eval_with_rescue/menu_activated?) |
| `bootstrap-table` inert sem JS (ordenar client-side ausente) | 🟢 | `sort_all` roda server-side via `sort_link` (ransack) — sem perda funcional |
| `pagy_bootstrap_nav` (visual BS5) — zutils usa `pagy_nav` puro | 🟢 | Avaliar extra/override visual na implementação; não bloqueia |
| Convivência com Sprint 23 (23.7–23.10 pendentes) | 🟡 | Nenhuma alteração em auth/ability; piloto respeita a matriz existente |

---

## Fora do Escopo

- Migração completa de `users`/`frequentadores` para partials genéricos (P3) — telas bespoke **preservadas** (RN02).
- Dashboard, relatórios, `time_records`, `gestores_individuais`, páginas de frequência/parcial — permanecem como estão.
- Partials não usados da zutils (`modal`, `dropdown`, `file_chooser`, `turbo_modal`, `empty_state*`, `flash*`, `toastr`, `sweetalert`, `ckeditor`).
- `zutils.scss`, tom-select, fileinput e demais dependências JS pesadas da zutils.
- Alterações em autenticação, autorização, banco, migrations ou regras de negócio do domínio.

---

## Rastreabilidade

**Decidido (fechado):** D1–D6 acima; escopo P2; piloto regimes/versoes via generator + estacoes manual; filtering local; bootstrap-table inert; whitelist ransackable; remoção total do kaminari; flash local mantida; `zutils.scss` não importado.

**Aberto (detalhes de implementação, não decisões):**
- `search_fields` default do template por model (zutils default `id_eq`; ajuste por tela).
- Avaliação de `pagy_bootstrap_nav` para o visual BS5 nas telas pilotos.
- Ícones (`self.icon`) específicos por model.
- Whitelist `ransackable_*` exata por model.
- Breakdown em tasks do Sprint (Project Planner / Sprint Planner).