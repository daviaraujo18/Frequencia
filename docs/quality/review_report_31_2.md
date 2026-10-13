# Relatório de Revisão — Tarefa 31.2 (`ExecutaTarefasJob` — job de despacho da fila de recálculo)

## Metadados

| Campo | Valor |
|-------|-------|
| Data da revisão | 2026-10-13 |
| Revisor | Code Reviewer (AI Workflow) |
| Branch origem | `feature/demanda-31-2-executa-tarefas-job` |
| Base | `b417fef` (HEAD da 31.1) |
| Tarefa revisada | 31.2 — Job de despacho `ExecutaTarefasJob` (a cada ~5min) |
| Rastreabilidade | PRD §5.2 (L139-148); `iteration_31.md` §`#### Tarefa 31.2` |
| Commits | **Nenhum** (`COMMIT_MODE=manual`) — 2 arquivos novos + `schedule.yml`/`iteration_31.md` modificados |
| Arquivos revisados | `api-ponto/app/jobs/executa_tarefas_job.rb` (122), `api-ponto/test/jobs/executa_tarefas_job_test.rb` (127), `api-ponto/config/schedule.yml` (+10), `docs/progress/iteration_31.md` (status 31.2) |
| Apoio | `app/models/tarefa_recalculo.rb` (31.1), `db/migrate/20261013120000_create_tarefas_recalculo.rb`, `app/jobs/*.rb` (LOCK_KEYs), `test/test_helper.rb`, `test/support/class_method_stub_helper.rb` |

**Veredito: ✅ Aprovado — 0 Blockers 🔴 | 3 Débitos 🟠 | 3 Sugestões 🟡 | 5 Elogios 🟢.**

> A entrega técnica da 31.2 está **aprovada**. O código cumpre integralmente os critérios de aceite da tarefa. Os achados abaixo são (a) débitos já pré-registrados, (b) um risco latente que só se materializa quando a 31.3–31.5 registrar handlers reais, e (c) higiene de escopo/higiene de arquivos no working tree.

---

## Evidência executada (números reais medidos nesta revisão)

Ambiente conforme o gotcha (`PATH` com o ruby 3.3.8 do mise + `BUNDLE_PATH` do bundle do Frequencia; binstub `bin/rails`):

| Execução | Comando | Resultado |
|----------|---------|-----------|
| Arquivo novo | `bin/rails test test/jobs/executa_tarefas_job_test.rb` | **7 runs, 23 assertions, 0F, 0E, 0 skips** |
| Direcionada (jobs + model da fila) | `bin/rails test test/jobs/ test/models/tarefa_recalculo_test.rb` | **62 runs, 149 assertions, 0F, 0E, 0 skips** (12 processos paralelos) |
| RuboCop | `bin/rubocop` (2 arquivos) | **no offenses detected** |
| Zeitwerk | `bin/rails zeitwerk:check` | **All is good!** |

O arquivo novo confere com o reportado (7/23). A execução conjunta com os demais jobs e o model da fila (62/149) roda **sem contaminação** entre arquivos neste momento — o registry é limpo de forma consistente (ressalva no Débito 🟠-D2, sobre o futuro).

---

## Resultado por foco da revisão

### 1. Advisory lock PRÓPRIO, sem colisão — ✅ Conforme
`LOCK_KEY = 728_104_536` (`executa_tarefas_job.rb:28`). Varredura em todo o repo (`grep -rn "LOCK_KEY *=" app/ lib/`): existem **exatamente 6** chaves, todas distintas — `837_462_915`, `592_017_384`, `471_209_336`, `194_773_608`, `451_926_073` e a nova `728_104_536`. Nenhum outro uso de `pg_advisory_lock` em `app/`, `lib/` ou `config/`. A colisão está coberta pelo teste "LOCK_KEY e distinta das chaves dos demais jobs" (que ainda asserta a unicidade mútua das 5 existentes). O comentário no job lista as 5 corretas.

