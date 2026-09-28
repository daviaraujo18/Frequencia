# _context.md — docs (raiz do projeto)
> Gerado em: 2026-09-23 | Fontes: PRD-SCAFFOLD-ESTILO-BASIC8.md, PRD-FREQUENCIA.md, README.md, AGENTS.md (raiz), 00-contexto/03-seguranca-stack.md, índice de pastas docs/ | Palavras: ~400
> Atualizar quando: novo PRD gerado na raiz; nova pasta numerada criada; mudança estrutural nos docs; novo _context.md de equivalência gerado (ex.: 00-contexto/).

## O que esta pasta contém
Fonte de verdade consolidada do **Frequência** (migração do módulo Frequência da Intranet para Rails 8 — app `Frequencia/api-ponto`). Estrutura numerada própria (`00-contexto/` a `12-plano-implementacao/`) no lugar das pastas canônicas `inception/`/`analysis/`/`knowledge/` — ver desvio abaixo. Na raiz há dois PRDs, `README.md` (estado por fases) e subpastas `adr/`, `duvidas/`, `specs/`, `governance/`, `progress/`.

## Estrutura canônica × estrutura real (desvio)
- **Não existem** `inception/`, `analysis/`, `knowledge/` nem `quality/` físicos neste projeto.
- `inception/` ≈ `00-contexto/` (visão, framework de migração, convenções) + `12-plano-implementacao/` (vazia) + `specs/` + `adr/` + `duvidas/`.
- `analysis/` ≈ `01-inventario/` (domínios, tabelas, schema), `03-dominio/` (DDD), `04-decisoes/`, `05-migracao/`, `06-integracoes/`, `07-estacao-ponto/`, `08-pessoas/`, `09-intranet/` (incl. `09-intranet/fluxos/` A–D).
- `knowledge/` ≈ `01-inventario/` (schema confirmado), `06-integracoes/`, `09-intranet/`.
- `02-arquitetura/`, `10-testes/`, `11-deploy/` existem mas estão vazios (fases suspensas — ver `README.md`).
- Pastas canônicas ativas: `governance/` e `progress/`.

## Pontos-chave para agentes
### PRD-SCAFFOLD-ESTILO-BASIC8.md (novo — 2026-09-21)
- Feature: padronizar scaffolds/CRUDs admin no estilo do basic8 — gems `zutils ~> 4.0`, `simple_form ~> 5.4`, `ransack ~> 4.4`, `pagy ~> 9`; **kaminari removido** ao final do piloto.
- Template em `lib/templates/` gera controller herdando `Admin::ApplicationController` com `load_and_authorize_resource` + `ransack(params[:q])` + `@pagy, @collection = pagy(...)` + notices pt-BR; views via partials `shared/*`.
- Piloto P2: `regimes`/`versoes` (generator) + `estacoes` (manual) no novo estilo; `users`/`frequentadores` só trocam paginação para pagy (exceção bespoke RN02); whitelist `ransackable_*`; controller Stimulus local `filtering`; decisões D1–D6 fechadas; sem alteração de auth/banco (RNF06).

### PRD-FREQUENCIA.md
- PRD-base do sistema Frequência (baseline da migração); fonte histórica de RFs/RNs gerais.

### README.md
- Estado por fases: F1 inventário ✅, F2 fluxos A–D ✅, F3 DDD ✅; F4+ (arquitetura/código) ⏸️ suspensas até PRD + plano.

## Estado atual
- Sprint 23 (auth) **fechada**; bug-hunting de `POST /u/password` **encerrado** (Bug 10 🟡 corrigido via phantom work, manutenção confirmada pelo CTO); merge da 23.7 pendente; Sprint 24 em andamento (24.1 ✅; 24.2–24.6 ⬜) — ver `progress/_context.md`.
- **NOVO** `00-contexto/03-seguranca-stack.md` (RNF rate limiting + checklist canal lateral + dependência fonte de email); equivalente de `inception/` agora com resumo em `docs/00-contexto/_context.md`.
- Equivalentes de `analysis/` (`01-inventario/`, `03-dominio/`, `04-decisoes/`, `05-migracao/`, `06-integracoes/`, `07-estacao-ponto/`, `08-pessoas/`, `09-intranet/`) e `knowledge/` (`01-inventario/`, `06-integracoes/`, `09-intranet/`) **sem alterações na Sprint 23** (estáticos desde 2026-08) — sem `_context.md` dedicados; estrutura real documentada nas linhas 10–14 acima.
- PRD-SCAFFOLD-ESTILO-BASIC8 aprovado — aguardando Project Planner / Sprint Planner; AGENTS.md raiz com Identidade preenchida (Rails 8.0.4, Devise 5, CanCanCan 3.6, Rolify 6, Pagy 9).
- Suíte mais recente: **707 runs / 2232 asserts / 1 falha** pré-existente de timezone (baseline anterior 669/1928).

## Referências para aprofundamento
- Para a feature de scaffolds/CRUD basic8 → `docs/PRD-SCAFFOLD-ESTILO-BASIC8.md`
- Para o PRD-base do Frequência → `docs/PRD-FREQUENCIA.md`
- Para navegação pelas fases e índices → `docs/README.md`
- Para regras e lições → `docs/governance/_context.md` e `docs/governance/lessons.md`
- Para o sprint atual → `docs/progress/_context.md` e `docs/progress/iteration_23.md`