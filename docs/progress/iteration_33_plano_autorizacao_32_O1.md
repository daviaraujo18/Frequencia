# Plano de Autorização — Candidato `32.O1` (enforcement opt-in da cascata)

> **[⌂ Home](../README.md)** · Candidato **32.O1** · Horizonte 33+ (agendado para a Sprint 33 por decisão do dev, 2026-10-15)
> **Status:** 📝 **PLANO / DESIGN — aguardando aprovação explícita do dev.** Nada implementado.
> **Escopo:** design **only**. Este documento **não** altera `app/`, rotas, testes, `Ability` nem a flag. É o
> insumo exato do `iteration_33.md` (a ser detalhado pelo Sprint Planner **somente após** o aval) e da
> implementação (Code Specialist).
> **Rastreabilidade:** `ADR-0010` **regra 9** + emenda 2026-10-08 · `implementation_plan.md` v2 (risco
> "Enforcement opt-in da cascata" — 🟠 Alto; candidato ao horizonte 33+) · `docs/progress/iteration_30.md`
> §"Débito ESTRUTURAL" · `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md` (Bug 🔴1) ·
> `docs/progress/iteration_32.md` §"Situação da Sprint 33".

> **Regra global satisfeita:** a alteração **toca autorização**; por isso exige **plano claro + aprovação
> explícita do dev ANTES de qualquer código** (`CLAUDE.md` do workspace, item 9). A ordem é
> **este plano → aprovação → `iteration_33.md` (Sprint Planner) → implementação (Code Specialist)**.

---

> # ✅ ARTEFATO ÚNICO PARA APROVAÇÃO DO DEV
> Este é o **único** documento que o dev aprova para o `32.O1`. Ele **reconcilia** duas análises
> independentes: o **Plano de Autorização do CTO** (este arquivo) e o **design do `iteration_33.md`**
> produzido pelo Sprint Planner. A **§0.5** registra as convergências e resolve as divergências.
> **Ordem decidida pelo dev:** este plano → **aval** → o Sprint Planner **refaz o `iteration_33.md`**
> alinhado ao que for aprovado → só então o Code Specialist implementa. **Nada de código antes do aval.**

## 0.5 Reconciliação das duas análises (coordenador, 2026-10-15)

**Contexto:** por uma falha de sequenciamento minha, o Orchestrator disparou o Sprint Planner **antes**
do aval, e existiram **duas** análises concorrentes deste mesmo débito. Elas **convergem no essencial** e
divergiam em 5 pontos de desenho. Abaixo, o que foi **unificado** e o que **sobra como decisão do dev**.

### Convergências (adotadas sem alteração)
1. **O furo:** `authorize! :read, :all` satisfaz o `check_authorization` — o leak é do **`:all`**, não do
   check por classe (ver correção na §0.1).
2. **Duas camadas:** (1) **runtime** — declaração explícita por controller + guard fail-closed;
   (2) **build** — teste estrutural **flag-independente**.
3. **`Ability` intocada** (D3 = não).
4. **O `include FrequenciaAuthorization` vira o opt-in** (hook `included`) — os 7 controllers atuais
   passam a declarar **sem tocar seus corpos**.
5. **Allow-list explícita e justificada** para quem não participa (`dashboard` = corpo gateado por
   `admin?`; `/presenca/*` = pré-sessão, Bug 🟠2 = risco aceito).
6. **Conjunto fechado de recursos:** `TimeRecord`, `CalculoDiario`, `RegistroMensalFrequencia`,
   `IntervencaoFrequencia`, **`Pessoas::Vinculo`** (Q33-C = **sim**).
7. **Exclusões:** sem `:on` production-wide; sem tocar regras da cascata/roles; sem Bug 🟠2.

### Divergências → decisão reconciliada
| # | Divergência | CTO (este plano) | Sprint Planner (`iteration_33.md`) | **Reconciliação** |
|---|---|---|---|---|
| **R1** | Granularidade da declaração | postura **por controller** (`:coberto`/`:dispensado`) | participação por controller **+ `toca_frequencia only:[…]` por action** | **Postura por controller** (simples, suficiente). O `toca_frequencia` por action fica como **refinamento opcional**, **não** no escopo inicial (D4). |
| **R2** | Como dispensar | macro `fora_da_cascata_justificativa(motivo)` — **motivo obrigatório no código** | allow-list no teste | **Macro com motivo obrigatório**; a allow-list do teste **lê a mesma declaração** (fonte única, sem lista paralela). |
| **R3** | Quando o guard **nega** | **fail-closed sempre** (rollout `log`→`raise`) | **só sob `:on`** (D2=(a)) | **Fail-closed sempre, com rollout `log`→`raise`** (D2=(a) na versão unificada). Razão: o guard exige **DECLARAÇÃO** (contrato de dev), **não** restringe leitura — com os controllers declarados é **no-op em produção, em qualquer estado da flag**. Fecha o furo **também** em `:off`/`:shadow`, onde a versão `:on`-only deixava só o build. |
| **R4** | De que depende o guard | flag própria `FREQUENCIA_CASCATA_ENFORCEMENT` (`log`/`raise`) | reusar `FREQUENCIA_AUTORIZACAO_CASCATA` | **Flag própria** — não acopla o contrato de declaração ao estado da cascata (não fica refém das roles da 30.9b a 87,9%). |
| **R5** | O que **fecha** a omissão | guard + gate de CI | **a Camada 2 (build) é o fechamento REAL** | **Camada 2 fecha a classe**; a Camada 1 é **defesa em profundidade**. Registrado explicitamente na §2.3. |

