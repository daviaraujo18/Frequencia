# Relatório de Revisão — Task 31.4 (Handler `RECALCULAR_TODOS`)

- **Revisor:** Code Reviewer (AI Workflow)
- **Data:** 2026-10-13
- **Branch de origem → destino:** `feature/demanda-31-4-recalcular-todos` (working tree, NÃO commitado) → `develop` (base `1fa033e` = HEAD da 31.3)
- **Veredito:** ✅ **Aprovado** — **0 Blockers 🔴 | 0 Sugestões de Melhoria 🟡 | 2 Débitos 🟠 | 4 Elogios 🟢**

## Escopo revisado

| Arquivo | Tipo | Estado |
|---------|------|--------|
| `api-ponto/app/services/recalcular_todos_handler.rb` | NOVO | untracked (lido direto) |
| `api-ponto/test/services/recalcular_todos_handler_test.rb` | NOVO | untracked (lido direto) |
| `api-ponto/config/initializers/recalculo_handlers.rb` | MODIFICADO | + registro `RECALCULAR_TODOS` |
| `docs/progress/iteration_31.md` | MODIFICADO | bloco da Tarefa 31.4 |

Fora de escopo (lixo de ambiente, ignorados): `config/credentials.yml.enc`, `config/environments/development.rb`, `log/*`, `tmp/cache/*`.

## Evidência executada

| Comando | Resultado |
|---------|-----------|
| `bin/rails test test/services/recalcular_todos_handler_test.rb` | **7 runs, 21 assertions, 0F, 0E, 0 skips** |
| `bin/rails test test/services/registro_recalculo_handler_test.rb test/jobs/executa_tarefas_job_test.rb test/services/recalcular_todos_handler_test.rb` | **27 runs, 85 assertions, 0F, 0E, 0 skips** (sem contaminação por stub) |
| `bin/rails zeitwerk:check` | **All is good!** |
| `bin/rubocop` (3 arquivos do diff) | **0 offenses** |

## Verificações do pedido (atenção especial)

1. **Eixo vínculo-ativo — FIEL.** `cpfs_com_vinculo_ativo` = `Pessoas::Vinculo.ativos.joins(:pessoa).distinct.pluck("pessoas.cpf").compact`. O `ativos` (`app/models/pessoas/vinculo.rb:22`) é o MESMO scope consumido por `frequentadores_ativos`, `cpfs_por_nome` (`vinculo.rb:143`), `cpfs_por_orgao` (`:171`) e `FrequentadoresVisiveis#base` (`frequentadores_visiveis.rb:92`). Sem JOIN cross-database (CPFs resolvidos no Pessoas → `User.where(cpf:)` local). Idêntico ao eixo canônico.
2. **`User.status` não filtrado — CORRETO.** O PRD (§5.2 L146) diz "frequentadores com vínculo ativo" (eixo do frequentador/Pessoas), não status do `User` local. Alinhado também ao `CalcularFrequenciaJob` (`User.where.not(cpf: nil)`, sem status). Sem risco de divergir da cascata no que a tarefa exige.
3. **Lista vazia.** `return if cpfs.empty?` (handler L68) — guard defensivo/correto. Tecnicamente cosmético: `User.where(cpf: [])` já gera `WHERE 1=0`, então o `find_each` seria no-op de qualquer forma; o guard documenta a intenção. Não é bug (ver 🟢-E4).
4. **CPFs nulos/duplicados.** `distinct` remove duplicatas (vínculo múltiplo por pessoa); `.compact` remove `nil` ANTES de montar o `IN`. O `IN (..., NULL)` nunca ocorre — o `compact` fecha o caso. Correto (o comentário L77-78 está certo: o SQL ignora NULL, mas o `compact` já evita o problema).
5. **Decisão de lock — CONCORDO e VALIDEI.** Advisory locks no Postgres são por sessão: `ExecutaTarefasJob` segura `728_104_536` na sua conexão; `CalcularFrequenciaJob` segura `451_926_073` na dele. Se o handler tentasse `pg_try_advisory_lock(451_926_073)` durante o job noturno, retornaria `false` → saída sem efeito → tarefa drenada como `processada` (perda silenciosa). Pior que a sobreposição. **A sobreposição NÃO corrompe dado**: `calculo_diarios` tem índice UNIQUE `[user_id, data]` (`db/schema.rb:48`) e `registro_mensal_frequencias` tem UNIQUE `[user_id, ano, mes]` (`:230`); um INSERT concorrente duplicado levanta `RecordNotUnique`, capturado pelo `rescue StandardError` por usuário (logado, lote segue). Pior caso = trabalho duplicado → convergente/idempotente, nunca dado incorreto. Decisão de NÃO herdar o lock está tecnicamente correta.
6. **Erro isolado por usuário — OK, com ressalva (ver 🟠-D1).** O `rescue StandardError` está em `processar_usuario` (por usuário, cobre as 3 chamadas + consolidação). Um erro em `cpfs_com_vinculo_ativo` (Pessoas indisponível) NÃO é isolado — vira `erro` na tarefa. Avaliação: aceitável/não-bloqueante, mas divergente da convenção do codebase.
7. **Testes — 7/7 reais, não vacuosos.** Stub via `com_metodos_de_classe_stubados` faz save/restore real (`UnboundMethod` capturado no `ensure` — `test/support/class_method_stub_helper.rb:59-65`), sem `remove_method`. "Sem vínculo não tocado" é real: `@user_sem_vinculo` (cpf `333...`) não está na lista stubada e é excluído por `User.where(cpf: cpfs)`; mutação `User.where(cpf:cpfs)`→`where.not(cpf:nil)` faz o teste falhar (confirmado pelo autor; reproduzível pela lógica). Runner confirmou 7/21/0F/0E.
8. **Segurança/correção no diff:** nenhum input cru; `User.where(cpf: array)` é parametrizado; sem SQL string interpolado; sem alteração de auth/banco/permissões. Nenhum bug de correção/segurança encontrado.

