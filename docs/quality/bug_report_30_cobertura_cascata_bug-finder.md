# Relatório Bug Finder — Sprint 30 (cobertura da cascata de autorização de frequência)

> **Branch:** integration/sprint-29 (medição em árvore de trabalho local)
> **Data:** 2026-10-07
> **Autor:** Bug Finder (adversarial)
> **Propósito:** Auditoria adversarial da **cobertura** da cascata de autorização de frequência
> (flag `FREQUENCIA_AUTORIZACAO_CASCATA`, ADR-0010). Confirmar/refutar a premissa de que
> `dashboard` e `users` vazam dados de terceiros a um usuário comum; provar por código e por
> execução; varrer os demais endpoints que expõem `TimeRecord`/`Frequentador`/`CalculoDiario`.
> **Regras:** nenhuma correção aplicada; nenhum commit; apenas medição e relato.
> **Ambiente:** Ruby 3.3.8 (mise) / Rails 8.1.4, `RAILS_ENV=test`, binstub `bin/rails test`.

---

## Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 9 (6 propagados + varredura de código de 8 controllers) |
| Bugs encontrados | 4 (+1 premissa refutada) |
| 🔴 Crítico | 1 |
| 🟠 Alto | 1 |
| 🟡 Médio | 1 |
| 🟢 Baixo | 1 |
| ⚪ Info | 1 (+1 refutação) |

**Evidência de execução:** teste adversarial temporário
`test/controllers/admin/zz_bf_auditoria_cascata_test.rb` (8 testes, 36 asserções, **0 falhas**),
removido após a medição. Todos os achados abaixo têm passo de execução reproduzível descrito no
campo *Teste sugerido*. Suíte existente de cobertura da cascata:
`frequencia_cascata_controller_test.rb` + `frequencia_matriz_aceite_test.rb` = **30 runs / 152
asserções / 0 falhas** (confirmados nesta auditoria).

---

## Bugs por Severidade

### Bug 1 — `admin/users_controller#index` lista TODOS os frequentadores a qualquer autenticado, sem consultar a cascata

- **Severidade:** 🔴 Crítico
- **RF/RN violado:** ADR-0010 (D2 — a cascata governa a leitura de frequência/frequentadores); PRD §3 (cascata). Inconsistência direta: a MESMA fonte (`Pessoas::Vinculo.frequentadores_ativos`) é restringida em `admin/frequentadores_controller` (cascata da 29.7) e exposta **sem restrição** em `admin/users_controller`.
- **Evidência (arquivo:linha):**
  - `app/controllers/admin/users_controller.rb:18` — `authorize! :read, :all` (baseline da Sprint 23: **qualquer autenticado** passa).
  - `app/controllers/admin/users_controller.rb:19-23` — `Pessoas::Vinculo.frequentadores_ativos(...)` **sem** `incluir_cpfs_com_cascata` / `restringir_frequencia` / `frequentadores_visiveis_cpfs`. O concern `FrequenciaAuthorization` **não é incluído** neste controller.
  - `app/controllers/admin/users_controller.rb:34` — `@users_sem_cpf = User.where(cpf: nil)` lista todas as contas locais sem CPF (inclui admins) a qualquer autenticado.
- **Passos:** (usuário `davi.queiroz` id 73, sem role, `admin=false`)
  1. Autenticar em `/login`.
  2. `GET /users`.
- **Atual:** HTTP 200 com a lista completa de nomes de todos os frequentadores ativos do Pessoas + todas as contas locais sem CPF. **Independe do valor da flag** (`:off`/`:shadow`/`:on`) — o controller não lê a flag. Confirmado sob `FREQUENCIA_AUTORIZACAO_CASCATA=on`.
- **Esperado:** sob `:on`, ou listar apenas os frequentadores visíveis (como `/frequentadores`), ou exigir role da cascata (passo 2). Sob `:shadow`/`:off`, ao menos manter paridade com a tela `/frequentadores`.
- **Teste sugerido:** `GET users_path` logado como não-admin, com `Pessoas::Vinculo.frequentadores_ativos` stubado devolvendo um vínculo de terceiro → assertar 200 e `response.body` contendo o nome do terceiro. **Resultado medido:** corpo contém `"PESSOA DE TERCEIRO BF"` (3 variações testadas: `:on`, sem flag, e conta admin local). O teste existente `users_controller_test.rb:110` (`"usuario nao-admin ainda pode listar usuarios (read baseline)"`) já *sanciona* o 200 — mas **não assere o conteúdo**, deixando o vazamento passar.
- **Observação de governança:** a diretiva `rules/dados-pessoais-cpf.md` ("CPF exposto não é bug") **não cobre** este achado: não é exposição de CPF em tela, é **falha de autorização** — um usuário sem privilégio enumera *quem* existe no órgão, exatamente o que a cascata existe para impedir. O paralelo com `/frequentadores` (que É restringido) prova a inconsistência.

