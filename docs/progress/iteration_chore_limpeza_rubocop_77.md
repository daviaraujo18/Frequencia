# iteration chore: limpeza RuboCop-77 (zerar offenses pré-existentes)

> **Modo:** AGILE | **Branch:** `chore/limpeza-rubocop-77` | **Data:** 2026-10-13
> **Base:** `4ddca3b` (HEAD da pilha da Sprint 31, branch `feature/demanda-31-5-vincular-desvincular`)
> **Rastreabilidade:** débito **RuboCop-77** registrado na §"Encerramento da Sprint 31" e no
> `docs/progress/_context.md` (deadline 2026-10-13).
> **Tipo:** chore (higiene/estilo — autocorrect seguro, sem alteração de comportamento).
> **COMMIT_MODE=manual** (sem commit/push nesta etapa — o coordenador commita).

## Descrição

Zerar as **75 offenses pré-existentes** do RuboCop que o gate de CI (`.gitlab-ci.yml`, estágio
`quality`) reporta como falha. Todas severity `convention`, restritas a **16 arquivos**. As três
cops envolvidas são puramente cosméticas:

| Cop | Qtde | Natureza |
|---|---|---|
| `Layout/SpaceInsideArrayLiteralBrackets` | 54 | espaçamento dentro de `[...]` |
| `Style/StringLiterals` | 16 | aspas simples → duplas |
| `Layout/TrailingEmptyLines` | 5 | newline final ausente |

## Procedimento executado

1. Branch `chore/limpeza-rubocop-77` criada a partir de `4ddca3b` (`git checkout -b`, sem git-flow — AGILE).
2. **`bin/rubocop -a`** (autocorrect **SEGURO** — `-a`, nunca `-A`), ambiente Ruby 3.3.8 (mise) + `BUNDLE_PATH` do vendor.
   - RuboCop corrigiu **48 offenses** (`48 offenses detected, 48 offenses corrected`, EXIT 0).
   - As 75 offenses originais viram 48 "corrigíveis" porque, em `[a, b]`, a cop emite **2 offenses na
     mesma linha** (o `[` e o `]`); o RuboCop marca a 1ª `[Correctable]` e a 2ª não, mas a correção de
     espaçamento elimina **ambas** de uma vez. Nada ficou por corrigir.
3. **Gate binário:** `bin/rubocop` → **EXIT 0, 290 files inspected, no offenses detected**.

## Arquivos alterados (offenses antes → depois)

Todos os 16 arquivos foram a **0 offenses**. Nenhuma supressão/`rubocop:disable` foi usada.

| # | Arquivo | Antes | Depois |
|---|---|---|---|
| 1 | `api-ponto/config/routes.rb` | 18 | 0 |
| 2 | `api-ponto/app/services/intranet/sync_digitais_service.rb` | 15 | 0 |
| 3 | `api-ponto/app/controllers/admin/time_records_controller.rb` | 10 | 0 |
| 4 | `api-ponto/test/migrations/add_devise_to_users_migration_test.rb` | 6 | 0 |
| 5 | `api-ponto/test/migrations/rolify_create_roles_migration_test.rb` | 4 | 0 |
| 6 | `api-ponto/db/migrate/20260910000001_rolify_create_roles.rb` | 4 | 0 |
| 7 | `api-ponto/app/controllers/admin/users_controller.rb` | 4 | 0 |
| 8 | `api-ponto/app/controllers/admin/sessions_controller.rb` | 4 | 0 |
| 9 | `api-ponto/test/services/intranet/sync_digitais_service_test.rb` | 2 | 0 |
| 10 | `api-ponto/test/services/crypto_des_test.rb` | 2 | 0 |
| 11 | `api-ponto/test/controllers/presenca/ponto_de_presenca_controller_test.rb` | 1 | 0 |
| 12 | `api-ponto/config/importmap.rb` | 1 | 0 |
| 13 | `api-ponto/app/controllers/presenca/validar_frequentador_controller.rb` | 1 | 0 |
| 14 | `api-ponto/app/controllers/presenca/dyn_hash_frequentadores_estacao_controller.rb` | 1 | 0 |
| 15 | `api-ponto/app/controllers/presenca/dyn_frequentadores_estacao_controller.rb` | 1 | 0 |
| 16 | `api-ponto/app/controllers/presenca/carrega_relogio_atual_controller.rb` | 1 | 0 |
| | **Total** | **75** | **0** |

