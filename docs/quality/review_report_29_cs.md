# Relatório de Revisão — Code Reviewer — Iteração 29 — Tarefa 29.1 (reavaliação)

> **Tipo:** review_report (reavaliação)
> **Data:** 2026-09-25
> **Branch origem:** `feature/demanda-29-exposicao-gestores-unidade` (revisão inicial, 0 blockers)
> **Branch destino:** `feature/demanda-29-correcoes-review` (correções HIGH-1/HIGH-2/LOW-1)
> **Base:** `bd3152a` — trabalho **não commitado** (`COMMIT_MODE=manual`; sem commit/push)
> **Arquivos alterados (revisados):** `api-ponto/app/models/pessoas/unidade.rb` (+28, **inalterado** desde a revisão inicial), `api-ponto/app/models/pessoas/pessoa.rb` (+10, **inalterado**), `api-ponto/test/models/pessoas_unidade_test.rb` (novo, 135 l.), `api-ponto/test/models/pessoas_pessoa_test.rb` (novo, 41 l.), `docs/progress/iteration_29.md` (+18/−5, doc), `docs/progress/_context.md` (+40/−32, doc)
> **Tarefa revisada:** 29.1 — Expor hierarquia e gestores de órgão no espelho `Pessoas::Unidade` (3 pts, Dev A, PRD §3 passo 5)
> **Validação executada nesta reavaliação:** testes direcionados 13/53/0; suíte completa 793/2886/1; RuboCop dos 4 arquivos 0 offenses; RuboCop completo 60 offenses; Zeitwerk OK; Brakeman 4 warnings, 0 nos arquivos da 29.1; **2 mutation tests** (guard de auto-referência e FKs de association) para provar que os testes novos discriminam.

## Veredito

**✅ APROVADO — sem Blockers (🔴) e sem achados de alta gravidade.**

Os três achados abertos na revisão anterior (HIGH-1, HIGH-2, LOW-1) foram **corrigidos e validados por mutation testing** — não apenas por leitura. O código de produção está **byte-idêntico** ao aprovado anteriormente (diff md5 conferido), o que elimina risco de regressão funcional. A documentação foi atualizada e é majoritariamente coerente, com uma regressão de rastreabilidade e três erros textuais registrados abaixo.

| Achado anterior | Status | Evidência |
|---|---|---|
| HIGH-1 — guard de auto-referência sem cobertura | ✅ **FECHADO** | `pessoas_unidade_test.rb:80-87`; mutation test confirma falha com o guard removido |
| HIGH-2 — FK das associations sem asseveração | ✅ **FECHADO** | `pessoas_unidade_test.rb:12-25`; mutation test confirma falha com FK errada |
| LOW-1 — `gestor?` sem caso negativo / sem instâncias distintas | ✅ **FECHADO** | `pessoas_unidade_test.rb:44-49` e `:51-58`; mutation com `equal?` falha |
| MEDIUM-2 — testes de metamodelo inflando o total | ⚪ **MOOT** | O teste de reflection passou a ser evidência substancial da 29.1 (mapeamento de FK), não metamodelo puro |
| MEDIUM-1 — N+1 em `gestor?`/`cadeia_ascendente` | ⏭️ **CARRIED** | Sem mudança (correto: fora do escopo da 29.1) → restrição de 29.4/29.6 |
| MEDIUM-3 — CPF normalizado só na entrada | ⏭️ **CARRIED** | Sem mudança (correto) → mitigação log em 29.4 |
| LOW-2 — monkey-patch de singleton não revertido | ⏭️ **ABERTO (baixo)** | `pessoas_unidade_test.rb:132-134`, `pessoas_pessoa_test.rb:38-40` |
| SUGGESTION-1 — ciclo entre ancestrais não neutralizado | ⏭️ **ABERTO (info)** | `unidade.rb:32,37` → `.uniq`/`.distinct` na 29.6 |
| SUGGESTION-2 — 3 jobs duplicam `por_user` | ⏭️ **CARRIED** | Não alterar na 29.1 (regra global 3) |

## Blockers (🔴)

Nenhum.

## Achados de alta gravidade

Nenhum. HIGH-1, HIGH-2 e LOW-1 foram encerrados.

