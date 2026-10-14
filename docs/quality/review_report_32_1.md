# Relatório de Revisão — Tarefa 32.1 (débito D2/17.5)

**Revisor:** Code Reviewer (AI Workflow)
**Data:** 2026-10-14
**Branch de origem:** `feature/demanda-32-1-guarda-finalizado-job` (working tree, NÃO commitado)
**Base:** `chore/limpeza-rubocop-77` @ `0e55c2a`
**Repo/app:** `Frequencia/` — app `api-ponto/`

## Escopo revisado

| Arquivo | Natureza |
|---|---|
| `api-ponto/app/jobs/calcular_frequencia_job.rb` | produção (guarda per-dia + pré-consolidação) |
| `api-ponto/test/jobs/calcular_frequencia_job_test.rb` | +3 testes (inserção pura) |
| `docs/progress/iteration_32.md` | rastreabilidade (status 32.1 ✅) |

Fora de escopo (ruído de ambiente, não avaliados): `config/credentials.yml.enc`, `config/environments/development.rb`, `log/*`, `tmp/cache/*`.

## Veredito

✅ **Aprovado** — sem Blockers. A entrega cumpre integralmente os 6 requisitos, o comportamento externo no caminho "mês aberto" está preservado e os 3 testes novos são comprovadamente não-vacuosos (verificado por mutation testing). Arquivos de handler NÃO foram tocados (requisito 6 OK — o espelho do `RecalcularTodosHandler` segue reservado à 32.2).

**Blockers: 0 | Sugestões: 1 (Melhoria: 1 / Débito: 0)**

## Evidências executadas

| Verificação | Comando | Resultado |
|---|---|---|
| Teste focado | `bin/rails test test/jobs/calcular_frequencia_job_test.rb` | **8 runs / 23 asserts / 0F / 0E / 0 skips** |
| Suíte completa | `bin/rails test` | **1217 runs / 4247 asserts / 3F / 12E / 0 skips** (baseline 1214/4239 + 3 novos) |
| RuboCop | `rubocop app/jobs/calcular_frequencia_job.rb test/jobs/calcular_frequencia_job_test.rb` | **2 files inspected, no offenses** |
| Zeitwerk | `bin/rails zeitwerk:check` | **All is good!** |
| Mutation A (guarda per-dia ⇒ `next if false`) | teste focado | **2 failures** (snapshot mês finalizado + virada de mês) |
| Mutation B (guarda pré-consolidação ⇒ `return if false`) | teste focado | **1 failure** ("consolidar NAO e chamado") |

> Nota de ambiente: o `bin/rails`/testes rodaram; o RuboCop direto falha por incompatibilidade de `prism.so` (compilado p/ Ruby 3.3.8 x runtime do loader) — contornado via `ruby -rbundler/setup .../exe/rubocop`. Não é problema do diff.

## Análise por requisito

1. **Guarda antes de qualquer escrita** ✅ — `calcular_frequencia_job.rb:79` (`next if ConsolidacaoMensalService.finalizado?(...)`) precede `:81` (`CalculoDiarioService.calcular`). `finalizado?` só faz leitura.
2. **Cobre a virada de mês** ✅ — a guarda é POR DIA (`dia.year/dia.month`), não pelo mês de `hoje`. Teste "virada de mes" cobre (11/01 → 11/01 calculado, 10/31 e 10/30 pulados).
3. **Consolidação pulada se finalizado** ✅ — `:87` (`return if finalizado?(hoje...)`) precede `:89` (`consolidar`).
4. **Rescues mantidos** ✅ — `:90` `rescue MesFinalizadoError` (agora só alcançável via corrida TOCTOU) e `:95` `rescue StandardError` por usuário.
5. **Comportamento inalterado em mês aberto** ✅ — suíte focada 0F; caminho 3 dias + consolidação idempotente preservado.
6. **Handlers não tocados** ✅ — `git status` não lista `registro_recalculo_handler.rb` nem `recalcular_todos_handler.rb`.

Reuso verificado: grep confirma que **não** foi criada segunda condição de finalização — tanto o job (`:79`,`:87`) quanto os handlers (`registro_recalculo_handler.rb:97`, `vincular_desvincular_handler.rb:129`) usam o ÚNICO predicado canônico `ConsolidacaoMensalService.finalizado?`.

## Semântica de borda (verificação manual)

