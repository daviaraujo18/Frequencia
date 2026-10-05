# Relatório de Revisão — Tarefa 30.2 (Ponto de entrada HTTP do gate D5)

> **[⌂ Home](../README.md)** · Sprint 30 · Frente 1 · Tarefa **30.2** (5 pts · Dev A)
> **Veredito:** ✅ **Aprovado** — **Blockers: 0** | Sugestões: 2 (Melhoria: 1 / Débito: 1)

## Metadados

| Campo | Valor |
|-------|-------|
| Data da revisão | 2026-10-05 |
| Revisor | Code Reviewer |
| Worktree | `wt-30.2` — branch `feature/demanda-30-2-gate-d5-http` @ `b47c0ce` |
| Origem → destino | `feature/demanda-30-2-gate-d5-http` → `integration/sprint-29` |
| Insumo-contrato | `docs/progress/iteration_30_task_30_1_plano_gate_d5.md` (plano aprovado na 30.1) |
| COMMIT_MODE | `manual` (sem commit/push nesta revisão) |

### Arquivos alterados revisados

| Arquivo | Δ | Papel |
|---------|---|-------|
| `api-ponto/config/routes.rb` | +15/-2 | member action + constraint `:off` |
| `api-ponto/app/controllers/admin/time_records_controller.rb` | +89 | ação `desconsiderar` (3 modos) |
| `api-ponto/app/models/ability.rb` | +52/-2 | `cannot`+`can` do gate D5 |
| `api-ponto/app/models/frequencia_autorizacao_cascata.rb` | +33 | eventos próprios do D5 |
| `api-ponto/test/controllers/admin/time_records_desconsiderar_test.rb` | +377 (novo) | 9 testes |
| `docs/governance/lessons.md` | +33 | lição CanCanCan fall-through |

> Não revisados como entrega (artefatos de ambiente): `log/test.log`, `tmp/cache/bootsnap/load-path-cache` — **excluir do stage**.

---

## Resultado por item solicitado

### 1. Fidelidade ao ruling D5 (ponto central) — ✅ CONFORME

- O gate (`Ability#grant_desconsideracao_frequencia`) usa **exclusivamente** `ElegibilidadeDesconsideracao#pode_desconsiderar?` → `AutorizacaoFrequencia#gestor_de_orgao_do?` (**só o passo 5**). **Nunca** `pode_ver?`. Confirmado por leitura (`ability.rb:195-205`) e por mutação (item 6 abaixo).
- `GestorIndividual` (passo 4) **vê mas NÃO desconsidera**: o teste linha 65 prova os **dois sentidos** — `assert AutorizacaoFrequencia.new(gestor).pode_ver?(alvo)` (pré-condição) e, sob `:on`, `refute Ability.new(gestor).can?(:desconsiderar, registro)` **e** o POST cai em `AccessDenied` → redirect dashboard **sem efeito** (`desconsiderado? == false`, `IntervencaoFrequencia.count == 0`). O teste é discriminante (mutação `pode_ver?` o derruba).
- A `Ability` **não amplia** além do D5: a única concessão de `:desconsiderar` é esse bloco.

### 2. Correção do fall-through do admin — ✅ CORRETA e COMPLETA

- **Probe independente (CanCanCan 3.6.1):**
  - `A) manage :all` + `can` bloco-false **sem** `cannot` → `can?(:desconsiderar,·) => true` (**vazamento confirmado**).
  - `B) cannot` **ANTES** do `manage :all` + bloco-false → `true` (**ainda vaza**).
  - `C) manage :all` + `cannot` **DEPOIS** + bloco-false → `false` (**nega**); bloco-true → `true`; `manage :all` → `true`.
  - `D) só cannot` → `false`; `manage :all` intacto.
