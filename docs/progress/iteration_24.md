# Iteration 24 — Stack basic8 (gems + wiring)
> Status: ✅ Concluída | Período: 2026-10-05 a 2026-10-09 | Goal: Adotar as gems de referência (zutils, simple_form, ransack, pagy) e expor o pagy no stack admin sem alterar auth/banco | RFs: RF01, RF02, RF03, RF14

## Pré-condição
- **Merge da tarefa 23.7** (Sprint 23 — integração CanCanCan nos controllers) antes do início da sprint. Decisão de planejamento do implementation_plan.md (§ Decisões Arquiteturais): a Sprint 24 expõe o `Pagy::Backend` no `Admin::ApplicationController` — mesma região de código da 23.7; sequenciar evita conflito de merge e respeita RN06 (zero regressão em auth/ability).

## Desenvolvedores
| Dev | Perfil | Foco |
|-----|--------|------|
| Code Specialist | Backend + Infra | Gemfile/bundle, initializers, wiring pagy, validação de compatibilidade |

## Backlog

### Gems — Gemfile e bundle (RF01, RF02, RF03)

#### Tarefa 24.1 — Adicionar gems `zutils`, `simple_form`, `ransack`, `pagy` ao Gemfile + bundle install
- User Story: Como dev, quero adicionar as gems de referência do basic8 ao Gemfile para que a feature de scaffolds tenha as dependências instaladas e resolvidas no bundle
- Rastreabilidade: RF01, RF02, RF03; RNF06 (sem alteração de banco/auth)
- Estimativa: 3 pontos | Atribuição: Code Specialist
- Dependências: 23.7 (merge — pré-condição da sprint)
- Critérios de aceite:
  - [x] `gem "zutils", "~> 4.0"` adicionada (RF01)
  - [x] `gem "simple_form", "~> 5.4"` e `gem "ransack", "~> 4.4"` adicionadas (RF02)
  - [x] `gem "pagy", "~> 9"` adicionada (RF03)
  - [x] `bundle install` limpo; `Gemfile.lock` com versões resolvidas (zutils 4.0.x, simple_form 5.4.x, ransack 4.4.x, pagy 9.x)
  - [x] `kaminari` NÃO removido (RF10 é escopo da Sprint 28)
  - [x] Sem conflito de helpers: `menu_activated?`/`eval_with_rescue` locais (ApplicationHelper) precedem os da engine zutils (D1 — helpers via ActionView::Base)
  - [x] `ransackable_*` NÃO entra nesta sprint (whitelist é RN04/Sprint 25 — verificar confirmado: nenhuma query ransack em runtime aqui)
  - [x] `rails zeitwerk:check` OK
  - [x] Boot do app OK (`bin/rails runner` com carregamento das 4 gems)
  - [x] Suíte baseline sem regressão (`bin/rails test` — 1 falha pré-existente de timezone permitida)
  - [x] Nenhuma migration/schema alterado; auth/ability intactos (RNF06)
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 09:35 | Leitura de contexto (iteration_24, PRD, iteration_23) + verificação de branch/estado git (feat/cancancan-controller-integration, 23.7 presente) | Branch confirmada; working tree com alterações pré-existentes irrelevantes (logs/cache/builds — ignoradas) |
  | 09:42 | Verificação de disponibilidade/versões das gems no rubygems (zutils 4.0.0, simple_form 5.4.x, ransack 4.4.x, pagy 9.x) | Todas publicadas; pins `~>` resolvem conforme basic8 |
  | 09:48 | Adição das 4 gems ao `Gemfile` (seções `# Pagination` e `Scaffold padrão do basic8`) + `bundle install` | Resolução limpa sem conflitos (Rails 8.0.x/Ruby 3.4.2/vendor): zutils 4.0.0, simple_form 5.4.1, ransack 4.4.1, pagy 9.4.0; kaminari 1.2.2 preservado no lock |
  | 09:56 | `rails zeitwerk:check` + `bin/rails runner` com carga das 4 gems + verificação de precedência de helpers | "All is good!"; boot OK (zutils/simple_form/ransack/pagy loaded); `menu_activated?`/`eval_with_rescue` resolvem para `app/helpers/application_helper.rb` (precedência local sobre Zutils::Helpers — verificado via source_location e chamada funcional) |
  | 10:02 | `bin/rails test` completo | 669 runs, 1928 assertions, 1 falha (timezone pré-existente — PresencaEndpointsTest 11:30 vs 14:30), 0 erros — sem NOVAS falhas |
  | 10:06 | RuboCop no Gemfile | 1 arquivo inspecionado, 0 offenses |

