# Iteration 23 — Devise + CanCanCan + Rolify (Autenticação + Autorização)
> Status: ✅ Concluída | Período: 2026-09-10 → 2026-09-21 | Goal: Framework completo de autenticação (Devise) e autorização (CanCanCan+Rolify) | RFs: Auth, Roles

## Desenvolvedores
| Dev | Perfil | Foco |
|-----|--------|------|
| Code Specialist | Backend + DB | Migrations, model, controllers |

## Backlog

### Auth

#### Tarefa 23.1 — Gerar migration `add_devise_to_users`
- User Story: Como dev, quero adicionar colunas Devise ao users para suportar autenticação Devise futura
- Rastreabilidade: Auth
- Estimativa: 1 ponto | Atribuição: Code Specialist
- Dependências: nenhuma (migration puramente aditiva)
- Critérios de aceite:
  - [x] Migration `AddDeviseToUsers` criada com 10 colunas Devise
  - [x] `password_digest` preservado (has_secure_password continua ativo)
  - [x] `email` nullable (compatibilidade com users sem email do Pessoas2)
  - [x] `reset_password_token` com índice único
  - [x] `sign_in_count` com default 0, not null
  - [x] Migration roda sem erro em dev e test
  - [x] `db/schema.rb` atualizado automaticamente
  - [x] `rails zeitwerk:check` passa
  - [x] Teste de schema/migration criado e passa (10/10)
  - [x] Suíte existente sem regressão (561 testes, 1 falha pré-existente de timezone)
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-10 | Branch `feat/add-devise-columns` criada a partir de `feat/auth-pessoas-bcrypt` (HEAD) | Branch pronta |
  | 2026-09-10 | Migration `20260910000000_add_devise_to_users.rb` criada | 10 colunas Devise aditivas, `password_digest` preservado |
  | 2026-09-10 | `db:migrate` em dev e test | OK — 0.28s (dev), 0.02s (test) |
  | 2026-09-10 | `rails zeitwerk:check` | "All is good!" |
  | 2026-09-10 | Teste `test/migrations/add_devise_to_users_migration_test.rb` criado (10 casos) | 10/10, 50 asserts |
  | 2026-09-10 | `db/schema.rb` verificado | Versão `2026_09_10_000000`, todas as colunas + índice |
  | 2026-09-10 | Suíte completa: `bin/rails test` | 561 testes, 1563 asserts, 1 falha pré-existente (timezone), 0 erros, 0 regressões |

#### Tarefa 23.2 — Gerar migration `create_roles` + `create_users_roles`
- User Story: Como dev, quero tabelas Rolify para suportar autorização baseada em roles
- Rastreabilidade: Roles
- Estimativa: 1 ponto | Atribuição: Code Specialist
- Dependências: nenhuma
- Critérios de aceite:
  - [x] Migration `CreateRoles` com tabela `roles` (name, resource_type, resource_id)
  - [x] Migration `CreateUsersRoles` com tabela `users_roles` (user_id, role_id)
  - [x] Índices apropriados
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-10 | Branch `feat/rolify-create-roles` criada a partir de `feat/add-devise-columns` | Branch pronta |
  | 2026-09-10 | Migration `20260910000001_rolify_create_roles.rb` criada (migration única `RolifyCreateRoles`, padrão basic8) | Tabelas `roles` + `users_roles` (join, `id: false`) |
  | 2026-09-10 | `db:migrate` em dev (0.04s) e test (0.01s) | OK — ambas as tabelas criadas |
  | 2026-09-10 | `rails zeitwerk:check` | "All is good!" |
  | 2026-09-10 | Model `app/models/role.rb` criado (sem `scopify`, sem validação `resource_type` — gem `rolify` ainda não instalada) | Model funcional para CRUD básico via ActiveRecord |
  | 2026-09-10 | Teste `test/migrations/rolify_create_roles_migration_test.rb` criado (14 casos) | 14/14, 27 asserts |
  | 2026-09-10 | Teste `test/models/role_test.rb` criado (8 casos) | 8/8, 18 asserts |
  | 2026-09-10 | `db/schema.rb` verificado | Versão `2026_09_10_000001`, tabelas `roles` + `users_roles` com colunas e índices corretos |
  | 2026-09-10 | Suíte completa: `bin/rails test` | 583 testes, 1608 asserts, 1 falha pré-existente (timezone), 0 erros, 0 regressões |

  **Nota técnica:** Migration única `RolifyCreateRoles` (padrão basic8) que cria ambas as tabelas de uma vez. O model `Role` foi criado sem `scopify` e sem `validates :resource_type` porque a gem `rolify` ainda não está no Gemfile — essas linhas serão adicionadas na task 23.4. O model é funcional para operações básicas de banco (CRUD, HABTM) sem depender da gem. A tabela `users_roles` é uma join table sem `id` (`id: false`), como padrão do Rolify.

#### Tarefa 23.3 — Configurar Devise no model `User`
- User Story: Como dev, quero ativar Devise no User mantendo autenticação Pessoas2
- Rastreabilidade: Auth
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 23.1
- Critérios de aceite:
  - [x] `devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :trackable` no model
  - [x] `authenticate` custom preservado (Pessoas2 via CPF)
  - [x] `password_digest` não removido
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-10 | Branch `feat/devise-no-user` criada a partir de `feat/rolify-create-roles` (HEAD) | Branch pronta — não há `develop` neste repo (convenção: feature branches encadeadas, ver 23.1/23.2) |
  | 2026-09-10 | Gem `devise` adicionada ao Gemfile (`~> 5.0`, versão 5.0.4 — a mesma do basic8; já presente no bundle como transitiva do `sticapi_client` >= 4.3) | `bundle install` limpo, 20 deps diretas, 117 gems |
  | 2026-09-10 | `rails generate devise:install` | `config/initializers/devise.rb` + `config/locales/devise.en.yml` criados; nenhum env file alterado pelo generator 5.x |
  | 2026-09-10 | Initializer ajustado para o contexto (comentários Task 23.3: API-only, mailer_sender placeholder sem ActionMailer, auth_keys) + rubocop autocorrect | Initializer carrega limpo, `router/ui` formatos OK |
  | 2026-09-10 | Locale `config/locales/devise.pt-BR.yml` criado (base devise-i18n canônico) | I18n pt-BR estrito atendido |
  | 2026-09-10 | Model `User`: `devise ...` + resolução de conflitos `has_secure_password`×Devise (dual-write `password=`, reader/writer `password_digest`, `email_required?` false) | `authenticate` custom INTOCADO; local via `super` e remoto via Pessoas2 verificados no console |
  | 2026-09-10 | 11 testes novos (10 model + 1 controller status inativo) + 2 testes das tasks 21.5/21.7 reaproveitados | 50 runs alvo verdes; console sanity 7/7 |
  | 2026-09-10 | `rails zeitwerk:check` | "All is good!" |
  | 2026-09-10 | Suíte completa: `bin/rails test` | 594 testes, 1647 asserts, 1 falha pré-existente (timezone), 0 erros, 0 regressões |
  | 2026-09-10 | RuboCop nos arquivos alterados | Limpo (5 offenses do initializer gerado corrigidos) |

  **Nota técnica:** A ativação do Devise no model foi feita **preservando integralmente** a autenticação Pessoas2: `has_secure_password` permanece (linha 2), o método `authenticate` custom (CPF → `Pessoas::User.buscar_por_cpf` + bcrypt do pessoas2; sem CPF → `super`) ficou intocado, e o fluxo atual de login (`Admin::SessionsController` → `user.authenticate`) continua sendo a fonte de verdade até a task 23.6 rotear o Devise. Conflitos `has_secure_password` × `DatabaseAuthenticatable` (Devise 5.0.4) resolvidos e documentados com comentários numerados no model:

  1. **`password=` (dual-write):** o módulo Devise, incluído depois do `has_secure_password`, vence na cadeia de ancestrais e gravaria só em `encrypted_password`, deixando `password_digest` vazio e quebrando a auth local via `super`. Sobrescrevemos `password=` para gravar **ambas** as colunas (mesma senha, ambos bcrypt) — `password_digest` para a transição atual e `encrypted_password` já pronta para a task 23.6. `nil` limpa só o atributo virtual (semântica do `clean_up_passwords`).
  2. **`password_digest` reader/writer:** o Devise define `password_digest(pw)` (com argumento, p/ gerar hash), o que faz o AR considerar o nome "já implementado" e não gerar o accessor da coluna — o `has_secure_password#authenticate` (`public_send(:password_digest)`) quebraria com ArgumentError. Restauramos reader (0 args) e writer explícitos sobre a coluna real (`self[:password_digest]`).
  3. **`validatable` + email nullable (decisão 23.1):** `email_required?` retorna `false` durante a transição. Desvio documentado da receita `cpf.blank?` sugerida na task: exigir email para usuários sem `cpf` agora quebraria a suíte inteira (fixtures e ~50 `User.create!` sem email) — a exigência para admins locais fica para 23.8/23.9 (então a regra pode virar `cpf.blank?`). Unicidade/formato usam `devise_will_save_change_to_email?` (dirty tracking do Devise 5) — inócuos enquanto email não é setado.
  4. **`valid_password?` NÃO foi sobrescrito:** valida `encrypted_password` local, que para usuários com `cpf` não pode ser fonte de verdade — mas como o login passa por `user.authenticate` (custom) até a 23.6, a rota atual não usa `valid_password?`. Decisão mínima; o roteamento Pessoas2 em `find_for_database_authentication`/`valid_password?` fica para a task 23.6 (com testes), como previsto na task.
  5. **Gem/versão:** `devise ~> 5.0` (5.0.4), a mesma do basic8 (app de referência do merge, Rails 8.1). Já estava no bundle como dependência transitiva do `sticapi_client` (`devise >= 4.3`) — a promoção a dependência direta não baixou nada novo. Devise 4.9 (sugestão da task) não foi usado porque o próprio projeto de referência usa 5.0.4 com Rails 8.
  6. **Débito técnico 23.1 (ip `string` vs `inet`):** mantido como decidido na 23.1 — o Devise 5 aceita `string` sem problema (`to_s` interno). Sem ação nesta task.
  - **Verificação Pessoas2 aplicada:** (a) cpf + registro Pessoas2 autentica com bcrypt real (teste 21.5 + novo teste provando que encrypted_password local gravada NÃO vira porta alternativa); (b) cpf sem registro → false (teste 21.5); (c) sem cpf → autentica via `super`/`password_digest` (testes novos + 23.1); (d) usuário inativo → bloqueado no CONTROLLER (`status == 1`, intocado) — teste novo em `sessions_controller_test.rb` documenta o contrato.

