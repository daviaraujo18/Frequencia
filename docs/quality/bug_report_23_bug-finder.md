# Relatório Bug Finder — Iteração 23 — Bug Finder (2ª rodada, independente)

> **Branch:** feat/cancancan-controller-integration
> **Data:** 2026-09-21
> **Propósito:** Segunda rodada de testes adversariais da Sprint 23 (Devise 5.0.4 + CanCanCan 3.6.1 + Rolify 6.0.1), independente do auto-teste do Code Specialist. Objetivos: (a) validar se as correções B1-B4 registradas em `bug_report_23_cs.md` realmente fecham os cenários (não apenas documentadas); (b) procurar bugs novos na interação Devise × CanCanCan × Rolify × autenticação legada Pessoas2.
> **Tarefas revisadas/testadas:** 23.3 (auth Devise + coexistência has_secure_password), 23.4 (Rolify), 23.5 (Ability), 23.6 (rotas/controllers Devise, valid_password?/authenticate/active_for_authentication?), 23.7 (CanCanCan nos controllers), 23.8 (views/recoverable), 23.9 (seeds), 23.10 (fechamento) + correções pós-Bug Finder (B1-B4) do Code Specialist
> **Arquivos alterados:** nenhum código de produção alterado — probe temporário `test/integration/bugfinder_23_probe_test.rb` (9 casos) criado e **removido ao final**; suíte completa re-rodada sem ele para confirmar baseline intacto (701/2213/1)

---

## Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 9 (probe direcionado a B1-B4 + 5 hipóteses novas) + 701 (suíte completa) |
| Bugs encontrados | 2 |
| 🔴 Crítico | 0 |
| 🟠 Alto | 2 |
| 🟡 Médio | 0 |
| 🟢 Baixo | 0 |
| ⚪ Info | 1 |

**Resultado da validação de B1-B4 (bug_report_23_cs.md):** as 4 correções (recoverable sem 500, hash Pessoas2 nulo/inválido, revogação de sessão desativada, remember_me sincronizado) **se confirmaram efetivas** nos testes reais (não apenas documentadas) — incluindo um cenário adicional não coberto pelo relatório original (logout explícito com `remember_me` ativo não reautentica sozinho no request seguinte). B5/B6 permanecem como débito aceito, sem mudança.

## Bugs por Severidade

### 🟠 Alto

#### Bug 1 — `Pessoas::User.buscar_por_cpf` sem tratamento de exceção de conexão gera 500 em login (Devise e legado)

- **Severidade:** 🟠 Alto
- **RF/RN violado:** RN de disponibilidade de Auth — "autenticação via CPF (Pessoas2) deve continuar funcionando" (Riscos da Sprint 23); a correção B2 do Code Specialist tratou hash ausente/inválido, mas não erro de conexão/infra com o banco espelho do Pessoas2.
- **Passos:**
  1. Usuário com `cpf` tenta login por `POST /u/sign_in` (ou `/login` legado).
  2. `User#valid_password?` (`app/models/user.rb:150`) chama `Pessoas::User.buscar_por_cpf(cpf)`.
  3. O banco/mirror do Pessoas2 está indisponível (`ActiveRecord::ConnectionNotEstablished` ou qualquer erro de rede/timeout).
