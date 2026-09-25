# Relatório Bug Finder — Iteração 23 (5ª rodada) — Frequência

> **Branch:** `fix/bug10-recoverable-timing-sidechannel`
> **Data:** 2026-09-23
> **Propósito:** 5ª rodada de teste adversarial independente sobre a Sprint 23, focada no **phantom work do Bug 10** (`Users::PasswordsController#create`, correção do code-specialist): side-effects, falsa paridade, cenários em que o timing ainda vaza, impacto quando o ActionMailer for habilitado, transações sob concorrência e edge cases de email (uppercase, unicode, blank, nil, flood). Foco secundário: regressões das tasks 23.1–23.9.
> **Tarefas testadas:** 23.1–23.10, com foco no patch Bug 10 (arquivos `app/controllers/users/passwords_controller.rb` e `test/controllers/users/passwords_controller_test.rb`).
> **Arquivos analisados:** `app/controllers/users/passwords_controller.rb` (patch), `test/controllers/users/passwords_controller_test.rb` (teste de paridade), `app/models/user.rb`, `config/initializers/devise.rb`, `config/locales/devise.pt-BR.yml`, `config/routes.rb`, `app/controllers/admin/users_controller.rb` (strong params — auditoria de writer de email), `db/seeds.rb`, gem `devise-5.0.4` (`app/controllers/devise_controller.rb`, `lib/devise/models/recoverable.rb`, `lib/devise/models/authenticatable.rb`, `lib/devise/token_generator.rb`, `lib/devise/models/validatable.rb`), banco dev (consulta read-only de emails), `docs/quality/bug_report_23_bug-finder-r4.md`.
> **Arquivos alterados por este agente:** nenhum arquivo de produção nem teste existente. Um probe temporário (`test/integration/bf_probe_r5_test.rb`, 9 cenários / 60 asserts) foi criado, executado e **removido**; a suíte foi revalidada no baseline exato depois.

## Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 9 (probe) + 707 (suíte completa) |
| Bugs encontrados | 0 (nenhum Crítico/Alto — ver Observações) |
| 🔴 Crítico | 0 |
| 🟠 Alto | 0 |
| 🟡 Médio | 2 (observações não-bloqueantes) |
| 🟢 Baixo | 1 (observação) |
| ⚪ Info | 2 |

**Baseline antes e depois do probe:** `bin/rails test` → **707 runs / 2232 assertions / 1 failure / 0 errors** (idêntico ao baseline documentado após a correção do Bug 10; a única falha continua sendo a pré-existente de timezone em `presenca_endpoints_test.rb:187`, fora do escopo da Sprint 23 — sem stack trace novo, sem falha nova).

## Bugs por Severidade (BUG_LEVEL=1)

Nenhum bug de severidade **Crítico ou Alto** foi encontrado nesta rodada. O phantom work do Bug 10 foi validado como **efetivo** na dimensão que se propôs a equalizar (paridade de queries e timing mediano known × unknown ≈ 0). Achados de severidade menor e latentes seguem como **Observações** (não bloqueiam a Sprint 23).

## Observações (🟡 Médio / 🟢 Baixo / ⚪ Info)

### Obs 1 — 🟡 Médio | Ausência de rate limiting / throttle em `POST /u/password` (flood) — amplificada pelas correções B9/Bug 10

- **RF/RN violado:** RN de proteção de dados pessoais/segurança do fluxo recoverable (task 23.8) — "endpoint público deve tratar emails conhecidos e desconhecidos de forma indistinguível **e não ser abusável**".
- **Passos:**
  1. Enviar 30 requisições `POST /u/password` alternando email conhecido/desconhecido (sessões isoladas).
  2. Medir status, contagem de queries, linhas de log e headers de rate limit.
