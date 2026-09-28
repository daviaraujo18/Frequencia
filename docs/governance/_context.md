# _context.md — governance
> Gerado em: 2026-09-23 | Fontes: AGENTS.md (raiz), lessons.md, _context.md anterior | Palavras: ~360
> Atualizar quando: lição aprendida registrada em lessons.md; mudança nas regras/configurações do AGENTS.md (raiz); ADR registrada; decisão de segurança/stack registrada fora dos ADRs.

## O que esta pasta contém
Diretrizes de governança do AI Workflow aplicadas ao Frequência. As regras canônicas vivem no `AGENTS.md` da raiz (lido por OpenCode/Antigravity); a pasta guarda o registro de **lições aprendidas** não cobertas por iteration/quality/inception/ADRs (não há pasta `rules/` aqui — desvio de estrutura, ver `docs/_context.md`).

## Pontos-chave para agentes
### AGENTS.md (raiz — `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`)
- Identidade: sistema Frequência (migração do módulo Frequência da Intranet), Rails 8.0.4 API-only custom, Devise 5, CanCanCan 3.6, Rolify 6, Pagy 9, AdminLTE 4 + Bootstrap 5.3, importmap (sem Node).
- Configuração: TASK_MODE=STANDARD, COMMIT_MODE=manual, MEMORY_MODE=classic, SUGGESTION_LEVEL=1, BUG_LEVEL=1; hierarquia de leitura e pipeline nas Seções 4/5.
- Chamar o Summarizer após: Brainstorm, ciclo Guardian, mudança estrutural nos docs, tarefa concluída, atualizações do CTO.

### lessons.md (6 lições — 2026-09-10 a 2026-09-23)
- Ambiente real: Ruby **3.4.2 (mise)** e Rails 8.0.5 no lock (docs citam 4.0.0/8.0.4 — defasados); conferir `bundle env` e, no Frequencia, **preferir binstubs `bin/*` a `bundle exec`** (`bundle exec rails`/`ruby -e` falham com `invalid switch in RUBYOPT`).
- Sprint 23 (auth): Rolify `scopify` só cria scopes `global`/`class_scoped`/`instance_scoped`; rota custom para controller Devise exige `devise_scope :user`; coexistência sessão legada × Warden exige `skip_before_action :verify_signed_out_user` no destroy + sync de `session[:user_id]` no create.
- **Nova (2026-09-23, Bug 10):** para timing side-channel em endpoint `paranoid`, iguale a assinatura de I/O com phantom work (SELECT por `reset_password_token` + UPDATE em `id` inexistente = 0 linhas), nunca `sleep` — paridade 5=5 queries validada empiricamente pelo Bug Finder r5.

## Estado atual
- 6 lições registradas (3 auth/Devise/Rolify — Sprint 23; 2 ambiente/binstubs — 23.10/24.1; 1 timing/phantom work — Bug 10).
- Decisão do CTO (2026-09-23): **manter** a correção do Bug 10 (divergência BUG_LEVEL=1 encerrada); lição vinculada a `docs/00-contexto/03-seguranca-stack.md` e aos débitos 23.8-Obs1..4.
- Sem ADR nova nesta sessão; ADRs vivem em `docs/adr/` (0001–0005).
- Estrutura canônica desviada: regras permanecem no AGENTS.md raiz, não em `governance/rules/`.

## Referências para aprofundamento
- Para regras globais, pipeline e configurações → `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`
- Para lições aprendidas → `docs/governance/lessons.md`
- Para RNF de segurança e checklist de canal lateral → `docs/00-contexto/03-seguranca-stack.md`
- Para débitos 23.8/23.8-Obs1..4 e encerramento do bug-hunting → `docs/progress/iteration_23.md`
- Para ADRs → `docs/adr/`