### Decisões finais para o dev
| # | Decisão | Recomendação |
|---|---|---|
| **D1** | Mecanismo | **Camada 1 + Camada 2** (ambas) |
| **D2** | Em que estado o guard de runtime nega | **(a) fail-closed em TODOS os estados da flag**, com rollout **`log` → `raise`** |
| **D3** | Tocar a `Ability`? | **Não** (guard no controller) |
| **D4** | Adotar `toca_frequencia only:[…]` por action? | **Não** no escopo inicial (postura por controller basta) |
| **D5** | Dobrar o DRY `incluir_cpfs_com_cascata` → concern? | **Sim** (mesma superfície; +1 pt) — é escolha do dev |

---

## 0. Diagnóstico — o mecanismo exato da falha

### 0.1 Por que `authorize! :read, :all` satisfaz o `check_authorization`

O `check_authorization` do CanCanCan **não** pergunta "o usuário pode ler *este* recurso?". Ele pergunta
apenas *"algum `authorize!`/`load_and_authorize` foi chamado nesta action?"* e, em caso negativo, levanta
`CanCan::AuthorizationNotPerformed`. Ele é um **guarda de presença de chamada**, não de conteúdo.

- `Admin::ApplicationController` inclui `CanCan::ControllerAdditions` e chama `check_authorization`
  (`app/controllers/admin/application_controller.rb:7` e `:42`).
- O baseline da Sprint 23 grantou `can :read, :all` a **todo usuário autenticado**
  (`app/models/ability.rb:91`). Logo, `authorize! :read, :all` **passa sempre** para qualquer logado —
  inclusive sem role.
- Consequência medida (ADR-0010 regra 9; Bug Finder 30, Info 2): `Ability#can?(:read, :all)` →
  `true` em **qualquer** valor da flag — o `can :read, :all` do baseline **não é revogado** por nada.
  Logo `authorize! :read, :all` **passa sempre**.
  ⚠️ **Correção (coordenador, 2026-10-15):** sob **`:on`**, o check **por CLASSE** em recurso de
  frequência **NÃO** é `true` — o `ability.rb:92` chama `deny_frequencia_baseline!` (L136-137), que faz
  `cannot :read, recurso` para cada `RECURSOS_FREQUENCIA`. O que **permanece** passando é o
  `:all` (o símbolo), que o `cannot` **não** revoga. Ou seja: a negação sob `:on` atinge **(i)** a
  classe dos recursos de frequência, **(ii)** a filtragem de listagem nos controllers instrumentados e
  **(iii)** a regra **por instância**. **O furo permanece** — mas por causa do `:all`, não do check por
  classe. Um controller que chame `authorize! :read, TimeRecord` (classe) **seria** negado sob `:on`;
  o que ele chama na prática é `authorize! :read, :all`, e é isso que vaza.

**Portanto:** um controller **novo** que leia `TimeRecord`/`CalculoDiario`/`RegistroMensalFrequencia`/
`IntervencaoFrequencia`/`Pessoas::Vinculo`, chame `authorize! :read, :all` e monte a listagem sem o
concern `FrequenciaAuthorization` **passa no `check_authorization` e vaza silenciosamente** o rol de
frequentadores — em **qualquer** valor da flag (`:off`/`:shadow`/`:on`). Foi a **causa-raiz do Bug 🔴1 da
Sprint 30** (`admin/users_controller#index`; corrigido em `f89d312`, ver §0.3).

### 0.2 O concern é opt-in (o "onde" ficou implícito)

O concern `app/controllers/concerns/frequencia_authorization.rb` é incluído **controller a controller**;
não há `before_action` central nem gate de CI que obrigue participação. A ADR-0010 cobre bem o **COMO**
restringir (PORO × SQL twin, `restringir_frequencia`, shadow × on) e deixou **implícito o ONDE**
(enforcement). A emenda de 2026-10-08 (regra 9) nomeia a mitigação como **em aberto**.

### 0.3 Inventário medido (varredura real de `app/controllers/`)

Método: `grep -nE "TimeRecord|CalculoDiario|RegistroMensalFrequencia|IntervencaoFrequencia|Pessoas::Vinculo"`
sobre `app/controllers/**/*.rb`, cruzado com `include FrequenciaAuthorization`.

**Contexto ADMIN** (base `Admin::ApplicationController`, com `check_authorization`) — **é o escopo real**:

