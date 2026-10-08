# iteration fix: cobertura da cascata de autorização de frequência (bugs 🔴/🟠/🟡)

> **Modo:** STANDARD (fix — sem PRD) | **Branch:** `fix/cascata-cobertura-users-time-records` | **Data:** 2026-10-07
> **Tipo:** fix de **cobertura** da cascata (`FREQUENCIA_AUTORIZACAO_CASCATA`, ADR-0010). **Não** altera a cascata em si.
> **COMMIT_MODE=manual** — **nenhum commit/push** feito nesta sessão (conforme diretiva).
> **Autor:** Code Specialist.
> **Referência:** `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md` (Bug Finder, 2026-10-07).
> **Base da branch:** `integration/sprint-29` @ `8bd6755` — **não** `develop` (que está 67 commits
> atrás e **não** contém o concern `FrequenciaAuthorization`/cascata da 29.x; basear em `develop`
> quebraria a compilação).

---

## Sumário executivo

| Bug | Severidade | Status | Ação |
|-----|-----------|--------|------|
| **1 — `admin/users#index` lista TODOS os frequentadores a qualquer autenticado** | 🔴 Crítico | ✅ **Corrigido** | Concern `FrequenciaAuthorization` incluído + restrição via `incluir_cpfs_com_cascata`; `@users_sem_cpf` com gate admin-only |
| **2 — `/presenca/*` sem autenticação expõe dados de terceiros** | 🟠 Alto | ⏸️ **PARE + reportado** | Gate de ativação **não é aplicável** sem quebrar o kiosk — **requer decisão PO/CTO** (ver §3) |
| **3 — `time_records#index` vaza a data da batida mais antiga** | 🟡 Médio | ✅ **Corrigido** | `@anos_disponiveis` movido para **depois** de `restringir_frequencia` + filtro de próprio usuário |
| **4 — sidebar expõe links administrativos** | 🟢 Baixo | ⏭️ **Fora do escopo** (não pedido na tarefa) | — |

**Evidência de teste:** +8 testes novos (27 asserções), **0 falhas**. Suíte completa:
**1137 runs / 4012 assertions / 3F + 12E** vs. baseline no HEAD (**1129 / 3985 / 3F + 12E**) →
**+8 runs, +27 asserts, zero regressão**. Os 3F + 12E são **pré-existentes** (2× `SeedsTest`
roles + 1× timezone `PresencaEndpointsTest`; 12× Devise `redirect_to`).

---

## 1. Bug 1 🔴 — `/users` vazava o roster de frequentadores

**Arquivo:** `api-ponto/app/controllers/admin/users_controller.rb`

**Causa:** a listagem lê a **mesma** fonte de `/frequentadores`
(`Pessoas::Vinculo.frequentadores_ativos`) mas chamava `authorize! :read, :all` + a fonte **sem**
a cascata — e **não incluía** o concern `FrequenciaAuthorization`. Resultado: qualquer autenticado
sem role enumerava todo o roster, **em qualquer valor da flag** (o controller não lia a flag).

**Correção (mesmo padrão da 29.7):**
- `include FrequenciaAuthorization`;
- `observar_cascata_frequentadores` (shadow) + `registrar_negacoes_frequentadores` (`:on`) — simetria
  de auditoria idêntica à de `/frequentadores`;
- `incluir_cpfs: incluir_cpfs_com_cascata` (novo método privado que espelha o de
  `frequentadores_controller`: `nil` = sem filtro; flag off/shadow não restringe; visão global não
  restringe; `:on` interseção com `frequentadores_visiveis_cpfs`).

**Decisão sobre `@users_sem_cpf` (l.34 original):** são **contas locais sem CPF — inclui admins**
criados manualmente. Expô-las a qualquer autenticado servia de **guia de enumeração de contas
privilegiadas** (achado 3 do relatório). Gate **admin-only** (`current_user.admin? ||
has_role?(:admin)`), **independente da cascata** — a cascata governa *frequência*, não contas
administrativas; e um não-admin não consegue nem editar essas contas (`load_and_authorize_resource`
nega). `User.none` para não-admin preserva o contrato da view (`.any?`/`.each`).

**Controle positivo:** admin (`frequencia_visao_global?` → passo 2) continua vendo **todos** os
frequentadores e as contas locais.

## 2. Bug 3 🟡 — dropdown de anos vazava a batida mais antiga de terceiros

