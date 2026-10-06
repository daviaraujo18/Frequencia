# Relatório de Revisão — Tarefa 30.9b (Migração 1:1 das 2 roles da cascata)

## Metadados

| Campo | Valor |
|-------|-------|
| Data da revisão | 2026-10-06 |
| Revisor | Code Reviewer (AI Workflow) |
| Worktree | `wt-30.9b` |
| Branch origem | `feature/demanda-30-9b-migracao-roles-legado` |
| Branch destino | `integration/sprint-29` @ `38359cd` |
| Tarefa revisada | 30.9b — Migração 1:1 das 2 roles da cascata a partir do Intranet legado |
| Ruling aplicável | **D-6 = (i)** (migração 1:1 pela conexão direta `intranet_development`) |
| Commits | **Nenhum** (`COMMIT_MODE=manual`) — 3 arquivos untracked |
| Arquivos revisados | `api-ponto/app/services/intranet/migrar_roles_cascata_service.rb` (277), `api-ponto/lib/tasks/frequencia_migrar_roles_cascata.rake` (32), `api-ponto/test/services/intranet/migrar_roles_cascata_service_test.rb` (204) |

**Veredito: ✅ Aprovado — 0 Blockers 🔴 | 0 High 🟠 | 3 Sugestões 🟡 (Melhoria) + 2 Nits 🟢.**

---

## Evidência executada (números reais medidos nesta revisão)

Ambiente conforme o gotcha (`PATH=/usr/bin:$PATH` + `BUNDLE_PATH` do bundle do Frequencia; binstub `bin/rails`):

| Execução | Comando | Resultado |
|----------|---------|-----------|
| Arquivo novo | `bin/rails test test/services/intranet/migrar_roles_cascata_service_test.rb` | **10 runs, 37 assertions, 0F, 0E, 0 skips** |
| Direcionada (intranet/ + cascata) | `test/services/intranet/ test/models/frequencia_autorizacao_cascata_test.rb test/models/ability_cascata_test.rb test/controllers/admin/frequencia_cascata_controller_test.rb` | **49 runs, 231 assertions, 0F, 0E** |
| Suíte completa | `bin/rails test` | **1108 runs, 3913 assertions, 1F, 12E, 0 skips** |
| RuboCop | `bin/rubocop` (3 arquivos) | **no offenses detected** |
| Zeitwerk | `bin/rails zeitwerk:check` | **All is good!** |

A suíte completa confere com a baseline (1098/3876, mesmos 1F+12E pré-existentes) **+ o delta do arquivo novo (10/37)**: 1108/3913, sem nenhuma falha nova. Os 13 eventos são os pré-existentes já catalogados (11 Devise `redirect_to`, 1 fuso `PresencaEndpointsTest`, 1 `PessoasSchemaLoaderTest` order-dependent). **Zero regressão atribuível a esta tarefa.**

---

## Resultado por critério de aceite

### 1. Read-only na conexão `intranet_development` — ✅ Conforme
`ler_atribuicoes_legado` (service:146-158) executa **um único** `client.query` com `SELECT` (INNER JOINs). `grep -nE "INSERT|UPDATE|DELETE|execute|\.save|create|destroy"` sobre o serviço e a rake task: **nenhuma ocorrência** (exit 1). A escrita local (`user.add_role`) atinge somente o banco primário da api-ponto. O contrato "a api-ponto NUNCA escreve no legado" é honrado.

### 2. Cadeia correta — ✅ Conforme
`INNER JOIN admin_profile p ON p.profileId = u.profile_profileId` (coluna `profile_profileId`, não `profileId`) e `admin_profile_role pr ON pr.profileId = p.profileId`, `admin_role r ON r.roleId = pr.roleId`. João por STRING, como o fato de referência. `admin_user` é usada por `u.login` (PK), sem `id`. Correto.

### 3. Só as 2 roles — ✅ Conforme
`MAPEAMENTO` (service:62-65) fecha exatamente as 2 roles; a query filtra por elas (service:154). Qualquer outro `roleId` seria tratado como não resolvido (service:221-225). Testes #4 e #5 provam que nomes legados fora do escopo não viram role local.

### 4. Idempotência (sequencial) — ✅ Conforme
Casamento por chave estável (login→User) + `has_role?` antes de `add_role` (service:232-236). Teste #2: 2ª execução = 0 atribuições, 1 sem-alteração, sem duplicar role. Reproduzido.

### 5. DRY_RUN sem escrita + relatório sem PII — ✅ Conforme
`atribuir` retorna cedo sob `@dry_run` (service:258-263); teste #1 confirma `refute user.has_role?` e `roles.count == 0`. Contabilidade fechada: `atribuidos + sem_alteracao + nao_resolvidos + erros == processados` (invariante `total_contabilizado`). Nada silenciosamente ignorado. PII: o `log` nunca imprime login/CPF (só `motivo`, `role` e `user_id`); o `resumo` agrupa por motivo (contagem); teste #8 prova que o `resumo` não contém o login.

### 6. Sem regressão sob `:off`; sem schema/migration/auth/Ability/rotas — ✅ Conforme
`git status` mostra apenas os 3 arquivos novos (+ `log/`, `tmp/cache/`). Nenhuma migration, `db/schema.rb` intacto. Suíte completa com 0 falhas novas. O guard `return relation unless frequencia_cascata_ligada?` (`frequencia_authorization.rb:47`) permanece intacto — verifiquei por mutação (abaixo).

---

## Blockers 🔴
Nenhum.

## Sugestões 🟡