- Ou seja: **a ordem é load-bearing** e o implementador acertou — o `cannot` vem **depois** de `can :manage, :all`. A lição registrada em `lessons.md` está factualmente correta.
- **Cobertura de caminhos:** admin → `can :manage :all; grant_desconsideracao` (cannot+can depois). Gestor → `grant_gestao_frequencia` cria `can :manage, TimeRecord`; em `:on` é só `[:create,:update,:destroy]` (não cobre `:desconsiderar`); em `:off`/`:shadow` cobre, mas `grant_desconsideracao` é no-op — logo `can?(:desconsiderar)` vira true por **fall-through do manage do gestor** (probe: `flag=shadow/off => true`). **Sem impacto no HTTP** (§4, nota). Operador/sem-role → sem `manage`, nega por padrão. **Não há outro verbo vazando**: o `manage :all` só é "negativado" para `:desconsiderar`; `:read`/etc. seguem intactos (correto — a 30.2 só gateia desconsiderar).
- A regra `:desconsiderar` está **sob `ligada?`** (`return unless FrequenciaAutorizacaoCascata.ligada?`): em `:off`/`:shadow` a ação custom **não é concedida** — confirmado por teste (`Ability` sob `nil`/`shadow` → `refute`) e por probe.

### 3. Os 3 estados da flag — ✅ CONFORME

| Estado | Mecanismo | Verificação |
|--------|-----------|-------------|
| `:off` | constraint de rota (`modo != :off`) → `RoutingError` → 404 | teste `off: a rota NAO existe (404)` — **não chega ao controller**; mutação (remover constraint) → falha (`302` em vez de `404`) |
| `:shadow` | branch de log; `lock` sem `update!`/`create!` | teste `shadow: roda mas e NO-OP` — `desconsiderado? == false`, `IntervencaoFrequencia.count == 0`, redirect+notice, evento próprio |
| `:on` | `authorize!` + `desconsiderar!` | testes `on:` — efeito completo + `IntervencaoFrequencia` com `responsavel: gestor` |

- `:shadow` **realmente não escreve**: o branch retorna antes de qualquer escrita; `skip_authorization_check` é aplicado só no shadow (`if:`), e removê-lo derruba o teste (`AuthorizationNotPerformed`).
- `:off` **realmente não chega ao controller**: a constraint é avaliada por request e `modo` lê o ENV a cada chamada (não memoizado — ADR-0010 regra 4), então a troca em runtime é refletida.

### 4. Fuga de autorização (adversarial) — ✅ SEM BLOCKER

- **Caminho HTTP no `:on`**: `set_time_record` → branch (`:shadow?` não) → `registrar_negacao` (se `!can?`) → `authorize!` (fonte única, PORO) → guard de justificativa → `desconsiderar!`. **`desconsiderar!` só roda após o gate** — correto.
- **Justificativa em branco**: guard responde alert **sem** chamar `desconsiderar!` (evita `RecordInvalid`, rollback da transaction como backstop). ✅
- **id inexistente**: `TimeRecord.find` → 404 (consistente; sem vazamento de autorização). ✅
- **Ordem `registrar_negacao` × `authorize!` (dupla avaliação do PORO)**: ambos usam **a mesma** `Ability`/PORO, só quando negado, sem estado mutável compartilhado entre as avaliações — **semântica não diverge** do autorizador. É custo de 2 avaliações (PORO com memo por instância), aceitável; detail registrado em 🟡Q1. ✅
- **`skip_authorization_check` no shadow**: em `:shadow` **qualquer autenticado** dispara POST e (a) passa (a rota não é exposta na UI) e (b) **não há mutação**. O log do shadow é ruidoso (um curioso gera evento) e a resposta `200 redirect + notice` revela, pelo texto, que a desconsideração está "em observação" (leve oráculo de estado de transição) — **aceitável para observação**, alinhado à decisão do dev. Sem vazamento de mutação. Registrado em 🟡Q1 (débito de baixa severidade).
- **Enumeração cross-user (adversarial)**: com `:on`, um gestor de órgão que adivinhe o `id` de um `TimeRecord` de **outro** usuário é barrado pelo bloco PORO (alvo fora do seu órgão → `false`) → `AccessDenied`, sem efeito. Confirmado pela lógica; o bloco é por **instância**, então não depende de tela. ✅
- **Não-`User`**: o bloco faz `registro.user` (associação → sempre `User`); o PORO reforça (`alvo_nao_user` → `false`). ✅
- **Não há outro caminho de produção** para `desconsiderar!` (grep: só o controller novo). ✅

