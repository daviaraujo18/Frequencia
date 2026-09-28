# Relatório Bug Finder — Iteração 23 — Code Specialist

> **Branch:** feat/cancancan-controller-integration
> **Data:** 2026-09-21
> **Propósito:** Testes adversariais da Sprint 23 (autenticação Devise 5.0.4 + autorização CanCanCan 3.6.1 + roles Rolify 6.0.1) — validação de hipóteses de ataque em fluxos alternativos, sessão legada×Devise, recoverable/passwords, seeds, load_and_authorize_resource e matriz de permissões.
> **Tarefas revisadas/testadas:** 23.3 (auth Devise), 23.6 (sessão/sync), 23.7 (CanCanCan + Ability), 23.8 (passwords recoverable), 23.9 (seeds roles), 23.10 (auditoria/fechamento)
> **Arquivos alterados:** nenhum código-fonte alterado — probe temporário `test/controllers/bugfinder_23_probe_test.rb` criado e **removido ao final** (não deixou rastro; suíte re-rodada sem ele)

---

## Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 15 (probe) + 691 (suíte completa) |
| Bugs encontrados | 6 |
| 🔴 Crítico | 1 |
| 🟠 Alto | 2 |
| 🟡 Médio | 1 |
| 🟢 Baixo | 2 |
| ⚪ Info | 3 |

## Bugs por Severidade

### 🔴 Crítico

#### Bug 1 — Recuperação de senha (recoverable) quebra com erro 500 no mundo real; teste 23.8 mascara com mock

- **Severidade:** 🔴 Crítico
- **RF/RN violado:** feature 23.8 (passwords recoverable) — fluxo "Esqueci minha senha" publicado na UI (`/u/password/new`); RN de disponibilidade do fluxo de recuperação
- **Passos:**
  1. Usuário conhecido acessa `GET /u/password/new` e submete `POST /u/password` com email válido cadastrado no banco local.
  2. Sem nenhum gêmeo — execução real, sem stub.
- **Atual:** `NameError: uninitialized constant Devise::Mailer` → **HTTP 500**. Causa raiz: `config/application.rb:10` `# require "action_mailer/railtie"` (ActionMailer NÃO montado; débito já documentado na 23.8). O controller `Users::PasswordsController` herda de `Devise::PasswordsController` e chama `Devise::Mailer.reset_password_instructions` → constante inexistente. Detalhe agravante: o `reset_password_token` é gravado no banco ANTES do erro (o 500 ocorre depois da persistência do token, no envio) — usuário pode receber token "morto" sem e-mail.
- **Esperado:** redirect com notice (`send_paranoid_instructions`: "Você receberá um e-mail...") sem 500, OU recurso desabilitado conscientemente na UI com mensagem adequada. Sem ActionMailer, o fluxo deve falhar limpo (422/redirect com alert), nunca 500.
- **Teste sugerido:** remover o stub de `User.send_reset_password_instructions` no `test/controllers/users/passwords_controller_test.rb` (linha 56-63) e POST/PATCH com email conhecido → NÃO deve lançar exceção (deve renderizar/redirect sem 500). Alternativa: teste de regressão que asserta que qualquer exceção dentro de recoverable vira redirect com erro, não 500.
- **Nota de rastreabilidade:** a decisão "ActionMailer não montado" é débito documentado na 23.8, mas o stub do teste cria falso verde: a rota está **publicamente quebrada com 500** para qualquer usuário que tente recuperar senha. O 500 também é alcançável por usuário não autenticado (superfície pública).

### 🟠 Alto

#### Bug 2 — Login via Devise com conta Pessoas2 cujo hash é nulo/inválido gera 500 (BCrypt::Errors::InvalidHash)

- **Severidade:** 🟠 Alto
- **RF/RN violado:** RN05 (não regredir autenticação de Pessoas2); contrato 23.6 ("autenticar via CPF contra o usuário integrante")
- **Passos:**
  1. Usuário integrante (Pessoas2) sem `encrypted_password` (ou com hash corrompido) tenta login por CPF em `POST /u/sign_in`.
  2. `find_for_database_authentication` retorna o User (+ stub Pessoas) com `encrypted_password = nil`.
  3. `User#valid_password?` (`app/models/user.rb:153`) executa `BCrypt::Password.new(encrypted_password)`.
