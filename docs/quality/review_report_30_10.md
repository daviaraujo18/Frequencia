# Review Report — Tarefa 30.10 (cobertura do `User` local dos gestores de unidade)

> **[⌂ Home](../README.md)** · Código: `Frequencia/api-ponto`

## Metadados

| Campo | Valor |
|-------|-------|
| **Tarefa** | 30.10 — Garantir o `User` local dos gestores de unidade a partir do Pessoas |
| **Sprint** | 30 (frente 5 — diretiva do dev, 2026-10-07) |
| **Revisor** | Code Reviewer |
| **Data** | 2026-10-07 |
| **Branch de origem** | `feature/demanda-30-10-user-local-gestores-unidade` (base `71e91f1`, **nada commitado**) |
| **Destino** | `integration/sprint-29` (a definir no push) |
| **Modo** | `TASK_MODE=STANDARD` · `SUGGESTION_LEVEL=1` · `COMMIT_MODE=manual` |
| **Veredito** | ✅ **Aprovado** — 0 Blockers 🔴 · 2 Sugestões 🟡 · 2 Débitos 🟠 · 4 Elogios 🟢 |

### Arquivos revisados (working tree)

| Arquivo | Estado |
|---------|--------|
| `api-ponto/app/services/garantir_user_local_service.rb` | NOVO — colaborador compartilhado |
| `api-ponto/app/services/importar_gestores_de_unidade_service.rb` | NOVO — serviço da 30.10 |
| `api-ponto/lib/tasks/frequencia_importar_gestores_unidade.rake` | NOVO — borda operacional |
| `api-ponto/test/services/importar_gestores_de_unidade_service_test.rb` | NOVO — 14 testes |
| `api-ponto/app/jobs/importar_servidores_unidade_job.rb` | ALTERADO — delegação (−26/+6) |

### Evidência reproduzida pelo revisor

| Medição | Resultado |
|---------|-----------|
| `bin/rails test test/services/importar_gestores_de_unidade_service_test.rb` | **14 runs / 56 assertions / 0F / 0E / 0 skip** |
| `bin/rails test ...service_test.rb ...importar_servidores_unidade_job_test.rb` | **24 runs / 75 assertions / 0F / 0E / 0 skip** |
| `bin/rubocop` (5 arquivos) | **0 offenses** |

Confere com o reportado pelo Code Specialist.

---

## Checklist focado (8 pontos da tarefa)

| # | Item | Resultado |
|---|------|-----------|
| 1 | **Comportamento externo do `ImportarServidoresUnidadeJob` preservado** | ✅ Paridade campo a campo (`nome_completo`, `username` só se `present?`, `SecureRandom.hex(16)`, status default). O job continua chamando `AtualizarFrequentadorCacheService.call` **SEMPRE** (`importar_servidor`, linha 70) — a delegação não toca o cache. Mudança de retorno do método (`nil/save!` → `true/false`) é **inócua**: o valor não é consumido pelo job. Teste do job 10/10 verde. |
| 2 | **Read-only no Pessoas** | ✅ O único acesso ao espelho é `unidades_do_pessoas` (`includes`, SELECT). Nenhuma escrita no mirror; `PessoasRecord#readonly?` = true. |
| 3 | **Sem autorização nova** | ✅ Nenhuma alteração em cascata/`Ability`/flag. Criação de conta é neutra; o passo 5 continua lendo gestor do Pessoas em tempo de request. |
| 4 | **PII no relatório** | ✅ `resumo` agrupa não-resolvidos por **motivo** (contagem); `NaoResolvido` só carrega `motivo`. Logs: `motivo` e `e.class` — sem CPF/login/nome. |
| 5 | **Idempotência** | ✅ `find_or_initialize_by(cpf:)` + retorno antecipado (`return false unless new_record?`) ⇒ 2ª execução = 0 criações e 0 escritas (cache só na criação). Divergência intencional do cache **documentada** no cabeçalho da classe e do colaborador; **não** afeta o job por lotação (que segue sempre chamando o cache). |
| 6 | **Correção (dedup/FK órfã/CPF branco/colisão)** | ✅ União dos 3 ids → dedup por id (primeira ocorrência) → dedup por CPF (branco preservado). FK órfã (`gestor_id` sem `gestor`) → não-resolvido. Colisão de `username` → `RecordInvalid` capturado por `processar` → contabilizado sem abortar. **`normalizar_cpf` com `.presence` (sem `gsub`): confirmei que não cria duplicata** — o job já usa o mesmo `pessoa.cpf` cru contra a validação `/\A\d{11}\z/` de `User`, logo a fonte é dígito-puro; a normalização é **consistente com o caminho existente**. |
| 7 | **Testes não-degenerados** | ✅ 14 testes / 56 asserts; stubs via `com_metodo_de_classe_stubado` (captura/restaura o `UnboundMethod`), **sem `remove_method`**. O teste 13 falha pela razão certa (stub que **levanta** → `falha_leitura`, distinto do teste 14 de leitura vazia). |
| 8 | **Escopo** | ⚠️ Ver 🟡S1: o `ImportarServidoresUnidadeJob` foi tocado, apesar de o texto da tarefa dizer "não o altera". Desvio **comportamento-preservante** e DRY-justificado — **aceito**. |

