# Iteration 29 — Cascata de autorização de frequência (quem vê/gerencia a frequência de quem)

> Status: 🔵 Em Andamento — Tarefa 29.1 aprovada (Review + Bug Finder), aguardando commit manual; Tarefa 29.0 implementada, aguardando review; Tarefas 29.2–29.8 pendentes | Período: a definir (após Sprint 28 ou conforme Gantt revisado) | Goal: Substituir o baseline "todo autenticado lê tudo" (Sprint 23.7) no domínio de frequência pela cascata de autorização do legado (`RegistroFrequenciaValidator.frequentador`) e pela regra de elegibilidade de desconsideração, com `GestorIndividual` MIGRADO do Intranet | Rastreabilidade: `Frequencia/PRD-REGRAS-NEGOCIO-PRESENCA.md` §2.3, §2.5, §3, §9 itens 1 e 7

## Decisão de numeração (ler antes)

- Existentes em `docs/progress/`: 23, 24, 26. Reservados pelo `implementation_plan.md`: 24–28 (25, 27, 28 ainda sem arquivo). Primeiro número livre: **29**.
- O PRD de regras de negócio **ainda não está refletido** no `docs/12-plano-implementacao/implementation_plan.md`. Este arquivo detalha a primeira sprint derivável; a formalização do épico/Gantt é do **Project Planner** (sem edição do plano por esta sprint).

## Pré-condições

- Sprints 24–28 (stack/scaffolds basic8) **não bloqueiam** esta sprint tecnicamente (domínios disjuntos), mas a 23.7 (CanCanCan nos controllers) precisa estar mergeada — esta sprint altera a `Ability`.
- **Aprovação explícita do usuário** (regra global: alterar autorização/migrations exige plano claro): as tarefas 29.2 (migration) e 29.7 (Ability/controllers) só iniciam após OK do usuário sobre as decisões D1–D4 abaixo.

## Estado real verificado (2026-09-24)

- `app/models/ability.rb`: autenticado → `can :read, :all`; `gestor` → `manage TimeRecord, IntervencaoFrequencia` sem escopo; comentário registra que o escopo por `GestorIndividualGerenciado` é evolução futura.
- `gestores_individuais` local = cadastro simples (`nome`, `orgao` string) + join `gestor_individual_gerenciados(user_id)`; **sem** vínculo a login/CPF do gestor, sem `ativo`/`data_exclusao`, sem id legado. Comentário do model aponta a fonte real: `SticapiClient::Intranet.gestores_individuais` (id, data_criacao, data_exclusao, observacao, id/matrícula gestor e gerido).
- Hierarquia de órgãos + gestores (atual/substituto/excepcional) **já existem no Pessoas2**: `unidades.ancestry`, `gestor_id`, `gestor_substituto_id`, `gestor_excepcional_id` (FK → `pessoas`), com `Unidade#gestor?(pessoa)` e `Unidade.importar_gestores_intranet` (dado do Intranet já migrado para o Pessoas2). O espelho readonly `Pessoas::Unidade` do Frequencia ainda **não** expõe esses campos.
- `users.cpf` (unique) é a ponte User ↔ `Pessoas::Pessoa`; lotação via `Pessoas::Lotacao.principais.vigentes`.

## Decisões necessárias (bloqueantes para 29.2/29.4/29.7)

| # | Decisão | Proposta padrão do Sprint Planner |
|---|---------|-----------------------------------|
| D1 | Roles legadas `PRESENCA_VISUALIZA_FREQUENTADORES` e `..._TERCEIRIZADOS` | Criar 2 roles Rolify novas (`visualiza_frequentadores`, `visualiza_terceirizados`) — não mexer em `admin/gestor/operador`; o mapeamento completo das 11 roles fica na Sprint 30 |
| D2 | O que acontece com o baseline `can :read, :all` para usuários sem role | Remover **apenas** para recursos de frequência (TimeRecord, CalculoDiario, RegistroMensalFrequencia, IntervencaoFrequencia, telas `frequencia*`/`parcial`/`relatorio_*`); demais telas mantêm leitura |
| D3 | Rollout | Feature flag (`FREQUENCIA_AUTORIZACAO_CASCATA`, default off em prod) + modo "shadow" que só loga negações durante 1 ciclo |
| D4 | Fonte de "TERCEIRIZADO" do frequentador-alvo | `Pessoas::Vinculo` → categoria do vínculo principal vigente (confirmar código no espelho) |