- **Atual:** `BCrypt::Errors::InvalidHash: invalid hash` → **HTTP 500**. Nota: o guard de `password.present?` protege o caso onde é passado nil como *senha*, mas NÃO protege o caso de *hash* ausente/ínválido; igualmente, `has_secure_password` (`authenticate`) sofre do mesmo padrão quando `password_digest` é nil/inválido (fluxo legado 21.5) — qualquer usuário Pessoas2 com hash nil derruba o login com 500. Conta com `encrypted_password == ""` (contas criadas na era pré-Devise, task 23.3) está em risco.
- **Esperado:** falha de autenticação limpa (redirect com alert/flash de credenciais inválidas, sem exceção), OU backfill garantido do seed (23.9 só cobre `admin.admin` e demonstrações — NÃO cobre todos os usuários Pessoas2, e Pessoas2 é read-only).
- **Teste sugerido:** login com usuário `encrypted_password = nil` e com `encrypted_password = ""` → deve redirecionar com alert, sem exceção; usar `assert_raises` atual para provar o 500 antes da correção.
- **Nota:** o guard `return false unless encrypted_password.present?` existe no model? Verificado: o erro ocorre — portanto o guard não cobre `String.new(nil)` numa entrada válida de Pessoas (o valor vem com encoding/objeto que escapa o guard, ou o guard checa o argumento errado). O teste H5 (hash nil literal) passou limpo; o H2 (objeto Pessoas stub com campo nil) estourou — a diferença está na origem do valor (objeto Pessoas::User vs User local).

#### Bug 3 — Sessão ativa de usuário desativado (status=0) permanece válida indefinidamente

- **Severidade:** 🟠 Alto
- **RF/RN violado:** contrato 23.6 ("usuário inativo não autentica") estendido a sessões vivas; RN de revogação de acesso
- **Passos:**
  1. Usuário com `status = 1` autentica normalmente (qualquer fluxo).
  2. Administração desativa a conta (`status = 0`).
  3. Sem logout, o usuário continua navegando (`GET /admin/dashboard` → **200**).
- **Atual:** `Admin::ApplicationController#current_user` resolve apenas `User.find_by(id: session[:user_id])` e nunca revalida `status`/`active_for_authentication?`. Como `config.timeout_in` está comentado no `devise.rb` (sem timeout de sessão) e a sessão Rails dura enquanto o browser estiver aberto, uma conta desativada mantém acesso pleno à leitura (e, para admin desativado, à escrita). Pré-existente no fluxo legado, mas a Sprint 23 (que define o contrato "inativo bloqueado") era a janela natural para corrigir — permanece aberto.
- **Esperado:** requisições de usuários com `status = 0` devem ser rejeitadas (logout forçado / redirect login) a cada request, ou ao menos em intervalo curto (revalidação do guard no `current_user`).
- **Teste sugerido:** `test/controllers/users/sessions_controller_test.rb`: autenticar, `update_column(:status, 0)`, `GET /admin/dashboard` → esperado redirect para login (hoje: 200).

### 🟡 Médio

#### Bug 4 — Remember_me do Devise não entrega acesso no contexto admin (cookie emitido, sessão não sincronizada)

- **Severidade:** 🟡 Médio
- **RF/RN violado:** contrato "Lembrar-me" da UI de login (`users/sessions/new.html.erb`) — funcionalidade publicada mas inoperante
- **Passos:**
  1. Login via `POST /u/sign_in` com `remember_me = 1` (cookie `remember_user_token` é emitido; `session[:user_id]` sincronizado no create).
  2. Usuário fecha e reabre o browser (sessão expirada/perdida; cookie remember presente).
  3. `GET /u/sign_in`: Warden autentica via strategy `rememberable` → **302 para /dashboard**.
  4. `GET /admin/dashboard`: `current_user` busca `session[:user_id]` (nil no request do passo 3 — sync só acontece no `create`) → `require_login` → **redirect para /login**.