**Arquivo:** `api-ponto/app/controllers/admin/time_records_controller.rb`

**Causa:** `@anos_disponiveis = (TimeRecord.minimum(:punched_at)&.year || ...)` era calculado sobre
a relação **global**, **antes** de `restringir_frequencia` (l.48) e do `where(user_id:
current_user.id)` (l.71). Um não-admin via no `select` de anos os anos que só existiam por causa de
batidas de **terceiros**.

**Correção:** cálculo movido para **depois** das duas restrições e **antes** do filtro de ano/mês
(senão o dropdown só refletiria o ano já selecionado), sobre a relação já filtrada:
`registros.except(:includes, :order).minimum(:punched_at)`. O `except(:includes, :order)` evita que
o `includes(:user)` force um JOIN na agregação — o `minimum` roda limpo sobre os `where` aplicados.

**Controle positivo:** admin sem filtro de usuário → relação global → o ano do terceiro volta a
aparecer (visão global por design).

## 3. Bug 2 🟠 — `/presenca/*` sem autenticação (PARE + reporte)

**Decisão: NÃO implementado.** O relatório sugere gate pelo código de ativação
(`EstacaoPonto.codigo_ativacao_valido?`), mas a investigação do código mostra que **o gate não é
aplicável sem quebrar o kiosk** — exatamente o gatilho de "PARE e reporte" da tarefa:

1. **`DynFrequentadoresEstacao` / `DynHashFrequentadoresEstacao`:** a documentação canônica declara
   **"Parâmetros: nenhum"** (`docs/07-estacao-ponto/02-endpoints-consumidos.md` EP-02/EP-03;
   `PRD-POC-API-PONTO.md` §8.2/§8.3). A Estação JavaFX (`core/DownloadFrequentadoresService.java`,
   fora deste repo) chama sem `codAtivacao`. Exigir o código → a Estação **não baixa as digitais** →
   ninguém bate ponto. **Gate inaplicável.**
2. **`PontoDePresenca`:** o fluxo kiosk **descartaria** o código: `InicializarPonto`
   (`app/views/presenca/inicializar_ponto/inicializar_ponto.html.erb:16`) redireciona para
   `/presenca/PontoDePresenca` **sem** `codigoAtivacao` (`window.location.href =
   '/presenca/PontoDePresenca'`). Além disso, o filtro legado
   (`intranet/src/modules/presenca/filters/PontoDePresencaFilter.java`) trata explicitamente o caso
   em que a Estação chega **sem** `codigoAtivacao` (recupera via `codigoUnicoMaquina` +
   `RecuperarCodigoAtivacao` — rota **inexistente** na app Rails). Gate ingênuo → tela bloqueada →
   terminal morto.

**Recomendação para decisão PO/CTO (não implementada):** escolher **uma** via —
(a) gate por código de ativação **atrás de flag/env** (default off) para `PontoDePresenca`, com a
app servindo o `RecuperarCodigoAtivacao` e o redirect do `InicializarPonto` carregando o código
(muda o protocolo — fere ADR-0003, "nenhuma mudança de protocolo"); ou
(b) **restrição de rede** (mTLS/allowlist de IP da Estação) no reverse-proxy — fora do código Rails;
ou (c) **aceitar** como superfície de rede por design (ADR-0003) e registrar a aceitação de risco.
Enquanto não decidido, **não** foi tocado nenhum arquivo de `app/controllers/presenca/*`,
`config/routes.rb`, `ApiController` ou Devise.

---

## 4. Testes

**Novos arquivos:**
- `test/controllers/admin/users_cascata_controller_test.rb` (Bug 1 — 6 testes): não-admin não vê
  terceiro sob `:on`; fail-closed sem visíveis; paridade sob flag off; **admin vê tudo** (controle);
  não-admin não enumera contas locais sem CPF; admin vê (controle). O stub de
  `frequentadores_ativos` **honra `incluir_cpfs`** (espelha o contrato real: `nil`=todos,
  `[]`=nenhum, lista=só os cpfs).
- `test/controllers/admin/time_records_anos_cascata_test.rb` (Bug 3 — 2 testes): ano de batida
  antiga (2019) de terceiro **não** aparece no `select#filtro_ano` do não-admin; **admin vê**
  (controle).

**Mutation testing (manual — não há gem `mutant` no bundle):** cada mutação aplicada ao ponto
corrigido foi **morta** pelos testes:

