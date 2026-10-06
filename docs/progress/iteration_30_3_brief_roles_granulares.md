# Brief de decisão — Tarefa 30.3: Roles granulares (PRD §9 item 2)

> **Tipo:** brief de decisão (doc-only). **Não** é o ruling — o ruling é do **dev/PO**.
> **Autor:** CTO · **Data:** 2026-10-06 · **Status:** insumo de decisão — **aguarda ruling**
> **Rastreabilidade:** `PRD-REGRAS-NEGOCIO-PRESENCA.md` §2.3, §6, §9 item 2 · `docs/adr/0010` (passos 2/3 da cascata) · `docs/progress/iteration_29.md` (ruling D1, §Decisão D1; quadro §9) · `docs/progress/iteration_30.md` §30.3 (Q3)
> **Objetivo:** encurtar a decisão do dev/PO entre **(A) manter simplificado** e **(B) expandir**, e fixar a **abrangência** (Q3). O dev decide.

---

## 0. Como ler este brief

- 🟢 **FATO MEDIDO** — verificado no código desta árvore (`api-ponto`) ou no texto do PRD/ADR/iteration.
- 🟡 **ESTIMATIVA/SUPOSIÇÃO** — juízo do CTO, não medido. O dev deve tratar como opinião.
- ⚠️ **LACUNA DO PRD** — o PRD é omisso/inconsistente; o número não existe na fonte e **não foi inventado** aqui.

Nada neste brief toca `app/`, seeds, rotas ou testes.

---

## 1. Estado atual das roles no Frequencia (fato medido)

| Fonte | O que existe | Onde |
|---|---|---|
| Rolify | Tabelas `roles`/`users_roles`; **roles globais apenas** (sem scoping por resource, decisão registrada) | `app/models/role.rb` |
| Roles **semeadas** | **Somente** `admin`, `gestor`, `operador` | `db/seeds.rb:61` |
| Roles **lidas pela cascata** | `visualiza_frequentadores` (passo 2), `visualiza_terceirizados` (passo 3) | `app/models/autorizacao_frequencia.rb:130,138` |
| Roles D1 (29.4) | **Existem no código** mas **NÃO são criadas/atribuídas nos seeds** (atribuição manual/out-of-band) | `db/seeds.rb` (ausentes) |
| Baseline de leitura | `can :read, :all` para **todo autenticado**; subtraído **só** dos recursos de frequência sob `:on` | `app/models/ability.rb:91-92,136-138` |
| `:manage` fora de frequência | Só **admin** (`can :manage, :all`); `gestor` gerencia **só** `TimeRecord`/`IntervencaoFrequencia`; `operador` só lê | `app/models/ability.rb:94-113,211-224` |

**Consequência medida:** hoje há **3 roles efetivas** em produção. As 2 roles da cascata **não são semeadas** — portanto, sem atribuição manual, o passo 2 (visão global) e o passo 3 (terceirizados) **nunca** disparam via Rolify em produção. Isso corrobora a leitura do quadro §9 (item 2 = "dependência de valor real").

**Ponto crítico para a decisão:** a cascata (`pode_ver?`) consome **exatamente 2** roles — `visualiza_frequentadores` e `visualiza_terceirizados`. As **demais** roles do §2.3 **não entram na cascata**; elas gateiam **outras seções** pela `Ability`/controllers (estações, excepcionais, etc.). Ou seja: **expandir para 11+7 não "liga" a cascata por si** — o que liga a cascata é (a) a flag `:on` e (b) a atribuição das 2 roles de leitura. O valor da expansão está, majoritariamente, **fora** do domínio de frequência. (🟡 interpretação do CTO sobre fato medido.)

---

## 2. Mapeamento legado → Frequencia (PRD §2.3)

### 2.1. As roles "granulares" do §2.3

⚠️ **LACUNA DO PRD (contagem):** §2.3 diz "**11 roles**", mas a tabela **enumera 13 nomes** `PRESENCA_*` distintos (4 de estação + 2 excepcionais + 3 frequentadores + 2 gestor-individual + 2 avulsas). O dev precisa decidir qual número vale — **não** foi presumido aqui.