#### Tarefa 24.2 — Gerar e configurar initializer do simple_form (wrapper Bootstrap 5 + locale pt-BR)
- User Story: Como dev, quero gerar e configurar o simple_form com wrapper Bootstrap 5 e mensagens em pt-BR para que os formulários dos scaffolds sigam o padrão visual e idiomático do projeto
- Rastreabilidade: RF02; RN03 (pt-BR estrito); RNF01 (base API-only)
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 24.1
- Critérios de aceite:
  - [x] `rails generate simple_form:install` gera `config/initializers/simple_form.rb` sem erro na base API-only (RNF01/D6)
  - [x] Initializer ajustado para wrapper/componentes Bootstrap 5 (padrão básico do basic8 — remover/comentar b3/b4 legacy)
  - [x] `config/locales/simple_form.pt-BR.yml` criado (RN03)
  - [x] Nenhuma view alterada (formulários só passam a usar simple_form na Sprint 25)
  - [x] `rails zeitwerk:check` OK
  - [x] Suíte baseline sem regressão (1 falha pré-existente de timezone permitida)
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 11:10 | Leitura de contexto (governance/_context.md, progress/_context.md, iteration_24.md task 24.2, iteration_23.md) + verificação de estado git | Branch `feat/simple-form-initializer` já criada a partir do HEAD de `feat/cancancan-controller-integration` (commit `612a442`, mesmo commit da pré-condição 23.7/24.1) — trabalho de geração já presente no working tree, não commitado (COMMIT_MODE=manual) |
  | 11:14 | Verificação de `config/application.rb`: `config.api_only = true`, mas `require "action_view/railtie"` está descomentado (necessário para as views ERB de presença/estação de ponto — Sprint A) | Generator do simple_form não falha: ActionView está carregado apesar do `api_only = true`; nenhum ajuste adicional necessário para D6 |
  | 11:18 | Revisão dos arquivos já gerados: `config/initializers/simple_form.rb` (base do generator, wrapper `:default` genérico sem classes Bootstrap), `config/initializers/simple_form_bootstrap.rb` (gerado com `rails generate simple_form:install --bootstrap`, define `:vertical_form` e demais wrappers 100% Bootstrap 5 — `form-control`/`form-select`/`invalid-feedback`, sem `control-group`/`form-group`/`input-group-addon` legados de b3/b4), `config/locales/simple_form.{en,pt-BR}.yml` | Confirmado: wrapper padrão efetivo em runtime é `:vertical_form` (Bootstrap 5) — carregado por ordem alfabética dos initializers (`simple_form.rb` → `simple_form_bootstrap.rb`, o segundo sobrescreve `default_wrapper`); pt-BR locale com chaves RN03 (yes/no/required/error_notification) |
  | 11:24 | `bin/rails zeitwerk:check` | "All is good!" |
  | 11:26 | `bundle exec rubocop` nos 3 arquivos novos/alterados (2 initializers + `test/config/simple_form_configuration_test.rb`) | 3 arquivos inspecionados, 0 offenses |
  | 11:30 | `bin/rails test` completo | 713 runs, 2280 assertions, 1 falha (mesma falha pré-existente de timezone, `presenca_endpoints_test.rb:187`), 0 erros — 7 novos testes de `test/config/simple_form_configuration_test.rb` (49 assertions); baseline desta branch (706, partindo de `612a442` sem o teste count_sql_queries do Bug 10) subiu para 713; zero regressão. Re-verificado em 2026-09-23: 713 runs / 2280 assertions / 1 falha |

  **Nota técnica:**
  - **D6 (generator em base API-only):** o app tem `config.api_only = true`, mas o Rails 8 permite reabilitar seletivamente frameworks — `action_view/railtie` já está descomentado em `config/application.rb` desde a Sprint A (views ERB de IniciarPonto/InicializarPonto/PontoDePresenca). Isso é suficiente para o generator `simple_form:install` rodar sem erro (ele depende de `ActionView::Base` para os templates de instalação), sem exigir nenhum ajuste manual ou gambiarra na base API-only.
  - **Wrapper Bootstrap 5 escolhido:** usado o flag nativo `--bootstrap` do generator da simple_form 5.4.1 (`rails generate simple_form:install --bootstrap -e erb`), que já produz templates 100% Bootstrap 5 (sem depender da gem externa `simple_form-bootstrap`, que hoje é mantida separada e teria overhead de dependência não justificado — RN de "não adicionar gem sem justificar" respeitada, pois o generator built-in já resolve). O padrão gerado separa dois arquivos: `simple_form.rb` (base genérica do generator, sem classes visuais) e `simple_form_bootstrap.rb` (wrappers reais: `:vertical_form` como `default_wrapper`, mais `:vertical_boolean`, `:vertical_select`, `:horizontal_form`, `:floating_labels_form`, `:input_group` etc., todos com classes `form-control`/`form-select`/`form-check`/`invalid-feedback`). A ordem alfabética de carregamento dos initializers garante que o segundo arquivo prevaleça — documentado em comentário no topo do próprio arquivo para evitar que alguém funda os dois blocos fora de ordem numa refatoração futura.
  - **Sem gem de suporte adicional:** nenhuma gem nova foi necessária (nem `simple_form-bootstrap`, nem sass adicional) — o asset pipeline (Bootstrap 5.3 via CDN/importmap, conforme `vanilla-rails-8-frontend`) já fornece as classes CSS consumidas pelos wrappers.
  - **Teste de contrato:** `test/config/simple_form_configuration_test.rb` cobre a configuração (wrapper padrão, wrappers registrados, wrapper_mappings, classes visuais BS5, ausência de classes legadas b3/b4, existência dos 3 arquivos entregáveis, mensagens pt-BR via I18n) — evita depender de views (que só chegam na Sprint 25) para validar o initializer.
  - **Decisão de branch:** conforme padrão de branches encadeadas das Sprints 23/24, a branch `feat/simple-form-initializer` foi criada a partir do HEAD de `feat/cancancan-controller-integration` (mesmo commit `612a442` da pré-condição 24.1), em vez de reiniciar de `develop`/main — evita reabrir conflitos já resolvidos nas sprints anteriores. Nenhum commit foi feito nesta sessão (COMMIT_MODE=manual): arquivos deixados no working tree para revisão do dev.