### Bug 2 — Endpoints `/presenca/*` acessíveis SEM autenticação expõem batidas e usuários de terceiros

- **Severidade:** 🟠 Alto
- **RF/RN violado:** RNF de autenticação/autorização; PRD §3 (visibilidade de frequência).
- **Evidência (arquivo:linha):**
  - `app/controllers/presenca/ponto_de_presenca_controller.rb:9` — `TimeRecord.by_date(Time.zone.now)` de **todos** os usuários, sem escopo. `app/controllers/presenca/application_controller.rb:6` — **sem** `require_login`/`before_action` de sessão.
  - `app/controllers/presenca/dyn_frequentadores_estacao_controller.rb:4` — `User.ativos.com_digitais` serializados (id, username, nome, hash).
  - Rotas públicas: `config/routes.rb:97` e `:103` (namespace `:presenca`, sem constraint).
- **Passos:**
  1. Sem sessão, `GET /presenca/PontoDePresenca`.
  2. Sem sessão, `GET /presenca/DynFrequentadoresEstacao`.
- **Atual:** HTTP 200. A tela `PontoDePresenca` (layout `kiosk`) exibe **nome + horário** das batidas do dia de todos; `DynFrequentadoresEstacao` devolve a lista de usuários com digitais (username/nome/hash) em texto puro.
- **Esperado:** o endpoint do terminal deve ser gated pelo código de ativação da estação (como `SincronizarRegistrosPonto` faz via `EstacaoPonto.codigo_ativacao_valido?`) ou por restrição de rede; hoje **não há gate algum**.
- **Teste sugerido:** `GET "/presenca/PontoDePresenca"` sem login → 200 e corpo contendo nome de terceiro. **Resultado medido:** 200 + `"ALVO PONTO BF"` no corpo (BF-05). `GET "/presenca/DynFrequentadoresEstacao"` sem login → 200 + `"alvodynbf"` (BF-06).
- **Nota:** a premissa do enunciado ("avaliar se é tela de terminal by design") procede parcialmente — é superfície de Estação (ADR-0003) —, mas a ausência de gate de ativação eleva o risco. **Requer decisão PO/CTO** (aceitar como surface de rede ou gate-ar). **Fora do grão da ADR-0010** (a cascata é pré-sessão administrativa).
- **🟡 DECISÃO DO DEV (2026-10-08) — ADIADO (não corrigir agora).** O dev decidiu **NÃO alterar a distinção de host** enquanto os **testes manuais** da Estação estiverem em curso — os endpoints abertos são necessários para testá-los. Risco **aceito temporariamente** (opção (c) com revisita), **não** resolvido. Contexto confirmado pelo dev: `/presenca` é o **kiosk** do terminal (chamado pela JavaFX); o **campo de login** ali **não é autenticação** — é **disparador de ponto** (digitar o login registra a batida, assim como a biometria). **PENDÊNCIA EXPLÍCITA:** revisitar a distinção de host (rede/allowlist ou gate por ativação) **após** os testes manuais — enquanto isso, `/presenca/PontoDePresenca` (batidas do dia de todos) e `/presenca/DynFrequentadoresEstacao` (hashes biométricos) seguem acessíveis **sem autenticação a qualquer host da rede**.

### Bug 3 — `time_records#index` vaza a data da batida mais antiga de toda a base a um não-admin

- **Severidade:** 🟡 Médio
- **RF/RN violado:** ADR-0010 (a listagem de frequência deve refletir só o visível).
- **Evidência (arquivo:linha):** `app/controllers/admin/time_records_controller.rb:29-30` — `@anos_disponiveis = (TimeRecord.minimum(:punched_at)&.year || ...)`. Este `minimum` é calculado sobre a relação **global**, **antes** de `restringir_frequencia` (l.48) e antes do filtro `where(user_id: current_user.id)` (l.71). O dropdown de anos exposto na view revela o ano da batida mais antiga de **quaisquer** usuários.
- **Passos:** logado como não-admin, `GET /time_records` e inspecionar o dropdown de ano.
- **Atual:** o seletor de anos inclui anos que só existem por causa de registros de terceiros.
- **Esperado:** o intervalo de anos deveria derivar apenas dos registros visíveis ao usuário.
- **Teste sugerido:** cenário com um `TimeRecord` antigo (ex.: 2019) de terceiro e nenhum do usuário; assertar que `2019` não aparece no `select` do não-admin. (Baixo impacto de dados — um ano, não a batida —, mas é a mesma classe de furo: consulta global fora do escopo da cascata.)