| Controller | Lê recurso sensível? | Tem o concern? | Observação |
|------------|----------------------|----------------|------------|
| `admin/frequencia_controller.rb` | Sim (`TimeRecord`, l.14/23) | ✅ | Instrumentado (29.7) |
| `admin/frequencia_por_orgao_controller.rb` | Sim (`Pessoas::Vinculo`, `CalculoDiario`, `TimeRecord`, l.34/44/73/81) | ✅ | Instrumentado |
| `admin/frequentadores_controller.rb` | Sim (`Pessoas::Vinculo`, l.38/46) | ✅ | Instrumentado (29.7) |
| `admin/parcial_controller.rb` | Sim (via concern) | ✅ | Instrumentado |
| `admin/relatorio_terceirizados_controller.rb` | Sim (via concern) | ✅ | Instrumentado |
| `admin/time_records_controller.rb` | Sim (`TimeRecord`, `Pessoas::Vinculo`, l.28/56/191/265) | ✅ | Instrumentado (29.7/30.2) |
| `admin/users_controller.rb` | Sim (`Pessoas::Vinculo`, l.36) | ✅ | Instrumentado no fix 🔴1 (Task 31) |
| **`admin/dashboard_controller.rb`** | **Sim** (`TimeRecord` l.16-18/48-55; `Pessoas::Vinculo.ativos.count` l.31; `RegistroMensalFrequencia` l.42) | ❌ | **NÃO instrumentado** — ver ressalva abaixo |
| `admin/estacoes_controller.rb` | Não | ❌ | Fora do alcance da cascata |
| `admin/versoes_controller.rb` | Não | ❌ | Fora |
| `admin/regimes_controller.rb` | Não | ❌ | Fora |
| `admin/direitos_deveres_controller.rb` | Não (`AfastamentoCache`) | ❌ | Fora |
| `admin/gestores_individuais_controller.rb` | Não (`GestorIndividual`) | ❌ | Fora |
| `admin/sessions_controller.rb` | Não | ❌ | `skip_authorization_check` |
| `admin/application_controller.rb` | Não (só o menu, l.166 `permission_check: TimeRecord`) | ❌ | Base |

> **Ressalva honesta sobre o `dashboard`:** ele **lê** recursos sensíveis, mas **todo** o corpo está
> dentro de `if current_user.admin?` (`dashboard_controller.rb:8`) e a view replica o gate
> (`bug_report_30_cobertura_cascata_bug-finder.md`, Info 1 — premissa **refutada**: **não vaza a
> não-admin**). Portanto o `dashboard` **não** é um vetor de vazamento para usuário comum; mesmo assim é
> um controller que lê frequência **sem declarar postura** — o desenho escolhido exige que ele **declare
> dispensa com justificativa** (admin-only, passo 2 da cascata = visão global por design).

**Contexto PRESENÇA** (base `Presenca::ApplicationController`, `app/controllers/presenca/application_controller.rb:6` — **sem sessão**):

| Controller | Lê recurso sensível? | Observação |
|------------|----------------------|------------|
| `presenca/ponto_de_presenca_controller.rb` | Sim (`TimeRecord`, l.9-10) | **Fora do alcance da ADR-0010 por construção** (pré-sessão, ADR-0003). **Bug 🟠2 = risco aceito** (dev, 2026-10-08; gatilho: após testes manuais da Estação). |
| `presenca/iniciar_ponto_controller.rb` | Sim (`TimeRecord`, l.9) | idem |
| `presenca/sincronizar_registros_ponto_controller.rb` | Sim (`TimeRecord`, l.80/103/124) | idem |

> O contexto presença **não** é alcançado pelo `check_authorization` (base distinta) e a cascata ali é
> **ortogonal** — a barreira é o código de ativação da Estação / rede. `32.O1` **não** o resolve.

### 0.4 Leitura do diagnóstico

O furo é **estrutural e independente da flag**: o que falta é uma forma de o **processo de desenvolvimento**
(CI) impedir que um controller novo leia frequência **sem declarar** como participa da cascata (ou por que
está fora). Hoje, o único guarda (`check_authorization`) aceita `:read, :all` e não vê o furo.

---

## 1. Alternativas de mitigação estrutural

> Premissa comum a TODAS: o objetivo do `32.O1` é **fechar o "silencioso"** — tornar **impossível mergear**
> um controller que leia frequência sem **declarar** postura (instrumentar ou justificar a dispensa), em
> **qualquer** valor da flag. **Não** é (e não pode ser) um *default-deny* de runtime para **todas** as
> rotas — isso está bloqueado pela mesma razão que mantém `:on` desligado (§4).

### Alternativa A — `before_action` central + macro de declaração obrigatória (runtime, fail-closed)

