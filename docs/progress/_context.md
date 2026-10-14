# _context.md — progress
> Gerado em: 2026-10-14 | Fontes: git (HEAD real medido `ceaac87`), iteration_29/30/31.md, iteration_31.md §Encerramento, iteration_chore_limpeza_rubocop_77.md, adr/0011, docs/12-plano-implementacao/implementation_plan.md (v2), docs/README.md, docs/governance/_context.md | Palavras: ~780
> Atualizar quando: nova iteration criada; status de tarefa alterado; sprint concluída; push/MR; baseline da suíte remedido.

## O que esta pasta contém
Acompanha as sprints do Frequência, com um `iteration_N.md` por sprint. Sprints 23/24 encerradas; 26 consolidada; **29, 30 e 31 estão COMPLETAS** (implementadas, aprovadas, commitadas). As chores transversais têm arquivo próprio (`iteration_chore_*.md`). **Defasagem real:** `iteration_25`, `iteration_27` e `iteration_28` **nunca existiram**; o `iteration_26.md` é o **"Port de Estilo basic8 (prelúdio dos scaffolds)"** — escopo diferente do "Piloto regimes/versoes" que o plano v1 previa.

## Pontos-chave para agentes
### iteration_29.md — Sprint 29 (cascata de autorização) ✅ CONCLUÍDA
- **Entrega:** substitui o baseline "todo autenticado lê tudo" pela cascata do legado — PORO `AutorizacaoFrequencia`/29.4 + scope SQL `FrequentadoresVisiveis`/29.6 (equivalente item a item, sem N+1) + `ElegibilidadeDesconsideracao`/29.5 (gate **só do passo 5**, D5) + `Ability` + 6 controllers/29.7 + matriz (12 cenários)/29.8. Consolidação durável: **ADR-0010**.
- **Flag `FREQUENCIA_AUTORIZACAO_CASCATA`** (`:off`/`:shadow`/`:on`, default **OFF**): `:on` restringe e loga negações; `:shadow` só loga. Implementada/provada, **não vigente**. Ligar `:on` = decisão do dev/PO (**resolvida** em `d50f317`: ativar quando todas as roles estiverem prontas; hoje bloqueada pela migração 30.9b a 87,9% de não-resolvidos).
- **Rulings do CTO (referência):** D1, D4, D5 (ver ≠ desconsiderar), D6 (fail-closed), D8 (leitura nunca `valid?`).

### iteration_30.md — Sprint 30 (gate D5, roles, débitos, shadow) ✅ ENCERRADA (CTO, 2026-10-08)
- **Entrega:** gate D5 exposto atrás da flag; **2 roles da cascata** semeadas (30.9a `98c43ce`) + migração do legado (30.9b `e79d89d`); débitos S2/S3 (30.6/30.7, só teste); **User local dos gestores de unidade** (30.10). **30.4/30.5 = N/A** sob ruling **30.3 = A emendado** (política incremental).
- **30.8 re-escopada** de "7 dias em PRODUÇÃO" → **observação em DEV** (1366 eventos; insumo com 4 limitações). Bug 🟠2 = **Risco Aceito**. **Débito ESTRUTURAL** (enforcement opt-in = causa-raiz do Bug 🔴1) → **ADR-0010 regra 9**.

### iteration_31.md — Sprint 31 (fila de recálculo por evento, PRD §5.2) ✅ ENCERRADA (CTO, 2026-10-13)
- **Entrega (5/5, 14 pts, pilha LINEAR, 0 blockers):** fila/model `TarefaRecalculo` + `enfileirar!` idempotente (31.1 `b417fef`; fix D2 `1fa033e` = savepoint) ▸ `ExecutaTarefasJob` com lock próprio `728_104_536` + registry (31.2 `97095bc`) ▸ `RegistroRecalculoHandler` + 2 produtores in-transaction (31.3 `b50e425`) ▸ `RecalcularTodosHandler` (31.4 `e13f782`) ▸ `VincularDesvincularHandler` + produtor `after_commit` em `RegimeFrequentador` (31.5 `dae631f`). **Q14 RESOLVIDA**.
- **Tipos ADIADOS** (`FERIADO`/`DIAEXCEPCIONAL`/`DIREITO`): declarados nos 7 `TIPOS_ENTIDADE`, **sem produtor/handler** (models inexistentes) — política incremental. Consolidação durável: **ADR-0011**.
- **Abertos:** **Q15** (quadro real de devs), **Q16** (cauda do período ao encolher vínculo — 31.5), **D2 da 17.5** (`CalcularFrequenciaJob` sem guarda de mês finalizado; fonte: `SPRINT-PLAN.md:536` — **não existe `iteration_17.md`**), deploy da migration (só test local).

