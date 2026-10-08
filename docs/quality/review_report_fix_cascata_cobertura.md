# Relatório de Revisão — fix de cobertura da cascata (Bugs 🔴 1 e 🟡 3)

> **Data:** 2026-10-08 | **Revisor:** Code Reviewer (AI Workflow)
> **Branch de origem:** `fix/cascata-cobertura-users-time-records` (base `integration/sprint-29` @ `8bd6755`)
> **Destino:** merge na linha de integração da Sprint 30/29 (a decidir pelo Orchestrator)
> **Modo:** TASK_MODE=STANDARD · COMMIT_MODE=manual · SUGGESTION_LEVEL=1 · BUG_LEVEL=1
> **Skills aplicadas:** `code-review-checklist` + `structural-conformity-checklist`
> **Referência:** `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md` (Bug Finder, 2026-10-07)
> **Plano do specialist:** `docs/progress/iteration_31_fix_cascata_cobertura.md`

## Veredito

✅ **Aprovado** — 0 Blockers 🔴.

- Blockers: **0** | Sugestões: **4** (Melhoria: 4 / Débito: 0) | Elogios: 5
- O furo 🔴 fecha sob `:on` com **paridade fiel** a `/frequentadores`; o 🟡 (ano global) fecha em
  todos os modos. Nenhuma regressão medida (suíte de cascata 55/273/0F/0E; direcionada 50/224/0F/0E;
  novos 8/27/0F/0E). Testes **não-degenerados** (mutations A/D mortas).

## Metadados

| Item | Valor |
|---|---|
| Arquivos alterados (working tree) | `api-ponto/app/controllers/admin/users_controller.rb`, `api-ponto/app/controllers/admin/time_records_controller.rb` |
| Testes novos | `api-ponto/test/controllers/admin/users_cascata_controller_test.rb`, `api-ponto/test/controllers/admin/time_records_anos_cascata_test.rb` |
| Docs novos | `docs/progress/iteration_31_fix_cascata_cobertura.md`, `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md` |
| Tarefas revisadas | Fix do Bug 🔴 1 (`users#index`) e Bug 🟡 3 (`time_records#index`) + NÃO-implementação do Bug 🟠 2 (`/presenca/*`, PARE+reporte) |
| Evidência reproduzida | novos **8 runs / 27 asserts / 0F / 0E**; direcionada (users+frequentadores+time_records) **50 / 224 / 0F / 0E**; cascata (6 arquivos) **55 / 273 / 0F / 0E**; mutations A e D **mortas** |

## Verificação por foco de revisão

1. **Correção real do 🔴 sob `:on`?** ✅ Sim. `users#index` passa a incluir `FrequenciaAuthorization`,
   chama `observar_cascata_frequentadores`/`registrar_negacoes_frequentadores` e usa
   `incluir_cpfs: incluir_cpfs_com_cascata`. Sob `:on`, não-admin sem visão global recebe a
   interseção com `frequentadores_visiveis_cpfs`; teste `fail-closed` (nenhum visível → nada) passa.
2. **Sem regressão sob `:off`/`:shadow`?** ✅ `incluir_cpfs_com_cascata` devolve `exigidos` (sem
   restrição) quando a flag não está ligada; `observar_*` só loga. Teste de paridade sob flag off
   confirma o terceiro visível — **idêntico** a `/frequentadores`.
3. **Admin/visão global vê tudo?** ✅ Controle positivo em ambos os arquivos de teste
   (`admin: true`) passa — terceiro e contas locais continuam visíveis ao admin.
4. **`incluir_cpfs_com_cascata` duplicado — paridade fiel?** ✅ Método texto-idêntico ao de
   `frequentadores_controller` (`nil`=sem filtro; `:off`/shadow não restringe; visão global não
   restringe; `:on` = `exigidos & visiveis`). Duplicação é débito aceitável (ver S1).
5. **`@users_sem_cpf` admin-only quebra a tela?** ✅ Não. `contas_locais_sem_cpf` devolve
   `User.none` para não-admin; a view só usa `.any?`/`.each`/atributos (nunca `.total_count` nessa
   coleção) → seção some sem erro. Verificado no teste e na leitura da view.
6. **Bug 3: `except(:includes, :order)` correto?** ✅ O cálculo foi movido para **depois** de
   `restringir_frequencia` e do `where(user_id: current_user.id)`, e **antes** do filtro ano/mês. O
   `except` evita JOIN/ORDERBY na agregação; admin sem filtro segue enxergando o ano global
   (controle positivo passa).
7. **Testes não-degenerados (lição 33)?** ✅ Usam `com_metodo_de_classe_stubado` (nunca
   `remove_method`); stub de `frequentadores_ativos` honra o contrato `incluir_cpfs` (`nil`/`[]`/lista).
   Mutations reproduzidas nesta revisão: **A** (voltar ao bug original em `users#index`) → 2 falhas;
   **D** (`TimeRecord.minimum` global) → 1 falha. Ambas **mortas**.
8. **Escopo:** ✅ Nenhum arquivo de `presenca/`, Devise, `config/routes.rb`, `Ability`, concern ou
   `FrequenciaAutorizacaoCascata` foi tocado. Bug 2 corretamente **PARE+reportado**. ⚠️ Há **ruído
   pré-existente** no working tree que não pertence a este fix (ver S2).

