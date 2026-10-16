# Relatório de Revisão — Tarefa 33.3 (Camada 2: testes de conteúdo por tela + revisão de expectativa)

**Revisor:** Code Reviewer (AI Workflow)
**Data:** 2026-10-15
**Branch de origem:** `feat/sprint-33-camada-2-conteudo-por-tela` (working tree, **NÃO commitado** — `COMMIT_MODE=manual`)
**HEAD:** `86da982`
**Repo/app:** `Frequencia/` — app `api-ponto/`
**Especificação medida contra:** `docs/progress/iteration_33.md` (tarefa 33.3 + "Notas de implementação (33.3)") +
`docs/progress/iteration_33_plano_autorizacao_32_O1.md` (§2.2(3), §3, §5 T6) +
`docs/quality/review_report_33_2.md` + `docs/quality/bug_report_33_2.md` (lição: teste que não prova o que nomeia).

## Escopo revisado

| Arquivo | Natureza |
|---|---|
| `api-ponto/test/controllers/admin/cascata_conteudo_test.rb` | testes (novo, 9 testes) — conteúdo por tela |
| `api-ponto/test/controllers/admin/users_controller_test.rb` | testes (alterado) — caso do "200 sem conteúdo" reescrito + `stub_vinculos` honra `incluir_cpfs` |
| `docs/progress/iteration_33.md` | rastreabilidade (status 33.3 ✅ + notas) |

Fora de escopo (ruído de ambiente pré-existente à tarefa, **não** avaliado): `config/credentials.yml.enc`,
`config/environments/development.rb`, `log/*`, `tmp/cache/*`.

## Veredito

✅ **Aprovado** — **sem Blockers (🔴)**. Há **1 achado 🟠** (dois asserts de conteúdo **vacuamente verdadeiros**
em telas sem fonte) e demais itens menores. O ponto crítico da tarefa — *o teste prova o filtro da cascata?* —
foi verificado por **mutação do código de produção** e a resposta é **SIM para as 4 telas que têm fonte real**
(`/frequentadores`, `/users`, `/frequencia`, `/frequencia_por_orgao`), e **NÃO para as 4 restantes**
(`/time_records`, `/relatorio_terceirizados`, `/parcial`, `/dashboard`) — as 3 últimas por ausência de fonte/gate
admin (trivial), a primeira por escopo não-admin (subsume a cascata). As divergências (b) e (c) declaradas pelo
autor são **honestas e confirmadas por mutação**; o defeito residual é de **rotação de expectativa** (o texto
promete "8 telas cobertas" quando 2 provam nada), não de correção.

**Blockers: 0 | Sugestões: 6 (Alto: 1 / Médio: 2 / Baixo: 2 / Sugestão: 1) | Elogios: 3**

## Evidências executadas (medidas neste review)

| Verificação | Comando | Resultado |
|---|---|---|
| `cascata_conteudo_test.rb` (baseline) | `bin/rails test test/controllers/admin/cascata_conteudo_test.rb` | **9 runs / 37 asserts / 0F / 0E / 0 skips** |
| `users_controller_test.rb` (baseline) | `bin/rails test test/controllers/admin/users_controller_test.rb` | **9 runs / 32 asserts / 0F / 0E / 0 skips** |
| Os dois juntos | — | **18 runs / 69 asserts / 0F / 0E** |
| Suíte completa | `bin/rails test` | **1265 runs / 4430 asserts / 3F / 12E / 0 skips** (baseline 33.2: 1256/4387/3F+12E; delta **+9/+43** = esta tarefa; 15 pré-existentes) |
| Mutação A (concern `frequencia_cascata_ligada? → false`) | `bin/rails test test/controllers/admin/cascata_conteudo_test.rb` | **4 failures** (frequentadores, users, frequencia, frequencia_por_orgao) |
| Mutação A sobre `users_controller_test.rb` | idem | **1 failure** (o caso reescrito, L146) |
| Mutação B (dropdown de anos → `TimeRecord.minimum(:punched_at)` global) | `time_records_anos_cascata_test.rb` e `cascata_conteudo_test.rb` | **1 failure** em cada (`anos_cascata:33`; `cascata_conteudo:162`) |
| `app/**`, `ability.rb`, `schema.rb`, rotas, `test_helper.rb` | `git diff --stat` | **vazio** — intocados |
| Resíduo de mutação | `git diff`/`status` | **vazio** — restaurado |

## Tabela tela → o teste falha sob mutação?

