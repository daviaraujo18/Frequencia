# Iteration 29 — Cascata de autorização de frequência (quem vê/gerencia a frequência de quem)

> Status: 📋 Planejada (aguardando formalização do Project Planner) | Período: a definir (após Sprint 28 ou conforme Gantt revisado) | Goal: Substituir o baseline "todo autenticado lê tudo" (Sprint 23.7) no domínio de frequência pela cascata de autorização do legado (`RegistroFrequenciaValidator.frequentador`) e pela regra de elegibilidade de desconsideração, com `GestorIndividual` MIGRADO do Intranet | Rastreabilidade: `Frequencia/PRD-REGRAS-NEGOCIO-PRESENCA.md` §2.3, §2.5, §3, §9 itens 1 e 7

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

### Tarefa 29.1 — Expor hierarquia e gestores de órgão no espelho `Pessoas::Unidade`
- User Story: Como sistema de autorização, quero navegar a árvore de órgãos e saber os gestores atual/substituto/excepcional de cada unidade para decidir acesso hierárquico.
- Rastreabilidade: PRD §3 passo 5
- Estimativa: 3 pontos | Atribuição: Dev A | Dependências: nenhuma
- Critérios de aceite:
  - [ ] `Pessoas::Unidade` ganha `belongs_to :gestor/:gestor_substituto/:gestor_excepcional` (`Pessoas::Pessoa`), `#gestor?(pessoa)` e `#cadeia_ascendente` (self + ancestrais a partir da coluna `ancestry`, ordem folha→raiz) sem adicionar gem
  - [ ] `Pessoas::Pessoa.por_user(user)` (lookup por CPF normalizado) — nil seguro para user sem CPF
  - [ ] Espelho continua readonly (`PessoasRecord#readonly?`); zero escrita no banco Pessoas
  - [ ] Testes com stub/fixture de árvore de 3 níveis (raiz, intermediária, folha) e ancestry vazio/corrompido
- Status: ⬜ Pendente

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
- Estimativa: 5 pontos | Atribuição: Dev A | Dependências: 29.1, 29.2 (D1, D4)
- Critérios de aceite:
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
- Estimativa: 3 pontos | Atribuição: Dev A | Dependências: 29.4
- Critérios de aceite:
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
| 29.1 | 3 | A | — |
| 29.2 | 3 | B | D1–D4 |
| 29.3 | 5 | B | 29.2 |
| 29.4 | 5 | A | 29.1, 29.2 |
| 29.5 | 3 | A | 29.4 |
| 29.6 | 3 | A | 29.4 |
| 29.7 | 5 | A | 29.4–29.6 |
| 29.8 | 2 | A | 29.7 |
| **Total** | **29** | | |

Caminho crítico: D1–D4 → 29.2 → 29.4 → 29.6 → 29.7 → 29.8. Paralelo: 29.1 ∥ 29.2→29.3.

## Riscos

- Restringir leitura pode cortar acesso legítimo hoje existente → mitigado por flag + shadow (D3).
- Dependência do banco Pessoas em tempo de request (hierarquia) → fail-closed + cache curto de cadeia por unidade se necessário.
- Matrículas do Intranet sem CPF resolvível → relatório de não resolvidos (29.3), tratamento manual.
- Semântica exata do "gestor excepcional" do Pessoas2 vs. o do Intranet não verificada 1:1 → validar com amostra na 29.8.

**Linha do Tempo:**

| Horário | O que foi feito | Resultado |
|---------|-----------------|-----------|
| 2026-09-24 | Sprint Planner detalhou a sprint a partir do PRD de regras de negócio | 8 tarefas, 29 pts, 4 decisões pendentes |
