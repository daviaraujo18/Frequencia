# _context.md — governance
> Gerado em: 2026-10-05 | Fontes: docs/governance/lessons.md, docs/adr/ (0000–0010), AGENTS.md (raiz), docs/progress/iteration_29_closure.md, iteration_chore_bump_rails_81.md | Palavras: ~760
> Atualizar quando: lição registrada em lessons.md; ADR nova; mudança nas regras/configurações do AGENTS.md (raiz); mudança do ambiente medido (Ruby/Rails).

## O que esta pasta contém
Diretrizes de governança do AI Workflow aplicadas ao Frequência. As regras canônicas vivem no `AGENTS.md` da raiz (lido por OpenCode/Antigravity); a pasta guarda o registro de **lições aprendidas** não cobertas por iteration/quality/ADRs (não há pasta `rules/` aqui — desvio de estrutura, ver `docs/_context.md`). Os ADRs vivem em `docs/adr/` (fora desta pasta, mas catalogados aqui).

## Pontos-chave para agentes
### lessons.md (37 lições — 2026-09-10 a 2026-10-05)
- **Ambiente real medido (2026-10-05):** Ruby **3.3.8** (`cat api-ponto/.ruby-version`) e Rails **8.1.4** (`Gemfile.lock`); no Frequencia, preferir binstubs `bin/*` a `bundle exec` (`bundle exec rails` falha com `invalid switch in RUBYOPT`).
- Lições de auth (Sprint 23): Rolify `scopify` só cria scopes `global`/`class_scoped`/`instance_scoped`; rota custom Devise exige `devise_scope :user`; coexistência sessão legada × Warden exige `skip_before_action :verify_signed_out_user`. Timing side-channel: phantom work, nunca `sleep`.
- Lições da Sprint 29 (a maioria): `uniqueness` com `conditions:` valida o registro NOVO por inteiro e **não espelha índice UNIQUE parcial**; validação de invariante deve rodar **no evento** (`will_save_change_to_X?`); os **dois lados** de invariante cruzando tabelas devem concordar sobre os **4 quadrantes de `ativo`**; callback de validação **nunca** deve chamar `reload` na instância do chamador. Stubs: `remove_method` mata **método real** (de produção e scope ORM) para o PROCESSO inteiro — só método HERDADO é seguro.
- Lições de CI (chore do fork, 2026-09-29/30): gate vermelho em stage anterior impede o seguinte (fail-fast GitLab); `localhost` **não** alcança `services:` no executor docker (resolvem por **alias**); só `.gitlab-ci.yml` na **raiz** do monorepo é lido; saída com precedência interna pode **mascarar** a checagem (Brakeman: exit 3 esconde 8/9).
- **Lição nova (2026-10-05, bump):** Brakeman SQL — `Arel.sql` **NÃO** silencia; `sanitize_sql_array` SIM (Weak→Medium pela interpolação) — vetor do achado `frequentadores_visiveis.rb:351`.

### ADRs (`docs/adr/` — 0000 a 0010; índice `docs/README.md` = `0000`–`0010`)
- 0001 integração Pessoas↔Frequência · 0002 estratégia de migração · 0003 compatibilidade EstaçãoPonto · 0004 spec-driven integração · 0005 destino PoC api-ponto · 0006 schema de teste do espelho Pessoas · 0007 soft-delete do vínculo de gestão individual · 0008 semântica de `ativo` do gestor (projeção: `true` sse ≥1 vínculo ativo; origem D1..D4 da 29.3).
- **ADR-0009 (2026-10-05):** versão-alvo da **toolchain** + lockstep das 3 fontes + política do ledger Brakeman. Fixa **Ruby 3.3.8** (o medido; Ruby major 3.4/4.0 = chore própria) e **Rails 8.1.x (alvo 8.1.4)**; as 3 fontes (`.ruby-version`/`.tool-versions`/`AGENTS.md`) passam a concordar; `load_defaults` **permanece 8.0**; ledger é **registro de aceitação** — `Medium`+ e EOL **nunca** cobertos (tratados estruturalmente). **Fecha a "dívida de versão do Ruby".**
- **ADR-0010 (2026-10-05):** arquitetura da **cascata de autorização** — dual-implementação canônica PORO (`AutorizacaoFrequencia`, fonte da verdade/decisão+auditoria) × SQL twin (`FrequentadoresVisiveis`, só listagem), **sem JOIN cross-database** (passos 1/4 em Ruby → `IN (cpfs/ids)`; passos 3/5 em SQL puro). Flag `FREQUENCIA_AUTORIZACAO_CASCATA` de **3 estados** (`:off` default / `:shadow` só loga / `:on` restringe). D5 (**ver ≠ desconsiderar**: gate de desconsiderar usa **só** o passo 5). Débito **🟡S2** eleva-se a regra de conformidade (prova nos DOIS corpos).