## Desenvolvedores

| Dev | Perfil | Foco |
|-----|--------|------|
| Dev A (Code Specialist) | Backend Rails (models/services/Ability) | 29.1, 29.4, 29.5, 29.6, 29.7, 29.8 |
| Dev B (opcional) | Integração/migração de dados | 29.2, 29.3 (paralelizáveis com 29.1) |

## Backlog

### Tarefa 29.0 — Schema de teste do espelho Pessoas (ADR-0006)
- User Story: Como time, quero que os espelhos `Pessoas::*` sejam testados contra PostgreSQL real no `frequencia_pessoas_espelho_test` para que os critérios de SQL, propriedade e contagem de queries da 29.4/29.6 sejam verificáveis.
- Rastreabilidade: `docs/adr/0006-schema-teste-espelho-pessoas.md`; `review_report_29_cs.md` R1/LOW-2; `bug_report_29_bug-finder.md` (sinalização ao CTO)
- Estimativa: 3 pontos | Atribuição: Dev A | Dependências: nenhuma (código de teste/infra de teste; não é migration)
- Critérios de aceite:
  - [x] `api-ponto/test/support/pessoas_schema.rb` com subconjunto fiel de `pessoas2/db/schema.rb` (pessoas, unidades, vinculos, lotacoes + apoio D4), cabeçalho com fonte e data
  - [x] Rake `test:pessoas_schema:load` idempotente, com guardas testadas (aborta fora de `RAILS_ENV=test` e se o banco não termina em `_test`); `database_tasks: false` mantido
  - [x] Helpers de dados em `test/support/pessoas_espelho_helper.rb` (sem YAML em `fixtures :all`), revertidos pela transação do teste
  - [x] Testes da 29.1 migrados para dados reais ou `stub` com escopo de bloco (fecha LOW-1 e LOW-2 do review); guard de drift contra `../../pessoas2/db/schema.rb` (skip explícito se ausente)
  - [x] Passo documentado no fluxo de testes/CI; comportamento com `parallelize` verificado e, se divergente do ADR, registrado em `lessons.md`
- Banco de teste: `frequencia_pessoas_espelho_test` (renomeado de `pessoas_test`, que colide com o banco de teste do Pessoas2; ver revisão de 2026-09-25 na ADR-0006). Setup por máquina/CI: `createdb -h localhost -U postgres -O app.frequencia frequencia_pessoas_espelho_test` e depois `RAILS_ENV=test bin/rails test:pessoas_schema:load`
- Status: ✅ Implementado (2026-09-25), aguardando Code Reviewer. Pendência: o `.github/workflows/ci.yml` ainda não cria o banco nem roda a task (documentado no README e na ADR)

### Tarefa 29.1 — Expor hierarquia e gestores de órgão no espelho `Pessoas::Unidade`
- User Story: Como sistema de autorização, quero navegar a árvore de órgãos e saber os gestores atual/substituto/excepcional de cada unidade para decidir acesso hierárquico.
- Rastreabilidade: PRD §3 passo 5
- Estimativa: 3 pontos | Atribuição: Dev A | Dependências: nenhuma
- Critérios de aceite:
  - [x] `Pessoas::Unidade` ganha `belongs_to :gestor/:gestor_substituto/:gestor_excepcional` (`Pessoas::Pessoa`), `#gestor?(pessoa)` e `#cadeia_ascendente` (self + ancestrais a partir da coluna `ancestry`, ordem folha→raiz) sem adicionar gem
  - [x] `Pessoas::Pessoa.por_user(user)` (lookup por CPF normalizado) — nil seguro para user sem CPF
  - [x] Espelho continua readonly (`PessoasRecord#readonly?`); zero escrita no banco Pessoas
  - [x] Testes com stub/fixture de árvore de 3 níveis (raiz, intermediária, folha) e ancestry vazio/corrompido