| Mutação | Ponto | Resultado |
|---------|-------|-----------|
| A — `incluir_cpfs: incluir_cpfs_com_cascata` → `cpfs_exigidos_pelos_filtros_locais` (bug original) | users#index | 2 falhas ✅ |
| B — combiner devolve sempre `exigidos` (não restringe) | `incluir_cpfs_com_cascata` | 2 falhas ✅ |
| C — `admin_de_contas_locais?` → `true` | gate contas locais | 1 falha ✅ |
| D — `registros.except(...).minimum` → `TimeRecord.minimum(:punched_at)` (bug original) | time_records#index | 1 falha ✅ |

**Suíte completa (isolamento dos pré-existentes):**

| | runs | asserts | F | E |
|---|---|---|---|---|
| HEAD sem as mudanças (baseline) | 1129 | 3985 | 3 | 12 |
| Com as mudanças | 1137 | 4012 | 3 | 12 |

Pré-existentes: 2× `SeedsTest` (roles), 1× timezone `PresencaEndpointsTest`, 12× Devise
`redirect_to` (`Sessions`/`Passwords`). **Nenhuma regressão; nenhum stub destrutivo** (uso de
`com_metodo_de_classe_stubado`, nunca `remove_method`).

---

## 5. Riscos e pendências

- **⏸️ Bug 2 — PENDENTE DE DECISÃO PO/CTO** (ver §3). É a superfície de **maior** risco (dados
  biométricos de terceiros + batidas do dia, sem autenticação); o gate por código de ativação
  **não** fecha sem alterar o protocolo da Estação (fere ADR-0003).
- **Dívida de DRY sinalizada ao CTO:** `incluir_cpfs_com_cascata` existe em
  `frequentadores_controller` (privado) e agora espelhado em `users_controller`. O home natural é o
  concern `FrequenciaAuthorization` (arquivo **compartilhado** com 6 controllers); optou-se por
  **não** refatorá-lo nesta sessão para não arriscar a cascata em produção — **sinalizado para o
  CTO** decidir a extração.
- **Achado sistêmico (Bug 4 / enforcement central)** permanece: a cascata é *opt-in* por controller
  e `authorize! :read, :all` satisfaz o `check_authorization` — o padrão sistêmico segue para o CTO
  (registrado no relatório do Bug Finder, §Achados de padrão sistêmico).
- **Branch:** criada a partir de `integration/sprint-29` (não de `develop`) — ver justificativa no
  topo. **Sem commit/push** (COMMIT_MODE=manual).

---

## 6. Review (Code Reviewer — 2026-10-08)

**Veredito:** ✅ **Aprovado** — 0 Blockers 🔴. Relatório completo em
`docs/quality/review_report_fix_cascata_cobertura.md`.

- **Evidência reproduzida:** novos **8/27/0F/0E**; direcionada (users+frequentadores+time_records)
  **50/224/0F/0E**; cascata (6 arquivos) **55/273/0F/0E**. **Mutation A** (bug original em `users#index`)
  → 2 falhas e **Mutation D** (`TimeRecord.minimum` global) → 1 falha: ambas **mortas** pelos testes.
- **Furos fechados:** 🔴 sob `:on` com paridade fiel a `/frequentadores`; 🟡 em todos os modos.
  Controle positivo (admin) preservado; view lida com `User.none` (`.any?`/`.each`).
- **Sugestões (não-bloqueantes):** S1 DRY de `incluir_cpfs_com_cascata` (extrair p/ o concern);
  S2 **higiene de entrega** — ruído pré-existente no working tree (`credentials.yml.enc`,
  `development.rb`, `log/*`, `tmp/*`, `iteration_30.md`) **não pode** entrar no commit (stage seletivo);
  S3 numeração — `iteration_31_*` colide com a Sprint 31 planejada (`iteration_31.md`);
  S4 confirmar com PO/CTO o gate admin-only de contas locais (independente da flag).
- **Elogios:** simetria shadow × `:on`, `User.none` como contrato, ordem correta do fix do Bug 3,
  testes não-degenerados (`com_metodo_de_classe_stubado`), Bug 2 corretamente PARE+reportado.
- **Pendências herdadas (fora deste fix):** Bug 🟠 2 (`/presenca/*`) e o enforcement opt-in da
  cascata seguem para o CTO.
