# _context.md — progress
> Gerado em: 2026-10-05 | Fontes: iteration_29.md (L978+ Quadro PRD §9), iteration_29_closure.md, iteration_chore_*.md, adr/0006–0010 | Palavras: ~780
> Atualizar quando: nova iteration criada; status de tarefa alterado; sprint concluída; push/MR; baseline da suíte remedido.

## O que esta pasta contém
Acompanha as sprints do Frequência, com um `iteration_N.md` por sprint. Sprints 23/24 encerradas; 26 consolidada; **29 é a sprint ativa e está COMPLETA** (29.0 a 29.8 entregues, aprovadas e commitadas). As chores transversais têm arquivo próprio (`iteration_chore_*.md`).

## Pontos-chave para agentes
### iteration_29.md — Sprint 29 (cascata de autorização de frequência) ✅ CONCLUÍDA
- **Entrega:** substitui o baseline "todo autenticado lê tudo" (23.7) pela cascata do legado — PORO `AutorizacaoFrequencia`/29.4 (5 passos + `motivo`, fail-closed), scope SQL `FrequentadoresVisiveis`/29.6 (equivalente item a item, sem N+1), PORO `ElegibilidadeDesconsideracao`/29.5 (gate **só do passo 5** — D5), integração na `Ability` + 6 controllers/29.7 e matriz (12 cenários)/auditoria/29.8. Consolidação durável: **ADR-0010**.
- **Quadro de status PRD §9 itens 1–8** (L978+, CTO 2026-10-05): a 29 **fechou 2** — itens **1** (cascata, "a regra mais importante") e **7** (`GestorIndividual` como fonte de autorização, com ressalva do furo 🟡S2). Itens **2–6 e 8 permanecem abertos e sem dono executivo** (item 2 = 11 roles granulares → destino **Sprint 30**; itens 3/4/5/6/8 = PO/CTO com gatilho declarado). Ressalva do item 1: flag **default OFF** — implementada/provada, **não vigente em produção**.
- **Flag `FREQUENCIA_AUTORIZACAO_CASCATA`** (`:off`/`:shadow`/`:on`, default **OFF**): `:on` restringe e loga negações; `:shadow` só loga; `:off` = comportamento idêntico ao atual. Preserva a visão global (admin / `visualiza_frequentadores`).
- **Rulings do CTO:** D1 (roles `visualiza_frequentadores`/`visualiza_terceirizados` — a de terceirizados só é significativa combinada); D4 (TERCEIRIZADO = `Vinculo#tipo_vinculo.nome == "Terceirizado"`); D5 (desconsiderar = **apenas** hierarquia/passo 5; `GestorIndividual` vê mas não desconsidera); D6 (unidade inelegível não libera, ausente não interrompe, path corrompido fail-closed); D8 (nunca `valid?` no caminho de leitura). ADR-0008 = semântica de `ativo` do gestor (**projeção**: `true` sse ≥1 vínculo ativo).

### iteration_29_closure.md — catálogo de fechamento (CTO, 2026-10-05)
- Visão consolidada da 29 (não duplica as tasks); lista entregas 29.0–29.8, a semântica da flag e os débitos herdados.
- **Débitos abertos (não-bloqueantes):** 🟡 **S2** (twin SQL `geridos_user_ids` × PORO passo 4/GI inativo — a matriz é cega ao PORO; mutar `.ativos` do PORO não derruba teste de listagem; **gatilho binário** = teste no PORO **e** no twin SQL, ambos no baseline — elevado a **regra de conformidade na ADR-0010** regra 7) e 🟡 **S3** (`frequencia_por_orgao` fora do grão da matriz; cenário 12 sem-CPF cobre fail-closed, decisão sobre contas sem CPF é do **PO**). Dono sugerido Sprint 30/chore.
- **Achado de segurança novo:** `SQL Injection` Medium em `frequentadores_visiveis.rb:351` (nasceu na 29.7/`16c1c9a`, ausente do ledger) — **tratado na chore do bump** (ADR-0009 regra 5).