- Status: ✅ Implementado, ✅ Aprovado (Code Reviewer 2026-09-25, reavaliação) — 0 blockers; HIGH-1/HIGH-2/LOW-1 fechados e validados por mutation testing. Relatório: `docs/quality/review_report_29_cs.md`. ✅ Bug Finder 2026-09-25 (0 crítico/alto/médio). Triagem CTO 2026-09-25: MEDIUM-1 e LOW-3 corrigidos (doc); LOW-1/LOW-2 → 29.0; Bugs 1/2 → 29.4; Bug 3 → regra D6 na 29.4; MEDIUM-2 → chore agile de pipeline. **Liberada para commit manual** (COMMIT_MODE=manual; stage seletivo dos 4 arquivos de código/teste + docs, nunca `git add -A`)

### Tarefa 29.2 — Evoluir schema de `GestorIndividual` para receber dado real (MIGRAÇÃO)
- User Story: Como gestor excepcional, quero que meu vínculo de gestão individual cadastrado no Intranet exista no Frequencia para continuar vendo a frequência dos meus geridos quando o Intranet for desativado.
- Rastreabilidade: PRD §2.5; memória do usuário (dado de negócio do Intranet deve ser migrado)
- Estimativa: 3 pontos | Atribuição: Dev B | Dependências: aprovação D1–D4 (migration)
- Critérios de aceite:
  - [ ] Migration **aditiva** (sem drop): `gestores_individuais` + `id_legado` (unique), `gestor_cpf`, `gestor_user_id` (FK opcional), `ativo` (default true), `data_exclusao`, `observacao`, `data_criacao_legado`; `gestor_individual_gerenciados` + `id_legado`, `ativo`, `data_exclusao`
  - [ ] Soft-delete: `destroy` na UI passa a marcar `ativo=false/data_exclusao` (nunca hard-delete) — scope `ativos`
  - [ ] Registros locais existentes preservados (sem `id_legado`), tela `admin/gestores_individuais` continua funcionando
  - [ ] Rollback da migration testado
- Status: ⬜ Pendente

### Tarefa 29.3 — Importação idempotente de gestores individuais do Intranet
- User Story: Como administrador, quero importar (e reimportar sem duplicar) os gestores individuais do Intranet para que o Frequencia seja a fonte de verdade após o desligamento do legado.
- Rastreabilidade: PRD §2.5; memória do usuário
- Estimativa: 5 pontos | Atribuição: Dev B | Dependências: 29.2
- Critérios de aceite:
  - [ ] Rake `frequencia:importar_gestores_individuais` (+ job opcional) consome `SticapiClient::Intranet.gestores_individuais`, resolve matrícula→CPF via `ResolverCpfPorMatriculaService`, upsert por `id_legado`
  - [ ] Preserva `data_exclusao` legada (registro excluído no legado entra como inativo, não é descartado)
  - [ ] Relatório final: importados / atualizados / não resolvidos (matrícula sem CPF ou gerido sem `User`) — nada é silenciosamente ignorado
  - [ ] Dry-run (`DRY_RUN=1`) sem escrita; segunda execução = 0 criações
- Status: ⬜ Pendente

