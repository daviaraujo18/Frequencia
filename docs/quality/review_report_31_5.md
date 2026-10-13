# Relatório de Revisão — Task 31.5 (Handler `VINCULAR_DESVINCULAR` + produtor)

- **Revisor:** Code Reviewer (AI Workflow)
- **Data:** 2026-10-13
- **Branch de origem → destino:** `feature/demanda-31-5-vincular-desvincular` (working tree, NÃO commitado) → `develop` (base `e13f782` = HEAD da 31.4)
- **Veredito:** ✅ **Aprovado** — **0 Blockers 🔴 | 2 Sugestões de Melhoria 🟡 | 2 Débitos 🟠 | 5 Elogios 🟢**

## Escopo revisado

| Arquivo | Tipo | Estado |
|---------|------|--------|
| `api-ponto/app/services/vincular_desvincular_handler.rb` | NOVO | untracked (lido direto) |
| `api-ponto/test/services/vincular_desvincular_handler_test.rb` | NOVO | untracked (lido direto) |
| `api-ponto/test/models/regime_frequentador_produtor_test.rb` | NOVO | untracked (lido direto) |
| `api-ponto/app/models/regime_frequentador.rb` | MODIFICADO | + callback produtor `after_commit` |
| `api-ponto/config/initializers/recalculo_handlers.rb` | MODIFICADO | + registro `VINCULAR_DESVINCULAR` |
| `docs/progress/iteration_31.md` | MODIFICADO | bloco da Tarefa 31.5 |

Fora de escopo (lixo de ambiente, ignorados): `config/credentials.yml.enc`, `config/environments/development.rb`, `log/*`, `tmp/cache/*`.

## Evidência executada

| Comando | Resultado |
|---------|-----------|
| `bin/rails test test/services/vincular_desvincular_handler_test.rb test/models/regime_frequentador_produtor_test.rb` | **21 runs, 67 assertions, 0F, 0E, 0 skips** |
| `bin/rails test` (suíte completa) | **1214 runs, 4239 assertions, 3F, 12E, 0 skips** — **bate EXATAMENTE o baseline declarado** (as 3F+12E são pré-existentes: `Users::PasswordsController`/`SessionsController` — `private method redirect_to`; `PessoasSchemaLoaderTest` — guard de nome de DB; `SeedsTest` ×2; `PresencaEndpointsTest` — timezone. Nenhuma toca 31.5) |
| `bin/rails test test/models/regime_frequentador_test.rb test/models/regime_test.rb test/services/calculo_diario_service_test.rb test/services/calculo_diario_service_paridade_test.rb test/services/consolidacao_mensal_service_test.rb test/jobs/calcular_frequencia_job_test.rb test/jobs/executa_tarefas_job_test.rb test/models/tarefa_recalculo_test.rb test/services/registro_recalculo_handler_test.rb` | **139 runs, 315 assertions, 0F, 0E, 0 skips** — **sem regressão** do novo callback nos suites que criam `RegimeFrequentador` |
| `bin/rails zeitwerk:check` | **All is good!** |
| `bin/rubocop` (5 arquivos do diff) | **0 offenses** |

## Verificações do pedido (atenção especial)

