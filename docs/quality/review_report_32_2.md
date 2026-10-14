# Relatório de Revisão — Tarefa 32.2 (débito D2/31.4 — espelho no handler)

**Revisor:** Code Reviewer (AI Workflow)
**Data:** 2026-10-14
**Branch de origem:** `feature/demanda-32-2-espelho-handler` (working tree, NÃO commitado)
**Base:** `fe7f8ff` (32.1 — já contém a guarda no `CalcularFrequenciaJob`)
**Repo/app:** `Frequencia/` — app `api-ponto/`

## Escopo revisado

| Arquivo | Natureza |
|---|---|
| `api-ponto/app/services/recalcular_todos_handler.rb` | produção (guarda per-dia + pré-consolidação + memo) |
| `api-ponto/test/services/recalcular_todos_handler_test.rb` | +4 testes (inserção pura) |
| `docs/progress/iteration_32.md` | rastreabilidade (status 32.2 ✅) |

Fora de escopo (ruído de ambiente, não avaliados): `config/credentials.yml.enc`, `config/environments/development.rb`, `log/*`, `tmp/cache/*`.

## Veredito

✅ **Aprovado** — sem Blockers. A entrega cumpre integralmente os 6 requisitos. `#processar_usuario` é **equivalente linha a linha** ao do `CalcularFrequenciaJob` (32.1): divergências apenas não-semânticas (indentação por viver em `class << self` e o prefixo do log). O memo é **local por usuário** (sem vazamento). Os 4 testes novos são comprovadamente **não-vacuosos** (mutation testing reproduzido: 2F/1F/1F). Escopo respeitado (job/handlers de registro NÃO tocados).

**Blockers: 0 | Sugestões: 0 formais (Melhoria: 0 / Débito: 0) — 1 observação fora de escopo, não bloqueante.**

## Evidências executadas

| Verificação | Comando | Resultado |
|---|---|---|
| Teste focado | `bin/rails test test/services/recalcular_todos_handler_test.rb` | **11 runs / 30 asserts / 0F / 0E / 0 skips** |
| Suíte completa | `bin/rails test` | **1222 runs / 4257 asserts / 3F / 12E / 0 skips** (baseline 1218/4248 + 4 novos: +4 runs / +9 asserts) |
| RuboCop | `rubocop app/services/recalcular_todos_handler.rb test/services/recalcular_todos_handler_test.rb` | **2 files inspected, no offenses** |
| Zeitwerk | `bin/rails zeitwerk:check` | **All is good!** |
| Mutation A (remove guarda per-dia) | teste focado | **2 failures** (snapshot mês finalizado + virada de mês) |
| Mutation B (remove guarda pré-consolidação) | teste focado | **1 failure** ("consolidar NAO e chamado") |
| Mutation C (memo `Hash#key?` → `\|\|=` truthiness) | teste focado | **1 failure** ("finalizado? e consultado uma vez") |

Falhas da suíte completa (15 = 3F+12E), todas **pré-existentes e não relacionadas** — nenhuma toca o handler: `test/controllers/users/sessions_controller_test.rb` (9), `test/controllers/users/passwords_controller_test.rb` (2), `test/lib/seeds_test.rb` (2), `test/integration/presenca_endpoints_test.rb` (1, fuso), `test/lib/pessoas_schema_loader_test.rb` (1). Mesmo conjunto do baseline 32.1.

## Análise por requisito

1. **Guarda por dia, reusando `finalizado?`, antes de `calcular`** ✅ — `recalcular_todos_handler.rb:131-136`: `next if finalizado.call(dia.year, dia.month)` precede `CalculoDiarioService.calcular` (`:135`). `finalizado?` só faz leitura (`consolidacao_mensal_service.rb:78-81`). Nenhuma segunda condição de finalização criada (reuso).
2. **Guarda antes de consolidar** ✅ — `:141` (`return if finalizado.call(hoje.year, hoje.month)`) precede `:143` (`consolidar`).
3. **Memo por `[ano, mes]` com `Hash#key?`** ✅ — `:114-120`. `key?` distingue "não cacheado" de "cacheado como false" (o caminho comum é `false`); `||=` reconSUltaria. Comprovado pela mutation C.
4. **Escopo do memo = por usuário** ✅ — `meses_finalizados = {}` é criado **dentro** de `processar_usuario` (`:114`), que é chamado **por usuário** no `find_each` de `call` (`:76`). Cada invocação tem seu próprio hash ⇒ **não vaza** "finalizado" de um usuário para outro. (Um memo em ivar/classe seria 🔴 — não é o caso.)
5. **Rescues mantidos** ✅ — `:144` `rescue MesFinalizadoError` (salvaguarda de corrida/TOCTOU) e `:150` `rescue StandardError => e` por usuário, com log por CPF (`:153`); guard `user.cpf.blank?` em `:98`.
6. **Comportamento externo inalterado (mês aberto)** ✅ — teste focado 0F; caminho 3 dias + consolidação idempotente preservado.
7. **Escopo intocado** ✅ — `git status` não lista `registro_recalculo_handler.rb`, `vincular_desvincular_handler.rb` nem `calcular_frequencia_job.rb`. Ordem 32.1 → 32.2 respeitada: branch nasce de `fe7f8ff` (32.1).

## Equivalência handler × job (comparação linha a linha de `processar_usuario`)