#### Tarefa 23.4 — Configurar `Rolify` no model `User`
- User Story: Como dev, quero gerenciar roles (admin/gestor/operador) via Rolify para suportar autorização baseada em papéis com CanCanCan
- Rastreabilidade: Roles
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 23.2 (migration `roles` + `users_roles`)
- Critérios de aceite:
  - [x] Gem `rolify` (~> 6.0) adicionada ao Gemfile
  - [x] `bundle install` limpo (rolify 6.0.1 instalado)
  - [x] `Role` model atualizado com `scopify` ( scopes `global`, `class_scoped`, `instance_scoped` ativos)
  - [x] `User` model com `rolify` (primeira linha da classe) — `has_role?`, `add_role`, `remove_role`, `with_role` funcionando
  - [x] `has_secure_password` e `authenticate` custom (Pessoas2) preservados intactos
  - [x] Devise modules intactos (validatable, trackable, etc.)
  - [x] Seeds idempotent com 3 roles padrão (admin, gestor, operador)
  - [x] Role `admin` atribuída ao usuário admin existente nos seeds
  - [x] `admin?` (coluna booleana) preservada — convive com roles durante a transição
  - [x] Validação `resource_type` NÃO adicionada (decisão documentada — roles globais apenas)
  - [x] Testes novos: Role (scopify, scopes, HABTM, polymorphic, destruição) — 17 casos
  - [x] Testes novos: User (rolify methods, add_role, has_role?, remove_role, with_role, coexistência) — 14 novos (45 total)
  - [x] `rails zeitwerk:check` OK
  - [x] `rubocop` nos arquivos alterados limpo (offenses preexistentes preservadas)
  - [x] Suíte existente sem regressão (618 testes, 1709 asserts, 1 falha pré-existente timezone, 0 erros)
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-10 | Gem `rolify` (`~> 6.0`, versão 6.0.1) adicionada ao Gemfile | Dependência necessária para autorização baseada em roles |
  | 2026-09-10 | `bundle install` | rolify 6.0.1 instalado, 21 deps diretas, 118 gems |
  | 2026-09-10 | Model `Role` (`app/models/role.rb`) atualizado | `scopify` habilitado (global, class_scoped, instance_scoped); validação `resource_type` deliberadamente omitida |
  | 2026-09-10 | Model `User` (`app/models/user.rb`) atualizado | `rolify` adicionado como 1ª linha da classe (antes de `has_secure_password` e Devise) |
  | 2026-09-10 | `rails zeitwerk:check` | "All is good!" |
  | 2026-09-10 | Fixture `test/fixtures/roles.yml` criado (admin, gestor, operador) | Fixtures prontas para testes |
  | 2026-09-10 | Teste `test/models/role_test.rb` atualizado (17 casos) | 17/17, 47 asserts — scopify, scopes, HABTM, polymorphic, destruição |
  | 2026-09-10 | Teste `test/models/user_test.rb` atualizado (14 novos, 45 total) | 45/45, 106 asserts — rolify methods, roles CRUD, coexistência com auth |
  | 2026-09-10 | Seeds `db/seeds.rb` atualizado (roles + atribuição admin) | 3 roles idempotent + role admin atribuída ao user admin |
  | 2026-09-10 | `rubocop` nos arquivos alterados | Limpo (offenses preexistentes de seeds preservadas) |
  | 2026-09-10 | Suíte completa: `bin/rails test` | 618 testes, 1709 asserts, 1 falha pré-existente (timezone), 0 erros, 0 regressões |

  **Nota técnica:** A instalação da gem `rolify` 6.0.1 (compatível com Rails 8.0.5) habilita a stack completa de autorização no model `User`:
  - **`rolify` no User:** inclui o módulo `Rolify::Role` no model, adicionando os métodos de instância `has_role?`, `add_role`, `remove_role`, `has_all_roles?`, `has_any_role?` e a associação `has_many :roles` (via HABTM com join table `users_roles`). Posicionado antes de `has_secure_password` para evitar conflitos na cadeia de ancestrais com módulos Devise/BCrypt.
  - **`scopify` no Role:** extende o model `Role` com `Rolify::Adapter::Scopes` (ActiveRecord), habilitando os scopes `global` (roles sem resource), `class_scoped` (roles com resource_type sem resource_id) e `instance_scoped` (roles com resource_type E resource_id). O Frequencia usa exclusivamente roles globais (admin/gestor/operador sem resource).
  - **Validação `resource_type` OMITIDA deliberadamente:** O basic8 referencia inclui `validates :resource_type, inclusion: { in: Rolify.resource_types }, allow_nil: true`, mas o Frequencia NÃO fará `user.add_role(:admin, SomeModel)` (roles por resource) — todas as roles são globais. Sem a validação: roles globais (`resource_type: nil`) funcionam sem restrição; `scopify` não depende dessa validação; evita-se configurar `Rolify.resource_types` (que para roles puramente globais seria sempre irrelevante). Se no futuro o projeto precisar de roles por resource, a validação pode ser adicionada com um ADR.
  - **`admin?` (coluna booleana) PRESERVADA:** a coluna `admin` do model User e o método `admin?` (boolean) continuam ativos — `Admin::ApplicationController#require_admin` e as views dependem disso. As roles Rolify convivem com `admin?` durante a transição; a migração completa para CanCanCan+Rolify fica para as tasks 23.7/23.10.
  - **`add_role` é idempotente:** o método verifica `roles.include?(role)` antes de gravar na join table — chamar `add_role(:admin)` duas vezes não duplica nem lança exceção.
  - **Testes de regressão:** todos os testes de autenticação (Pessoas2 via CPF, local via `has_secure_password`, Devise modules) continuam verdes. A coexistência `rolify` × `has_secure_password` × `devise` × `authenticate` custom foi validada explicitamente em 3 testes novos.

#### Tarefa 23.5 — Criar `app/models/ability.rb` (CanCanCan)
- User Story: Como dev, quero um model Ability (CanCanCan) que mapeie permissões por role (admin/gestor/operador) para autorizar ações nos controllers na task 23.7
- Rastreabilidade: Auth
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 23.4 (roles Rolify + fixtures `roles.yml`)
- Critérios de aceite:
  - [x] Gem `cancancan` (~> 3.6) adicionada ao Gemfile e `bundle install` limpo (cancancan 3.6.1, mesma versão do basic8, compatível com Rails 8.0.x)
  - [x] `app/models/ability.rb` criado com `include CanCan::Ability` e `initialize(user)` com fallback `user ||= User.new`
  - [x] Guest (`User.new` sem id) não acessa nada (early return `unless user.id`)
  - [x] `:admin` → `can :manage, :all` via role Rolify E/OU coluna booleana `admin?` (transição documentada)
  - [x] `:gestor` → `can :read, :all` + `can :manage` em `TimeRecord` e `IntervencaoFrequencia` (escopo por geridos documentado como evolução futura)
  - [x] `:operador` → `can :read, :all` (somente leitura)
  - [x] Usuário sem role e sem `admin?` não recebe permissão alguma
  - [x] `Admin::ApplicationController#require_admin` NÃO alterado (integração fica para 23.7)
  - [x] NENHUM controller/route/view alterado — apenas o model Ability
  - [x] Nenhum arquivo `app/models/pessoas/*.rb` tocado
  - [x] Teste `test/models/ability_test.rb` criado com matriz de permissões (guest, sem role, admin via role, admin via boolean, admin via ambos, gestor, operador) — 13 casos, 80 asserts
  - [x] `rails zeitwerk:check` OK ("All is good!")
  - [x] `rubocop` nos arquivos alterados limpo
  - [x] Suíte existente sem regressão (631 testes, 1789 asserts, 1 falha pré-existente timezone, 0 erros)
  - [x] Autenticação Pessoas2/local preservada (regressão `user_test.rb`/`sessions_controller_test.rb` verde)
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-10 | Branch `feat/cancancan-ability` criada a partir de `feat/devise-no-user` (HEAD, convenção de branches encadeadas — work in progress 23.1-23.4 preservado no working tree) | Branch pronta |
  | 2026-09-10 | Gem `cancancan` (`~> 3.6`, versão 3.6.1) adicionada ao Gemfile — mesma versão do basic8 (app de referência, Rails 8.1) | `bundle install` limpo, 22 deps diretas, 119 gems |
  | 2026-09-10 | `app/models/ability.rb` criado | Matriz por role implementada (ver Nota técnica) |
  | 2026-09-10 | `test/models/ability_test.rb` criado (13 casos, 80 asserts) | 13/13 verde — matriz guest/admin/gestor/operador/sem role |
  | 2026-09-10 | `rails zeitwerk:check` | "All is good!" |
  | 2026-09-10 | Suíte completa: `bin/rails test` | 631 testes (618 + 13 novos), 1789 asserts, 1 falha pré-existente (timezone), 0 erros, 0 regressões |
  | 2026-09-10 | RuboCop em `app/models/ability.rb` + `test/models/ability_test.rb` | Limpo (2 offenses de final newline autocorrigidos) |

  **Nota técnica:**
  - **Gem/versão:** `cancancan ~> 3.6` (3.6.1) — a mesma versão resolvida pelo basic8 (Gemfile sem constraint, Rails 8.1.3 → cancancan 3.6.1). Compatível com Rails 8.0.x; não existe versão 4.x estável no momento da task (rubygems lista 3.6.1 como latest). Instalação justificada: CanCanCan é o framework de autorização declarativa necessário para mapear permissões por role e integrar nos controllers na task 23.7.
  - **Decisão — convivência `admin?` booleano × roles Rolify:** o Ability considera admin quem é admin PELA COLUNA boolean (`user.admin?`) OU PELA ROLE (`user.has_role?(:admin)`). Dupla fonte de verdade proposital durante a transição: (a) contas legacy com `admin = true` continuam autorizadas sem depender de role; (b) contas novas com role admin funcionam antes da migração da coluna. `Admin::ApplicationController#require_admin` (só `admin?`) NÃO foi tocado — a integração é escopo da task 23.7.
  - **Matriz de permissões do gestor:** `can :read, :all` (consulta de todas as telas — cadastrais, relatórios, frequência) + `can :manage, TimeRecord` e `can :manage, IntervencaoFrequencia` (batida manual, errata, desconsideração/reconsideração, horas extras, prédio). O escopo por frequentadores gerenciados (`GestorIndividual`/`GestorIndividualGerenciado`) NÃO foi implementado: o model `GestorIndividual` identifica o gestor por vínculo no Pessoas (não por login local), então o vínculo gestor→geridos não é resolvível de forma confiável nesta task — decisão documentada no próprio `ability.rb` e registrada como evolução futura (task 23.7 pode revisitar ao integrar).
  - **Escopo preservado por design:** NENHUM controller/route/view alterado; SEM `check_authorization`, `load_and_authorize_resource` nem `rescue_from` (integração na 23.7). Models `Pessoas::*` não foram tocados — a leitura deles via `can :read, :all` é inócua (projeções readonly por `PessoasRecord#readonly?`).
  - **Testes:** `test/models/ability_test.rb` valida a matriz completa (guest sem nada; sem role sem nada; admin via role, via boolean e via ambos; gestor lê tudo + gerencia TimeRecord/IntervencaoFrequencia mas NÃO User/Role/EstacaoPonto; operador read-only em tudo), incluindo matriz consolidada parametrizada e regressão de coexistência com `authenticate` (Pessoas2/local intacto).