## Achados desta reavaliação

### 🟡 MEDIUM-1 (novo, documentação) — `_context.md` perdeu a pré-condição bloqueante do merge da 23.7

**`Frequencia/docs/progress/_context.md`** (reescrita completa) vs **`Frequencia/docs/progress/iteration_29.md:12`**

```
$ grep -n "23\.7" docs/progress/_context.md
>>> AUSENTE
```

A versão anterior do `_context.md` carregava explicitamente *"Merge da 23.7 continua pendente (bloqueia 24.3)"* no Estado atual. A reescrita removeu **todas** as menções a 23.7, mas `iteration_29.md:12` mantém a pré-condição viva: *"a 23.7 (CanCanCan nos controllers) precisa estar mergeada — esta sprint altera a `Ability`"* — ou seja, **29.7 está condicionada a um merge que o `_context.md` não registra mais**.

**Cenário concreto:** um agente entra na Sprint 29 lendo `docs/progress/_context.md` (leitura obrigatória pelo AGENTS.md §4), vê "Sprint 29 ativa; 29.2/29.4/29.7 dependem das decisões D1–D4" (`_context.md:31`) e **não** descobre que a 29.7 também depende do merge da 23.7. Inicia a alteração da `Ability` sem a pré-condção satisfeita.

**Recomendação:** reintroduzir em `_context.md` uma linha em "Estado atual", p.ex.: `- Merge da 23.7 (CanCanCan nos controllers) segue pendente: pré-condição da 29.7, que altera a Ability.` Não bloqueia a entrega da 29.1; é correção documental de 1 linha.

### 🟡 MEDIUM-2 (novo, pipeline) — "Brakeman OK" nos docs é um *falso verde*: o scan não executa

**`Frequencia/api-ponto/bin/brakeman:5`** · impacto declarado em `docs/progress/_context.md:30` e `Frequencia/docs/progress/iteration_29.md:155-156`

```ruby
# bin/brakeman
ARGV.unshift("--ensure-latest")     # <-- binstub força esta flag
```

Diagnóstico fechado nesta reavaliação: `bin/brakeman` (8.0.5) imprime **apenas** `Brakeman 8.0.5 is not the latest version 8.0.6` e **sai com código 0 sem escanear** — a flag `--ensure-latest` aborta antes do scan porque 8.0.5 < 8.0.6. Três evidências convergentes: (a) a única saída é o aviso de versão, que é exatamente a saída de `--ensure-latest`; (b) `bin/brakeman -o arquivo.json` **não cria o arquivo**, algo que um scan real sempre faria; (c) `bundle exec` com a flag contornada produz o relatório.

Contornando o binstub, o scan real retorna **4 warnings, todos pré-existentes e nenhum nos arquivos da 29.1**:

| Check | Arquivo | Linha |
|---|---|---|
| Dangerous Eval (Weak) | `app/helpers/application_helper.rb` | 33 |
| SQL Injection (Weak) | `app/controllers/admin/frequencia_por_orgao_controller.rb` | 71 |
| SQL Injection (Weak) | `app/controllers/admin/frequencia_por_orgao_controller.rb` | 72 |
| (4º warning) | — | pré-existente |

`grep -c "pessoas/unidade.rb\|pessoas/pessoa.rb"` no relatório → **0**.

**Recomendação (duas frentes, ambas de infra, nenhuma bloqueia a 29.1):**
1. **Pipeline:** o step de security do `.gitlab-ci.yml` está inerte enquanto o binstub exigir "latest". Remover o `--ensure-latest` do binstub ou fixar a versão no Gemfile, e **validar o step com um warning intencional** antes de tratá-lo como gate.
2. **Docs:** enquanto (1) não for feita, trocar "Brakeman OK" por "Brakeman **não executado** (binstub `--ensure-latest` + versão defasada); scan manual via `bundle exec` retorna 4 warnings pré-existentes, 0 na 29.1".

### 🟠 LOW-1 (novo, qualidade de teste) — Caso negativo de `gestor?` é confundido por classe anônima distinta

**`api-ponto/test/models/pessoas_unidade_test.rb:44-49`**

