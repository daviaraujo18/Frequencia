# Relatório de Revisão — Tarefa 30.9a (Seed idempotente das 2 roles da cascata)

## Metadados

| Campo | Valor |
|-------|-------|
| Data da revisão | 2026-10-06 |
| Revisor | Code Reviewer (AI Workflow) |
| Worktree | `wt-30.9` |
| Branch origem | `feature/demanda-30-9a-seed-roles-cascata` @ `98c43ce` |
| Branch destino | `integration/sprint-29` |
| Tarefa revisada | 30.9a — Seed idempotente das 2 roles da cascata |
| Ruling aplicável | **30.3 = A** (manter simplificado + semear as 2 roles; só frequência; adiar perfis) |
| Commits | **Nenhum** (`COMMIT_MODE=manual`) |
| Arquivos alterados | `api-ponto/db/seeds.rb` (+19/-4), `api-ponto/test/lib/seeds_test.rb` (+23) |

**Veredito: ✅ Aprovado — 0 Blockers 🔴 | 0 Sugestões 🟡🟠.**

---

## Escopo revisado

Diff toca **somente** `db/seeds.rb` e `test/lib/seeds_test.rb`. Confirmado via
`git diff HEAD --stat` (excluindo `log/` e `tmp/`): 2 arquivos, 38 inserções,
4 remoções. `app/`, `config/`, `lib/`, `db/schema.rb` = **intactos**.

---

## Resultado por item

### 1. Escopo do ruling A — ✅ Conforme
`db/seeds.rb:70-72` semeia **exatamente 5 roles**:
`admin gestor operador visualiza_frequentadores visualiza_terceirizados`
(as 3 genéricas preservadas + as **2 roles da cascata**). **Não** expandiu para
as 11 rejeitadas pelo ruling A (as 30.4/30.5 continuam N/A). **Nenhuma
atribuição** de role a usuário foi introduzida — o bloco `add_role`
(`db/seeds.rb:119`) segue restrito a `admin`/`gestor`/`operador`; as 2 roles da
cascata são apenas **criadas**, deixando a atribuição real (30.9b) fora do diff,
conforme o re-escopo.

### 2. Idempotência real — ✅ Conforme (reproduzido)
- Padrão `Role.find_or_create_by!(name: name)` mantido (idempotência herdada).
- Teste novo `seed de roles e idempotente: segunda execucao nao cria nenhuma role`
  usa `assert_no_difference("Role.count") { load_seeds }` + `assert_equal 5, Role.count`.
- Teste novo `semeia as 5 roles efetivas mantendo as 3 genericas pre-existentes intactas`
  captura o mapa `{nome => id}` das 3 genéricas **antes** do seed e reafirma
  **mesmo id** depois — provando que são **reaproveitadas, não recriadas**.
- **Reproduzido em árvore:** `bin/rails test test/lib/seeds_test.rb` →
  **10 runs, 37 assertions, 0 failures, 0 errors, 0 skips**.

### 3. Sem regressão sob `:off` — ✅ Conforme
Semear as roles é **inerte** fora de `:on`: as roles só são **lidas** por código
gated na flag. Verificado no código:
- `FrequenciaAuthorization#restringir_frequencia` → `return relation unless frequencia_cascata_ligada?`
  (early-return em `:off`/`:shadow`); `observar_cascata_frequencia` → `return unless ...shadow?`.
- `FrequenciaAutorizacaoCascata.ligada?` == `modo == :on` (default `:off`).
- `Ability`: `deny_frequencia_baseline!` / `grant_leitura_frequencia` só sob `ligada?`;
  `return unless FrequenciaAutorizacaoCascata.ligada?` (linhas 92, 105, 196, 212).
- `FrequentadoresVisiveis#role_geral?`/`role_terceirizados?` só são alcançados a
  partir do concern/fluxos gated.
Criar linhas `Role` não altera comportamento algum enquanto não forem lidas.

### 4. Sem alteração de schema — ✅ Conforme
`git diff HEAD --name-only -- api-ponto/db/schema.rb` = vazio. Nenhuma migration
adicionada. As tabelas `roles`/`roles_users` já são providas pelo Rolify.

### 5. Regressão (suíte completa) — ✅ Confirmado
`bin/rails test` → **1098 runs, 3876 assertions, 1 failure, 12 errors, 0 skips**
(exatamente o medido pelo agente). As 13 ocorrências são **pré-existentes e não
relacionadas a seeds/roles**:
- 10 errors `Users::SessionsControllerTest`/`PasswordsControllerTest`
  (`NoMethodError: private method 'redirect_to'` — Devise x controller).
- 2 errors `PessoasSchemaLoaderTest` (`GuardError: refuses database ... name must end with _test` — ambiente).
- 1 failure `PresencaEndpointsTest` (formatação `dd/mm/YYYY HH:MM:SS` — fuso/formato).
Nenhuma toca `db/seeds.rb` ou o domínio de roles.

### 6. Nomes das roles — ✅ Conforme (exatos, string a string) — ATENÇÃO ESPECIAL
Comparação literal contra os pontos de leitura **reais**:
- `visualiza_frequentadores` — `has_role?(:visualiza_frequentadores)` em
  `app/models/autorizacao_frequencia.rb:131` e `app/models/frequentadores_visiveis.rb:100`
  (e `app/controllers/concerns/frequencia_authorization.rb:63`).
- `visualiza_terceirizados` — `has_role?(:visualiza_terceirizados)` em
  `app/models/autorizacao_frequencia.rb:139` e `app/models/frequentadores_visiveis.rb:109`.

Casamento **1:1**, sem typo. Ambos os símbolos batem também com os testes de
cascata existentes (`autorizacao_frequencia_test.rb`, `frequentadores_visiveis_test.rb`,
`frequencia_matriz_aceite_test.rb`). O seed **não** é decorativo por nome.

---

## Blockers 🔴
Nenhum.

## Sugestões 🟡 / Débito 🟠
Nenhuma.

## Elogios 🟢

| ID | Elogio | Tarefa |
|----|--------|--------|
| E1 | Teste de idempotência assertivo no grão certo (`assert_no_difference` + `assert_equal 5`) e teste separado que **prova preservação de id** das 3 genéricas — não apenas contagem. | 30.9a |
| E2 | Comentário no seed documenta o "porquê" (passos 2/3, gate `:on`) e a inércia em `:off`/`:shadow`, amarrando o código ao ruling A. | 30.9a |

## Ações corretivas
Nenhuma — aprovado técnico. Sem blockers.

## Recomendação de commit (`COMMIT_MODE=manual`)
Stage **seletivo** (excluir `log/test.log` e `tmp/cache/*`):

```
git add api-ponto/db/seeds.rb api-ponto/test/lib/seeds_test.rb
git commit -m "feat: semeia as 2 roles da cascata (visualiza_frequentadores/visualiza_terceirizados) — 30.9a"
```

Sugestão de prefixo: `feat` (novo dado semeado) ou `chore`, conforme a
convenção do projeto. Não commitar `log/` nem `tmp/`.
