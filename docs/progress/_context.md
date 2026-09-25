# _context.md — progress
> Gerado em: 2026-09-23 | Fontes: iteration_23.md, iteration_24.md | Palavras: ~520
> Atualizar quando: nova iteration criada; status de tarefa alterado no iteration_24.md; sprint concluída; correção/encerramento registrado no iteration_23.md.

## O que esta pasta contém
Acompanhamento de sprints do Frequência (arquivos `iteration_N.md`, um por sprint). Registra a **Sprint 23** (auth: Devise + CanCanCan + Rolify — fechada, com ciclo de bug-hunting de `POST /u/password` **encerrado em 2026-09-23**) e a **Sprint 24** (stack basic8: gems + wiring — em andamento).

## Pontos-chave para agentes
### iteration_23.md (Sprint 23 — fechada: 23.1–23.10 + bug-hunting encerrado)
- **Bug 10 🟡 (timing side-channel)** corrigido via phantom work em `app/controllers/users/passwords_controller.rb#create` — `Devise.token_generator.generate` + UPDATE em `id = -1` (0 linhas) → paridade **5=5 queries**, teste `count_sql_queries` no `passwords_controller_test.rb`; branch `fix/bug10-recoverable-timing-sidechannel` **criada, commit pendente** (COMMIT_MODE=manual).
- **CTO (2026-09-23):** decisão de **MANTER** a correção do Bug 10 (divergência SERVICE-LEVEL/BUG_LEVEL=1 encerrada; veredito r4 vira referência histórica) — validação empírica da r5: paridade 5=5, timing mediano known×unknown ≈ 0 ms, zero mutação de dados, suíte 707/2232/1.
- **Débitos novos 23.8 + 23.8-Obs1..4:** 23.8 (habilitar ActionMailer) não avança sem 23.8-Obs1 (rate limiting rack-attack, 429/Retry-After) e 23.8-Obs2 (re-medição da paridade com `deliver_now` síncrono); Obs3 (blank/whitespace — 4 vs 5 queries) opcional; Obs4 (0/84 emails em dev; RF futura de fonte de email). Ciclo de bug-hunting **encerrado** com gatilhos de reabertura (habilitar mailer; surgir fonte real de emails). 5ª rodada: **0 bloqueadores** (Obs1 🟡 / Obs2 🟡 latente / Obs3 🟢 / Obs4-5 ⚪).
- ⚠️ 23.7–23.10 continuam marcadas ⬜ no original; o **merge da 23.7 permanece pendente** (pré-condição da 24.3; inconsistência de status não alterada).

### iteration_24.md (Sprint 24 — Stack basic8: gems + wiring; em andamento)
- 24.1 ✅: gems no Gemfile/lock — **zutils 4.0.0, simple_form 5.4.1, ransack 4.4.1, pagy 9.4.0**; `kaminari` 1.2.2 **preservado** (remoção RF10/Sprint 28); `ransackable_*` fora (RN04/Sprint 25); zero migration/schema e auth/ability intactos (RNF06).
- 24.2–24.6 ⬜ pendentes: initializer simple_form (wrapper BS5 + locale pt-BR), `Pagy::Backend` no `Admin::ApplicationController` (24.3 — exige merge da 23.7), `Pagy::Frontend` no `ApplicationHelper` (24.4), validação do flash local RF14 (24.5), smoke test de carga + aceite (24.6).
- Caminho crítico: 23.7 (merge) → 24.1 → 24.2 → 24.6; 24.3/24.4/24.5 paralelizáveis após 24.1. Total: 6 tasks | 10 pontos.

## Estado atual
- Sprint 23 fechada; Bug 10 corrigido e validado empiricamente (r5); branch `fix/bug10-recoverable-timing-sidechannel` criada — **commit + push pendentes**.
- Merge da 23.7 continua pendente (bloqueia 24.3).
- Sprint 24 em andamento: 24.1 ✅; 24.2–24.6 pendentes.
- Suíte mais recente: **707 runs / 2232 asserts / 1 falha** (timezone pré-existente, `presenca_endpoints_test.rb:187`; baseline anterior 669/1928).
- `authenticate` custom (CPF → Pessoas2) e `password_digest` preservados — risco alto (não remover).

## Referências para aprofundamento
- Para o ciclo de bugs do recoverable (B1/B9/Bug 10, débitos 23.8-Obs1..4, gatilhos de reabertura) → `docs/progress/iteration_23.md`
- Para relatórios das rodadas do Bug Finder → `docs/quality/bug_report_23_bug-finder-r5.md` (e r1..r4)
- Para detalhe das tasks 24.1–24.6 (critérios, riscos, aceite) → `docs/progress/iteration_24.md`
- Para a lição de phantom work e a RNF de segurança → `docs/governance/lessons.md` e `docs/00-contexto/03-seguranca-stack.md`
- Para a lição de ambiente (Ruby 3.4.2 real vs docs; binstubs `bin/*`) → `docs/governance/lessons.md`