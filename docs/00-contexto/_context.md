# _context.md — inception (equiv.: 00-contexto/ + specs/ + adr/)
> Gerado em: 2026-09-23 | Fontes: 00-contexto/{00,01,02,03}*.md, specs/STATE.md, adr/0001..0005 | Palavras: ~640
> Atualizar quando: novo documento criado em 00-contexto/, specs/ ou adr/; ADR aceita/proposta; decisão arquitetural registrada; marco de fase alterado em specs/STATE.md.

## O que esta pasta contém
Equivalente real da pasta canônica `inception/`, que **não existe fisicamente** neste projeto (desvio documentado pelo CTO em `docs/_context.md`): visão/framework/convenções e requisitos de segurança em `00-contexto/`; memória de decisões e handoff da migração em `specs/STATE.md`; decisões arquiteturais em `adr/` (0001–0005; template em `0000-template.md`). `12-plano-implementacao/` e `duvidas/` também mapeiam para inception em `docs/_context.md`, mas ficam fora deste resumo (sem alterações na Sprint 23).

## Pontos-chave para agentes
### 00-contexto/00-visao-geral.md
- Migração do módulo Frequência da Intranet (Java 6 + MySQL 5) para Rails; Pessoas = autoridade cadastral (API/eventos), Frequência = autoridade de ponto, EstaçãoPonto com o mínimo de alterações; Intranet desligada ao final.
- Restrições fundamentais: nunca assumir regras sem evidência no legado; toda descoberta documentada; nunca gerar código antes de entender o comportamento.

### 00-contexto/01-framework-migracao.md
- Framework de 10 fases (Preparação → Inventário → Eng. Reversa → DDD → Arquitetura → Migração → Compatibilidade → Implementação → Testes → Implantação), evolutivo e orientado a risco, com critérios de aceite por fase.
- Estado: Fases 0–3 concluídas; Fase 4+ suspensas por decisão do usuário até PRD/plano; estratégia recomendada a priori = Strangler Fig (consolidada no ADR-0002).

### 00-contexto/02-convencoes.md
- Estrutura numerada `docs/00-…11/` + `adr/`; arquivos kebab-case com prefixo de 2 dígitos; cabeçalho com Propósito; marcadores `PENDÊNCIA:`/`DECISÃO:`/`APRENDIZADO:`/`EVIDÊNCIA:`/`⚠️ RISCO:`/`🤔 DÚVIDA:`.
- ADR: copiar `docs/adr/0000-template.md` → `NNNN-titulo-curto.md`; referenciar como "(ver ADR-NNNN)".

### 00-contexto/03-seguranca-stack.md (NOVO — 2026-09-23, CTO; Sprint 23)
- **RNF aceita, pendente de implementação:** rate limiting (rack-attack) em endpoint público de recuperação de senha (429/Retry-After) — vinculada ao débito 23.8: habilitar ActionMailer e aplicar throttle são pré-requisitos mútuos.
- Checklist de enumeração por canal lateral (status HTTP → flash → HTML → headers → log → timing → entradas malformadas → re-probe ao mudar dependência); equalizar assinatura de I/O (phantom work), não tempo (lição do Bug 10).
- Dependência funcional: recoverable exige fonte real de email (0/84 em dev; RF futura de cadastro/vinculação/sync) — débito 23.8-Obs4.

### specs/STATE.md (memória Spec-Driven)
- Decisões AD-001..006: integração Pessoas via API+eventos (AD-001), Strangler Fig 3 estágios (AD-002), Adapter+Nginx p/ EstaçãoPonto (AD-003), ciclo Spec-Driven sobre framework (AD-004, proposto), PoC `api-ponto` → novo repositório + DDD incremental (AD-005, aceito), API canônica Pessoas (AD-006, **pendente**).
- Handoff: Fases 0–3 concluídas; inventário fechado (schema de 22 tabelas `presenca_*` confirmado); Fase 4+ suspensa até PRD/plano; sem alterações na Sprint 23.

### adr/ (0001–0005)
- 0001 Integração Pessoas–Frequência (API REST + eventos; cache local espelho) — aceito; proíbe consulta direta ao banco do Pessoas.
- 0002 Strangler Fig com proxy reverso (sombra → parcial → total) — aceito; 0003 Adapter + proxy Nginx, zero alteração na EstaçãoPonto — aceito.
- 0004 Ciclo Spec-Driven (micro sobre o framework macro de 10 fases) — proposto; 0005 PoC `api-ponto` restaurada em novo repositório + refactoring incremental DDD (FR-LEGADO-DEBT-01..04) — aceito pelo gestor (04/08/2026).

## Estado atual
- Nova sinalização de segurança `03-seguranca-stack.md` (RNF rate limiting pendente; checklist canal lateral; dependência fonte de email) — Sprint 23.
- ADRs: 0001–0005 (4 aceitas, 1 proposta); AD-006 (API canônica Pessoas) pendente — não-bloqueante.
- Fases 0–3 concluídas; Fase 4+ suspensas até PRD; PRD-SCAFFOLD-ESTILO-BASIC8 aprovado na raiz (Sprint 24).
- `specs/STATE.md` e `adr/*` sem alteração na Sprint 23 (estáticos desde 2026-08).

## Referências para aprofundamento
- Para a visão geral da migração → `docs/00-contexto/00-visao-geral.md`
- Para RNF de segurança e checklist de canal lateral → `docs/00-contexto/03-seguranca-stack.md`
- Para decisões de projeto e handoff → `docs/specs/STATE.md`
- Para as ADRs → `docs/adr/0001-integracao-pessoas-frequencia.md` … `docs/adr/0006-schema-teste-espelho-pessoas.md`
- Para o framework de 10 fases → `docs/00-contexto/01-framework-migracao.md`