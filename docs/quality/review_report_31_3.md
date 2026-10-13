# Relatório de Revisão — Tarefa 31.3 (Handler `REGISTRO_FREQUENCIA` / `REGISTRO_ESTACAO` + produtores)

## Metadados

| Campo | Valor |
|-------|-------|
| Data da revisão | 2026-10-13 |
| Revisor | Code Reviewer (AI Workflow) |
| Branch origem | `feature/demanda-31-3-handler-registro` (working tree, **não commitado**) |
| Base | `97095bc` (HEAD da 31.2) |
| Tarefa revisada | 31.3 — handler dos eventos `REGISTRO_FREQUENCIA`/`REGISTRO_ESTACAO` + produtores + correção pós-review A/B |
| Rastreabilidade | PRD §5.2 (L145); `iteration_31.md` §`#### Tarefa 31.3` |
| Commits | **Nenhum** (`COMMIT_MODE=manual`) |
| Arquivos novos | `app/services/registro_recalculo_handler.rb` (108), `config/initializers/recalculo_handlers.rb` (26), `test/services/registro_recalculo_handler_test.rb` (203) |
| Arquivos modificados | `app/services/consolidacao_mensal_service.rb` (+15, aditivo), `app/services/registro_manual_frequencia_service.rb` (+17), `app/controllers/presenca/sincronizar_registros_ponto_controller.rb` (+17), `test/integration/presenca_endpoints_test.rb` (+40), `test/services/registro_manual_frequencia_service_test.rb` (+65), `docs/progress/iteration_31.md` |
| Apoio | `app/services/calculo_diario_service.rb`, `app/jobs/executa_tarefas_job.rb`, `app/models/tarefa_recalculo.rb`, `test/support/class_method_stub_helper.rb` |

**Veredito: ✅ Aprovado — 0 Blockers 🔴 | 2 Débitos 🟠 | 2 Sugestões 🟡 | 5 Elogios 🟢.**

> A entrega técnica da 31.3 está **aprovada**. As correções pós-review A/B estão **corretas e verificadas**: o predicado `finalizado?` reusa a MESMA condição de `consolidar` sem duplicar regra e sem alterar `consolidar`; o guard de futuro barra o ramo do `else`. Não há Blocker bloqueando o commit. Os achados remanescentes são dois débitos latentes de baixa probabilidade (não introduzem corrupção de dados) e higiene de escopo do working tree.

## Evidência reproduzida

| Comando | Resultado |
|---------|-----------|
| `bin/rails test test/services/registro_recalculo_handler_test.rb test/services/registro_manual_frequencia_service_test.rb` | **19 runs, 67 assertions, 0F, 0E, 0 skips** |
| `bin/rails test test/integration/presenca_endpoints_test.rb` | **45 runs, 152 assertions, 1F, 0E** — a **única falha é pré-existente** (TZ, ver S2) |
| `bin/rails test test/jobs/executa_tarefas_job_test.rb test/models/tarefa_recalculo_test.rb test/services/calculo_diario_service_test.rb test/services/consolidacao_mensal_service_test.rb test/jobs/calcular_frequencia_job_test.rb` | **81 runs, 207 assertions, 0F, 0E** |
| `bin/rails zeitwerk:check` | `All is good!` |
| `bin/rubocop` (8 arquivos da 31.3) | `8 files inspected, no offenses detected` |

## Blockers (🔴)

**Nenhum.** Não há defeito de correção, segurança, quebra de lógica ou regressão de dados que impeça o commit.

## Débitos (🟠)

| ID | Descrição | Evidência / Tarefa | Bloqueante? |
|----|-----------|--------------------|-------------|
| D1 | **Janela de corrida residual do guard `finalizado?` — o `rescue` NÃO garante consistência, e o comentário superestima a proteção.** No ramo "data passada", a ordem é `finalizado?` → `calcular` → `consolidar`. Se o mês for finalizado por outro processo **entre** a checagem e o `calcular` (janela de microssegundos), o `calcular` reescreve o `CalculoDiario` de um mês recém-finalizado (mesma classe de bug do Bug A) e só depois `consolidar` levanta `MesFinalizadoError`, que é engolido silenciosamente — deixando o dia reescrito e o `RegistroMensalFrequencia` desatualizado. O comentário (`registro_recalculo_handler.rb:57-60`) afirma "não reescreve nada de forma inconsistente", o que **não é verdadeiro** nesse instante. **Probabilidade desprezível** (finalização é ação manual, janela ínfima, sem propagação de erro). | `app/services/registro_recalculo_handler.rb:51-61, 65-98` | **Não** — débito aceitável; recomenda-se corrigir o comentário (honestidade) ou, no futuro, fechar a janela com lock/savepoint |
| D2 | **`enfileirar!` não é seguro dentro de transação no caminho de corrida `RecordNotUnique`.** Os produtores da 31.3 (primeiros a chamar `enfileirar!` **dentro** de uma transação) expõem o `rescue ActiveRecord::RecordNotUnique` do 31.1: em PostgreSQL, após o `INSERT` violar o índice único parcial a transação fica **abortada**, e o `pendentes.find_by!` do `rescue` levanta `PG::InFailedSqlTransaction` — que **não** é capturado, propagando e derrubando a transação do produtor (o `TimeRecord` recém-criado é perdido; sem corrupção, mas erro espúrio na requisição concorrente). Só ocorre sob concorrência real (dois INSERTs do mesmo par `(tipo, referencia)`). **Herdado do 31.1** — não foi exercitado antes porque a 31.2 não tinha caller in-transaction. | `app/models/tarefa_recalculo.rb:83-96` + callers `registro_manual_frequencia_service.rb:48`, `sincronizar_registros_ponto_controller.rb:134` | **Não** — débito de baixa probabilidade (sem orphan; sem corrupção). Correção futura: `create!` com `requires_new: true` (savepoint) antes do rescue, ou retry fora da transação |