- **Atual:** a exceção propaga sem rescue até o controller → **HTTP 500** para qualquer usuário integrante tentando logar enquanto o Pessoas2 estiver fora do ar. Comprovado por teste com stub de `Pessoas::User.buscar_por_cpf` levantando `ActiveRecord::ConnectionNotEstablished`: `valid_password?` propaga a exceção (stacktrace: `user.rb:150` → `sessions_controller.rb:43`). O helper `remote_password_hash` (correção B2) só trata `blank?` do resultado e `BCrypt::Errors::InvalidHash` — não envolve a chamada a `Pessoas::User.buscar_por_cpf` em `rescue`, então qualquer exceção de infraestrutura (conexão recusada, timeout, `ActiveRecord::StatementInvalid` etc.) ainda derruba a requisição. O mesmo padrão existe em `authenticate` (fluxo legado `/login`, `Admin::SessionsController`), que também chama `remote_password_hash(Pessoas::User.buscar_por_cpf(cpf))` sem proteção contra falha de conexão.
- **Esperado:** falha de infraestrutura no Pessoas2 deve resultar em falha de login limpa (redirect/alert "tente novamente" ou "serviço indisponível"), nunca 500 — mesmo padrão de degradação aplicado ao B2 (hash ausente/inválido) deveria cobrir também erros de conexão/timeout na consulta ao mirror.
- **Teste sugerido:** stubar `Pessoas::User.buscar_por_cpf` para levantar `ActiveRecord::ConnectionNotEstablished` (ou `PG::ConnectionBad`) e fazer `POST /u/sign_in` com usuário `cpf` presente → esperado `422`/redirect com alert, não exceção. Mover a chamada a `Pessoas::User.buscar_por_cpf` para dentro do `begin/rescue` de `remote_password_hash` (ou envolver com `rescue ActiveRecord::ActiveRecordError`/`StandardError` documentado).

### 🟠 Alto — Info de segurança elevado a bug

#### Bug 2 — Enumeração de contas via `POST /u/password` (paranoid mode desabilitado)

- **Severidade:** 🟠 Alto
- **RF/RN violado:** RN de proteção de dados pessoais/segurança do fluxo recoverable (task 23.8) — endpoint público (`/u/password`, sem autenticação) deve tratar emails conhecidos e desconhecidos de forma indistinguível.
- **Passos:**
  1. `POST /u/password` com `user[email]` de uma conta existente (com email cadastrado).
  2. `POST /u/password` com `user[email]` inexistente.
  3. Comparar o status HTTP das duas respostas.