### Tarefa 29.4 — `AutorizacaoFrequencia` — cascata de visualização
- User Story: Como gestor, quero ver apenas a frequência de quem eu gerencio (hierarquia, gestão individual ou permissão geral) para respeitar a regra de acesso do legado.
- Rastreabilidade: PRD §3 passos 1–5; §9 itens 1 e 7
- Estimativa: 5 pontos | Atribuição: Dev A | Dependências: 29.0, 29.1, 29.2 (D1, D4)
- **Regra de negócio D6 — hierarquia com unidade ausente/inativa/extinta (decisão CTO 2026-09-25, origem: Bug 3 do Bug Finder):**
  - A **cadeia estrutural** é percorrida inteira (folha→raiz) pelo `ancestry` persistido; uma unidade da cadeia **não interrompe** a subida por estar ausente, inativa ou extinta — o path é a fonte da estrutura, e interromper negaria acesso legítimo aos gestores superiores.
  - **Unidade inelegível não libera acesso pelos seus gestores:** é inelegível a unidade com `active = false` **ou** `data_extincao_serventia` preenchida e `<= Date.current`. Vale também para a própria unidade de lotação do alvo. Gestor de órgão extinto/inativo não tem autoridade corrente.
  - **Ancestral ausente** (id no path sem registro): é pulado, a subida continua, e é emitido `Rails.logger.warn` estruturado (`evento: autorizacao_frequencia.ancestral_ausente`, `unidade_id`, `ancestral_id`) — nunca falha a request.
  - **Path corrompido** (formato inválido, auto-referência inclusive com zero à esquerda, ids repetidos) continua **fail-closed**: cadeia = `[self]` (fecha Bugs 1 e 2 do Bug Finder aqui).
  - Motivo de auditoria: negações em que a única unidade com gestor correspondente era inelegível retornam `:negado` com detalhe `:unidade_inelegivel` no log (alimenta o shadow da 29.7/29.8).
  - **Gatilho de reabertura:** `unidades.active` tem default `false` no Pessoas2. Antes de ligar a flag, a amostra R2 do review deve medir `% de unidades com lotação principal vigente e active=false`; se relevante (> 5%), o CTO reavalia usar só `data_extincao_serventia`.
- Critérios de aceite:
  - [ ] D6 implementada: testes de ancestral ausente (sobe + loga), ancestral inativo (não libera, sobe), ancestral extinto (idem), unidade de lotação inativa, e gestor de unidade ativa acima de inativa liberando
  - [ ] Bugs 1 e 2 do Bug Finder corrigidos em `Pessoas::Unidade#cadeia_ascendente`: comparação de auto-referência após `to_i` e path com ids repetidos → `[self]`, ambos sem consulta
  - [ ] `includes(:gestor, :gestor_substituto, :gestor_excepcional)` ao percorrer a cadeia; log quando `user.cpf` presente e `por_user` → nil (carried do review)
  - [ ] Testes de precedência/negação usam o schema real (ADR-0006), não stubs
  - [ ] PORO `AutorizacaoFrequencia.new(usuario).pode_ver?(frequentador)` avalia em ordem, retornando no primeiro match: (1) próprio (user.id/CPF), (2) role `visualiza_frequentadores` ou admin, (3) role `visualiza_terceirizados` **e** alvo TERCEIRIZADO, (4) `GestorIndividual` **ativo** vinculado, (5) gestor atual/substituto/excepcional de qualquer unidade na cadeia ascendente da lotação principal vigente do alvo
  - [ ] Retorna também o **motivo** (`:proprio`, `:role_geral`, `:terceirizado`, `:gestor_individual`, `:hierarquia`, `:negado`) para auditoria
  - [ ] Alvo sem lotação vigente → só passos 1–4; Pessoas indisponível → nega (fail-closed) e loga
  - [ ] Testes cobrindo cada passo isolado, precedência e negação até a raiz; `GestorIndividual` inativo não libera
- Status: ⬜ Pendente