### 2. Registry de handlers (contrato mínimo, injetável) — ✅ Conforme
`handlers` (`:45-47`, `@handlers ||= {}`), `registrar_handler` (`:51-53`, coage a `String`) e `limpar_handlers` (`:58-60`). Roteamento por `tarefa.tipo_entidade` em `processar` (`:93`). Sem framework de plugins — o mínimo pedido. `@handlers` é ivar de **classe** (mesmo `self` no corpo da classe e em `class << self`), preguiçoso (`nil` até o 1º uso), sem acoplar ao autoload. Correto.

### 3. Tipos adiados: guard ANTES do registry, nunca `raise` — ✅ Conforme (invariante provada)
`processar:91` retorna cedo (`marcar_como_processada`) se `adiada?` — **antes** de `self.class.handlers[...]` (`:93`). O teste "tipo adiado nao e despachado nem que haja handler registrado" (`test:40-54`) registra um handler **para um tipo adiado** (`FERIADO`) e prova que ele **não é chamado** (`assert_not chamou`) — é exatamente a prova de que o guard é anterior ao registry. `assert_nothing_raised` confirma o "nunca `raise`". Sólido.

### 4. Erro por item (`rescue StandardError`) — ✅ Conforme
`processar:86-108`: `rescue StandardError => e` no **item** (`:102`), log (`:106`) e `tarefa.update!(status: ERRRO)` (`:107`) — o `find_each` continua. `processada_em` só em sucesso/skip (`marcar_como_processada:119-121`); o teste `:75-77` asserta `STATUS_ERRO` + `processada_em` **nil**. Fiel ao critério.

### 5. Idempotência — ✅ Conforme (com ressalva do crash-window → 🟠-D1)
Só `TarefaRecalculo.pendentes` é drenado (`:68`); após o drain a tarefa sai do escopo, então reprocessar = efeito único. Teste `:81-92`: 2× `perform_now` ⇒ `contador == 1` e `pendentes.count == 0`. `find_each` ordena por id e o cursor é por id, então **marcar processada durante a iteração não pula nem repete** itens (progresso monotônico). Correto.

### 6. `schedule.yml` production-only — ✅ Conforme
`config/schedule.yml:6` `<% if Rails.env.production? %>` … `:51-53` `<% else %> {} <% end %>`. Entrada `executa_tarefas` com `cron: "*/5 * * * *"`, `class: "ExecutaTarefasJob"`, `queue: default` (`:46-49`). Dev/test ⇒ `{}`. Correto.

### 7. Débito: tipo não-adiado sem handler ⇒ `processada` (drenado sem efeito) — 🟠 (ver D3)
`processar:98` marca `processada` (skip) quando não há handler. Está **documentado** (`:96-97`, `iteration_31.md:105`) e é coerente com "nesta task nenhum produtor cria tais tipos". O **risco**: quando a 31.3–31.5 criarem os produtores, uma falha de registro do handler (autoload/boot) faria a tarefa ser **drenada silenciosamente sem efeito** — perda silenciosa, sem retry e sem log. Ver D3/S1.

### 8. Testes não-degenerados — ✅ (com 1 ressalva em 🟡-S1)
Os 7 testes falham pela razão certa:
- Roteamento (`:22-38`), adiado (`:40-54`), sem-handler (`:56-63`), erro isolado (`:65-79`), idempotência (`:81-92`), lock concorrente (`:94-113`), unicidade de chave (`:115-126`).
- **Não usam `remove_method` nem stub de método de classe** — exercitam a **API real** (`registrar_handler`) e um handler fake por lambda. Honra o critério "save/restore, nunca `remove_method`" por construção.
- Registry limpo em `setup`/`teardown` (`:11-16`). Ressalva: `limpar_handlers` **recria** o hash (destrutivo) — ver D2.
- `RLock` test: se `select_value(...) == true` falhasse (ex.: string `"t"`), o job sempre pularia e o teste "despacha cada tarefa pendente" falharia — logo o `7/7` **prova** que `select_value` devolve `true` neste adapter. Não é degenerado.

