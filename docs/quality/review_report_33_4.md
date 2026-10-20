# Relatório de Revisão — Tarefa 33.4 (Sprint 33)

> **Modo:** `TASK_MODE=STANDARD`, `COMMIT_MODE=manual`, `MEMORY_MODE=classic`, `SUGGESTION_LEVEL=1`
> **Data:** 2026-10-16
> **Revisor:** Code Reviewer
> **Branch:** `feat/sprint-33-camada-2-conteudo-por-tela` → mesma (nada commitado; HEAD `2b92550`)
> **Arquivos revisados (working tree, não commitados):**
> - `api-ponto/test/controllers/admin/cascata_enforcement_test.rb` (T5 endurecido; 17 testes / 89 assertivas)
> - `docs/progress/iteration_33.md` (tarefa 33.4 + §Notas (33.4))
> **Código sob teste (somente leitura; `git diff app/` vazio ao final):**
> `api-ponto/app/controllers/admin/application_controller.rb`,
> `api-ponto/app/controllers/concerns/frequencia_authorization.rb`,
> `api-ponto/app/models/frequencia_cascata_enforcement.rb`.
> **Escopo:** reconciliação — a 33.4 **estende** o arquivo criado pela 33.1 (não o recria); o delta é o
> endurecimento de T5 + a prova de não-vacuidade por mutation testing.

---

## Veredicto

**✅ Aprovado — 0 Blockers 🔴.**

A entrega é fiel ao escopo reconciliado: T4/T5 já vinham da 33.1 e foram **reforçados** (não duplicados);
o endurecimento de T5 é **real** (não cosmético); e a prova de não-vacuidade por mutation testing
**reproduzi ao vivo** — as 3 mutações derrubam exatamente os testes reportados, com números idênticos.
Nenhuma mutação é tautológica. `app/**` restaurado (md5 idêntico).

---

## 1. Reprodução independente das mutações (prioridade 1)

Ambiente: `BUNDLE_PATH="$(pwd)/vendor/bundle" PATH=".../ruby/3.3.8/bin:$PATH" bin/rails test <arquivo>`
(mutações aplicadas sobre `app/**`, backup em `/tmp`, restauração por `cp` + conferência de md5).

| Mutação | Alvo | Medido por mim | Reportado (iteration_33 §Notas 33.4) | Bate? |
|---|---|---|---|---|
| **(i)** neutralizar o guard (`return` no topo de `verificar_postura_cascata`) | `application_controller.rb` | **6 failures / 0 errors** (17 runs) — inclui T4 (3 testes) + wiring + "mesma mensagem" + **T5 endurecido** | **6F** | ✅ |
| **(ii)** remover o hook `included do` do concern | `frequencia_authorization.rb` | **4 failures** em `cascata_cobertura_test.rb` (T2 árvore real, T2 injetar, T3 recíproco, T1 contraprova) **+ 2 failures** em `cascata_enforcement_test.rb` ("no-op :coberto", "todo `Admin::*` declara") | **4F (33.2) + 2F (33.1)** | ✅ |
| **(iii)** trocar o predicado da flag (`log?` → `modo == :raise`) | `frequencia_cascata_enforcement.rb` | **6 failures / 1 error** (17 runs) — o **error é o T5 endurecido**, que morre com `CascataNaoDeclaradaError` (o guard levanta em `log`) | **6F + 1E** | ✅ |

**Prova de restauração:** `md5sum -c` dos 3 arquivos ⇒ OK; `git diff --stat -- api-ponto/app/` ⇒ **vazio**;
`git status` mostra apenas o ruído pré-existente (`config/credentials.yml.enc`,
`config/environments/development.rb`, `log/*`, `tmp/*`) + os 2 entregáveis intencionais
(`cascata_enforcement_test.rb`, `iteration_33.md`).

**Conclusão:** a prova de não-vacuidade **não é crítica** — os três números bateram exatamente. O guard,
o hook de declaração e o PORO da flag são todos **efetivamente cobertos** (matar qualquer um derruba
testes reais).

---

## 2. O endurecimento de T5 é real ou cosmético? (prioridade 2)