### AGENTS.md (raiz — `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`)
- Identidade: sistema Frequência, Rails 8 API-only custom, Devise 5, CanCanCan 3.6, Rolify 6, Pagy 9, AdminLTE 4 + Bootstrap 5.3, importmap (sem Node).
- Configuração: TASK_MODE=STANDARD, COMMIT_MODE=manual, MEMORY_MODE=classic, SUGGESTION_LEVEL=1, BUG_LEVEL=1.
- ✅ **DOCS_PATH (dívida D4) — CORRIGIDA em 2026-09-30:** apontava para `workspace_integracao/docs/` (árvore paralela defasada, não versionada); repontado para `Frequencia/docs/` e taxonomia da Seção 4 corrigida. **Processar sempre `Frequencia/docs/`.** Neutralização física da árvore morta fica **pendente de aprovação do dev**.

## Estado atual
- **37 lições registradas** (medido: `grep -cE "^### [0-9]{4}-[0-9]{2}-[0-9]{2}" docs/governance/lessons.md` = 37). **Reconciliação da contagem:** o "27" era stale (correto em 2026-09-30); a closure da 29 e a ADR-0009 apontavam **36**; a lição de **2026-10-05** (Brakeman `sanitize_sql_array`, chore do bump) = **+1 → 37**.
- **ADRs 0000–0010** (era "0000–0008"); índice `docs/README.md` já atualizado para `0000`–`0010`.
- **Dívida de versão do Ruby — FECHADA pela ADR-0009 (2026-10-05).** Era "dívida aberta (dono pendente)" com três fontes conflitantes; a ADR-0009 fixou **Ruby 3.3.8 / Rails 8.1.x** e o **lockstep** das 3 fontes. **Medido 2026-10-05: Ruby 3.3.8 / Rails 8.1.4** (fonte `Gemfile.lock`; medida em `iteration_chore_bump_rails_81.md`). O `.ruby-version` mentiroso (`ruby-4.0.0`, inexistente) suprimia o check `EOLRuby` do Brakeman; corrigido. Ruby major 3.4/4.0 fica como **chore futura** (dívida declarada, não escondida).
- Ledger Brakeman: `Medium`+ não é ignorável; o achado `SQL Injection` de `frequentadores_visiveis.rb:351` foi **corrigido no código** (bind + `sanitize_sql_array`, opção b1) — `bin/brakeman` = EXIT 0, ledger 3 entradas, 0 obsoletas.

## Referências para aprofundamento
- Lições aprendidas → `docs/governance/lessons.md`
- Regras globais, pipeline e configurações → `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`
- Decisões arquiteturais → `docs/adr/` (em especial `0009-estrategia-versao-toolchain-ruby-rails.md` e `0010-arquitetura-cascata-autorizacao-frequencia.md`)
- Ambiente real (versões) e bump → `docs/progress/iteration_chore_bump_rails_81.md`
- Fechamento da Sprint 29 → `docs/progress/iteration_29_closure.md`