| # | Role legado (§2.3) | Efeito no legado | Existe no Frequencia? | Consumidor hoje | Gap real |
|---|---|---|---|---|---|
| 1 | `PRESENCA_VISUALIZA_ESTACOES` | ver estações | 🟢 leitura coberta pelo baseline `can :read, :all` (**sem role**) | Estações (index) | sem granularidade: todo autenticado vê |
| 2 | `PRESENCA_CONTROLA_ESTACOES` | controle remoto da estação | 🟢 **inexistente** | — (há campos `vnc`/`anydesk`/`teamviewer` na tabela) | papel e ação ausentes |
| 3 | `PRESENCA_GERENCIA_ESTACAO` | gerenciar estação | 🟡 `:manage` em `EstacaoPonto` = **admin-only** (via `:all`) | Estações (write) | sem role dedicada; só admin |
| 4 | `PRESENCA_CADASTRA_ESTACAO` | cadastrar estação | 🟡 `:create` em `EstacaoPonto` = **admin-only** | Estações (create) | idem #3 (o legado separa criar × gerenciar; Frequencia não) |
| 5 | `PRESENCA_GERENCIA_EXCEPCIONAIS` | Direitos, Feriados, Dias Excepcionais, Registros Manuais, Regimes | 🟢 **quase inexistente**: só `Regime` (admin-only). **Não há** modelos Feriado/DiaExcepcional/Direito/RegistroManual | Regimes (admin) | seção não portada |
| 6 | `PRESENCA_VISUALIZA_EXCEPCIONAIS` | ler o que #5 gerencia | 🟢 leitura coberta por `:read, :all` (**sem role**) | — | idem #5 + sem granularidade |
| 7 | `PRESENCA_GERENCIA_FREQUENTADORES` | gerir frequentadores **+ as 4–5 flags de `CalculoDiario`** (§6) | 🟡 `:manage User` = **admin-only**; **flags §6 NÃO implementadas** (só existe a coluna `descontado_em_folha`; as `liberado_*`/`permitido_*` não existem no schema) | Frequentadores (admin) | role ausente **e** feature §6 ausente. **Não** participa da cascata (passo 2 legado = só `VISUALIZA`) |
| 8 | `PRESENCA_VISUALIZA_FREQUENTADORES` | acesso geral de leitura a frequência | 🟢 **existe** (`visualiza_frequentadores`) e **é lida** (passo 2) | cascata passo 2; `Ability` | **não semeada** → atribuição manual |
| 9 | `PRESENCA_VISUALIZA_FREQUENTADORES_TERCEIRIZADOS` | ler só `TERCEIRIZADO` | 🟢 **existe** (`visualiza_terceirizados`) e **é lida** (passo 3) | cascata passo 3 | **não semeada** |
| 10 | `PRESENCA_VISUALIZA_GESTOR_INDIVIDUAL` | ver entidade GestorIndividual | 🟡 tela `admin/gestores_individuais` (**index apenas**), leitura via `:read, :all` | Gestores Individuais (read) | sem role; sem granularidade |
| 11 | `PRESENCA_GERENCIA_GESTOR_INDIVIDUAL` | gerir GestorIndividual | 🟢 **inexistente** (o controller **só tem `index`**) | — | ação de escrita e role ausentes |
| 12 | `PRESENCA_GERENCIA_RETIFICADORES` | criar/editar retificadores de banco de horas | 🟡 model `RetificadorBancoHoras` **existe**, **sem controller/tela** | — | tela e role ausentes |
| 13 | `PRESENCA_CADASTRO_DIGITAL` | cadastrar digital biométrica via estação | 🟢 **inexistente** (não há modelo/controller) | — | seção não portada |

### 2.2. Os 7 perfis (`PresencaProfilesEnum`)

⚠️ **LACUNA DO PRD:** §2.3 nomeia os 7 perfis mas **não especifica a composição (quais roles cada bundle contém)** — só o rótulo. A composição exata **não pode** ser inferida sem consultar o `PresencaProfilesEnum` do legado. O dev precisa decidir se a composição dos perfis entra no escopo.

| Perfil | Rótulo no PRD | Alvo no Frequencia |
|---|---|---|
| `PRESENCA_ADMIN` | excepcionais + frequentadores | bundle → já coberto por `admin` (curto-circuito) |
| `PRESENCA_ADMIN_EXCEPCIONAIS` | só excepcionais | seção não portada |
| `PRESENCA_ADMIN_FREQUENTADORES` | só frequentadores | `gestor` + flags §6 (ausentes) |
| `PRESENCA_OPERADOR` | estações | `operador` (hoje só leitura) |
| `PRESENCA_PROGRAMADOR` | tudo | ≈ `admin` |
| `PRESENCA_VISUALIZADOR_FREQUENTADORES` | inclui terceirizados | `visualiza_frequentadores` + `visualiza_terceirizados` |
| `PRESENCA_VISUALIZADOR_EXCEPCIONAIS` | excepcionais (leitura) | seção não portada |

🟢 **Nota técnica:** Rolify **não modela "perfis"/bundles nativamente** (só roles). Representar os 7 perfis exige uma camada própria (tabela de perfis, convenção de nomes ou `add_role` múltiplo) — **não decidida** nesta sprint.

