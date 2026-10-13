# _context.md — governance
> Gerado em: 2026-10-13 | Fontes: docs/governance/lessons.md, docs/adr/ (0000–0011), AGENTS.md (raiz), docs/progress/iteration_31.md, iteration_29_closure.md, iteration_chore_bump_rails_81.md | Palavras: ~780
> Atualizar quando: lição registrada em lessons.md; ADR nova; mudança nas regras/configurações do AGENTS.md (raiz); mudança do ambiente medido (Ruby/Rails).

## O que esta pasta contém
Diretrizes de governança do AI Workflow aplicadas ao Frequência. As regras canônicas vivem no `AGENTS.md` da raiz (lido por OpenCode/Antigravity); a pasta guarda o registro de **lições aprendidas** não cobertas por iteration/quality/ADRs (não há pasta `rules/` aqui — desvio de estrutura, ver `docs/_context.md`). Hoje a pasta contém **apenas `lessons.md`** e este `_context.md`. Os ADRs vivem em `docs/adr/` (fora desta pasta, mas catalogados aqui).

## Pontos-chave para agentes
### lessons.md (42 lições — 2026-09-10 a 2026-10-13)
- **Ambiente real medido (2026-10-13):** Ruby **3.3.8** (`cat api-ponto/.ruby-version`) e Rails **8.1.4** (`Gemfile.lock`); no Frequencia, preferir binstubs `bin/*` a `bundle exec` (`bundle exec rails` falha com `invalid switch in RUBYOPT`).
- Lições de auth (Sprint 23): Rolify `scopify` só cria scopes `global`/`class_scoped`/`instance_scoped`; rota custom Devise exige `devise_scope :user`; coexistência sessão legada × Warden exige `skip_before_action :verify_signed_out_user`. Timing side-channel: phantom work, nunca `sleep`.
- Lições da Sprint 29 (a maioria): `uniqueness` com `conditions:` valida o registro NOVO por inteiro e **não espelha índice UNIQUE parcial**; validação de invariante deve rodar **no evento** (`will_save_change_to_X?`); os **dois lados** de invariante cruzando tabelas devem concordar sobre os **4 quadrantes de `ativo`**; callback de validação **nunca** deve chamar `reload` na instância do chamador. Stubs: `remove_method` mata **método real** (de produção e scope ORM) para o PROCESSO inteiro — só método HERDADO é seguro.
- Lições de CI (chore do fork, 2026-09-29/30): gate vermelho em stage anterior impede o seguinte (fail-fast GitLab); `localhost` **não** alcança `services:` no executor docker (resolvem por **alias**); só `.gitlab-ci.yml` na **raiz** do monorepo é lido; saída com precedência interna pode **mascarar** a checagem (Brakeman: exit 3 esconde 8/9).
- Lição (2026-10-05, bump): Brakeman SQL — `Arel.sql` **NÃO** silencia; `sanitize_sql_array` SIM (Weak→Medium pela interpolação) — vetor do achado `frequentadores_visiveis.rb:351`. CanCanCan: `can` com bloco que devolve `false` **cai** no `manage :all` (fall-through) — mute o default com `cannot`.
- **Lições novas (2026-10-13, Sprint 31):** `RecordNotUnique` **dentro** da transação do chamador aborta a transação inteira → isolar o `INSERT` num **SAVEPOINT** (`transaction(requires_new: true)`, `rescue` fora do bloco); reusar um **advisory lock ÚNICO** dentro de um job que já segura lock ⇒ tarefa "drenada sem efeito" **silenciosa** (o `pg_try_advisory_lock` retorna `false` e o handler sai); guarda de "estado finalizado" só protege se aplicada **ANTES de toda escrita** (o `save!` de outro caminho pula a trava que "levanta erro" no fim).