1. **Discriminador create/update/destroy em `after_commit` — CORRETO.** Em `after_commit`, `previously_new_record?` é `true` para o create (o flag sobrevive ao commit) e `destroyed?` é `true` no `after_destroy_commit` — por isso o hash `previous_changes` (que vem VAZIO no destroy e CHEIO no create) não pode ser o discriminador, e o código usa o ESTADO, não o hash. O update cai no `previous_changes.key?("momento_inicial") || key?("momento_final")`. Não encontrei create/update legítimo que DEIXE de enfileirar: um create sempre tem `momento_inicial` (validado `presence: true`), então mesmo sem o atalho de estado a chave apareceria; o destroy depende exclusivamente do estado. Também não encontrei enfileiramento SEM motivo: um `touch` (só `updated_at`) não põe `momento_*` no `previous_changes` ⇒ não enfileira. Confirmado empiricamente pelos 9 testes do produtor (create / update-muda / update-não-muda / destroy), todos passando.
2. **Ciclo de vida em massa — ACEITÁVEL, sem N+1 patológico.** `after_commit` roda 1× por linha; cada `enfileirar!` faz **1 SELECT + (1 INSERT ou find)** — custo **O(N)**, não O(N²). A referência estável **evita duplicação REAL** entre eventos do MESMO período pendentes (dedup por `tipo_entidade`+`referencia` entre `pendente`); não "mascara" — depois de drenada, um novo evento do mesmo período cria linha nova (comportamento idempotente pretendido). Para um import em lote de milhares de linhas com períodos DISTINTOS, o volume de tarefas cresce com o nº de períodos distintos — fora de escopo, mas anotado.
3. **Ordem dias-antes-de-consolidar — CORRETA, e a ordem CRONOLÓGICA importa.** `consolidar` do mês M lê `acumulado` do mês M-1 (`buscar_saldo_mes_anterior`, `consolidacao_mensal_service.rb:213`); o `group_by` sobre um `Range#to_a` já ordenado preserva a ordem de inserção do Hash ⇒ M-1 é consolidado antes de M. O `vigente_para(user, data_fim)` em `consolidar:220` encontra um vínculo recém-criado cujo período COBRE o fim do mês (`vigentes_em` usa `>= beginning_of_day`) — e se o vínculo NÃO cobrir `data_fim`, `aplicar_saldo` retorna cedo deixando saldo zerado: comportamento **pré-existente** do `consolidar`, não introduzido aqui.
4. **`PERIODO_ALERTA_DIAS` sem truncar — decisão CERTA; lock é risco baixo.** O requisito proíbe truncar em silêncio; recalcular todos os dias é fiel. O advisory lock `728_104_536` é EXCLUSIVO do `ExecutaTarefasJob` (jobs de importação/`CalcularFrequenciaJob` usam chaves distintas) ⇒ um período de anos segura o lock por segundos/minutos, atrasando apenas OUTRAS instâncias do próprio `ExecutaTarefasJob` (que fariam no-op) — **sem bloqueio cross-job**. Risco aceitável; chunking é débito opcional futuro.
5. **Payload do produtor vs handler — distinção aberto × inválido CORRETA.** Produtor emite ISO (`to_date.iso8601`) e `nil` para período aberto; o handler: `raw_fim.present? && fim.nil?` ⇒ skip (PRESENTE-mas-inválido), senão `fim = parse_data(nil) = nil` ⇒ ABERTO (fim = `Date.current`). Verificado por teste (`final: "fim-invalido"` skip vs `final: :ausente`/`nil` aberto). Ressalva menor em 🟡-S2.
6. **Testes — 21 casos REAIS, não vacuosos.** O teste "falha no enfileiramento (create/update/destroy)" **prova de verdade**: stub que LEVANTA (`->(**) { raise }`) + `assert_nothing_raised` + `assert_difference` de persistência do vínculo + `assert_match` do log. O helper `com_metodos_de_classe_stubados` faz **save/restore real** (`UnboundMethod` capturado e reinstalado no `ensure`, `class_method_stub_helper.rb:59-65`), sem `remove_method`. Os 4 testes com `Date.current` usam ranges RELATIVOS + clamp (robustos a virada de mês), embora ainda dependam do relógio — aceitável.
7. **Correção/segurança no diff:** nenhum input cru, sem SQL interpolado, sem alteração de auth/banco/permissões. Nenhum bug de correção/segurança encontrado.

**Progresso da varredura (Q14):** confirmada — em código de PRODUÇÃO (`app`/`lib`) não há NENHUM escritor de `regime_frequentadores`; as ocorrências são de LEITURA (`calculo_diario_service.rb:40`, `consolidacao_mensal_service.rb:220`) e associações (`regime.rb:63`, `user.rb:21`). Criações só em TESTES. O callback `after_commit` é o único locus de ciclo-de-vida. Veredito: varredura do dev está CORRETA.

## Sugestões de Melhoria (🟡) — opcionais

| ID | Descrição | Arquivo:linha | Bloqueante? |
|----|-----------|---------------|-------------|
| 🟡-S1 | O `rescue ConsolidacaoMensalService::MesFinalizadoError` no nível de `call` é (hoje) **inofensivo mas código morto**: `consolidar` já engole o erro internamente (`consolidar` privado L145-149) e nem `finalizado?` nem `CalculoDiarioService.calcular` levantam essa exceção. Pode induzir o leitor a acreditar que a corrida está tratada além do que está. Considerar comentário explícito ou remoção. | `vincular_desvincular_handler.rb:65-70` | NÃO |
| 🟡-S2 | `momento_final` PRESENTE mas string VAZIA (`""`) ⇒ `raw_fim.present?` é `false` ⇒ tratado como ABERTO (recalcula até `Date.current`) em vez de "inválido/skip". O produtor nunca emite `""`, então é risco baixo — mas um produtor futuro mal-formado recalcaria um intervalo maior em vez de pular. | `vincular_desvincular_handler.rb:62` | NÃO |

