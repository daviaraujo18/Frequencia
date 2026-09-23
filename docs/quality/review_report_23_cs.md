# Relatório de Revisão — Code Reviewer — Iteração 23 — Frequência

> **Tipo:** review_report
> **Data:** 2026-09-23
> **Branch origem:** `fix/bug10-recoverable-timing-sidechannel` (commit `66ca7fd`)
> **Branch destino:** encadeamento local (convenção de branches encadeadas; repo sem `develop`)
> **Arquivos alterados (revisados):** `api-ponto/app/controllers/users/passwords_controller.rb` (+34), `api-ponto/test/controllers/users/passwords_controller_test.rb` (+36)
> **Tarefa revisada:** Bug 10 (🟡 Médio) — timing side-channel em `POST /u/password` (recoverable `paranoid` + ActionMailer desmontado)
> **Baseline comparado:** `612a442` (estado pré-Bug 10)
> **Validação executada nesta revisão:** classe `test/controllers/users/passwords_controller_test.rb` → 7 runs / 45 assertions / 0 failures, em 4 seeds distintos (35139, 1, 42, 12345); `test/controllers/users/` → 24 runs / 148 assertions / 0 failures. Suíte completa já validada pelo Bug Finder r5 (707/2232/1, falha de timezone pré-existente).

## Veredito

**✅ APROVADO — sem Blockers (🔴).** O patch é inócuo, seguro e alinhado à arquitetura da stack (Devise 5 / Rails 8 API-only custom). O phantom work equaliza a assinatura de I/O sem mutar dados (UPDATE em `id = -1` afeta 0 linhas, `update_all` sem callbacks/validações) e o teste de paridade é determinístico (contagem de queries, não timing) e estável nas 4 execuções verificadas.

## Blockers (🔴)

Nenhum.

## Sugestões não-bloqueantes (🟡 / 🟠)

| ID | Tipo | Descrição | Tarefa afetada | Ação sugerida |
|----|------|-----------|----------------|---------------|
| S1 | 🟡 Melhoria | O teste de paridade trava apenas a **contagem** de queries; a **inocuidade** do phantom (nenhum campo de token/`reset_password_sent_at` alterado em nenhum usuário) foi validada empiricamente pelo Bug Finder r5, mas não está coberta por um assert permanente. | 23.8 (Bug 10) | Opcional: adicionar assert no teste (ex.: snapshot de `User.pluck(:id, :reset_password_token, :reset_password_sent_at)` antes/depois do caminho unknown) para documentar a invariante de não-mutação. Não bloqueante (SUGGESTION_LEVEL=1). |
| S2 | 🟡 Melhoria (herdada r5 Obs 3) | Blank/whitespace no email executam 4 queries vs 5 (o Devise pula o SELECT por email para valores blank); o teste do Bug 10 não cobre esse formato. Não explorável para enumeração (known × unknown continuam 5=5), mas quebra a generalidade da invariante "5 = 5". | 23.8-Obs3 | Já registrado como débito opcional no `iteration_23.md`; manter como está ou estender o teste com `email: ""` e `email: "   "` quando a invariante total for desejada. |
| S3 | 🟠 Débito (herdada r5 Obs 2) | Ao habilitar ActionMailer (`deliver_now` síncrono), a paridade de timing do Bug 10 quebra por ordem de grandeza e o teste de queries continuaria verde (falsa segurança). O comentário do patch afirma a suficiência da correção apenas no cenário atual. | 23.8-Obs2 | Já registrado como débito bloqueador da 23.8; recomenda-se atualizar o comentário do patch para explicitar a condicionalidade (mailer desligado) quando a 23.8 for trabalhada. |
| S4 | ⚪ Info | `where(id: -1)` depende da PK ser sempre ≥ 1 (serial/identity). Se um registro com PK negativa fosse inserido manualmente, o phantom o atualizaria (apenas token/`sent_at`; nunca senha). Risco teórico desprezível — nenhuma evidência de PKs negativas no domínio. | — | Registrar apenas como nota de auditoria; sem ação. |