### iteration_chore_*.md
- **`limpeza_rubocop_77`** (`chore/limpeza-rubocop-77`, 2026-10-13): **débito RuboCop-77 ZERADO** — 75 → **0** (`bin/rubocop` EXIT 0, autocorrect seguro `-a`, 16 arquivos, 0 supressões); suíte idêntica ao baseline.
- **`bump_rails_81`**: fixa **Ruby 3.3.8 / Rails 8.1.4** (lockstep/ADR-0009); `bin/brakeman` EXIT 0.
- **`debitos_pre_29_7`** · **Stubs destrutivos** (`remove_method` vazava por processo; 8 arquivos) · **`gitlab-ci`**: pipeline criado mas **bloqueado por infra — nenhum runner online**.

## Estado atual
- **HEAD real medido: `ceaac87`** na branch **`chore/limpeza-rubocop-77`** ("docs: regera governance/_context.md … + corrige a contagem no iteration_31"), **JÁ PUSHADA** em `origin` (fork GitHub `daviaraujo18/Frequencia`) **e** `gitlab` (`gitlab.tjpi.jus.br`); **NÃO** existe em `upstream`.
- **`integration/sprint-29` @ `d50f317`** (local) — resolve a Q16 (ativar `:on` quando as roles estiverem prontas). Os remotes estão **atrás**: `origin` @ `38359cd`, `gitlab` @ `bcf0807`. O **merge da pilha 31 em `integration/sprint-29` segue PENDENTE / bloqueado por decisão do dev**.
- **CI gate verde:** suíte **1214/4239/3F+12E/0 skip** (15 pré-existentes: 11× Devise `redirect_to` + 1× timezone + order-dependent do espelho/paralelização) — **sem regressão**.
- **ADRs 0000–0011** (índice em `docs/README.md`). **`docs/governance/_context.md` regenerado** (42 lições, ADRs 0000–0011). **`docs/README.md` atualizado (2026-10-14)** — cabeçalho "Estado Atual" deixou de dizer "Fases 4+ suspensas"; Sprints 23–31 implementadas.
- **`implementation_plan.md` reescrito (v2, 2026-10-14)** — cobre as **Sprints 24–32** com nova seção **"Reconciliação de numeração e cobertura"**; registra que 25/27/28 não rodaram e a divergência de escopo da 26.
- **Sprint 32 = esboço (macro)** — hardening/débitos herdados: **D2/17.5** (guarda de mês finalizado no `CalcularFrequenciaJob`; o handler espelha), **Q16** (cauda do período do vínculo), **Q15** (quadro de devs), deploy da migration `create_tarefas_recalculo` no dev remoto, governança de docs (`CLAUDE.md` do workspace aponta (errado) para `pessoas2/docs/`).
- **Questões abertas:** **Q15**, **Q16** e uma nova (registrada na reconciliação do plano v2): **a linha basic8 (25/27/28) foi abandonada ou está pausada?**
- **Working tree (não commitado, `COMMIT_MODE=manual`):** `implementation_plan.md` e `docs/README.md` aparecem como **modificados** (edits v2/2026-10-14 ainda pendentes de commit) + `api-ponto/config/{credentials.yml.enc,environments/development.rb}` e logs/tmp.

## Referências para aprofundamento
- Estado/tarefas 29.0–29.8, rulings, Quadro PRD §9 (L978+) e baseline canônico → `/home/davi.queiroz/Área de trabalho/workspace_integração/Frequencia/docs/progress/iteration_29.md`
- Catálogo de fechamento e débitos S2/S3 → `…/docs/progress/iteration_29_closure.md` · Encerramento 30 → `…/docs/progress/iteration_30.md`
- Mecanismo §5.2 (fila/registry/handlers) e **Encerramento** → `…/docs/progress/iteration_31.md` + `…/docs/adr/0011-mecanismo-recalculo-por-evento.md`
- Revisões 31.2–31.5 → `…/docs/quality/review_report_31_2..31_5.md` · Plano macro (v2, 24–32) → `…/docs/12-plano-implementacao/implementation_plan.md`
- Índice/estado geral → `…/docs/README.md` · Regras/lições → `…/docs/governance/_context.md` e `…/docs/governance/lessons.md`