```ruby
pessoa = Struct.new(:id).new(42)
outra_pessoa = Struct.new(:id).new(43)   # 2 chamadas => 2 classes anônimas DISTINTAS
assert_not build_unidade(gestor: pessoa).gestor?(outra_pessoa)
```

Verificado empiricamente em Ruby puro:

```
mesmo id, classes diferentes -> a == b ? false
mesmo id, MESMA classe      -> x == y ? true
```

`Struct#==` compara **classe + membros**. Como as duas linhas criam **duas classes anônimas diferentes**, o teste passaria **mesmo que os ids fossem iguais** — ele não isola "id diferente ⇒ `false`", que é a invariante de que a 29.4 depende (uma pessoa com o mesmo id é a mesma pessoa; com id diferente, não). O teste continua sendo um caso negativo válido, porém mais fraco do que aparenta.

Note-se que o teste vizinho **`:51-58` faz certo**: usa `pessoa_class = Struct.new(:id)` uma única vez e duas instâncias da mesma classe, com `refute_same`. A mutação para `equal?` falha em `:57` — comprovando que esse teste discrimina de fato.

**Recomendação (2 linhas):**
```ruby
pessoa_class = Struct.new(:id)
assert_not build_unidade(gestor: pessoa_class.new(42)).gestor?(pessoa_class.new(43))
```

### 🟠 LOW-2 (herdado, aberto) — Monkey-patch de classe singleton não revertido

**`api-ponto/test/models/pessoas_unidade_test.rb:132-134`** e **`api-ponto/test/models/pessoas_pessoa_test.rb:38-40`**

```ruby
Pessoas::Unidade.define_singleton_method(:where, original_where)
```

`original_where` é o método **herdado** de `ActiveRecord::Relation`; restaurar com `define_singleton_method` não remove o override, deixando um método singleton permanente em `Pessoas::Unidade`. Impacto contido (`test_helper.rb:8` faz *fork* por worker), mas é mutação permanente de classe de produção em tempo de teste. **Recomendação:** `singleton_class.send(:remove_method, :where)` quando o método não existia antes no singleton, ou `Minitest::Mock`/`stub`.

### ⚪ LOW-3 (novo, documentation) — Erros textuais em `_context.md`

- **`_context.md:20`** — *"registrada como **pendiente** de Code Reviewer"* — palavra em **espanhol** num documento em português. Correto: *"pendente de"*.
- **`_context.md:24`** — *"auto-referência **válida** sem consulta"* — terminologia imprecisa: o `ancestry` que se auto-referencia é **inválido**; o que é válido é a **detecção** dele. Sugestão: *"path de ancestry com auto-referência é corretamente rejeitado sem consulta"*.
- **`_context.md:40`** — ausência de newline no fim do arquivo (pré-existente, mantida).

### ⚪ SUGGESTION-1 (herdado, carried) — Ciclo entre ancestrais não neutralizado

**`api-ponto/app/models/pessoas/unidade.rb:32,37`**

O guard cobre só o id da **própria** unidade. Numa path numericamente válida com id repetido entre ancestrais (ex.: `ancestry = "2/1/2"`), `index_by` (`:35`) deduplica e o `filter_map` (`:37`) devolve `[self, u2, u1, u2]` — `u2` **duas vezes**. Inofensivo para 29.4 (`find`/`any?`); em **29.6** (scope SQL) exigir `.distinct`. **Não alterar agora.**

### ⚪ SUGGESTION-2 (herdado, carried) — 3 jobs duplicam o que `por_user` padroniza

`api-ponto/app/jobs/importar_dados_pessoa_job.rb:33`, `api-ponto/app/jobs/sincronizar_afastamentos_job.rb:46`, `api-ponto/app/jobs/importar_servidores_unidade_job.rb:66`. **Não alterar na 29.1** (regra global 3). Registrar como chore pós-29.4.

## Elogios (🟢)