## Elogios (🟢)

| ID | Elogio | Tarefa |
|----|--------|--------|
| E1 | Phantom work por **paridade de I/O real** (SELECT de colisão + SAVEPOINT/UPDATE/RELEASE simétrico ao safe do Devise) em vez de `sleep`/delay artificial — anti-pattern explícito — alinhado à lição registrada em `docs/governance/lessons.md` | Bug 10 |
| E2 | `update_all` em registro inexistente: zero callbacks/validações, zero mutação garantida, sem lock contention (validado em análise de concorrência pelo r5) | Bug 10 |
| E3 | `transaction(requires_new: true)` → SAVEPOINT/RELEASE, replicando exatamente a assinatura de transação do caminho conhecido | Bug 10 |
| E4 | Teste **determinístico** (contagem de `sql.active_record`) e não-timing-based → imune a flakiness; `ensure` desinscreve o subscriber; `reset!` isola as sessões entre as duas requisições | Bug 10 |
| E5 | Uso de `Devise.token_generator.generate` (API pública da gem) com `_raw, enc` — mesma assinatura/fonte do `recoverable.rb` da gem, sem reinventar geração de token | Bug 10 |

## Checklist de revisão

### Funcionalidade
- [x] Phantom work inócuo: nenhum side-effect em dados (UPDATE 0 linhas) nem em segurança (token fantasma não persistido)
- [x] Quando `super` retorna sem exceção (unknown/blank), o phantom roda; quando levanta `NameError` (known), o código pós-`super` não roda — lógica correta
- [x] Comentário contextual preciso (5 queries known: SELECT email + SELECT colisão + SAVEPOINT/UPDATE/RELEASE — confirmado contra `devise-5.0.4/lib/devise/token_generator.rb` e `models/recoverable.rb`)

### Arquitetura
- [x] `super` do Devise preservado; nenhuma decisão da stack rompida (Devise 5, Rails 8, API-only custom, ActionMailer desmontado)
- [x] Sem vazamento de responsabilidade; correção contida no controller já customizado (padrão do projeto de comentar decisões no próprio código)

### Qualidade
- [x] Teste significativo (trava a invariante que motivou o bug: paridade de queries) e estável
- [x] Sem duplicação; nomes consistentes com o domínio Devise (`enc`, `resource_class`, `_raw`)
- [x] Sem feature creep: 2 arquivos, escopo mínimo

### Segurança
- [x] `where(id: -1)` com literal inteiro fixo — sem input do usuário; **sem SQL injection** (valores via bind em `update_all`)
- [x] Nenhuma exposição nova: o phantom não loga nem grava nada
- [x] Sem risco de token órfão/fantasma válido (nada é persistido)
- [x] Elimina o canal lateral que era o objetivo (paridade 5=5, validado empiricamente pelo r5)

### Conformidade estrutural (structural-conformity-checklist)
- [x] FSM: não há FSM no fluxo recoverable; `update_all` sem callbacks não interage com `status`/máquina de estados
- [x] Transação: `requires_new: true` → SAVEPOINT/RELEASE simétrico ao save do Devise; sem saída antecipada; UPDATE 0 linhas não levanta rollback
- [x] Guards: rota pública de recoverable (sem guard loop); rescue `NameError` específico (`e.name == :Mailer`) preservado e não ampliado
- [x] Exceções: nenhum novo caminho de exceção não tratada introduzido (qualquer erro de DB propagaria — aceitável, indica falha de infraestrutura)

## Ações corretivas

Nenhuma obrigatória (0 blockers). Opcionais: S1 (assert de inocuidade no teste), S2/S3 já registradas como débitos 23.8-Obs1..3 no `iteration_23.md`.

## Referência

- Relatório empírico: `docs/quality/bug_report_23_bug-finder-r5.md`
- Lição registrada: `docs/governance/lessons.md` (phantom work vs sleep)
- Decisão CTO de manter a correção: `docs/progress/iteration_23.md`