### iteration_chore_*.md
- **`bump_rails_81`** (`chore/bump-rails-8.1`): fixa **Ruby 3.3.8 / Rails 8.1.4**, corrige as 3 fontes de versão (lockstep/ADR-0009), mantém `load_defaults 8.0`. O warning (b) de `frequentadores_visiveis.rb:351` foi **corrigido no código** — `sanitize_sql_array` + bind (opção b1), ledger intocado; `bin/brakeman` = **EXIT 0** com relatório (EOLRails removido pelo bump).
- **`debitos_pre_29_7`**: 3 débitos fechados em `16c1c9a`.
- **Stubs destrutivos**: causa-raiz do 13º erro — `remove_method` do scope `Pessoas::Vinculo.ativos` vazava por processo; auditoria achou **8 arquivos vazando** (`43b7d84`); blindagens locais removidas (`166f51d`). Helper e cop anti-`remove_method` agendados (gatilho = tocar os arquivos).
- **`gitlab-ci`**: monorepo (raiz git = `Frequencia/`, app em `api-ponto/`) exige `.gitlab-ci.yml` na **raiz**; pipeline criado mas **bloqueado por infra — nenhum runner online**, o job `test` nunca rodou em runner real. **Não declarar concluída.**

### iteration_23.md / 24.md / 26.md
- 23: Devise + CanCanCan + Rolify (origem do baseline `can :read, :all`). 24: basic8. 26: 26.1–26.10 (`1a73a4d`).

## Estado atual
- Branch `integration/sprint-29` @ **`da26ee8`**, publicada (GitLab + fork GitHub). Sprint 29 fechada; pacote doc do CTO publicado (`da26ee8` = **ADR-0010** + **Quadro PRD §9**, `iteration_29.md` L978+). Árvore limpa.
- Commits-chave: `df57cf5` (29.7), `e795df9` (29.8), `16c1c9a` (débitos pré-29.7), `42ddb28` (bump Rails 8.1.4 + fix SQL injection), `d69324f` (ADR-0009/plano/closure), `da26ee8` (ADR-0010 + Quadro §9).
- **Baseline da suíte: 1083 runs / 3789 assertions / 1F + 11E / 0 skip.** As 12 são pré-existentes: 11× Devise `redirect_to` (`Users::SessionsControllerTest`/`PasswordsControllerTest`) + 1× timezone em `PresencaEndpointsTest`. Espelho Pessoas: 19/68/0/0.
- Próximo: **Sprint 30** (cascata/roles granulares + débitos S2/S3). Ligar a flag `:on` é **decisão do PO**.
- Dívidas de CI com gatilho binário: 77 offenses RuboCop (`chore/limpeza-rubocop-77`, gatilho rubocop EXIT=0). **Dívida de versão do Ruby FECHADA pela ADR-0009.** Ambiente medido: Ruby **3.3.8** / Rails **8.1.4** → ver `governance/_context.md`.

## Referências para aprofundamento
- Estado/tarefas 29.0–29.8, rulings do CTO, **Quadro PRD §9 (L978+)** e baseline canônico → `docs/progress/iteration_29.md`
- Catálogo de fechamento e débitos S2/S3 → `docs/progress/iteration_29_closure.md`
- Chore do bump 8.1 e warning `frequentadores_visiveis.rb:351` → `docs/progress/iteration_chore_bump_rails_81.md`
- Esteira/CI → `docs/progress/iteration_chore_gitlab-ci.md` · Stubs destrutivos → `docs/progress/iteration_chore_auditoria_stubs_destrutivos.md`
- ADRs 0006–0010 → `docs/adr/0006-…` … `0010-arquitetura-cascata-autorizacao-frequencia.md`
- Reviews 29.4–29.8 → `docs/quality/review_report_29_4..29_8.md` · Regras/lições → `docs/governance/_context.md` e `docs/governance/lessons.md`
