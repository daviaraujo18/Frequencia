# _context.md — progress
> Gerado em: 2026-10-13 | Fontes: iteration_29.md (L978+ Quadro PRD §9), iteration_29_closure.md, iteration_30.md (encerramento 30.8 + emenda ruling A), iteration_chore_*.md, iteration_31.md (Encerramento + ADR-0011), adr/0006–0011, git log (HEAD `dae631f`) | Palavras: ~780
> Atualizar quando: nova iteration criada; status de tarefa alterado; sprint concluída; push/MR; baseline da suíte remedido.

## O que esta pasta contém
Acompanha as sprints do Frequência, com um `iteration_N.md` por sprint. Sprints 23/24 encerradas; 26 consolidada; **29, 30 e 31 estão COMPLETAS** (implementadas, aprovadas, commitadas). As chores transversais têm arquivo próprio (`iteration_chore_*.md`).

## Pontos-chave para agentes
### iteration_29.md — Sprint 29 (cascata de autorização) ✅ CONCLUÍDA
- **Entrega:** substitui o baseline "todo autenticado lê tudo" pela cascata do legado — PORO `AutorizacaoFrequencia`/29.4 + scope SQL `FrequentadoresVisiveis`/29.6 (equivalente item a item, sem N+1) + `ElegibilidadeDesconsideracao`/29.5 (gate **só do passo 5**, D5) + `Ability` + 6 controllers/29.7 + matriz (12 cenários)/29.8. Consolidação durável: **ADR-0010**.
- **Flag `FREQUENCIA_AUTORIZACAO_CASCATA`** (`:off`/`:shadow`/`:on`, default **OFF**): `:on` restringe e loga negações; `:shadow` só loga. Implementada/provada, **não vigente**. Ligar `:on` é **decisão do PO/dev** (shelved — Q16 da 30).
- **Rulings do CTO (referência):** D1 (roles), D4 (TERCEIRIZADO = tipo de vínculo), D5 (ver ≠ desconsiderar), D6 (fail-closed), D8 (leitura nunca `valid?`). Débitos 🟡S2 (twin SQL cego ao PORO) e 🟡S3 (`frequencia_por_orgao`).

### iteration_30.md — Sprint 30 (gate D5, roles, débitos, shadow) ✅ ENCERRADA (CTO, 2026-10-08)
- **Entrega:** gate D5 exposto atrás da flag; **2 roles da cascata** semeadas (30.9a `98c43ce`) + migração do legado (30.9b `e79d89d`); débitos S2/S3 (30.6/30.7, só teste); **User local dos gestores de unidade** (30.10). **30.4/30.5 = N/A** sob ruling **30.3 = A emendado** (política incremental: cada role nasce na tarefa que implementa a seção do PRD que a consome).
- **30.8 re-escopada** de "7 dias em PRODUÇÃO" → **observação em DEV** (realizada: 1366 eventos; insumo com 4 limitações). Bug 🟠2 = **Risco Aceito** (revisita após testes manuais). **Débito ESTRUTURAL** (enforcement opt-in da cascata = causa-raiz do Bug 🔴1) → **ADR-0010 regra 9**.
- **Emenda ADR-0010 (2026-10-08):** regra 9 — "ONDE restringir" (opt-in por controller; `authorize! :read, :all` **não** basta). Fix `f89d312`.

### iteration_31.md — Sprint 31 (fila de recálculo por evento, PRD §5.2) ✅ ENCERRADA (CTO, 2026-10-13)
- **Entrega (5/5, 14 pts, pilha LINEAR, 0 blockers):** fila/model `TarefaRecalculo` + `enfileirar!` idempotente (31.1 `b417fef`; fix D2 `1fa033e` = savepoint) ▸ `ExecutaTarefasJob` com lock próprio `728_104_536` + registry (31.2 `97095bc`) ▸ `RegistroRecalculoHandler` + 2 produtores in-transaction (31.3 `b50e425`; correções A/B) ▸ `RecalcularTodosHandler` (31.4 `e13f782`) ▸ `VincularDesvincularHandler` + produtor `after_commit` em `RegimeFrequentador` (31.5 `dae631f`). **Q14 RESOLVIDA**.
- **Tipos ADIADOS** (`FERIADO`/`DIAEXCEPCIONAL`/`DIREITO`): declarados nos 7 `TIPOS_ENTIDADE`, **sem produtor/handler** (models inexistentes) — política incremental. Consolidação durável: **ADR-0011**.
- **Abertos:** **Q15** (quadro real de devs), **Q16** (cauda do período ao encolher vínculo — 31.5), **D2 da 17.5** (`CalcularFrequenciaJob` sem guarda de mês finalizado), deploy da migration (só test local), **RuboCop-77** (deadline 2026-10-13). Ver §"Encerramento da Sprint 31".

### iteration_chore_*.md
- **`bump_rails_81`** (`chore/bump-rails-8.1`): fixa **Ruby 3.3.8 / Rails 8.1.4** (lockstep/ADR-0009); warning b de `frequentadores_visiveis.rb:351` corrigido no código (`sanitize_sql_array` + bind); `bin/brakeman` EXIT 0.
- **`debitos_pre_29_7`** (3 débitos, `16c1c9a`) · **Stubs destrutivos** (`remove_method` vazava por processo; 8 arquivos; `43b7d84`) · **`gitlab-ci`**: pipeline criado mas **bloqueado por infra — nenhum runner online**; **não declarar concluída**.

## Estado atual
- Branch **`feature/demanda-31-5-vincular-desvincular`** @ **`dae631f`** (pilha linear 31.1→31.5) — **NÃO pushada, NÃO mergeada** em `integration/sprint-29`. `COMMIT_MODE=manual`.
- `integration/sprint-29` @ **`da26ee8`** = pacote doc da 29 (ADR-0010 + Quadro §9) publicado. A 30 e a 31 ainda **não** entraram nela.
- **Baseline da suíte: 1214 runs / 4239 assertions / 3F + 12E / 0 skip** (15 pré-existentes: 11× Devise `redirect_to` + 1× timezone em `PresencaEndpointsTest` + order-dependent `PessoasSchemaLoaderTest`/paralelização). Espelho Pessoas: 19/68/0/0.
- **ADRs 0000–0011** (índice em `docs/README.md` atualizado p/ `0011`). Ambiente medido: Ruby **3.3.8** / Rails **8.1.4**.
- Próximo: **merge da pilha 31 em `integration/sprint-29`** + push (sequência em `iteration_31.md` §"Encerramento") → **Sprint 32** (débitos herdados: D2/17.5, Q16, RuboCop-77) + formalizar `implementation_plan.md` (sprints 29–31 ausentes).

## Referências para aprofundamento
- Estado/tarefas 29.0–29.8, rulings, **Quadro PRD §9 (L978+)** e baseline canônico → `docs/progress/iteration_29.md`
- Catálogo de fechamento e débitos S2/S3 → `docs/progress/iteration_29_closure.md` · Encerramento 30 → `docs/progress/iteration_30.md`
- Mecanismo §5.2 (fila/registry/handlers) e **Encerramento** → `docs/progress/iteration_31.md` + `docs/adr/0011-mecanismo-recalculo-por-evento.md`
- ADRs 0006–0011 → `docs/adr/` · Revisões 31.2–31.5 → `docs/quality/review_report_31_2..31_5.md`
- Regras/lições → `docs/governance/_context.md` e `docs/governance/lessons.md`