### Bug 4 — Sidebar (menu lateral) expõe a um não-admin links para todas as seções administrativas

- **Severidade:** 🟢 Baixo
- **RF/RN violado:** expectativa de UX de autorização (menu refletir permissões).
- **Evidência (arquivo:linha):** `app/controllers/admin/application_controller.rb:151-288` — itens de menu com `permission_check: :all` (ex.: Frequentadores, Frequência, Frequência por Órgão, Relatório Terceirizados, Parcial). Como o baseline é `can :read, :all`, **todos** os itens chaveados em `:read, :all` aparecem para qualquer autenticado.
- **Atual:** o menu lista "Frequência", "Frequentadores", "Frequência por Órgão", "Relatório Terceirizados" para usuário sem role.
- **Esperado:** o menu deveria refletir a cascata (passo 2) quando ligada; hoje serve de guia de enumeração para as telas sensíveis.
- **Teste sugerido:** `GET dashboard_path` como não-admin → corpo contém esses rótulos (BF-04, medido: 200 com os 4 links). Menus que usam `permission_check: <Model>` (ex.: `TimeRecord`) seguem o baseline por classe e igualmente aparecem — ver Bug 5/info no `Ability`.

### Info 1 — Premissa #1 do enunciado (`admin/dashboard_controller#index` vaza a não-admin): **REFUTADA**

- **Severidade:** ⚪ Info (falso positivo)
- **Evidência (arquivo:linha):** `app/controllers/admin/dashboard_controller.rb:8-56` — **todo** o corpo (contagens globais de `TimeRecord`, `Pessoas::Vinculo.ativos.count`, `@ultimas_entradas`/`@ultimas_saidas` de todos) está dentro de `if current_user.admin?`. A view `app/views/admin/dashboard/index.html.erb:3` replica o gate (`<% if current_user.admin? %>` … `<% else %>` "Bem-vindo"). Um não-admin recebe apenas "Bem-vindo, X!" + link para os próprios registros.
- **Teste:** `GET dashboard_path` como não-admin sob `:on` → 200, contém "Bem-vindo", **não** contém "Batidas Hoje"/"Total de Usuários"/cards `.small-box` (BF-01, medido). **Conclusão: o dashboard NÃO é um vetor de vazamento para usuário comum.** A contagem global existente é exclusiva do admin (passo 2 da cascata — visão global por design).

### Info 2 — `Ability`: baseline `can :read, :all` por CLASSE permanece verdadeiro sob `:on`

- **Severidade:** ⚪ Info (comportamento documentado, ADR-0010 / Ability l.60-68)
- **Medição:** sob `FREQUENCIA_AUTORIZACAO_CASCATA=on`, com a cascata stubada para "nenhum visível" (BF-03, 0 falhas):
  - `Ability#can?(:read, :all)` → **true**;
  - `Ability#can?(:read, TimeRecord)` (chamada por CLASSE, usada pelo `load_and_authorize_resource` e por `can?` em views) → **true**;
  - `Ability#can?(:read, <TimeRecord instance de terceiro>)` → **false**.
- **Implicação:** a negação sob `:on` é **apenas** a filtragem de listagem + o bloco por instância. Qualquer tela/autorização que só pergunte `can?(:read, :all)` ou `can?(:read, TimeRecord)` **por classe** continua liberada. É exatamente o mecanismo que deixa o Bug 1 passar.

---

## Cenários Testados (sem bugs)