- **Atual:** o usuário "lembrado" é autenticado pelo Warden (redirect para dashboard) e imediatamente devolvido ao login — o remember_me não entrega acesso e ainda gera experiência de "loop" de redirecionamento. A raiz é a dupla autoridade de sessão: Warden (Devise) vs `session[:user_id]` (contrato legado); o sync só ocorre no caminho `create`.
- **Esperado:** após autenticar via remember cookie, o `session[:user_id]` deve ser sincronizado (ou `current_user` deve considerar a sessão Warden) para o acesso admin funcionar; ou o checkbox "Lembrar-me" deve ser removido/desabilitado se o contrato for só session-cookie.
- **Teste sugerido:** integral (Rails integration test) simulando browser com cookie remember após sessão limpa: `GET /u/sign_in` → follow redirect → o fluxo deve chegar ao dashboard com conteúdo (hoje: chega ao /login).

### 🟢 Baixo

#### Bug 5 — Views de estacoes/regimes/versoes expõem ações de escrita a gestor/operador (sem `can?`)

- **Severidade:** 🟢 Baixo
- **RF/RN violado:** RN05/RN06 (matriz de permissões) — backend correto, UI inconsistente
- **Passos:**
  1. Gestor (ou operador) autentica e acessa `GET /estacoes` (ou regimes/versoes index).
  2. A tela exibe botões "Nova Estação"/"Editar"/"Cadastrar Nova Versão" (confirmado via `assert_select` no probe H29 — link `a[href='/estacoes/new']` presente para gestor).
  3. Clicar em qualquer ação → `load_and_authorize_resource` nega → redirect dashboard com alert.
- **Atual:** UX enganosa: o gestor vê ações que sempre falham. As views foram criadas antes da matriz de autorização e não usam o helper `can?`/`cannot?` (nenhuma ocorrência em `app/views/admin/{estacoes,regimes,versoes}/`).
- **Esperado:** condicionar os botões de escrita a `can?(:create, ...)`/`can?(:update, ...)` nas views (ou ocultar por perfil) — sem alterar a matriz.
- **Teste sugerido:** assert_select negativo: gestor em `/estacoes` não deve ver `a[href='/estacoes/new']`.

#### Bug 6 — Usuário já autenticado via fluxo legado vê a tela de login ao visitar `/u/sign_in`

- **Severidade:** 🟢 Baixo
- **RF/RN violado:** UX/contrato de sessão (Devise deveria redirecionar usuários autenticados, mas desconhece a sessão legada)
- **Passos:**
  1. Autenticar via `/login` (fluxo legado, `session[:user_id]` setado).
  2. `GET /u/sign_in` com sessão viva.
- **Atual:** 200 renderizando o formulário de login (probe H26) — o Devise não reconhece a sessão legada e não redireciona; usuário pensa que está deslogado.
- **Esperado:** redirecionar para `dashboard_path` quando `session[:user_id]` existe (guard no controller ou override de `signed_in?` considerando a sessão legada).
- **Teste sugerido:** autenticar via `/login`, `GET /u/sign_in` → esperado redirect para dashboard.

---

## Observações (⚪ Info — não-bugs de teste, para contexto estrutural)

1. **Hierarquia de exceções CanCanCan:** `CanCan::AuthorizationNotPerformed < CanCan::Error` (NÃO < AccessDenied). O `rescue_from CanCan::AccessDenied` do `Admin::ApplicationController` (23.7) cobre apenas negativas; se uma action futura esquecer de autorizar, o `check_authorization` (after_action) lança 500 não capturado. Auditoria atual: **100% das actions admin** têm `authorize!`/`load_and_authorize_resource`/`skip_authorization_check` — sem lacuna hoje, mas o safety net é frágil para regressões futuras.
2. **CSRF inconsistente entre fluxos de login:** `Admin::SessionsController#create` (`/login`) faz `skip_before_action :verify_authenticity_token` (pré-existente — git blame commit `1229f95`, jul/2026), enquanto `/u/sign_in` exige CSRF. Não reproduzível no ambiente de teste (`allow_forgery_protection = false`); risco de segurança em produção fica fora de cobertura de teste — candidato a verificação manual/QA em ambiente real.
3. **Recoverable por email vs autenticação por username:** `reset_password_within = 6.hours` e o fluxo é 100% baseado em email, mas a autenticação primária é por username/CPF e a maioria dos usuários não possui email cadastrado — a funcionalidade "esqueci minha senha" tem cobertura real baixa (além de estar quebrada pelo Bug 1).
4. **Probe removido:** o arquivo `bugfinder_23_probe_test.rb` foi apagado após a coleta de evidências; a suíte completa re-rodada **sem ele** confirma baseline intacto (691/2169/1).

