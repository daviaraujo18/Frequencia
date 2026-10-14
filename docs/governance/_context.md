# _context.md — governance
> Gerado em: 2026-10-14 | Fontes: docs/governance/lessons.md, docs/adr/ (0000–0011), AGENTS.md (raiz), docs/progress/iteration_31.md, iteration_32.md (§Encerramento), iteration_29_closure.md, iteration_chore_bump_rails_81.md | Palavras: ~780
> Atualizar quando: lição registrada em lessons.md; ADR nova; mudança nas regras/configurações do AGENTS.md (raiz); mudança do ambiente medido (Ruby/Rails).

## O que esta pasta contém
Diretrizes de governança do AI Workflow aplicadas ao Frequência. As regras canônicas vivem no `AGENTS.md` da raiz (lido por OpenCode/Antigravity); a pasta guarda o registro de **lições aprendidas** não cobertas por iteration/quality/ADRs (não há pasta `rules/` aqui — desvio de estrutura). Hoje contém **apenas `lessons.md`** e este `_context.md`. Os ADRs vivem em `docs/adr/` (catalogados aqui).

## Pontos-chave para agentes
### lessons.md (42 lições — 2026-09-10 a 2026-10-13)
- **Ambiente real medido (2026-10-13):** Ruby **3.3.8** (`cat api-ponto/.ruby-version`) e Rails **8.1.4** (`Gemfile.lock`); no Frequencia, preferir binstubs `bin/*` a `bundle exec` (`bundle exec rails` falha com `invalid switch in RUBYOPT`).
- **Lições por tema:** auth (Sprint 23: Rolify `scopify` só cria scopes `global`/`class_scoped`/`instance_scoped`; rota custom Devise exige `devise_scope`; timing side-channel — phantom work, nunca `sleep`); Sprint 29 (a maioria): invariantes validados **no evento**, os **4 quadrantes de `ativo`**, callback nunca chama `reload`; stubs `remove_method` matam método **real** — só HERDADO é seguro. CI: fail-fast; `localhost` não alcança `services:` (usar **alias**); só `.gitlab-ci.yml` na **raiz**; precedência interna mascara checagem (Brakeman exit 3).
- **Lições novas (2026-10-13, Sprint 31):** `RecordNotUnique` **dentro** da transação do chamador aborta a transação → isolar o `INSERT` num **SAVEPOINT**; reusar advisory lock **ÚNICO** dentro de job que já segura lock ⇒ tarefa "drenada sem efeito" **silenciosa**; guarda de "estado finalizado" só protege se aplicada **ANTES de toda escrita**. **A Sprint 32 NÃO registrou lição nova** — o hardening (32.1/32.2) é **aplicação** da lição de 2026-10-13 + ADR-0011 regra 4.

### ADRs (`docs/adr/` — 0000 a 0011; índice `docs/README.md` = `0000`–`0011`)
- 0001 integração Pessoas↔Frequência · 0002 estratégia de migração · 0003 compatibilidade EstaçãoPonto · 0004 spec-driven integração · 0005 destino PoC api-ponto · 0006 schema de teste do espelho Pessoas · 0007 soft-delete do vínculo de gestão individual · 0008 semântica de `ativo` do gestor.
- **ADR-0009 (2026-10-05):** versão-alvo da **toolchain** + lockstep das 3 fontes + política do ledger Brakeman. Fixa **Ruby 3.3.8** e **Rails 8.1.x (alvo 8.1.4)**; `load_defaults` **permanece 8.0**. Fecha a "dívida de versão do Ruby".
- **ADR-0010 (2026-10-05; emenda 2026-10-08):** cascata de autorização — dual-implementação canônica PORO × SQL twin, **sem JOIN cross-database**; flag `FREQUENCIA_AUTORIZACAO_CASCATA` (`:off` default). D5 (**ver ≠ desconsiderar**). **Regra 9:** enforcement **opt-in por controller** = causa-raiz do Bug 🔴1 da 30 (candidato **32.O1**).
- **ADR-0011 (2026-10-13):** mecanismo de **recálculo por evento** (PRD §5.2) — fila `TarefaRecalculo` idempotente × job `ExecutaTarefasJob` (advisory lock próprio `728_104_536`) × registry de handlers. **Regra 4:** trava de mês finalizado (17.2) vale para o recálculo **inclusive para o DIA**; **§Consequências prescrevia** o tratamento do **D2/17.5** (guard por dia no job; handler espelha). **Nota datada (2026-10-14):** **D2/17.5 RESOLVIDO** pelos espelhos 32.1 (`fe7f8ff`)/32.2 (`905d8fb`) — **nenhuma ADR nova**.