> **Nota (não-bug):** o probe mostrou que, para a role `:gestor` sob `:shadow`/`:off`, `can?(:desconsiderar,·)` é `true` por fall-through do `manage :all` **do gestor** (que não tem `cannot` pareado). Isso **não é explorável pelo HTTP**: em `:off` a rota não existe; em `:shadow` o branch nunca chama `authorize!` nem `desconsiderar!`. É uma assimetria de `can?` que só seria um vetor se um futuro consumidor confiasse em `can?(:desconsiderar)` para decidir **fora** do controller. Fica como observação de hardening (relacionada à 🟡Q1); não bloqueia.

### 5. Eventos próprios (Q7) — ✅ CONFORME

- `EVENTO_DESCONSIDERAR_SHADOW` e `EVENTO_DESCONSIDERAR_NEGACAO` são **distintos** de `EVENTO_SHADOW`/`EVENTO_NEGACAO`. O teste do shadow **refuta explicitamente** a presença de `frequencia_autorizacao_cascata.shadow` no log → não polui a contagem de visualização do rollout da 30.8.
- Payload consistente (`emitir` centralizado: `usuario_id, alvo_tipo, alvo_id, alvo_cpf, motivo, decisao`), `decisao: :negaria` no mesmo vocabulário da 29.7/29.8.
- `log_desconsiderar_shadow` guarda por `shadow?`; `log_desconsiderar_negacao` por `ligada?` — **simétricos**. ✅

### 6. Testes — ✅ ADEQUADOS e DISCRIMINANTES

9 testes cobrindo os 7 cenários do critério + Ability + fall-through do admin. **Não-degenerados** (têm sanidade de cenário: `gestor_de_orgao_do?`/`pode_ver?` assertados antes). **Mutações que eu apliquei (5, todas mortas):**

| # | Mutação | Resultado |
|---|---------|-----------|
| 1 | remover `cannot :desconsiderar, TimeRecord` | **1F** — teste do admin (fall-through) |
| 2 | `pode_desconsiderar?` → `pode_ver?` | **3F** — incluindo o discriminador do GestorIndividual |
| 3 | remover a constraint do `:off` | **1F** — `off:` esperava 404, veio 302 |
| 4 | remover `skip_authorization_check` | **1E** — `AuthorizationNotPerformed` no shadow |
| 5 | (lido) trocar evento shadow pelo `EVENTO_SHADOW` | coberto pelo `refute` do teste do shadow |

- O teste do `GestorIndividual` prova "vê **mas** não desconsidera" nos dois sentidos. O teste do admin prova `refute :desconsiderar` **e** `assert :manage, :all` (não regride o resto).
- **Lacunas de cobertura (menores):** (a) não há teste de "gestor do órgão que também é o **próprio** alvo" (auto-bloqueio cláusula 7) via HTTP — coberto no PORO (29.5) e o teste do admin cobre implicitamente a negação, mas não o caminho auto-bloqueio ponta-a-ponta; (b) o retorno do `log_desconsiderar_negacao` é asserado (evento presente) mas `motivo`/`alvo_cpf` do payload não; (c) `params[:justificativa]` em `:shadow` é irrelevante (não lê), ok.

### 7. Regressão e qualidade — ✅ CONFORME

