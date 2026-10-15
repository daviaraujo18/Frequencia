## Relatório Bug Finder — Sprint 33 (tarefa 33.1) — guard fail-closed + contrato de postura da cascata

> **Branch:** `feat/sprint-33-camada-1-guard-cascata` (working tree, **NÃO commitado** — `COMMIT_MODE=manual`)
> **Data:** 2026-10-15
> **Alvo (Camada 1, runtime):** `api-ponto/app/controllers/concerns/frequencia_authorization.rb` (hook `included`),
> `api-ponto/app/controllers/admin/application_controller.rb` (`class_attribute`, macro `fora_da_cascata_justificativa`, guard `verificar_postura_cascata`),
> `api-ponto/app/models/frequencia_cascata_enforcement.rb` (PORO da flag `FREQUENCIA_CASCATA_ENFORCEMENT`),
> `api-ponto/app/models/cascata_nao_declarada_error.rb`, os 14 controllers `Admin::*` anotados,
> `api-ponto/test/controllers/admin/cascata_enforcement_test.rb` (14 testes).
> **Propósito:** teste adversarial da tarefa 33.1 — herança de `class_attribute`, resíduo de `cascata_justificativa`,
> valores da flag de enforcement, `Rails.env`/`CI`, bypass por `skip_before_action`, ordem dos `before_action`
> (guard × `require_login` × `check_authorization`), herdeiros fora de `admin/`, vazamento de mensagem/erro e falha em cascata.
> **Não duplica** o `review_report_33_1.md` (M1–M4/B1/S1/S2 — insumos da 33.2, doc do kill-switch, instance accessor, teste tautológico).
> **Restrições respeitadas:** nenhuma correção, nenhum commit/push, nenhuma alteração em código de produção. Sondas
> exploratórias rodadas via `bin/rails runner` e um teste temporário (removidos ao final; árvore limpa).

### Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 9 ângulos adversariais + 8 cenários de análise + 14 testes da 33.1 |
| Bugs NOVOS com impacto hoje (bloqueantes) | **0** |
| 🔴 Crítico | 0 |
| 🟠 Alto | 0 |
| 🟡 Médio | 2 (herança de postura por subclasse; valores "de ligar" do kill-switch falham aberto) |
| 🟢 Baixo | 1 (`ENV["CI"].present?` trata `CI=false`/`CI=0` como ligado) |
| ⚪ Info / Observação | 3 (resíduo de `cascata_justificativa`; bypass por `skip_before_action`; 500 genérico / herança na base) |

**Veredito curto:** **nenhum bug bloqueante** — a 33.1 está correta nos caminhos que o app exercita hoje (os 14
controllers `Admin::*` declaram postura; o guard é no-op em produção). Os 2 achados 🟡 são **latentes** (não
explorados pela árvore atual, pois nenhum controller herda de outro concreto e nenhum operador setou valores
"de ligar" não reconhecidos) e são **insumos de robustez** para a Camada 2 (33.2) e para a operação. **Nada
contradiz** o veredito do review (0 blockers).

---

## Bugs por Severidade

### 🟡 Bug 1 — Postura de cascata é HERDADA por subclasse de controller concreto (falso-verde no guard e na Camada 2)

- **Severidade:** 🟡 Médio (latente — nenhum controller herda de outro concreto HOJE; reproduzido por sonda)
- **RF/RN violado:** contrato de declaração por controller da 33.1 (D1/D4 — "a postura é por controller"); risco 🟠 da
  §"Riscos" do `iteration_33.md` ("um controller admin escapa da anotação").
- **Arquivos:** `api-ponto/app/controllers/admin/application_controller.rb:27` (`class_attribute :cascata_postura`) e
  `:34` (`class_attribute :cascata_justificativa`); `api-ponto/app/controllers/concerns/frequencia_authorization.rb:31-34` (hook `included`).
- **Passos (reprodução via `bin/rails runner`):**
  1. `class FilhoDeDispensado < Admin::DashboardController; end`
  2. `FilhoDeDispensado.cascata_postura`  → `:dispensado`
  3. `FilhoDeDispensado.cascata_justificativa` → `"corpo gateado por current_user.admin? (passo 2 — visão global); não vaza a não-admin"` (**justificativa do PAI**)
  4. (inverso) `class FilhoDeCoberto < Admin::FrequenciaController; end` → `FilhoDeCoberto.cascata_postura` → `:coberto`