- **Atual:** nenhum throttle em lugar algum da aplicação (grep por `rate_limit|rack_attack|throttle` → vazio). Cada request com email **conhecido** gera 1 `UPDATE` (rotação do `reset_password_token` + `reset_password_sent_at` + `updated_at`) **e 1 linha `Rails.logger.error`** com o email da vítima; cada email desconhecido roda o phantom (sem mutação). Em 30 requests: 303 estáveis, queries estáveis [5], **zero headers de rate limit** (`ratelimit`/`retry-after` ausentes). No cenário atual (sem ActionMailer, sem emails populados) o impacto prático é churn de log/DB; **quando o ActionMailer for habilitado (débito 23.8)**, o mesmo comportamento vira: (a) **inbox flooding** — cada request com email conhecido dispara um e-mail real de reset (`deliver_now`) para a vítima; (b) **reset-DoS** — a rotação de token a cada request invalida o link já enviado por e-mail antes da vítima clicar.
- **Esperado:** throttle no endpoint público (ex.: rack-attack: N requests/intervalo por IP ou por email), como prática padrão para endpoints de recuperação de senha (OWASP/ASVS).
- **Teste sugerido:** rajada de N+1 requests e assert de `429`/`Retry-After`; validação de que a rotação de token não invalida o link em voo quando o mailer estiver ativo.

### Obs 2 — 🟡 Médio (latente) | Quando o ActionMailer for habilitado, a paridade de timing do Bug 10 volta a quebrar — e o teste atual continuaria verde

- **RF/RN violado:** mesma RN do Bug 10 (paridade de trabalho entre email conhecido/desconhecido) — **condicionalmente**, no futuro.
- **Passos:**
  1. Leitura de `devise-5.0.4/lib/devise/models/authenticatable.rb` (`send_devise_notification`): o Devise 5.0.4 usa **`message.deliver_now`** (SMTP **síncrono**) por padrão.
  2. Simular mailer habilitado: `super` do caminho conhecido completa sem `NameError` → `resource.persisted?` é `true` → **o phantom work é pulado** (`unless resource.persisted?`); o caminho desconhecido roda phantom normalmente (4 queries).
- **Atual:** com mailer ligado, o caminho conhecido executa 5 queries + renderização do mailer + **round-trip SMTP síncrono** (centenas de ms), enquanto o desconhecido executa 5 queries. A paridade de timing (razão de existência do Bug 10) fica violada por **ordem de grandeza maior** do que o delta original de ~1-2ms — embora o teste "mesma quantidade de queries" continue passando (a contagem de queries não muda), dando falsa segurança.
- **Esperado:** ao habilitar ActionMailer (débito registrado na 23.8), re-executar a medição de timing/paridade; considerar `deliver_later` (ActiveJob) e/ou nível de throttle da Obs 1; atualizar o comentário do patch (hoje afirma "sem nenhuma alteração aqui" — verdade funcional, mas a invariante de segurança do Bug 10 não sobrevive ao `deliver_now`).
- **Teste sugerido:** após habilitar mailer, repetir o probe de timing (mediana/quantis) e o teste de queries — esperado: falha de paridade de tempo.

### Obs 3 — 🟢 Baixo | Invariante do Bug 10 incompleta para valores blank/whitespace: 4 queries vs 5 (~0.9ms mais rápido)

- **RF/RN violado:** RN do Bug 10 — o teste de paridade só cobre known × unknown; blank/whitespace não são cobertos.
- **Passos:**
  1. `POST /u/password` com `user[email]=""` e com `user[email]="   "`.
  2. Contar queries (`sql.active_record`) e medir timing.
- **Atual:** blank e whitespace executam **4 queries** (caminho do Devise não faz SELECT por email — `find_or_initialize_with_errors` descarta valor blank — e o phantom roda mesmo assim: SELECT colisão + SAVEPOINT/UPDATE/RELEASE); known/unknown fazem **5**. Timing mediano: blank ≈ 4.3ms vs known/unknown ≈ 5.2-5.3ms (delta ~0.9ms). **Não é explorável para enumeração** (blank não é uma tentativa de conta; known × unknown continuam 5=5 com delta mediano ≈ 0.1ms — ruído), mas quebra a generalidade da invariante prometida ("5 = 5 queries") para entradas malformadas, e o teste do Bug 10 não detectaria se o phantom fosse removido amanhã para o caso blank.
- **Esperado:** estender a invariante a todos os formatos de entrada (ex.: forçar o SELECT de email mesmo para blank), ou registrar como débito aceito (impacto desprezível para enumeração).
- **Teste sugerido:** acrescentar ao teste do Bug 10 os casos `email: ""` e `email: "   "` asserindo mesma contagem de queries das demais entradas.