| ID | Elogio |
|----|--------|
| E1 | **Teste de mutação, não só teste que passa.** Os 3 testes novos atacam exatamente as branches que a revisão pediu, e o mutation test confirma que discriminam. Fechar HIGH-1 apenas com um teste que passa não provaria nada. |
| E2 | O teste do guard verifica **as duas** invariantes: retorno (`assert_equal [unidade], ...`) **e** ausência de consulta (`assert_empty consultas`). A segunda é a que realmente discrimina — provado: com o guard removido o retorno ainda é `[unidade]`, mas a query `{id: [3, 1]}` aparece. |
| E3 | Teste de reflection virou **data-driven** (hash `association => foreign_key` em `:13-17`), eliminando a chance de as três associations divergirem por cópia-e-cola. |
| E4 | `refute_same gestor, pessoa` (`:56`) documenta *dentro* do teste por que o caso existe — o duplo não é a mesma instância. É auto-explicativo. |
| E5 | **Zero mudança em código de produção.** O diff dos dois models é byte-idêntico ao da revisão aprovada (md5 conferido): risco de regressão funcional estruturalmente zero. |
| E6 | Trilha de auditoria preservada em `iteration_29.md:154-156`: a linha original (10/41) **não** foi sobrescrita, e as duas novas linhas de 2026-09-25 separam *implementação*, *correções* e *revalidação*. |
| E7 | Branch dedicada `feature/demanda-29-correcoes-review`, sem `git add -A` — apesar dos logs rastreados no worktree, o worktree está limpo de artefatos de teste. |

## Verificação item-a-item (pedido explícito)

