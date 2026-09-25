# Segurança da Stack de Autenticação — Padrões e Sinalizações

> **[⌂ Home](../README.md)**

## Propósito

Registrar as sinalizações de RF/RN e os padrões de segurança consolidados durante o bug-hunting da Sprint 23 sobre o fluxo recoverable do Devise (`POST /u/password`), para que as próximas sprints — em especial a que habilitar ActionMailer — já nasçam com estes requisitos. Fonte: `docs/quality/bug_report_23_bug-finder-r5.md` (Obs 1–4) e `docs/quality/bug_report_23_bug-finder-r4.md` (padrão recorrente de enumeração por canal lateral).

## Sinalizações

### 1. RNF — Rate limiting em endpoint público de recuperação de senha (padrão da stack Devise)

**Status:** ⏳ Aceita como RNF — pendente de implementação (vinculada ao débito 23.8)

Todo endpoint público de recuperação de senha/credencial do Frequência **deve** ter throttle (ex.: `rack-attack`: N requisições/intervalo por IP ou por email), como prática padrão para password recovery (OWASP/ASVS). É requisito **da stack Devise do Frequência**, não item pontual: qualquer fluxo público de auth (recoverable, e futuros confirmable/invitation) deve nascer com ele.

- **Justificativa (r5, Obs 1):** hoje `POST /u/password` não tem throttle; cada request com email conhecido gera 1 `UPDATE` (rotação de token + `reset_password_sent_at` + `updated_at`) e 1 linha `Rails.logger.error` com o email da vítima. Quando o ActionMailer for habilitado, o mesmo comportamento vira **inbox flooding** (email real de reset por request) e **reset-DoS** (rotação de token invalida o link já enviado antes do clique).
- **Condição de aceite:** rajada de N+1 requests → `429`/`Retry-After`; rotação de token não invalida link em voo quando o mailer estiver ativo.
- **Vínculo:** débito 23.8-Obs1 no `iteration_23.md` — nenhum avança sem o outro com a habilitação do ActionMailer.

### 2. Checklist — Enumeração por canal lateral (inclui blank/whitespace/malformed)

**Status:** ✅ Padrão registrado — aplicar preventivamente

As 4–5 rodadas de teste adversarial sobre `POST /u/password` formam um caso de estudo de "enumeração de contas via canais laterais" com hierarquia de explorabilidade decrescente. Checklist padrão para **qualquer** fluxo público que precise tratar entradas conhecidas/desconhecidas de forma indistinguível (recuperação de senha, e futuros confirmable/invitation). Aplicar preventivamente, não reativamente:

1. **Status HTTP** (trivial — 1 request);
2. **Flash tipo + texto** (trivial — 1 request; compara conteúdo, não só status);
3. **HTML estrutural** (trivial se houvesse diferença);
4. **Headers/cookies** (trivial);
5. **Log** (vazamento de email nos logs);
6. **Timing** (não-trivial — N requisições e análise estatística; igualar assinatura de I/O, não tempo artificial — ver lição em `docs/governance/lessons.md`);
7. **Entradas malformadas:** **blank, whitespace, `nil`, uppercase/mixed-case, unicode, arrays/hashes, tamanhos extremos** — a invariante de paridade deve cobrir todos os formatos de entrada, não só known × unknown (r5, Obs 3: blank/whitespace executam 4 queries vs 5, delta ~0.9ms — não explorável para enumeração hoje, mas fora da invariante prometida);
8. **Re-executar os probes de paridade sempre que uma dependência do fluxo mudar** — gatilho conhecido: habilitar ActionMailer/ActiveJob (`deliver_now` síncrono invalida qualquer equalização construída sem mailer; r5, Obs 2).

**Referência de implementação futura:** a r4 sugeriu adicionar esta subcategoria à skill `adversarial-testing-strategy` ou `structural-conformity-checklist` (Edge Cases/Integrações) — avaliar quando o AI Workflow for evoluído.

### 3. Dependência funcional — Fonte real de email como pré-requisito do recoverable

**Status:** ⏳ Aceita como dependência — pendente de RF futura de cadastro/vinculação de email

O fluxo recoverable **não pode ser validado de ponta a ponta em ambiente real** enquanto não existir origem de email:

- **Fato (r5, Obs 4):** 0/84 usuários em dev com `email`; `Admin::UsersController#user_params` não permite email; `db/seeds.rb` e fixtures não setam email; nenhum controller/import escreve email; ActionMailer desmontado.
- **Consequência:** mesmo habilitando o mailer (débito 23.8) e o throttle (sinalização 1), a feature continuará inoperante para usuários reais sem fonte populadora de email.
- **Ação:** registrar como dependência explícita/RN da evolução do recoverable — RF futura de cadastro/vinculação/sync de email (ex.: via Pessoas2/microsserviço cadastral ou cadastro local admin). A sprint que habilitar ActionMailer deve nascer com esta dependência mapeada (débito 23.8-Obs4).

## Rastreabilidade

- Iteração: `docs/progress/iteration_23.md` (débitos 23.8 / 23.8-Obs1..4; encerramento do bug-hunting de `POST /u/password` com gatilhos de reabertura).
- Relatórios: `docs/quality/bug_report_23_bug-finder-r4.md` (Bug 10; padrão recorrente), `docs/quality/bug_report_23_bug-finder-r5.md` (Obs 1–5; sinalização ao CTO).
- Lição: `docs/governance/lessons.md` (2026-09-23 — timing side-channel / phantom work).

---
**Autor:** CTO
**Data:** 2026-09-23
**Revisão:** 1
**Última atualização:** 2026-09-23
**Referências:** `docs/quality/bug_report_23_bug-finder-r5.md`, `docs/quality/bug_report_23_bug-finder-r4.md`, `docs/progress/iteration_23.md`, `docs/governance/lessons.md`
---