### 9. Escopo — ✅ no código 31.2 / 🟡-S3 no working tree
Os arquivos da 31.2 **não tocam** `Ability`, cascata, nem `TarefaRecalculo` (só leem a constante `TIPOS_ADIADOS`/status). Porém o **working tree** carrega alterações **não relacionadas** à 31.2 (ver S3).

---

## Blockers 🔴
Nenhum.

## Débitos 🟠

| ID | Descrição | Arquivo:linha | Impacto |
|----|-----------|---------------|---------|
| D1 | **Crash-window entre `handler.call` e a marcação.** Não há estado "processando"/claim: a tarefa só sai de `pendentes` **depois** do handler. Se o processo cair (ou o worker for morto) entre `handler.call(tarefa)` (`:100`) e `marcar_como_processada` (`:101`), a tarefa volta a ser drenada no próximo tick ⇒ **duplo processamento**. A "idempotência = efeito único" depende da idempotência **dos handlers** (31.3), não do job. **Pré-registrado** como "concorrência fina" (`iteration_31.md:105,185,195`). | `executa_tarefas_job.rb:68,100-101` | Duplo recálculo em crash — inócuo se os handlers forem idempotentes (são, por design). Aceitável como débito. |
| D2 | **`limpar_handlers` apaga o registry GLOBAL (destrutivo).** `@handlers = {}` (`:59`) **descarta** qualquer handler real registrado no processo. Hoje inócuo (registry vazio de fábrica), mas quando a 31.3–31.5 registrarem handlers (provavelmente em tempo de load), rodar **este** arquivo no mesmo worker da suíte pode **zerar** os handlers reais para os arquivos seguintes ⇒ testes de outras tarefas passariam **vacuamente** (tarefa "skipada" em vez de "handled"). É a mesma classe de contaminação process-global que as lições 29/33 documentam (save/restore, nunca destruir). | `executa_tarefas_job.rb:58-60; test:11-16` | Latente. Não quebra a 31.2; quebra/mascara a 31.3–31.5. Corrigir **junto/já antes** da 31.3. |
| D3 | **Skip de tipo não-adiado sem handler é silencioso (sem log).** `:98` marca `processada` sem qualquer registro. Um handler não registrado (falha de autoload/boot) ⇒ tarefa drenada **sem efeito e sem rastro**. É o débito já registrado, mas hoje **não há nem um `Rails.logger.warn`** para detectá-lo em produção. | `executa_tarefas_job.rb:98` | Perda silenciosa potencial no futuro. |

### Correção sugerida
- **D1:** (fora do escopo desta task) — documentar explicitamente que a idempotência é garantida pelos handlers; opcionalmente um estado `processando` + claim com timestamp na 31.3. Manter como débito.
- **D2:** no teste, **salvar/restaurar** o hash em vez de recriá-lo:
  ```ruby
  def setup
    @handlers_backup = ExecutaTarefasJob.handlers.dup
    ExecutaTarefasJob.handlers.clear
  end
  def teardown
    ExecutaTarefasJob.handlers.replace(@handlers_backup)
  end
  ```
  e **remover** `limpar_handlers` da API de produção (é método só-de-teste vazando para o job). Alternativa mínima: manter `limpar_handlers`, mas fazê-lo guardar/restaurar via um helper de save/restore, no espírito do `class_method_stub_helper`.
- **D3:** adicionar `Rails.logger.warn("[ExecutaTarefasJob] sem handler para #{tarefa.tipo_entidade}; drenando como processada (id=#{tarefa.id})")` antes do `return marcar_como_processada`. Custo zero, elimina o ponto cego.

## Sugestões 🟡