| Elemento | `RecalcularTodosHandler` | `CalcularFrequenciaJob` | Divergência |
|---|---|---|---|
| Guard `cpf.blank?` | `:98` | `:65` | nenhuma |
| `hoje = Date.current` | `:100` | `:67` | nenhuma |
| Memo `{}` + lambda + `return ... if key?` | `:114-120` | `:83-89` | nenhuma (semântica idêntica) |
| Guarda per-dia (`next if finalizado.call`) | `:131-136` | `:100-105` | nenhuma |
| Guarda pré-consolidação (`return if finalizado.call`) | `:141` | `:110` | nenhuma |
| `consolidar(user, hoje.year, hoje.month)` | `:143` | `:112` | nenhuma |
| `rescue MesFinalizadoError` | `:144` | `:113` | nenhuma |
| `rescue StandardError => e` + log por CPF | `:150-153` | `:114-116` | prefixo do log (`[RecalcularTodosHandler]` × `[CalcularFrequenciaJob]`) — não-semântica |
| Indentação | dentro de `class << self` | método de instância | não-semântica |

**0 divergência de regra.** A duplicação é intencional (decisão da 31.4 de não extrair colaborador) — não é achado.

## Interação `return` × `rescue` (verificação manual)

- `return if finalizado.call(hoje.year, hoje.month)` (`:141`) é um **retorno de método**, não uma exceção ⇒ **não** é capturado pelos `rescue` abaixo. Nenhum caminho de exceção ficou descoberto.
- O `return` interno do lambda (`:117`) sai do **lambda** (não do método) — comportamento correto; idêntico ao job.

## Cenários de borda (hoje = dia 1 da virada)

| Cenário | Mês anterior finalizado? | Mês corrente finalizado? | Resultado esperado | Diff |
|---|---|---|---|---|
| Normal | – | não | 3 dias recalculados + consolida mês | ✅ |
| Virada | sim | não | dias do mês anterior pulados; dia/mês corrente processados | ✅ (teste 2) |
| Inverso | não | sim | dias do anterior (aberto) recalculados; dia + consolidação do corrente pulados | ✅ |
| Mês fechado | sim | sim | tudo pulado, nada reescrito | ✅ (teste 1) |

## Apontamentos

### 🟢 Elogios

- **🟢 E1** — **Espelho fiel**: `#processar_usuario` do handler é semanticamente idêntico ao do `CalcularFrequenciaJob` (32.1). Só há divergência de indentação e prefixo de log. O desalinhamento que o débito D2 alertava **deixou de existir**.
- **🟢 E2** — **Memo corretamente local por usuário** (`:114`), criado dentro de `processar_usuario`. Sem vazamento entre usuários — o risco apontado (memo global/persistente) **não** se materializa.
- **🟢 E3** — **Testes não-vacuosos comprovados por mutation testing** (A ⇒ 2F, B ⇒ 1F, C ⇒ 1F), reproduzidos nesta revisão e batendo exatamente com a alegação do dev. Snapshot cobre **ambos** `CalculoDiario` **E** `RegistroMensalFrequencia` com valores "errados" propositais; cobre virada de mês.
- **🟢 E4** — **Uso correto do helper save/restore** `com_metodos_de_classe_stubados` (captura `UnboundMethod` + reinstala no `ensure`; **sem** `remove_method`), respeitando a lição da Sprint 29.
- **🟢 E5** — **Sem regressão**: diff do teste é **inserção pura** (nenhuma linha removida ⇒ nenhuma expectativa pré-existente alterada; 7 pré-existentes seguem verdes). Suíte completa fecha em 1222/4257/3F+12E; as 15 falhas/erros são pré-existentes e em arquivos distintos do handler.
- **🟢 E6** — **Escopo respeitado**: `RegistroRecalculoHandler` (31.3), `VincularDesvincularHandler` (31.5/Q16) e `CalcularFrequenciaJob` **não tocados**; ordem 32.1 → 32.2 respeitada (base `fe7f8ff`).
- **🟢 E7** — **Evidência do dev verificável e honesta**: os números em `iteration_32.md` (11/30/0F+0E; 1222/4257/3F+12E; mutation 2F/1F/1F) conferem com as execuções independentes desta revisão.

### Observações (fora de escopo, NÃO bloqueantes)

- **⚪ O1** — O comentário de cabeçalho do arquivo de teste (`recalcular_todos_handler_test.rb:3`) escreve `RECALCALAR_TODOS` (typo; o tipo real é `RECALCULAR_TODOS`). **Pré-existente**, não faz parte deste diff. Registrado apenas para eventual higienização futura.
- **⚪ O2** — Permanece uma janela TOCTOU mínima: entre o predicado `finalizado?` e o `calcular`/`consolidar`, o mês pode ser finalizado por outro processo. É **débito conhecido, documentado** (`:146-149`) e de **paridade exata** com o job (32.1) — a 32.2 não introduz nem agrava; não é achado desta tarefa.

## Ações corretivas

- Nenhuma obrigatória (sem Blockers).

## Checklist de rastreabilidade

- [x] Relatório salvo em `docs/quality/review_report_32_2.md`
- [ ] Referência em `docs/progress/iteration_32.md` (recomendado adicionar seção de Review)
- [x] Nenhum commit realizado
- [x] Working tree restaurado ao estado original após mutation testing (`diff` do handler vs. backup = idêntico; `git diff --stat` = +54/-4)