---

## 3. Efeito na cascata (passos 2/3) × fora dela

| Onde | O que a role afeta | Roles que importam hoje |
|---|---|---|
| **Dentro da cascata** (`AutorizacaoFrequencia`/`FrequentadoresVisiveis`) | passos **2** (visão global) e **3** (terceirizados) | **só** #8 e #9 |
| **Fora da cascata** (`Ability`/controllers) | estações (#1–4), excepcionais (#5–6), gestão de frequentadores + §6 (#7), gestor-individual (#10–11), retificadores (#12), digital (#13) | hoje tudo isso é **admin-only** ou **sem enforcement** (baseline `:read`) |

🟢 **Acoplamentos medidos** (pontos que "só checam admin" hoje e teriam de ser reabertos para uma role granular):
- `ability.rb` não concede `:manage` a ninguém além de admin para `EstacaoPonto`, `Regime`, `Versao`, `User`, `AfastamentoCache` (só há `can :manage, :all` para admin).
- Controllers: `load_and_authorize_resource` em `estacoes`, `regimes`, `versoes`; `authorize! :manage, User` em `frequentadores`; `authorize! :manage, AfastamentoCache` em `direitos_deveres` — todos **admin-only** por consequência do item anterior.
- `GestoresIndividuaisController` **só tem `index`** e libera por `:read, :all`.
- Sidebar/`@static_menu` reflete `permission: :manage, check: User` (admin-only) — `application_controller.rb:169-177`.

**Implicação:** uma role granular como `gerencia_estacao` **não produz efeito** até a `Ability` e os controllers deixarem de depender de "admin-only". Criar a role sem reabrir o enforcement = role decorativa.

---

## 4. As duas opções macro

### Opção A — Manter simplificado (3+2) e evoluir pontualmente

**O que é:** manter `admin`/`gestor`/`operador` + as 2 da D1; **semear/atribuir** as 2 roles de cascata; abrir granularidade **só onde há consumidor** (estações e gestor-individual no máximo). Nada de 11+7.

| | |
|---|---|
| Cascata ganha | 🟢 As 2 roles passam a existir **de fato** (semeadas/migradas) → passos 2/3 operam. É o mínimo que dá **valor real** à flag `:on`. |
| Cascata perde | nada (a cascata nunca consumiu as outras 11) |
| Acoplamentos | 🟢 baixos — mexe em seeds + `Ability` só se abrir estações/GI |
| 30.4 (3 pts) | 🟢 **cabe**: criar/garantir 2 roles + seed idempotente + eventual role de estações |
| 30.5 (3 pts) | 🟢 **cabe**: migrar 1:1 as 2 roles + relatório de não-resolvidos |
| Risco | 🟡 baixo; decisão **reversível** (aditivo) |

### Opção B — Expandir para as 11+7 do legado (ou subconjunto)

**B.1 — Expansão completa (11–13 roles + 7 perfis):**

| | |
|---|---|
| Cascata ganha | 🟢 **nada além de A** (a cascata só lê 2 roles) |
| Cascata perde | nada |
| Acoplamentos | 🟢 **altos**: reabrir `Ability` para estações (4 granularidades), excepcionais (seção inexistente), frequentadores/§6 (feature inexistente), GI (write inexistente), retificadores (tela inexistente), digital (inexistente) |
| 30.4 (3 pts) | 🟢 **ESTOURA** — 11–13 roles + 7 perfis + wiring por seção, várias **sem alvo** no código |
| 30.5 (3 pts) | 🟢 **ESTOURA** — migração 1:1 de todas + resolução de não-mapeados |
| Risco | 🟢 alto: roles sem efeito (decorativas) + perfis exigem camada nova (Rolify não os modela) |

**B.2 — Subconjunto mínimo que destrava valor (🟡 recomendação de escopo):**
> Criar/atribuir **as roles que têm consumidor real hoje**, e nada além:

1. `visualiza_frequentadores` — semear + migrar (**cascata passo 2**) — **essencial**.
2. `visualiza_terceirizados` — semear + migrar (**cascata passo 3**) — **essencial**.
3. (Opcional, se a abrangência for além de frequência) `gerencia_estacao` + `cadastra_estacao` + `visualiza_estacoes` + `controla_estacoes` e as 2 de gestor-individual — **somente se** a `Ability`/controllers forem reabertos junto.
4. **Adiar** (sem alvo no código): excepcionais (#5/#6), retificadores (#12), cadastro digital (#13), `gerencia_frequentadores`/§6 (#7) e os 7 perfis.

| | |
|---|---|
| Cascata ganha | 🟢 igual a A (as 2 essenciais) |
| 30.4/30.5 | 🟢 **cabe** se restrito a #1/#2; passa a **estourar** se incluir #3 (reabrir 4 granularidades de estação + GI) |
| Diferença vs A | só vale a pena se a **abrangência (Q3) = todas as seções** |

---

## 5. Q3 — Abrangência da integração

| Escolha | O que implica | Estimativa 30.4/30.5 (3+3) |
|---|---|---|
| **Só frequência** | Só #8/#9 importam. As 11 restantes gateiam **outras seções** → criá-las agora = **peso morto** (sem consumidor). | 🟢 **cabe folgado** (provável **< 6 pts**) |
| **Todas as seções** | Exige roles de **estação (#1–4)** e **gestor-individual (#10–11)** (telas existem) **e** as de excepcionais/retificadores/digital (telas **não** existem → role sem efeito). Implica reabrir `Ability`/controllers por seção. | 🟢 **ESTOURA** 6 pts (mesmo só estações+GI + reabertura de enforcement + migração) |

🟢 **Fato que ancora a Q3:** as roles de **estação**, **excepcionais**, **gestor-individual**, **retificadores** e **cadastro digital** só fazem sentido **fora** do domínio de frequência — e várias apontam para **seções que não existem** no Frequencia. Logo, "expandir" sem "todas as seções" é **incoerente**; e "todas as seções" **não cabe** no orçamento 3+3 desta sprint.

---

## 6. Recomendação do CTO 🟡 (o dev decide)

1. **Opção A + semear as 2 roles da cascata** como **entrega mínima de valor** desta sprint (30.4/30.5), com a migração 1:1 limitada a `PRESENCA_VISUALIZA_FREQUENTADORES`/`..._TERCEIRIZADOS`. Isso dá **valor real à cascata** (o objetivo declarado da frente 2) **dentro** do orçamento.
2. **Abrangência = só frequência** nesta sprint (Q3). Registrar "todas as seções" como **épico próprio** (com as seções faltantes: excepcionais, retificadores, digital), **fora** da Sprint 30.
3. **Adiar** os perfis (`PresencaProfilesEnum`): exigem camada nova no Rolify e não têm consumidor; não caber no escopo.
4. Se o PO **quiser** estações/GI agora, tratar como **frente separada** (reabrir `Ability`+controllers), **não** como "roles granulares" — senão vira role decorativa.

> Esta é uma **recomendação**. A decisão é do **dev/PO**.

---

## 7. Riscos e o que fica fora

**Riscos:**
- 🟡 **Role decorativa** (Opção B.1/B.2 com #3): criar role sem reabrir `Ability` dá falsa sensação de controle (nada muda).
- 🟡 **Perfis sem suporte nativo** (Rolify não modela bundles): exigiria tabela/convenção nova — decisão de arquitetura não coberta pela 30.3.
- 🟡 **Contagem divergente do PRD** (13 nomes vs "11 roles") e **composição omissa dos perfis**: risco de escopo ambíguo se não fixada no ruling.
- 🟡 **Seções inexistentes** (#5/#6/#12/#13): criar roles para elas não produz efeito verificável → risco de "entregar" algo inerte.
- 🟡 **Acoplamento admin-only** (§3): qualquer granularidade fora de frequência exige mudar autorização — **regra global do `CLAUDE.md`** (alterar autorização exige plano e aprovação), o que **excede** 30.4/30.5.

**Fica fora deste brief / desta sprint:**
- Implementar qualquer role (é 30.4/30.5, pós-ruling).
- Composição exata dos 7 perfis (PRD omisso — consulta ao legado necessária).
- Decisão de **ligar a flag `:on`** (é do PO, frente 4 / 30.8).
- As 4–5 flags de `CalculoDiario` (§6) — feature ausente, tratada no quadro §9 item 4.

---

## 8. Decisões que o dev/PO precisam tomar

| # | Decisão | Opções |
|---|---|---|
| **D-1** | Macro | **(A)** manter simplificado × **(B)** expandir |
| **D-2** | Se (B): escopo | **B.1** completo (11–13+7) × **B.2** subconjunto mínimo (só as 2 da cascata + eventualmente estações/GI) |
| **D-3** | Abrangência (Q3) | **só frequência** × **todas as seções** (estações/excepcionais/GI) |
| **D-4** | Contagem | qual número vale: "11" (§2.3) × **13** nomes enumerados |
| **D-5** | Perfis | entram no escopo? (exigem camada nova no Rolify — PRD omisso na composição) |
| **D-6** | Atribuição (critério 4 da 30.3) | seed manual × **migração 1:1 do Intranet** (D1 aponta para 1:1) + tratamento de não-resolvidos |