## Blockers (🔴)

Nenhum.

## Sugestões (🟡) — Melhoria

| ID | Descrição | Tarefa afetada |
|----|-----------|----------------|
| S1 | **DRY:** `incluir_cpfs_com_cascata` existe (privado) em `frequentadores_controller` e foi espelhado em `users_controller`. Paridade 100% fiel hoje, mas duas cópias divergem com o tempo. Home natural = concern `FrequenciaAuthorization` (já compartilhado por 6 controllers). **Não é blocker** (o specialist sinalizou ao CTO; extrair em tarefa própria reduz risco de tocar a cascata em produção). | `users#index`, `frequentadores#index` |
| S2 | **Higiene de entrega/escopo:** há mudanças **não relacionadas** no working tree que **NÃO devem** entrar no commit deste fix: `api-ponto/config/credentials.yml.enc` (mtime 2026-09-28), `api-ponto/config/environments/development.rb` (2026-10-07 12:32 — altera o default de dev para `FREQUENCIA_AUTORIZACAO_CASCATA=shadow`), `api-ponto/log/development.log`, `api-ponto/log/test.log`, `api-ponto/tmp/cache/bootsnap/load-path-cache`, `docs/progress/iteration_30.md`. **Stage seletivo obrigatório** (só os 2 controllers + 2 testes + docs do fix). | entrega/commit |
| S3 | **Rastreabilidade/numeração:** `docs/progress/iteration_31_fix_cascata_cobertura.md` colide com `docs/progress/iteration_31.md` (sprint **planejada**, escopo distinto — Fila assíncrona §5.2). Pela `agile-task-protocol`, um fix usa `iteration_[tipo]_[slug].md` → renomear para `iteration_fix_cascata_cobertura.md` para não confundir a numeração da Sprint 31. | rastreabilidade |
| S4 | **Cobertura de teste:** o teste do Bug 3 roda com a flag no default (`:off`); sob `:off` o não-admin já só via os próprios registros, então o fix é exercitado, mas um caso explícito `:on` reforçaria a matriz da cascata. Verificar também a decisão de produto: `@users_sem_cpf` admin-only passa a valer **mesmo em `:off`/`:shadow`** (independente da flag) — a justificativa (contas privilegiadas; gestor/operador já não editam) é sólida, mas convém confirmar com o PO/CTO. | Bug 3; gate de contas locais |

## Elogios (🟢)

| ID | Elogio | Tarefa |
|----|--------|--------|
| E1 | Simetria de auditoria preservada: `observar_cascata_frequentadores` (shadow) + `registrar_negacoes_frequentadores` (`:on`) exatamente como em `/frequentadores` — sem log mudo no `:on`. | Bug 1 |
| E2 | `User.none` como contrato de "sem acesso" para não-admin: mínimo privilégio sem quebrar a view. | Bug 1 |
| E3 | Bug 3 no ponto **e na ordem** corretos (após restrições, antes do filtro ano/mês) + comentário explicando o `except(:includes, :order)`. | Bug 3 |
| E4 | Testes não-degenerados com o helper correto (`com_metodo_de_classe_stubado`), honrando o contrato `incluir_cpfs` e com controles positivos de admin. | ambos |
| E5 | Bug 2 (`/presenca/*`) tratado como **PARE + reporte** com investigação de protocolo (ADR-0003) em vez de um gate ingênuo que quebraria o kiosk. | Bug 2 |

## Ações Corretivas

- [ ] (S1) Registrar o débito de DRY ao CTO; extrair `incluir_cpfs_com_cascata` para o concern em
      tarefa própria (não neste fix).
- [ ] (S2) No commit: **stage seletivo** — apenas `users_controller.rb`, `time_records_controller.rb`
      e os 2 arquivos de teste (+ docs do fix). **Não** incluir `credentials.yml.enc`, `development.rb`,
      `log/*`, `tmp/*`, `iteration_30.md`.
- [ ] (S3) Renomear `iteration_31_fix_cascata_cobertura.md` → `iteration_fix_cascata_cobertura.md`
      (evitar colisão com a Sprint 31 planejada).
- [ ] (S4) Confirmar com PO/CTO a decisão do gate admin-only de contas locais (independente da flag).
- [ ] Pendência herdada (fora deste fix): Bug 🟠 2 (`/presenca/*` sem autenticação) e o achado
      sistêmico de **enforcement opt-in** da cascata seguem para o CTO.

## Nota de governança (ao CTO)

O fix fecha os dois furos por **paridade com `/frequentadores`**, mas confirma o achado sistêmico do
Bug Finder: a cascata é *opt-in* por controller e `authorize! :read, :all` satisfaz o
`check_authorization`. O 🔴 só fecha de fato quando `FREQUENCIA_AUTORIZACAO_CASCATA=:on` estiver
ligada em produção; em `:off`/`:shadow` `/users` permanece na paridade atual (roster visível a
autenticado). Recomenda-se documentar o padrão de **enforcement central** (ou um teste de conteúdo
obrigatório por tela de listagem, como sugerido pelo Bug Finder §Achados de padrão sistêmico).