| # | Item | Veredito | Evidência |
|---|---|---|---|
| 1 | Guard de auto-referência — retorno **e** ausência de consulta | ✅ **CONFIRMADO** | `pessoas_unidade_test.rb:80-87`. Retorno: `assert_equal [unidade], unidade.cadeia_ascendente` (`:84`). Sem consulta: `assert_empty consultas` (`:85`). **Mutation test:** com `unidade.rb:32` removido o teste falha com `Expected [{id: [3, 1]}] to be empty.` — discrimina de verdade. |
| 2 | `foreign_key` e `active_record_primary_key` das 3 associations | ✅ **CONFIRMADO** | `pessoas_unidade_test.rb:12-25`, data-driven. Asserções em `:21` (`foreign_key`) e `:22` (`active_record_primary_key`), além de `class_name` (`:20`) e `optional` (`:23`). **Mutation test:** com FKs erradas o teste falha em `:21` (`"gestor_id"` vs `"gestor_pessoa_id"`). Cruzado com `pessoas2/db/schema.rb:4809,4820-4822`. |
| 3 | `gestor?` — pessoa diferente **e** instâncias distintas mesmo id | ⚠️ **PARCIAL** | Instâncias distintas (`:51-58`): ✅ correto e **discrimina** (mutation `equal?` → falha em `:57`). Pessoa diferente (`:44-49`): ⚠️ presente mas **confundido** por classes anônimas distintas → LOW-1. |
| 4 | Coerência de `_context.md` e `iteration_29.md` | ⚠️ **PARCIAL** | `iteration_29.md`: ✅ coerente (status `:1` e `:49`, trilha `:154-156`, ACs `[x]` com evidência agora real). `_context.md`: ⚠️ atualizado e muito mais útil, mas **perdeu a pré-condição 23.7** (MEDIUM-1) e tem 3 erros textuais (LOW-3). |
| 5 | Escopo, segurança, readonly, ausência de regressões | ✅ **CONFIRMADO** | Escopo: só 4 arquivos de código/teste + 2 docs; zero migration, zero controller/rota/`Ability`, zero gem. Readonly: `pessoas_unidade_test.rb:27-29`; `PessoasRecord#readonly?` inalterado; zero escrita introduzida. Regressões: 793/2886/**1** — a mesma falha baseline de timezone, `presenca_endpoints_test.rb:187`. Segurança: Brakeman real → **0 warnings** nos arquivos da 29.1; nenhum SQL com interpolação de entrada do usuário. |

## Validações executadas (não destrutivas)

| # | Comando | Resultado |
|---|---------|-----------|
| 1 | `bin/rails test test/models/pessoas_{unidade,pessoa}_test.rb` | ✅ **13 runs / 53 assertions / 0 failures** — confere com `_context.md:29` e `iteration_29.md:155-156` |
| 2 | `bin/rails test` (suíte completa) | ⚠️ **793 runs / 2886 assertions / 1 failure** — `PresencaEndpointsTest#test_POST_SincronizarRegistrosPonto_...` em `test/integration/presenca_endpoints_test.rb:187` (timezone, idêntica à baseline de `review_report_23_cs.md:10`). **Nenhuma regressão.** 793−13 = 780 = 790−10 da revisão anterior. |
| 3 | `bin/rubocop` nos 4 arquivos | ✅ 0 offenses |
| 4 | `bin/rubocop` completo | ✅ **60 offenses** (222 arquivos) — confere com a alegação; todos pré-existentes |
| 5 | `bin/rails zeitwerk:check` | ✅ `All is good!` |
| 6 | `bin/brakeman` | ⚠️ **no-op** (ver MEDIUM-2) |
| 7 | `RUBYOPT= bundle exec brakeman` (contorna o binstub) | ✅ Scan real: **4 warnings, 0 nos arquivos da 29.1** |
| 8 | **Mutation test 1** — guard de `unidade.rb:32` removido | ✅ Teste **falha** (`Expected [{id: [3, 1]}] to be empty.`) → HIGH-1 fechado |
| 9 | **Mutation test 2** — FKs erradas + `gestor?` com `equal?` | ✅ **2 falhas** (`Expected "gestor_id", got "gestor_pessoa_id"` em `:21`; `Expected false to be truthy` em `:57`) → HIGH-2 e LOW-1 fechados |
| 10 | `git diff` dos models (md5) | ✅ **Byte-idêntico** à revisão aprovada — nenhum código de produção alterado |
| 11 | Verificação Ruby da semântica de `Struct#==` | ✅ Confirma o achado LOW-1 (2 classes anônimas ⇒ `==` falso mesmo com id igual) |
| 12 | `git status --porcelain` | Artefatos temporários de validação removidos; worktree idêntico ao deixado pelo Code Specialist |

## Riscos residuais e limitações

- **R1 — Sem validação com camada AR real.** `pessoas_test` segue sem as tabelas do espelho (verificado: `select current_database()` → `pessoas_test`; `tables.grep(/^unidades$|^pessoas$/)` → `[]`). A asserção de `foreign_key` (item 2) fecha a lacuna **de convenção do Rails**, mas **não** substitui uma introspecção do banco real: se o Pessoas2 tiver um `type` de STI em `unidades`, ou um *trigger*/`generated column*, a suíte não veria. Mapeamento atual confirmado por cross-check em `pessoas2/db/schema.rb:4809,4820-4822` (todos indexados).
- **R2 — Sem amostra real de `unidades.ancestry`.** A conclusão sobre o formato raiz→pai continua derivada do *source* da gem `ancestry` v4.1.0 (`pessoas2/Gemfile.lock:83`) e não de dados de produção. **Recomendação mantida:** `SELECT ancestry FROM unidades WHERE ancestry IS NOT NULL ORDER BY updated_at DESC LIMIT 20` antes da 29.4.
- **R3 — Regressão documental de rastreabilidade.** MEDIUM-1 deixa a 29.7 sem pré-condição visível no `_context.md`.
- **R4 — Gate de segurança inerte.** MEDIUM-2 — 4 warnings pré-existentes estão hoje invisíveis ao pipeline. Nada na 29.1, mas o gate não deve ser considerado eficaz.
- **R5 — Semântica "gestor excepcional" Pessoas2 × Intranet** não verificada 1:1 (pré-existente, `iteration_29.md:147`); segue pendente para a 29.8.
- **R6 — Artefatos rastreados no worktree.** `log/development.log`, `log/test.log` e `tmp/cache/bootsnap/load-path-cache` seguem como `M`. Com commit manual, **stagear seletivamente** (4 arquivos de código/teste + 2 docs) — nunca `git add -A`.
- **R7 — Mutação 2 cobre só `equal?`.** O teste de instâncias distintas prova que o código não usa identidade; não prova que usa `==` do ActiveRecord (que resolve por `instance_of?` + `id`). A semântica real foi verificada por paridade com `pessoas2/app/models/unidade.rb` (`self.gestor == pessoa`).

## Checklist de revisão

**Escopo** — [x] Só 4 arquivos de código/teste + 2 docs · [x] zero migration · [x] zero controller/rota/`Ability` · [x] zero gem · [x] nenhum arquivo fora do escopo tocado

**Segurança** — [x] Brakeman real: 0 warnings na 29.1 · [x] zero SQL com interpolação de entrada do usuário (`where(id: [...])` com inteiros de `to_i`; `find_by(cpf:)` com bind param) · [x] fail-closed preservado em todos os caminhos corrompidos · [x] nenhum caminho de escrita · [x] `por_user` não embute lógica de autorização

**Readonly** — [x] `PessoasRecord#readonly?` inalterado (`pessoas_record.rb:15-17`) · [x] asserção preservada em `pessoas_unidade_test.rb:27-29` · [x] zero escrita introduzida no banco Pessoas

