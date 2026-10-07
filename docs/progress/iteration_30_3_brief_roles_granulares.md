# Brief de decisão — Tarefa 30.3: Roles granulares (PRD §9 item 2)

> **Tipo:** brief de decisão (doc-only). **Não** é o ruling — o ruling é do **dev/PO**.
> **Autor:** CTO · **Data:** 2026-10-06 · **Status:** insumo de decisão — **rulingado (dev): D-1 = A; emendado em 2026-10-07 para A + expansão incremental dirigida pelo PRD** (ver **§9 — Desfecho e regra operacional**)
> **Rastreabilidade:** `PRD-REGRAS-NEGOCIO-PRESENCA.md` §2.3, §6, §9 item 2 · `docs/adr/0010` (passos 2/3 da cascata) · `docs/progress/iteration_29.md` (ruling D1, §Decisão D1; quadro §9) · `docs/progress/iteration_30.md` §30.3 (Q3), §"Ruling registrado" (2026-10-06) e §"Emenda do ruling A" (2026-10-07)
> **Objetivo:** encurtar a decisão do dev/PO entre **(A) manter simplificado** e **(B) expandir**, e fixar a **abrangência** (Q3). O dev decide. **Desfecho:** D-1 = **A + expansão incremental**; D-3 = **dirigida pelo PRD, caso a caso** (§9).

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

> **⚠️ Desfecho (dev, 2026-10-07):** **D-1 = A + expansão incremental**. A opção vencedora **não é** A puro (só as 2 roles) **nem** B puro (big-bang 11+7): é **A com expansão incremental dirigida pelo PRD** — ver **opção A+** ao fim desta §4 e **§9 (Desfecho e regra operacional)**. As opções A/B abaixo ficam **preservadas como histórico** do que foi decidido e por quê.

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

### Opção A+ — A com expansão incremental dirigida pelo consumidor (ESCOLHIDA — dev, 2026-10-07)

**O que é:** manter o ruling **A** (3+2 roles; as 2 da cascata semeadas/migradas na **30.9** ✅) **e**, a partir daí, **criar cada role granular do legado sob demanda — na mesma tarefa que implementa a seção do `PRD-REGRAS-NEGOCIO-PRESENCA.md` que a consome**. A role nasce **junto** com a `Ability`/controller que a usa (não antes, não "solta"). **Nada de 11+7 de uma vez** (não é B.1) e **nada de congelar a expansão** (não é A puro).

| | |
|---|---|
| Cascata ganha | 🟢 o mesmo que A (as 2 roles da cascata, entregues na 30.9); a expansão **não** é escopo da Sprint 30 |
| Risco da "role decorativa" (§7) | 🟢 **eliminado por construção** — a role só existe **com** o consumidor (a tarefa que a cria também reabre a `Ability`/controller) |
| Custo (30.4/30.5 desta sprint) | 🟢 **zero** — a tarefa "de roles" autônoma (big-bang) **não se aplica**; cada role futura é **orçada na tarefa que a consome** |
| Diferença vs A | **A deixa de ser "fim da linha"** — vira o **piso**; a expansão passa a ser **dirigida pelo PRD, caso a caso** |
| Diferença vs B | **não** exige reabrir a `Ability` de seções **inexistentes**; só se expande onde há seção implementável — **sem peso morto** |
| Perfis (7 `PresencaProfilesEnum`) | 🟡 seguem **adiados** (D-5) — Rolify não modela bundles; sem consumidor |

**Como funciona na prática (regra operacional — ver §9.2):** toda tarefa que implementar uma seção do PRD **cria, na própria tarefa, a role que ela consome e reabre a `Ability`/controller correspondente — com teste de que a role SEM atribuição não muda comportamento**. A atribuição segue o mecanismo **D-6/i** (migração 1:1 do legado) ou o que o dev definir para aquela role.

---

## 5. Q3 — Abrangência da integração