### Wiring Pagy (RF03)

#### Tarefa 24.3 — Expor `Pagy::Backend` no `Admin::ApplicationController`
- User Story: Como dev, quero expor Pagy::Backend no Admin::ApplicationController para que todos os controllers admin possam paginar com pagy (`@pagy, @collection = pagy(...)`)
- Rastreabilidade: RF03; RNF01 (compatibilidade API-only)
- Estimativa: 1 ponto | Atribuição: Code Specialist
- Dependências: 24.1; 23.7 (merge obrigatório — mesma região de código)
- Critérios de aceite:
  - [x] `include Pagy::Backend` adicionado; `include CanCan::ControllerAdditions`, `check_authorization` e `rescue_from CanCan::AccessDenied` (23.7) intactos
  - [x] `pagy(...)` disponível em controller admin (teste de controller/helper callable)
  - [x] `require_login`/`current_user` e comportamento de auth inalterados (RN06)
  - [x] `rails zeitwerk:check` OK; suíte baseline sem regressão
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-23 | Verificação do estado do merge da 23.7 ANTES de codar: `2d99706` (Sprint 23, inclui 23.7) é ancestor do HEAD; HEAD (`612a442`) == tip de `feat/cancancan-controller-integration`; `Admin::ApplicationController` já contém na base `include CanCan::ControllerAdditions`, `check_authorization` e `rescue_from CanCan::AccessDenied` | Base OK — sem bloqueio (região de código da 23.7 presente; "merge para main" segue pendente no repo — inconsistência docs × código já registrada no progress/_context.md). Branch `feat/pagy-backend-admin-controller` criada a partir do HEAD `612a442` |
  | 2026-09-23 | `include Pagy::Backend` adicionado no `Admin::ApplicationController` (comentário pt-BR do PORQUÊ: módulo privado no Pagy 9, chamado pelas actions, sem impacto em auth/CanCan); constructos 23.7 e auth intactos | Diff: +6 linhas no controller (nada removido) |
  | 2026-09-23 | `test/controllers/admin/application_controller_test.rb` criado (4 testes/25 asserts): ancestry `Pagy::Backend` + `private_method_defined?(:pagy)`; `pagy(...)` callable via esteira real (login → dashboard → `@controller.send(:pagy, User.all)` → `[Pagy, records]`); 23.7 intacta (ancestry CanCan + after_action do `check_authorization` com source_location cancancan + `rescue_handlers` com handler Proc para `CanCan::AccessDenied` + `handler_for_rescue` resolvível); RN06 (guest → redirect login; `current_user` da sessão preservado) | Isolado: 4 runs / 25 asserts verdes; área admin: 122 runs / 578 asserts verdes |
  | 2026-09-23 | `zeitwerk:check` + rubocop nos 2 arquivos + suíte completa | "All is good!"; rubocop 0 offenses; **717 runs / 2305 asserts / 1 falha (timezone pré-existente `presenca_endpoints_test.rb:187`) / 0 erros** — sem NOVAS falhas (baseline 24.2: 713/2280/1) |

  **Nota técnica:**
  - **Lição — `pagy` é privado no Pagy 9:** `Pagy::Backend` (9.4.0) declara `private` no topo do módulo e define `def pagy(collection, **vars)` — não é público. Nas actions a chamada ocorre em contexto privado natural (`@pagy, @collection = pagy(...)`); em specs, `send(:pagy, ...)`. O teste de aceite usa `@controller.send(:pagy, User.all)` na esteira real (router → before_action → CanCan → action) e confirma o retorno `[Pagy, records]` com `pagy.count` = total da collection.
  - **Pagy não ordena a collection:** o pagy aplica `offset`/`limit` sobre a collection como fornecida (sem ORDER BY) — a asserção de registros no teste compara por conjunto de ids.
  - **23.7 intacta — verificação estrutural e comportamental:** além da suíte existente (`authorization_matrix_test`, 23.7), o teste de contrato da 24.3 verifica: ancestry `CanCan::ControllerAdditions`; after_action do `check_authorization` (bloco com `source_location` no `cancancan/controller_additions.rb`, que levanta `CanCan::AuthorizationNotPerformed` quando a action não autoriza); `rescue_handlers` contendo `CanCan::AccessDenied` com handler Proc e `handler_for_rescue` resolvível para a exceção.
  - **Auth (RN06):** `require_login`/`current_user` inalterados — teste dedicado confirma guest → redirect `login_path` e `current_user` derivado do usuário autenticado na sessão.
  - **Merge 23.7 (dependência):** base OK — o commit da Sprint 23 é ancestor do HEAD e os constructos da 23.7 já estavam no arquivo editado; a sequencialização da sprint (24.3 sobre branch encadeada na 23.7, após 24.1) eliminou o risco de conflito na mesma região (mitigação do risco 🟡 da seção Riscos confirmada).
  - **COMMIT_MODE=manual:** nenhum commit/push executado — controller editado + teste novo deixados no working tree para revisão do dev.