| ID | Descrição | Arquivo:linha |
|----|-----------|---------------|
| S1 | **O teste de lock não asserta que a conexão concorrente ADQUIRIU o lock.** `outra_conexao.exec("SELECT pg_try_advisory_lock(...)")` (`test:103`) tem o retorno ignorado. Se um lock tiver vazado de um teste anterior, o job pularia **pela razão errada** e o teste ainda passaria. Sugestão: `assert_equal "t", outra_conexao.exec("...").getvalue(0,0)` (ou `select_value`), endurecendo a prova. | `executa_tarefas_job_test.rb:103` |
| S2 | **Comentário do schema (31.1) contradiz o comportamento decidido na 31.2.** A migration diz "Preenchido quando a tarefa é drenada (status vira processada/erro)", mas o job — e o teste `:76` — **não** setam `processada_em` no `erro`. Alinhar o comentário da migration (ou documentar a decisão), para não induzir um consumidor futuro a achar que há timestamp de erro. | `db/migrate/20261013120000_create_tarefas_recalculo.rb:32` vs `executa_tarefas_job.rb:118` |
| S3 | **Higiene de escopo no working tree.** Há alterações **não relacionadas** à 31.2 no diff: `config/environments/development.rb` (liga a **cascata** de autorização em `shadow` — ADR-0010/D3), `config/credentials.yml.enc` (arquivo sensível), `log/*.log` e `tmp/cache/bootsnap/load-path-cache`. Se o commit da 31.2 usar `git add -A`, o flag da cascata e o `credentials.yml.enc` **vazam** para a entrega. Fazer o stage **explícito** dos 4 arquivos da 31.2 (`app/jobs/executa_tarefas_job.rb`, `test/jobs/executa_tarefas_job_test.rb`, `config/schedule.yml`, `docs/progress/iteration_31.md`) e confirmar a proveniência do resto. | `Frequencia/api-ponto/config/environments/development.rb`, `config/credentials.yml.enc` |

## Elogios 🟢

| ID | Elogio | Onde |
|----|--------|------|
| E1 | **Testes exercitam a API real do registry** (sem `define_singleton_method`/`remove_method` nem stub de classe) — honra o critério de aceite por construção, não por conformidade aparente. | `executa_tarefas_job_test.rb` |
| E2 | **Prova do invariante do guard:** o teste de tipo adiado **registra um handler para um tipo adiado** e prova que ele não roda — testa a *ordem* do guard, não só o efeito. | `:40-54` |
| E3 | **Unicidade da LOCK_KEY assertada + comentário enumerando as 5 chaves** — prevenção barata e legível de colisão de advisory lock. | `job:17-28`; `test:115-126` |
| E4 | **`ensure` no release do lock** (`:69-71`) e `rescue` **por item** — o lote nunca trava nem derruba o lock em erro. Mesmo padrão comprovado dos jobs existentes. | `executa_tarefas_job.rb:64-72` |
| E5 | **`LIMPAR` consistente e comentários de decisão** — cada não-obviedade (ordem do guard, `processada_em` só no sucesso, ivar de classe preguiçoso) está justificada no código, e os débitos estão declarados no `iteration_31.md`. | arquivo inteiro |

---

## Ações corretivas

- [ ] **Blockers:** nenhum — a 31.2 não precisa de correção para prosseguir.
- [ ] (Recomendado antes da 31.3) **D2** — trocar o reset destrutivo do registry por save/restore e remover `limpar_handlers` da API de produção.
- [ ] (Recomendado) **D3** — adicionar `Rails.logger.warn` no skip sem handler.
- [ ] (Recomendado) **S3** — stage **explícito** dos 4 arquivos da 31.2; não commitar `development.rb`/`credentials.yml.enc`/logs no commit da demanda.
- [ ] (Opcional) **D1** — manter como débito documentado (idempotência mora nos handlers).
- [ ] (Opcional) **S1** — assertar a aquisição do lock na conexão concorrente.
- [ ] (Opcional) **S2** — alinhar o comentário da migration (31.1) à semântica de `processada_em`.

## Certificação de entrega

Entrega técnica **aprovada** (0 Blockers 🔴). Sinal verde para o **Code Specialist** agrupar os commits atômicos e executar o protocolo de entrega, com o **stage seletivo** descrito em S3. O fechamento dessa rastreabilidade é pré-requisito para o início da 31.3–31.5.
