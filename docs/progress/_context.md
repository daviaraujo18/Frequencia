# _context.md — progress
> Gerado em: 2026-09-25 | Fontes: iteration_23.md, iteration_24.md, iteration_26.md, iteration_29.md, adr/0006-schema-teste-espelho-pessoas.md | Palavras: ~680
> Atualizar quando: nova iteration criada; status de tarefa alterado; correções de review registradas; sprint concluída.

## O que esta pasta contém
Acompanha as sprints do Frequência, com um `iteration_N.md` por sprint. A Sprint 23 foi encerrada, a Sprint 24 foi concluída, a Sprint 26 está consolidada e aguarda revisão, e a Sprint 29 é a sprint ativa de autorização/cascata de frequência; a Tarefa 29.1 foi aprovada por Code Reviewer e Bug Finder e aguarda commit manual.

## Pontos-chave para agentes
### iteration_23.md
- Sprint Devise + CanCanCan + Rolify concluída; o ciclo de bug-hunting do `POST /u/password` foi encerrado.
- A correção de timing side-channel foi mantida pelo CTO, com paridade 5=5 queries e sem mutação de dados.
- Débitos e gatilhos de reabertura do ActionMailer permanecem registrados na própria iteration.

### iteration_24.md
- Sprint basic8 concluída: `zutils`, `simple_form`, `ransack` e `pagy` foram integrados sem alteração de banco ou autenticação.
- `kaminari` foi preservado; `ransackable_*` permanece fora do escopo desta sprint.

### iteration_26.md
- As tarefas 26.1–26.10 foram consolidadas no commit `1a73a4d`, com estilo basic8 e assets/build.
- A validação consolidada foi registrada como pendente de Code Reviewer/Bug Finder e verificação visual manual.

### iteration_29.md
- A Tarefa 29.1 expõe no espelho Pessoas os três gestores, `#gestor?`, `#cadeia_ascendente` e `Pessoas::Pessoa.por_user`, preservando `PessoasRecord#readonly?` e sem nova gem.
- Os achados HIGH-1/HIGH-2/LOW-1 foram fechados por mutation testing: path de ancestry com auto-referência é rejeitado sem consulta, `foreign_key`/`active_record_primary_key` das três associations e igualdade de gestores.
- Tarefa 29.0 (ADR-0006, ✅ implementada, aguardando Code Reviewer) (ADR-0006): schema mínimo do Pessoas2 carregado no `frequencia_pessoas_espelho_test` por rake com guardas; pré-requisito da 29.4 e da 29.6 (testes de SQL, propriedade e contagem de queries não podem depender só de stubs). O banco de teste do espelho foi renomeado de `pessoas_test` (colidia com o banco de teste do Pessoas2) para `frequencia_pessoas_espelho_test`. Setup por máquina/CI: `createdb -O app.frequencia frequencia_pessoas_espelho_test` e depois `RAILS_ENV=test bin/rails test:pessoas_schema:load`. Helpers em `test/support/pessoas_espelho_helper.rb`.
- Regra D6 (29.4): cadeia sobe inteira; unidade inativa/extinta não libera acesso pelos seus gestores; ancestral ausente é pulado com log; path corrompido segue fail-closed (inclui Bugs 1/2 do Bug Finder).
- As tarefas 29.2–29.8 permanecem pendentes; D1–D4 continuam decisões bloqueantes para migration e autorização.

## Estado atual
- Sprint 29 ativa; Tarefa 29.1 ✅ aprovada (Review 0 blockers; Bug Finder 0 crítico/alto/médio), liberada para commit manual com stage seletivo (nunca `git add -A`; logs e `tmp/cache` rastreados não entram).
- Merge da 23.7 (CanCanCan nos controllers) segue pendente: é pré-condição da 29.7, que altera a `Ability`.
- Testes direcionados: 13 runs / 53 assertions / 0 failures; suíte completa: 793 runs / 2886 assertions / 1 falha baseline de timezone em `presenca_endpoints_test.rb:187`, não atribuída à 29.1.
- RuboCop dos quatro arquivos alterados: 0 offenses; RuboCop completo: 60 offenses preexistentes; Zeitwerk e `bundle check` OK.
- **Brakeman:** `bin/brakeman` NÃO executa scan (binstub força `--ensure-latest` com gem defasada) — não registrar "Brakeman OK" com base nele. Scan real (`RUBYOPT= bundle exec brakeman`): 4 warnings pré-existentes, 0 na 29.1. Correção do gate fica em chore agile de pipeline.
- Branch `feature/demanda-29-correcoes-review`; nenhuma alteração de banco, autenticação ou autorização foi feita; 29.2/29.4/29.7 dependem das decisões D1–D4.

## Referências para aprofundamento
- Para a Tarefa 29.1, critérios, achados e validações → `docs/progress/iteration_29.md`
- Para a estratégia de schema de teste do espelho → `docs/adr/0006-schema-teste-espelho-pessoas.md`
- Para o estado da Sprint 26 → `docs/progress/iteration_26.md`
- Para o ciclo Devise/Rolify e débitos de segurança → `docs/progress/iteration_23.md`
- Para as gems e wiring da Sprint 24 → `docs/progress/iteration_24.md`
- Para as lições operacionais → `docs/governance/lessons.md`
- Para as regras e configurações → `/home/davi.queiroz/Área de trabalho/workspace_integração/AGENTS.md`
