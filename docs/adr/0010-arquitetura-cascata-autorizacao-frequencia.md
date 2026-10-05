# ADR-0010: Arquitetura da cascata de autorização de frequência (dual-implementação PORO × SQL, flag de rollout e regras de conformidade)

> **[⌂ Home](../README.md)**

## Status

Aceito (CTO, 2026-10-05). Consolida em decisão durável o que a **Sprint 29** produziu e que hoje
vive apenas dentro de `docs/progress/iteration_29.md` (212 KB — registro primário, difícil de
descobrir e auditar). Origem direta: `docs/progress/iteration_29_closure.md` §2 ("ADR-0010
recomendada"). Orienta o rollout da flag, o consumo da cascata na Sprint 30 e a remoção do débito
🟡S2. **Não** reedita os rulings que a cascata cumpre (D1/D4/D5/D6/D8) — referencia-os.

## Contexto

- **Regra portada do legado.** A cascata substitui o baseline "todo autenticado lê tudo" (Sprint
  23.7) por um porte fiel de `RegistroFrequenciaValidator.frequentador` (visualização) e
  `RegistroFrequenciaServices.podeDesconsiderarFrequencia` (desconsiderar). Ordem **primeiro-match
  vence**: `1` próprio · `2` admin OU `visualiza_frequentadores` (precedência/curto-circuito) ·
  `3` `visualiza_terceirizados` E alvo Terceirizado · `4` `GestorIndividual` ativo · `5` hierarquia
  (gestor do órgão do alvo via `cadeia_ascendente`) · `6` `:negado`.

- **A mesma regra existe em DOIS lugares, por necessidade estrutural.** O PORO de consulta
  `AutorizacaoFrequencia` (`app/models/autorizacao_frequencia.rb`, task 29.4) responde por **um
  alvo** (`pode_ver?`/`motivo`); o scope SQL `FrequentadoresVisiveis` (`app/models/frequentadores_visiveis.rb`,
  task 29.6) responde pela **lista inteira**. A razão é uma **restrição de banco**: `users`
  (banco primário) e `pessoas`/`vinculos` (banco espelho do Pessoas) são **Postgres distintos**
  (`config/database.yml`) — **não há JOIN cross-database**.

- **Contrato de equivalência.** Para TODO par (usuário, frequentador), o frequentador está na lista
  do scope **sse** `AutorizacaoFrequencia.new(usuario).pode_ver?(frequentador)` é `true`. A **fonte
  da verdade da regra é o PORO**; o SQL **não inventa semântica** — replica. A prova é o teste de
  propriedade em `test/models/frequentadores_visiveis_test.rb`.

- **Bug de sobre-reporte (corrigido em `16c1c9a`, débito D2).** O agregado de log de negações do
  scope (`log_unidades_inelegiveis`) rodava o D6 direto e contava alvos que os passos 1–4 já
  liberariam — inflando o shadow de forma **sistemática** (todo alvo liberado por 1/3/4 com unidade
  inelegível na cadeia). O `OR` do SQL tem de reproduzir o **curto-circuito e a precedência** do
  PORO, não só o conjunto de condições.

- **A cascata está implementada, provada e NÃO vigente.** O rollout é por flag de 3 estados com
  **default OFF**.

- **Débito 🟡S2 (blind spot do twin).** O twin SQL e o PORO têm construções análogas do passo 4
  (`GestorIndividualGerenciado.ativos`), mas a matriz de aceite exercita o **caminho de listagem
  (SQL)**. Mutar o passo 4 no **PORO** **não derruba** nenhum teste de listagem.

- Rulings que a cascata cumpre (referência, **não** re-escritos aqui): **D1** (roles
  `visualiza_frequentadores`/`visualiza_terceirizados` e sua combinação) · **D4** (TERCEIRIZADO =
  **tipo de vínculo** `Pessoas::TipoVinculo#nome == "Terceirizado"`, nunca categoria eSocial) ·
  **D5** (ver ≠ desconsiderar) · **D6** (unidade inelegível não libera; ancestral ausente não
  interrompe) · **D8** (o caminho de leitura nunca chama `valid?`).

## Alternativas Consideradas

### Alternativa A — Dual-implementação canônica: PORO (decisão) × SQL (listagem), com contrato de equivalência testado
- **Prós:** resolve a restrição real (sem JOIN cross-database); a regra de negócio fica em **um só
  lugar** por camada, com a semântica canônica no PORO; a listagem SQL evita materializar N alvos em
  Ruby (e o vazamento por paginação); o contrato de equivalência é **verificável** (teste de
  propriedade).
- **Contras:** **drift** entre os dois corpos é possível (é o débito 🟡S2); exige baseline explícito
  em ambos e disciplina de mutação.

### Alternativa B — Só PORO (carregar alvos e decidir um a um em Ruby)
- **Contras:** o passo 5 (hierarquia) e o passo 3 (terceirizado) dependem do banco do Pessoas;
  avaliar N alvos por requisição é O(N) de queries e não filtra por paginação — inviável para o
  universo de frequentadores. **Rejeitada.**

### Alternativa C — Só SQL (um scope único, sem PORO)
- **Contras:** o passo 1 (identidade própria por id/CPF) e o passo 4 (vínculo de gestor individual)
  vivem no banco **primário** e não são expressáveis no SQL do espelho sem o `IN (cpfs)`;
  o `motivo` por alvo (usado pela auditoria/shadow) exige avaliação **sequencial** com curto-circuito
  — que o `OR` do SQL achata. Perderia a precedência e o rastro de auditoria. **Rejeitada.**

### Alternativa D — Ligar a cascata direto (sem flag, substituindo o baseline)
- **Contras:** o baseline `can :read, :all` serve todas as telas; a troca afeta a suíte inteira e o
  comportamento em produção num passo só. Sem shadow, não há como medir o impacto antes de negar
  acesso real. **Rejeitada.**

## Decisão

> **ADOTAMOS A ALTERNATIVA A, com rollout pela flag de 3 estados (Alternativa D adiada por
> observação).** A cascata é **dual**: `AutorizacaoFrequencia` (PORO) é a **fonte da verdade da
> decisão e da auditoria**; `FrequentadoresVisiveis` (SQL) é o **twin de listagem**, obrigado a
> equivalência. A cascata só vale com a flag `:on`; o default é `:off`.

Regras:

1. **Dual-implementação canônica.** A semântica vive em dois artefatos com papéis distintos:
   `AutorizacaoFrequencia` decide **por alvo** (`pode_ver?`/`motivo`) e alimenta a auditoria/shadow;
   `FrequentadoresVisiveis` serve a **listagem** (`ActiveRecord::Relation`) para index/relatórios sem
   vazar por paginação. O PORO é a **fonte da verdade**; o SQL **replica**, não redefine.

2. **Resolução obrigatória dos passos no banco certo (sem JOIN cross-database).** Os passos que
   dependem do **primário** — `1` próprio e `4` gestor individual — são resolvidos **em Ruby** contra
   `users`/`gestores_individuais` e o resultado entra no SQL como `IN (cpfs)`/`IN (ids)`. Os passos
   que vivem no **espelho** — `3` terceirizado e `5` hierarquia — viram **SQL puro** sobre
   `vinculos`/`lotacoes`/`unidades`. Nenhum dos dois lados pode tentar JOIN entre bancos.

3. **Equivalência como requisito, incluindo precedência (não só o conjunto de condições).** O `OR`
   do SQL tem de reproduzir o **curto-circuito e a ordem** do PORO. A versão que só somava condições
   produziu **sobre-reporte sistemático** no log de negações (corrigido em `16c1c9a`): o agregado do
   passo 5 exclui os alvos que os passos 1–4 já liberariam (`liberado_por_passos_1_a_4`) — um alvo
   liberado por 1/2/3/4 **nunca** chega ao passo 5 e **nunca** loga. Toda condição adicionada ao
   scope que alimente log **deve** carregar o mesmo guard de precedência.

4. **Flag `FREQUENCIA_AUTORIZACAO_CASCATA` de 3 estados, default OFF.** Ponto **único** de leitura:
   `FrequenciaAutorizacaoCascata` (lida **a cada chamada**, não memoizada — permite troca em runtime
   e teste dos 3 estados sem reiniciar o processo).

   | Valor de ENV | Modo | Efeito |
   |--------------|------|--------|
   | ausente/vazio/outro | **`:off`** | comportamento **atual**; **default em produção** |
   | `shadow`/`sombra` | `:shadow` | **só LOGA** as negações que a cascata faria (`EVENTO_SHADOW`), **sem negar** — 1 ciclo de observação antes de ligar |
   | `on`/`1`/`true`/`ligada` | `:on` | cascata **vale**: `Ability` restringe + index filtram + log de negação **efetiva** (`EVENTO_NEGACAO`) |

   Payload de auditoria **único** (`usuario`, `alvo`, `motivo`, `decisao`) nos dois eventos — a
   diferença fica **só no nome do evento**, para que shadow e `:on` sejam comparáveis linha a linha.

5. **`FrequentadoresVisiveis` é o único caminho de listagem sob `:on`.** Os controllers integram via
   o concern `FrequenciaAuthorization` (helpers `restringir_frequencia`/`observar_cascata_*`/
   `registrar_negacoes_*`), no-op em `:off`/`:shadow` e para quem tem **visão global** (passo 2). O
   shadow é **limitado** (`LIMITE_SHADOW = 200` alvos/chamada) — observa, não varre o universo.

6. **D5 — "ver ≠ desconsiderar".** O passo 4 (`GestorIndividual`) **VÊ mas NÃO desconsidera**. O
   predicado público que autoriza desconsiderar é `AutorizacaoFrequencia#gestor_de_orgao_do?`, que
   expõe **APENAS o passo 5** — **nunca** `pode_ver?`. Usar `pode_ver?` no gate de desconsiderar
   **ampliaria** a autorização, exatamente o que a D5 veda. A Sprint 29.5 **reusa** o mesmo passo 5
   (`ElegibilidadeDesconsideracao#pode_desconsiderar?`), não reimplementa a hierarquia.

7. **Débito 🟡S2 como regra de conformidade (baseline explícito nos DOIS corpos).** O twin SQL é
   **cego ao PORO**: mutar o passo 4 no PORO (`gestor_individual?`) **não derruba** nenhum teste de
   listagem. Enquanto não existir um teste que exercite o **PORO** `AutorizacaoFrequencia#motivo`
   com `GestorIndividual` **inativo** (assert `:negado`) **E** o twin SQL com o mesmo cenário, **ambos
   no baseline**, o furo fica **aberto por construção**. Toda mudança em passo compartilhado exige
   **prova nos dois** — não basta a matriz de listagem.

8. **Regras transversais herdadas (referência, não re-escritas).** A cascata cumpre D1 (semântica das
   roles), D4 (fonte de TERCEIRIZADO), D6 (unidade inelegível não libera; ausente não interrompe;
   path corrompido → fail-closed) e D8 (o caminho de leitura **nunca** chama `valid?` — só
   `where`/`exists?`/associações). Fail-closed em todos os pontos: usuário/alvo ausente, ou Pessoas
   indisponível nos passos que dele dependem (3 e 5), resulta em **negação com log**.

## Consequências

### Positivas

- A regra de autorização mais sensível do sistema deixa de existir só dentro de um `iteration_29.md`
  de 212 KB — passa a ter **lugar canônico e auditável**.
- O contrato de arquitetura (PORO canônico × SQL twin + restrição de banco) fica **explícito**,
  evitando que um agente futuro tente "otimizar" com JOIN cross-database ou redefinir a semântica no
  SQL.
- O gatilho de remoção do débito 🟡S2 fica **binário e verificável** (teste nos dois corpos).
- O rollout por flag com default OFF permite ligar a cascata **sem regressão** e medir negações em
  shadow antes de negar de fato.

### Negativas / Trade-offs

- A **dual-implementação** é uma dívida de manutenção estrutural: dois corpos, um contrato. Mitigação
  = a regra de conformidade do item 7 (prova nos dois) + o teste de propriedade.
- A flag **lida a cada chamada** tem custo desprezível, mas a cascata **não é vigente** até o PO
  decidir ligá-la — a Sprint 30 (roles granulares) é dependência de valor real.
- `frequencia_por_orgao` (agregação por CPF) tem grão próprio e cobertura de matriz mais rasa
  (débito **🟡S3**) — o denomínio de negação ali é por CPF, não por registro.

### Neutras

- Não altera migrations, schema do Pessoas, nem o baseline `can :read, :all` das telas **fora** de
  frequência.
- Não muda a idempotência da 29.3 nem o mapeamento `id_legado`.
- Não altera a ADR-0008 (semântica de `ativo` do gestor) — a cascata **consome** `.ativos`, não
  redefine a projeção.

## Compliance

- `AutorizacaoFrequencia` é a **fonte da verdade**; `FrequentadoresVisiveis` **não** define semântica
  nova — replica. Prova: teste de propriedade em `test/models/frequentadores_visiveis_test.rb`.
- Nenhum artefato da cascata faz JOIN cross-database; passos 1/4 em Ruby → `IN (...)`, passos 3/5 em
  SQL.
- Toda condição do scope que alimente **log** carrega o guard de precedência (`liberado_por_passos_1_a_4`).
- `FrequenciaAutorizacaoCascata` é o **único** ponto de leitura de `FREQUENCIA_AUTORIZACAO_CASCATA`;
  default `:off`; payload de auditoria único nos eventos `EVENTO_SHADOW`/`EVENTO_NEGACAO`.
- O gate de **desconsiderar** usa **apenas** `gestor_de_orgao_do?` (passo 5); jamais `pode_ver?`.
- **Regra do débito 🟡S2:** mudança em passo compartilhado exige teste do **PORO** (`motivo`) **e** do
  twin SQL no mesmo cenário, ambos no baseline.

## Notas

- ADRs relacionados: **0008** (semântica de `ativo` do gestor individual — a cascata consome
  `.ativos`), **0007** (soft-delete do vínculo de gestão), **0009** (toolchain/ledger — o warning
  `SQL Injection` de `frequentadores_visiveis.rb:351` foi tratado na chore do bump), **0001**
  (integração com Pessoas).
- Fontes: `docs/progress/iteration_29.md` (rulings D1/D4/D5, Ruling M2, matriz 29.8);
  `docs/progress/iteration_29_closure.md` (§1–§2); PRD-REGRAS-NEGOCIO-PRESENCA §3 e §9 item 1.
- Artefatos: `app/models/autorizacao_frequencia.rb`; `app/models/frequentadores_visiveis.rb`;
  `app/models/frequencia_autorizacao_cascata.rb`; `app/models/ability.rb`;
  `app/controllers/concerns/frequencia_authorization.rb`;
  `app/models/elegibilidade_desconsideracao.rb`.
- Testes: `test/models/autorizacao_frequencia_test.rb`, `test/models/frequentadores_visiveis_test.rb`,
  `test/models/frequencia_autorizacao_cascata_test.rb`, `test/models/ability_cascata_test.rb`,
  `test/controllers/admin/frequencia_cascata_controller_test.rb`.
- Legado (fonte primária): `RegistroFrequenciaValidator.frequentador` (Sprint 29 → 29.4);
  `RegistroFrequenciaServices.podeDesconsiderarFrequencia` (`.../RegistroFrequenciaServices.java:91-108`).
