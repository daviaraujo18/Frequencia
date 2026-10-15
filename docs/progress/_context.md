# _context.md — progress
> Gerado em: 2026-10-15 | Fontes: git (HEAD real medido `b23bf49`), iteration_29/30/31/32.md, iteration_32.md §Encerramento, docs/quality/review_report_32_1.md/_32_2.md + bug_report_32_hardening_guard_finalizado.md, adr/0011, docs/12-plano-implementacao/implementation_plan.md (v2), docs/README.md | Palavras: ~780
> Atualizar quando: nova iteration criada; status de tarefa alterado; sprint concluída; push/MR; baseline da suíte remedido.

## O que esta pasta contém
Acompanha as sprints do Frequência, com um `iteration_N.md` por sprint. Sprints 23/24 encerradas; 26 consolidada; **29, 30, 31 e 32 estão COMPLETAS** (implementadas, aprovadas, commitadas). As chores transversais têm arquivo próprio (`iteration_chore_*.md`). **Defasagem real:** `iteration_25`, `iteration_27` e `iteration_28` **nunca existiram**; o `iteration_26.md` é o **"Port de Estilo basic8 (prelúdio dos scaffolds)"** — escopo diferente do "Piloto regimes/versoes" que o plano v1 previa.

## Pontos-chave para agentes
### iteration_32.md — Sprint 32 "Hardening e débitos herdados" 🟢 ENCERRADA (CTO, 2026-10-14)
- **Núcleo de código (5 pts, 0 blockers / 0 bugs novos):** **32.1** (`fe7f8ff` guarda de mês finalizado **por dia** no `CalcularFrequenciaJob` — débito **D2/17.5**) ▸ **32.2** (`905d8fb` espelho no `RecalcularTodosHandler`) ⇒ **D2/17.5 fechado nos DOIS espelhos**. Guarda reusa o predicado **único** `ConsolidacaoMensalService.finalizado?` + memo local por usuário (S1); cobre virada de mês/ano bissexto.
- **32.3 reclassificada STANDALONE** (deploy da migration `create_tarefas_recalculo` no dev remoto: **aprovada pelo dev, bloqueada por REDE** — host `10.150.110.174:5000` inalcançável; **cron `executa_tarefas` DESLIGADO**, correto). **32.4 ✅** (`CLAUDE.md` do workspace **escopado por projeto** — arquivo **fora** do repo, sem commit).
- **Qualidade:** Code Reviewer **0 blockers** (32.1/32.2); Bug Finder **0 bugs novos** (`docs/quality/bug_report_32_hardening_guard_finalizado.md`) — 2 achados não-bloqueantes: 🟢 TOCTOU residual **confirmado reproduzível** (reduzido pelo hardening; a memoização amplia a janela de *por consulta* → *por usuário*) e ⚪ staleness pré-existente na virada. Suíte **1222/4257/3F+12E/0 skip** (15 pré-existentes). RuboCop 0; Zeitwerk OK.

### iteration_31.md — Sprint 31 (fila de recálculo por evento, PRD §5.2) ✅ ENCERRADA (CTO, 2026-10-13)
- **Entrega (5/5, 14 pts, pilha LINEAR):** fila/model `TarefaRecalculo` + `enfileirar!` idempotente (31.1) ▸ `ExecutaTarefasJob` (lock `728_104_536`) + registry (31.2) ▸ `RegistroRecalculoHandler` + 2 produtores (31.3) ▸ `RecalcularTodosHandler` (31.4) ▸ `VincularDesvincularHandler` + produtor `after_commit` (31.5). **Q14 RESOLVIDA**. Consolidação durável: **ADR-0011**. Tipos **ADIADOS** (`FERIADO`/`DIAEXCEPCIONAL`/`DIREITO`).
- **Débitos herdados tratados na 32:** **D2/17.5** (job, 32.1 ✅) e **D2/31.4** (handler, 32.2 ✅); deploy da migration (32.3, standalone).

### iteration_30.md — Sprint 30 (gate D5, roles, débitos, shadow) ✅ ENCERRADA (CTO, 2026-10-08)
- **Entrega:** gate D5 exposto atrás da flag; **2 roles da cascata** semeadas (30.9a) + migração do legado (30.9b); débitos S2/S3 (só teste); **User local dos gestores de unidade** (30.10). **30.4/30.5 = N/A** sob **30.3 = A emendado** (política incremental).
- **30.8 re-escopada** de "7 dias em PRODUÇÃO" → **observação em DEV**. Bug 🟠2 = **Risco Aceito**. **Débito ESTRUTURAL** (enforcement opt-in = causa-raiz do Bug 🔴1) → **ADR-0010 regra 9** (candidato **32.O1**).

