# Relatório Bug Finder — Iteração 23 (4ª rodada) — Frequência

> **Branch:** `feat/cancancan-controller-integration`
> **Data:** 2026-09-21
> **Propósito:** 4ª rodada de teste adversarial independente sobre a Sprint 23 (Devise + CanCanCan + Rolify — Autenticação + Autorização). Foco prioritário: esgotar a superfície de enumeração de contas em `POST /u/password` além de status HTTP (B8, 2ª rodada) e flash tipo/texto (Bug 9, 3ª rodada) — timing, headers/cookies, vazamento de token, diff estrutural de HTML, vazamento de log. Foco secundário: passada de regressão mais ampla na Sprint 23 (matriz CanCanCan, seeds, Rolify×Ability) não coberta em profundidade nas 3 rodadas anteriores.
> **Tarefas testadas:** 23.1–23.10 (fechadas), com foco no `Users::PasswordsController#create` pós-correção do Bug 9.
> **Arquivos analisados:** `app/controllers/users/passwords_controller.rb`, `app/models/user.rb`, `app/views/users/sessions/new.html.erb`, `config/initializers/devise.rb`, `config/locales/devise.pt-BR.yml`, `test/controllers/users/passwords_controller_test.rb`, `app/models/ability.rb`, `db/seeds.rb`, `test/controllers/admin/authorization_matrix_test.rb`, `test/lib/seeds_test.rb`, gem `devise-5.0.4` (`lib/devise/models/recoverable.rb`).
> **Arquivos alterados por este agente:** nenhum arquivo de produção. Um probe temporário (`test/integration/bf_probe_r4_test.rb`, 5 casos) foi criado, executado e **removido** ao final; a suíte foi revalidada no baseline exato antes e depois.

## Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 5 (probe) + 706 (suíte completa) + 14 (matriz/seeds, incluídos nos 706) |
| Bugs encontrados | 1 |
| 🔴 Crítico | 0 |
| 🟠 Alto | 0 |
| 🟡 Médio | 1 |
| 🟢 Baixo | 0 |
| ⚪ Info | 1 |

**Baseline antes e depois do probe:** `bin/rails test` → **706 runs / 2231 assertions / 1 failure / 0 errors** (idêntico ao baseline documentado após a correção do Bug 9 na 3ª rodada; a única falha é a pré-existente de timezone em `presenca_endpoints_test.rb:187`, fora do escopo da Sprint 23).

## Investigação item a item (missão desta rodada)

### (a) Timing (timing attack) — 🟡 Bug 10 encontrado (ver abaixo)

Leitura de `devise-5.0.4/lib/devise/models/recoverable.rb` (`ClassMethods#send_reset_password_instructions`) confirma uma assimetria **estrutural**, não apenas de implementação do Frequência:

- **Email conhecido:** `find_or_initialize_with_errors` encontra o registro (`persisted? == true`) → chama `recoverable.send_reset_password_instructions` → `set_reset_password_token` roda `Devise.token_generator.generate` (gera + persiste hash do token) e `save(validate: false)` → **grava no banco**. Em seguida `send_reset_password_instructions_notification` tenta `Devise::Mailer` → `NameError` → capturado pelo rescue do B1/Bug 9 no controller.
- **Email desconhecido:** `find_or_initialize_with_errors` retorna um registro **novo, não persistido**, com erro `:not_found` — `recoverable.send_reset_password_instructions` **nunca é chamado** (`if recoverable.persisted?`). Não há `set_reset_password_token`, não há `save`, não há tentativa de notificação, não há exceção.

Probe (`ActiveSupport::Notifications.subscribed("sql.active_record")`) confirmou a diferença de trabalho real:
```
KNOWN queries (5): SELECT users WHERE email; SELECT users WHERE reset_password_token; SAVEPOINT; UPDATE users SET reset_password_token/sent_at; RELEASE SAVEPOINT
UNKNOWN queries (1): SELECT users WHERE email (miss)
```
E de tempo de resposta (30 amostras, ambiente de teste local, portanto ruidoso mas direcionalmente consistente):
```
KNOWN   avg=5.267ms  median=4.835ms
UNKNOWN avg=4.103ms  median=3.237ms
```
Delta consistente de ~1-2ms (known sempre mais lento) — o caminho "email conhecido" sempre faz 1 SELECT extra + 1 SAVEPOINT/UPDATE/RELEASE + levanta/captura uma exceção Ruby (custo não-trivial de `raise`/`rescue`), enquanto o caminho "email desconhecido" faz apenas 1 SELECT que já retorna vazio. Isso é reportado como **Bug 10** abaixo.

### (b) Headers/cookies — sem bug

