# Relatório de Revisão — Tarefa 33.2 (Camada 2: meta-teste de drift + prova do gate)

**Revisor:** Code Reviewer (AI Workflow)
**Data:** 2026-10-15
**Branch de origem:** `feat/sprint-33-camada-2-meta-teste-drift` (working tree, **NÃO commitado** — `COMMIT_MODE=manual`)
**HEAD:** `ab19400`
**Repo/app:** `Frequencia/` — app `api-ponto/`
**Especificação medida contra:** `docs/progress/iteration_33.md` (tarefa 33.2 + "Notas de implementação (33.2)") +
`docs/progress/iteration_33_plano_autorizacao_32_O1.md` (§0.5, §2.2, §3, §5 T1/T2/T3, §7.1) +
`docs/quality/review_report_33_1.md` (M1/M2/M3) + `docs/quality/bug_report_33_1.md` (Bug 1, Obs. 1).

## Escopo revisado

| Arquivo | Natureza |
|---|---|
| `api-ponto/test/support/cobertura_cascata.rb` | testes (novo) — detector/meta-helper `CoberturaCascata` |
| `api-ponto/test/controllers/admin/cascata_cobertura_test.rb` | testes (novo, 15 testes) — meta-teste de drift |
| `docs/progress/iteration_33.md` | rastreabilidade (status 33.2 ✅ + notas) |

Fora de escopo (ruído de ambiente pré-existente à tarefa, **não** avaliado): `config/credentials.yml.enc`,
`config/environments/development.rb`, `log/*`, `tmp/cache/*` (idênticos ao ruído já listado no review da 33.1).

## Veredito

✅ **Aprovado** — **sem Blockers (🔴) e sem achados de severidade alta (🟠)**.

O ponto que mais importava — **o meta-teste é tautológico?** — foi verificado por **experimento adversarial**
(mutação do código real, não só leitura) e **não** se confirmou: o gate **falha de verdade** quando o código
regride. O detector `CoberturaCascata` fecha a **classe** do Bug 🔴1 exatamente como a 33.2 prometeu (T1/T2/T3,
M1 recursivo/por classe, M2 base+comentários, M3 runtime sem grep, flag-independência), com M1/M2/M3 do review
33.1 endereçados e footprint mínimo (`test_helper.rb`, `ability.rb`, schema, rotas e migrations intocados).

**Blockers: 0 | Sugestões: 8 (Melhoria: 4 / Débito: 0 — 4 🟡; Baixo: 4 ⚪; Sugestão: 3 💡) | Elogios: 3**

Os 🟡 são **limites/decisões de desenho** já parcialmente documentados nas notas da 33.2 ou no §"Riscos" do
plano — nenhum exige correção para aprovar. Recomendo registrar os itens M1/M3 como insumo da 33.3/33.x.

## Evidências executadas (medidas neste review)

| Verificação | Comando | Resultado |
|---|---|---|
| Meta-teste (baseline) | `bin/rails test test/controllers/admin/cascata_cobertura_test.rb` | **15 runs / 39 asserts / 0F / 0E / 0 skips** |
| Área admin | `bin/rails test test/controllers/admin` | **253 runs / 1348 asserts / 0F / 0E / 0 skips** |
| Suíte completa | `bin/rails test` | **1254 runs / 4383 asserts / 3F / 12E / 0 skips** (baseline 33.1: 1239/4344/3F+12E; delta +15/+39 = esta tarefa; 15 falhas pré-existentes) |
| RuboCop (tocados) | `bin/rubocop test/support/cobertura_cascata.rb test/controllers/admin/cascata_cobertura_test.rb` | **2 files inspected, no offenses** |
| Zeitwerk | `bin/rails zeitwerk:check` | **All is good!** |
| Prova D3 (prod intocado) | `git diff --stat -- app/models/ability.rb db/schema.rb config/routes.rb db/migrate/` | **vazio** |
| Varredura real do detector | `bin/rails runner` (exp.) | **14 varridos / 6 sensíveis / 0 drift** |

### Provas de **não-tautologia** (mutação do código real — arquivos restaurados ao final)