## Débitos Técnicos (🟠) — não bloqueantes

| ID | Descrição | Arquivo:linha | Impacto | Bloqueante? |
|----|-----------|---------------|---------|-------------|
| 🟠-D1 | `cpfs_com_vinculo_ativo` (query ao Pessoas) está FORA de qualquer `rescue`. Pessoas indisponível (`PG::Error`/`ActiveRecord::ActiveRecordError`) propaga até `ExecutaTarefasJob#processar`, que marca a tarefa `erro`. Como o despacho não tem retry automático, o recálculo global é **perdido** (só recuperável por re-enqueue manual, já que a linha deixa de ser `pendente`). Divergente da convenção do codebase (`FrequentadoresVisiveis` faz `rescue ... rescue` e log `autorizacao_frequencia.pessoas_indisponivel`, fail-closed). O docstring do handler ("Nunca levanta para condições esperadas") é levemente superestimado nesse ponto. | `recalcular_todos_handler.rb:61-71, 79-85` | Tarefa vira `erro` sob outage transitório do Pessoas; recuperação manual. Marcar `erro` é observável e defensável ("falha genuína"), mas difere do fail-closed dos demais pontos de acesso ao Pessoas. | NÃO |
| 🟠-D2 | Sem guard `ConsolidacaoMensalService.finalizado?` prévio (diferente do handler 31.3, que ganhou esse guard no review). Quando hoje é 1º/2º do mês, a janela "últimos 3 dias" inclui dias do mês ANTERIOR que podem pertencer a um mês FINALIZADO: `CalculoDiarioService.calcular` reescreve esses `CalculoDiario` (não há guard de finalização no service) e, em seguida, `consolidar` do mês CORRENTE não levanta `MesFinalizadoError` — logo os dias do mês fechado ficam reescritos sem que o `RegistroMensalFrequencia` (congelado) seja reagregado. | `recalcular_todos_handler.rb:89-99` | Comportamento **herdado por design** (mirror literal do `CalcularFrequenciaJob`, que faz exatamente isso). Não é regressão introduzida pela 31.4. Impacto prático desprezível (limite de mês + mês finalizado manual). | NÃO |

## Elogios (🟢)

| ID | Elogio | Relacionado |
|----|--------|-------------|
| 🟢-E1 | Eixo "vínculo ativo" resolvido SEM inventar eixo novo — reusa `Pessoas::Vinculo.ativos` (canônico), sem JOIN cross-database, exatamente como a cascata/`frequentadores_ativos`. Fidelidade verificada por leitura cruzada dos 4 consumidores. | `recalcular_todos_handler.rb:79-85` |
| 🟢-E2 | Decisão de lock documentada no código com o argumento COMPLETO (por que não herdar `451_926_073`, risco de drenar-sem-efeito, convergência idempotente) — e validada contra os índices UNIQUE das tabelas de destino. Boa engenharia de concorrência. | `recalcular_todos_handler.rb:28-39` |
| 🟢-E3 | Isolamento de erro por usuário + `MesFinalizadoError` como skip silencioso — mirror fiel do `CalcularFrequenciaJob` (17.5), sem refatorar o job (preserva comportamento aprovado). | `recalcular_todos_handler.rb:89-104` |
| 🟢-E4 | Guard de lista vazia + `distinct`/`compact` defensivos, e registro no boot via `to_prepare` idempotente (mesmo padrão da 31.3, sem autoload lazy). | `recalcular_todos_handler.rb:68,82-84`; `recalculo_handlers.rb:30` |

## Ações corretivas

- Nenhuma ação corretiva obrigatória. **0 Blockers** — a entrega está tecnicamente aprovada para commit.
- Opcionais (não bloqueiam): (a) tratar o outage do Pessoas em `cpfs_com_vinculo_ativo` (rescue + log, à la `FrequentadoresVisiveis`) OU ajustar o docstring para não afirmar "nunca levanta"; (b) registrar 🟠-D2 como débito conhecido no código (o handler 31.3 já documenta esse tipo de janela).

## Certificação de entrega

- **Sinal verde:** entrega técnica APROVADA (sem Blockers 🔴).
- **Code Specialist:** pode prosseguir com o agrupamento de commits atômicos e o protocolo de entrega (`COMMIT_MODE=manual` — aguardando autorização de commit/push).
- O fechamento desta rastreabilidade é pré-requisito para o início da próxima tarefa.