### AGENTS.md (raiz — `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`)
- Identidade: sistema Frequência, Rails 8 API-only custom, Devise 5, CanCanCan 3.6, Rolify 6, Pagy 9, AdminLTE 4 + Bootstrap 5.3, importmap (sem Node).
- Configuração: TASK_MODE=STANDARD, COMMIT_MODE=manual, MEMORY_MODE=classic, SUGGESTION_LEVEL=1, BUG_LEVEL=1.
- ✅ **DOCS_PATH (dívida D4) — CORRIGIDA em 2026-09-30:** apontava para `workspace_integracao/docs/` (árvore paralela defasada); repontado para `Frequencia/docs/`. **Processar sempre `Frequencia/docs/`.**

## Estado atual
- **42 lições registradas** (medido: `grep -cE "^### [0-9]{4}-[0-9]{2}-[0-9]{2}" docs/governance/lessons.md` = **42**; período 2026-09-10 a 2026-10-13). **A Sprint 32 NÃO adicionou lição** (0 novas).
- **ADRs 0000–0011** — a **Sprint 32 não criou ADR nova**; apenas anexou uma **nota datada** à ADR-0011 registrando o fechamento do **D2/17.5** (feito pelos espelhos 32.1/32.2), **nos dois espelhos** (job `CalcularFrequenciaJob` + handler `RecalcularTodosHandler`).
- **Dívida de versão do Ruby — FECHADA pela ADR-0009.** Medido 2026-10-13: **Ruby 3.3.8 / Rails 8.1.4**. Ruby major 3.4/4.0 fica como **chore futura**.
- **Sprint 32 encerrada (CTO, 2026-10-14):** **D2/17.5 fechado nos dois espelhos**; **32.3** é pendência **OPERACIONAL STANDALONE** (deploy da migration `create_tarefas_recalculo`, bloqueio de **rede**/infra; cron `executa_tarefas` **desligado**); **32.4** = governança de docs (ponteiro do `CLAUDE.md` do workspace **escopado por projeto**; arquivo **fora** do repo, sem commit). **Sprint 33 EM ABERTO por falta de ruling do dev** (candidato `32.O1` — enforcement opt-in da cascata, ADR-0010 regra 9, ~5 pts, toca autorização).
- **Nuance do TOCTOU memoizado NÃO foi promovida a lição:** a memoização por `[ano, mes]` (local ao usuário) torna a janela de corrida "grudenta" *por usuário* em vez de *por consulta* — impacto desprezível (finalização manual). Justificativa: é **micro-otimização já capturada** nos relatórios de qualidade (`bug_report_32_…` Bug 1, `review_report_32_2` ⚪ O2) e coberta pela **classe** do débito TOCTOU (ADR-0011 regra 4); promovê-la seria **duplicação sem ganho**.
- Ledger Brakeman: `Medium`+ não é ignorável; o achado `SQL Injection` de `frequentadores_visiveis.rb:351` foi **corrigido** (bind + `sanitize_sql_array`) — `bin/brakeman` = EXIT 0, ledger 3 entradas.

## Referências para aprofundamento
- Lições aprendidas → `docs/governance/lessons.md`
- Regras globais, pipeline e configurações → `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`
- Decisões arquiteturais → `docs/adr/` (em especial `0009`, `0010` e `0011`)
- Encerramento das Sprints 31/32 → `docs/progress/iteration_31.md` e `iteration_32.md` · Fechamento da 29 → `docs/progress/iteration_29_closure.md` · Bump/versões → `docs/progress/iteration_chore_bump_rails_81.md`