### iteration_29.md — Sprint 29 (cascata de autorização) ✅ CONCLUÍDA
- **Entrega:** substitui o baseline "todo autenticado lê tudo" pela cascata — PORO `AutorizacaoFrequencia`/29.4 + scope SQL `FrequentadoresVisiveis`/29.6 + `Ability` + 6 controllers + matriz. Consolidação durável: **ADR-0010**.
- **Flag `FREQUENCIA_AUTORIZACAO_CASCATA`** (`:off`/`:shadow`/`:on`, default **OFF**): `:on` restringe e loga; `:shadow` só loga. `:on` = decisão do dev (resolvida em `d50f317`: ativar quando as roles estiverem prontas).

### iteration_chore_*.md
- **`limpeza_rubocop_77`** (2026-10-13): **débito RuboCop-77 ZERADO** (75 → 0). **`bump_rails_81`**: fixa **Ruby 3.3.8 / Rails 8.1.4** (lockstep/ADR-0009). **`gitlab-ci`**: pipeline criado mas **bloqueado por infra — nenhum runner online**.

## Estado atual
- **HEAD real medido: `b23bf49`** na branch **`feature/demanda-32-2-espelho-handler`** ("docs: encerramento documental da Sprint 32 (hardening/debitos)"), **JÁ PUSHADA** em `origin` (fork GitHub `daviaraujo18/Frequencia`) **e** `gitlab` (`gitlab.tjpi.jus.br`); **NÃO** existe em `upstream`.
- **`integration/sprint-29` @ `d50f317`** (local) — resolve a Q16 (ativar `:on` quando as roles estiverem prontas); **INTACTA**. O **merge da pilha 31 em `integration/sprint-29` segue PENDENTE / bloqueado por decisão do dev**.
- **CI gate:** suíte **1222/4257/3F+12E/0 skip** (15 pré-existentes: 11× Devise `redirect_to` + 1× timezone + order-dependent do espelho; **sem regressão**). RuboCop 0; Zeitwerk OK.
- **Plano/documentação:** `implementation_plan.md` **v2** (Sprints 24–32; **Sprint 32 ✅ encerrada**, Épico 7); `docs/README.md` atualizado ("Sprints 23–32"); **ADR-0011** com **nota datada** (2026-10-14) registrando o fechamento do D2/17.5 — **nenhuma ADR nova**; `docs/governance/lessons.md` com **42 lições** (nenhuma nova na 32).
- **Questões:** Q15 resolvida (**1 dev sequencial**); Q16 resolvida (**manter o literal** — cauda = débito aceito); **Q32-B parcialmente resolvida** (32.4 executada; resta o deploy); linha **basic8 (25/27/28) PAUSADA**; **Sprint 33 com escopo definido pelo dev = `32.O1`** (enforcement opt-in da cascata, ADR-0010 regra 9, ~5 pts, toca autorização — plano a ser submetido ao dev antes de qualquer código; **nada implementado**); tipos adiados `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO`; Bug 🟠2 = risco aceito.
- **Working tree (não commitado, `COMMIT_MODE=manual`):** **só ruído de ambiente** (`config/credentials.yml.enc`, `config/environments/development.rb` [flag `FREQUENCIA_AUTORIZACAO_CASCATA=shadow` — manter fora do commit], logs/tmp). **O pacote doc-only foi COMMITADO em `b23bf49`** (encerramento da Sprint 32: `iteration_32.md`, `docs/README.md`, `implementation_plan.md`, `adr/0011-*.md`, `bug_report_32_*.md`, `governance/_context.md`, `progress/_context.md`) — **nada pendente de commit** (esta linha foi gerada em `40740b3`, antes daquele commit).

## Referências para aprofundamento
- Encerramento da Sprint 32, débitos e achados → `/home/davi.queiroz/Área de trabalho/workspace_integração/Frequencia/docs/progress/iteration_32.md`
- Qualidade 32 → `…/docs/quality/review_report_32_1.md`, `_32_2.md`, `bug_report_32_hardening_guard_finalizado.md`
- Mecanismo §5.2 + nota de resolução do D2/17.5 → `…/docs/adr/0011-mecanismo-recalculo-por-evento.md`
- Estado/tarefas 29.0–29.8 e baseline canônico → `…/docs/progress/iteration_29.md` · Fechamentos 30/31/32 → `…/docs/progress/`
- Plano macro (v2, 24–32) → `…/docs/12-plano-implementacao/implementation_plan.md` · Índice → `…/docs/README.md` · Regras/lições → `…/docs/governance/`