## Débitos Técnicos (🟠) — não bloqueantes

| ID | Descrição | Arquivo:linha | Impacto | Bloqueante? |
|----|-----------|---------------|---------|-------------|
| 🟠-D1 | **Encerrar/encolher o período não recalcula a "cauda".** Quando um vínculo ABERTO é encerrado (ou tem `momento_final` reduzido), o handler recalcula apenas `[inicio, novo_fim]`. Os dias APÓS o novo `momento_final`, que antes estavam cobertos pelo período aberto (e foram calculados COM esse regime), NÃO são recalculados ⇒ `CalculoDiario` remanescente pode ficar stale. Fiel ao literal "recalcula os dias do período" (Q14 travado; o "período" é o pós-imagem), mas é limitação real do caso "desvincular/encerrar". | `vincular_desvincular_handler.rb:76-85`; `regime_frequentador.rb:113-123` | Dados potencialmente desatualizados na cauda após encerramento com fim no passado. **Herdado da semântica escolhida em Q14** — não é regressão; recomenda-se registrar como pergunta/débito de follow-up (recalcular também a cauda até `Date.current` no caso de encerramento). | NÃO |
| 🟠-D2 | **TOCTOU residual do mês finalizado** (mesmo débito herdado da 31.3): o guard `finalizado?` é por mês ANTES de recalcular os dias; se OUTRO processo finalizar o mês entre o guard e o `consolidar`, o dia pode ter sido reescrito (o `rescue MesFinalizadoError` só evita a PROPAGAÇÃO, não a reescrita). Probabilidade desprezível (finalização é manual); já documentado no código como débito conhecido. | `vincular_desvincular_handler.rb:127-137,145-152` | Janela ínfima; sem ação nesta task. | NÃO |

## Elogios (🟢)

| ID | Elogio | Relacionado |
|----|--------|-------------|
| 🟢-E1 | `after_commit` fica FORA da transação que persiste o vínculo (diferente da 31.3, que enfileirava DENTRO): um rollback não deixa tarefa órfã; e o `enfileirar_recalculo` inteiro é protegido por `rescue StandardError` + log, garantindo que uma falha de enfileiramento NUNCA derrube o `create`/`update`/`destroy` — provado por teste nos 3 verbos. | `regime_frequentador.rb:40,104-129` |
| 🟢-E2 | Referência ESTÁVEL por `user_id` + DATAS do período (`...to_date.iso8601`): dedup REAL por pendente, insensível a hora/minuto (o recálculo é por dia) — teste prova "2 eventos do mesmo período = 1 pendente". | `regime_frequentador.rb:113` |
| 🟢-E3 | Ordem cronológica por `(ano,mês)` preservada via ordem de inserção do Hash, com consolidação DEPOIS dos dias do mês — necessário porque o `acumulado` do mês M depende do mês M-1. | `vincular_desvincular_handler.rb:105-107` |
| 🟢-E4 | Grão de isolamento de erro bem calibrado: POR DIA no recálculo e POR MÊS na consolidação (com log em cada nível), sem derrubar o período inteiro. | `vincular_desvincular_handler.rb:135-152` |
| 🟢-E5 | 21 testes não-vacuosos, incluindo o caso crítico de robustez (stub que levanta + assert de persistência + assert de log) e uso correto do helper save/restore (sem `remove_method`, lição da Sprint 29). | `vincular_desvincular_handler_test.rb`; `regime_frequentador_produtor_test.rb` |

## Ações corretivas

- Nenhuma ação corretiva obrigatória. **0 Blockers 🔴** — a entrega está tecnicamente aprovada para commit.
- Opcionais (não bloqueiam): (a) resolver 🟡-S1 (comentar/remover o `rescue` morto no nível de `call`); (b) ajustar 🟡-S2 (tratar `""` como inválido, se desejado); (c) registrar 🟠-D1 como pergunta/débito de follow-up (recalcular a cauda no encerramento); (d) 🟠-D2 já está documentado no código.

## Certificação de entrega

Entrega técnica **APROVADA** (0 Blockers). Próximo passo: o **Code Specialist** deve realizar o agrupamento de commits atômicos e executar o protocolo de entrega; o fechamento da rastreabilidade é pré-requisito para a próxima tarefa.