- **Atual:** email conhecido → **302** (redirect para `new_user_session_path` com notice "instruções enviadas"); email desconhecido → **422** (re-render do form com erro "não encontrado"). A diferença de status/comportamento permite a um atacante externo (rota não exige autenticação) enumerar quais emails estão cadastrados no sistema, testando um a um. `config.paranoid` está comentado/desabilitado em `config/initializers/devise.rb:116`.
- **Esperado:** `config.paranoid = true` (ou lógica equivalente no controller custom) para que ambos os casos retornem a mesma resposta (redirect + mensagem genérica "se o e-mail existir, você receberá instruções"), independentemente de o email existir.
- **Teste sugerido:** `POST /u/password` com email cadastrado e com email aleatório inexistente → `assert_equal` nos dois status HTTP (hoje: 302 vs 422, comprovado em teste).
- **Nota de contexto:** o próprio `bug_report_23_cs.md` (observação ⚪ #3) já registrava que a cobertura real do recoverable é baixa (login é por username, poucos usuários têm email) — isso reduz a superfície prática de exploração, mas não elimina o problema para as contas que têm email (ex.: admins locais).

## Observações (⚪ Info)

1. **CSRF inconsistente entre fluxos de login (reconfirmado):** `Admin::SessionsController#create` (`/login`) pula `verify_authenticity_token`, enquanto `/u/sign_in` exige CSRF — já registrado no `bug_report_23_cs.md` como fora de cobertura de teste automatizado; reafirmado nesta rodada sem mudança de status (ainda candidato a verificação manual em ambiente real, `allow_forgery_protection = false` em test).

## Cenários Testados (sem bugs)

| Cenário | Resultado |
|---------|-----------|
| Suíte completa `bin/rails test` (baseline pós-remoção do probe) | 701 runs / 2213 asserts / 1 falha de timezone pré-existente genuína (mesma da 23.10) |
| **B1 revalidado:** `POST /u/password` com email conhecido, sem stub de mailer, ambiente real (ActionMailer não montado) | Redireciona limpo (sem 500) — correção efetiva |
| **B2 revalidado:** login Devise com `cpf` presente e `encrypted_password` vazio (`""`) no registro Pessoas2 | 422 limpo, sem `BCrypt::Errors::InvalidHash` — correção efetiva |
| **B3 revalidado:** usuário autenticado via `/login` legado, desativado (`status = 0`) em seguida, novo `GET /admin/dashboard` | Redirect para `/login` — sessão revogada corretamente |
| **B4 revalidado:** login via `/u/sign_in` com `remember_me=1`, acesso subsequente ao dashboard | `session[:user_id]` sincronizado, acesso mantido |
| **Novo — logout explícito com remember_me ativo:** login com remember_me, `DELETE /logout`, novo `GET /admin/dashboard` | Redirect para `/login` — o cookie de remember NÃO reautentica sozinho após logout explícito (hipótese de regressão pela correção B4 descartada; `Devise::Hooks::Forgetable` + `sign_out` funcionam corretamente mesmo com a fonte de sessão dupla legado×Warden) |
| **Novo — role removida em runtime:** usuário ganha role `:gestor`, loga, role é removida via `remove_role`, novo request a tela de leitura | `Ability` recalculada por request corretamente — sem permissão residual/cache indevido |

## Veredito Final

**2 bugs novos** (ambos 🟠 Alto) encontrados nesta segunda rodada, além de **validação positiva** das 4 correções B1-B4 do Code Specialist (efetivas de fato, não apenas documentadas) e descarte de duas hipóteses de regressão (logout×remember, cache de role/Ability).

O núcleo estrutural da Sprint 23 (matriz CanCanCan/Rolify, sync de sessão, revogação por status, seeds) permanece **sólido**. As duas lacunas remanescentes são de **robustez de integração** (Bug 1 — exceção de conexão com o Pessoas2 não tratada) e de **segurança do fluxo público de recuperação de senha** (Bug 2 — enumeração de contas por diferença de status HTTP).

**Prioridade de correção recomendada:**
1. **Bug 1 (🟠)** — envolver a consulta a `Pessoas::User.buscar_por_cpf` em `rescue` (mesmo padrão do guard B2) tanto em `valid_password?` quanto em `authenticate` — evita que uma instabilidade de infraestrutura do Pessoas2 derrube o login com 500 (login por CPF é o RF-01 de risco alto da sprint).
2. **Bug 2 (🟠)** — habilitar `config.paranoid = true` no `devise.rb` (mudança de baixo risco, comportamento padrão recomendado do Devise) para eliminar a enumeração de contas via `/u/password`.

**Sinalização ao CTO:** o padrão recorrente identificado é que os *guards* de robustez (B2 do Code Specialist) foram desenhados para os sintomas observados no teste anterior (hash nulo/inválido), mas não generalizados para "qualquer falha na integração com o Pessoas2" (conexão, timeout, erro de schema) — recomenda-se que testes de integração com serviços/bancos externos incluam sistematicamente um cenário de "serviço fora do ar" (exceção de conexão), não só "dado malformado retornado", como categoria própria do checklist de `structural-conformity-checklist`/`adversarial-testing-strategy` para todas as integrações do Frequencia com Pessoas2 (não só auth).

---

## Metodologia

Testes escritos como probes de integração (`ActionDispatch::IntegrationTest`) contra o app real (`Frequencia/api-ponto`), exercitando rotas HTTP reais (`/u/sign_in`, `/u/password`, `/login`, `/logout`, `/admin/dashboard`, `/estacoes`) com stubs pontuais de `Pessoas::User.buscar_por_cpf` (mesmo padrão dos testes oficiais da sprint) para simular hash ausente, hash inválido, falha de conexão e sucesso. Nenhum código de produção foi alterado; o probe foi removido ao final e a suíte completa (701 runs) foi re-executada para confirmar que nenhuma regressão foi introduzida pelo processo de teste.