Probe comparou `response.headers` (excluindo `Date`/`X-Request-Id`/`X-Runtime`, que variam por natureza a cada request) e `Set-Cookie`: as chaves de header são **idênticas** nos dois casos (`cache-control, content-length, content-type, location, referrer-policy, set-cookie, x-content-type-options, x-frame-options, x-permitted-cross-domain-policies, x-xss-protection`), sem nenhum header extra/faltante. `Set-Cookie` emite apenas o cookie de sessão padrão (`_api_ponto_session`) em ambos os casos, com formato/tamanho equivalente (o conteúdo é sempre o payload de sessão Rails cifrado, cujo tamanho não vaza informação sobre a existência do usuário). Nenhum cookie extra (ex.: `remember_user_token`) é emitido em nenhum dos dois casos — correto, pois `remember_me` não se aplica ao fluxo de recovery. **Sem bug.**

### (c) Vazamento do `reset_password_token` na resposta HTTP — sem bug (confirmação)

Confirmado por leitura de código (já observado na 3ª rodada, item d) e reconfirmado por probe: o token (`@user.reset_password_token`, hash já persistido no banco) **não aparece** em nenhum lugar do corpo da resposta HTTP nem dos headers do `POST /u/password` — o controller nunca expõe `resource.reset_password_token` (que de qualquer forma é o hash digerido, não o token bruto enviado por e-mail) em flash, redirect location ou body. Isso é esperado e correto — não é o bug em si, apenas confirmação solicitada pela missão. **Sem bug.**

### (d) Diff estrutural de HTML — sem bug (confirmação pós-Bug 9)

Probe fez `POST` conhecido e desconhecido (sessões isoladas via `reset!`), seguiu o redirect (`follow_redirect!`) até `users/sessions/new` e comparou o `response.body` normalizado (removendo apenas o CSRF token, que sempre muda por request). **Resultado: HTML idêntico byte a byte** após a normalização — mesma estrutura, mesma classe CSS (`alert alert-success`), mesmo ícone (`fa-circle-check`), mesmo texto (ambos usam `flash[:notice]` com a chave `send_paranoid_instructions` desde a correção do Bug 9). Isso confirma que a correção da 3ª rodada fechou completamente a dimensão de HTML/flash, sem deixar nenhum atributo `data-*`, classe extra ou diferença de whitespace residual. **Sem bug — Bug 9 validado como efetivamente fechado nesta dimensão.**

### (e) Vazamento do log de auditoria (`Rails.logger.error` do Bug 9) — sem bug

Probe capturou `Rails.logger` num buffer em memória durante o `POST` com email conhecido e confirmou: (1) o log é escrito **apenas** via `Rails.logger.error` (texto: `[Users::PasswordsController] Não foi possível enviar o e-mail de recuperação de senha... (email="...")`), nunca incluído na resposta HTTP (`token_leaked` / verificação do body+headers → `false`); (2) não existe nenhuma rota/endpoint no escopo da Sprint 23 (nem em nenhuma outra sprint revisada) que exponha `log/*.log` ou um endpoint de debug/console publicamente — verificado por ausência de qualquer rota `/rails/info`, `/debug`, `/logs` no `config/routes.rb` (aplicação `api_only`, sem `Rails::Info`/`web-console` montado em produção). **Sem bug.**

## Bugs por Severidade

### 🟡 Médio

#### Bug 10 — Timing side-channel estrutural em `POST /u/password`: email conhecido sempre faz mais trabalho de I/O (SELECT extra + UPDATE + exceção) que email desconhecido

- **Severidade:** 🟡 Médio
- **RF/RN violado:** RN de proteção de dados pessoais/segurança do fluxo recoverable (task 23.8) — mesma regra das rodadas 2/3 ("endpoint público deve tratar emails conhecidos e desconhecidos de forma indistinguível"), agora pelo canal de **tempo de resposta**, não status/flash/HTML (já fechados).
- **Passos:**
  1. `POST /u/password` com email cadastrado, medir tempo de resposta (N amostras).
  2. `POST /u/password` com email não cadastrado, medir tempo de resposta (N amostras, sessão isolada via `reset!`).
  3. Comparar quantidade de queries SQL disparadas e tempo médio/mediano.