---

## Blockers 🔴

**Nenhum.** Não foi encontrado bug de lógica, segurança, PII ou quebra de comportamento externo.

---

## Sugestões 🟡

| ID | Descrição | Tarefa/Arquivo |
|----|-----------|----------------|
| **S1** | **Desvio de escopo textual — decisão: ACEITAR a extração (opção a).** O texto de escopo da 30.10 diz "**Não** altera o `ImportarServidoresUnidadeJob`", mas o job foi refatorado para delegar a `GarantirUserLocalService.call` (`importar_servidores_unidade_job.rb:80-82`). A verificação confirma **paridade de comportamento** (mesmos campos, mesmo fluxo, cache sempre chamado) e os testes do job seguem verdes (24/75/0F/0E). Recomendo: **manter a extração** (evita duplicar a regra de criação) e **corrigir o texto da tarefa** / registrar a exceção sancionada, para que a rastreabilidade não fique contraditória. | `importar_servidores_unidade_job.rb:80-82`; `iteration_30.md` §30.10 "o que NÃO ENTRA" |
| **S2** | **Colisão de `username` deixa o gestor SEM conta local.** Quando `pessoa.username` já pertence a outro `User`, o `save!` falha e o gestor entra em `erros` — ou seja, um gestor real continua **sem** `User` local, reabrindo parcialmente o furo que a 30.10 fecha. É **conforme o spec** ("colisão vai ao relatório, nunca resolve em silêncio") e a rake sai com exit ≠ 0, mas recomendo uma decisão consciente: **fallback para `generate_username`** (que já sufixa `.2`, `.3`, … no callback `before_validation, on: :create`) ou documentar explicitamente por que não fazer o fallback. Não bloqueia (é o comportamento herdado do job). | `importar_gestores_de_unidade_service.rb:204-210`; `garantir_user_local_service.rb:36`; `user.rb` (`generate_username`) |

---

## Débitos Técnicos 🟠

| ID | Descrição | Tarefa/Arquivo |
|----|-----------|----------------|
| **D1** | **Política de PII em log inconsistente no domínio de importação.** O novo serviço loga apenas `e.class` (sem mensagem — bem), enquanto o `ImportarServidoresUnidadeJob` já loga `Falha ao importar CPF #{cpf}` (PII) em `importar_servidor`. É **pré-existente** e **fora do escopo da 30.10** (não foi introduzido aqui), mas fica registrado por serem o mesmo domínio de dados. | `importar_servidores_unidade_job.rb:72` (pré-existente) |
| **D2** | **`FrequentadorCache` write-once para gestores.** Como o cache só é atualizado na criação, um gestor cuja `Pessoas::Pessoa` mude (órgão/vínculo) **não** terá o cache atualizado por este serviço nas re-execuções. Para os 24 sem lotação vigente isso é benigno (não têm vínculo ativo → `orgao`/`vinculo` nulos) e o job por lotação cobre quem tem lotação. Documentado e intencional (mantém o "0 escritas" honesto) — registrado para ciência. | `importar_gestores_de_unidade_service.rb:215-223` |