Mutação A = neutralizar o filtro da cascata no concern (`FrequenciaAuthorization#frequencia_cascata_ligada?` → `false`),
o que desliga a cascata em **todas** as telas de uma vez. Mutação B = reverter o dropdown de anos ao mínimo global.

| Tela (teste) | Falha sob Mutação A (filtro da cascata neutralizado)? | Prova o filtro da cascata? |
|---|---|---|
| `/frequentadores` (L56) | **SIM** (L77) | **Sim** — real |
| `/users` (L84) | **SIM** (L103) | **Sim** — real |
| `/frequencia` (L110) | **SIM** (L128) | **Sim** — real |
| `/frequencia_por_orgao` (L190) | **SIM** (L209) | **Sim** — real (por contagem) |
| `/time_records` `:on` (L135) | **NÃO** (parte a = nome: degenerada). Parte b (ano) falha sob **Mutação B** (L162), mas pela *mutação B*, não pela A | Parcial — a parte (b) cobre o bug do dropdown; a cascata em si **não** é exercitada (escopo não-admin subsume) |
| `/time_records` `:off` degenerescência (L166) | **NÃO** | Não (documenta a degenerescência — honesto) |
| `/relatorio_terceirizados` (L218) | **NÃO** | Não — **vacuamente verdadeiro** (sem fonte) |
| `/parcial` (L229) | **NÃO** | Não — **vacuamente verdadeiro** (sem fonte) |
| `/dashboard` (L242) | **NÃO** | Não — guarda o **gate admin** (`current_user.admin?`), não a cascata |

> `users_controller_test.rb` — caso reescrito (L125): **SIM**, falha sob Mutação A (L146). Fecha o furo da 33.2.

## Apontamentos

### 🟠 Alto — A1 — `/relatorio_terceirizados` e `/parcial`: assert de conteúdo **vacuamente verdadeiro** (falsa noção de cobertura)

- **Local:** `api-ponto/test/controllers/admin/cascata_conteudo_test.rb:218-238`; contra-produção
  `admin/relatorio_terceirizados_controller.rb:20` e `admin/parcial_controller.rb:22` (`@registros = []`).
- **Problema:** as duas telas têm **fonte vazia por construção** (`@registros = []`). O assert
  `assert_select "td", { text: NOME_TERCEIRO, count: 0 }` é **sempre verdadeiro** — não há `td` algum, então
  não há o que vazar. Confirmado por mutação: **não falha** com o filtro da cascata neutralizado (Mutação A).
- **Risco concreto (duas camadas):** (i) **infla o critério de aceite** — o `iteration_33.md:296-302` conta
  "8 telas" cobertas, mas **2 dessas 8 não provam nada**; é exatamente a classe de defeito que a lição da 33.2
  ("teste que não prova o que nomeia") manda atacar. (ii) **Falso-negativo silencioso futuro:** quando a fonte
  real chegar, este teste **continuará verde** mesmo que a tela vaze um terceiro cujo nome **não** seja o
  `NOME_TERCEIRO` do teste (o assert só procura pelo nome do double, que nunca estará na fonte real).