### Tarefa 29.5 — Regra de elegibilidade para desconsiderar um dia
- User Story: Como gestor, quero só conseguir desconsiderar um dia elegível de um subordinado, nunca o meu próprio, para evitar autobenefício.
- Rastreabilidade: PRD §3 (regra irmã, `podeDesconsiderarFrequencia`)
- Estimativa: 3 pontos | Atribuição: Dev A | Dependências: 29.4
- Critérios de aceite:
  - [ ] `pode_desconsiderar?(frequentador, data)`: dia com registros; não falta/meta-zero/descontado em folha; nenhum registro do dia já desconsiderado; acionador é gestor do órgão do alvo (passo 5 ou gestor individual — confirmar D5); **bloqueia o próprio ponto mesmo sendo gestor**
  - [ ] Integrado ao fluxo da Sprint 19 (desconsiderar/deferir) sem alterar o efeito já implementado
  - [ ] Testes para cada condição de bloqueio + autodesconsideração
- Status: ⬜ Pendente

### Tarefa 29.6 — Scope de listagem `frequentadores_visiveis(usuario)`
- User Story: Como gestor, quero que listagens e relatórios mostrem apenas frequentadores que posso ver, sem vazar registros por paginação/filtro.
- Rastreabilidade: PRD §3; §9 item 1
- Estimativa: 3 pontos | Atribuição: Dev A | Dependências: 29.0, 29.4
- Critérios de aceite:
  - [ ] Regra D6 (unidade inelegível não libera; ausente não interrompe) replicada no SQL; `.distinct` no resultado
  - [ ] Scope SQL (não filtro em Ruby) combinando: próprio ∪ geridos por GestorIndividual ativo ∪ lotados em unidades cuja cadeia contém unidade gerida pelo usuário ∪ (terceirizados se role) ∪ todos (role geral/admin)
  - [ ] Resultado idêntico a `pode_ver?` item a item em teste de propriedade sobre fixture
  - [ ] Sem N+1 (teste de contagem de queries)
- Status: ⬜ Pendente

### Tarefa 29.7 — Integração na `Ability` e controllers de frequência (atrás de flag)
- User Story: Como responsável pela segurança, quero a regra aplicada nas telas e endpoints de frequência sem quebrar quem já acessa legitimamente.
- Rastreabilidade: PRD §3; §9 item 1; Sprint 23.7
- Estimativa: 5 pontos | Atribuição: Dev A | Dependências: 29.4–29.6, D2, D3, aprovação explícita
- Critérios de aceite:
  - [ ] Com flag ligada: `can :read` de TimeRecord/CalculoDiario/RegistroMensalFrequencia/IntervencaoFrequencia por bloco usando `pode_ver?`; `accessible_by`/index usam `frequentadores_visiveis`; `gestor` só gerencia `IntervencaoFrequencia`/`TimeRecord` de visíveis
  - [ ] Controllers afetados mapeados e cobertos: `frequencia`, `frequencia_por_orgao`, `frequentadores`, `parcial`, `time_records`, `relatorio_terceirizados`
  - [ ] Flag desligada: comportamento idêntico ao atual (suíte existente sem regressão)
  - [ ] Modo shadow: loga `usuario, alvo, motivo, decisão` sem negar
  - [ ] Endpoints `Presenca::*` (estação) intocados
- Status: ⬜ Pendente

### Tarefa 29.8 — Matriz de aceite e auditoria
- User Story: Como PO, quero uma matriz de cenários reais validada para decidir ligar a flag em produção.
- Rastreabilidade: PRD §3
- Estimativa: 2 pontos | Atribuição: Dev A | Dependências: 29.7
- Critérios de aceite:
  - [ ] Teste de integração com a matriz: próprio / role geral / terceirizado com e sem role / gestor individual ativo e inativo / gestor atual-substituto-excepcional em nível pai e avô / usuário sem vínculo → 403
  - [ ] Relatório do modo shadow (contagem de negações por motivo) documentado nesta iteration
  - [ ] Suíte completa sem novas falhas vs. baseline vigente
- Status: ⬜ Pendente

## Resumo