---

## Elogios 🟢

| ID | Elogio | Tarefa/Arquivo |
|----|--------|----------------|
| **G1** | **Extração DRY limpa e comportamento-preservante.** A regra de criação do `User` foi movida para um colaborador único, com paridade campo a campo e testes do job intactos — exatamente o que a tarefa visava (evitar duplicação entre os dois caminhos). | `garantir_user_local_service.rb`; `importar_servidores_unidade_job.rb` |
| **G2** | **Disciplina de PII no relatório.** `resumo` e `NaoResolvido` só carregam motivo/contagem; o teste 7 (`refute_includes` de nome e login) trava essa propriedade. | `importar_gestores_de_unidade_service.rb:47-76`; teste 7 |
| **G3** | **Testes não-degenerados com stub save/restore.** Uso correto de `test/support/class_method_stub_helper.rb` sobre um `def self.` OWN, sem `remove_method`; o teste 13 prova que "falha de leitura ≠ leitura vazia" (falha pela razão certa — lição 33). | `importar_gestores_de_unidade_service_test.rb:46-55,208-225` |
| **G4** | **Guardas operacionais portados da 30.9b.** `DRY_RUN` sem escrita, `falha_leitura` explícito (aborta inclusive em dry-run) e exit ≠ 0 em erros na execução real — coerente com o padrão S2 já aprovado. | `frequencia_importar_gestores_unidade.rake:27-36` |

---

## Notas / Nits

- **N1:** `normalizar_cpf` usa `.to_s.presence` sem `strip`/`gsub`. Seguro **desde que** `pessoa.cpf` seja dígito-puro (confirmado). Se um dia a fonte ganhar formatação/whitespace, a criação passaria a falhar na validação de `User` (contada como `erros`, não silenciosa) em vez de casar — um comentário de uma linha blindaria a intenção.
- **N2:** Housekeeping de entrega: o working tree tem arquivos **não relacionados** modificados (`config/credentials.yml.enc`, `log/*.log`, `tmp/cache/bootsnap/load-path-cache`). No commit atômico, garantir stage **apenas** dos 5 arquivos da tarefa — o `credentials.yml.enc` modificado **não** deve entrar.

---

## Ações Corretivas (para desbloquear a entrega)

- [ ] **(Opcional, não-bloqueante)** S1 — corrigir o texto de escopo da 30.10 no `iteration_30.md` (registrar a extração aceita) **ou** autorizar formalmente o desvio. *Já sinalizado pelo Code Specialist na seção "⚠️ Desvio de escopo".*
- [ ] **(Opcional, não-bloqueante)** S2 — decidir sobre fallback de `username` colidente (ou documentar a decisão de mantê-lo como erro).
- [ ] **Entrega:** como **não há blockers**, seguir para o **Source Code Delivery Protocol** (agrupamento de commits atômicos), com stage seletivo (ver N2).

---

## Certificação

✅ **Entrega técnica aprovada** (0 Blockers 🔴). Sugestões 🟡 e débitos 🟠 **não-bloqueantes** (`SUGGESTION_LEVEL=1`). Próximo passo: Code Specialist realiza o agrupamento de commits atômicos e a execução do protocolo de entrega (`COMMIT_MODE=manual` — aguarda o dev). O fechamento desta rastreabilidade é pré-requisito para o início da próxima tarefa.