- **Atual:** `class_attribute` propaga o valor do pai. Um controller novo que herde de um `Admin::*` **concreto** e
  **não declare nada** passa no guard (`cascata_postura.present?` → herda `:dispensado`/`:coberto` do pai) e, no caso
  `:dispensado`, exibe a **justificativa do pai** (que pode ser falsa para o filho — ex.: um filho de `DashboardController`
  que leia `TimeRecord` fora do gate `current_user.admin?`). O meta-teste da 33.2 que use `Admin::ApplicationController.descendants`
  (M1 do review) também verá a subclasse como "declarada" (herdada) → **verde falso**.
- **Esperado:** cada controller **concreto** deveria declarar a própria postura; herdar a do pai por acidente não deveria
  satisfazer o contrato (sem justificativa própria para um `:dispensado`).
- **Nuance honesta:** um filho de um controller `:coberto` (ex.: `Admin::FrequenciaController`) **herda também os métodos
  do concern** (o `include` é herdado), então `:coberto` é *correto em comportamento* para esse caso específico. O risco real
  está no eixo `:dispensado`: a **justificativa herdada** pode não se aplicar ao filho, e nada força o filho a justificar.
- **Teste sugerido (33.2):** assertar que a postura NÃO é herdada de um ancestral concreto — ex.: exigir que a classe
  seja owner direto do `class_attribute` (`klass.instance_variable_get(:@cascata_postura)`/`klass.singleton_class`...) ou
  que todo `descendants` sensível tenha declaração **própria** (`klass.cascata_justificativa` presente quando `:dispensado`,
  e `klass.singleton_class.ancestors` diferente do pai); cobrir com arquivo sintético `class Admin::X < Admin::DashboardController` que lê `TimeRecord`.

---

### 🟡 Bug 2 — Valores "de LIGAR" do kill-switch falham ABERTO (fail-open silencioso num gate de segurança)

- **Severidade:** 🟡 Médio (documentado, mas armadilha de confiança falsa; fail-open = default)
- **RF/RN violado:** expectativa do operador de que `FREQUENCIA_CASCATA_ENFORCEMENT` **ligue** o fail-closed; D2 (fail-closed sob `raise`).
- **Arquivos:** `api-ponto/app/models/frequencia_cascata_enforcement.rb:29` (`VALORES_RAISE = %w[raise levantar]`) e `:33-39` (`modo`).
- **Passos (reprodução via `bin/rails runner`):** iterar `ENV["FREQUENCIA_CASCATA_ENFORCEMENT"]` sobre
  `on`, `ON`, `true`, `1`, `yes`, `enabled`, `ativo`, `fail`, `strict` e ler `FrequenciaCascataEnforcement.modo`.
- **Atual:** **todos** caem em `:log` (fail-**OPEN** — apenas `Rails.logger.warn`, não levanta). Só `raise`/`levantar` ligam o gate.
  Um operador que setar `FREQUENCIA_CASCATA_ENFORCEMENT=on`/`true`/`1` — o vocabulário mais natural para "ligar" — recebe
  **modo observação silencioso**, achando que o gate está duro.
- **Esperado:** ou reconhecer um conjunto de valores "de ligar" (`on/true/1/yes/enabled/...`) como `:raise`, ou **falhar
  ruidosamente** (`raise ArgumentError` / abort do boot) para valor não reconhecido, em vez de degradar para fail-open.
- **Distinção do M4 do review:** M4 cobre o eixo "**desligar**" (`off` → continua WARN, não há modo silencioso). Este achado
  é o eixo **oposto e mais perigoso** — "**ligar**" digitado com palavra comum produz **fail-open**, contrariando a intenção.
  O `iteration_33.md` §"Compatibilidade e rollback" formaliza "qualquer valor diferente de raise/levantar ... cai em :log",
  então é comportamento **documentado** — por isso 🟡 e não 🟠.
- **Teste sugerido:** teste unitário que asserta o contrato para valores de ligar comuns (ou que asserta o `raise` em valor
  desconhecido, se a equipe preferir endurecer).

---

### 🟢 Bug 3 — `ENV["CI"].present?` trata `CI=false` / `CI=0` como "CI ligado" → default `:raise` em produção