| Tarefa | Pontos | Dev | Depende de |
|---|---|---|---|
| 29.0 | 3 | A | — |
| 29.1 | 3 | A | — |
| 29.2 | 3 | B | D1–D4 |
| 29.3 | 5 | B | 29.2 |
| 29.4 | 5 | A | 29.0, 29.1, 29.2 |
| 29.5 | 3 | A | 29.4 |
| 29.6 | 3 | A | 29.0, 29.4 |
| 29.7 | 5 | A | 29.4–29.6 |
| 29.8 | 2 | A | 29.7 |
| **Total** | **32** | | |

Caminho crítico: D1–D4 → 29.2 → 29.4 → 29.6 → 29.7 → 29.8. Paralelo: 29.0 ∥ 29.1 ∥ 29.2→29.3 (29.0 deve fechar antes da 29.4).

## Riscos

- Restringir leitura pode cortar acesso legítimo hoje existente → mitigado por flag + shadow (D3).
- Dependência do banco Pessoas em tempo de request (hierarquia) → fail-closed + cache curto de cadeia por unidade se necessário.
- Matrículas do Intranet sem CPF resolvível → relatório de não resolvidos (29.3), tratamento manual.
- Semântica exata do "gestor excepcional" do Pessoas2 vs. o do Intranet não verificada 1:1 → validar com amostra na 29.8.

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
| 2026-09-24 | Sprint Planner detalhou a sprint a partir do PRD de regras de negócio | 8 tarefas, 29 pts, 4 decisões pendentes |
| 2026-09-25 | Code Specialist implementou a Tarefa 29.1 e adicionou testes isolados para gestores, ancestry e lookup por CPF | Testes direcionados: 10 runs/41 assertions, 0 failures; RuboCop dos arquivos alterados sem offenses; Zeitwerk e Brakeman OK; suíte completa com 1 falha baseline de timezone fora do escopo; sem commit/push |
| 2026-09-25 | Code Specialist aplicou os achados HIGH-1 (auto-referência), HIGH-2 (chaves das associations) e LOW-1 (igualdade de pessoas) solicitados pelo Code Reviewer | Testes direcionados: 13 runs/53 assertions, 0 failures; suíte completa: 793 runs/2886 assertions, 1 falha timezone pré-existente em `presenca_endpoints_test.rb:187`, não atribuída à Tarefa 29.1; RuboCop dos 4 arquivos alterados sem offenses; suíte completa RuboCop: 60 offenses preexistentes; Zeitwerk/Brakeman/bundle check OK; sem commit/push |
| 2026-09-25 | Code Specialist revalidou as correções da 29.1 na branch `feature/demanda-29-correcoes-review`, sem alterar código fora do escopo | `bin/rails test test/models/pessoas_unidade_test.rb test/models/pessoas_pessoa_test.rb`: 13 runs/53 assertions, 0 failures; `bin/rails test`: 793 runs/2886 assertions, 1 falha baseline de timezone em `presenca_endpoints_test.rb:187`; RuboCop direcionado sem offenses; RuboCop completo manteve 60 offenses preexistentes; Zeitwerk, Brakeman e `bundle check` OK; sem commit/push |
| 2026-09-25 | Code Reviewer reavaliou a 29.1 e confirmou o fechamento de HIGH-1/HIGH-2/LOW-1 por **mutation testing** (guard removido → teste falha; FK errada → teste falha; `equal?` → teste falha) | **✅ APROVADO, 0 blockers, 0 achados de alta gravidade**; 13/53/0 direcionados e 793/2886/1 suíte completa (mesma falha baseline), RuboCop 4 arquivos 0 offenses e 60 preexistentes no total, Zeitwerk OK, Brakeman real 4 warnings pré-existentes e **0 na 29.1**; abertos não bloqueantes: MEDIUM-1 (`_context.md` perdeu a pré-condição 23.7), MEDIUM-2 (gate Brakeman inerte por `--ensure-latest` no binstub), LOW-1 (caso negativo de `gestor?` confundido por classe anônima), LOW-2 (monkey-patch de singleton), LOW-3 (3 erros textuais no `_context.md`); relatório em `docs/quality/review_report_29_cs.md` |
| 2026-09-25 | CTO decidiu as pendências pós-review/Bug Finder da 29.1 | ADR-0006 (schema de teste do espelho Pessoas) + nova Tarefa 29.0 (3 pts); regra D6 registrada na 29.4 (Bug 3); Bugs 1/2 → 29.4 (BUG_LEVEL=1); LOW-1/LOW-2 → 29.0; MEDIUM-2 → chore agile de pipeline; MEDIUM-1/LOW-3 corrigidos pelo CTO no `_context.md`. **Correção de registro:** "Brakeman OK" nas linhas acima de 2026-09-25 não representa scan executado (binstub `--ensure-latest`); scan real: 4 warnings pré-existentes, 0 na 29.1. 29.1 liberada para commit manual com stage seletivo (R6) |
| 2026-09-25 | Code Specialist implementou a Tarefa 29.0 (ADR-0006) no banco `frequencia_pessoas_espelho_test`: schema de teste com 8 tabelas copiadas literalmente do Pessoas2, task `test:pessoas_schema:load` com guardas, helpers transacionais, testes da 29.1 migrados para o banco real (LOW-1/LOW-2 fechados), teste de divergência e verificação do `parallelize` | Task carregada 2x sem erro (idempotente); guarda em development aborta com exit 1; testes 29.0+29.1: 25 runs/134 assertions, 0 failures (só 29.1: 15/59/0); divergência: falha com mutação e é pulada sem o checkout do Pessoas2; suíte completa: 805 runs/2967 assertions, 1 falha baseline de timezone em `presenca_endpoints_test.rb:187`; RuboCop dos arquivos novos 0 offenses; sem commit/push |