- **Descrição:** um macro de classe (`fora_da_cascata_justificativa "..."`) e um hook no concern
  (`included do … end`) marcam a **postura** de cada controller. Um `before_action` no
  `Admin::ApplicationController` (`:verificar_postura_cascata`) roda em toda action e **levanta** se o
  controller não declara postura nenhuma (`CascataNaoDeclaradaError`). Default-deny por **declaração**
  (blanket: **todo** controller admin precisa declarar).
- **O que quebra:** controllers não declarados → a requisição levanta (500/erro) e, na suíte, os testes
  desses controllers falham. **Mitigação:** anotar todos os controllers existentes na mesma tarefa (os 7
  instrumentados declaram via `include`; os ~6 restantes ganham uma linha de dispensa com justificativa).
- **O que exige mudar em cada controller:** 1 linha (inclusão do concern **ou** `dispensa`).
- **Interação com a flag:** **nenhuma** — o guard é flag-independente (fecha o furo em `:off`/`:shadow`/`:on`).
  É a vantagem principal: o furo existe em qualquer modo.
- **Prós:** fail-closed **em runtime**; não depende de grep; cobre indireção parcial (a chamada
  `dispensa`/`include` é explícita); consistente com a cultura do projeto (fail-closed).
- **Contras:** blast-radius de anotação (toca ~13 controllers); **não** verifica **conteúdo** (um controller
  que **inclui** o concern mas esquece de chamar `restringir_frequencia` continua vazando); risco de 500 em
  produção se um controller escapar da anotação (mitigável por modo `log` — §4); o guard **não sabe** quem
  "lê frequência", então precisa ser *blanket* (exige declarar até quem não lê) — ruído.

### Alternativa B — Teste de conteúdo obrigatório por tela + meta-teste de drift (gate de CI)

- **Descrição (duas partes):**
  1. **Meta-teste de drift:** varre `app/controllers/admin/**/*.rb`, coletando os que casam
     `TimeRecord|CalculoDiario|RegistroMensalFrequencia|IntervencaoFrequencia|Pessoas::Vinculo`. Para cada
     um, **asserta** que a classe declara postura (`:coberto` ⟺ `include FrequenciaAuthorization`;
     `:dispensado` com justificativa não vazia). Um controller que lê sensível e não declara → **CI vermelho**.
     Assert **recíproco**: todo `:coberto` realmente inclui o concern (remover o concern → falha).
  2. **Teste de conteúdo por tela de listagem:** sob `:on`, com `Pessoas::Vinculo` stubado devolvendo um
     terceiro **não-visível**, assertar que `response.body` **NÃO** contém dado identificador do terceiro
     (tela a tela: `frequentadores`, `users`, `time_records#index`, `frequencia`, `frequencia_por_orgao`,
     `relatorio_terceirizados`, `parcial`, `dashboard`). É o grão da matriz de aceite da 29.8 que faltou
     no `users_controller_test.rb` (que sancionava o **200 sem assertar conteúdo** — Bug Finder 30, achado 5).
- **O que quebra:** CI (teste vermelho) quando um controller novo lê frequência sem declarar; **zero**
  mudança de comportamento em produção/rotas.
- **O que exige mudar em cada controller:** nada de runtime; a declaração é lida do **código-fonte** pelo
  meta-teste (a inclusão do concern **é** a declaração; a dispensa é o macro).
- **Interação com a flag:** o **meta-teste** é flag-independente. Os **testes de conteúdo** asseguram a
  restrição **sob `:on`** (em `:off`/`:shadow` a cascata legitimamente mostra tudo / só loga — o mesmo
  observado no Bug Finder 30, cenários "sem bugs").