- **Atual:** o caminho "email conhecido" dispara **5 queries** (`SELECT` por email, `SELECT` por `reset_password_token` — checagem de colisão do `Devise.token_generator`, `SAVEPOINT`, `UPDATE` do token/timestamp, `RELEASE SAVEPOINT`) e ainda levanta/captura uma exceção `NameError` (rescue do Bug 1/9); o caminho "email desconhecido" dispara **apenas 1 query** (`SELECT` por email, sem match) e nenhuma exceção. Em 30 amostras no ambiente de teste local, a diferença observada foi de ~1.2ms na média (5.27ms vs 4.10ms) e ~1.6ms na mediana — pequena, ruidosa e sensível a jitter de rede/infra em produção, mas **consistente na direção** (known sempre mais lento) porque a causa é estrutural (mais trabalho de I/O), não um artefato de medição.
- **Esperado:** idealmente, ambos os caminhos deveriam realizar quantidade de trabalho (queries, tempo de CPU) equivalente — por exemplo, gerando e descartando um token "fantasma" (sem persistir, ou persistindo em um registro descartável) para o caso "desconhecido", de forma a igualar o custo de I/O. Esse é um problema **inerente ao design do modo `paranoid` do próprio Devise** (não introduzido por nenhuma correção do Frequência) — o Devise paranoid iguala o *status HTTP* e a *mensagem*, mas não tem mecanismo nativo para igualar o *tempo de execução*, porque não pode fisicamente persistir um token de reset para um usuário que não existe.
- **Teste sugerido:** teste de integração medindo `ActiveSupport::Notifications` (`sql.active_record`) ou `Benchmark.realtime` para `POST /u/password` com email conhecido vs. desconhecido, asserindo que a contagem de queries é igual (hoje: 5 vs 1) — documentando o comportamento esperado após uma eventual correção, ou registrando a limitação como aceita.
- **Nota de contexto/mitigação:** a explorabilidade prática deste canal é **baixa a moderada**: (1) exige um atacante capaz de fazer centenas/milhares de requisições e medir tempo com baixo jitter (rede real introduz variância que normalmente supera 1-2ms, exigindo técnicas estatísticas avançadas tipo as usadas em ataques de timing contra APIs remotas); (2) diferente dos Bugs 2/9 das rodadas anteriores (que eram triviais de explorar — um único request bastava), este exige instrumentação estatística; (3) é uma limitação conhecida e documentada da comunidade Devise/OWASP para qualquer implementação de "paranoid mode" — não é uma regressão introduzida por nenhuma das 3 correções anteriores (B1/Bug 9, B8/Bug 2) desta sprint.

## Observações (⚪ Info)

#### Info 1 — Regressão ampla da Sprint 23 (matriz CanCanCan, seeds, Rolify×Ability): sem achados

Rodada de regressão mais ampla e menos profunda solicitada pela missão (áreas não cobertas em detalhe pelas 3 rodadas anteriores, que focaram quase exclusivamente em auth/recoverable):

- `test/controllers/admin/authorization_matrix_test.rb` + `test/lib/seeds_test.rb`: **14/14 verdes**, incluídos nos 706 runs da suíte completa — nenhuma das correções B7/B8/Bug 9 (que só tocaram `passwords_controller.rb`, `user.rb` e `devise.rb`) quebrou a matriz de autorização CanCanCan/Rolify ou a idempotência dos seeds.
- Leitura de `app/models/ability.rb` e `db/seeds.rb`: nenhuma mudança nesses arquivos desde a 2ª rodada (confirmado — as correções B7/B8/Bug 9 não tocaram autorização/seeds, apenas o fluxo de recuperação de senha e o model `User`). Não há interação nova Rolify×Ability para revisitar além do que já foi validado nas rodadas 1-3 (papel removido em runtime → `Ability` recalculada corretamente, já confirmado na 2ª rodada).
- Nenhum bug novo encontrado nesta frente — área permanece estável.

## Cenários Testados (sem bugs)

| Cenário | Resultado |
|---------|-----------|
| Suíte completa `bin/rails test` (baseline antes e depois do probe) | 706 runs / 2231 assertions / 1 failure de timezone pré-existente (idêntico) |
| **Bug 9 revalidado — item (d) HTML estrutural:** `POST /u/password` conhecido vs. desconhecido, sessões isoladas, HTML da tela de recall após redirect | Byte-idêntico após normalização de CSRF — mesma classe, ícone e texto do flash |
| **Item (b) headers/cookies:** comparação de `response.headers` e `Set-Cookie` entre os dois casos | Nenhuma diferença de chaves; nenhum cookie extra emitido em nenhum dos casos |
| **Item (c) vazamento de token:** `reset_password_token` gerado (known) não aparece no body/headers da resposta HTTP | Confirmado — token nunca vaza externamente |
| **Item (e) vazamento de log:** `Rails.logger.error` do Bug 9 capturado em buffer isolado durante o request | Log presente apenas internamente; não aparece na resposta HTTP; nenhuma rota de debug/log exposta no `routes.rb` |
| Matriz de autorização CanCanCan/Rolify (`authorization_matrix_test.rb`) | 100% verde, sem regressão das correções B7/B8/Bug 9 |
| Seeds idempotentes (`seeds_test.rb`) | 100% verde, sem regressão |
| `PATCH /u/password` com token válido/inválido (regressão, não retestado a fundo — já coberto nas rodadas 2/3) | Comportamento inalterado (confirmado por leitura, sem probe dedicado nesta rodada) |