#### Tarefa 24.4 — Expor `Pagy::Frontend` no `ApplicationHelper`
- User Story: Como dev, quero expor Pagy::Frontend no ApplicationHelper para que as views admin tenham `pagy_info`/`pagy_nav` disponíveis
- Rastreabilidade: RF03
- Estimativa: 1 ponto | Atribuição: Code Specialist
- Dependências: 24.1
- Critérios de aceite:
  - [x] `include Pagy::Frontend` adicionado no `ApplicationHelper`
  - [x] `menu_activated?`/`eval_with_rescue` (portados da zutils) preservados
  - [x] `pagy_info`/`pagy_nav` callable (teste de helper)
  - [x] `rails zeitwerk:check` OK; suíte baseline sem regressão
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-23 | Verificação da base: repo sem `develop`, sessão em branches encadeadas a partir do HEAD `612a442` (padrão 24.2/24.3); working tree contém 24.2/24.3 não-commitadas (arquivos disjuntos — sem bloqueio, nenhum arquivo tocado). Branch `feat/pagy-frontend-application-helper` criada a partir de `612a442`; inspeção da API do Pagy 9.4.0: `Pagy::Frontend` público (`pagy_anchor`/`pagy_info`/`pagy_nav`/`pagy_t`), inclui `UrlHelpers` (usa `request`/`params` do contexto de view); `ActionView::TestCase::Behavior` expõe `request` — base do teste de helper | Base OK; API confirmada |
  | 2026-09-23 | `include Pagy::Frontend` adicionado no `ApplicationHelper` (comentário pt-BR do PORQUÊ: módulo público no Pagy 9, usa `request`/`params` da view via UrlHelpers, sem depender do controller; helpers zutils `menu_activated?`/`eval_with_rescue` intactos) | Diff: +5 linhas no helper (nada removido) |
  | 2026-09-23 | `test/helpers/application_helper_test.rb` estendido (4 testes novos/9 asserts): ancestry `Pagy::Frontend`; `pagy_info` callable (multi-página e página única → `<span class="pagy info">`); `pagy_nav` callable (10 páginas → `<nav class="pagy nav">` + `aria-current="page"` + links `?page=N` construídos via `request` do contexto de view); 6 testes zutils existentes intactos (preservação dos helpers) | Isolado: **10 runs / 24 asserts verdes** |
  | 2026-09-23 | `zeitwerk:check` + rubocop nos 2 arquivos + suíte completa | "All is good!"; rubocop 0 offenses (2 arquivos); **721 runs / 2323 asserts / 1 falha (timezone pré-existente `presenca_endpoints_test.rb:187` — 11:30 vs 14:30) / 0 erros** — sem NOVAS falhas (baseline 24.3: 717/2305/1) |

