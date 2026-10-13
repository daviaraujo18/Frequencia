# ADR-0011: Mecanismo de recálculo por evento — fila persistente, registry de handlers e contrato de produtores

> **[⌂ Home](../README.md)**

## Status

Aceito (CTO, 2026-10-13). Consolida em decisão durável o que a **Sprint 31** entregou (PRD §5.2, gap §9
#3) e que, sem esta ADR, viveria apenas dentro de `docs/progress/iteration_31.md` (registro primário).
Origem direta: escolha do dev (**opção 3 = PRD §5.2**); commits `b417fef`/`1fa033e` (31.1), `97095bc`
(31.2), `b50e425` (31.3), `e13f782` (31.4), `dae631f` (31.5); reviews `docs/quality/review_report_31_2..31_5.md`
(**0 blockers** em todas). Cobre **também** a decisão de domínio **Q14** (regra 6). **Não** reabre a
filosofia do `CalcularFrequenciaJob` (17.5) — apenas a **referencia** (débito D2/17.5).

## Contexto

- **O mecanismo que faltava.** O PRD §5.2 (`PRD-REGRAS-NEGOCIO-PRESENCA.md` L139-148) descreve o
  **"trigger" real de recálculo em lote por evento** do legado (tabela `presenca_historicotarefa` +
  job `ExecutaTarefas` a cada 5min que despacha por `TipoEntidade`) e crava: *"sem equivalente
  conhecido no Frequencia"* (§9 gap #3). Antes da Sprint 31, o app só tinha recálculo **síncrono no
  request** (marcação manual) e os **jobs noturnos** (`CalcularFrequenciaJob`, 17.5) — não havia
  recálculo **assíncrono dirigido por evento**.

- **Os 7 `TipoEntidade` do PRD, e quantos têm domínio aqui.** `FERIADO`, `DIAEXCEPCIONAL` e `DIREITO`
  **não têm model no Frequência** (brief da 30.3, §9.3); `VINCULAR_DESVINCULAR` tem o vínculo de
  período (`RegimeFrequentador`); `REGISTRO_FREQUENCIA`/`REGISTRO_ESTACAO` têm `TimeRecord`/
  `RegistroEstacaoPonto`; `RECALCULAR_TODOS` tem `User` + `Pessoas::Vinculo.ativos`.

- **Política incremental vigente (ruling do dev 30.3 = A, emendado 2026-10-07).** Cada tipo/role nasce
  na **tarefa que implementa a seção do PRD que o consome** — não se inventam models adiantados.

- **Tensão com o doc de domínio existente.** `docs/03-dominio/05-eventos-dominio.md` **propõe** modelar
  a fila como **eventos de domínio** ("não como tabela de tarefas genérica"). A implementação adotou o
  caminho **pragmático e fiel ao legado**: tabela de tarefas + `tipo_entidade` (ver Alternativa B).

- **Restrições reais do app.** O despacho precisa ser **concorrente-seguro** (workers do Sidekiq) e o
  pipeline de recálculo é **idempotente** (`CalculoDiarioService#calcular`/`ConsolidacaoMensalService#consolidar`
  usam `find_or_initialize_by`); o Postgres é o banco (advisory locks + `jsonb` já no schema).

- **A trava de mês finalizado (17.2) e a proibição de dia futuro são regras de negócio** que o
  recálculo por evento **não pode burlar** — descobertas na correção A/B da 31.3.

## Alternativas Consideradas

### Alternativa A — Fila persistente de tarefas + registry de handlers por `tipo_entidade` (ADOTADA)
- **Descrição:** tabela `tarefas_recalculo` (com `tipo_entidade`/`status`/`payload jsonb`/`referencia`),
  model `TarefaRecalculo` com `enfileirar!` **idempotente** (índice UNIQUE **parcial** em
  `[tipo_entidade, referencia] WHERE status='pendente'`); job `ExecutaTarefasJob` (cron `*/5`, advisory
  lock próprio) que drena `pendentes` e despacha por um **registry** `tipo → callable`; produtores nos
  pontos de escrita de cada evento.
- **Prós:** fiel ao mecanismo do PRD §5.2 (mesmo modelo mental do legado); idempotência **no banco**
  (não em memória); desacopla produtor × recálculo (o request não recalcula); o registry é **mínimo**
  (mapa + initializer), sem framework de plugins; tipos sem domínio ficam **declarados e adiados** sem
  quebrar o despacho.
- **Contras:** mais uma tabela e um cron para operar; requer disciplina de idempotência nos produtores
  (referência estável); o registry é um padrão **novo** no app.

### Alternativa B — Barramento de eventos de domínio (como proposto em `05-eventos-dominio.md`)
- **Descrição:** publicar eventos de domínio (`RegistroFrequenciaSalvo`, `VinculoAlterado`, …) e consumir
  via subscribers, sem tabela de fila.
- **Prós:** alinhado ao DDD alvo do doc de domínio; desacoplamento semântico.
- **Contras:** o Frequência **não tem** infraestrutura de barramento; exige semântica de entrega
  (at-least-once, retry, dead-letter) que a tabela de tarefas **fornece de graça** via o índice de
  `pendente` + `status`; o PRD §5.2 descreve explicitamente uma **tabela de fila**, não um bus.
  **Rejeitada** (o doc de domínio fica com nota de reconciliação).

### Alternativa C — Recálculo síncrono no ponto do evento (sem fila)
- **Contras:** o request de criação de `TimeRecord`/batida manual passaria a executar o pipeline de
  cálculo (`CalculoDiario` + consolidação mensal) **in-line** — latência e acoplamento que o §5.2
  justamente elimina. **Rejeitada.**

### Alternativa D — Reusar o `CalcularFrequenciaJob` como handler (herdar o lock único)
- **Contras:** o job noturno tem lock único (`451_926_073`); usá-lo dentro do drain (que já segura o
  lock `728_104_536`) faria `pg_try_advisory_lock` retornar `false` sob concorrência ⇒ o handler sairia
  **sem efeito** e a tarefa seria marcada `processada` (**drain-without-effect silencioso**). **Rejeitada**
  (regra 2).

## Decisão

> **ADOTAMOS A ALTERNATIVA A.** A fila de recálculo é uma **tabela persistente de tarefas governada
> por um registry de handlers**, fiel ao PRD §5.2. O produtor **enfileira**; o `ExecutaTarefasJob`
> **despacha**; o handler **recalcula** reusando o pipeline idempotente existente.

Regras:

1. **Registry de handlers por `tipo_entidade` (padrão novo, deliberadamente mínimo).** O contrato é um
   **mapa** `tipo → callable` no `ExecutaTarefasJob`, **vazio de fábrica**, populado por um initializer
   (`config/initializers/recalculo_handlers.rb`) via **`to_prepare`** (idempotente, sem autoload lazy).
   Nada de framework de plugins. Cada handler é um PORO que recebe a `TarefaRecalculo` e executa o
   recálculo. Tipo **não-adiado sem handler** ⇒ `skip` explícito + `Rails.logger.warn` (nunca `raise`);
   tipo **adiado** ⇒ no-op **silencioso** (guard antes de consultar o registry).

2. **Advisory lock PRÓPRIO, nunca herdado nem reusado.** `ExecutaTarefasJob::LOCK_KEY = 728_104_536`
   (distinto das demais 5 chaves: `837_462_915`, `592_017_384`, `471_209_336`, `194_773_608`,
   `451_926_073`). Um handler que roda **dentro** do drain **NÃO** pega um segundo lock — em especial
   **não** reusa o lock do `CalcularFrequenciaJob` (Alternativa D). A sobreposição com o job noturno é
   **convergente** (ambos idempotentes sobre os mesmos dados) ⇒ o pior caso é **trabalho duplicado**,
   não dado incorreto. Regra: **jamais** deixar uma tarefa ser drenada sem efeito por contenção de lock.

3. **Contrato de produtores — dentro × fora da transação, decidido caso a caso.**
   - **31.3 (`REGISTRO_FREQUENCIA`/`ESTACAO`):** enfileira **DENTRO** da transação do `TimeRecord`
     (atomicidade: rollback não deixa tarefa órfã). Para que a violação de unicidade (`RecordNotUnique`)
     de `enfileirar!` **não aborte** a transação do chamador, o `INSERT` é isolado num **SAVEPOINT**
     (`transaction(requires_new: true)`), com os `rescue` **fora** do bloco.
   - **31.5 (`VINCULAR_DESVINCULAR`):** produtor via callback **`after_commit`** no model (fora da
     transação) — um rollback **não** deixa tarefa órfã, e a origem é o **único locus** de ciclo-de-vida
     do vínculo (regra 6). O enfileiramento é protegido por `rescue StandardError` + log: falhar em
     enfileirar **nunca** derruba a persistência do vínculo.
   A escolha é **do caso concreto**, documentada no código — não há regra única "sempre dentro".

4. **Trava de mês finalizado (17.2) vale para o recálculo por evento — inclusive para o DIA.** Antes de
   **qualquer** escrita, o handler checa `ConsolidacaoMensalService.finalizado?(user, ano, mes)`
   (**predicado público mínimo**, que **reusa** a mesma condição de `consolidar` — não duplica a regra)
   e faz **skip silencioso** do mês finalizado. Motivo: o `CalculoDiarioService.calcular` faz `save!`
   **sem** guarda de finalização; sem o predicado prévio, o ramo "passado" reescreveria o `CalculoDiario`
   de um mês fechado **antes** de `consolidar` levantar `MesFinalizadoError` (o erro seria engolido) —
   **burla da trava 17.2**. O `rescue MesFinalizadoError` permanece como **salvaguarda de corrida**.
   **Débito TOCTOU conhecido e documentado honestamente:** entre o guard e o `consolidar`, OUTRO processo
   pode finalizar o mês (janela ínfima, finalização manual) ⇒ o dia é reescrito e só então o `consolidar`
   propaga. O comentário descreve a janela **sem superestimar** a proteção.

5. **Nunca recalcular dia futuro.** `return if data > Date.current` ⇒ skip silencioso. Vale para
   `REGISTRO_FREQUENCIA` (correção B/31.3) e para o recorte do fim de período na `VINCULAR_DESVINCULAR`
   (31.5: período aberto ⇒ fim = `Date.current`; fim futuro ⇒ recortado). Recálculo de futuro é
   semanticamente inválido e não tem consumidor.

6. **Q14 — `RegimeFrequentador` é a entidade que emite `VINCULAR_DESVINCULAR`; produtor = callback
   `after_commit` no próprio model.** É o **único locus** de ciclo-de-vida do vínculo que existe, porque
   a app **NUNCA escreve** `regime_frequentadores` (nenhum controller/rota/service/job/rake/seed; só
   `db/migrate` a cria — as demais referências são de **leitura** em `calculo_diario_service.rb` e
   `consolidacao_mensal_service.rb`). Não há ponto de CRUD onde pendurar o enfileiramento; quando surgir,
   o callback já o cobre. **Referência estável** = `"VINCULAR_DESVINCULAR:#{user_id}:#{início}:#{fim}"`
   ⇒ 2 eventos do mesmo período = **1** tarefa pendente. `update` só enfileira se `momento_inicial`/
   `momento_final` mudou (`previous_changes`, não o `changed?` já limpo).

7. **Tipos ADIADOS são declarados, não implementados.** `TIPOS_ENTIDADE` cobre os **7** do PRD
   (fidelidade), mas `TIPOS_ADIADOS = %w[FERIADO DIAEXCEPCIONAL DIREITO]` isola os 3 **sem produtor e
   sem handler** (models de domínio inexistentes). O despacho **não os toca**. Cada um nasce na tarefa
   que implementar a seção do PRD que o consome (política incremental — ruling 30.3 = A emendado).

## Consequências

### Positivas

- O mecanismo estrutural do PRD §5.2 deixa de ser um gap ("sem equivalente") e passa a ter **lugar
  canônico e auditável**.
- O contrato de arquitetura (fila idempotente no banco × registry × contrato de produtores × regras de
  negócio do recálculo) fica **explícito** — evita que um agente futuro "otimize" com JOIN cross-database,
  redefina a idempotência em memória, ou reabra a filosofia do job 17.5.
- Idempotência **no banco** (índice UNIQUE parcial) + pipeline idempotente ⇒ reprocessar a fila é seguro.
- Os tipos adiados ficam **registrados** sem dívida silenciosa, sob política incremental.

### Negativas / Trade-offs

- **Débito TOCTOU de mês finalizado** (regra 4) — janela residual aceita, documentada; reabrir se a
  finalização de mês passar a ser automatizada.
- **D2 da 17.5** (pré-existente): `CalcularFrequenciaJob` recalcula os últimos 3 dias **sem** guarda de
  mês finalizado (mesmo padrão do bug A/31.3). Corrigir **só o handler** criaria **divergência handler ×
  job** — o tratamento correto é **tarefa própria sobre a 17.5** (guard por dia lá; o handler espelha).
- **Crash-window do despacho:** entre marcar `processada` e o efeito do handler, um crash perde o
  efeito (não há retry automático sofisticado). A idempotência mora **nos handlers** — débito aceito.
- **Volume** (`RECALCULAR_TODOS`/período longo): mitigado pelo escopo temporal do pipeline (3 dias +
  mês corrente), pela consolidação **1× por (ano,mês)** (não 1× por dia), pela idempotência e por um
  `warn` de observabilidade para períodos anômalos (`PERIODO_ALERTA_DIAS = 366`) — **sem truncamento**.
- O `registry` é um padrão **novo** no app (mapa + initializer `to_prepare`).

### Neutras

- **Nada de autorização:** nenhuma alteração em `Ability`/`AutorizacaoFrequencia`/`FrequentadoresVisiveis`/
  `FrequenciaAutorizacaoCascata`.
- **Nada da §5.1 da `§5.3`:** os jobs autônomos do legado e a auto-inativação de `APOSENTADO` **não** são
  tocados; o mecanismo **reusa** o pipeline existente.
- Não reedita a ADR-0010 (cascata) nem a ADR-0008 (semântica de `ativo`).

## Compliance

- **Registry:** `ExecutaTarefasJob` expõe apenas `handlers`/`registrar_handler`; a população é do
  initializer `config/initializers/recalculo_handlers.rb` via `to_prepare`; tipo adiado ⇒ no-op silencioso;
  tipo não-adiado sem handler ⇒ `skip` + `warn`.
- **Lock:** existe **uma** `LOCK_KEY` por job; `728_104_536` é única no repo (nenhum handler pega lock).
- **Idempotência:** índice UNIQUE **parcial** `[tipo_entidade, referencia] WHERE status='pendente'`;
  `enfileirar!` isola o `INSERT` em SAVEPOINT; cada produtor tem `referencia` estável provada por teste.
- **Trava 17.2:** todo handler de recálculo por evento checa `ConsolidacaoMensalService.finalizado?`
  **antes** de escrever; `rescue MesFinalizadoError` como salvaguarda.
- **Dia futuro:** nenhum handler escreve em `data > Date.current`.
- **Tipos adiados:** grep prova que **nenhum** código de produção cria tarefa de tipo adiado.

## Notas

- ADRs relacionados: **0010** (cascata — mecanismo irmão, dual-implementação), **0008** (semântica de
  `ativo` do gestor — a `RECALCULAR_TODOS` **consome** `Pessoas::Vinculo.ativos`, não redefine), **0009**
  (toolchain), **0001** (integração com Pessoas — restrição de banco).
- Requisitos do PRD: `PRD-REGRAS-NEGOCIO-PRESENCA.md` **§5.2 (L139-148)** e **§9 item 3 (L201)**;
  contexto da §5.1 (L133-137); §6 (flags manuais — "exigem recálculo manual"; o recálculo por evento é a
  via automatizada complementar).
- Fontes: `docs/progress/iteration_31.md` (tasks 31.1–31.5 + §"Encerramento da Sprint 31");
  `docs/quality/review_report_31_2..31_5.md`; commits `b417fef`/`1fa033e`/`97095bc`/`b50e425`/`e13f782`/`dae631f`.
- **Reconciliação com o domínio:** `docs/03-dominio/05-eventos-dominio.md` (proposta de "eventos de
  domínio") recebe **nota** apontando que o mecanismo foi materializado como **tabela de tarefas**
  (Alternativa A) — o mapa evento → `tipo_entidade` fica registrado lá.
- Artefatos: `app/models/tarefa_recalculo.rb`; `app/jobs/executa_tarefas_job.rb`;
  `app/services/registro_recalculo_handler.rb`; `app/services/recalcular_todos_handler.rb`;
  `app/services/vincular_desvincular_handler.rb`; `config/initializers/recalculo_handlers.rb`;
  `app/models/regime_frequentador.rb` (produtor `after_commit`); `config/schedule.yml` (entrada
  `executa_tarefas`); migration `20261013120000_create_tarefas_recalculo`.
- Testes: `test/models/tarefa_recalculo_test.rb`; `test/jobs/executa_tarefas_job_test.rb`;
  `test/services/registro_recalculo_handler_test.rb`; `test/services/recalcular_todos_handler_test.rb`;
  `test/services/vincular_desvincular_handler_test.rb`; `test/models/regime_frequentador_produtor_test.rb`;
  produtores em `test/services/registro_manual_frequencia_service_test.rb` e
  `test/integration/presenca_endpoints_test.rb`.
- Legado (fonte primária): tabela `presenca_historicotarefa` + `HistoricoTarefaServices` + job
  `ExecutaTarefas` (PRD §5.2).