## Inspeção do diff (prova de que é só formatação)

Inspeção manual do `git diff` de **todos** os arquivos de produção (`app/`, `config/`, `db/`):

- **`config/routes.rb`** — apenas `only: [:a, :b]` → `only: [ :a, :b ]` (9 rotas). As rotas, verbos,
  paths e constraints (ex.: `constraints: ->(_req) { FrequenciaAutorizacaoCascata.modo != :off }`) estão
  **idênticos**.
- **`app/controllers/admin/{sessions,users,time_records}_controller.rb`** — apenas espaçamento em
  literais de array (`only: [...]`, `[mes, ...].min`, `group_by { |r| [...] }`, `montar_linha_dia`).
  Nenhum símbolo, callback ou argumento alterado.
- **`app/services/intranet/sync_digitais_service.rb`** — apenas aspas simples→duplas em strings
  (`'log'`, `'mysql2'`, `ENV.fetch('INTRANET_*', ...)`, `encode('UTF-8')`, `File.open(..., 'a')`).
  Valores literais inalterados.
- **4 controllers `presenca/`** — apenas acréscimo do **newline final** (EOF). Nenhuma linha de código
  tocada.
- **`db/migrate/20260910000001_rolify_create_roles.rb`** — `add_index :t, [:a, :b]` → `[ :a, :b ]`.
  Nenhum índice/coluna alterado (migração **não** foi re-executada).
- **`config/importmap.rb`** — apenas newline final.
- **Arquivos de teste** — espaçamento de arrays / aspas; nenhuma asserção alterada.

**Conclusão da inspeção:** nenhuma mudança semântica. 100% formatação.

## Evidência da suíte (não-regressão)

Comando (mesma env do RuboCop): `bin/rails test`

| Medida | Baseline | Após a chore |
|---|---|---|
| runs | 1214 | **1214** |
| assertions | 4239 | **4239** |
| failures | 3 | **3** |
| errors | 12 | **12** |
| skips | 0 | **0** |

**Idêntica ao baseline canônico.** As 15 falhas/erros são **pré-existentes** e não relacionadas à
chore (não foram tocadas nesta task): 11× Devise `redirect_to`, 1× timezone
`PresencaEndpointsTest:187`, 2× `SeedsTest` order-dependent, 1× `PessoasSchemaLoaderTest`
order-dependent.

## Riscos

- **Baixo.** Todas as correções são cosméticas (espaço em array, aspas, newline final), aplicadas
  por `-a` (conjunto **seguro**), sem `rubocop:disable` e sem `-A`. A suíte completa confirma
  comportamento inalterado (baseline exato).
- **Escopo de arquivos:** `config/routes.rb` e controllers foram os de maior volume — inspecionados
  linha a linha (acima), sem mudança de semântica de rotas/autorização.
- **Fora de escopo (não tocados):** `config/credentials.yml.enc`, `config/environments/development.rb`,
  `docs/governance/_context.md` (modificado no working tree pelo Summarizer), `log/*`, `tmp/cache/*`
  — permanecem como estavam, fora de qualquer staging.

## Nota de ambiente

Não foram executados `db:migrate`/`db:reset`/`db:drop`/`db:schema:load` (banco de dev remoto
compartilhado). A migração `20260910000001_rolify_create_roles.rb` teve apenas formatação — não é
necessário (nem permitido) re-executá-la.

## Pendências / débitos

| Débito | Dono | Critério de pronto |
|---|---|---|
| Commit + push da branch `chore/limpeza-rubocop-77` | coordenador (COMMIT_MODE=manual) | ✅ **CONCLUÍDO (2026-10-14):** commit `51992e8`; pushada em `origin` e `gitlab` (`ceaac87`). Falta apenas o **merge em `integration/sprint-29`** — pendente/bloqueado por decisão do dev. |