| ID | Achado | Severidade | Evidência |
|----|--------|-----------|-----------|
| S1 | **Teste #5 não discrimina a inércia sob `:off`/`:shadow`** (ponto 5 do ceticismo). O usuário do teste **recebe a role `visualiza_frequentadores`** antes do assert; `frequencia_visao_global?` (`frequencia_authorization.rb:59-64`) curto-circuita `return relation if ... has_role?(:visualiza_frequentadores)`. Logo, mesmo removendo o guard `return relation unless frequencia_cascata_ligada?`, o teste continua verde. **Mutação verificada por mim:** troquei a linha 47 por `return relation if false` e rodei só o teste de inércia → **1 run, 3 assertions, 0F/0E** (mutação sobreviveu); revertida em seguida (`git diff` do concern = vazio). O comentário "Discriminador: o stub do Pessoas LEVANTA se for chamado" não se sustenta para este usuário. Correção sugerida: usar um usuário **sem** a role (ou sem roles), onde a quebra do guard alcança `frequentadores_visiveis_user_ids` → stub levanta. Impacto: falso senso de segurança sobre a propriedade de segurança da tarefa. A propriedade global segue coberta pela suíte completa, por isso não é blocker. | 🟡 Melhoria | `test/.../migrar_roles_cascata_service_test.rb:182-203`; `frequencia_authorization.rb:47,59-64` |
| S2 | **Falha de leitura do legado vira "0 lidas / 0 erros" e exit 0.** `ler_atribuicoes_legado` captura `Mysql2::Error/ECONNREFUSED/EHOSTUNREACH` e retorna `[]` (service:159-162); `carregar_mysql2!` idem (service:164-170). Numa execução REAL, DB fora do ar ⇒ `processados: 0`, `erros: 0` ⇒ a rake **não aborta** (exit 0), indistinguível de "nada a migrar". Contraria o espírito de "nada silenciosamente ignorado" para a falha de lote. Sugestão: distinguir erro fatal de leitura (abort/exit≠0) de resultado vazio. Padrão herdado do `SyncDigitaisService` (mesmo comportamento) — não é defeito novo. | 🟡 Melhoria | `service:140-162`, `frequencia_migrar_roles_cascata.rake:28-30` |
| S3 | **Concorrência não protegida por índice único.** `users_roles` **não** tem índice `unique` em `(user_id, role_id)` (`db/schema.rb:334`); o `add_role` do Rolify é check-then-insert não-atômico (`rolify-6.0.1/lib/rolify/role.rb:17-19`). Duas execuções simultâneas poderiam inserir linhas duplicadas de atribuição. A idempotência **sequencial** é sólida; a concorrente não. Para um rake one-off manual, probabilidade baixa — recomenda-se executar uma única vez (ou documentar a restrição). | 🟡 Melhoria | `db/schema.rb:330-336`; `rolify role.rb:17-19` |

## Nits 🟢 / observações

| ID | Observação |
|----|-----------|
| N1 | `.first` em `User.where("lower(username) = ?", ...)` (service:253) — o índice único de `username` é **case-sensitive** (`db/schema.rb:327`) enquanto a validação de app é case-insensitive; um registro inserido cru diferindo só por caixa faria `.first` escolher arbitrariamente (sem `ORDER BY`). Baixa probabilidade. `lower()` também impede uso do índice (seq scan) — irrelevante nesta escala. |
| N2 | `atribuidos` no `dry_run` conta a atribuição **projetada**. O `resumo` sinaliza "DRY-RUN (nenhuma escrita)", então não induz a erro no relatório; o nome do campo isolado pode ser mal lido. Já documentado no cabeçalho da classe (service:48-52). |

## Elogios 🟢

| ID | Elogio |
|----|--------|
| E1 | Contabilidade **fechada** por construção: cada linha cai em exatamente um destino e `total_contabilizado == processados` é testado (#3). Nada silenciosamente ignorado. |
| E2 | Isolamento por injeção (`atribuicoes:`) mantém os testes **sem rede/banco legado**; a porta é segura (só acrescenta 1 das 2 roles fixas a usuários resolvidos) e não representa risco em produção. |
| E3 | SQL estritamente read-only; conexão/produção e tratamento de erro reaproveitam fielmente o padrão do `SyncDigitaisService`. |
| E4 | PII corretamente contida: `log`/`resumo` nunca imprimem login/CPF; o `login` é mantido apenas em memória no struct para uso programático. |
| E5 | `abort` (exit 1) em execução real com pendências e exit 0 em `DRY_RUN` — semântica de exit code correta para encadeamento. Nit: `ENV["DRY_RUN"] == "1"` é igualdade estrita (`DRY_RUN=true` não ativa o dry-run). |

## Ações corretivas
Nenhuma bloqueante. Recomendada apenas a S1 (fortalecer a discriminância do teste #5) como melhoria; S2/S3 são débitos/observações.

## Recomendação de commit (`COMMIT_MODE=manual`)
Stage **seletivo** (excluir `log/test.log` e `tmp/cache/*`):

```
git add api-ponto/app/services/intranet/migrar_roles_cascata_service.rb \
        api-ponto/lib/tasks/frequencia_migrar_roles_cascata.rake \
        api-ponto/test/services/intranet/migrar_roles_cascata_service_test.rb
git commit -m "feat: migra 1:1 as 2 roles da cascata do Intranet legado (read-only) — 30.9b"
```

Não commitar `log/` nem `tmp/`. Prefixo `feat` (nova capacidade) ou `chore`, conforme a convenção.

---

**Veredito final: ✅ Aprovado (0 Blockers).** Aprovação recomendada, com a ressalva opcional S1 no teste de inércia.