| # | Mutação injetada | Resultado do meta-teste |
|---|---|---|
| 4 | **Arquivo novo** sensível real em `admin/sub/novo_controller.rb` (lê `TimeRecord`, sem postura) | **2 falhas** (T2 árvore real + T2 "injetar") |
| 5 | Remover `include FrequenciaAuthorization` de `admin/frequencia_controller.rb` (`:coberto` real) | **3 falhas** (T2 real, T2 injetar, T3 recíproco) |
| 6b | Trocar a macro por `self.cascata_postura = :dispensado` em `admin/dashboard_controller.rb` (sem justificativa) | **2 falhas** (T2 real + T2 injetar) |

Resolução de classe **funciona** (processo limpo): o controller novo em subpasta resolveu para
`Admin::Sub::NovoController` e foi marcado como sensível+drift. `git diff` dos 3 arquivos mutados = **vazio**
(restauração confirmada); nenhum resíduo em `app/controllers`.

## Análise por requisito

1. **T1 — controller novo sem declaração FALHA** ✅ — arquivo sintético com `TimeRecord` sem declarar →
   `detectores == [arquivo]`. Provado também com arquivo **real** (Exp. 4).
2. **T2 — árvore real verde / injeção vermelha** ✅ — a varredura realmedida devolve **exatamente os 14
   controllers `Admin::*` concretos** (exclui a base abstrata, `Presenca::*`, `Users::*`, `api_controller.rb`,
   `application_controller.rb` raiz), **6 sensíveis** (`dashboard`, `frequencia`, `frequencia_por_orgao`,
   `frequentadores`, `time_records`, `users`), **0 drift**. Injeção real → vermelho.
3. **T3 — recíproco** ✅ — `:coberto` ⟺ `klass.include?(FrequenciaAuthorization)` em runtime; o stub
   `CobertoSemIncludeTestStubController` (`:coberto` sem concern) é reprovado; remover o `include` de um
   `:coberto` real → 3 falhas (Exp. 5). Não-vacuidade coberta por `refute_empty cobertos`.
4. **M1 — recursivo + por classe** ✅ — glob `**/*_controller.rb` + resolução pela **posição relativa**
   (`camelize.safe_constantize`), sem `descendants` (que seria falso-verde sem eager-load). Controller em
   subpasta real resolvido e reprovado (Exp. 3/4).
5. **M2 — base abstrata + comentários** ✅ — a base é excluída por não ser subclasse de si mesma
   (`arquivos_do_app` filtro `klass < Admin::ApplicationController`); `estacoes_controller.rb:4` (só comentário)
   → `sensivel? == false`; `dashboard` (código real) → `true` mas **declarado**.
6. **M3 — justificativa em runtime, sem grep** ✅ — `declarado?` lê `klass.cascata_justificativa` (runtime);
   um texto que **menciona** a macro mas cujo runtime é `nil` → **reprovado** (declaração morta). Provado por
   teste e por mutação real (Exp. 6b).
7. **Flag-independente** ✅ — `grep` confirmou que o helper/teste citam `FREQUENCIA_AUTORIZACAO_CASCATA` /
   `FREQUENCIA_CASCATA_ENFORCEMENT` **apenas em comentários e no próprio teste** (`com_env`); o detector **não**
   referencia nenhuma das duas.
8. **Sem regressão / padrões** ✅ — suíte **1254/4383/3F+12E** (delta = +15/+39 desta tarefa); RuboCop 0;
   zeitwerk OK; `test_helper.rb` **não** alterado (carga por `require_relative`, sem `parallelize` novo);
   nenhum `remove_method`.
9. **Bug 1 do bug_report_33_1 (postura herdada) — CLASSE fechada na 33.1** ✅ (verificado) — o hook
   `self.inherited` da 33.1 zera `cascata_postura`/`cascata_justificativa` em toda subclasse: um
   `class X < Admin::DashboardController` fica com postura `nil` → `declarado? == false` → o detector **flagga**.
   Portanto o meta-teste da 33.2 **não** herda o falso-verde apontado pelo Bug Finder.

## Apontamentos

### 🟡 Melhoria — M1 — A exclusão é por **ancestralidade**, não por caminho: um controller sensível fisicamente sob `admin/` que **não** herde a base escapa