**Qualidade dos testes** — [x] 3 achados anteriores fechados com **mutation testing** · [x] asserções sobre a forma da query (`assert_empty consultas`, `assert_equal [{id: [2, 1]}]`) preservadas · [x] testes data-driven onde cabia · [ ] LOW-1: caso negativo de `gestor?` confundido por classe anônima · [ ] LOW-2: monkey-patch de singleton não revertido

**Documentação** — [x] `iteration_29.md` coerente e com trilha de auditoria preservada · [x] `_context.md` regenerado com data, fontes e gatilhos corretos · [ ] MEDIUM-1: pré-condição 23.7 removida do `_context.md` · [ ] LOW-3: "pendiente" (espanhol), "auto-referência válida", falta de newline

**Conformidade estrutural** — [x] FSM não aplicável · [x] sem transações/locks novos (só leitura) · [x] guards fail-safe e na ordem correta (`:28` → `:31` → `:32` → consulta) · [x] nenhuma nova exceção propagada · [x] fail-closed com log previsto para 29.4

## Ações corretivas

**Nenhuma bloqueia a entrega.** Sugestões para o Code Specialist (opcionais, correções rápidas):

- [ ] **LOW-1** — `pessoas_unidade_test.rb:44-49`: hoistar `pessoa_class = Struct.new(:id)` (2 linhas)
- [ ] **LOW-3** — `_context.md:20` "pendiente" → "pendente"; `:24` "auto-referência válida" → "path de ancestry com auto-referência é rejeitado sem consulta"
- [ ] **LOW-2** — restaurar `where`/`find_by` com `remove_method` em vez de `define_singleton_method`
- [ ] **MEDIUM-1** — `_context.md` Estado atual: reintroduzir a pré-condição do merge da 23.7 para a 29.7 (1 linha)
- [ ] **MEDIUM-2** — pipeline: remover `--ensure-latest` de `bin/brakeman:5` ou fixar a versão; e trocar "Brakeman OK" por "Brakeman não executado" nos docs até a correção
- [ ] **R6** — stagear seletivamente no commit manual

**Carried forward (não tocar na 29.1):**
- [ ] 29.4 — `includes(:gestor, :gestor_substituto, :gestor_excepcional)` ao percorrer a cadeia (MEDIUM-1 da revisão inicial / N+1)
- [ ] 29.4 — logar a negação quando `user.cpf` presente e `por_user` → `nil`
- [ ] 29.6 — `.uniq`/`.distinct` no scope SQL (SUGGESTION-1) + teste de contagem de queries
- [ ] 29.4 — amostra real de `unidades.ancestry` (R2)
- [ ] pós-29.4 — migrar os 3 jobs para `por_user` (SUGGESTION-2)

## Referências

- Revisão inicial desta tarefa (0 blockers, 8 achados): relatório da sessão anterior de 2026-09-25
- Schema autoritativo do espelho: `pessoas2/db/schema.rb:4809` (`ancestry`), `:4820-4822` (gestores), `:3293,3342` (`pessoas.cpf`)
- Modelo de referência: `pessoas2/app/models/unidade.rb` (`gestor?`, `gestor_ativo`, as 3 `belongs_to`, `reload_gestor_intranet`)
- Semântica do materialized path: gem `ancestry` v4.1.0 — `parent_id = ancestor_ids.last`, `root_id = ancestor_ids.first`
- Baseline de suíte: `docs/quality/review_report_23_cs.md:10`