---

## Cenários Testados (sem bugs)

| Cenário | Resultado |
|---------|-----------|
| Suíte completa `bin/rails test` (baseline pós-remoção do probe) | 691 runs / 2169 asserts / 1 falha de timezone pré-existente genuína (documentada na 23.10) |
| Gestor tenta DESTROY de regime com frequentadores vinculados (H28) | Negado (AccessDenied → redirect dashboard + flash alert), mesmo com DeleteRestriction ativo |
| Convidado (guest) acessa `/admin/dashboard` (H27) | Redirect para `/login` |
| PATCH `/u/password` com token de reset válido (H6) | Nova senha definida e reautentica com sucesso |
| POST `/u/sign_in` com usuário sem `encrypted_password` (nil literal) (H5) | Falha limpa (422), sem exceção BCrypt |
| POST `/u/password` com email desconhecido (teste oficial 23.8) | Re-renderiza `new` com erro, sem envio |
| Requisição a recurso `load_and_authorize_resource` sem `:id` (H25) | 400 ParameterMissing limpo, sem 500 |
| Matriz RN05/RN06 por perfil (`authorization_matrix_test.rb`) | Verdes (guest/gestor/operador/admin-role/autenticado-sem-role) |
| Sessão legada × Devise: /login e /u/sign_in coexistem (testes 23.6 + 1 assert 23.10) | Verdes |
| Integração Devise→CanCan com role (2 testes novos 23.10) | Verdes |
| Seeds idempotentes + dual-write + backfill (seeds_test.rb) | Verdes |
| Auditoria de cobertura de autorização em todos os 15 controllers admin | Nenhuma action sem authorize!/loader/skip |

---

## Veredito Final

**6 bugs** (1 crítico, 2 altos, 1 médio, 2 baixos) + 3 observações estruturais. O núcleo da Sprint 23 — matriz de autorização CanCanCan/Rolify, seeds, sync de sessão no login, integração Devise→CanCan — está **correto e bem testado** (691 verdes com a única falha pré-existente de timezone, genuína e documentada).

**Prioridade de correção (recomendada ao Code Specialist):**
1. **Bug 1 (🔴)** — desbloquear a rota pública de recuperação: ou falha limpa sem 500, ou remoção consciente da feature da UI enquanto ActionMailer não for montado. **Antes do merge da 23.8/23.10.**
2. **Bug 2 (🟠)** — guard para hash ausente/vazio/inválido em `valid_password?` e `authenticate` (cobre Pessoas2 read-only e contas legadas pré-Devise). Backfill do seed também é opção para contas do banco local.
3. **Bug 3 (🟠)** — revalidar `status`/`active_for_authentication?` em `current_user` (revogação de acesso efetiva).
4. **Bug 4 (🟡)** — sincronizar `session[:user_id]` após autenticação por remember cookie (ou desativar o checkbox).
5. **Bugs 5/6 (🟢)** — `can?` nas views + guard de `signed_in?` legado — melhorias de UX de baixo custo.

**Sinalização ao CTO (padrões recorrentes):** (a) os fluxos Devise e o contrato de sessão legado (`session[:user_id]`) coexistem como duas autoridades de sessão sem ponte — origina os bugs 3, 4 e 6; recomenda-se ADR de unificação de sessão (Warden como fonte única + sync bidirecional). (b) Testes com stub em `passwords_controller_test.rb` mascaram rota publicamente quebrada — recomenda-se política: mocks só quando a dependência real estiver documentada como débito com teste de "falha limpa" paralelo.

---

## Status de Correção (2026-09-21)

Correções implementadas pelo Code Specialist **sem commit/merge/push** (`COMMIT_MODE=manual`, branch de demanda já ativa).