### Compatibilidade (RF14)

#### Tarefa 24.5 — Validar compatibilidade do flash local com a zutils carregada
- User Story: Como dev, quero verificar que o flash local do layout admin continua renderizando notices/alerts com a zutils no bundle para garantir que os notices pt-BR dos scaffolds apareçam sem adotar partials `shared/flash*`
- Rastreabilidade: RF14; RNF04/RNF05 (visual AdminLTE)
- Estimativa: 1 ponto | Atribuição: Code Specialist
- Dependências: 24.1
- Critérios de aceite:
  - [x] Layout admin (e views de layout) inalterado — `flash[:notice]`/`flash[:alert]` continuam renderizando
  - [x] Nenhum partial `shared/flash*` nem helper `bootstrap_flash` adotado (RF14)
  - [x] Verificação funcional: flash exibido em ação admin real (ex: `redirect_to ..., notice:` em controller admin existente)
  - [x] Nenhuma colisão de renderização/helper com a engine zutils
  - [x] Suíte baseline sem regressão
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-23 | Leitura de contexto (iteration_24, progress/_context, lessons) + análise da superfície de flash da zutils 4.0.0 (engine): `Zutils::Helpers#bootstrap_flash` incluído em `ActionView::Base` via `config.to_prepare` (mapeia `alert`→`alert-warning`, `error`→`alert-danger`, zera `flash[:error]`) e partial `shared/_flash` com wrapper `#flash_messages[data-controller=toastr]` — NENHUM adotado pelo app | Compatibilidade preliminar: sem conflito real (layouts renderizam flash inline; nunca chamam `bootstrap_flash`/`render "shared/flash"`); branch `feat/flash-local-zutils-compat` criada a partir de `612a442` (padrão da sessão) |
  | 2026-09-23 | Criação de `test/integration/flash_local_zutils_compat_test.rb` (4 testes/62 asserts): (1) ação admin real `POST /login` → `redirect_to dashboard_path, notice:` → flash consumido em `regimes_path` renderiza markup LOCAL (`alert-success` + `btn-close`, exatamente 1 alerta, sem `#flash_messages`/`toastr`); (2) `CanCan::AccessDenied` real (gestor → `new_estacao_path`) → `flash[:alert]` renderiza `alert-danger` LOCAL, NÃO `alert-warning` da zutils (preferência local provada na mesma chave); (3) RF14 estrutural: layouts admin/application inalterados (inline `flash[:notice]`/`flash[:alert]` e helpers `notice`/`alert`), sem partials `shared/flash*` no app, `bootstrap_flash` não definido no `ApplicationHelper`; (4) engine ativa (`Zutils::Helpers` no ancestry do `ActionView::Base`) coexistindo sem colisão | Isolado: **4 runs / 62 asserts verdes** (1º ajuste: consumir flash em `regimes_path` em vez de `dashboard` — dashboard admin consulta `Pessoas::Vinculo`, tabela `vinculos` inexistente no banco de teste — padrão task 8.13) |
  | 2026-09-23 | `zeitwerk:check` + rubocop no arquivo novo + suíte completa | "All is good!"; rubocop 0 offenses (1 arquivo — 3 ofensas de layout corrigidas); **725 runs / 2385 asserts / 1 falha (timezone pré-existente `presenca_endpoints_test.rb:187`) / 0 erros** — sem NOVAS falhas (baseline 24.4: 721/2323/1) |

  **Nota técnica:**
  - **Conclusão da validação (RF14): SEM conflito real — não houve correção de código.** O flash local e a superfície de flash da zutils coexistem sem colisão porque são caminhos de renderização independentes: os layouts `admin.html.erb`/`application.html.erb` leem `flash`/`notice`/`alert` diretamente (via `ActionController::Flash` no `ApplicationController`) e renderizam inline; a engine zutils só entra no HTML se o app optar por `render "shared/flash"` ou chamar `bootstrap_flash` — nunca acontece (RF14).
  - **Análise de compatibilidade (o que a zutils provê × o que o flash local faz):**
    - zutils `bootstrap_flash` (helper): mapeia `notice`→`alert-success`, `error`→`alert-danger`, **`alert`→`alert-warning`** (amarelo) e demais→`alert-info`; rende em div com `btn-close`/ícone/título; **efeito colateral: zera `flash[:error]`**; depende de `controller_name`/`action_name`/`@object_name`/`I18n`.
    - Flash local: `flash[:notice]`→`alert-success` e **`flash[:alert]`→`alert-danger`** (vermelho), com `btn-close`; sem ícone; sem mutação do flash. A diferença de mapeamento do `alert` (danger local × warning zutils) é justamente o discriminador usado no teste 2 para provar a preferência local na renderização real.
    - Meta-helper `menu_activated?`/`eval_with_rescue`: conflito de nomes já resolvido na 24.1 (precedência do `ApplicationHelper` sobre `Zutils::Helpers` — verificado via source_location); inalterado nesta task.
    - Partial `shared/_flash` da engine (wrapper Toastr `#flash_messages`): parcial não existe no app e nunca é renderizado — comprovado por assert estrutural e pela ausência de `id="flash_messages"`/`data-controller="toastr"` no HTML das páginas admin reais.
  - **Observação fora de escopo (registrada, NÃO alterada):** o layout `login.html.erb` NÃO renderiza flash — `flash.now[:alert]` do `Admin::SessionsController#create` com credenciais inválidas não é exibido. Pré-existente e alheio ao RF14 (admin scaffolds); corrigir exigiria tocar layout não relacionado à task (regra "não toque em código não relacionado"). Sinalizado ao Orchestrator como observação.
  - **COMMIT_MODE=manual:** nenhum commit/push executado — apenas `test/integration/flash_local_zutils_compat_test.rb` (novo) deixado no working tree para revisão do dev.

