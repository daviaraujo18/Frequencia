# _context.md — progress
> Gerado em: 2026-09-30 | Fontes: iteration_29.md, iteration_chore_gitlab-ci.md, iteration_23/24/26.md, adr/0006, adr/0007, quality/review_report_29_2_final.md, quality/review_report_29_pipeline.md, quality/review_report_chore_gitlab_ci.md | Palavras: ~700
> Atualizar quando: nova iteration criada; status de tarefa alterado; correções de review registradas; commit/push; sprint concluída.

## O que esta pasta contém
Acompanha as sprints do Frequência, com um `iteration_N.md` por sprint. Sprints 23/24 encerradas; 26 consolidada; **29 é a sprint ativa** (cascata de autorização de frequência), com 29.0/29.1/29.2/29.2-D7/Bug 8 implementados, aprovados e **commitados**. O bloco de esteira e a chore do fork do CI saíram como arquivo próprio (`iteration_chore_gitlab-ci.md`).

## Pontos-chave para agentes
### iteration_29.md
- **29.0** (ADR-0006): schema de teste do espelho no `frequencia_pessoas_espelho_test` via `RAILS_ENV=test bin/rails test:pessoas_schema:load`. ✅ implementada e **aprovada** (review 29.0 aprovado, 0 blockers); débito do CI (passo do espelho) fechado.
- **29.1**: expõe no espelho os 3 gestores, `#gestor?`, `#cadeia_ascendente`, `Pessoas::Pessoa.por_user`. ✅ aprovada; **já commitada** (merge `8e2b6f7`/PR #17 — não "aguarda commit").
- **29.2** (migração `GestorIndividual`): índice UNIQUE **parcial** em `(gestor_individual_id, user_id) WHERE ativo`, concern `Desativavel`, `dependent: :restrict_with_exception`, invariante de auto-gerência pelos 2 lados (event-scoped). **3 rodadas de Bug Finder (19 achados)** + **29.2-D7** (concern `InvarianteAutoGerencia`) + **Bug 8** (i18n). ✅ **re-review final APROVADO** (`review_report_29_2_final.md`) e **FECHADO/COMMITADO** em `1e935cd` (código) + `1cf5d97` (docs).
- **Decisões do CTO (2026-09-29):** invariante canônico *"nenhum vínculo ATIVO liga o gestor a si mesmo"*; validação **event-scoped**; **D8** (`valid?` proibido no caminho de leitura — o `index` levantava `RecordInvalid`); índice parcial testado nos **4 quadrantes × 2 lados**; **D1** decidida (roles `visualiza_frequentadores`/`visualiza_terceirizados`); **D4** corrigida (TERCEIRIZADO = `Pessoas::Vinculo#tipo_vinculo.nome == "Terceirizado"`, não categoria eSocial); **Ruling M2** (Brakeman: ledger `config/brakeman.ignore` + flags anti-drift, acoplado ao fork do CI).
- **29.3–29.8 pendentes.** D2/D3 (baseline `can :read`/rollout) com aprovação explícita pendente — gate da 29.7.

### iteration_chore_gitlab-ci.md
- Chore `chore/gitlab-ci-fork` (AGILE): cria `.gitlab-ci.yml` para o runner **GitLab** (remote real `gitlab.tjpi.jus.br`; o `ci.yml` de GitHub tem `ruby-version: .ruby-version` → `ruby-4.0.0` inexistente e **não roda em produção**). Corrige **RR-S1** (exits 8/9 do Brakeman) e **RR-S2** (`PESSOAS_DB_DATABASE` deixa de ser decorativo).
- `.gitlab-ci.yml`: stages security/quality/test; service `postgres:17`; job `test` cria o banco espelho. 3 blockers (B1 alias `postgres`, B2 `DATABASE_URL`, B3 `PGPASSWORD`) achados e **fechados** no re-review. `allow_failure: true` em security/quality, `test` DURO (fail-fast impedia o `test` de rodar).
- **✅ Re-review APROVADO (0 blockers). Commitada e pushada** para branch de teste no GitLab: `3ae995d` (fix RR-S1/S2), `ccba59f` (CI), `6382de6` (docs).
- ⚠️ **CORREÇÃO DE ESTADO (2026-09-30): o pipeline ainda NÃO foi criado no GitLab.** O repo é **MONOREPO** (raiz git = `Frequencia/`, app Rails em `api-ponto/`) e o `.gitlab-ci.yml` tinha sido criado em **`api-ponto/`** — o GitLab **só lê o arquivo na RAIZ** (sem descoberta em subpasta), então o pipeline não existia e o `test` não rodou (não falhou: não existia). **Ação:** arquivo **movido para a raiz** (`Frequencia/.gitlab-ci.yml`) + `cd api-ponto` no `before_script` global para os comandos resolverem. Estado real: **"arquivo correto, agora na raiz, mas ainda não lido pelo GitLab"** — pendente 1 run real no runner do TJPI.
- **Pendente:** 1 run real no runner do TJPI (validação ambiental; sem `glab`/token aqui, não foi lido).

### iteration_23.md / 24.md / 26.md
- 23: Devise + CanCanCan + Rolify; bug-hunting de `POST /u/password` encerrado (timing side-channel via phantom work, mantido pelo CTO).
- 24: basic8 (`zutils`/`simple_form`/`ransack`/`pagy`), sem alterar banco/auth. 26: 26.1–26.10 no commit `1a73a4d`.

## Estado atual
- **Sprint 29 — a 29.2 está FECHADA na linha local.** Branch `feature/demanda-29-schema-gestor-individual` com 5 commits locais (`1e935cd`, `1cf5d97`, `3619fb1`, `dd1aa1b`, `73726e1`) — **sem push**.
- **Fase 2 — decidida e NÃO iniciada:** serializar 29.3 → 29.4 (bancos de teste únicos + suíte flaky sob 12 workers + mesmo domínio `GestorIndividual`). Desbloqueios fechados: D7, Bug 8, D1/D4.
- **Suíte (baseline):** 896 runs / 1 failure + 12 errors — 11× `NoMethodError: private method 'redirect_to'` nos controllers Devise da Sprint 23 + 1× timezone em `presenca_endpoints_test.rb`. **FLAKY** sob paralelização — conferir isolado antes de atribuir regressão. Espelho Pessoas: 19/68/0/0/0.
- **Débitos catalogados com destino:** Bug 9 → `chore/desativavel-guarda-colisao`; ⚪11/14, 🟢19, `ativo: nil` → 29.3; ⚪16, 🟡A2, Bug 15 (auto-gerência tardia) → 29.4/29.5; B2 → chore de infra de teste; ⚪7 → ADR-0007; ⚪9/B4/B3 aceitos. 23.7 merge pendente (gate da 29.7). Bump Rails ≥8.1.x segue sem execução.
- **Dívidas de CI com dono + prazo + gatilho binário:** EOLRails/Rails ≥8.1.x (`chore/bump-rails-8.1`, até **2026-10-07**, gatilho `brakeman`=EXIT=0); 77 offenses RuboCop (`chore/limpeza-rubocop-77`, até **2026-10-13**, gatilho `rubocop`=EXIT=0). **Dívida de versão do Ruby** (3 fontes conflitantes; medido **3.3.8 / 8.0.5**) sem dono — ver `governance/_context.md`.

## Referências para aprofundamento
- Para a 29.2, 3 rodadas, D1/D4/M2 e Ruling do CTO → `docs/progress/iteration_29.md`
- Para o fork do CI, RR-S1/RR-S2 e a dívida de versão → `docs/progress/iteration_chore_gitlab-ci.md`
- Para o re-review final da 29.2 → `docs/quality/review_report_29_2_final.md`
- Para as ADRs 0006/0007 → `docs/adr/0006-schema-teste-espelho-pessoas.md` · `docs/adr/0007-soft-delete-gestor-individual-e-politica-delecao-usuario.md`
- Para regras e lições → `docs/governance/_context.md` e `docs/governance/lessons.md`