- **Arquivo-alvo:** `9 runs / 59 assertions / 0F / 0E`.
- **Suíte completa (medida por mim):** `1092 runs / 3847 assertions / 1F + 12E / 0 skips` — **idêntico** ao declarado. Os 12 erros são pré-existentes: 11× Devise `redirect_to` (Users::Sessions/Passwords) + 1× `PresencaEndpointsTest` (timezone) + `PessoasSchemaLoaderTest` (`accepts_the_configured_test_mirror_database`) que **passa isolado (4/28/0/0)** — ordem-dependente, não regressão.
- **RuboCop:** arquivos do gate 0 offenses novas — o controller tem apenas `Layout/SpaceInsideArrayLiteralBrackets` em linhas **legadas** (não tocadas); `routes.rb` mantém o mesmo débito legado do arquivo inteiro; nenhuma violação nas linhas **adicionadas**.
- **Zeitwerk:** `All is good!`. **Rotas:** `desconsiderar_time_record POST /time_records/:id/desconsiderar`.

---

## Blockers 🔴

**Nenhum.**

## Sugestões

| ID | Tipo | Descrição | Tarefa |
|----|------|-----------|--------|
| 🟡Q1 | Melhoria | **Consistência de `can?(:desconsiderar)` entre papéis na mesma flag.** No `:on`, admin e gestor negam o passo 4 corretamente; mas sob `:shadow`/`:off` o **gestor** `can?(:desconsiderar)` vira `true` por fall-through do `manage` (o gestor não tem `cannot` pareado), enquanto o admin é `false`. Não é explorável pelo HTTP (rota/branch protegem), mas é uma assimetria de `can?` que um futuro consumidor poderia confiar indevidamente. Recomendação: emparelhar o `cannot :desconsiderar, TimeRecord` **incondicionalmente** dentro de `grant_desconsideracao_frequencia` (antes do `return unless ligada?`), de modo que a ação nunca vaze por fall-through em nenhum modo/papel. Alternativamente, documentar a assimetria como contrato ("`can?(:desconsiderar)` só é significativo sob `:on`"). | 30.2 |
| 🟠D1 | Débito | **Ruído/oráculo do `:shadow` com `skip_authorization_check`.** Qualquer autenticado pode POSTar em `:shadow` (sem autorização) e gera evento + `notice` que revela o estado de observação. Aceitável para o ciclo de observação, mas registrar como débito (confinar o shadow a autorizados, ou não responder texto que revele o modo). | 30.2/30.8 |

## Elogios 🟢

| ID | Elogio | Tarefa |
|----|--------|--------|
| 🟢E1 | **Achado e correção do fall-through `can`-bloco × `manage :all`** — descoberto por probe (não por leitura), com a ordem `cannot`→`can` **depois** do `manage` provada correta; a lição foi formalizada em `lessons.md`. Robustez exemplar num ponto cego clássico do CanCanCan. | 30.2 |
| 🟢E2 | **Simetria de auditoria shadow × `:on`** com eventos próprios (Q7) e payload centralizado — não polui a contagem de visualização e mantém as trilhas comparáveis linha a linha. | 30.2 |
| 🟢E3 | **Fail-closed em três camadas** (`:off` → 404 por constraint; `:shadow` → no-op; `:on` → PORO) com comentários que explicam o *porquê* e citam o plano/ADR. | 30.2 |
| 🟢E4 | Testes com **sanidade de cenário** (assertam a pré-condição antes do efeito) — evita o padrão degenerado da lição 33. | 30.2 |

---

## Ações corretivas

- [ ] (Opcional / não-bloqueante) Endereçar 🟡Q1 e registrar 🟠D1 como débito na sprint.
- [ ] **Stage seletivo** — incluir apenas: `config/routes.rb`, `app/controllers/admin/time_records_controller.rb`, `app/models/ability.rb`, `app/models/frequencia_autorizacao_cascata.rb`, `test/controllers/admin/time_records_desconsiderar_test.rb`, `docs/governance/lessons.md`. **Excluir** `log/test.log` e `tmp/cache/bootsnap/load-path-cache`.
- [ ] Commits atômicos conforme o protocolo de entrega (Code Specialist).

## Recomendação de commit

Entrega técnica **aprovada**. O fechamento da rastreabilidade (agrupamento de commits atômicos + protocolo de entrega) é **pré-requisito** para o início da próxima tarefa.