| Cenário (hoje = dia 1) | Mês anterior finalizado? | Mês corrente finalizado? | Resultado esperado | Diff entrega |
|---|---|---|---|---|
| Normal | – | não | 3 dias recalculados + consolida mês | ✅ |
| Virada | sim | não | dias do mês anterior pulados; dia/mês corrente processados | ✅ (teste 2) |
| Inverso | não | sim | dias do mês anterior (aberto) recalculados; dia e consolidação do corrente pulados | ✅ |
| Mês fechado | sim | sim | tudo pulado, nada reescrito | ✅ (teste 1) |

Nenhum cenário de falso-positivo: `finalizado?` retorna `true` apenas com registro persistido e `finalizado? == true` — semântica pretendida.

## Apontamentos

### 🟡 Sugestão de Melhoria

**🟡 S1 — Queries redundantes de `finalizado?` por usuário (memoização por mês).**
Arquivo: `api-ponto/app/jobs/calcular_frequencia_job.rb:79` e `:87`.
O predicado é chamado até 4×/usuário: no laço, os 3 dias normalmente caem no MESMO mês (fora da virada) ⇒ 3 `find_by` idênticos, mais 1 no `:87` para o mesmo mês ⇒ 4 lookups, sendo que no máximo existem **2 meses distintos** no laço. Na virada de mês, ainda assim são 2 meses distintos consultados 2× cada.
**Impacto:** não é N+1 clássico (não itera linhas de associação) — é O(N_usuários) de `find_by` **indexados** (`index_registro_mensal_frequencias_on_user_ano_mes`, unique — confirmado em `db/schema.rb:232`), portanto lookups de 1 linha baratos. Frente ao custo pré-existente por usuário (3× `calcular` com `RegimeFrequentador.vigente_para` + `find_or_initialize` + estratégia por dia, mais ~5 queries do `consolidar`), o acréscimo é modesto e bounded — **não bloqueia**.
**Sugestão:** memoizar/lookup por par `(ano, mes)` dentro de `processar_usuario` (o job já computa os dias no laço), reduzindo de até 4 para no máximo 2 consultas por usuário. Opcional, ganho pequeno; registrável como refino de baixo risco.
**BLOQUEANTE para commit?** Não.

### 🟢 Elogios

- **🟢 E1** — **Reuso correto do predicado canônico** `ConsolidacaoMensalService.finalizado?` (sem duplicar a regra de finalização), espelhando exatamente a correção do bug A da 31.3. Grep comprova ausência de segunda condição.
- **🟢 E2** — **TOCTOU documentado com honestidade**: o comentário do `rescue MesFinalizadoError` (`:90-94`) e o de cabeçalho explicitam que o rescue virou salvaguarda de corrida — sem superestimar a garantia da guarda prévia.
- **🟢 E3** — **Testes não-vacuosos comprovados por mutation testing** (A ⇒ 2F, B ⇒ 1F) e bem desenhados: snapshot de **ambos** `CalculoDiario` e `RegistroMensalFrequencia`; valores "errados" propositais para detectar reescrita; cobre virada de mês.
- **🟢 E4** — **Uso correto do helper save/restore** `com_metodo_de_classe_stubado` (sem `remove_method`), respeitando a lição da Sprint 29 registrada em `docs/governance/lessons.md`.
- **🟢 E5** — **Sem regressão**: o diff do arquivo de teste é inserção pura (nenhuma linha removida ⇒ nenhuma expectativa pré-existente alterada). Suíte completa fecha em 1217/4247/3F+12E; as 15 falhas/erros são **pré-existentes e não relacionadas** (arquivos distintos: `sessions_controller_test` — `redirect_to` privado; `presenca_endpoints_test` — fuso horário; `pessoas_schema_loader_test` — guard de nome de banco), nenhuma tocando o job.
- **🟢 E6** — Escopo respeitado: nenhum handler alterado (32.2 preservada) e a filosofia 3-dias + mês corrente não foi reaberta.

## Ações corretivas

- Nenhuma obrigatória (sem Blockers).
- Opcional: avaliar 🟡 S1 (memoização) — pode ser registrado como débito de baixa prioridade, sem bloquear a entrega.

## Checklist de rastreabilidade

- [x] Relatório salvo em `docs/quality/review_report_32_1.md`
- [ ] Referência em `docs/progress/iteration_32.md` (recomendado adicionar seção de Review)
- [x] Nenhum commit realizado
- [x] Working tree restaurado ao estado original após mutation testing (md5 do job = `00aa5d32cdf9743228e9c7c311ed3b61`)
