# Plano — Tarefa 30.1: exposição do gate D5 e aprovação do dev (design; GATE)

> **[⌂ Home](../README.md)** · Sprint 30 · Frente 1 · Tarefa **30.1** (2 pts · Dev B/CTO)
> **Status:** ✅ **Plano escrito + aprovação do dev registrada — gate satisfeito.** Desbloqueia a **30.2**.
> Rastreabilidade: `iteration_30.md` §Tarefa 30.1/30.2; `PRD-REGRAS-NEGOCIO-PRESENCA.md` §3 e §2.5;
> `docs/adr/0010-...md` regra 6; ruling **D5** (CTO, 2026-10-01, `iteration_29.md` §"Decisão D5");
> `iteration_29.md` §Tarefa 29.5.

> **Escopo:** design **only**. Este documento **não** altera `app/`, rotas, testes ou `Ability`. É o
> insumo exato da implementação da **30.2** — que só inicia após esta aprovação (regra global do
> `CLAUDE.md`: alterar autorização/rotas exige plano claro).

---

## 0. Registro da aprovação do dev (satisfaz o gate da 30.1)

| Item | Valor |
|------|-------|
| Decisão aprovada | (a) ponto de entrada = **member action em `Admin::TimeRecordsController`** (não controller dedicado); (b) **`:off` → 404** (recurso indisponível) |
| Autor | **dev Davi Araujo** |
| Data | **2026-10-05** |
| Efeito | **Gate da 30.1 satisfeito** → a tarefa **30.2** está desbloqueada |
| Consequências nos rulings abertos | **Q1 respondida** (member action + 404); **Q2 confirmada** (não haverá extensão ao `GestorIndividual` — ruling D5 mantido: **só o passo 5**) |