## Veredito Final

Esta 4ª rodada **não encontrou nenhum bug de severidade Alta ou Crítica**. O único achado é o **Bug 10 (🟡 Médio)** — um canal de timing residual, **estrutural e inerente ao modo `paranoid` do Devise** (não uma regressão das correções B1/B7/B8/Bug 9), com explorabilidade prática baixa a moderada (exige medição estatística, não um único request).

Todas as outras dimensões de enumeração investigadas nesta rodada — headers/cookies (b), vazamento de token (c), diff de HTML (d), vazamento de log (e) — **não apresentaram problema algum**. Em particular, o item (d) confirma de forma independente e mais rigorosa (sessões isoladas, comparação byte a byte) que o **Bug 9 da 3ª rodada está de fato e completamente corrigido** — não há mais nenhuma pista visual, estrutural ou de conteúdo que distinga um email conhecido de um desconhecido na tela de recall.

A passada de regressão ampla (matriz CanCanCan, seeds, Rolify×Ability) não encontrou nada — a Sprint 23 permanece estruturalmente sólida fora do fluxo de recuperação de senha, e as correções pontuais das rodadas anteriores não vazaram efeitos colaterais para autorização/seeds.

### Recomendação: ENCERRAR o ciclo de bug-hunting focado em enumeração de `POST /u/password`

Diferente das rodadas 2→3 (onde cada correção abria uma nova dimensão de mesma severidade, Alto), esta rodada apresenta **rendimento nitidamente decrescente**: nenhum achado Alto/Crítico, e o único achado (Bug 10) é uma limitação de design conhecida da comunidade Devise, não uma falha de implementação específica do Frequência, com exploração não-trivial. Recomenda-se:

1. **Não bloquear a Sprint 23 por causa do Bug 10** — registrar como débito técnico aceito (ou fechar como "risco residual aceito, limitação do Devise paranoid") em vez de disparar uma 5ª rodada de correção pontual + nova rodada de teste. O padrão observado nas rodadas 1→3 (cada correção pontual abre uma fresta adjacente) tende a se esgotar quando a fresta remanescente é uma limitação arquitetural do framework, não um bug de código — não há "correção pontual" equivalente para timing sem uma mudança de design (dummy write) que tem seu próprio custo/risco.
2. Se o time quiser fechar também esta dimensão, a correção sugerida (dummy write simétrico) deve ser tratada como uma **melhoria de segurança de escopo próprio** (não um "bug fix" reativo), avaliada pelo CTO/dev quanto ao custo-benefício, e não como pré-requisito para considerar a Sprint 23 fechada.
3. Recomenda-se **encerrar o ciclo de bug-hunting nesta área específica** (`POST /u/password`) após esta 4ª rodada — as 4 rodadas somadas já cobriram exaustivamente status HTTP, flash tipo/texto/cor/ícone, HTML estrutural, headers, cookies, vazamento de token e log, e timing. Rodadas adicionais sobre o mesmo endpoint têm baixa probabilidade de encontrar algo novo de severidade relevante.

## Sinalização ao CTO

**Padrão recorrente identificado (para registro em `docs/inception/`):** as 4 rodadas de teste adversarial sobre `POST /u/password` formam um caso de estudo de "enumeração de contas via canais laterais" com uma hierarquia clara de explorabilidade decrescente: status HTTP (trivial, 1 request) → conteúdo/tipo de flash (trivial, 1 request, mas exige olhar a UI e não só o código de status) → HTML estrutural (também trivial se houvesse diferença, mas não houve) → headers/cookies (também trivial, não houve) → timing (não-trivial, exige N requisições e análise estatística). Recomenda-se documentar esta hierarquia como checklist padrão para qualquer fluxo futuro de recuperação de senha / enumeração de contas em outras partes do sistema (ex.: se o Frequência ganhar fluxo de confirmação de conta ou de convite, a mesma sequência de verificações — status, flash, HTML, headers, timing — deveria ser aplicada preventivamente, em vez de descoberta reativa ao longo de 4 rodadas). Sugestão de adicionar este checklist à skill `adversarial-testing-strategy` ou `structural-conformity-checklist` como uma subcategoria "enumeração por canal lateral" dentro de Edge Cases/Integrações.