- **Sugestão:** trocar o assert vácuo por **(a)** um teste de **contrato da tela hoje** (não-vacuidade):
  `assert_select "tbody tr", count: 0` (ou equivalente), provando que a tela renderiza vazio; **e/ou**
  **(b)** marcar como `skip`/TO-DO explícito ("sem fonte real — cobertura efetiva bloqueada pela tarefa da
  fonte"). O comentário de topo já registra a limitação — o rótulo do critério de aceite deveria refleti-la
  ("2/8 telas: assert de ausência trivial, sem valor probatório").

### 🟡 Médio — M1 — `/time_records` `:on`: a assertiva de **nome** é degenerada; a cascata não tem efeito observável nesta tela

- **Local:** `cascata_conteudo_test.rb:135-164` (assert (a) `count: 0` do nome) e `:166-186` (teste da degenerescência).
- **Problema:** a Mutação A **não** derruba a assert (a) nem o teste de `:off` — confirmado. O isolamento do
  terceiro em `/time_records` vem do escopo do não-admin (`time_records_controller.rb:66`,
  `where(user_id: current_user.id)`), que vale em **qualquer** estado da flag; sob `:on`, `restringir_frequencia`
  (`:64`) é aplicado **antes**, mas é **subsumido** pelo `where(user_id:)` da linha 66. Para admin, `restringir_frequencia`
  é no-op (visão global). Ou seja, **o filtro da cascata não muda o que `/time_records#index` exibe** — a assert
  de nome só passa porque o escopo já escondeu o terceiro, não por causa da cascata.
- **Risco concreto:** o nome do teste ("sob :on o terceiro … NÃO aparece") atribui à cascata uma garantia que
  ela não fornece. O autor **documentou** isso honestamente (Notas 33.3 (4); divergência (b)) — o que mitiga. Mas
  o critério de aceite `iteration_33.md:296-302` lista `/time_records` entre as telas "cobertas" sem essa ressalva.
- **Sugestão:** renomear para refletir o que prova (ex.: "…NÃO aparece — isolamento pelo escopo não-admin; ano do
  terceiro ausente do dropdown") e ajustar o critério de aceite para "coberto por escopo, não pela cascata".
  Manter a assert (b) (ano) — ela **tem** poder (falha sob Mutação B), embora cubra o bug do dropdown global,
  não a cascata.

### 🟡 Médio — M2 — Contagem reportada incorreta: `users_controller_test.rb` é **9 testes / 32 assertivas**, não 15/52

- **Local:** relato de implementação (fora do arquivo; o `iteration_33.md` cita apenas "9 testes / 37 assertivas"
  para o arquivo novo).
- **Medido:** `users_controller_test.rb` = **9 runs / 32 asserts**. `git show HEAD:` também tem **9** `test "`
  (o working tree também tem 9; o diff é 79+/6- e **um** teste foi **renomeado**,
  `usuario nao-admin ainda pode listar usuarios (read baseline)` → `…(conteudo sob :on)`).
- **Risco concreto:** nenhum no código — **nada foi mesclado nem removido indevidamente** (verificado por
  `git show HEAD`). É **só divergência de relato** (baixo impacto), mas confunde a rastreabilidade da suíte.
- **Sugestão:** corrigir o número reportado. O delta da suíte confere: `+9 runs` (arquivo novo) e `+43 asserts`
  (37 do arquivo novo + 6 do caso reescrito) → 1256/4387 → 1265/4430. ✅

### ⚪ Baixo — B1 — `assert_select` acoplado ao HTML (`td`, `option value=`, `select#filtro_ano`, `h3`)

- **Local:** todo o `cascata_conteudo_test.rb` (ex.: `:68`, `:162`, `:258`).
- **Problema:** a ausência do terceiro é provada pela **ausência de um `<td>`** — se o layout trocar `td` por
  `div`/`th`/`li`, a assert `count: 0` continua passando **pelo motivo errado** (nada casou), e o `:off` de
  controle `count: 1` quebraria (ruído). O contrato real ("o identificador não está no corpo") é mais forte que
  o seletor escolhido.
- **Risco concreto:** falso-verde em mudança de layout (a assert central sobrevive sem provar nada) + fragilidade
  na assert de contraste. `assert_select … text: NOME` casa por **substring** (String vira regex), mas os nomes
  são únicos e não colidem — o risco de falso-positivo por substring é baixo aqui.
- **Sugestão:** nas assertivas de **ausência**, somar um assert robusto e independente de layout:
  `refute_match NOME_TERCEIRO, response.body`. Mantém o `assert_select` para a prova de presença (contraste).

### ⚪ Baixo — B2 — `/dashboard`: o teste guarda o **gate admin**, não a cascata (rótulo)

- **Local:** `cascata_conteudo_test.rb:242-260`; contra-produção `dashboard_controller.rb:18` (`if current_user.admin?`)
  e `dashboard/index.html.erb:3` (`<% if current_user.admin? %>`) — verificado: o card "Últimas Batidas"
  (`h3`, view L167-226) está **integralmente** dentro do bloco admin-only; não existe o texto fora dele.
- **Problema:** a Mutação A não derruba o teste (confirma). O assert `count: 0` do `h3` "Últimas Batidas" prova
  que o **gate `current_user.admin?`** está de pé (e o `td` do terceiro ausente é consequência dele), **não** a
  cascata. É **coerente** com a dispensa justificada da 33.1 (`dashboard` = `:dispensado`) — o autor o declara.
- **Risco concreto:** baixo; nada de errado, apenas o rótulo pode induzir a leitura de que a cascata "cobre" o
  dashboard. Não é degenerado (pegaria a remoção do gate admin).
- **Sugestão:** comentar explicitamente "este assert é o gate admin-only (33.1), não a cascata".

### 💡 Sugestão — S1 — Duplicação de helpers de teste entre `cascata_conteudo_test.rb` e `users_controller_test.rb`

- **Local:** `cascata_conteudo_test.rb:30-52,320-351` vs. `users_controller_test.rb:153-185`
  (`PessoaDouble`, `VinculoDouble`, `com_visiveis`, `com_flag`, constantes de CPF/nome).
- **Problema:** os mesmos doubles e o mesmo helper `com_flag` (save/restore de ENV) são re-definidos nos dois
  arquivos. É duplicação de **infraestrutura de teste**, não do produto (o DRY da 33.5 é de `incluir_cpfs_com_cascata`).
- **Sugestão:** extrair para `test/support/` (ex.: módulo `CascataTestHelpers`) numa tarefa futura, se mais
  arquivos passarem a consumir. Não bloqueia.

## Elogios

- 🟢 **E1 — As 4 telas com fonte real têm poder comprovado por mutação.** Neutralizar o filtro da cascata
  (`frequencia_cascata_ligada? → false`) derruba **4 testes** de `cascata_conteudo_test.rb` + **1** de
  `users_controller_test.rb`. O contraste `:off x :on` é **real** (os controles `count: 1` / `"2"` passam sob
  `:off` e invertem sob mutação), não viciado: o `:off` prova que o **stub** entrega o terceiro, de modo que o
  `count: 0` sob `:on` só pode ser atribuído ao filtro da cascata.
- 🟢 **E2 — O furo da 33.2 está fechado.** O caso de `users#index` que sancionava o **200 sem conteúdo** foi
  reescrito e assere o corpo; e o `stub_vinculos` passou a **honrar `incluir_cpfs`** (espelha
  `scope.where(pessoas: { cpf: incluir_cpfs })`) — sem isso a assertiva seria degenerada. **Verifiquei que o
  endurecimento do stub NÃO enfraquece nenhum teste existente:** os demais casos do arquivo usam
  `stub_vinculos([])` (lista vazia), logo o filtro por `incluir_cpfs` é irrelevante para eles (resultado
  inalterado: 9/32/0F/0E).
- 🟢 **E3 — Honestidade do critério e footprint limpo.** O autor **declara** as divergências (b) e (c) e
  submete o contraste a "onde ele é verdadeiro" em vez de forçar um contraste falso — exatamente a resposta
  esperada à lição da 33.2, e **confirmada por mutação** (as 4 telas "fracas" realmente não falham). Padrões
  respeitados: stub só via `com_metodo_de_classe_stubado` (save/restore; **nenhum `remove_method`**),
  `test_helper.rb` intocado, `app/**`/`ability.rb`/`schema.rb`/rotas sem diff (`git diff` vazio).

## Ações corretivas

- [ ] **(Recomendado, 🟠 A1)** `/relatorio_terceirizados` e `/parcial`: substituir o assert vácuo por um assert
      não-vacuoso da tela vazia (`tbody` sem linhas) **ou** marcar como `skip`/TO-DO com motivo explícito; ajustar
      o critério de aceite `iteration_33.md:296-302` para **6/8 telas com valor probatório** (2 = ausência trivial).
- [ ] **(Recomendado, 🟡 M1)** Renomear o teste de `/time_records` `:on` para refletir que o isolamento vem do
      **escopo não-admin**, não da cascata.
- [ ] **(Opcional, 🟡 M2)** Corrigir a contagem reportada de `users_controller_test.rb` (9/32, não 15/52).
- [ ] **(Opcional, ⚪ B1/B2, 💡 S1):** somar `refute_match` no `response.body` nas assertivas de ausência;
      rotular o assert do dashboard como gate admin; extrair helpers duplicados para `test/support/`.
- [ ] **Nenhuma ação corretiva obrigatória** (sem Blockers).

## Nota de rastreabilidade

- Conforme as restrições do review, **não** alterei código, `iteration_33.md`, o plano aprovado nem ADRs.
  Este relatório é a fonte de verdade em `docs/quality/`; o registro no `iteration_33.md` (seção de review)
  fica a cargo do Orchestrator/Code Specialist.
- Mutações (concern `frequencia_authorization.rb`; `time_records_controller.rb`) foram aplicadas e
  **restauradas**; `git diff` de `app/**` = **vazio**; nenhum resíduo na árvore (confirmado por `git status`).
- Suíte completa medida neste review: **1265/4430/3F+12E/0 skip** (as 15 pré-existentes isoladas; delta +9/+43).