> Registro espelhado em `iteration_30.md` §Tarefa 30.1 (critério "aprovação explícita do dev
> registrada"). Sem este registro, a 30.2 **não** poderia iniciar.

---

## 1. Ponto de entrada

### 1.1 Controller, ação, rota, params

| Campo | Definição |
|-------|-----------|
| Controller | `Admin::TimeRecordsController` (`app/controllers/admin/time_records_controller.rb`) |
| Ação | `desconsiderar` |
| Verbo | `POST` |
| Tipo de rota | **member action** de `resources :time_records` |
| Path real | **`/time_records/:id/desconsiderar`** (ver divergência §1.3) |
| Helper | `desconsiderar_time_record_path(id)` |
| Params | `id` (`TimeRecord`), `justificativa` (String, **obrigatória**) |
| Alvo do gate | `@time_record.user` (`User` local) |
| Dia avaliado | `@time_record.punched_at.to_date` |

**Rota especificada** (alteração a ser feita na 30.2, em `config/routes.rb`, hoje `resources :time_records, only: [:index]`):

```ruby
resources :time_records, only: [:index] do
  member do
    post :desconsiderar
  end
end
```

### 1.2 Efeito (`:on`, autorizado)

```ruby
@time_record.desconsiderar!(
  justificativa: params[:justificativa],
  responsavel: current_user
)
```

Assinatura **real** (confirmada no código — ver §4): `TimeRecord#desconsiderar!(justificativa:, responsavel:)`
(`app/models/time_record.rb:37`). Efeito atual do método, **preservado sem mudança**:
`update!(desconsiderado: true, ressalva: true)` + criação de uma `IntervencaoFrequencia`
(`tipo: "desconsideracao_ponto"`, `status: "registrado"`, `user: self.user`, `responsavel:`,
`justificativa:`, `momento: punched_at`, `punch_type:`, `time_record: self`), tudo em `transaction`.
`justificativa` e `responsavel` são **obrigatórios** (validação do model). O motor de cálculo **não** é
tocado (o `IntervencaoFrequencia`/`desconsiderado` já é consumido por `CalculoDiarioService`).

**Falha de validação:** `justificativa` em branco → `ActiveRecord::RecordInvalid` no `create!` da
intervenção. A 30.2 deve tratar com negação **sem efeito** (a `transaction` faz rollback); especificar
resposta ao usuário (redirect com alerta ou 422) — ver **Q8 §5**.

### 1.3 Divergência de path a registrar (não é erro de código)

O enunciado/decisões referem-se a "member action em **`admin/time_records`**". Isso é o **namespace do
controller** (`Admin::TimeRecordsController`), **não** o path. O `config/routes.rb` usa
`scope module: "admin"` (linha 30) — **não** `namespace :admin` — logo o **path real é
`/time_records`** (medido: `bin/rails routes` → `time_records GET /time_records(.:format)
admin/time_records#index`). A rota nova é **`POST /time_records/:id/desconsiderar`**.
Se a intenção do dev fosse um path sob `/admin/...`, isso exigiria `namespace :admin` — mudança
estrutural **não** autorizada. **Mantido o path `/time_records/:id/desconsiderar` (design).**

---

## 2. Comportamento nos 3 estados da flag (`FrequenciaAutorizacaoCascata`)

| Modo | Rota alcança o controller? | Efeito | Resposta |
|------|----------------------------|--------|----------|
| **`:off`** (default em produção) | **Não** — rota indisponível | **Nenhum** (fail-closed) | **404** ("recurso indisponível"); **não revela autorização** (não chega à `Ability`) |
| **`:shadow`** | Sim | **Nenhum** — **não** desconsidera | registra a decisão **projetada** do gate (log) e responde sem mutação (ver §2.2 + **Q7 §5**) |
| **`:on`** | Sim | Aplica o **gate D5** (§3); se autorizado, chama `desconsiderar!` | sucesso → redirect com notice; negado → `CanCan::AccessDenied` (redirect do base) **sem efeito** |

### 2.1 Como o `:off` produz 404 (recomendação de mecanismo)

**Primário — constraint de rota** (rota genuinamente indisponível; não chega ao controller; não dispara
`check_authorization`):

```ruby
post :desconsiderar, constraints: ->(_req) { FrequenciaAutorizacaoCascata.modo != :off }
```

A lambda é avaliada **por request** e `FrequenciaAutorizacaoCascata` lê o ENV **a cada chamada** (não
memoizado — ADR-0010 regra 4), então a troca de flag em runtime é refletida. Em `:off` nenhuma rota
casa → `ActionController::RoutingError` → 404 (exceptions app). **`= :off` não expõe nem o controller
nem a `Ability`.**

**Alternativa equivalente (se houver blocker técnico com a constraint):** `before_action` no controller
que, em `:off`, responde `head :not_found` (404) — externamente indistinguível da 404 do roteador.
Escolher UMA; a 30.2 registra a escolha.

### 2.2 `:shadow` — só loga, sem efeito

A ação roda, mas **não** chama `desconsiderar!` nem qualquer `update!`/`create!`. Consulta
`ElegibilidadeDesconsideracao#pode_desconsiderar?` apenas para **registrar** a decisão projetada, e
responde sem mutação (com `skip_authorization` para o `check_authorization` do base).

> ⚠️ **Tensão declarada (não decidida aqui → Q7):** o modo `:shadow` **existente** loga decisões de
> **visualização** (`EVENTO_SHADOW` com o `motivo` de `AutorizacaoFrequencia`/`pode_ver?`). O gate D5 é
> de **desconsiderar** e, por ADR-0010 / Tarefa 30.8, "o gate D5 é `:on`-only e **não** produz sinal em
> shadow". Como o dev decidiu que `:shadow` "só loga", é preciso definir **qual** evento/payload — ver
> **Q7 §5**. Recomendação: **evento próprio** (não reusar `EVENTO_SHADOW`), para não poluir a contagem
> por motivo da visualização.

---

## 3. Critério de autorização (ruling D5)

**Só o passo 5 da cascata.** O predicado que autoriza desconsiderar é:

```
ElegibilidadeDesconsideracao.new(current_user).pode_desconsiderar?(@time_record.user, @time_record.punched_at.to_date)
```

que internamente delega o passo 5 a
`AutorizacaoFrequencia.new(current_user).gestor_de_orgao_do?(@time_record.user)`.

- **NUNCA `pode_ver?`.** Usar `pode_ver?` ampliaria a autorização (passos 1–4) — exatamente o que a
  **D5** veda. `GestorIndividual` (passo 4) **vê** mas **NÃO** desconsidera.
- O `pode_desconsiderar?` já aplica **fail-closed** (acionador/alvo/data ausente, alvo não-`User`,
  `Dia` sem cálculo, dia sem registros, falta/meta-zero/compensada/descontado-em-folha, registro já
  desconsiderado, **auto-bloqueio** do próprio ponto) — a 30.2 **reusa** esse PORO, não reimplementa.

### 3.1 Onde entra na `Ability` (a 30.2 implementa)

- Nova **ação custom `:desconsiderar`** sobre `TimeRecord`, concedida **somente quando
  `FrequenciaAutorizacaoCascata.ligada?`**, por regra de **bloco/instância** que consulta o **mesmo**
  PORO (`ElegibilidadeDesconsideracao#pode_desconsiderar?`). Regra por bloco serve `can?`/`authorize!`
  por instância; **não** é usada por `accessible_by` (limite CanCanCan 3.6.1 já medido — ADR/`ability.rb`).
- O controller chama `authorize! :desconsiderar, @time_record`. `CanCan::AccessDenied` é tratado pelo
  base (`Admin::ApplicationController#rescue_from`) → redirect para dashboard com alerta, **sem efeito**.
- **Under `:off`/`:shadow` a ação `:desconsiderar` NÃO é concedida** — em `:off` a rota nem existe; em
  `:shadow` não se chama `authorize!` (branch de log). Single source of truth: a regra da `Ability`
  **reusa** `pode_desconsiderar?` (nenhuma cópia da cláusula "passo 5" em outro lugar).
  - Se a 30.2 preferir um guard explícito no controller **além** do `authorize!`, ele deve invocar o
    **mesmo** PORO e produzir o **mesmo booleano** (proibido divergir).

### 3.2 Casos de teste obrigatórios (a 30.2 cobre)

| Cenário | Esperado |
|---------|----------|
| Gestor do órgão do alvo (passo 5) | **autorizado** → `desconsiderar!` aplicado (efeito + `IntervencaoFrequencia`) |
| **`GestorIndividual` (passo 4), sem hierarquia** | **vê** (`pode_ver? == true`) mas **NÃO desconsidera** (`pode_desconsiderar? == false`) → negado **sem efeito** |
| Sem role / sem hierarquia | negado sem efeito |
| Flag `:off` | **404** (rota indisponível); nenhum efeito |
| Flag `:shadow` | ação roda mas **no-op** (só log; nenhum `update!`/`create!`) |
| Flag `:on` | gate D5 restringe |
| `justificativa` em branco | validação falha → **sem efeito** (rollback) |

**Mutation testing:** (i) remover o gate → o teste do gestor-do-órgão **falha**; (ii) trocar o passo 5
por `pode_ver?` → o teste do **`GestorIndividual`** falha.

---

## 4. Assinaturas reais (confirmadas no código — nenhuma divergência material)

| Artefato | Assinatura real | Arquivo:linha |
|----------|-----------------|---------------|
| `TimeRecord#desconsiderar!` | `desconsiderar!(justificativa:, responsavel:)` | `app/models/time_record.rb:37` |
| `ElegibilidadeDesconsideracao#pode_desconsiderar?` | `pode_desconsiderar?(frequentador, data)` — alvo **deve ser `User`** (senão `false` + `warn`) | `app/models/elegibilidade_desconsideracao.rb:79` |
| `AutorizacaoFrequencia#gestor_de_orgao_do?` | `gestor_de_orgao_do?(frequentador)` (expõe **só o passo 5**) | `app/models/autorizacao_frequencia.rb:72` |
| `FrequenciaAutorizacaoCascata` | `.modo` → `:off`/`:shadow`/`:on`; `.ligada?`; `.shadow?`; `.log_shadow`; `.log_negacao` | `app/models/frequencia_autorizacao_cascata.rb:48-95` |

**Conformidade com o presumido pela 30.1:** a assinatura de `desconsiderar!` **confere** com
`(justificativa:, responsavel: current_user)` — **sem divergência**. A única divergência registrada é de
**path** (§1.3): `/time_records/:id/desconsiderar`.

---

## 5. Perguntas abertas (não decididas aqui — exigem o dev)

- **Q7 — evento/payload do log em `:shadow` para o gate D5** (bloqueia a 30.2 no ramo shadow). O
  shadow existente loga **visualização** (`EVENTO_SHADOW` com motivo de `pode_ver?`); o gate D5 é de
  **desconsiderar** e, por ADR-0010/30.8, não tem sinal em shadow. Opções:
  (a) reusar `EVENTO_SHADOW` — **risco de poluir** a contagem por motivo da visualização;
  (b) **novo evento** (ex.: `frequencia_autorizacao_cascata.desconsiderar_shadow`), mesmo formato de
  payload — **recomendado**;
  (c) não logar em shadow (tratar "só loga" como no-op silencioso) — contraria a decisão do dev.
- **Q8 — resposta HTTP em `:shadow` e em `justificativa` em branco**: redirect com alerta/notice vs
  4xx. **Recomendação:** `:shadow` → redirect back com notice "desconsideração indisponível em
  observação"; `justificativa` em branco → redirect com alerta (nenhum efeito).

> **Q1** (ponto de entrada) e **Q2** (sem extensão ao `GestorIndividual`) ficam **respondidas/confirmadas**
> pela aprovação do dev em 2026-10-05 (§0).

---

## 6. Riscos

- **Ampliação indevida de autorização (30.2).** Mitigado por: gate **só passo 5**, **nunca** `pode_ver?`;
  404 em `:off`; no-op em `:shadow`; teste explícito "`GestorIndividual` vê mas não desconsidera";
  mutation testing (trocar passo 5 por `pode_ver?` deve derrubar teste).
- **Conflação de log shadow.** Reusar `EVENTO_SHADOW` para o D5 misturaria duas decisões distintas —
  **Q7**.
- **Path divergente do enunciado.** Fixado `/time_records/:id/desconsiderar` (scope module, não
  namespace) — §1.3. Implementar sob `/admin/...` exigiria mudança estrutural não autorizada.
- **`check_authorization` × branch de shadow.** O branch `:shadow` não chama `authorize!` → precisa
  `skip_authorization` explícito (detalhe de implementação da 30.2).