#### Tarefa 23.6 — Configurar Devise routes + controllers
- User Story: Como dev, quero que o login admin funcione via Devise routes (mantendo `/login`/`/logout` compatíveis) para autenticar por `username` com senha local OU Pessoas2 (via cpf), bloqueando inativos
- Rastreabilidade: Auth
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 23.3 (Devise no model + initializer), 23.1 (colunas Devise)
- Critérios de aceite:
  - [x] `devise_for :users` em `config/routes.rb` com `path: "u"` e `skip: :registrations` (cadastro vem do Pessoas2, não auto-registro)
  - [x] Rotas `login`/`logout` admin preservadas: `login_path` → GET/POST `/login` (Admin::SessionsController), `logout_path` → DELETE `/logout` (Users::SessionsController — Devise), todas as referências em testes/views continuam válidas
  - [x] Controller `Users::SessionsController` criado (custom Devise): REUSA a view `admin/sessions/new` + layout `login`, redireciona para `dashboard_path` após login e `login_path` após logout, sincroniza `session[:user_id]` para o contexto admin (Admin::ApplicationController)
  - [x] `config.authentication_keys = [:username]` no initializer (login por username, não email) + `case_insensitive_keys`/`strip_whitespace_keys` com `:username`
  - [x] `config.parent_controller = "ApplicationController"` (API-only com módulos view/flash/CSRF) + `navigational_formats` com `:html`
  - [x] `User.find_for_database_authentication` sobrescrito — busca por `username` (lower, case-insensitive)
  - [x] `User#valid_password?` sobrescrito — usuário com `cpf` valida contra hash bcrypt do Pessoas2 (`Pessoas::User.buscar_por_cpf`), sem `cpf` usa `super` (encrypted_password local)
  - [x] `User#active_for_authentication?` sobrescrito — `status != 1` bloqueado (contrato do Admin::SessionsController preservado)
  - [x] `Admin::SessionsController` preservado e funcional (login legado com `User#authenticate` custom intocado — controllers presenca/outros continuam dependendo)
  - [x] Registrations DESABILITADAS via `skip: %i[registrations]` no `devise_for` (auto-cadastro fora do escopo)
  - [x] Locale `devise.pt-BR.yml` ajustado: mensagens de falha passam a dizer "Username ou senha inválidos" (auth key do projeto)
  - [x] Testes novos: `test/controllers/users/sessions_controller_test.rb` (7 casos) — login via rota Devise com session[:user_id], username (não email), Pessoas2 via cpf com senha real, senha errada Pessoas2 rejeitada (recall com alert), inativo bloqueado (redirect), logout Devise, logout legado `/logout` após login admin
  - [x] Testes novos em `test/models/user_test.rb` (6 casos) — find_for_database_authentication (username, case-insensitive, ignora email), valid_password? (Pessoas2, cpf órfão, local), active_for_authentication? (status)
  - [x] `rails zeitwerk:check` OK ("All is good!")
  - [x] `rubocop` limpo nos arquivos novos/alterados (offenses preexistentes de routes.rb preservadas)
  - [x] `bin/rails test` completo sem regressão (644 testes, 1833 asserts, 1 falha pré-existente de timezone, 0 erros)
  - [x] `bin/rails routes | grep devise` — rotas Devise existem em /u/sign_in, /u/sign_out, /u/password
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-10 | Branch `feat/devise-routes-controllers` criada a partir de `feat/cancancan-ability` (HEAD) | Branch pronta |
  | 2026-09-10 | `config/routes.rb`: `devise_for :users, path: "u", skip: registrations, controllers: sessions = users/sessions` + `devise_scope :user { delete "logout" }`; rota logout do scope admin removida | Rotas Devise em /u/*; `logout_path` → Users::SessionsController#destroy; `login_path` inalterado |
  | 2026-09-10 | `app/controllers/users/sessions_controller.rb` criado (custom Devise) | REUSA `admin/sessions/new` + layout login; `session[:user_id]` sincronizado; after_sign_in → dashboard; after_sign_out → login; `skip_before_action :verify_signed_out_user` (logout legado) |
  | 2026-09-10 | `config/initializers/devise.rb`: authentication_keys = [:username], case_insensitive/strip com :username, parent_controller = ApplicationController, navigational_formats com :html | Devise configurado p/ o Frequencia (API-only + UI admin) |
  | 2026-09-10 | `app/models/user.rb`: `find_for_database_authentication` (username), `valid_password?` (Pessoas2 via cpf), `active_for_authentication?` (status == 1) | Roteamento Devise completo; `authenticate` custom e has_secure_password INTOCADOS |
  | 2026-09-10 | `config/locales/devise.pt-BR.yml`: mensagens de falha "Username ou senha inválidos" | I18n pt-BR alinhado à auth key do projeto |
  | 2026-09-10 | `test/controllers/users/sessions_controller_test.rb` criado (7 casos) + 6 casos novos em `test/models/user_test.rb` | 13 casos novos verdes |
  | 2026-09-10 | `rails zeitwerk:check` | "All is good!" |
  | 2026-09-10 | `rails routes \| grep devise` | Rotas Devise em /u/sign_in, /u/sign_out, /u/password OK |
  | 2026-09-10 | Suíte completa: `bin/rails test` | 644 testes (631 + 13 novos), 1833 asserts, 1 falha pré-existente (timezone), 0 erros, 0 regressões |
  | 2026-09-10 | RuboCop nos arquivos alterados | Limpo (offenses preexistentes de routes.rb preservadas) |

  **Nota técnica:**

  **Decisão de roteamento (mínima e segura):** `devise_for :users, path: "u", skip: %i[registrations], controllers: { sessions: "users/sessions" }` — as rotas Devise ficam em `/u/sign_in` (GET/POST), `/u/sign_out` (DELETE) e `/u/password/*` (recoverable), como no basic8. O fluxo admin (`/login` GET/POST → `Admin::SessionsController`) foi **preservado intocado** (login legado com `User#authenticate` custom, que continua sendo a fonte de verdade). A rota `logout` foi removida do scope admin e passou a apontar para `Users::SessionsController#destroy` (Devise) — `logout_path` continua válido em todos os testes/views. Retrocompatibilidade total: `login_path`, `logout_path`, `dashboard_path` inalterados. Registrations `skip` — cadastro de usuários vem do Pessoas2, não há auto-registro (decisão da task; se um dia houver fluxo de cadastro, será por `Users::RegistrationsController` custom ou seeds).

  **Auth keys (username, não email):** `config.authentication_keys = [:username]` no initializer (com `case_insensitive_keys`/`strip_whitespace_keys` incluindo `:username`). O login do Frequencia sempre foi por `username`; o Devise passa a usar a mesma chave. `find_for_database_authentication` no model busca `where(conditions).find_by("lower(username) = ?", username.to_s.downcase)` — case-insensitive como os outros auth keys.

  **Roteamento Pessoas2 (adiado da 23.3):** `valid_password?` foi sobrescrito no model User: usuário com `cpf` → valida contra `Pessoas::User.buscar_por_cpf(cpf).encrypted_password` (bcrypt do pessoas2, mesma fonte de verdade do `authenticate` custom); sem `cpf` → `super` (encrypted_password local, gravada pelo dual-write da 23.3). `find_for_database_authentication` localiza o User por username; o `valid_password?` decide a origem da senha. Fluxo manual `user.authenticate` continua intocado (controllers presenca e legados dependem).

  **Usuário inativo (status):** `active_for_authentication?` retorna `super && status == 1`. No fluxo Devise, o Warden `after_set_user` hook detecta o retorno false, descarta o usuário e redireciona para `/u/sign_in` com alert "Sua conta ainda não foi ativada." — mesmo contrato do antigo `user.status == 1` no `Admin::SessionsController#create` (que permanece no controller legado).

  **Controller custom + logs de transição:** `Users::SessionsController` (Devise) sincroniza `session[:user_id]` no `create` (via `super` com bloco) — sem isso, o `Admin::ApplicationController#current_user` não reconheceria o login feito pelo Warden (fonte de verdade do contexto admin é `session[:user_id]`). `skip_before_action :verify_signed_out_user` no destroy é obrigatório para o logout funcionar quando o login foi feito pelo fluxo legado (Warden vazio) — o `verify_signed_out_user` do Devise abortaria antes de limpar `session[:user_id]`. `after_sign_in_path_for` → `dashboard_path`; `after_sign_out_path_for` → `login_path`. A view NÃO foi criada (task 23.8): o `new` REUSA `admin/sessions/new` com layout `login` (mesma tela); o recall de falha de senha renderiza essa mesma view com o alert do Devise (status `unprocessable_content` via `responder.error_status`).

  **Débito técnico conhecido:** `rememberable` continua no model mas não há checkbox na view admin — cookie de remember só seria emitido se o param `user[remember_me]` fosse enviado (fluxo hoje não expõe). Reavaliar na 23.8/23.10 se necessário.

#### Tarefa 23.7 — Integrar CanCanCan em controllers
- User Story: Como dev, quero que todos os controllers admin autorizem ações via CanCanCan (Ability por role — admin/gestor/operador) para que nenhum perfil execute ação fora da matriz de permissões (RN05/RN06), mantendo a esteira controller → CanCan → action com testes de integração por perfil
- Rastreabilidade: Auth
- Critérios de aceite:
  - [x] Todos os 15 controllers admin com integração CanCanCan (commit da Sprint 23): `include CanCan::ControllerAdditions`, `check_authorization` e `rescue_from CanCan::AccessDenied` (redirect dashboard + alert pt-BR) no `Admin::ApplicationController`; `authorize!` explícito nas telas de leitura/agregação (dashboard, frequencia, gestores_individuais, parcial, relatorio_terceirizados, time_records, estacoes index, regimes index, versoes index, users index, etc.) e nas ações de manutenção (`:manage, AfastamentoCache` em sincronizar, `:manage, User` em reimportar/importar_unidade)
  - [x] CRUD puros (estacoes/regimes/versoes) convertidos para `load_and_authorize_resource` (padrão do Admin::UsersController da 23.7): remove `before_action :set_*`, loader constrói/carrega/autoriza `@estacao`/`@regime`/`@versao`, `except: [:index]` (index mantém `authorize! :read, :all` + query customizada) — mesmo padrão do UsersController com `class: EstacaoPonto` (ver nota técnica)
  - [x] `Admin::SessionsController#new/create` com `skip_authorization_check` (login não pode exigir ability — justificado no controller); `skip_before_action :require_login` restrito a new/create
  - [x] Testes de matriz de autorização por CONTROLLER: `test/controllers/admin/authorization_matrix_test.rb` (6 casos, 139 asserts) — guest (redirect login em leitura e escrita, zero registros criados), admin via role Rolify (coluna `admin` false; CRUD estacao/regime/versao + sincronizar enfileira job), gestor (lê dashboard/estacoes/regimes/versoes/frequencia/time_records/gestores_individuais/parcial/relatorio_terceirizados/users; nega create/update estacao, update regime, create versao, update User, sincronizar), operador (lê + não edita estação + não abre form), autenticado sem role (baseline de leitura 23.7 + escrita negada) e `current_ability` (Ability derivada do `current_user` de sessão — contexto API-only, sem Warden)
  - [x] `ParcialController` e `RelatorioTerceirizadosController` cobertos pela matriz (não tinham teste próprio)
  - [x] Padrões preservados: usuários criados inline (username via callback), stubs de `Pessoas::Vinculo.frequentadores_ativos` (banco pessoas_test sem schema — task 8.13), fixtures intocadas
  - [x] `rails zeitwerk:check` OK ("All is good!")
  - [x] `rubocop` limpo nos arquivos novos/alterados (4 offenses autocorrigidas; ofensas pré-existentes do users_controller_commit não tocadas)
  - [x] `bin/rails test` completo SEM regressão (675 testes, 2067 asserts, 1 falha pré-existente de timezone, 0 erros — baseline 669/1928/1 + 6 testes/139 asserts novos)
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-21 | Branch `feat/cancancan-controller-integration` verificada (23.7 presente, merge pendente); baseline `bin/rails test` | 669 testes, 1928 asserts, 1 falha pré-existente (timezone), 0 erros |
  | 2026-09-21 | `Admin::EstacoesController`, `Admin::RegimesController`, `Admin::VersoesController`: `load_and_authorize_resource` (`except: [:index]`), remoção de `before_action :set_*`/`authorize! :manage`/`X.new` por ação | CRUD puro autorizado pelo loader (padrão UsersController) |
  | 2026-09-21 | Corrigido pitfall do loader: `load_and_authorize_resource :estacao` exigiu `class: EstacaoPonto` (nome `:estacao` → camelize `Estacao`, model real é `EstacaoPonto`) | NameError eliminado; `@estacao` preservado p/ views |
  | 2026-09-21 | `test/controllers/admin/authorization_matrix_test.rb` criado (6 casos: guest/admin-role/gestor/operador/sem-role/current_ability) | 139 asserts verdes |
  | 2026-09-21 | Suíte completa + zeitwerk + rubocop | 675 testes/2067 asserts, 1 falha pré-existente; "All is good!"; rubocop limpo |
  | 2026-09-21 | `docs/progress/iteration_23.md` atualizado (esta seção); merge da 23.7 segue pendente (pré-condição da 24.3) | Rastreabilidade 23.7 concluída |

  **Nota técnica:**

  **Padrão CanCanCan por tipo de controller:** (1) telas de leitura/agregação (`authorize! :read, :all`) — dashboard, frequencia, frequencia_por_orgao, gestores_individuais, parcial, relatorio_terceirizados, time_records e as index dos CRUD (que usam query customizada, sem `accessible_by`); (2) ações de manutenção com sujeito explícito — `:manage, AfastamentoCache` (sincronizar afastamentos) e `:manage, User` (reimportar/importar_unidade frequentadores); (3) CRUD puro com `load_and_authorize_resource` (UsersController + estacoes/regimes/versoes nesta task) — o loader constrói (new/create via strong params, `estacao_params` etc.), carrega (edit/update/destroy via `params[:id]`) e autoriza (`:new`/`:create`/`:edit`/`:update`/`:destroy`) na instância, negando via `CanCan::AccessDenied` → redirect dashboard. `Admin::SessionsController` usa `skip_authorization_check` (login não pode exigir ability — decisão já documentada no controller).

  **Pitfall do `class:` no loader (lição):** `load_and_authorize_resource :estacao` faria o CanCan derivar a classe `"estacao".camelize.constantize` → `Estacao` — que não existe (model real é `EstacaoPonto`, tabela `estacoes_ponto`). A opção `class: EstacaoPonto` resolve mantendo `@estacao` na instância (views/actions intactas). regimes (`Regime`) e versoes (`Versao`) não precisam por ter nome de model idêntico ao camelize do resource name.

  **Matriz por perfil (ability.rb 23.5 intocado):** guest = nada (`require_login`); autenticado sem role = baseline de leitura 23.7 (`can :read, :all`); operador = leitura + escrita negada; gestor = leitura de todas as telas + manage em TimeRecord/IntervencaoFrequencia (escopo por gestores gerenciados = evolução futura, ver 23.5) — CREATE/UPDATE de EstacaoPonto/Regime/Versao, UPDATE de User e sincronizar afastamentos negados (RN05/RN06); admin = via role Rolify OU coluna `admin?` (dupla fonte de verdade da transição) — manage total. A suíte de integração valida a esteira completa (router → before_action → CanCan → action) e o `current_ability` derivado do `current_user` de sessão (contexto API-only, sem Warden).

#### Tarefa 23.8 — Criar views Devise
- User Story: Como usuário do painel, quero telas de login e de recuperação de senha no padrão visual AdminLTE do TJPI (I18n pt-BR), para autenticar pelo Devise (`/u/sign_in`) e recuperar acesso (`/u/password/*`) sem depender da view legada do login admin
- Rastreabilidade: Auth
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 23.3 (Devise no model + initializer), 23.6 (rotas/controllers Devise)
- Critérios de aceite:
  - [x] Views Devise dedicadas em `app/views/users/`: `sessions/new` (login, refatorada) + `passwords/new` + `passwords/edit` (criadas)
  - [x] `Users::PasswordsController` custom (`layout "login"`) registrado em `devise_for` (`controllers: { passwords: "users/passwords" }`) — views resolvidas pelo controller path, sem depender de `config.scoped_views`
  - [x] Layout `login` aplicado às telas Devise (mesma identidade visual AdminLTE 4 do login legado)
  - [x] Partial compartilhado `users/shared/_card_header` (header do card) — evita duplicação entre as 3 views
  - [x] Partials `users/shared/_links` (navegação recoverable/sessions) e `users/shared/_error_messages` (erros de resource)
  - [x] I18n pt-BR estrito: labels/títulos/mensagens via `t("devise.*")`; `devise.pt-BR.yml` completado (`sessions.new`, `passwords.new`, `passwords.edit`, `links`, `shared.minimum_password_length`)
  - [x] Login legado `Admin::SessionsController` + view `admin/sessions/new` (GET/POST `/login`) intactos
  - [x] Registrations NÃO criadas (skip no `devise_for`)
  - [x] Débito 23.6 resolvido: checkbox `remember_me` (rememberable) exposto no form Devise novo
  - [x] Link "Esqueceu sua senha?" no login → `/u/password/new` (recoverable)
  - [x] Testes: `test/controllers/users/passwords_controller_test.rb` (5 casos: render new/edit, POST email desconhecido/conhecido com envio mockado, PATCH token inválido) + 1 caso novo e 1 assert de recall na `sessions_controller_test.rb`
  - [x] `rails zeitwerk:check` OK ("All is good!")
  - [x] `rubocop` limpo nos arquivos novos/alterados (offenses pré-existentes de `routes.rb` preservadas)
  - [x] Suíte completa sem regressão: **681 runs / 2118 asserts / 1 falha pré-existente de timezone / 0 erros** (baseline 675/2067/1)
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-21 | Implementação sobre o branch `feat/cancancan-controller-integration` (decisão do dev — sem nova branch, sem merge, sem push; `COMMIT_MODE=manual`) | Escopo 23.8 no working tree |
  | 2026-09-21 | `app/controllers/users/passwords_controller.rb` criado (`Devise::PasswordsController` + `layout "login"`); `devise_for` recebe `passwords: "users/passwords"` | `/u/password/*` → `users/passwords#*`; views em `app/views/users/passwords/` |
  | 2026-09-21 | Partial `users/shared/_card_header` + `_error_messages` + `_links` criados | Base visual/navegação compartilhada das telas Devise |
  | 2026-09-21 | `users/passwords/new` e `users/passwords/edit` criados (form Devise, error_messages, links, hint de senha mínima) | Telas recoverable no padrão AdminLTE/login |
  | 2026-09-21 | `users/sessions/new` refatorada: textos via I18n, `card_header`, link "Esqueceu sua senha?", checkbox remember_me mantido | Login Devise com I18n pt-BR estrito |
  | 2026-09-21 | `config/locales/devise.pt-BR.yml` completado com chaves de views (padrão canônico devise-i18n) | Nenhum texto hardcoded nas views novas |
  | 2026-09-21 | `test/controllers/users/passwords_controller_test.rb` criado (5 casos) + `sessions_controller_test.rb` com GET da view nova e assert de recall | 13 runs / 82 asserts verdes na pasta `users/` |
  | 2026-09-21 | Suíte completa + `zeitwerk:check` + rubocop | 681 testes/2118 asserts, 1 falha pré-existente (timezone); "All is good!"; rubocop limpo |
  | 2026-09-21 | `docs/progress/iteration_23.md` atualizado (esta seção) | Rastreabilidade 23.8 concluída |

  **Nota técnica:**

  **Controller custom × `scoped_views`:** as views de passwords ficam em `app/views/users/passwords/` porque criamos `Users::PasswordsController < Devise::PasswordsController` e o registramos em `devise_for` — o render implícito/`respond_with` resolve pelo controller path (`users/passwords`). A alternativa (`config.scoped_views = true`) mudaria o lookup de views Devise GLOBALMENTE (todas as scopes/módulos) e ainda exigiria override de layout; o controller custom é explícito, isolado e espelha o padrão já adotado em `Users::SessionsController` (task 23.6). O `layout "login"` no controller garante o card sem sidebar — sem ele, o `DeviseController` herdaria o layout administrativo (`application.html.erb`).

  **Reaproveitamento sem tocar o legado:** o login legado (`Admin::SessionsController` → `admin/sessions/new`, `form_tag login_path`) foi mantido 100% intacto. Os dois forms têm naturezas diferentes (legado = `form_tag` sem resource; Devise = `form_for(resource, url: session_path)` com `remember_me`), então NÃO foi criado partial de form compartilhado — extrair um form comum exigiria refatorar o legado além do necessário (contra a diretriz da tarefa). O que foi compartilhado entre as telas Devise são os partials visuais `users/shared/_card_header`, `_error_messages` e `_links`.

  **Recuperação de senha — chave e e-mail:** o recoverable usa o default do Devise (`reset_password_keys = [:email]`), inalterado nesta task. O envio real do e-mail de instruções depende de **ActionMailer, que NÃO está montado** (`config/application.rb` não requer `action_mailer/railtie`) — o fluxo visual, a geração/validação de token e a redefinição por `reset_password_by_token` funcionam; apenas o disparo do e-mail falharia (o `create` com e-mail encontrado chama `Devise::Mailer`). Nos testes esse envio é **mockado** (`User.send_reset_password_instructions` via `define_singleton_method`, mesmo padrão de stub de `Pessoas::User.buscar_por_cpf` da 23.6). Habilitar ActionMailer + mailer Devise fica como débito para a task 23.10/evolução do recoverable.

  **Escopo preservado:** nenhum arquivo não relacionado tocado; os controllers da 23.7 (`estacoes`/`regimes`/`versoes`) e o `authorization_matrix_test` que já estavam no working tree não foram alterados por esta task. Nenhuma migration/seeds/auth/ability alterados. `password_digest` e `authenticate` custom (Pessoas2) intocados.

#### Tarefa 23.9 — Migrar seeds existentes
- User Story: Como dev, quero que os seeds gerem um ambiente coeso no novo modelo de auth/autorização (Devise + CanCanCan + Rolify), mantendo idempotência e respeitando o banco já existente, para que admin/gestor/operador tenham as roles e credenciais corretas sem migrations
- Rastreabilidade: Roles
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 23.4 (roles + seeds de roles), 23.5 (Ability), 23.6 (Devise routes/valid_password?)
- Critérios de aceite:
  - [x] Seeds idempotentes: segunda execução não cria usuários, roles nem batidas
  - [x] Conta admin canônica localizada por `username` estável (`admin.admin`), não por `nome_completo` — corrige a criação de duplicata (`admin.admin.2`) e garante a role `admin` ao admin REAL
  - [x] Admin com role Rolify `:admin` **e** coluna boolean `admin = true` (views/controllers ainda usam `current_user.admin?`)
  - [x] Contas de demonstração `gestor.demo`/`operador.demo` com as roles `:gestor`/`:operador` (e `admin = false`)
  - [x] Credencial Devise (`encrypted_password`) via dual-write (task 23.3) para as contas seedadas — autenticam por Devise (`valid_password?`) E localmente (`authenticate`)
  - [x] Backfill conservador de `encrypted_password` apenas quando ausente (nunca sobrescreve credencial Devise válida)
  - [x] Seeds tocam SOMENTE o banco local; base Pessoas2 (somente-leitura) não é escrita — nenhuma conta seedada tem `cpf`
  - [x] `status` mantido como fonte de verdade de "ativo" (decisão confirmada: NÃO migrar para `confirmed_at`; módulo `:confirmable` ausente)
  - [x] Nenhuma migration criada; `db/seeds.rb` atual não quebrado (contas/batidas de demonstração preservadas)
  - [x] Teste `test/lib/seeds_test.rb` criado (8 casos, 31 asserts) — idempotência, admin canônico, não-duplicação, não-sobrescrita de senha, backfill de conta legada, roles demo, credencial dual-write, ausência de cpf
  - [x] `rails zeitwerk:check` OK ("All is good!")
  - [x] `rubocop` limpo nos arquivos novos/alterados (12 offenses pré-existentes do seeds eliminadas na reescrita)
  - [x] Suíte completa sem regressão: **689 runs / 2149 asserts / 1 falha pré-existente de timezone / 0 erros** (baseline 681/2118/1)
  - [x] Validação no ambiente real (dev): 2 execuções de `db:seed` — 2ª sem alterações; admin id=1 (role + coluna + credencial) e gestor/operador demo coesos
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-21 | Implementação sobre o branch `feat/cancancan-controller-integration` (decisão do dev — sem nova branch, sem merge, sem push; `COMMIT_MODE=manual`) | Escopo 23.9 no working tree |
  | 2026-09-21 | Diagnóstico do ambiente dev: admin id=1 (`admin.admin`, `admin=true`) sem role e sem `encrypted_password`; duplicata `admin.admin.2` criada pelo seed antigo; 77/82 usuários sem credencial Devise; roles sem gestor/operador atribuídos | Descasamentos mapeados |
  | 2026-09-21 | `db/seeds.rb` reescrito: localização por `username`, helper `seed_user` (lambda) com dual-write/backfill conservador, contas gestor/operador demo, roles idempotentes, comentários das decisões (admin duplo, Pessoas2 local-only, `status`) | Seeds migrados, RuboCop limpo (12 offenses pré-existentes eliminadas) |
  | 2026-09-21 | `test/lib/seeds_test.rb` criado (8 casos, 31 asserts), com `capture_io` para silenciar `puts` | 8/8 verde |
  | 2026-09-21 | `bin/rails db:seed` em dev, 2 execuções | Idempotente; admin id=1 com role+coluna+Devise; gestor/operador demo criados |
  | 2026-09-21 | Suíte completa + `zeitwerk:check` + rubocop | 689 testes/2149 asserts, 1 falha pré-existente (timezone); "All is good!"; rubocop limpo |
  | 2026-09-21 | `docs/progress/iteration_23.md` atualizado (esta seção) | Rastreabilidade 23.9 concluída |

  **Nota técnica:**

  **Bug do seed antigo (corrigido):** o admin era localizado por `find_or_create_by!(nome_completo: "Admin Admin")`, mas o admin legado tem `nome_completo: "Admin"` — o seed criava uma conta NOVA (`admin.admin.2`, porque o username `admin.admin` já existia) e atribuía a role `admin` a essa duplicata, deixando o admin REAL (id=1, `admin=true`) sem role e sem `encrypted_password` (não logava por Devise). A localização agora é pelo `username` estável `admin.admin`; `nome_completo` só é preenchido quando ausente (não renomeia contas existentes). A duplicata legada `admin.admin.2` NÃO é removida pelo seed (não se apaga dado de usuário) — fica registrada como resíduo de ambiente para eventual limpeza manual/decisão.

  **Backfill de credencial Devise (decisão central):** contas locais criadas antes das tasks 23.1/23.3 têm `password_digest` (has_secure_password) mas `encrypted_password` vazio — e bcrypt é unidirecional, então não há como derivar o hash Devise do digest legado. Para as contas SEEDADAS, o helper grava a senha padrão (`123456`, já documentada na tela de login) via dual-write quando `encrypted_password` está vazio — só assim o admin legado volta a autenticar por Devise. O guard `encrypted_password.blank?` garante que uma credencial Devise já existente NUNCA é sobrescrita (testado). Usuários do Pessoas2 (com `cpf`) não são tocados: eles autenticam pelo hash do Pessoas2 (tasks 21.5/23.6) e os seeds não escrevem na base integrante (conexão `pessoas` é SELECT-only).

  **`admin` coluna × role:** a conta admin recebe ambos (`admin = true` + role `:admin`) porque, embora a Ability (23.5) aceite role OU coluna, views/controllers ainda ramificam em `current_user.admin?` (`layouts/admin`, `admin/time_records`, `admin/dashboard`). As contas demo gestor/operador recebem apenas a role (e `admin = false`).

  **Escopo preservado:** nenhuma migration/schema/controller/ability alterado; nenhum arquivo não relacionado tocado (as demais modificações do working tree são das tasks 23.7/23.8). Seeds continuam apenas locais e idempotentes; contas/batidas de demonstração preservadas.

#### Tarefa 23.10 — Testes
- User Story: Como dev, quero fechar a Sprint 23 (auth Devise + CanCanCan + Rolify) com a cobertura da stack consolidada e validada, lacunas reais de teste fechadas e a suíte completa sem regressão, para garantir que a sprint está completa e sem débitos de qualidade invisíveis
- Rastreabilidade: Auth
- Estimativa: 2 pontos | Atribuição: Code Specialist
- Dependências: 23.1–23.9
- Critérios de aceite:
  - [x] Baseline da Sprint 23 validado: **689 runs / 2149 asserts / 1 falha pré-existente de timezone / 0 erros**
  - [x] Falha pré-existente de timezone validada como GÊNUINA e documentada (endpoints legados de presença, fora do escopo Sprint 23 — ver Nota técnica)
  - [x] Lacuna real 1 — Integração Devise×CanCan fechada: login via rota Devise (`/u/sign_in`) de gestor (leitura OK + escrita administrativa negada) e de admin por role Rolify (CRUD autorizado) — 2 testes novos em `test/controllers/users/sessions_controller_test.rb`
  - [x] Lacuna real 2 — Contrato do `rescue_from CanCan::AccessDenied` fechado: assert de `flash[:alert]` presente no redirect para dashboard (antes só o redirect era testado) — `authorization_matrix_test.rb`
  - [x] Cobertura de `valid_password?`/`active_for_authentication?`/`find_for_database_authentication` confirmada (23.6 — `user_test.rb`)
  - [x] Matriz de autorização por perfil confirmada (23.7 — `authorization_matrix_test.rb`, 6 casos) e auditoria de actions `authorize! :manage, User` (reimportar/importar_unidade) confirmada em `frequentadores_controller_test.rb`
  - [x] Decisão coberto vs não coberto documentada (ver Nota técnica) — sem testes "a granel"
  - [x] `bin/rails test` completo verde: **691 runs / 2169 asserts / 1 falha pré-existente de timezone / 0 erros / 0 skips** (baseline 689/2149/1 + 2 testes/20 asserts novos) — SEM novas falhas
  - [x] `rails zeitwerk:check` OK ("All is good!")
  - [x] `rubocop` limpo nos arquivos alterados (2 arquivos de teste, 0 offenses)
  - [x] Nenhum arquivo não relacionado tocado; nenhum controller/model/migration/ability alterado nesta task (apenas testes + doc)
  - [x] Sprint 23 fechada: tasks 23.1–23.10 ✅ no iteration_23.md
- Status: ✅ Concluída

  **Linha do Tempo:**

  | Horário | O que foi feito | Resultado |
  |---------|-----------------|-----------|
  | 2026-09-21 | Implementação sobre o branch `feat/cancancan-controller-integration` (decisão do dev — sem nova branch, sem merge, sem push; `COMMIT_MODE=manual`) | Escopo 23.10 no working tree |
  | 2026-09-21 | Baseline `bin/rails test` confirmado | 689 runs / 2149 asserts / 1 falha pré-existente (timezone) / 0 erros |
  | 2026-09-21 | Falha de timezone investigada (git blame `68112a8` "Ajuste data e hora" + `config.time_zone`) | Genuína e pré-existente — endpoints legados presença; documentada, NÃO corrigida |
  | 2026-09-21 | Auditoria de lacunas: `authorization_matrix_test` (23.7), `users/sessions_controller_test` (23.6), `user_test` (23.6), `frequentadores_controller_test` (23.10-auditoria do commit `2d99706`), per-controller admin | Duas lacunas REAIS identificadas (Devise×CanCan com role; contrato flash do rescue_from) |
  | 2026-09-21 | 2 testes novos em `users/sessions_controller_test.rb` (gestor e admin-role via `/u/sign_in` até CanCan) + 1 assert de flash em `authorization_matrix_test.rb` | 16 runs / 203 asserts verdes nos arquivos alvo |
  | 2026-09-21 | Suíte completa + `zeitwerk:check` + rubocop | **691 testes/2169 asserts**, 1 falha pré-existente (timezone); "All is good!"; rubocop limpo |
  | 2026-09-21 | `docs/progress/iteration_23.md` atualizado (esta seção + header ✅ + riscos) | Sprint 23 fechada (23.1–23.10) |

  **Nota técnica:**

  **Falha pré-existente de timezone — validada GÊNUINA (não corrigida):** a única falha da suíte é `test/integration/presenca_endpoints_test.rb:187` (POST SincronizarRegistrosPonto, contrato "horario" da confirmação visual): o teste espera `"15/07/2026 11:30:45"` e o controller devolve `"15/07/2026 14:30:45"`. Investigação: a expectativa foi introduzida no commit `68112a8` ("Ajuste data e hora", 2026-07-24) junto com a mudança de `config.time_zone = "America/Sao_Paulo"`; o fluxo atual (parse `Time.zone.strptime` local → store UTC → read TimeWithZone → `strftime` local) faz round-trip consistente na hora local. A discrepância vive nos endpoints legados da Estação (Sprint 1/R), NENHUM caminho da Sprint 23 (auth Devise/CanCanCan/Rolify). Corrigir = alterar contrato legacy da Estação ou a expectativa de um teste de Sprints anteriores — fora do escopo e não trivial/seguro. Decisão: documentar como pré-existente (baseline desde a 23.1: 561→644→669→675→681→689→691 runs com a MESMA falha), manter para avaliação futura (ex: validar se o client Java espera UTC ou hora local).

  **Lacunas fechadas nesta task (2 — sem teste "a granel"):**
  1. **Integração Devise×CanCan com role** — os testes da 23.6 provavam login Devise + `session[:user_id]`, e a matriz da 23.7 provava CanCan por role via login legado (`/login`); mas NENHUM teste exercitava a esteira completa login Devise (Warden) → sessão → `current_ability` → ação admin com usuário PORTADOR de role. Fechado com 2 testes em `users/sessions_controller_test.rb`: gestor via `/u/sign_in` lê dashboard e tem escrita administrativa negada (redirect dashboard + alert); admin via role Rolify (coluna `admin` false) cria EstacaoPonto com sucesso.
  2. **Contrato do `rescue_from CanCan::AccessDenied`** — a matriz assertava o redirect para `dashboard_path`, mas nunca o `alert` do flash que o rescue_from (23.7) preenche (`alert: exception.message`). Fechado com assert de `flash[:alert].present?` no caso negativo do gestor em `authorization_matrix_test.rb`. Presença (não texto exato) porque a mensagem default do CanCan é em inglês e o texto não é contrato de I18n da Sprint 23.

  **Coberto × não coberto (decisão do fechamento):**
  - Coberto: matriz por perfil no nível de controller (23.7); actions `authorize! :manage, User` (reimportar/importar_unidade — testes de auditoria já presentes no commit `2d99706`); `valid_password?`/`active_for_authentication?`/`find_for_database_authentication` (23.6); telas Devise new/passwords (23.8); seeds idempotentes (23.9); login/session sync/recall/logout Devise e legado (23.6); baseline de leitura por autenticado-sem-role e `current_ability` (23.7); fallback legado `Admin::SessionsController` com `skip_authorization_check` (coberto implicitamente pelos testes de GET/POST `/login` que passam com `check_authorization` ativo).
  - NÃO coberto (por design, sem escopo infinito): (a) telas `frequencia_por_orgao`/`frequentadores` não exaustivas na matriz — usam a MESMA regra `authorize! :read, :all` já coberta por telas representativas por perfil; adicioná-las exigiria stubs de Pessoas e não mudaria o contrato de autorização testado; (b) texto exato da mensagem do AccessDenied (locale do CanCan, não contrato da sprint); (c) `can :manage, TimeRecord/IntervencaoFrequencia` do gestor não exercitado em controller — nenhum controller admin gerencia esses recursos hoje (só leitura); a permissão é contrato de Ability (coberto em `ability_test.rb` 23.5) e preparação para a gestão futura; (d) envio real de e-mail do recoverable (ActionMailer não montado — débito documentado na 23.8); (e) falha de timezone (genuína, documentada acima).

  **Escopo preservado:** nesta task apenas 2 arquivos de teste foram alterados (`users/sessions_controller_test.rb` +2 testes; `authorization_matrix_test.rb` +1 assert de flash) — nenhum controller/model/migration/ability/view tocado; nenhum arquivo não relacionado alterado como parte da 23.10.

## 📋 Relatório de Bugs — Iteração 23 — Code Specialist

Teste adversarial completo da Sprint 23 (auth Devise + CanCanCan + Rolify) executado após o fechamento da 23.10: **6 bugs** (🔴 1 / 🟠 2 / 🟡 1 / 🟢 2) encontrados, com probe temporário removido e suíte re-rodada sem ele (baseline 691/2169/1 intacto).

| ID | Severidade | Título | Resumo |
|----|-----------|--------|--------|
| B1 | 🔴 Crítico | Recoverable quebra com 500 | `POST /u/password` com e-mail conhecido → `NameError: uninitialized constant Devise::Mailer` (ActionMailer não montado); teste 23.8 mascara com stub |
| B2 | 🟠 Alto | Login Devise com hash Pessoas2 nulo/inválido → 500 | `BCrypt::Errors::InvalidHash` em `user.rb:153` (`valid_password?`) |
| B3 | 🟠 Alto | Sessão de usuário desativado permanece válida | `current_user` não revalida `status=0`; dashboard 200 mesmo com conta inativa |
| B4 | 🟡 Médio | remember_me inoperante no contexto admin | cookie emitido + Warden autentica, mas `session[:user_id]` não sincronizado → 302 dashboard→/login |
| B5 | 🟢 Baixo | Views estacoes/regimes/versoes expõem escrita a gestor/operador | botões "Nova/Editar" sem `can?` — clicar sempre falha (backend correto) |
| B6 | 🟢 Baixo | `/u/sign_in` mostra login a usuário já autenticado via fluxo legado | Devise desconhece `session[:user_id]`; 200 form em vez de redirect |

📄 Relatório completo: [`docs/quality/bug_report_23_cs.md`](../quality/bug_report_23_cs.md)

**Prioridade de correção:** B1 antes do merge da 23.8/23.10 (rota pública com 500); B2 e B3 em seguida (autenticação/revogação); B4, B5, B6 em sequência (UX/consistência).

### Correções pós-Bug Finder (2026-09-21 — Code Specialist, sem commit/merge/push)

Implementadas sobre o working tree do branch `feat/cancancan-controller-integration` (`COMMIT_MODE=manual`).

**✅ B1 (🔴)** — `Users::PasswordsController#create` degrada limpo: `super` + `rescue NameError` (`raise unless e.name == :Mailer`) → `set_flash_message!(:alert, :mail_unavailable)` + redirect para o login (nunca 500). **Decisão: opção (b)** — ActionMailer NÃO habilitado (SMTP/env/views = infra, fora do escopo); caminho sendável 100% Devise preservado. Removido o stub de `User.send_reset_password_instructions` no teste 23.8 (teste real sem máscara). Chave `devise.passwords.mail_unavailable` (pt-BR) adicionada.

**✅ B2 (🟠)** — Helper privado `User#remote_password_hash`: guard `blank?` (user/hash nil ou "") + `rescue BCrypt::Errors::InvalidHash → nil`; usado em `authenticate` e `valid_password?`. Hash ausente/inválido do Pessoas2 → falha limpa (`false`), nunca 500. `super` (senha local) e link Pessoas2 (CPF) preservados.

**✅ B3 (🟠)** — `Admin::ApplicationController#current_user` reescrito: revalida `status == 1` a cada request nas duas fontes (legada `session[:user_id]` e Warden) → conta desativada revoga sessão (`revoke_admin_session!`: limpa `session[:user_id]` + `warden.logout`) e `require_login` redireciona. Sem mudança em `active_for_authentication?`/Ability.

**✅ B4 (🟡)** — Mesmo `current_user`: `session[:user_id]` vazio → `request.env["warden"].authenticate(scope: :user)` (fast path sessão Warden ou strategy rememberable) com status ativo → **sincroniza `session[:user_id]`** → remember_me entrega acesso admin persistente; inativo revoga.

**⏸️ B5/B6 (🟢)** — Débito técnico **aceito** (fora do escopo das correções): `can?` nas views estacoes/regimes/versoes e guard de `signed_in?` legado no `/u/sign_in` — melhorias de UX para sprint futura.

**Evidência:** suíte completa → **701 runs / 2213 asserts / 1 falha** (timezone pré-existente, `presenca_endpoints_test.rb:187` — baseline era 691/2169/1: +10 testes, +44 asserts, nenhuma falha nova); `zeitwerk:check` OK; RuboCop sem offenses nos 6 arquivos alterados.

**Arquivos alterados:** `app/models/user.rb` (B2), `app/controllers/admin/application_controller.rb` (B3+B4), `app/controllers/users/passwords_controller.rb` (B1), `config/locales/devise.pt-BR.yml` (B1), + testes `user_test.rb` (+4), `sessions_controller_test.rb` (+6), `passwords_controller_test.rb` (1 substituído). Status detalhado no [bug_report_23_cs.md](../quality/bug_report_23_cs.md#status-de-correção-2026-09-21).

## 📋 Relatório de Bugs — Iteração 23 — Bug Finder

Segunda rodada de testes adversariais, independente do auto-teste do Code Specialist (`bug_report_23_cs.md`). Objetivo: validar se as correções B1-B4 realmente fecham os cenários e procurar bugs novos na interação Devise × CanCanCan × Rolify × autenticação legada Pessoas2.

**Validação de B1-B4:** confirmadas efetivas nos testes reais (não apenas documentadas) — incluindo cenário adicional (logout explícito com `remember_me` ativo não reautentica sozinho). B5/B6 seguem como débito aceito, sem mudança.

| ID | Severidade | Título | Resumo |
|----|-----------|--------|--------|
| B7 | 🟠 Alto | `Pessoas::User.buscar_por_cpf` sem tratamento de exceção de conexão → 500 | Erro de infraestrutura (conexão/timeout) no mirror Pessoas2 propaga sem rescue em `valid_password?`/`authenticate`, gerando 500 em vez de falha limpa |
| B8 | 🟠 Alto | Enumeração de contas via `POST /u/password` | Email conhecido → 302; email desconhecido → 422 — diferença de status permite enumerar contas cadastradas (rota pública); `config.paranoid` desabilitado |

📄 Relatório completo: [`docs/quality/bug_report_23_bug-finder.md`](../quality/bug_report_23_bug-finder.md)

**Prioridade de correção:** B7 (robustez da integração Pessoas2, RF de risco alto da sprint) e B8 (segurança do fluxo público de recuperação de senha — `config.paranoid = true`), ambos antes de considerar a Sprint 23 fechada para produção.

### Correções pós-Bug Finder (2ª rodada) (2026-09-21 — Code Specialist, sem commit/merge/push)

Implementadas sobre o working tree do branch `feat/cancancan-controller-integration` (`COMMIT_MODE=manual`), fechando os 2 bugs 🟠 Alto reportados na segunda rodada do Bug Finder (`docs/quality/bug_report_23_bug-finder.md`).

**✅ Bug 1 (🟠)** — `app/models/user.rb`: nova função privada `remote_password_hash_by_cpf(cpf)` que envolve a chamada `Pessoas::User.buscar_por_cpf(cpf)` em `rescue ActiveRecord::ActiveRecordError, PG::Error → nil` (com log de erro), delegando o resultado para o `remote_password_hash` já existente (guard de hash ausente/inválido, correção B2). Usada tanto em `authenticate` (fluxo legado `/login`) quanto em `valid_password?` (fluxo Devise `/u/sign_in`) — rescue centralizado num único ponto, sem duplicação. Falha de conexão/infra com o mirror Pessoas2 agora vira falha de login limpa (`false` → recall 422 com alert), nunca 500.

**✅ Bug 2 (🟠)** — `config/initializers/devise.rb`: `config.paranoid = true` habilitado (linha ~116), eliminando a enumeração de contas via `POST /u/password` (antes: email conhecido → 302/303, email desconhecido → 422). Ambos os casos agora respondem com o mesmo status HTTP e tipo de resposta (redirect). A chave I18n `devise.passwords.send_paranoid_instructions` já existia no `devise.pt-BR.yml` (padrão canônico devise-i18n, presente desde a 23.3) — nenhuma chave nova necessária. `app/controllers/users/passwords_controller.rb`: o rescue de `NameError` (correção B1) passou a usar `redirect_to ..., status: :see_other` (em vez do default 302 do Rails) para não reintroduzir uma diferença de status entre o caminho "email conhecido, mailer indisponível" (redirect manual) e o caminho paranoid "email desconhecido" (redirect via responder Devise, já 303 por `config.responder.redirect_status`).

**Testes atualizados/criados:**
- `test/models/user_test.rb`: teste antigo que documentava a propagação da exceção (`authenticate propaga erro quando a leitura ao pessoas2 falha`) substituído por 3 testes novos provando falha limpa (`authenticate`/`valid_password?` com `ActiveRecord::ConnectionNotEstablished` e `ActiveRecord::StatementInvalid`), sem `assert_raises`.
- `test/controllers/sessions_controller_test.rb` (fluxo legado `/login`): +1 teste (`ConnectionNotEstablished` → 422 limpo, sem 500).
- `test/controllers/users/sessions_controller_test.rb` (fluxo Devise `/u/sign_in`): +1 teste (`ConnectionNotEstablished` → recall 422, sem 500).
- `test/controllers/users/passwords_controller_test.rb`: teste de email desconhecido atualizado (antes esperava 422/re-render; agora espera redirect + `send_paranoid_instructions`) e +1 teste provando que email conhecido e desconhecido retornam o mesmo status HTTP.

**Evidência:** suíte completa → **706 runs / 2226 asserts / 1 falha** (timezone pré-existente, `presenca_endpoints_test.rb:187` — baseline era 701/2213/1: +5 testes, +13 asserts, nenhuma falha nova); `rails zeitwerk:check` → "All is good!"; RuboCop nos 7 arquivos alterados → sem offenses.

**Arquivos alterados:** `app/models/user.rb` (Bug 1), `config/initializers/devise.rb` (Bug 2), `app/controllers/users/passwords_controller.rb` (Bug 2, ajuste de status), + testes `test/models/user_test.rb`, `test/controllers/sessions_controller_test.rb`, `test/controllers/users/sessions_controller_test.rb`, `test/controllers/users/passwords_controller_test.rb`. Nenhuma migration, Ability, roles ou controller fora do escopo tocados. Status detalhado no [bug_report_23_bug-finder.md](../quality/bug_report_23_bug-finder.md).

## Caminho Crítico
23.1 → 23.3 → 23.6 → 23.8 → 23.10

## Riscos
- **Risco alto (Sprint 23):** Autenticação via CPF (Pessoas2) deve continuar funcionando. O método `authenticate` custom (User model) é o ponto de integração — não pode ser removido.
- `password_digest` preservado durante toda a transição (tasks 23.1-23.10).
- **Falha pré-existente de timezone (documentada na 23.10):** `presenca_endpoints_test.rb:187` — expectativa oriunda do commit `68112a8` (2026-07-24) vs. comportamento atual round-trip local em `America/Sao_Paulo`. Genuína, fora do escopo Sprint 23, presente em todos os baselines da sprint (561→691 runs). Avaliar em sprint futura se o client Java da Estação espera UTC ou hora local.

## Débitos Técnicos
- [ ] `current_sign_in_ip` / `last_sign_in_ip` usam `string` em vez de `inet` (basic8 usa `inet`) — decidido por compatibilidade com endpoints legados. Reavaliar na task 23.3. — Severidade: 🟢 — Tarefa: 23.1
- [ ] **23.8 — Habilitar ActionMailer + mailer Devise** (origem: nota técnica da 23.8; adiado para evolução do recoverable) — **não pode ser considerado pronto sem os débitos 23.8-Obs1 (rate limiting) e 23.8-Obs2 (re-medição de paridade de timing)**; sem eles, mailer ativo = inbox flooding + reset-DoS + paridade do Bug 10 quebrada por SMTP síncrono. — Severidade: 🟡 — Tarefa: 23.8
- [ ] **23.8-Obs1 — Rate limiting em `POST /u/password`** (rack-attack ou similar: N requisições/intervalo por IP ou por email; headers `429`/`Retry-After`) — origem r5 Obs 1; **bloqueado pelo 23.8** (impacto real só com mailer ativo) **E pré-requisito do 23.8** (sem throttle, habilitar mailer abre flooding/reset-DoS). Nenhum avança sem o outro. — Severidade: 🟡 — Tarefa: 23.8
- [ ] **23.8-Obs2 — Re-medição da paridade de timing do Bug 10 ao habilitar o mailer** (`send_devise_notification` usa `deliver_now` síncrono → paridade por ordem de grandeza; avaliar `deliver_later`/ActiveJob; atualizar comentário do patch; repetir probe de timing/queries) — origem r5 Obs 2; **bloqueado pelo 23.8 E pré-requisito do 23.8**. O teste atual de queries continuaria verde com mailer ativo (falsa segurança). — Severidade: 🟡 (latente) — Tarefa: 23.8
- [ ] **23.8-Obs3 — Invariante do Bug 10 para blank/whitespace** (blank/whitespace executam 4 vs 5 queries; estender teste do Bug 10 com `email: ""` e `email: "   "` asserindo mesma contagem das demais entradas) — origem r5 Obs 3; opcional/cosmético (não explorável para enumeração). — Severidade: 🟢 — Tarefa: 23.8
- [ ] **23.8-Obs4 — Fonte real de emails como pré-requisito funcional do recoverable** (0/84 usuários em dev com email; `Admin::UsersController#user_params` não permite email; seeds/fixtures sem email; nenhum writer) — origem r5 Obs 4; sem origem de email (cadastro/vinculação/sync — RF futura), habilitar o mailer não entrega valor de ponta a ponta. — Severidade: ⚪ — Tarefa: 23.8

## 📋 Relatório de Bugs — Iteração 23 — Bug Finder (3ª rodada)

Terceira rodada de testes adversariais, independente das duas anteriores (`bug_report_23_cs.md` e `bug_report_23_bug-finder.md`). Objetivo: validar de forma independente (sem confiar apenas na documentação) se B7 e B8 foram efetivamente corrigidos, verificar a especificidade do rescue de B7, checar interação de `paranoid` com o fluxo completo de reset de senha, efeitos colaterais do status `303`/`see_other` e regressão no login legado — e procurar bugs novos.

**Validação de B7/B8:** B7 confirmado corrigido (rescue específico `ActiveRecord::ActiveRecordError, PG::Error`, sem mascarar bugs de programação genuínos, sem regressão no `/login` legado). B8 confirmado corrigido **apenas na dimensão de status HTTP** (303 idêntico nos dois casos) — mas foi encontrada uma **assimetria de flash** (tipo + texto + cor/ícone na view) que reabre a enumeração de contas por outro canal, já que o ActionMailer nunca está montado nesta aplicação e todo email conhecido cai deterministicamente no caminho de erro (`alert` vermelho) enquanto todo email desconhecido cai no caminho paranoid (`notice` verde).

| ID | Severidade | Título | Resumo |
|----|-----------|--------|--------|
| Bug 9 | 🟠 Alto | Assimetria de flash (tipo + texto) entre email conhecido/desconhecido em `POST /u/password` | HTTP status idêntico (303), mas `flash[:alert]` (vermelho, "mail_unavailable") vs. `flash[:notice]` (verde, "send_paranoid_instructions") são deterministicamente diferentes — reabre a enumeração de contas que B8 se propôs a fechar |

📄 Relatório completo: [`docs/quality/bug_report_23_bug-finder-r3.md`](../quality/bug_report_23_bug-finder-r3.md)

**Prioridade de correção:** Bug 9 antes de considerar o fluxo recoverable pronto para produção — correção pequena (unificar a chave/tipo de flash usada no `rescue NameError` de `Users::PasswordsController#create` com a do caminho paranoid) e sem necessidade de habilitar ActionMailer. Recomenda-se também reforçar o teste existente de paridade de status para comparar também o conteúdo/tipo do flash.

**Evidência:** suíte completa revalidada em **706 runs / 2226 assertions / 1 falha** (timezone pré-existente) antes e depois do probe temporário usado para provar o Bug 9 — nenhum arquivo de produção alterado por este agente (Bug Finder nunca corrige, apenas reporta).

### Correções pós-Bug Finder (3ª rodada) (2026-09-21 — Code Specialist, sem commit/merge/push)

Implementada sobre o working tree do branch `feat/cancancan-controller-integration` (`COMMIT_MODE=manual`), fechando o único bug 🟠 Alto reportado na terceira rodada do Bug Finder (`docs/quality/bug_report_23_bug-finder-r3.md`).

**✅ Bug 9 (🟠)** — `app/controllers/users/passwords_controller.rb`: no `rescue NameError` de `Users::PasswordsController#create` (correção B1), o flash exposto ao usuário final deixou de ser `set_flash_message!(:alert, :mail_unavailable)` e passou a ser `set_flash_message!(:notice, :send_paranoid_instructions)` — a MESMA chave/tipo que o caminho paranoid (email desconhecido) já usa. Como o ActionMailer nunca está montado nesta aplicação, todo email conhecido caía deterministicamente neste rescue; com a chave `:alert` diferente do `:notice` do caminho paranoid, um visitante não autenticado conseguia enumerar contas cadastradas pela cor/ícone/texto do flash, mesmo com o status HTTP já idêntico (303, B8). O erro real (mailer indisponível) continua sendo logado internamente via `Rails.logger.error` — com o texto da chave `devise.passwords.mail_unavailable` (mantida no locale só para esse log administrativo) e o email submetido — preservando a única forma do time perceber que o mailer está fora do ar. Nenhuma mudança em `config.paranoid`, no status HTTP (`:see_other` preservado) ou no rescue de B7 (`remote_password_hash_by_cpf`, intocado). ActionMailer permanece desabilitado (decisão já documentada, fora de escopo).

**Testes atualizados:**
- `test/controllers/users/passwords_controller_test.rb`: teste "POST /u/password com email conhecido sem ActionMailer degrada limpo" atualizado para esperar `flash[:notice]` = `send_paranoid_instructions` (e `flash[:alert]` nulo) em vez de `flash[:alert]` = `mail_unavailable`. Teste "POST /u/password com email conhecido e desconhecido retornam o mesmo status HTTP" renomeado e estendido para também comparar CONTEÚDO e TIPO do flash entre as duas requisições, usando `reset!` para isolar as sessões (a lacuna diagnosticada no relatório: testes antigos reusavam a mesma sessão/flash e mascaravam a diferença) — assert de `flash[:notice]` idêntico e `flash[:alert]` ausente em ambos os casos.

**Evidência:** suíte completa → **706 runs / 2231 asserts / 1 falha** (timezone pré-existente, `presenca_endpoints_test.rb:187` — baseline era 706/2226/1: mesmo número de testes reescritos/estendidos, +5 asserts, nenhuma falha nova, 0 erros); `rails zeitwerk:check` → "All is good!"; RuboCop em `app/controllers/users/passwords_controller.rb` e `test/controllers/users/passwords_controller_test.rb` → sem offenses.

**Arquivos alterados:** `app/controllers/users/passwords_controller.rb` (Bug 9), `test/controllers/users/passwords_controller_test.rb` (2 testes atualizados). Nenhuma migration, `config/initializers/devise.rb`, `Ability`, ActionMailer ou controller fora do escopo tocados. Status detalhado no [bug_report_23_bug-finder-r3.md](../quality/bug_report_23_bug-finder-r3.md).

## 📋 Relatório de Bugs — Iteração 23 — Bug Finder (4ª rodada)

4ª rodada de teste adversarial independente, focada em esgotar a superfície de enumeração de contas em `POST /u/password` além de status HTTP (B8) e flash tipo/texto (Bug 9) — timing, headers/cookies, vazamento de token, diff estrutural de HTML e vazamento de log — mais uma passada de regressão ampla (matriz CanCanCan, seeds, Rolify×Ability).

| ID | Severidade | Resumo |
|----|-----------|--------|
| Bug 10 | 🟡 Médio | Timing side-channel estrutural em `POST /u/password`: email conhecido sempre dispara mais queries (5 vs 1: SELECT extra + SAVEPOINT/UPDATE/RELEASE) e levanta/captura uma exceção que o caminho "desconhecido" não faz — delta de tempo mensurável (~1-2ms em ambiente de teste), mas **limitação estrutural do próprio modo `paranoid` do Devise**, não uma regressão de código do Frequência |

Itens (b) headers/cookies, (c) vazamento de token, (d) diff de HTML e (e) vazamento de log — **todos sem bug** (Bug 9 revalidado como completamente fechado na dimensão HTML/flash). Matriz de autorização CanCanCan/Rolify e seeds — **sem regressão** (14/14 verdes).

📄 Relatório completo: [`docs/quality/bug_report_23_bug-finder-r4.md`](../quality/bug_report_23_bug-finder-r4.md)

**Veredito:** recomenda-se **ENCERRAR o ciclo de bug-hunting** focado em `POST /u/password` — rendimento decrescente (nenhum achado Alto/Crítico nesta rodada; o único achado é uma limitação de design conhecida do Devise, de exploração não-trivial, não uma falha de implementação). Bug 10 deve ser tratado como débito técnico aceito, não como bloqueador da Sprint 23.

**Evidência:** suíte completa revalidada em **706 runs / 2231 assertions / 1 falha** (timezone pré-existente) antes e depois do probe temporário — nenhum arquivo de produção alterado por este agente (Bug Finder nunca corrige, apenas reporta).

### Correções pós-Bug Finder (4ª rodada) (2026-09-23 — Code Specialist, COMMIT_MODE=manual, sem commit/merge/push)

Correção do **Bug 10 (🟡 Médio)** — timing side-channel estrutural em `POST /u/password` (`docs/quality/bug_report_23_bug-finder-r4.md`).

> **Nota de configuração:** o veredito r4 e o `BUG_LEVEL=1` (SERVICE-LEVEL) recomendavam registrar o 🟡 como débito técnico aceito. A instrução explícita da tarefa foi **implementar a correção**, então o patch foi feito com o alinhamento do Code Specialist à delegação; a divergência fica registrada aqui para o CTO/dev decidirem se mantêm ou revertem para débito documentado.
>
> **✅ Decisão do CTO (2026-09-23) — MANTER a correção do Bug 10; divergência encerrada.** Justificativa: a 5ª rodada do Bug Finder validou **empiricamente** o phantom work como efetivo — paridade de queries 5 = 5, timing mediano known × unknown ≈ 0 ms, zero mutação de dados nos caminhos desconhecidos, zero regressão na suíte (707/2232/1) e nenhum bug Crítico/Alto restante (BUG_LEVEL=1 → sem bloqueador). Reverter para "débito documentado" destruiria a invariante já testada e a lição registrada em `docs/governance/lessons.md`, sem ganho de segurança (delta residual de µs, dominado pelo I/O igualado). A correção permanece válida **na configuração atual (mailer desligado)**; sua sobrevivência à habilitação do ActionMailer está condicionada aos débitos 23.8-Obs1/Obs2 (ver Débitos Técnicos). O veredito r4 permanece como referência histórica da recomendação SERVICE-LEVEL (registrar débito aceito), superada pela validação empírica da r5 + decisão explícita de manter.

**✅ Bug 10 (🟡)** — `app/controllers/users/passwords_controller.rb` (`create`): o caminho de email **conhecido** executava 5 queries (SELECT por email + SELECT por `reset_password_token` do `token_generator` + SAVEPOINT/UPDATE/RELEASE do save) e ainda levantava/capturava `NameError` (mailer desmontado); o caminho **desconhecido** executava apenas 1 query (SELECT miss) e retornava normal — delta de ~1-2ms mensurável, permitindo em tese enumerar contas por timing. Correção: quando `super` retorna **sem** exceção (só ocorre no caminho desconhecido; o conhecido levanta `NameError` antes do retorno), executa-se **phantom work** inócuo — `Devise.token_generator.generate` (SELECT por `reset_password_token`, mesma query do Devise) + `transaction(requires_new: true)` com `update_all` em registro inexistente (`id = -1`, UPDATE de 0 linhas — SAVEPOINT/UPDATE/RELEASE, mesmas 3 queries do save). Resultado: **5 = 5 queries**, nenhum dado alterado. O custo do raise/rescue não é replicado de propósito (anti-pattern; delta residual de µs, dominado pelo I/O igualado).

**Testes:** `test/controllers/users/passwords_controller_test.rb` — novo teste "POST /u/password com email conhecido e desconhecido executam a mesma quantidade de queries SQL (Bug 10)" com contagem via `ActiveSupport::Notifications` (`sql.active_record`): **falhava antes (5 vs 1), passa depois (5 vs 5)**.

**Evidência:** suíte completa → **707 runs / 2232 asserts / 1 falha** (timezone pré-existente, `presenca_endpoints_test.rb:187` — baseline era 706/2231/1: +1 teste, +1 assert, nenhuma falha nova); `rails zeitwerk:check` → "All is good!"; RuboCop em `app/controllers/users/passwords_controller.rb` e `test/controllers/users/passwords_controller_test.rb` → sem offenses. Branch de demanda: `fix/bug10-recoverable-timing-sidechannel` (repo sem `develop`; convenção local de branches encadeadas, conforme tasks 23.1+).

**Arquivos alterados:** `app/controllers/users/passwords_controller.rb` (Bug 10 ~linha 44), `test/controllers/users/passwords_controller_test.rb` (+1 teste e helper `count_sql_queries`). Nenhuma migration, `config/initializers/devise.rb`, Ability ou ActionMailer tocados.

## 📋 Relatório de Bugs — Iteração 23 — Bug Finder (5ª rodada)

5ª rodada de teste adversarial independente, focada exclusivamente no **phantom work do Bug 10** (`Users::PasswordsController#create`): side-effects, falsa paridade, cenários onde o timing ainda vaza, impacto quando o ActionMailer for habilitado, transações sob concorrência e edge cases de email (uppercase, unicode, blank, nil, flood) — mais regressão ampla das tasks 23.1–23.9.

**Veredito: nenhum bug Crítico/Alto** (BUG_LEVEL=1 → sem bloqueador). O phantom work foi validado empiricamente: paridade de queries 5 = 5, timing mediano known × unknown ≈ 0 ms, zero mutação de dados nos caminhos desconhecidos, suíte intacta (707/2232/1).

| ID | Severidade | Título | Resumo |
|----|-----------|--------|--------|
| Obs 1 | 🟡 Médio | Ausência de rate limiting em `POST /u/password` (flood) | 30 requests sem throttle; cada email conhecido = 1 UPDATE + rotação de token + 1 linha de ERROR log; sem headers de rate limit. Hoje: churn de log/DB. Com ActionMailer habilitado: inbox flooding + reset-DoS (rotação invalida link em voo) |
| Obs 2 | 🟡 Médio (latente) | Mailer `deliver_now` (SMTP síncrono) quebra a paridade de timing do Bug 10 quando ActionMailer for habilitado | `send_devise_notification` usa `deliver_now`; caminho conhecido passaria a levar SMTP round-trip e o phantom é pulado (`persisted?` true) — o teste de queries continuaria verde dando falsa segurança |
| Obs 3 | 🟢 Baixo | Invariante do Bug 10 incompleta para blank/whitespace: 4 queries vs 5 (~0.9ms mais rápido) | `find_or_initialize_with_errors` pula o SELECT por email quando valor é blank e o phantom roda mesmo assim; não explorável para enumeração, mas o teste não cobre |
| Obs 4 | ⚪ Info | 0/84 usuários com email em dev; nenhum writer de email (admin/users_controller não permite; seeds/fixtures sem email) + mailer desmontado → recoverable inoperante ponta a ponta no ambiente real | Cadeia de dependência a registrar na evolução do recoverable |
| Obs 5 | ⚪ Info | POST sem parâmetro `user` → 303 idêntico ao blank (sem 400/500) | Comportamento seguro/consistente |

📄 Relatório completo: [`docs/quality/bug_report_23_bug-finder-r5.md`](../quality/bug_report_23_bug-finder-r5.md)

**Prioridade de ação (não-bloqueante):** vincular o débito "habilitar ActionMailer" (23.8) às Obs 1+2 (throttle + re-medição de paridade) antes de ativá-lo; Obs 3 opcional (estender teste do Bug 10). Recomenda-se encerrar o ciclo de bug-hunting sobre `POST /u/password` até que o mailer seja habilitado ou haja fonte real de emails.

**Evidência:** suíte completa revalidada em **707 runs / 2232 assertions / 1 falha** (timezone pré-existente, `presenca_endpoints_test.rb:187`) antes e depois do probe temporário `bf_probe_r5_test.rb` (9 cenários/60 asserts — removido ao final). Nenhum arquivo de produção ou teste existente foi alterado por este agente (Bug Finder nunca corrige, apenas reporta).

### 🔒 Encerramento do ciclo de bug-hunting sobre `POST /u/password` (decisão do CTO — 2026-09-23)

O ciclo adversarial sobre `POST /u/password` é **encerrado na configuração atual (mailer desligado)**, conforme recomendação das rodadas r4/r5 e `BUG_LEVEL=1`: as 5 rodadas cobriram status HTTP, flash (tipo + texto), HTML estrutural, headers/cookies, token, log e timing (com e sem phantom work); nenhum blocker restante e rendimento decrescente confirmado.

**Gatilhos de reabertura (explícitos):**
1. **Habilitar ActionMailer** (débito 23.8) — exige re-executar o probe de paridade de timing/queries (23.8-Obs2) e impõe throttle (23.8-Obs1) antes de considerar o endpoint pronto; sem essas salvaguardas, a invariante do Bug 10 não sobrevive ao `deliver_now` síncrono.
2. **Surgimento de fonte real de emails no sistema** (writer de `users.email` — cadastro/vinculação/sync; 23.8-Obs4) — altera o conjunto de contas atingíveis e pode revelar vazamentos não observáveis com 0/84 emails populados em dev.

Enquanto nenhum gatilho disparar, novas rodadas sobre este endpoint têm rendimento esperado decrescente (veredito r4) e **não devem ser agendadas**.

---

## 📋 Relatório de Revisão — Code Reviewer (Bug 10 — commit `66ca7fd`)

> Referência: `docs/quality/review_report_23_cs.md` (completo, com checklist e tabelas).

**Veredito: ✅ APROVADO — 0 Blockers.** Revisão do commit `66ca7fd` (branch `fix/bug10-recoverable-timing-sidechannel`): phantom work validado como inócuo (UPDATE em `id = -1` → 0 linhas, `update_all` sem callbacks), seguro (sem SQL injection — literal fixo + binds), sem feature creep e sem ruptura da stack (Devise 5 / Rails 8 / API-only). Teste de paridade determinístico e estável: 7 runs / 45 assertions / 0 failures em 4 seeds (35139, 1, 42, 12345) na classe revisada; 24 runs / 148 assertions / 0 failures em `test/controllers/users/`.

**Sugestões não-bloqueantes:** S1 (opcional — assert de inocuidade no teste de paridade), S2/S3 (herdadas r5 Obs 3/Obs 2 — já registradas como débitos 23.8-Obs3/Obs2), S4 (info — nota de auditoria sobre PK negativa). Status das tarefas revisadas: Bug 10 — **✅ Implementado, ✅ Aprovado (revisão técnica)**; aguardando rastreabilidade/merge pelo Code Specialist.

## 🏭 CI/CD Pipeline Local

**Branch:** `fix/bug10-recoverable-timing-sidechannel`
**Data:** 2026-09-23
**Resultado:** ✅ Aprovado (push liberado)

| Step | Status | Issues Remanescentes |
|------|--------|---------------------|
| Security | ✅ | brakeman 8.0.5 — 0 vulnerabilidades (apenas aviso de versão 8.0.6) |
| Quality | ✅ | rubocop — arquivos do Bug 10 sem offenses; 59 offenses pré-existentes em outros arquivos (fora do escopo) |
| Test | ✅ | 707 runs / 2232 asserts / 1 failure — falha timezone pré-existente (`presenca_endpoints_test.rb:187`), fora do escopo |

**Observações:** Esteira mapeada do `.github/workflows/ci.yml` (GitHub Actions: brakeman → rubocop → db:test:prepare + rails test), não do `.gitlab-ci.yml` da skill (este repo não possui GitLab CI). Nenhuma falha nova introduzida pelo commit `66ca7fd`.