### Validação Final (RNF04/RNF06)

#### Tarefa 24.6 — Smoke test de carga das 4 gems + aceite da Sprint 24
- User Story: Como dev, quero validar a carga conjunta das gems (zeitwerk, boot, suíte baseline) para confirmar que a Sprint 24 não introduz regressões e liberar a Sprint 25
- Rastreabilidade: RNF04, RNF06, RN06; aceite RF01–RF03/RF14
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 24.2, 24.3, 24.4, 24.5
- Critérios de aceite:
  - [x] `bin/rails test` completo verde (baseline: 644 testes/1 falha pré-existente de timezone — sem NOVAS falhas)
  - [x] `rails zeitwerk:check` OK com as 4 gems carregadas juntas
  - [x] RuboCop limpo nos arquivos novos/alterados
  - [x] `bin/rails runner` boot OK; nenhuma migration nova (RNF06 — banco inalterado)
  - [x] Auth Pessoas2/Devise e Ability (Sprint 23) sem regressão (RN06)
  - [x] Rastreabilidade RF01–RF03/RF14 e notas técnicas registradas (detalhes de implementação da sprint)
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-23 | Verificação de contexto (iteration_24 completa, progress/_context, lessons) + estado git: working tree contém 24.2–24.5 não-commitadas (COMMIT_MODE=manual — padrão da sessão); Gemfile/lock já com as 4 gems (commitado em `612a442`); `db/` inalterado (RNF06); branch `feat/smoke-test-4-gems-sprint-24` criada a partir do HEAD `612a442` (padrão encadeado da sessão) | Branch confirmada; working tree preservado |
  | 2026-09-23 | Probe de carga conjunta via `bin/rails runner`: boot OK; zutils 4.0.0 / simple_form 5.4.1 / ransack 4.4.1 / pagy 9.4.0 / kaminari 1.2.2 carregados juntos; `User.ransack({})` → `Ransack::Search`/`ActiveRecord_Relation`; `ransackable_attributes` source_location na gem (RN04 intocada); `Pagy.new(count: 42, page: 2, limit: 20)` → 42/2/3; `menu_activated?` source_location em `app/helpers/application_helper.rb` (precedência local D1); `Admin::ApplicationController < Pagy::Backend` + `ApplicationHelper < Pagy::Frontend`; `Zutils::Helpers` no ancestry do `ActionView::Base`; `SimpleForm.default_wrapper == :vertical_form`; CanCan presente | Boot OK; funcionalidade mínima de cada gem confirmada sob carga conjunta |
  | 2026-09-23 | `bin/rails zeitwerk:check` | "All is good!" (EXIT 0) — carregamento simultâneo das 4 gems sem conflito |
  | 2026-09-23 | Criação de `test/config/sprint24_gem_smoke_test.rb` (6 testes/46 asserts): lock com as 4 gems + kaminari preservado (RF10); zutils engine ativa + precedência local de `menu_activated?`/`eval_with_rescue` (D1); simple_form wrapper BS5 + pt-BR sob carga conjunta; ransack funcional + whitelist na gem (RN04/Sprint 25); pagy Backend+Frontend expostos e core funcional; coexistência kaminari×pagy sem conflito | Isolado: **6 runs / 46 asserts verdes** |
  | 2026-09-23 | RuboCop nos 9 arquivos novos/alterados da sprint (2 controllers/helpers + 2 initializers + 5 testes) | 9 arquivos inspecionados, 0 offenses |
  | 2026-09-23 | `bin/rails test` completo | **731 runs / 2431 asserts / 1 falha (timezone pré-existente `presenca_endpoints_test.rb:187` — 11:30 vs 14:30) / 0 erros** — sem NOVAS falhas (baseline 24.5: 725/2385/1; +6 runs/+46 asserts do smoke test 24.6); RN06 coberto pela suíte (authorization_matrix, devise flows, admin area) |
  | 2026-09-23 | Aceite da Sprint 24 registrado (header Status ✅ Concluída; tasks 24.1–24.5 já ✅; 24.6 ✅; Definição de Pronto confirmada) | Sprint 24 aceita — libera Sprint 25 |

  **Nota técnica:**
  - **Smoke test de carga conjunta (`test/config/sprint24_gem_smoke_test.rb`):** em contraste com os testes por task (24.2–24.5, cada um isolando seu setup), o smoke da 24.6 valida TODAS as 4 gems no mesmo processo de teste/boot: lock resolvido, engine zutils ativa com precedência local, wrapper BS5 default do simple_form intacto, `ransack` funcional sem whitelist no app (RN04), pagy wired (Backend+Frontend) e core paginando, e coexistência kaminari×pagy. Isso cobre o critério "carregamento simultâneo sem conflito" de forma automatizada e reproduzível.
  - **RN06 (auth/ability sem regressão):** não houve mudança de código de autenticação nesta sprint; a suíte completa (731 runs) cobre authorization_matrix, devise/password flows e área admin (122 runs/578 asserts verdes na 24.3) — 0 falhas novas confirma a invariante.
  - **RNF06 (banco inalterado):** `git status db/` vazio; schema.rb com `version: 2026_09_10_000001` (mesma da Sprint A) — zero migrations.
  - **Nenhuma correção de código foi necessária nesta task:** o smoke confirmou que a carga conjunta não introduz conflito; não houve alteração em código de produção (apenas teste novo + docs).
  - **'Bundler.locked_gems' usado no teste para ler o lock** (não parse manual do `Gemfile.lock`) — versões assertadas por prefixo (zutils 4.0.x, simple_form 5.4.x, ransack 4.4.x, pagy 9.x, kaminari 1.2.x) para não quebrar em patch bumps futuros.
  - **COMMIT_MODE=manual:** nenhum commit/push executado — `test/config/sprint24_gem_smoke_test.rb` (novo) + `docs/progress/iteration_24.md` (aceite) deixados no working tree para revisão do dev.

