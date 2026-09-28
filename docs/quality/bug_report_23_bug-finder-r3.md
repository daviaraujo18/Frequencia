# Relatório Bug Finder — Iteração 23 (3ª rodada) — Frequência

> **Branch:** `feat/cancancan-controller-integration`
> **Data:** 2026-09-21
> **Propósito:** 3ª rodada de teste adversarial independente sobre a Sprint 23 (Devise + CanCanCan + Rolify — Autenticação + Autorização), focada em validar as correções pós-2ª rodada (B7/B8) e procurar bugs novos na interação `paranoid` × recoverable × sessão legada × login `/login` (CPF/Pessoas2).
> **Tarefas testadas:** 23.1–23.10 (fechadas), com foco nas correções registradas na seção "Correções pós-Bug Finder (2ª rodada)" do `iteration_23.md`.
> **Arquivos analisados:** `app/models/user.rb`, `app/controllers/users/passwords_controller.rb`, `app/controllers/users/sessions_controller.rb`, `app/controllers/admin/sessions_controller.rb`, `app/controllers/admin/application_controller.rb`, `config/initializers/devise.rb`, `config/locales/devise.pt-BR.yml`, `config/application.rb`, `test/controllers/users/passwords_controller_test.rb`, `test/models/user_test.rb`, `test/controllers/sessions_controller_test.rb`, `test/controllers/users/sessions_controller_test.rb`, gem `devise-5.0.4` (`passwords_controller.rb`, `models/recoverable.rb`, `controllers/responder.rb`, `app/controllers/devise_controller.rb`).
> **Arquivos alterados por este agente:** nenhum arquivo de produção. Um probe temporário (`test/integration/bf_probe_test.rb`) foi criado, executado e **removido** ao final; a suíte foi revalidada no baseline exato antes e depois.

## Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 14 |
| Bugs encontrados | 1 |
| 🔴 Crítico | 0 |
| 🟠 Alto | 1 |
| 🟡 Médio | 0 |
| 🟢 Baixo | 0 |
| ⚪ Info | 1 |

**Baseline antes e depois dos probes:** `bin/rails test` → **706 runs / 2226 assertions / 1 failure / 0 errors** (idêntico ao baseline documentado na 23.10/pós-2ª rodada; a única falha é a pré-existente de timezone em `presenca_endpoints_test.rb:187`, fora do escopo da Sprint 23).

## Validação Independente de B7 e B8 (não assumida pela documentação)

### B7 — `Pessoas::User.buscar_por_cpf` sem rescue de exceção de conexão

**Status: CONFIRMADO CORRIGIDO.** Lido `app/models/user.rb`: o método privado `remote_password_hash_by_cpf(cpf)` envolve `Pessoas::User.buscar_por_cpf(cpf)` em `rescue ActiveRecord::ActiveRecordError, PG::Error => e` (com log via `Rails.logger.error`), retornando `nil` em caso de falha de infraestrutura. É chamado tanto em `authenticate` (fluxo legado `/login`) quanto em `valid_password?` (fluxo Devise `/u/sign_in`) — um único ponto de rescue, sem duplicação. Testes reais (sem stub que mascare) existem em `test/models/user_test.rb` (`ActiveRecord::ConnectionNotEstablished`, `ActiveRecord::StatementInvalid`), `test/controllers/sessions_controller_test.rb` e `test/controllers/users/sessions_controller_test.rb` — todos verdes na suíte completa.

### B8 — Enumeração de contas via `POST /u/password`

**Status: PARCIALMENTE CORRIGIDO — nova assimetria encontrada (ver Bug 9 abaixo).** `config.paranoid = true` está de fato habilitado em `config/initializers/devise.rb:121`. Confirmado por probe que o **HTTP status é idêntico** (303 `see_other`) para email conhecido e desconhecido — a correção original do relatório da 2ª rodada (diferença 302/303 vs 422) está de fato fechada. Porém, ao investigar a fundo o item (b) desta missão, foi identificada uma **assimetria de conteúdo/tipo de flash** que reabre a mesma classe de vulnerabilidade por outro canal (ver Bug 9).

### Item (c) — Especificidade do rescue de B7