- **Local:** `api-ponto/test/support/cobertura_cascata.rb:90-98` (filtro `next unless klass.nil? || (klass.is_a?(Class) && klass < Admin::ApplicationController)`).
- **Problema:** o detector decide a **inclusão** pela posição na hierarquia de classes. Um arquivo em
  `app/controllers/admin/foo_controller.rb` cuja classe seja `Admin::FooController < ::ApplicationController`
  (herdou a base **raiz**, não a admin) resolve a constante — e é **descartado** por não ser `< Admin::ApplicationController`.
- **Risco concreto:** falso-negativo na exata classe que a 33.2 fecha ("um controller `Admin::*` que lê
  frequência sem declarar"). Esse controller também **não** teria o guard de runtime (que vive na base admin),
  logo nem a Camada 1 o pega. É um cenário atípico (sem layout/guard), mas plausível num arquivo novo colocado
  "no lugar errado".
- **Sugestão:** complementar a regra com um critério **por caminho** — por exemplo, sinalizar qualquer
  `*_controller.rb` sob `app/controllers/admin/**` cuja classe **não** herde a base (ou cujo `klass` seja `nil`),
  e manter a base abstrata excluída por identidade (`klass == Admin::ApplicationController`). Se mantiver só
  ancestralidade, registrar este limite explicitamente nas Notas (hoje as Notas citam indireção, não isto).

### 🟡 Melhoria — M2 — O conjunto sensível é uma **lista paralela** (strings) de `Ability::RECURSOS_FREQUENCIA`

- **Local:** `api-ponto/test/support/cobertura_cascata.rb:33-39` (`RECURSOS_SENSIVEIS`) vs.
  `api-ponto/app/models/ability.rb:74-79` (`RECURSOS_FREQUENCIA`).
- **Problema:** o conjunto fechado do detector **duplica** os nomes dos recursos de produção como strings (a
  `Ability` não inclui `Pessoas::Vinculo`, que foi adicionado à mão — Q33-C). O teste "conjunto fechado" asserta
  a lista **literal** (`cascata_cobertura_test.rb:44-48`), então ele **não** detecta se a `Ability` adicionar um
  recurso novo e o detector ficar para trás.
- **Risco concreto:** se um recurso de frequência for adicionado a `RECURSOS_FREQUENCIA` (prod) sem ser
  adicionado a `RECURSOS_SENSIVEIS`, um controller que leia só esse recurso **não** é marcado como sensível →
  falso-negativo silencioso (build verde indevido).
- **Sugestão:** derivar o conjunto de `Ability::RECURSOS_FREQUENCIA.map(&:name) + ["Pessoas::Vinculo"]` (ou
  assertar igualdade entre os dois no teste), preservando a intenção de "fonte única" já declarada no contrato
  (§0.5/R2 fala em "sem lista paralela").

### 🟡 Melhoria — M3 — `skip_before_action :verificar_postura_cascata` não é detectado (limite da Camada 1; registrar como débito)

- **Local:** `api-ponto/test/controllers/admin/cascata_cobertura_test.rb` (nenhum teste) e
  `api-ponto/app/controllers/admin/application_controller.rb:78` (o `before_action` que pode ser pulado).
- **Problema:** um controller `Admin::*` pode anular o gate de runtime com uma linha
  (`skip_before_action :verificar_postura_cascata`) e continuar "declarado"/"sensível" aos olhos do meta-teste.
  É a Observação 1 do `bug_report_33_1.md`, reconhecida como limite inerente à Camada 1; as Notas da 33.2 a
  listam como limite declarado (ponto 10).
- **Risco concreto:** o build passa e o guard é neutralizado no runtime — defesa em profundidade furada.
- **Sugestão:** registrar como **débito explícito** no `iteration_33.md` (ou criar um teste barato que reprove
  um `skip_before_action :verificar_postura_cascata` no conjunto varrido). É uma decisão de escopo (a 33.2 não
  foi encarregada disto) — por isso 🟡, não 🟠.

### 🟡 Melhoria — M4 — Doc vs comportamento: "ignora linhas de comentário" — só o comentário de **linha inteira** é ignorado

- **Local:** `api-ponto/test/support/cobertura_cascata.rb:119-121` (`linhas_de_codigo` usa
  `linha.strip.start_with?("#")`).
- **Problema:** um recurso citado com **comentário no fim da linha** (`foo # TimeRecord`) **conta** como
  sensível (direção fail-closed, verificada). O critério de aceite M2 / §2.2 falam em "ignorar linhas de
  comentário" e "um recurso citado em comentário não conta" — a implementação só cumpre a parte
  "comentário de linha inteira".
- **Risco concreto:** baixo no estado atual (todo controller admin **declara** postura, então a
  sobre-inclusão não gera drift); o risco residual é um falso-positivo num arquivo **não-resolvível** (ver B1)
  e a divergência documento×código (um leitor futuro pode achar que comentário de fim de linha é ignorado).
- **Sugestão:** alinhar a redação (documentar que só comentário de **linha inteira** é ignorado, e que
  comentário no fim da linha é sobre-inclusão **intencional**/fail-closed) **ou** estender `linhas_de_codigo`
  para truncar comentários de fim de linha (mais arriscado: heurística de string/heredoc). Preferir documentar.

### ⚪ Baixo — B1 — `klass.nil?` mantém arquivos: `*_controller.rb` que não resolve e cita recurso vira "drift" (falso-positivo)

- **Local:** `api-ponto/test/support/cobertura_cascata.rb:93-94`.
- **Problema:** um `*_controller.rb` cujo símbolo não resolve (nome de classe divergente do caminho, erro de
  carregamento) é **mantido** (fail-safe) e, se citar um recurso, é reportado como drift — sem distinguir
  "controller novo sem postura" de "arquivo que nem carrega".
- **Risco concreto:** falso-positivo em arquivo auxiliar em `app/controllers/**` que casa `*_controller.rb` mas
  não é controller; a mensagem "drift" confunde o diagnóstico. Hoje não ocorre (o conjunto real é exatamente os
  14 admin).
- **Sugestão:** manter o fail-safe, mas diferenciar a mensagem/asserção (ex.: separar "não resolvido" de
  "sensível sem postura") para não mascarar um erro de carregamento como violação de contrato.

### ⚪ Baixo — B2 — T2 sem guarda de **não-vacuidade** na árvore real

- **Local:** `api-ponto/test/controllers/admin/cascata_cobertura_test.rb:75-81`.
- **Problema:** T2 asserta `arquivos.size >= 10` e `detectores == []`, mas **não** asserta que há itens
  **sensíveis** (e declarados) na árvore real. Se a sensibilidade regredisse para "tudo `false`" na árvore real,
  T2 continuaria verde. O T3 tem a contraparte (`refute_empty cobertos`); o T2 não.
- **Risco concreto:** falso-verde num cenário de regressão combinada. Mitigado pelo teste "conjunto fechado"
  (asserta a lista) + T1 (asserta `sensivel?` verdadeiro), então o impacto é baixo.
- **Sugestão:** adicionar ao T2 um `refute_empty` sobre os sensíveis reais (ex.: `>= 5`), simétrico ao T3.

### ⚪ Baixo — B3 — O teste M1 de subpasta passa pelo ramo `klass.nil?`, não pela **resolução de classe**

- **Local:** `api-ponto/test/controllers/admin/cascata_cobertura_test.rb:123-136`.
- **Problema:** o arquivo sintético é criado em `Dir.mktmpdir`, que **não** está no autoload path → 
  `Admin::Sub::NovoController` **não** é resolvido → `klass == nil` → o arquivo é mantido pelo fail-safe e
  reprovado. Ou seja, o caso passa a despeito da resolução de classe, não por causa dela; o nome do teste
  promete "por classe" e prova só o glob recursivo + o keep de `nil`.
- **Risco concreto:** uma regressão em `classe_do_controller` **não** seria pega por este teste. (Compensação
  medida: se a resolução quebrasse por completo, a base `application_controller.rb` — sensível pelo menu — seria
  mantida como `nil` e o **T2 real falharia**; logo, há cobertura indireta.)
- **Sugestão:** provar a resolução de classe com um arquivo real em processo limpo (o Exp. 3 deste review
  mostrou que funciona) ou assertar explicitamente `klass == nil` no caso do tmpdir para deixar o mecanismo claro.

### ⚪ Baixo — B4 — O teste "flag-independente" é quase-tautológico

- **Local:** `api-ponto/test/controllers/admin/cascata_cobertura_test.rb:188-200`.
- **Problema:** o teste asserta que o resultado é o mesmo sob {off, shadow, on} × {log, raise}. Como o detector
  é **função pura do conteúdo/classe** e nunca lê ENV, o teste não pode falhar pelas razões amostradas (só se
  alguém introduzir leitura de flag que mude entre esses valores).
- **Risco concreto:** nenhum (é um guarda fraco, não um defeito). A independência real está garantida por
  **ausência de leitura** (verificado por `grep`).
- **Sugestão:** opcional — reforçar com um `grep`/assert de que o helper não referencia as duas variáveis (o
  comentário já documenta a intenção).

### 💡 Sugestão — S1 — Redundância/overlap com o teste (6) da 33.1

- **Local:** `test/controllers/admin/cascata_enforcement_test.rb:152-160` (`"todo controller Admin::* declara
  postura"`, via glob top-level + `File.basename(...).camelize`) vs. o T2 da 33.2.
- **Problema:** o teste da 33.1 é um **subconjunto mais fraco** do T2 da 33.2 (exatamente a abordagem que M1
  apontou como frágil). Não é defeito (redundância defensiva), mas some ao inventário.
- **Sugestão:** considerar consolidar/substituir o teste (6) da 33.1 pelo T2 da 33.2 numa tarefa futura.

### 💡 Sugestão — S2 — Derivar `RECURSOS_SENSIVEIS` de `Ability::RECURSOS_FREQUENCIA` (ver M2).

### 💡 Sugestão — S3 — `test/support` fora do `test_helper` é adequado (footprint mínimo); se mais testes passarem a consumir `CoberturaCascata`, mover o `require` para o `test_helper` evita `require_relative` repetido por arquivo.

## Elogios

- 🟢 **E1 — Prova de não-tautologia embutida no deliverable e confirmada por mutação.** O detector puro
  (`detectores` sobre `Arquivo`) permite os testes sintéticos; verifiquei por **mutação do código real** que o
  gate falha de verdade (injeção de controller novo → 2 falhas; remoção de `include` → 3 falhas; `:dispensado`
  sem justificativa → 2 falhas). O meta-teste **não** é um espelho do próprio módulo.
- 🟢 **E2 — M3 fechado por runtime, com prova explícita de "declaração morta".** O teste M3 usa um texto que
  menciona `fora_da_cascata_justificativa("…")` **mas** com `cascata_justificativa == nil` → reprovado; é a
  demonstração de que a checagem lê o atributo de runtime, não o fonte. Fecha o M3 do review 33.1 com evidência,
  não com promessa.
- 🟢 **E3 — Fonte única + footprint mínimo.** O detector **consome a declaração da 33.1** (`cascata_postura` /
  `cascata_justificativa`) sem allow-list paralela; `test_helper.rb`, `ability.rb`, schema, rotas e migrations
  intocados; carga do helper por `require_relative` (não acopla a suíte); nenhum `remove_method` (respeita a
  lição do projeto).

## Ações corretivas

- [ ] **Nenhuma ação corretiva obrigatória** (sem Blockers e sem 🟠).
- [ ] (Recomendado, pós-33.2) **M1:** complementar a regra de inclusão com critério **por caminho** para
  `app/controllers/admin/**` (ou registrar o limite explicitamente nas Notas).
- [ ] (Recomendado, pós-33.2) **M2:** alinhar `RECURSOS_SENSIVEIS` a `Ability::RECURSOS_FREQUENCIA`
  (elimina a lista paralela; preserva §0.5/R2).
- [ ] (Orchestrator/33.x) **M3:** registrar o `skip_before_action :verificar_postura_cascata` como **débito**
  explícito (Observação 1 do `bug_report_33_1.md`).
- [ ] (Opcional) **M4/B1/B2/B3/B4/S1/S2/S3:** ajustes de doc de teste e reforço de não-vacuidade.

## Nota de rastreabilidade

- Conforme as restrições do review, **não** alterei código, `iteration_33.md`, o plano aprovado nem ADRs.
  Este relatório é a fonte de verdade em `docs/quality/`; o registro no `iteration_33.md` (seção de review)
  fica a cargo do Orchestrator/Code Specialist.
- Experimentos de mutação (arquivos temporários em `app/controllers/` + `Dir.mktmpdir` + `bin/rails runner`)
  foram executados e **removidos**; `git diff` dos 3 controllers mutados = **vazio**; nenhum resíduo na árvore.