## Caminho Crítico
23.7 (merge) → 24.1 → 24.2 → 24.6 — com 24.3/24.4/24.5 paralelizáveis após 24.1 (24.3 exige 23.7 mergeado). Se houver 2º dev: 24.3/24.4/24.5 em worktree paralela após 24.1.

## Riscos
| Risco | Severidade | Mitigação |
|---|---|---|
| Conflito de merge em `Admin::ApplicationController` (23.7 × 24.3) | 🟡 | Pré-condição da sprint: início somente após merge da 23.7 (decisão de planejamento) |
| Resolução de versões no bundle (zutils 4.0.x engine × Rails 8.0.4/Ruby 4.0.0) | 🟡 | Pins `~>` como no basic8; se conflito, reportar ao Orchestrator SEM reabrir D1–D6 |
| Colisão de helpers locais (menu_activated?/eval_with_rescue portados) × engine zutils | 🟢 | app/helpers tem precedência; verificado na 24.1 |
| `simple_form:install` em base API-only | 🟢 | D6 verificado; ajustes manuais no initializer se necessário |
| Baseline 1 falha pré-existente de timezone | 🟢 | Documentada; aceite RNF04 = sem NOVAS falhas |
| Falha de visual AdminLTE/Bootstrap 5 por influência das gems (flash/forms — Sprint 25) | 🟢 | Nada de views na sprint; RF14 verificado na 24.5 |