**Real (modesto, mas legítimo).** `cascata_enforcement_test.rb:74-89` agora assere, na **linha do único
WARN** (`warns.first`), o nome da classe **E** o marcador `"sem postura de cascata declarada"`.

- Antes: `assert_match "Admin::...", io.string` (string inteira) + `assert_equal 1, warns.size`.
- Agora: os dois asserts miram `warns.first` — a linha do WARN. Um WARN espúrio que apenas *mencionasse*
  a classe em outra linha do log não satisfaria mais. É um ganho real de poder probatório.
- **Flakiness:** não. O bloco roda com um `Rails.logger` fresco (StringIO) e **só** chama `guard(...)`;
  sob `log` a flag é reconhecida (não dispara o WARN de "valor não reconhecido" do PORO), então
  exatamente **1** WARN é emitido — determinístico. Um WARN de outra origem no mesmo logger **quebraria**
  o `assert_equal 1`, o que é o comportamento **desejável** (não flakiness).
- **Limite (⚪ baixo):** o assert prova que a *linha* do WARN carrega a assinatura textual do guard; não
  amarra estruturalmente a emissão ao método (um caminho diferente que logasse a mesma string passaria).
  Como a string é única ao guard, na prática é suficiente.

---

## 3. Cobertura de `log` × `raise` (prioridade 3)

**Confirmado: mensagem idêntica, e comparada.** O guard monta `msg` uma vez e faz
`return Rails.logger.warn(msg) if ...log?` / `raise CascataNaoDeclaradaError, msg`
(`application_controller.rb:117-121`). O teste `"log e raise produzem a MESMA mensagem"` (:91-103)
captura `.message` do raise e asserta `assert_includes msg_log, msg_raise` — **não-vácuo** (se o log
não emitisse nada, `msg_log=""` reprovaria). O único delta é levantar × WARN, como especificado.

---

## 4. O que a 33.4 NÃO prova (prioridade 4)

Verificado contra §5 (T4/T5) e §2.1 do plano:

- **T4/T5 (§5):** cobertos. `log` para `:dispensado` (não emite WARN) coberto (`:129-140`); base
  `Presenca::*` não alcançada coberta (`:182-193`); valor não reconhecido fail-closed coberto (`:215-225`).
- **`skip_before_action :verificar_postura_cascata`** — **não** há teste que asserte que nenhum
  `Admin::*` desliga o guard. É o débito já registrado (M3 do review 33.2; Obs. 1 do `bug_report_33_1`;
  §Débitos do `iteration_33.md:487-491`). **Corretamente fora do escopo reconciliado da 33.4** — a 33.4
  não fecha esse caminho.
- **Guard em `Presenca::*`:** não é "caminho sem teste" — é **provado ausente** por efeito (`:182-193`).
- **Helper `admin_controller_classes` (`:276-281`):** glob **não-recursivo** (`admin/*_controller.rb`).
  Herdado da 33.1; a varredura recursiva é responsabilidade do meta-teste 33.2 (`CoberturaCascata`).
  Fora do delta da 33.4.

---

## 5. Apontamentos

### 🟡 Médio

| ID | Arquivo:linha | Problema | Risco | Sugestão |
|---|---|---|---|---|
| **M1** | `cascata_enforcement_test.rb:327` | O **wiring test** (`CascataEnforcementWiringTest`, a cadeia real de `before_action`) mantém o assert **fraco** do modo `log`: `assert_match "Admin::SemPosturaWiringController", io.string` — sem `warns.size` nem o marcador da mensagem. O endurecimento foi aplicado só ao teste unitário de T5. | Inconsistência: o caminho **mais realista** (callbacks) ainda aceitaria um WARN espúrio que apenas cite a classe; o ganho da 33.4 fica restrito ao caminho unitário. | Aplicar o mesmo endurecimento ao wiring (`assert_equal 1` + os 2 `assert_match` sobre a linha do WARN). |

### ⚪ Baixo