## 🐞 Relatório de Bugs — Bug Finder

> **`docs/quality/bug_report_29_bug-finder.md`** — 2026-09-25 — Tarefa 29.1
> **Resultado:** 3 achados (🔴 0 / 🟠 0 / 🟡 0 / 🟢 2 / ⚪ 1). Bug 1: um ID com zero à esquerda contorna a checagem de auto-referência em `cadeia_ascendente`. Bug 2: IDs repetidos no caminho não são tratados como corrupção. Bug 3 (Info): um ancestral ausente ou inativo é pulado em silêncio, o que é uma decisão de política para a 29.4.
> **Suíte:** 793/2886/1 (baseline de timezone pré-existente) · direcionados 13/53/0.
> **Sinalização ao CTO:** o banco `pessoas_test` não tem schema, então os espelhos só são testáveis com stubs. Isso bloqueia a verificação dos critérios da 29.6.

## 📋 Relatório de Revisão — Code Reviewer

> **`docs/quality/review_report_29_cs.md`** — 2026-09-25 — reavaliação da Tarefa 29.1 na branch `feature/demanda-29-correcoes-review`
> **Veredito:** ✅ Aprovado (0 blockers, 0 achados de alta gravidade)
> **Fechados por mutation testing:** HIGH-1 (guard de auto-referência), HIGH-2 (chaves das associations), LOW-1 (igualdade de pessoas)
> **Abertos, não bloqueantes:** MEDIUM-1, MEDIUM-2, LOW-1, LOW-2, LOW-3 + débitos carried-forward para 29.4/29.6 (N+1, log de negação, `.distinct`)
> **Limitação de validação relevante:** o gate `bin/brakeman` é no-op (binstub força `--ensure-latest` com gem defasada) — o "Brakeman OK" registrado nas linhas 154–156 **não** representa um scan executado; o scan real (`RUBYOPT= bundle exec brakeman`) retorna 4 warnings pré-existentes, 0 nos arquivos da 29.1
> **Tabela de distribuição:** 29.1 = ✅ Implementado, ✅ Aprovado · 29.2–29.8 = ⬜ Pendente