**Status: CONFORME.** `rescue ActiveRecord::ActiveRecordError, PG::Error` é específico o suficiente — não é um `rescue StandardError` genérico. Confirmado por leitura: qualquer erro de programação genuíno (ex.: `NoMethodError` se `Pessoas::User` devolvesse um objeto sem `encrypted_password`, ou um `NameError` de código quebrado) **não seria capturado** por este rescue e propagaria normalmente. Isso é o comportamento correto — o rescue existe para blindar contra falhas de infraestrutura (conexão/timeout com o mirror Pessoas2), não para mascarar bugs de programação. Nenhum teste foi necessário para provar isso (é uma leitura direta da classe de exceção), mas a inspeção da classe `PG::Error` e da hierarquia `ActiveRecord::ActiveRecordError` confirma que `NoMethodError`/`NameError`/`TypeError` ficam de fora do rescue.

## Bugs por Severidade

## Bug 9 — Assimetria de flash (tipo + texto) entre email conhecido e desconhecido em `POST /u/password` reabre a enumeração de contas que o `paranoid` deveria eliminar

- Severidade: 🟠 Alto
- RF/RN violado: RN de proteção de dados pessoais/segurança do fluxo recoverable (task 23.8), a mesma regra do B8 original — "endpoint público (`/u/password`, sem autenticação) deve tratar emails conhecidos e desconhecidos de forma indistinguível". A correção do B8 tratou apenas o status HTTP, não o conteúdo da resposta.
- Passos:
  1. Ter um usuário existente com `email` preenchido (ex.: `probe.paranoid@tjpi.jus.br`).
  2. `POST /u/password` com `user[email]` = email existente, em uma sessão nova.
  3. Observar a resposta: redirect 303 para `/u/sign_in` com `flash[:alert]` = *"Não foi possível enviar o e-mail de recuperação de senha (serviço de e-mail não configurado). Entre em contato com o administrador do sistema."* (chave `devise.passwords.mail_unavailable`, renderizada como `<div class="alert alert-danger">` com ícone de alerta, em `users/sessions/new.html.erb`).
  4. `POST /u/password` com `user[email]` = email inexistente, em outra sessão nova.
  5. Observar a resposta: redirect 303 para `/u/sign_in` com `flash[:notice]` = *"Se seu e-mail existir em nosso banco de dados, você receberá um e-mail com um link para redefinir sua senha."* (chave `devise.passwords.send_paranoid_instructions`, renderizada como `<div class="alert alert-success">` com ícone de confirmação).
- Atual: o status HTTP é idêntico (303) nos dois casos — mas a **cor do alerta** (vermelho "alert-danger" vs. verde "alert-success"), o **ícone** (triângulo de alerta vs. círculo de confirmação) e o **texto completo da mensagem** são diferentes e diretamente observáveis por qualquer visitante não autenticado, sem precisar inspecionar headers/status HTTP. Isso porque, nesta aplicação, o ActionMailer **nunca está montado** (`config/application.rb:10`, `# require "action_mailer/railtie"` comentado) — logo, **todo** email conhecido cai sempre no `rescue NameError` do B1 (nunca no caminho "sucesso real" que usaria `:notice, :send_instructions`), tornando o par de mensagens 100% determinístico e diferenciável: "alerta vermelho de erro" = email existe; "aviso verde genérico" = paranoid (pode ou não existir). Um atacante consegue enumerar contas cadastradas observando apenas a cor/ícone/texto do flash, sem qualquer necessidade de inspecionar o código de status.
- Esperado: as duas respostas deveriam ser **indistinguíveis** também no conteúdo — mesmo tipo de flash (`:notice`, não `:alert`) e mesma mensagem genérica (ex.: a própria `send_paranoid_instructions`) nos dois casos, exatamente como o modo `paranoid` do Devise pretende garantir quando corretamente configurado (o modo paranoid foi desenhado presumindo que o e-mail real seria enviado em ambos os casos "com sucesso"; aqui a falha do mailer quebra essa premissa porque o rescue de B1 intercepta ANTES de `successfully_sent?` rodar para o caso "conhecido").
- Teste sugerido: um teste de integração que faça duas requisições `POST /u/password` em **sessões independentes** (`reset!` entre elas — testes existentes reusam a mesma sessão/flash e mascaram a diferença) — uma com email existente, outra com email inexistente — e assirtam `flash[:alert].present? == flash[:alert_da_outra_requisição].present?` e `flash[:notice].present? == flash[:notice_da_outra_requisição].present?`, além de comparar o texto. O teste `"POST /u/password com email conhecido e desconhecido retornam o mesmo status HTTP (Bug 2)"` já existente em `passwords_controller_test.rb` só compara `response.status`/`response.redirect?` — nunca o conteúdo do flash — e por isso não detectou esta regressão. Correção mais simples/segura: no `rescue NameError` de `Users::PasswordsController#create`, usar a MESMA chave/tipo de flash que o caminho paranoid usaria em caso de sucesso (`set_flash_message!(:notice, :send_paranoid_instructions)` em vez de `:alert, :mail_unavailable`) — preservando o log interno do erro real (`Rails.logger`) para o administrador, sem vazar a diferença ao usuário final.