## Definição de Pronto
- 4 gems no Gemfile e resolvidas no `Gemfile.lock` (zutils 4.0.x, simple_form 5.4.x, ransack 4.4.x, pagy 9.x)
- `config/initializers/simple_form.rb` com wrapper Bootstrap 5 + `config/locales/simple_form.pt-BR.yml`
- `Pagy::Backend` no `Admin::ApplicationController` e `Pagy::Frontend` no `ApplicationHelper` — testados
- RF14 validado: flash local do layout admin intacto; `shared/flash*`/`bootstrap_flash` não adotados
- Suíte verde (RNF04), zeitwerk OK, rubocop limpo; zero migrations e zero mudança em auth/ability (RNF06/RN06)
- Rastreabilidade por RF completa nas tasks 24.1–24.6

### ✅ Aceite da Sprint 24 — 2026-09-23
Todos os itens da Definição de Pronto confirmados pelo smoke test da task 24.6: carga conjunta das 4 gems (zutils/simple_form/ransack/pagy) sem conflito (zeitwerk OK + boot OK + `test/config/sprint24_gem_smoke_test.rb`), suíte **731 runs / 2431 asserts / 1 falha pré-existente de timezone** (sem NOVAS falhas), RuboCop limpo (9 arquivos), zero migrations (RNF06) e auth/ability intactos (RN06). Sprint 24 **aceita** — libera a Sprint 25.

## Sincronização CAPTEI (opcional — sob demanda)
> O sync com o gerenciador CAPTEI é uma etapa independente e opcional: executada apenas quando solicitada. Abaixo, a estrutura das tarefas aptas a sincronizar nesta sprint (espelhamento futuro — nenhum sync automático agora).

| Tarefa | Título | RF | Aptidão | Observação |
|--------|--------|----|---------|------------|
| 24.1 | Gems zutils/simple_form/ransack/pagy + bundle | RF01, RF02, RF03 | ✅ Aptas | Entregável: Gemfile + lock resolvido |
| 24.2 | Initializer simple_form (wrapper BS5 + locale pt-BR) | RF02 | ✅ Aptas | Entregável: initializer + locale |
| 24.3 | Pagy::Backend no Admin::ApplicationController | RF03 | ✅ Aptas | Entregável: include + teste |
| 24.4 | Pagy::Frontend no ApplicationHelper | RF03 | ✅ Aptas | Entregável: include + teste |
| 24.5 | Validação flash local (RF14) | RF14 | 🟡 Parcial | Verificação/compatibilidade — sem entregável novo; apenas evidência |
| 24.6 | Smoke test de carga + aceite | RNF04/RNF06 | ⬜ Não apta | Validação interna/suíte verde; sem entregável externo |

**Total Sprint 24:** 6 tarefas | 10 pontos | 1 semana | 1 dev (Code Specialist)