- **Severidade:** 🟢 Baixo (hoje inócuo — todos os controllers declaram; latente para controller novo)
- **RF/RN violado:** default "1º deploy de produção = `:log`" (D2/documentação do PORO).
- **Arquivos:** `api-ponto/app/models/frequencia_cascata_enforcement.rb:55-57` (`padrao` → `Rails.env.test? || ENV["CI"].present?`).
- **Passos (reprodução via `bin/rails runner`, fora de test):**
  1. `ENV.delete("FREQUENCIA_CASCATA_ENFORCEMENT"); ENV["CI"] = "false"` → `FrequenciaCascataEnforcement.modo` → `:raise`
  2. `ENV["CI"] = "0"` → `:raise`
- **Atual:** `ActiveSupport` `present?` considera `"false"`/`"0"` **presentes** → o ambiente é tratado como CI e o default
  vira **fail-CLOSED** (`:raise`). Em produção (sem a flag explícita) com `CI=false`/`CI=0` no ambiente, o default deveria
  ser `:log` (observação) mas vira `:raise` — um controller novo sem postura passaria a responder **500** num ambiente que
  o operador julgava em observação.
- **Esperado:** o default proteger-se contra o valor-string: `ENV["CI"] == "true"` (ou `!~ /\A(false|0|no|)\z/i`), em vez de `present?`.
- **Nota:** também vale a direção oposta (um `ENV["CI"]` *setado por engano* em produção — ex.: imagens buildadas em CI que
  persistem a var — ligaria fail-closed inesperadamente). Com todos os controllers declarados, o guard é no-op e o impacto é nulo hoje.
- **Teste sugerido:** cenário que remove a flag explícita e asserta `:log` para `CI=false`/`CI=0` fora de test.

---

### ⚪ Info — resíduo de `cascata_justificativa`: o invariante "nil a menos que `:dispensado`" não é garantido

- **Severidade:** ⚪ Info (estado não alcançável pela árvore atual)
- **Arquivos:** `api-ponto/app/controllers/admin/application_controller.rb:32-33` (comentário: "`nil` quando a postura não é `:dispensado`"),
  `:44-45` (macro seta o motivo) e `api-ponto/app/controllers/concerns/frequencia_authorization.rb:31-34` (hook **não** reseta `cascata_justificativa`).
- **Descrição:** um controller que chame `fora_da_cascata_justificativa("…")` **e também** inclua `FrequenciaAuthorization`
  fica com `cascata_justificativa` residual ≠ `nil` (a postura resultante depende da ordem das duas linhas). O comentário
  do código afirma o invariante "nil quando não é `:dispensado`", mas nada o impõe. Também: um filho de um `:dispensado`
  herda a justificativa do pai (ver Bug 1). Não ocorre hoje (nenhum controller combina macro + include).
- **Sugestão:** no hook `included`, resetar `self.cascata_justificativa = nil` ao marcar `:coberto`; e/ou assertar o invariante na 33.2.

---

### ⚪ Observação 1 — bypass do guard via `skip_before_action :verificar_postura_cascata`

- **Arquivos:** `api-ponto/app/controllers/admin/application_controller.rb:78`.
- **Descrição:** um controller `Admin::*` pode anular o gate com uma linha (`skip_before_action :verificar_postura_cascata`).
  Grep confirma que **nenhum** controller faz isso hoje (só `Admin::SessionsController:8-9` skippa `require_login`/`verify_authenticity_token`).
  O meta-teste da 33.2, como especificado, **não** detecta esse skip. É uma limitação inerente à Camada 1 (defesa em profundidade).
  Registrar como risco residual conhecido (ver §"Riscos" do `iteration_33.md`).

### ⚪ Observação 2 — `CascataNaoDeclaradaError` → 500 genérico, sem `rescue_from` (intencional, sem vazamento)

- **Arquivos:** `api-ponto/app/controllers/admin/application_controller.rb:84` (único `rescue_from` = `CanCan::AccessDenied`).
- **Descrição:** a exceção do guard **não** é resgatada por nada → propaga como 500. Em **produção**
  (`config.consider_all_requests_local = false`, `production.rb:13`) a resposta é o 500 genérico do Rails — a mensagem
  (que inclui `self.class.name`) **não** vaza ao usuário final, só ao log. É o comportamento fail-closed esperado. Confirmado: nenhum
  `rescue_from` genérico (`StandardError`/`Exception`) que pudesse "engolir" o guard (a falha em cascata não é mascarada).

### ⚪ Observação 3 — herdar postura na BASE anularia o guard para toda a árvore