### Obs 4 — ⚪ Info | Cadeia de dependência: recuperação de senha é inoperante de ponta a ponta no ambiente real hoje (0 emails populados + 0 mailer + 0 writer)

- Consulta read-only no banco dev: **84 usuários, 0 com `email`**. `db/seeds.rb` não seta email; fixtures não têm email; `Admin::UsersController#user_params` **não permite email**; nenhum controller/import escreve email. Somado ao ActionMailer desmontado, o fluxo recoverable é funcional apenas em teste (emails fabricados). Os débitos são documentados em partes (mailer na 23.8; `email_required?` no model), mas a lacuna "nenhuma fonte populando email" não está explicitada como gargalo próprio. Sem isso, mesmo habilitando o mailer a feature continuará inoperante. **Sugestão ao CTO:** registrar como dependência explícita da evolução do recoverable (RF futura de cadastro/vinculação de email).

### Obs 5 — ⚪ Info | `POST /u/password` sem o parâmetro `user` responde 303 idêntico ao caminho blank (não 400/500) — comportamento seguro

- Probe com `post user_password_path` (sem `user[...]`): status **303** com flash paranoid igual ao demais — o `resource_params` do Devise não estoura `ParameterMissing` neste fluxo (caminho tratado como "sem chave de busca"). Consistente com a paridade obsessiva do restante; nenhum vazamento de informação.

## Cenários Testados (sem bugs — veredito ✅ salvo os apontados nas Observações)

| Cenário | Resultado |
|---------|-----------|
| Suíte completa `bin/rails test` (baseline antes e depois do probe) | 707 runs / 2232 assertions / 1 failure de timezone pré-existente (idêntico ao baseline pós-Bug 10) |
| **Paridade de queries pós-patch:** known (5) × unknown (5) — SELECT email + SELECT colisão token + SAVEPOINT/UPDATE/RELEASE nos dois | ✅ igual, SQL inventory byte-equivalente (única diferença: UPDATE conhecido inclui `updated_at`) |
| **Timing mediano known × unknown** (30 amostras interleaved, 2 execuções) | ✅ delta mediano ≈ −0.003ms a +0.096ms (ruído; sem vazamento consistente) |
| **Side-effects unknown/blank:** snapshot de todos os usuários (token/sent_at/encrypted_password/password_digest/updated_at) antes/depois | ✅ nenhuma linha alterada |
| **Side-effect known:** apenas a linha alvo muda (token rotacionado, 64 hex); senha (`encrypted_password` e `password_digest`) intacta | ✅ |
| **Flood** 15 known + 15 unknown interleaved: 303 estáveis, queries [5]=[5], 15 linhas de log (só known), 0 linhas unknown | ✅ (falta de throttle → Obs 1) |
| **Log injection** via email com `\n`: email desconhecido jamais loga; email conhecido loga 1 linha única; emails com `\n` não são cadastráveis (regex do validatable bloqueia `\s`) | ✅ inviável |
| **Edge: uppercase/mixed-case** (stored `Probe.R5.Mixed@TJPI.JUS.BR`): validatable normaliza (downcase) no save; submeter lowercase → match → token rotacionado | ✅ recovery funciona; sem bug |
| **Edge: unicode / long email (500 chars)** | ✅ 303 + 5 queries + mesmo flash (paridade) |
| **Edge: array `email[]` / hash `email[foo]`** | ✅ 303 + 5 queries (permit trata como não-escalar; paridade mantida) |
| **Edge: blank e whitespace** | 303 + mesmo flash, mas **4 queries** (→ Obs 3) |
| **Usuário inativo (status=0) com email conhecido** | ✅ paridade total com ativo (303/5/msm flash) — sem vazamento de status |
| **Fluxo completo de reset com token válido (PATCH):** senha trocada, token limpo, dual-write (`authenticate` + `valid_password?`) validando a nova senha, pós-login no dashboard (interação B4) | ✅ funcional |
| **Token expirado (7h > `reset_password_within` 6h):** 422, token preservado, senha antiga válida | ✅ |
| **Regressões tasks 23.1–23.9:** matriz de autorização CanCanCan/Rolify, seeds idempotentes, sessions Devise/legado — cobertas pelas 707 runs | ✅ sem regressão |
| **Conformidade estrutural:** phantom work dentro de `transaction(requires_new: true)` (SAVEPOINT/RELEASE simétrico ao save do Devise); sem caminho de saída antecipada; `UPDATE` em `id=-1` nunca altera dados; rescue `NameError` específico (`e.name == :Mailer`) preservado; nenhuma exceção de transação/rollback observada em 30+ requests | ✅ |
| **Concorrência (análise):** `update_all` em `id = -1` não toca linha alguma → sem lock contention entre requests paralelos; tokens concorrentes do caminho known seguem last-write-wins do Devise | ✅ (argumentado; sem race observável) |