- `/frequencia` sob `:on` restringe aos visíveis; sob `shadow` **não** filtra (mostra todos) mas loga a negação — coberto por `frequencia_cascata_controller_test.rb` (o sintoma relatado pelo dev é o **comportamento esperado do modo shadow**, confirmado por teste existente `"frequencia: modo shadow NAO filtra mas LOGA a negacao"`).
- `/frequentadores` sob `:on` restringe por CPF; `:off`/`shadow` mostram tudo (cascata da 29.7). ✔
- `/time_records` sob `:on` restringe; não-admin já vê só os próprios registros por `where(user_id: current_user.id)` independentemente da flag. ✔ (exceto o vazamento de ano — Bug 3).
- `/frequencia_por_orgao` sob `:on` aplica `cpfs &= frequentadores_visiveis_cpfs`; matriz 30.7a/b/c cobre o grão por CPF, fail-closed sem CPF e a trilha de auditoria. ✔
- `/parcial` e `/relatorio_terceirizados` — `@registros = []` (sem fonte real); nada a vazar hoje. ✔
- `admin/frequencia_por_orgao` — `observar_cascata_por_cpf`/`registrar_negacoes_por_cpf` simétricos. ✔
- Matriz de aceite completa (12 cenários, ADR-0006) + cascata: **30 runs / 152 asserts / 0 falhas**. ✔

---

## Achados de padrão sistêmico (para o CTO)

1. **A cascata é aplicada manualmente por controller, sem enforcement central.** `FrequenciaAuthorization` é um concern *opt-in*; a `Ability` só restringe por classe via `cannot :read, RECURSO` e o `can?(:read, :all)` por classe segue `true`. Qualquer controller novo que leia `TimeRecord`/`CalculoDiario`/`Pessoas::Vinculo` e chame `authorize! :read, :all` **vaza silenciosamente** — o Bug 1 é o caso concreto. O `check_authorization` do base **não** detecta esse furo (ele só falha se *nenhum* `authorize!`/`load_and_authorize` for chamado; o `:all` o satisfaz).
2. **`admin/users_controller` é o caso que prova a assimetria**: a mesma consulta `Pessoas::Vinculo.frequentadores_ativos` é protegida em `/frequentadores` e desprotegida em `/users`. A D2 da ADR-0010 restringiu "recursos de frequência", mas o **grão Pessoas::Vinculo** (roster de frequentadores) escapou da varredura — inclusive `dashboard` é lido no mesmo padrão.
3. **`/users` também expõe contas locais sem CPF (admins)** por `User.where(cpf: nil)` — a mesma tela serve de enumeração de contas privilegiadas.
4. **Endpoints `/presenca/*` (pré-sessão) ficam fora do alcance da cascata por construção** — a barreira ali é outra (código de ativação / rede), e hoje `PontoDePresenca`/`DynFrequentadoresEstacao` não têm gate algum.
5. **Recomendação de teste (não aplicada):** o teste `users_controller_test.rb` sanciona o 200 de não-admin sem assertar conteúdo; falta um teste de *conteúdo* (nome de terceiro ausente) por tela de listagem, no mesmo grão da matriz de aceite.

---

## Veredito Final

A **cascata funciona nos 6 controllers que ela instrumenta** (30 testes verdes). O problema não está
nesses controllers, e sim na **cobertura**: ela é opt-in e não há enforcement central, de modo que
duas telas que leem os mesmos dados por fora dela seguem abertas a **qualquer usuário autenticado,
em qualquer valor da flag** — inclusive `:on`:

- 🔴 **Bug 1 (`/users`)** é o achado principal: quebra o objetivo da feature (um usuário sem role enxerga o roster inteiro de frequentadores) e passa despercebido porque o teste existente só valida o HTTP 200, não o conteúdo. **Prioridade de correção: 1.**
- 🟠 **Bug 2 (`/presenca/*`)** é exposição **não autenticada** de dados de terceiros; requer decisão PO/CTO (surface de terminal vs. gate). **Prioridade: 2.**
- 🟡 **Bug 3 (ano global)** e 🟢 **Bug 4 (sidebar)** são vazamentos menores da mesma classe. **Prioridade: 3.**
- ⚪ A premissa sobre o **dashboard é refutada** — não vaza a não-admin.

**Ação sistêmica sugerida ao CTO:** registrar em `docs/inception/*` (ou ADR) o padrão de *enforcement
central* da cascata e incluir `users#index`, `dashboard` e os endpoints `/presenca/*` na varredura de
cobertura — hoje a ADR-0010 cobre bem o "como restringir" e deixa implícito o "**onde** restringir".

---

> **Rastreabilidade:** relaciona-se a `docs/progress/iteration_29.md` (29.7/29.8), `docs/adr/0010-arquitetura-cascata-autorizacao-frequencia.md`, `docs/progress/iteration_30.md` (frentes 1–5), `docs/quality/review_report_29_7.md`, `docs/quality/bug_report_29_bug-finder.md`.