- **Arquivos:** `api-ponto/app/controllers/admin/application_controller.rb:27`.
- **Descrição:** a base é `nil` **de propósito** (documentado). Se alguém — por engano — chamar
  `Admin::ApplicationController.fora_da_cascata_justificativa("…")` (ou setar um default não-nil), **todos** os filhos
  herdariam `:dispensado` e o guard viraria **no-op global** silencioso. Footgun de manutenção; não há guarda contra isso.
  Vale uma nota/assert no meta-teste da 33.2 (`Admin::ApplicationController.cascata_postura` deve permanecer `nil`).

---

## Cenários Testados (sem bugs)

1. **Ordem dos `before_action` (ângulo 6) — SEM BUG.** Callbacks reais da base: `verify_authenticity_token` →
   (proc breadcrumbs) → `require_login` → `set_configurations` → `verificar_postura_cascata`; o
   `check_authorization` do CanCanCan é registrado como **`after`** (`cancancan-3.6.1/.../controller_additions.rb:266`) →
   o guard precede a checagem CanCan. Teste temporário (removido): requisição **não autenticada** a um controller
   `Admin::*` **sem postura** sob `FREQUENCIA_CASCATA_ENFORCEMENT=raise` → **`302` para `/login`** (não 500, não
   `CascataNaoDeclaradaError`). `require_login` (que chama `redirect_to`) **halta** a cadeia antes do guard → **sem
   vazamento de info e sem 500** para visitante.
2. **`Presenca::*` (ângulo 7) — SEM BUG.** `Presenca::ApplicationController < ::ApplicationController` (não herda admin);
   `respond_to?(:cascata_postura)` → `false`; o guard **não** está na cadeia de callbacks dela. Confirmado por sonda.
3. **Herdeiros fora de `app/controllers/admin/` (ângulo 7) — SEM BUG.** Grep de `< Admin::ApplicationController` em
   todo `app/` só retorna os 14 controllers de `app/controllers/admin/`; nenhum controller raiz (`api_controller.rb`,
   `application_controller.rb`) herda a base admin.
4. **Cobertura de anotação — SEM BUG.** 14/14 controllers `Admin::*` concretos declaram: 7 `:coberto` (via `include`) +
   7 `:dispensado` (via macro). Nenhum deixa o guard levantar na suíte.
5. **Valores de `raise` (case/whitespace) — SEM BUG.** `raise`, ` RAISE`, `Raise`, `raise `, `levantar` → `:raise`
   (`strip.downcase` cobre). `tab`/`""` → default do ambiente.
6. **No-op para declarados — SEM BUG.** `:coberto` e `:dispensado` → `nil` (sem WARN); undeclared sob `log` → **exatamente 1** WARN.
7. **Macro exige justificativa — SEM BUG.** `""`/`nil`/`"   "` → `ArgumentError`; a classe **não** é marcada quando a macro falha.
8. **Desacoplamento da flag de cascata (D2) — SEM BUG.** O guard referencia apenas `FrequenciaCascataEnforcement`; não há
   leitura de `FrequenciaAutorizacaoCascata`/`FREQUENCIA_AUTORIZACAO_CASCATA` no caminho do guard (`application_controller.rb:101-108`).
9. **`Ability`/schema/rotas/migrations — SEM BUG.** Nenhum indício de alteração; fora do meu mandato re-medir `git diff`, mas a
   leitura do código confirma que não há acoplamento com `Ability`.

---

## Nota de rastreabilidade

- Conforme as restrições da tarefa, **não** alterei `docs/progress/iteration_33.md` (nem testes, nem o plano, nem ADRs).
  Este relatório é a fonte de verdade em `docs/quality/`; o registro no `iteration_33.md` (seção de bugs) fica a cargo do
  Orchestrator/Code Specialist.
- Sondas exploratórias (`bin/rails runner` + 1 teste temporário de integração) foram executadas e **removidas**; a árvore
  de trabalho não contém resíduos.

## Ações corretivas

- [ ] **Nenhuma ação corretiva obrigatória para a 33.1** (0 blockers; nada contradiz o review).
- [ ] (33.2) Cobrir o **Bug 1** — postura herdada de ancestral concreto não deve satisfazer o contrato; exigir declaração **própria**.
- [ ] (Operação/33.x) Endurecer a leitura da flag (**Bug 2/Bug 3**): reconhecer valores "de ligar" ou falhar ruidosamente em
  valor desconhecido; corrigir `ENV["CI"].present?` para não tratar `"false"`/`"0"` como ligado.
- [ ] (33.2) Assertar os invariantes das Observações 1/3 (base permanece `nil`; detectar `skip_before_action`).