**Evidência (probe removido ao final, suíte revalidada em 706/2226/1):**
```
KNOWN   -> status=303 alert="Não foi possível enviar o e-mail de recuperação de senha (...)" notice=nil
UNKNOWN -> status=303 alert=nil notice="Se seu e-mail existir em nosso banco de dados, você receberá um e-mail com um link para redefinir sua senha."
```

## Observação ⚪ Info — "Email conhecido + mailer disponível" (caso i) é hoje inalcançável nesta aplicação

- Severidade: ⚪ Info (não é bug; documentação para o CTO/registro técnico)
- Contexto: o item (b) da missão pedia para confirmar que os 3 caminhos possíveis de `POST /u/password` (email conhecido+mailer OK / email conhecido+mailer indisponível / email desconhecido) são indistinguíveis. Na investigação, verificou-se que o **caso (i) não existe hoje**: como `action_mailer/railtie` está comentado em `config/application.rb:10`, `Devise::Mailer` é sempre uma constante inexistente — logo **todo** email conhecido cai deterministicamente no `rescue NameError` (caso ii). O código está preparado para o caso (i) (`super` completaria o fluxo normal quando o ActionMailer for habilitado, conforme comentário do controller), mas ele é inatingível no estado atual do deploy. Isso não é um bug — é uma decisão de escopo já documentada (task 23.8, débito "envio real de e-mail... fora do escopo") — mas reforça que o Bug 9 acima afeta **100% dos emails conhecidos** hoje, não um caso raro.
- Sinalização ao CTO: quando o ActionMailer for habilitado em sprint futura, o caso (i) passará a existir e produzirá `flash[:notice]` com a chave `:send_instructions` (texto "Você receberá um e-mail...", diferente de `send_paranoid_instructions`) — outra fonte potencial de assimetria de texto entre "mailer OK" e "paranoid", mesmo que ambas usem `:notice`. Recomenda-se, ao habilitar o mailer, unificar a chave de tradução usada nos 3 caminhos (ou aceitar formalmente a mensagem diferente como não-sensível, já que nesse cenário futuro AMBOS os casos (i) e (iii) seriam sucesso simulado indistinguível do ponto de vista do usuário puro, restando apenas o texto).

## Cenários Testados (sem bugs)