- **Prós:** cobre **dois** furos: (i) "esqueceu de incluir o concern" e (ii) "incluiu mas não aplicou";
  **risco zero de produção**; o gate natural de código novo já é o CI neste projeto ("test é mandatório",
  `ci-cd-pipeline`); a mitigação é **exatamente** a que a ADR-0010 regra 9 nomeia ("teste de conteúdo
  obrigatório por tela de listagem").
- **Contras:** é gate de **CI**, não de runtime (alguém que burle o CI não é bloqueado em runtime);
  o meta-teste é baseado em **grep** → pode ser **evadido por indireção** (um controller que lê `TimeRecord`
  **via** um service/model intermediário não casa o grep); exige disciplina de manter a lista.

### Alternativa C — Default-deny no `Ability` com allowlist explícita

- **Descrição:** trocar o baseline `can :read, :all` por concessões explícitas por recurso, de modo que
  `authorize! :read, :all` **deixe de satisfazer** o `check_authorization` para recursos de frequência.
- **O que quebra:** **praticamente toda a suíte e todas as telas.** Todos os controllers usam
  `authorize! :read, :all` (ex.: `dashboard`, `regimes#index`, `estacoes#index`, …). Além disso, um
  controller que **nunca** chame `authorize!` sobre o recurso (ou leia `Pessoas::Vinculo` direto) continua
  passando. Fere a diretriz da Sprint 23.7 ("capacidade de acesso não pode diminuir") e a decisão **Q16**
  ("ativar a restrição quando TODAS as roles estiverem prontas").
- **Interação com a flag:** colide de frente com a flag — é o **mesmo** efeito que `:on` production-wide,
  porém **sem** o shadow nem o freio da flag. **Bloqueada pela mesma razão** que mantém `:on` desligado
  (migração de roles da 30.9b a **87,9% de não-resolvidos** → restringiria demais).
- **Veredito:** **rejeitada** (blast-radius altíssimo; resolve um problema que o `32.O1` **não** é — o
  `32.O1` é sobre **cobertura do processo**, não sobre **ligar a cascata**).

### Alternativa D (recomendada) — A + B em camadas

União das duas: **B** (meta-teste de drift + testes de conteúdo) como **gate duro** e **A** (macro de
declaração + `before_action` central) como **defesa em profundidade em runtime**, **ligado em modo `log` por
padrão** e flipável para `raise` (§4). A declaração (macro/`include`) é a **única fonte de verdade**
consumida pelos dois — não há manifest paralelo.
Justificativa de combinar: **A sozinha** deixa passar o "incluiu mas não aplicou"; **B sozinha** deixa de
falhar-closed em runtime. Juntas cobrem os dois casos do §1 e são o que a ADR-0010 regra 9 prescreve na
íntegra ("enforcement **central**" **ou** "teste de conteúdo obrigatório" — aqui, os dois, com papéis
distintos).

---

## 2. Recomendação e desenho concreto (Alternativa D)

> **ADOTO A ALTERNATIVA D.** Fecho o furo estrutural com **dois artefatos complementares e falhos em
> conjunto**: uma **declaração de postura** por controller (runtime, via macro/`include`) e um **gate de CI**
> (meta-teste de drift + testes de conteúdo). A decisão que sobe para ADR após aprovação é esta.

### 2.1 Contrato de declaração (a "única fonte de verdade")

No `app/controllers/concerns/frequencia_authorization.rb`, adicionar o hook de inclusão:

```ruby
included do
  # Declara postura :coberto — o controller participa da cascata.
  class_attribute :cascata_postura, default: nil
  self.cascata_postura = :coberto
end
```

No `Admin::ApplicationController`, o macro de dispensa explícita (com justificativa obrigatória):

```ruby
def self.fora_da_cascata_justificativa(motivo)
  raise ArgumentError, "justificativa obrigatória" if motivo.blank?
  self.cascata_postura = :dispensado
end
```

E o guard central (defesa em profundidade):

```ruby
before_action :verificar_postura_cascata

def verificar_postura_cascata
  return if self.class.cascata_postura.present?          # :coberto ou :dispensado
  msg = "#{self.class.name}: controller admin sem postura de cascata declarada " \
        "(include FrequenciaAuthorization ou fora_da_cascata_justificativa)"
  return Rails.logger.warn(msg) if FrequenciaCascataEnforcement.log?   # §4
  raise CascataNaoDeclaradaError, msg                                   # fail-closed
end
```

- **Contrato:** todo controller `Admin::*` declara **exatamente um** de: `:coberto` (inclui o concern) ou
  `:dispensado` (macro com justificativa). Controllers da base `Presenca::*` **não** herdam o guard.
- **Fail-closed × fail-open:** o guard é **fail-closed** no modo `raise` (config do §4) e **fail-open com
  WARN** no modo `log` (default no 1º deploy). O gate de CI (§2.2) é **sempre duro**.

### 2.2 Gate de CI (o artefato que "faz um controller NOVO falhar")

Arquivo novo `test/controllers/admin/cascata_cobertura_test.rb`:

1. **Detector de drift** (extraído para um helper testável — ex.: `CoberturaCascata.detectores(lista_de_arquivos)`),
   que devolve os controllers que casam `SOURCES_SENSIVEIS`. Assert: `detectores ⊄ declarados` → **falha**.
2. **Prova do gate:** teste unitário que passa ao detector um **arquivo sintético** ("controller novo" que
   lê `TimeRecord` sem declarar) e asserta que ele é **rejeitado** — prova executável de que o §2.2(1)
   pega um controller novo.
3. **Testes de conteúdo por tela** sob `:on` (terceiro não-visível **ausente** do corpo), tela a tela.

### 2.3 Escopo real desta tarefa (o que o `32.O1` entrega)

O `32.O1` entrega um **gate de governança** — impede **mergear** código que leia frequência sem declarar —
e os **testes de conteúdo** que provam a restrição onde a cascata vale. **Não** entrega um *default-deny* de
runtime para todas as rotas (isso é a Alternativa C, bloqueada). O "silencioso" fecha; o que **permanece
legítimo** fora da cascata (telas não-frequência, `dashboard` admin-only, `/presenca/*`) continua
funcionando, agora **explicitamente declarado**.

### 2.4 Notas do CTO — honestidade sobre o `32.O1` (para o dev)

- **O escopo está bem especificado?** Em parte. O texto "enforcement opt-in da cascata" pode sugerir
  *default-deny de runtime*; o entregável viável é **gate de governança + testes de conteúdo**. Recomendo
  o dev **confirmar essa leitura** (Checklist §6, item 1) — se a expectativa for default-deny real, ela
  colide com Q16 (roles 87,9%) e **não cabe** no `32.O1`.
- **Complexidade:** "~5 pts" é **otimista** se incluir a anotação de ~13 controllers + o meta-teste + os
  testes de conteúdo por tela. Recomendo **replanejar para 5–8 pts** no `iteration_33.md`.
- **O ganho é real independentemente da flag:** o furo existe em `:off`/`:shadow`/`:on`; logo o `32.O1`
  **não depende** de ligar `:on` production-wide. Bom custo/benefício de hardening.
- **Débito correlato (DRY) — decisão do dev:** `incluir_cpfs_com_cascata` está **duplicado**
  (`frequentadores_controller` + `users_controller`); o home natural é o concern
  `FrequenciaAuthorization` (ADR-0010 regra 9, "DRY correlato"). **Sugiro** dobrar essa extração no `32.O1`
  (o guard toca o mesmo concern) — mas **é escolha do dev** (Checklist §6, item 4).

---

## 3. Alvos do gate de CI — telas de listagem a cobrir

| Tela (rota) | Controller#action | O que o teste de conteúdo asserta sob `:on` |
|-------------|-------------------|---------------------------------------------|
| `/frequentadores` | `frequentadores#index` | terceiro não-visível **ausente** |
| `/users` | `users#index` | terceiro não-visível ausente; `@users_sem_cpf` admin-only |
| `/time_records` | `time_records#index` | terceiro ausente; dropdown de anos sem ano exclusivo de terceiro (Bug 🟡3) |
| `/frequencia` | `frequencia#index` | terceiro ausente |
| `/frequencia_por_orgao` | `frequencia_por_orgao#index` | CPF de terceiro ausente do agregado |
| `/relatorio_terceirizados` | `relatorio_terceirizados#index` | sem fonte real hoje; assert trivial |
| `/parcial` | `parcial#index` | sem fonte real hoje; assert trivial |
| `/dashboard` | `dashboard#index` | só-admin (não-admin não vê cards de batidas) |

---

## 4. Estratégia de rollout e reversibilidade

> **A cascata NÃO está vigente** (em dev roda `:shadow`; produção, `:off`). Este plano **não** a liga.

1. **Aditivo e sem migração de dados.** A mudança é: (i) linhas de declaração nos controllers
   (sem efeito de comportamento); (ii) o guard central; (iii) testes. Nenhuma migration, nenhum schema.
2. **Guard em modo `log` primeiro.** Novo ponto único de leitura de ENV (espelha a cultura da flag):
   `FREQUENCIA_CASCATA_ENFORCEMENT` = `log` (default no 1º deploy — só `Rails.logger.warn`) | `raise`
   (fail-closed). Em **test/CI**, o `raise` é o padrão (o gate é duro). Após **um ciclo** sem WARN no
   log de produção (i.e., todo controller declarado), o dev **flipa para `raise`**.
3. **O `:shadow` mede antes de exigir (no sentido da cascata).** Já existe para a *cascata* (mede o que
   seria negado); o `32.O1` **não** interfere nele. O papel do `:shadow` aqui é o de **não** exigir
   restrição de conteúdo onde a flag não vale: os testes de conteúdo só assertam restrição **sob `:on`**.
4. **Rollback (trivial, sem dado):** (a) ENV `FREQUENCIA_CASCATA_ENFORCEMENT=log` (ou `off`) desliga o
   guard de runtime; (b) remover o `before_action`/macro + arquivos de teste reverte o gate de CI.
   Reversível por **uma linha / um env**, sem tocar a cascata.
5. **O que NÃO precisa acontecer para o `32.O1` valer:** ligar `:on` production-wide; concluir a migração
   de roles (30.9b); tocar as regras da cascata.

---

## 5. Plano de testes

| # | O que prova | Como | Onde |
|---|-------------|------|------|
| T1 | **Controller NOVO sem declaração FALHA (gate de CI)** | `CoberturaCascata.detectores` recebe um arquivo sintético que lê `TimeRecord` sem declarar → **rejeitado** | `test/controllers/admin/cascata_cobertura_test.rb` |
| T2 | **Toda a árvore real declara postura** | varredura de `app/controllers/admin/**/*.rb` ⊄ declarados → falha | idem |
| T3 | **Recíproco:** `:coberto` ⟺ `include FrequenciaAuthorization` | remover o concern → falha | idem |
| T4 | **Guard de runtime fail-closed** | controller anônimo sem declaração + `FREQUENCIA_CASCATA_ENFORCEMENT=raise` → levanta | `test/controllers/admin/cascata_enforcement_test.rb` |
| T5 | **Guard em `log`** | mesmo cenário em `log` → não levanta, emite WARN | idem |
| T6 | **Conteúdo por tela** sob `:on` | terceiro não-visível **ausente** do corpo (§3) | `cascata_cobertura_test.rb` + ampliação dos existentes |
| T7 | **Não-regressão** | suíte completa **não piora** o baseline | `bin/rails test` |

**Baseline atual (documentado — NÃO pode piorar):** **1222 runs / 4257 asserções / 3F+12E / 0 skip**
(15 falhas pré-existentes: 11× Devise `redirect_to`, 1× timezone, ordem no espelho). RuboCop = 0; Zeitwerk OK.
*(A re-medição do baseline deve ser feita pelo Code Specialist no ambiente correto — Ruby **3.3.8** conforme
`.ruby-version`/ADR-0009; aqui o ambiente ativo é Ruby 3.4.2 mise sem as gems materializadas, então a suíte
não roda nesta sessão.)*

**Testes existentes a preservar/estender (medidos, não inventados):**
`test/controllers/admin/{frequencia_cascata_controller_test,frequencia_matriz_aceite_test,authorization_matrix_test,time_records_anos_cascata_test,users_cascata_controller_test}.rb`,
`test/models/{ability_cascata_test,frequencia_autorizacao_cascata_test}.rb`.

---

## 6. Riscos e o que NÃO entra

### Riscos

| Risco | Sev. | Mitigação |
|-------|------|-----------|
| Guard em `raise` e um controller admin escapa da anotação → erro em produção | 🟠 | Ship em `log` primeiro (§4.2); anotar todos na mesma tarefa; a suíte (T2/T4) pega antes do deploy |
| Meta-teste de grep **evadido por indireção** (lê `TimeRecord` via service) | 🟡 | Testes de conteúdo (T6) cobrem o efeito, não só a fonte; declarar o limite explicitamente |
| Testes de conteúdo instáveis por stub entre 2 bancos (Pessoas × primário) | 🟡 | Seguir o padrão dos testes de cascata já existentes (29.8/30.7) |
| Blast-radius de anotação "comporta" 13 controllers | 🟢 | Mecânico; 1 linha por controller; revisável |

### Fica explicitamente FORA do `32.O1`

- ❌ **Ligar `:on` production-wide** (decisão Q16: só quando as roles estiverem prontas).
- ❌ **Alterar as regras da cascata em si** (`AutorizacaoFrequencia`, `FrequentadoresVisiveis`, a semântica do
  `Ability`, D1/D4/D5/D6/D8). O `32.O1` **consome** a cascata, não a redefine.
- ❌ **Tocar a migração de roles** (30.9b, 87,9% de não-resolvidos).
- ❌ **Bug 🟠2 (`/presenca/*` sem autenticação)** — risco aceito (dev, 2026-10-08; gatilho: após os testes
  manuais da Estação). Contexto distinto (`Presenca::ApplicationController`), fora do `check_authorization`.
- ❌ **Default-deny de runtime no `Ability`** (Alternativa C — bloqueada por §1).
- ❌ **Qualquer commit/push** (`COMMIT_MODE=manual`).

### Decisão opcional do dev (não-obrigatória ao `32.O1`)

- ⚖️ **Dobrar o DRY de `incluir_cpfs_com_cascata`** (concentrar no concern `FrequenciaAuthorization`) — ADR-0010
  regra 9 registra o débito; o guard toca o mesmo concern, então encaixa, mas **é escolha do dev**.

---

## 7. Checklist de aprovação (o que o dev decide)

> **Versão reconciliada (2026-10-15).** As decisões **D1–D5** estão consolidadas na **§0.5**; a checklist
> abaixo é a forma de aprovação delas.

1. [ ] **D1 — Mecanismo:** aprovo as **duas camadas** (runtime + build)? *(recomendado: sim)*
2. [ ] **D2 — Guard de runtime:** **fail-closed em TODOS os estados da flag**, com rollout **`log` → `raise`**
       (recomendado) **ou** negar **só sob `:on`**?
3. [ ] **D3 — `Ability`:** **não** tocar (recomendado)?
4. [ ] **D4 — `toca_frequencia only:[…]` por action:** **não** no escopo inicial (recomendado)?
5. [ ] **D5 — DRY `incluir_cpfs_com_cascata` → concern:** puxar nesta sprint (+1 pt) (recomendado: sim)?
6. [ ] **Q33-C — incluir `Pessoas::Vinculo`** no conjunto de recursos (recomendado: sim)?
7. [ ] **Confirmo a leitura** de que o `32.O1` entrega um **gate de governança + defesa em profundidade**,
       e **não** um *default-deny* de runtime (§2.4) — o default-deny real colide com as roles da 30.9b (87,9%).
8. [ ] **Aprovo o local** deste documento e a via de consolidação pós-aprovação: **emenda à ADR-0010**
       (regra 9/10) **ou** **ADR-0012** nova — **não criar a ADR agora** (§8).
9. [ ] **Replanejo o tamanho** da tarefa (**5–8 pts**; "~5" era otimista — §2.4) no `iteration_33.md`.
10. [ ] **Confiro as exclusões** (§6): sem `:on` production-wide, sem tocar regras da cascata/roles, sem Bug 🟠2.
11. [ ] **Aceito o baseline** (1222/4257/3F+12E, 15 pré-existentes) como piso de não-regressão (§5).

> **Após o aval:** o **Sprint Planner** detalha o `iteration_33.md`; o **Code Specialist** implementa. Sem o
> aval, **nada** de código (regra global de autorização).

## 7.1 ✅ APROVAÇÃO DO DEV — REGISTRADA (2026-10-15)

> **Decisão do dev:** **aprovado como recomendado**, integralmente. Registro abaixo; a ordem foi
> **plano → aval → `iteration_33.md` → código**, e o aval **é este**.

| # | Decisão | Resultado |
|---|---|---|
| **D1** | Mecanismo | ✅ **Camada 1 (runtime) + Camada 2 (build)** |
| **D2** | Em que estado o gate de runtime nega | ✅ **(a) fail-closed em TODOS os estados da flag**, com rollout **`log` → `raise`**; flag própria `FREQUENCIA_CASCATA_ENFORCEMENT` |
| **D3** | Tocar a `Ability`? | ✅ **Não** — guard vive no controller |
| **D4** | `toca_frequencia only:[…]` por action? | ✅ **Não** no escopo inicial |
| **D5** | DRY `incluir_cpfs_com_cascata` → concern | ✅ **Sim** (+1 pt, mesma superfície) |
| **Q33-C** | Incluir `Pessoas::Vinculo` no conjunto | ✅ **Sim** |
| — | Leitura do escopo | ✅ **Gate de governança + defesa em profundidade** (não é default-deny de runtime) |
| — | Local deste documento | ✅ `docs/progress/iteration_33_plano_autorizacao_32_O1.md` |
| — | Tamanho da tarefa | ✅ **5–8 pts** (a estimativa "~5" era otimista) |
| — | Exclusões | ✅ Sem `:on` production-wide; sem tocar regras da cascata/roles; sem Bug 🟠2 |
| — | Baseline | ✅ **1222/4257/3F+12E** (15 pré-existentes) como piso de não-regressão |
| — | Consolidação pós-implementação | ⬜ **emenda à ADR-0010 (regra 9/10) ou ADR-0012** — decisão **posterior** à implementação; **não criar agora** |

**Autor da aprovação:** dev (Davi Araújo) · **Data:** 2026-10-15 · **Via:** sessão Claude Code (`/loop` de decisões D1–D5/Q33-C).

**Efeito:** o **Sprint Planner** está liberado para **refazer** o `docs/progress/iteration_33.md` alinhado a
este plano (o rascunho anterior fica superseded). O **Code Specialist** só entra **depois** disso.

---

## 8. Onde este documento vive, e o que vira ADR depois

- **Local escolhido:** `docs/progress/iteration_33_plano_autorizacao_32_O1.md`.
  **Justificativa (convenção real):** planos/design **pré-aprovação** vivem em `docs/progress/` — precedente
  direto **`docs/progress/iteration_30_task_30_1_plano_gate_d5.md`** (também um "plano/gate" aprovado pelo dev
  **antes** de codar). A pasta `docs/adr/` guarda **decisões já tomadas** (status `Aceito`/`Proposto`, ver
  `adr/0000-template.md` e o cabeçalho da ADR-0010: "Aceito (CTO, …)"); criar um ADR agora **pré-emptaria** a
  aprovação do dev e violaria a ordem decidida.
- **Consolidação durável após a aprovação (NÃO fazer agora):** a decisão arquitetural de **como** e **onde**
  enforce a cascata deve virar **ADR** — seja como **nova regra (10) na ADR-0010** (que hoje tem a regra 9
  exatamente sobre este débito), seja como **ADR-0012** própria. Decisão de forma: **do dev** (§7, item 2).
- **Registro da aprovação:** uma tabela "Registro da aprovação do dev" no topo deste arquivo (espelhando a
  §0 do plano da 30.1) deve ser preenchida quando o dev aprovar — é o que **destrava** o `iteration_33.md`.

---

> **Documento de decisão/design. Nada implementado. Nada commitado.** Aguarda aprovação explícita do dev.
> Fontes primárias lidas nesta sessão (medidas): `app/models/ability.rb`; `app/models/frequencia_autorizacao_cascata.rb`;
> `app/controllers/concerns/frequencia_authorization.rb`; `app/controllers/admin/*.rb`; `app/controllers/presenca/*.rb`;
> `docs/adr/0010-arquitetura-cascata-autorizacao-frequencia.md` (regra 9 + emenda 2026-10-08);
> `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md`; `docs/progress/iteration_30.md` (§Débito ESTRUTURAL);
> `docs/progress/iteration_32.md` (§Situação da Sprint 33); `docs/12-plano-implementacao/implementation_plan.md` v2.