| ID | Severidade | Status | Correção | Testes de regressão |
|----|-----------|--------|----------|---------------------|
| B1 | 🔴 Crítico | ✅ Corrigido | Degradação controlada em `Users::PasswordsController#create` (rescue `NameError` com `e.name == :Mailer` → `set_flash_message!(:alert, :mail_unavailable)` + redirect para login; nunca 500). **Decisão: opção (b)** — ActionMailer NÃO habilitado (exigiria SMTP/env/views de mailer = infra, fora da correção mínima). Caminho sendável preservado 100% Devise: quando o mailer for montado, `super` dispara o e-mail real sem mudança neste controller. Stub de `User.send_reset_password_instructions` removido do teste 23.8 — teste do comportamento real, sem máscara. Chave `devise.passwords.mail_unavailable` adicionada (pt-BR). | `passwords_controller_test.rb`: "POST /u/password com email conhecido sem ActionMailer degrada limpo (redirect + alert, sem 500)" |
| B2 | 🟠 Alto | ✅ Corrigido | Helper privado `remote_password_hash` em `User` (guard `blank?` para user/hash + `rescue BCrypt::Errors::InvalidHash → nil`), usado em `authenticate` e `valid_password?` — hash nulo/vazio/corrompido vira falha limpa (`false`), nunca 500. Fluxo local (`super`) e link Pessoas2 (CPF) preservados. | `user_test.rb`: 4 testes B2 (hash nil/""/corrompido/senha errada); `sessions_controller_test.rb`: 2 testes B2 (login Devise com hash nulo/corrompido → 422 + alert) |
| B3 | 🟠 Alto | ✅ Corrigido | `Admin::ApplicationController#current_user` revalida `status == 1` a cada request nas duas fontes de sessão (legada e Warden); conta desativada → `revoke_admin_session!` (limpa `session[:user_id]` + `warden.logout`) → redirect login. Sem alteração em `active_for_authentication?`/Ability. | `sessions_controller_test.rb`: 2 testes B3 (desativado pós-login Devise e pós-login legado → redirect login + `session[:user_id]` nil) |
| B4 | 🟡 Médio | ✅ Corrigido | Mesmo `current_user`: quando `session[:user_id]` vazio, `request.env["warden"].authenticate(scope: :user)` (fast path sessão ou strategy rememberable) com status ativo → **sincroniza `session[:user_id]`** → o acesso admin persiste via cookie remember; inativo → revoga. | `sessions_controller_test.rb`: 2 testes B4 (acesso direto ao dashboard após sessão limpa; fluxo `/u/sign_in` → follow redirect → dashboard com conteúdo) |
| B5 | 🟢 Baixo | ⏸️ Débito aceito | `can?` nas views de estacoes/regimes/versoes — fora do escopo das correções (UX; backend já nega). Registrar como dívida técnica para sprint futura. | — |
| B6 | 🟢 Baixo | ⏸️ Débito aceito | Guard de `signed_in?` legado no Devise — fora do escopo das correções (UX). Registrar como dívida técnica para sprint futura. | — |

**Evidência:** suíte completa `bin/rails test` → **701 runs / 2213 asserts / 1 falha** (única falha = timezone pré-existente documentada, `presenca_endpoints_test.rb:187`); `bin/rails zeitwerk:check` → "All is good!"; RuboCop → 6 arquivos alterados, sem offenses. Baseline anterior: 691/2169/1 — +10 testes, +44 asserts, nenhuma falha nova.

**Notas de decisão registradas:**
- B1: o `reset_password_token` gerado antes da falha é inócuo (nunca chega ao usuário sem e-mail) e é substituído a cada nova solicitação — limpeza manual não implementada (mínimo, trade-off documentado).
- B1: `set_flash_message!` usa o scope de tradução `devise.passwords` (chave `mail_unavailable` em `config/locales/devise.pt-BR.yml`).
- B3/B4: `current_user` memoiza com `defined?(@current_user)` (nil memoizado evita re-rodar `warden.authenticate` a cada request); o fast path `warden.user` do `_perform_authentication` (Warden 1.2.9) devolve o usuário da sessão Warden sem re-rodar strategies.
- B4: cenário do relatório (GET `/u/sign_in` → 302 dashboard) funcionava por `require_no_authentication` + `no_input_strategies=[:rememberable]`; a ponte faltante era o sync no contexto admin — agora coberto nos dois caminhos.

> **Rastreabilidade:** registrar em `docs/progress/iteration_23.md` (seção `## 📋 Relatório de Bugs — Iteração 23 — Code Specialist`) com link para este arquivo.