1. **B7 revalidado** — `authenticate`/`valid_password?` com `Pessoas::User.buscar_por_cpf` lançando `ActiveRecord::ConnectionNotEstablished`/`ActiveRecord::StatementInvalid`/`PG::Error` → falha limpa (`false`), nunca 500. Confirmado por leitura de código e pelos testes existentes (verdes na suíte completa).
2. **B8 (status HTTP) revalidado** — `POST /u/password` com email conhecido vs. desconhecido → mesmo status HTTP 303 nos dois casos (confirmado por probe com sessões independentes).
3. **Especificidade do rescue de B7 (item c)** — `rescue ActiveRecord::ActiveRecordError, PG::Error` não captura `NoMethodError`/`NameError`/`TypeError` — bugs de programação genuínos continuariam propagando (não mascarados).
4. **Token de reset ainda funciona com `paranoid = true` (item d)** — probe confirmou que `set_reset_password_token` roda e persiste o hash do token em `reset_password_token` **antes** do `rescue NameError` interceptar a falha do mailer; o fluxo `PATCH /u/password` (`reset_password_by_token`) permanece funcional para quem obtiver o token por outro canal (ex.: suporte manual) — `paranoid` não interfere no `update`, apenas em `successfully_sent?` do `create`.
5. **`see_other` (303) não quebra nenhum teste que espere 302** — busca por `302`/`:found` hardcoded nos testes de `users/passwords`/`sessions`/`presenca` não encontrou nenhuma expectativa incompatível; único hit é um comentário histórico, não uma asserção.
6. **Regressão no login legado `/login` (`Admin::SessionsController`)** — `authenticate` (chamado por `user&.authenticate(params[:password])`) usa o mesmo `remote_password_hash_by_cpf` de B7; já coberto por teste dedicado (`sessions_controller_test.rb`, cenário `ConnectionNotEstablished`), verde na suíte. Login local (sem `cpf`, via `super`/`password_digest`) não foi alterado por nenhuma das correções B7/B8 — caminho intocado.
7. **PATCH `/u/password` com token inválido** — continua re-renderizando `edit` com `422`/`.alert-danger` (comportamento padrão do Devise), sem qualquer interferência do `paranoid` (que só afeta `create`).
8. **GET `/u/password/new` e `/u/password/edit`** — views renderizam normalmente, sem qualquer alteração de comportamento pelas correções B7/B8.
9. **`config.responder.redirect_status = :see_other`** — confirmado como o mecanismo que também governa o redirect paranoid via `respond_with` (gem `devise/controllers/responder.rb`), garantindo que o status do caminho paranoid (`case iii`) e do rescue manual de B1 (`case ii`, ajustado nesta correção) batem em 303 — o ajuste de status feito pelo Code Specialist foi necessário e correto.
10. **Suíte completa antes/depois dos probes** — 706 runs / 2226 assertions / 1 failure (idêntico ao baseline documentado; nenhuma regressão introduzida pela investigação).
11. **`rubocop`/`zeitwerk` não avaliados nesta rodada** — não houve alteração de código de produção; não se aplica.
12. **Caso (i) "email conhecido + mailer disponível"** — confirmado inatingível no deploy atual (ActionMailer não montado); ver Observação Info acima.
13. **Fluxo Devise × sessão legada (regressão cruzada)** — não foi alterado por B7/B8; testes de `users/sessions_controller_test.rb` (gestor/admin via `/u/sign_in`) seguem verdes.
14. **CSRF inconsistente entre `/login` e `/u/sign_in`** — reconfirmado como já registrado (2ª rodada, `bug_report_23_bug-finder.md`), sem mudança de status; fora do escopo desta rodada (nenhuma correção B7/B8 tocou CSRF).

## Veredito Final

As correções B7 e B8 da 2ª rodada são **efetivas no que se propuseram a resolver**: B7 elimina o 500 por falha de infraestrutura do Pessoas2 (login CPF e Devise), e B8 elimina a diferença de **status HTTP** entre email conhecido/desconhecido em `POST /u/password`. Nenhuma regressão foi introduzida nos fluxos legado (`/login`) ou Devise (`/u/sign_in`), e o fluxo de token de reset (`PATCH /u/password`) permanece íntegro sob `paranoid = true`.

Porém, a correção de B8 tratou apenas a dimensão de **status HTTP**, deixando aberta uma dimensão igual ou mais fácil de explorar — o **conteúdo e tipo do flash** — que hoje distingue determinística e visivelmente (cor, ícone, texto) todo email conhecido de todo email desconhecido. Como o ActionMailer nunca está montado nesta aplicação, essa assimetria não é um caso de borda raro: é o comportamento de **100%** das submissões com email cadastrado. Isso reabre, por um canal diferente (UI em vez de status code), exatamente a vulnerabilidade de enumeração de contas que a task 23.8/B8 se propôs a fechar.

**Recomendação de prioridade:** corrigir o Bug 9 antes de considerar o fluxo recoverable pronto para produção — é uma correção pequena e localizada (unificar a chave de flash usada no `rescue NameError` de `Users::PasswordsController#create` com a chave usada pelo caminho paranoid), sem necessidade de habilitar ActionMailer. Recomenda-se também atualizar o teste `"POST /u/password com email conhecido e desconhecido retornam o mesmo status HTTP (Bug 2)"` para também comparar o conteúdo/tipo do flash (não só o status), fechando a lacuna de cobertura que permitiu esta regressão passar despercebida por duas rodadas de teste adversarial anteriores.
