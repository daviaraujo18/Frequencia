# _context.md — docs (raiz do projeto)
> Gerado em: 2026-10-15 | Fontes: docs/README.md, docs/12-plano-implementacao/implementation_plan.md (v2), docs/progress/iteration_32.md, docs/adr/ (0000–0011), docs/quality/ (39 arquivos), PRD-FREQUENCIA.md, PRD-SCAFFOLD-ESTILO-BASIC8.md, índice real de docs/ | Palavras: ~525
> Atualizar quando: novo PRD/ciclo gerado na raiz; nova pasta numerada criada; mudança estrutural nos docs; novo `_context.md` de equivalência gerado (ex.: `00-contexto/`).

## O que esta pasta contém
Fonte de verdade consolidada do **Frequência** (migração do módulo Frequência da Intranet para Rails 8 — app `Frequencia/api-ponto`). Estrutura numerada própria (`00-contexto/` a `12-plano-implementacao/`) no lugar das pastas canônicas `inception/`/`analysis/`/`knowledge/` — ver desvio abaixo. Na raiz há dois PRDs, `README.md` (estado por fases) e as subpastas `adr/`, `duvidas/`, `specs/`, `governance/`, `progress/` e `quality/`.

## Estrutura canônica × estrutura real (desvio)
- **Não existem** `inception/`, `analysis/` nem `knowledge/` físicos. (A pasta `quality/` **existe** — ver abaixo.)
- `inception/` ≈ `00-contexto/` (visão, framework, convenções, `03-seguranca-stack.md`) + `12-plano-implementacao/` (`implementation_plan.md` v2) + `specs/` + `adr/` + `duvidas/`.
- `analysis/` ≈ `01-inventario/` (domínios, tabelas, schema), `03-dominio/` (DDD), `04-decisoes/`, `05-migracao/`, `06-integracoes/`, `07-estacao-ponto/`, `08-pessoas/`, `09-intranet/` (incl. `09-intranet/fluxos/` A–D).
- `knowledge/` ≈ `01-inventario/` (schema confirmado), `06-integracoes/`, `09-intranet/`.
- `quality/` existe e está **ativa**: **39 arquivos** (review/bug reports das Sprints 23, 29, 30, 31, 32 + chores).
- `02-arquitetura/` e `10-testes/` existem mas estão **vazias** (só `.gitkeep`); `11-deploy/` contém `arquivo-recurring-yml-solid-queue.yml` (arquivo histórico da migração Solid Queue→Sidekiq).
- Pastas canônicas ativas: `governance/`, `progress/`, `quality/`.

## Pontos-chave para agentes
### README.md (atualizado 2026-10-14)
- Estado por fases: F1 inventário ✅, F2 fluxos A–D ✅, F3 DDD ✅; **F4 (arquitetura/código) 🚧 EM ANDAMENTO** — arquitetura definida, implementação por sprints.
- **Sprints 23–32 implementadas** (última: 32 — hardening da guarda de mês finalizado, 2026-10-14; antecessora 31 — recálculo por evento, ADR-0011). ADRs `0000`–`0011`.
### 12-plano-implementacao/implementation_plan.md (v2, ~31 KB)
- Plano macro **v2**, cobrindo **Sprints 24–32** (Épico 7); **Sprint 32 ✅ encerrada**.
### PRD-SCAFFOLD-ESTILO-BASIC8.md
- Feature: padronizar scaffolds/CRUDs admin no estilo basic8 (zutils, simple_form, ransack, pagy; **kaminari removido**). Linha basic8 (Sprints 25/27/28 do plano v1) **PAUSADA** por ruling do dev (2026-10-14) — não cancelada.
### PRD-FREQUENCIA.md
- PRD-base do sistema; fonte histórica de RFs/RNs gerais.

## Estado atual
- **Sprint 32 ENCERRADA** (CTO, 2026-10-14): 32.1 ✅ guarda de mês finalizado por dia no `CalcularFrequenciaJob` (D2/17.5); 32.2 ✅ espelho no `RecalcularTodosHandler` (**fechado nos dois espelhos**); 32.4 ✅ CLAUDE.md do workspace escopado por projeto. **32.3 STANDALONE** — deploy bloqueado por rede.
- **Sprint 33 com escopo definido pelo dev = `32.O1`** (enforcement opt-in da cascata, ADR-0010 regra 9, ~5 pts) — toca autorização; plano será submetido ao dev antes de qualquer código. **Nada implementado.**
- Qualidade: Code Reviewer **0 blockers**; Bug Finder **0 bugs novos**; suíte **1222/4257/3F+12E/0 skip** (15 pré-existentes). Lições **42**. RuboCop 0; Zeitwerk OK.
- **Ciclo Guardian rodado em 2026-10-15** (cadência 3–5 sprints): veredito = entropia moderada-baixa, concentrada no `docs/_context.md` da raiz (este arquivo).
- HEAD `b23bf49` na branch `feature/demanda-32-2-espelho-handler`.

## Referências para aprofundamento
- Para a feature de scaffolds/CRUD basic8 → `docs/PRD-SCAFFOLD-ESTILO-BASIC8.md`
- Para o PRD-base do Frequência → `docs/PRD-FREQUENCIA.md`
- Para navegação pelas fases e índices → `docs/README.md`
- Para regras e lições → `docs/governance/_context.md` e `docs/governance/lessons.md`
- Para o sprint atual e estado → `docs/progress/_context.md` e `docs/progress/iteration_32.md`
- Para o plano macro de sprints → `docs/12-plano-implementacao/implementation_plan.md`