| ID | Onde | Problema | Risco | Sugestão |
|---|---|---|---|---|
| **B1** | Branch `feat/sprint-33-camada-2-conteudo-por-tela` | A 33.4 **não** criou branch própria — rodou sobre a branch da **33.3**. Desvio do padrão "1 tarefa = 1 branch" (§Notas 33.4, item 7). | Como nada está commitado (`COMMIT_MODE=manual`), quando o dev commitar, os changesets de 33.3 e 33.4 cairão na **mesma branch/commit** — granularidade de rastreabilidade diluída. | Registrar no commit de entrega que a branch cobre 33.3+33.4, **ou** separar os commits por tarefa no agrupamento atômico. Não é bloqueio. |
| **B2** | `cascata_enforcement_test.rb:85-86` | A assinatura textual do WARN é **duplicada como literal** no teste (`"sem postura de cascata declarada"`). | Se a mensagem do guard mudar, o teste quebra (aceitável — é o ponto), mas o literal acopla o teste ao texto. | Opcional: extrair a mensagem para uma constante no guard e referenciá-la, tornando o vínculo explícito. |

### 💡 Sugestões

| ID | Onde | Sugestão |
|---|---|---|
| **S1** | `iteration_33.md:487-491` | Manter o débito do `skip_before_action` aberto; a 33.4 não o fecha (nem deveria). Considerar, numa 33.x, um assert no meta-teste de que nenhum `Admin::*` faz o skip. |
| **S2** | Processo | O projeto **não tem framework de mutation testing**; a prova vive só nos **números** das §Notas. Já é o idiom dos reviews anteriores (29.3/29.6/32.1/32.2) — manter a prática de reproduzir as mutações no review, como feito aqui. |

### 🟢 Elogios

| ID | Onde | Elogio |
|---|---|---|
| **G1** | 33.4 (todas as 3 mutações) | Não-vacuidade **reproduzida ao vivo** e **idêntica** ao reportado (6F / 4F+2F / 6F+1E). O reporte não inflou números. |
| **G2** | `cascata_enforcement_test.rb` | Reconciliação honesta: **estendeu** o arquivo da 33.1 em vez de recriá-lo (anti-DRY), documentando o mapeamento de lacunas em §Notas (33.4, item 1). |
| **G3** | Padrões | Sem `remove_method`; ENV/logger via save/restore no `ensure`; `app/**`/`ability.rb`/`schema.rb`/rotas **intocados** (md5 idêntico após mutações). |
| **G4** | Suíte | Piso **medido por mim**: **1265 runs / 4436 assertions / 3 failures / 12 errors / 0 skips** — bate exatamente com o reportado (as 15 pré-existentes isoladas). RuboCop **0** offenses; `zeitwerk:check` **OK**. |

---

## 6. Evidência medida (resumo)

| Comando | Resultado medido |
|---|---|
| `bin/rails test test/controllers/admin/cascata_enforcement_test.rb` (baseline) | 17 runs / 89 assertions / **0F / 0E** |
| Mutação (i) — guard neutralizado | 17 runs / 75 assertions / **6F / 0E** |
| Mutação (ii) — hook `included do` removido | 33.2: 17/36/**4F** · 33.1: 17/78/**2F** |
| Mutação (iii) — `log?` → `modo == :raise` | 17 runs / 74 assertions / **6F / 1E** |
| `bin/rails test` (suíte completa) | **1265 / 4436 / 3F / 12E / 0 skips** |
| `bin/rubocop test/controllers/admin/cascata_enforcement_test.rb` | **0 offenses** |
| `bin/rails zeitwerk:check` | **OK** |
| `git diff --stat -- api-ponto/app/` | **vazio** (mutações restauradas) |

---

## 7. Ações corretivas

- [ ] (Opcional, 🟡 M1) Endurecer o assert do modo `log` no `CascataEnforcementWiringTest` (`:327`).
- [ ] (Opcional, ⚪ B1) No commit de entrega, explicitar que a branch cobre 33.3+33.4 ou separar commits.
- Nenhuma ação **bloqueante**.

**Próxima Ação:** Orchestrator avalia o estado e decide o próximo passo (candidata natural: 33.5).