## Veredito Final

O phantom work do Bug 10 foi validado **empiricamente efetivo** na dimensão que se propôs a corrigir: paridade de queries (5 = 5) e timing mediano known × unknown ≈ 0 ms, com **zero mutação de dados** nos caminhos desconhecidos e **zero regressão** na suíte (707/2232/1). Nenhum bug de severidade **Crítico ou Alto** foi encontrado — conforme `BUG_LEVEL=1`, nenhum bloqueador para a Sprint 23.

As 3 observações (2 🟡, 1 🟢) são **não-bloqueantes** e majoritariamente **latentes**:
- **Obs 1 (rate limit)** e **Obs 2 (mailer `deliver_now`)** formam uma dupla: a correção do Bug 10 só faz sentido no mundo "mailer desligado"; ao habilitar ActionMailer (débito 23.8), a paridade de timing quebra por SMTP síncrono E abre inbox flooding/reset-DoS sem throttle. **Prioridade de ação: vincular o débito "habilitar ActionMailer" a estas duas salvaguardas** (throttle + re-medição de paridade), antes de considerá-lo pronto.
- **Obs 3 (blank = 4 queries)** é cosmética para enumeração; corrigir apenas se o time quiser invariante total, com teste estendido.

Recomenda-se **encerrar o ciclo de bug-hunting sobre `POST /u/password`** na configuração atual (mailer desligado): as 5 rodadas cobriram status, flash, HTML, headers, cookies, token, log e timing (com e sem phantom). A próxima rodada só se justifica **após** a habilitação do ActionMailer ou a introdução de fontes reais de email.

## Sinalização ao CTO (para `docs/inception/`)

1. **Padrão confirmado (herdado da r4):** a checklist de "enumeração por canal lateral" deve incluir os casos **blank/whitespace/malformed** e re-executar os probes de paridade **sempre que uma dependência do fluxo mudar** (neste caso, o gatilho conhecido é habilitar ActionMailer/ActiveJob — `deliver_now` síncrono invalida qualquer equalização de timing construída sem mailer).
2. **Requisito não-funcional sugerido:** rate limiting em endpoint público de recuperação de senha (rack-attack ou similar) deve ser tratado como padrão da stack Devise do Frequência, não como item pontual — registrar em `docs/inception/` (Seção de segurança/stack) para que a Sprint que habilitar ActionMailer já nasça com ele.
3. **Dependência de dados:** nenhuma fonte popula `users.email` (0/84 usuários em dev) — a feature recoverable não pode ser validada em ambiente real até existir origem de email (cadastro/vinculação/sync). Recomenda-se registrar como dependência explícita.