| Escolha | O que implica | Estimativa 30.4/30.5 (3+3) |
|---|---|---|
| **Só frequência** | Só #8/#9 importam. As 11 restantes gateiam **outras seções** → criá-las agora = **peso morto** (sem consumidor). | 🟢 **cabe folgado** (provável **< 6 pts**) |
| **Todas as seções** | Exige roles de **estação (#1–4)** e **gestor-individual (#10–11)** (telas existem) **e** as de excepcionais/retificadores/digital (telas **não** existem → role sem efeito). Implica reabrir `Ability`/controllers por seção. | 🟢 **ESTOURA** 6 pts (mesmo só estações+GI + reabertura de enforcement + migração) |
| **Dirigida pelo PRD, caso a caso — ESCOLHIDA (dev, 2026-10-07)** | Não cria nada agora; a role de cada seção nasce **na mesma tarefa** que a implementa (a que **reabre a `Ability`/controller**). Evita a role decorativa **sem** virar big-bang; expande conforme o PRD avança. | 🟢 **custo zero** nesta sprint (30.4/30.5 = N/A/substituída); cada role é orçada **na tarefa que a consome** |

🟢 **Desfecho da Q3 (dev, 2026-10-07):** **não** "só frequência" (fixo) **nem** "todas as seções" (de uma vez) — **dirigida pelo PRD, caso a caso**. Ver **§9**.

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

| # | Decisão | Opções | **Desfecho** |
|---|---|---|---|
| **D-1** | Macro | **(A)** manter simplificado × **(B)** expandir | ✅ **A + expansão incremental dirigida pelo PRD** (dev, 2026-10-07; **emenda** do ruling A de 2026-10-06 — ver §9) |
| **D-2** | Se (B): escopo | **B.1** completo (11–13+7) × **B.2** subconjunto mínimo (só as 2 da cascata + eventualmente estações/GI) | ✅ **N/A (big-bang)** — sob A+ **não há** subconjunto a fixar de uma vez; o escopo é **por seção do PRD, caso a caso** (§9.3) |
| **D-3** | Abrangência (Q3) | **só frequência** × **todas as seções** (estações/excepcionais/GI) | ✅ **Dirigida pelo PRD, caso a caso** (dev, 2026-10-07) — **nem** "todas de uma vez" **nem** "nada"; cada seção implementada puxa a sua role (§9) |
| **D-4** | Contagem | qual número vale: "11" (§2.3) × **13** nomes enumerados |
| **D-5** | Perfis | entram no escopo? (exigem camada nova no Rolify — PRD omisso na composição) |
| **D-6** | Atribuição (critério 4 da 30.3) | seed manual × **migração 1:1 do Intranet** (D1 aponta para 1:1) + tratamento de não-resolvidos | ✅ **(i) migração 1:1 do legado** (dev, 2026-10-06) — implementada na **30.9b** (`Intranet::MigrarRolesCascataService`); ver `iteration_30.md` §"Ruling D-6" |

---

## 9. Desfecho (dev, 2026-10-07) — A + expansão incremental dirigida pelo PRD

> **Reabertura da 30.4 pelo dev (2026-10-07).** Perguntado sobre a **abrangência** da expansão (**Q3 / D-3**), o dev respondeu **verbatim**:
>
> *"vamos criando as roles de acordo com o que for sendo implementado baseado no PRD de regras de negocio"*

**Interpretação (CTO, tendo o texto acima como fonte):** política de **criação incremental, dirigida pelo consumidor**. As roles granulares do legado (§2.1) passam a ser criadas **sob demanda**, à medida que a **seção do `PRD-REGRAS-NEGOCIO-PRESENCA.md` correspondente for implementada** — a role nasce **na MESMA tarefa** que implementa a `Ability`/controller que a consome. **NÃO é big-bang** (não cria as 11+7 de uma vez) e **NÃO é "nada"** (a política não congela: expande conforme o PRD avança). Isso **elimina por construção** o risco da "role decorativa" (§7).

### 9.1. Como a emenda refina o ruling 30.3 = A

| Antes (ruling A, 2026-10-06) | Depois (emenda, 2026-10-07) |
|---|---|
| **D-1 = A** — manter simplificado; **só** as 2 roles da cascata; nada de 11+7 | **D-1 = A + expansão incremental** — mantém o mínimo, **mas** as demais roles passam a ser criadas **sob demanda**, dirigidas pelo PRD |
| **D-3 = só frequência** (expansão fora / épico próprio) | **D-3 = dirigida pelo PRD, caso a caso** — cada seção implementada puxa a sua role; **nem** "todas de uma vez" **nem** "nada" |
| **30.4/30.5 = N/A** puro | **30.4 = substituída pela política incremental**; a criação de role vira **parte de cada tarefa futura** que implementa a seção do PRD |

O histórico do ruling A **não é apagado** — fica registrado em `iteration_30.md` §"Ruling registrado" (2026-10-06) e nesta §4/§8; esta §9 é a **emenda** que o refina.

### 9.2. Regra operacional (a política em uma frase)

> **Toda tarefa que implementar uma seção do `PRD-REGRAS-NEGOCIO-PRESENCA.md` cria, na própria tarefa, a(s) role(s) que ela consome e reabre a `Ability`/controller correspondente — com teste de que a role SEM atribuição não muda comportamento (inerte fora do consumidor).** A atribuição segue o mecanismo **D-6/i** (migração 1:1 do legado) ou o que o dev definir para aquela role.

**Corolários:**
- **Sem role decorativa:** a role só nasce **com** o consumidor (§7) — vira gatilho, não dívida.
- **Custo orçado na tarefa que a consome**, não numa tarefa "de roles" autônoma (a 30.4 big-bang deixa de existir).
- **Atribuição:** herda o padrão **D-6/i** (read-only do legado, `DRY_RUN`, relatório de não-resolvidos) — ver §8 D-6.
- **Teste obrigatório da role inerte:** sem atribuição, não altera comportamento (evita regressão silenciosa sob `:off`).

### 9.3. Gatilhos futuros — qual seção do PRD traz qual role

| Seção do PRD (se/quando implementada) | Role(s) que nascem **na mesma tarefa** | Existe no Frequencia hoje? |
|---|---|---|
| §4.3 / §6 — cap de banco de horas + 4 flags `CalculoDiario` | `PRESENCA_GERENCIA_FREQUENTADORES` | 🟢 **Não** — só a coluna `descontado_em_folha`; as `liberado_*`/`permitido_*` não existem no schema |
| §2.3 / §9 item 4 — Direitos, Feriados, Dias Excepcionais, Registros Manuais, Regimes | `PRESENCA_GERENCIA_EXCEPCIONAIS` + `PRESENCA_VISUALIZA_EXCEPCIONAIS` | 🟢 **Só `Regime`** (admin-only); **não há** modelos Feriado/DiaExcepcional/Direito/RegistroManual |
| §8 / §2.3 — estações (ver/controlar/gerenciar/cadastrar) | `PRESENCA_VISUALIZA_ESTACOES`, `PRESENCA_CONTROLA_ESTACOES`, `PRESENCA_GERENCIA_ESTACAO`, `PRESENCA_CADASTRA_ESTACAO` | 🟡 telas existem (**admin-only**); **controle remoto ausente** (há campos `vnc`/`anydesk`/`teamviewer`, sem ação) |
| §2.5 / §9 item 7 — `GestorIndividual` como fonte de autorização | `PRESENCA_VISUALIZA_GESTOR_INDIVIDUAL`, `PRESENCA_GERENCIA_GESTOR_INDIVIDUAL` | 🟡 tela `admin/gestores_individuais` (**index apenas**); **write ausente** |
| §2.3 — retificadores de banco de horas | `PRESENCA_GERENCIA_RETIFICADORES` | 🟡 model `RetificadorBancoHoras` existe; **sem controller/tela** |
| §2.3 / §8 — cadastro de digital biométrica via estação | `PRESENCA_CADASTRO_DIGITAL` | 🔴 **Inexistente** (sem modelo/controller) |

**O que NÃO existe no Frequencia hoje (não inventar):** modelos `Feriado`/`DiaExcepcional`/`Direito`/`RegistroManual`; as 4-5 flags `CalculoDiario` (§6); ação de controle remoto de estação; `GestorIndividual` **write**; controller/tela de retificadores; cadastro digital. As roles dessas seções **não** podem ser criadas "soltas" — seriam **decorativas** (§7).

### 9.4. Perfis (7 `PresencaProfilesEnum`)

Seguem **adiados** (D-5): Rolify não modela bundles/perfis nativamente e não há consumidor. Reavaliar **apenas se** o dev pedir, junto de uma seção que os consuma.

### 9.5. Perguntas abertas geradas por esta emenda

- **Q13 (defaults operacionais da política)** — ver `iteration_30.md` §"Perguntas abertas": (a) a **atribuição** da role entra na **mesma tarefa** ou em tarefa de migração à parte? (b) quando/quem resolve a **contagem 11×13 (D-4)** e a **composição dos 7 perfis**? (c) a política vale **também** para seções que já têm consumidor **admin-only** (estações/GI — reabrir a `Ability`)? **Decisão do dev** (recomendação do CTO 🟡 registrada na Q13).