### ADRs (`docs/adr/` — 0000 a 0011; índice `docs/README.md` = `0000`–`0011`)
- 0001 integração Pessoas↔Frequência · 0002 estratégia de migração · 0003 compatibilidade EstaçãoPonto · 0004 spec-driven integração · 0005 destino PoC api-ponto · 0006 schema de teste do espelho Pessoas · 0007 soft-delete do vínculo de gestão individual · 0008 semântica de `ativo` do gestor (projeção: `true` sse ≥1 vínculo ativo; origem D1..D4 da 29.3).
- **ADR-0009 (2026-10-05):** versão-alvo da **toolchain** + lockstep das 3 fontes + política do ledger Brakeman. Fixa **Ruby 3.3.8** (Ruby major 3.4/4.0 = chore própria) e **Rails 8.1.x (alvo 8.1.4)**; as 3 fontes (`.ruby-version`/`.tool-versions`/`AGENTS.md`) passam a concordar; `load_defaults` **permanece 8.0**; ledger é **registro de aceitação** — `Medium`+ e EOL **nunca** cobertos. **Fecha a "dívida de versão do Ruby".**
- **ADR-0010 (2026-10-05; emenda 2026-10-08):** arquitetura da **cascata de autorização** — dual-implementação canônica PORO (`AutorizacaoFrequencia`) × SQL twin (`FrequentadoresVisiveis`), **sem JOIN cross-database**. Flag `FREQUENCIA_AUTORIZACAO_CASCATA` de **3 estados** (`:off` default / `:shadow` só loga / `:on` restringe). D5 (**ver ≠ desconsiderar**). **Regra 9 (emenda):** "ONDE restringir" é **opt-in por controller** — `authorize! :read, :all` **não** basta (enforcement opt-in = causa-raiz do Bug 🔴1 da 30).
- **ADR-0011 (2026-10-13):** mecanismo de **recálculo por evento** (PRD §5.2, gap §9 #3) — **fila persistente** `TarefaRecalculo` + `enfileirar!` idempotente (índice UNIQUE **parcial**) × job **`ExecutaTarefasJob`** (cron `*/5`, advisory lock próprio `728_104_536`) × **registry de handlers** por `tipo_entidade` (initializer `to_prepare`). Consolida as 7 decisões da Sprint 31: lock próprio (nunca herdado), contrato de produtores **dentro × fora da transação** (caso a caso), trava de mês finalizado (17.2) e proibição de dia futuro aplicadas ao recálculo, **Q14** (`RegimeFrequentador` emite `VINCULAR_DESVINCULAR` via `after_commit`), tipos **adiados** (`FERIADO`/`DIAEXCEPCIONAL`/`DIREITO`).

### AGENTS.md (raiz — `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`)
- Identidade: sistema Frequência, Rails 8 API-only custom, Devise 5, CanCanCan 3.6, Rolify 6, Pagy 9, AdminLTE 4 + Bootstrap 5.3, importmap (sem Node).
- Configuração: TASK_MODE=STANDARD, COMMIT_MODE=manual, MEMORY_MODE=classic, SUGGESTION_LEVEL=1, BUG_LEVEL=1.
- ✅ **DOCS_PATH (dívida D4) — CORRIGIDA em 2026-09-30:** apontava para `workspace_integracao/docs/` (árvore paralela defasada, não versionada); repontado para `Frequencia/docs/`. **Processar sempre `Frequencia/docs/`.** Neutralização física da árvore morta fica **pendente de aprovação do dev**.

## Estado atual
- **42 lições registradas** (medido: `grep -cE "^### [0-9]{4}-[0-9]{2}-[0-9]{2}" docs/governance/lessons.md` = **42**; período 2026-09-10 a 2026-10-13). **Reconciliação:** o "37" deste arquivo (stale, gerado em 2026-10-05) já omitia a 2ª lição daquele dia (CanCanCan `false`→`manage :all`); +1 (2026-10-06, `vendor/bundle` com ruby do sistema) +3 (2026-10-13, SAVEPOINT/lock herdado/guarda de escrita) ⇒ **42**.
- **ADRs 0000–0011** (era "0000–0010"); índice `docs/README.md` já atualizado para `0000`–`0011`.
- **Dívida de versão do Ruby — FECHADA pela ADR-0009 (2026-10-05).** Medido 2026-10-13: **Ruby 3.3.8 / Rails 8.1.4**. Ruby major 3.4/4.0 fica como **chore futura** (dívida declarada).
- **Sprint 31 encerrada (CTO, 2026-10-13):** mecanismo §5.2 (fila + despacho + 3 handlers) **existe no app**; consolidação durável = **ADR-0011**. Status/commits/baseline em `docs/progress/_context.md` e `docs/progress/iteration_31.md`.
- Ledger Brakeman: `Medium`+ não é ignorável; o achado `SQL Injection` de `frequentadores_visiveis.rb:351` foi **corrigido no código** (bind + `sanitize_sql_array`) — `bin/brakeman` = EXIT 0, ledger 3 entradas, 0 obsoletas.

## Referências para aprofundamento
- Lições aprendidas → `docs/governance/lessons.md`
- Regras globais, pipeline e configurações → `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`
- Decisões arquiteturais → `docs/adr/` (em especial `0009-estrategia-versao-toolchain-ruby-rails.md`, `0010-arquitetura-cascata-autorizacao-frequencia.md` e `0011-mecanismo-recalculo-por-evento.md`)
- Ambiente real (versões) e bump → `docs/progress/iteration_chore_bump_rails_81.md`
- Fechamento da Sprint 29 → `docs/progress/iteration_29_closure.md` · Encerramento da Sprint 31 → `docs/progress/iteration_31.md`