## Sugestões (🟡)

| ID | Descrição | Evidência |
|----|-----------|-----------|
| S1 | **Higiene de escopo do working tree — 2 arquivos alheios à 31.3.** `config/environments/development.rb` (+10, flag `FREQUENCIA_AUTORIZACAO_CASCATA`, residual do D3/30.x) e `config/credentials.yml.enc` estão modificados no working tree mas **não pertencem à 31.3**. Não devem entrar no commit desta tarefa (já apontados como S3 no `review_report_31_2.md`). | `git status` / `git diff -- config/environments/development.rb` |
| S2 | **Falha de TZ em `presenca_endpoints_test.rb:187` é PRÉ-EXISTENTE — confirmado, não introduzida pela 31.3.** O teste (linhas 171-187, `POST ... saves records ... confirmacao visual`) espera `"15/07/2026 11:30:45"` e recebe `"15/07/2026 14:30:45"` (offset de 3h). O corpo do teste **não é tocado** pelo diff (o hunk da 31.3 adiciona a partir da linha 188). Bate com o baseline documentado (`iteration_31.md` §47: "1× timezone em `PresencaEndpointsTest`"). Alerta: o teste contém uma asserção de horário hardcoded sensível a `Time.zone` — débito de teste a corrigir fora da 31.3. | `test/integration/presenca_endpoints_test.rb:171-187` |

## Elogios (🟢)

| ID | Elogio | Evidência |
|----|--------|-----------|
| E1 | **Bug A fechado reusando a MESMA condição, sem duplicar a regra.** `ConsolidacaoMensalService.finalizado?` (`find_by` + `!nil? && finalizado?`) é equivalente a `registro.persisted? && registro.finalizado?` do `consolidar`; `consolidar` **não mudou de comportamento** e nenhum outro chamador foi afetado. Guard avaliado **antes** de qualquer recálculo. | `consolidacao_mensal_service.rb:78-81, 99-106`; `registro_recalculo_handler.rb:80` |
| E2 | **Testes dos guards A/B são reais e não vacuosos.** O teste de mês finalizado usa o pipeline REAL (sem stub) e asserta `CalculoDiario` **e** `RegistroMensalFrequencia` inalterados; o de mês finalizado com data de HOJE asserta que `calcular` **não** é chamado; o de futuro asserta zero criação. Neutralizar os guards quebra os testes correspondentes. | `registro_recalculo_handler_test.rb:63-135` |
| E3 | **Produtores enfileiram DENTRO da transação de criação, com atomicidade provada.** O rollback derruba `TimeRecord` + tarefa juntos (teste `rollback da transação não deixa tarefa órfã`). No controller, só enfileira no caminho de `TimeRecord` criado (os `next` de rejeição pulam o enfileiramento). | `registro_manual_frequencia_service.rb:25-53`; `sincronizar_registros_ponto_controller.rb:52-140`; `registro_manual_frequencia_service_test.rb` (teste de rollback) |
| E4 | **Referência estável correta e com fuso correto.** `"#{tipo}:#{user_id}:#{date}"` usa `to_date.iso8601` do fuso do registro (`Time.zone.strptime` no controller; `momento` do serviço), alinhado ao `data` do `payload` que o handler parseia. Idempotência do produtor provada (2 batidas mesmo dia = 1 pendente). | `sincronizar_registros_ponto_controller.rb:136`; `registro_manual_frequencia_service.rb:50` |
| E5 | **Registry no boot via `to_prepare`, idempotente e não-destrutivo; testes sem `remove_method`.** O initializer reatribui a MESMA chave (sem acumular/duplicar) e o save/restore do job test (`handlers.dup`/`replace`) preserva handlers de outros arquivos do worker. Todos os stubs usam `class_method_stub_helper`. | `config/initializers/recalculo_handlers.rb:17-26`; `executa_tarefas_job_test.rb:13-21` |

## Conferência dos pontos sensíveis solicitados

1. **TOCTOU guard × `consolidar`:** o `rescue MesFinalizadoError` **não** fecha a janela — apenas evita a propagação (§D1). Não bloqueante.
2. **Custo do predicado / ramo "hoje":** o ramo "hoje" agora paga 1 `find_by` extra em `registro_mensal_frequencia`. Custo desprezível (query indexada por `(user, ano, mes)`), sem efeito colateral. Aceitável.
3. **Produtores:** enfileiramento na transação correta (rollback atômico provado); referência estável correta (`to_date` do fuso certo); rejeitado NÃO enfileira. Ver D2 para o único risco latente.
4. **Registry/boot:** `to_prepare` idempotente, sem re-registro destrutivo; save/restore dos testes do job preservado. OK.
5. **Testes:** os 3 novos guards exercitam de fato (não vacuosos), sem `remove_method`; a falha de TZ citada é pré-existente (§S2).
6. **Correção/segurança:** nenhuma alteração de `Ability`/autorização/cascata; nenhum produtor de tipo adiado criado.

## Ações corretivas

- [ ] **Obrigatório para o commit:** nenhum Blocker pendente. ✅ Pronto para o Code Specialist agrupar commits atômicos da 31.3.
- [ ] (Recomendado) Ajustar o comentário do `rescue MesFinalizadoError` para não afirmar que a corrida "não reescreve nada de forma inconsistente" (§D1).
- [ ] (Débito, tarefa futura) Endurecer `TarefaRecalculo.enfileirar!` para uso in-transaction (savepoint/`requires_new`) — §D2.
- [ ] (Higiene) Excluir `config/environments/development.rb` e `config/credentials.yml.enc` do commit da 31.3 — §S1.
