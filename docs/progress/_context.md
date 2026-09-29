# _context.md — progress
> Gerado em: 2026-09-29 | Fontes: iteration_23.md, iteration_24.md, iteration_26.md, iteration_29.md, adr/0006-schema-teste-espelho-pessoas.md | Palavras: ~620
> Atualizar quando: nova iteration criada; status de tarefa alterado; correções de review registradas; sprint concluída.

## O que esta pasta contém
Acompanha as sprints do Frequência, com um `iteration_N.md` por sprint. A Sprint 23 foi encerrada, a Sprint 24 foi concluída, a Sprint 26 está consolidada e aguarda revisão, e a Sprint 29 é a sprint ativa de autorização/cascata de frequência. Na Sprint 29: a 29.1 está aprovada (Review + Bug Finder) e aguarda commit manual; a 29.0 está implementada e aguarda Code Reviewer (pendência de CI); a **29.2** foi implementada, passou por **3 rodadas de Bug Finder** (19 achados) e acaba de ser **triada pelo CTO (2026-09-29)** — aguarda re-review do Code Reviewer no diff final.

## Pontos-chave para agentes
### iteration_23.md
- Sprint Devise + CanCanCan + Rolify concluída; o ciclo de bug-hunting do `POST /u/password` foi encerrado.
- A correção de timing side-channel foi mantida pelo CTO, com paridade 5=5 queries e sem mutação de dados.

### iteration_24.md
- Sprint basic8 concluída: `zutils`, `simple_form`, `ransack` e `pagy` integrados sem alteração de banco ou autenticação; `kaminari` preservado.

### iteration_26.md
- Tarefas 26.1–26.10 consolidadas no commit `1a73a4d`; validação consolidada pendente de Code Reviewer/Bug Finder.

### iteration_29.md
- **29.1** expõe no espelho Pessoas os três gestores, `#gestor?`, `#cadeia_ascendente` e `Pessoas::Pessoa.por_user`, preservando `PessoasRecord#readonly?`. ✅ aprovada; liberada para commit manual com stage seletivo (nunca `git add -A`).
- **29.0** (ADR-0006): schema mínimo do Pessoas2 no `frequencia_pessoas_espelho_test` (renomeado de `pessoas_test`) via `RAILS_ENV=test bin/rails test:pessoas_schema:load`; setup: `createdb -O app.frequencia frequencia_pessoas_espelho_test`. ✅ implementada, aguardando Code Reviewer; **pendência: o `ci.yml` não cria o banco nem roda a task**.
- **29.2** migrou `GestorIndividual` para o dado real do Intranet: 2 migrations (aditiva + índice UNIQUE **parcial** em `(gestor_individual_id, user_id) WHERE ativo`), concern `Desativavel` (soft-delete), `dependent: :restrict_with_exception`, invariante de auto-gerência guardado pelos **dois lados**. Corrigidos os 🟠 e 🟡 das 3 rodadas do Bug Finder. Débitos com destino: ⚪ 9 → chore `Desativavel`; ⚪ 11/14 e 🟢 19 → 29.3; ⚪ 16 → 29.4; 🟢 7 → ADR-0007; 🟢 8 (locale `record_invalid`) → fix small, **blocker da 29.3**.
- **Decisões do CTO (2026-09-29):** invariante canônico *"nenhum vínculo ATIVO liga o gestor a si mesmo"*; validação de invariante **event-scoped**; **29.2-D7** (extrair as validações de invariante para concern compartilhado — pré-condição da 29.3); **D8** (`valid?` proibido no caminho de leitura — o `index` levantava `RecordInvalid`); índice parcial testado nos **4 quadrantes × 2 lados**.
- Regra **D6** (29.4): cadeia sobe inteira; unidade inativa/extinta não libera; ancestral ausente é pulado com log; path corrompido é fail-closed.
- **29.3–29.8** pendentes; D1–D4 continuam bloqueantes para autorização (não para o schema da 29.2, já aprovado).

## Estado atual
- Sprint 29 ativa. **29.2: próximo passo = re-review do Code Reviewer** no diff final pós-3ª-rodada (as correções dos Bugs 17/18 vieram **depois** do review da 1ª rodada); a triagem do CTO **não** é gate. Só depois: 29.2-D7 (concern) e liberação para commit.
- **29.3 não inicia** sem 29.2-D7, sem o fix `record_invalid`/`full_messages` (Bug 8) e sem confirmar o modo de escrita (ActiveRecord, não `upsert_all`).
- Merge da 23.7 (CanCanCan nos controllers) segue pendente: pré-condição da 29.7. 29.1 ainda sem commit.
- Suíte completa nesta linha: **887 runs / 3121 assertions** com **12 problemas PRÉ-EXISTENTES** (11× `NoMethodError: private method 'redirect_to'` nos controllers Devise `users/sessions`/`users/passwords` da Sprint 23 + 1× timezone em `presenca_endpoints_test.rb`). A suíte é **FLAKY** sob paralelização (12 workers) — conferir isolado antes de atribuir falha nova.
- **`db/schema.rb` versionado defasado** em relação ao banco (25 tabelas); `db:migrate` regenera fiel, mas **nunca** rode `db:schema:load`/`db:reset` no dev sem revisar. FK duplicada de `calculo_diarios` (merge `94bdbd6`) foi removida — sem isso a suíte ficava inexecutável.
- **Brakeman:** `bin/brakeman` NÃO escaneia (binstub `--ensure-latest` com gem defasada); scan real (`RUBYOPT= bundle exec brakeman`) = 4 warnings pré-existentes. Chore de pipeline.
- Branch `feature/demanda-29-schema-gestor-individual` (a partir de `integracao/wilker`, não de `develop`); nada commitado (COMMIT_MODE=manual).

## Referências para aprofundamento
- Para a Tarefa 29.2, critérios, 3 rodadas, triagem e decisões do CTO → `docs/progress/iteration_29.md` (seção `🧭 Plano do CTO — Tarefa 29.2`)
- Para a estratégia de schema de teste do espelho → `docs/adr/0006-schema-teste-espelho-pessoas.md`
- Para as lições operacionais (inclui índice parcial × validação, event-scope de invariante) → `docs/governance/lessons.md`
- Para as regras e configurações → `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`
