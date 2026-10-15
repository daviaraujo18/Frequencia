## Relatório Bug Finder — Sprint 33 (tarefa 33.2) — meta-teste de drift + prova do gate (Camada 2)

> **Branch:** `feat/sprint-33-camada-2-meta-teste-drift` (working tree, **NÃO commitado** — `COMMIT_MODE=manual`)
> **Data:** 2026-10-15
> **Alvo (Camada 2, build):** `api-ponto/test/support/cobertura_cascata.rb` (detector `CoberturaCascata`: `sensivel?`,
> `declarado?`, `detectores`, `arquivos_do_app`, `RECURSOS_SENSIVEIS`) e
> `api-ponto/test/controllers/admin/cascata_cobertura_test.rb` (16 testes). Consome o contrato da 33.1
> (`cascata_postura`, `cascata_justificativa`, `include FrequenciaAuthorization`).
> **Propósito:** teste adversarial da tarefa 33.2 — falsos-negativos (escape do gate), falsos-positivos (build quebrado
> indevidamente), fronteira de palavra de `cita_recurso?`, derivação de `RECURSOS_SENSIVEIS`, varredura por caminho,
> determinismo/ordem e tautologia residual. **Não duplica** o `review_report_33_2.md` (M1–M4/B1–B4/S1–S3 — já insumos).
> **Restrições respeitadas:** nenhuma correção, nenhum commit/push, nenhuma alteração em código de produção. Sondas
> rodadas via `bin/rails runner` + uma mutação temporária do helper (`sob_admin`), **removida ao final** (md5 confirmado
> idêntico). Nenhum resíduo na árvore.

### Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 8 ângulos adversariais + 13 sondas de conteúdo + 1 mutação do helper + 16 testes da 33.2 |
| Bugs NOVOS com impacto hoje | **0** (nenhum falso-negativo verde na árvore atual) |
| 🔴 Crítico | 0 |
| 🟠 Alto | 1 (`declarado?` levanta `NoMethodError` no caso que o critério de CAMINHO existe para pegar) |
| 🟡 Médio | 1 (o teste "critério por CAMINHO" não exercita o critério; `sob_admin` é código não-provado) |
| 🟢 Baixo | 0 |
| ⚪ Observação | 3 (assert tautológico; falso-positivo de base abstrata intermediária; helper não autossuficiente) |
| 💡 Sugestão | 2 (limite de indireção/SQL cru; `=begin/=end` não tratado) |

**Veredito curto:** o meta-teste **não é tautológico** (confirmei por mutação que o gate fica vermelho) e **não há
falso-negativo verde** na árvore real — nenhum controller admin sensível escapa com build verde por indireção textual
(os caminhos plausíveis de escape são os limites já declarados). **Porém**, a correção **M1 do review 33.2** (critério
por **CAMINHO** / `sob_admin`) está **defeituosa e não-provada**: o ramo que ela adiciona **levanta `NoMethodError`**
(o `declarado?` não sabe avaliar uma classe que não herde a base admin) e **nenhum teste a cobre** (a remoção de
`sob_admin` mantém a suíte 16/51/0F/0E — provado por mutação). Isso **contradiz parcialmente** a leitura do review de
que o M1 está "fechado": a classe do Bug 🔴1 continua fechada **na prática** (o build fica vermelho, mesmo que por
ERRO), mas o mecanismo novo é inconsistente e a prova que o acompanha é vazia.

---

## Bugs por Severidade

### 🟠 Bug 1 — `declarado?`/`detectores` levantam `NoMethodError` no cenário que o critério de CAMINHO (M1) foi criado para pegar

- **Severidade:** 🟠 Alto (defeito num mecanismo recém-adicionado; o cenário é justamente o que o M1 do review declarou plausível — "um arquivo novo colocado no lugar errado")
- **RF/RN violado:** critério de aceite T2/M1 da 33.2 (`iteration_33.md` linhas 249–258, "um controller sensível **criado em subpasta** **ou** que herde `Admin::ApplicationController` de **fora** de `admin/` → vermelho"; e a nota de implementação (33.2) item 1: "arquivo que não resolve a constante também é retido (fail-safe); retenção por **CAMINHO** — pega um controller admin que *não* herde a base e que, só por ancestralidade, escaparia").
- **Arquivos:**
  - `api-ponto/test/support/cobertura_cascata.rb:60-68` (`declarado?` — chama `klass.cascata_postura` sem guarda)
  - `api-ponto/test/support/cobertura_cascata.rb:74-76` (`detectores`)
  - `api-ponto/test/support/cobertura_cascata.rb:102-105` (retenção por `sob_admin` — o critério do M1)
- **Passos (reprodução via `bin/rails runner`, sem tocar na árvore):**
  1. Definir uma classe admin que **não** herde a base admin (uso `::ApplicationController` para fugir do nesting lexical):
     ```ruby
     module Admin; end
     class Admin::TopLevelProbeController < ::ApplicationController; end
     ```
  2. Criar um arquivo que a varredura retém pelo critério de CAMINHO e armadilhar a constante:
     `admin/top_level_probe_controller.rb` com `class Admin::TopLevelProbeController < ::ApplicationController; def index; TimeRecord.all; end; end`.
  3. `CoberturaCascata.arquivos_do_app(raiz: tmp)` → retém o arquivo (critério `sob_admin`). `sensivel?` → `true`.
  4. `CoberturaCascata.detectores(arquivos)` →
- **Atual:** `NoMethodError: undefined method 'cascata_postura' for class Admin::TopLevelProbeController` — o detector **explode** em vez de reportar o drift. O meta-teste T2 (que chama `detectores` sobre a varredura real) **ERRORARIA** com `NoMethodError`, não falharia de forma limpa. A causa: o critério `sob_admin` retém a classe, mas `declarado?` assume que **toda** classe retida responde a `cascata_postura` (só quem herda `Admin::ApplicationController` — ou inclui `FrequenciaAuthorization` — tem o `class_attribute`). O `rescue StandardError` de `classe_do_controller` (que devolveria `nil`) **não** protege este ponto — a classe resolve, e o erro só aparece na avaliação da postura.
- **Esperado:** `declarado?` tratar como NÃO declarada uma classe que não responda a `cascata_postura` (ex.: `return false unless klass.respond_to?(:cascata_postura)`), devolvendo o drift **limpo** (o arquivo sensível sem postura vai para a lista de drift) — ou o critério `sob_admin` ser removido e o limite documentado. Qualquer das duas mantém o fail-closed, mas a atual entrega um ERRO confuso em vez do sinal de contrato.
- **Nuance honesta:** o build **permanece vermelho** (fail-closed preservado) — **não** há escape com build verde por este caminho. O defeito é de robustez/contrato (e de prova: ver Bug 2), não um furo de autorização.
- **Teste sugerido:** adicionar ao meta-teste um caso sintético com classe resolvível que **não** herde a base admin (sem colidir com constante já carregada — ver Bug 2) e assertar que `detectores` a reporta como drift **sem levantar**.

---

### 🟡 Bug 2 — O teste "critério por CAMINHO" (M1) não exercita o critério; o stub tem nome/comentário falsos e `sob_admin` é código não-provado

- **Severidade:** 🟡 Médio (teste verde por motivo diferente do que nomeia; a correção do M1 fica **sem cobertura** — provado por mutação)
- **RF/RN violado:** critério de aceite M1 da 33.2 (`iteration_33.md:256-258`) e o próprio nome/comentário do teste `"M1(33.2): controller sob admin/ que NAO herda a base admin e retido (criterio por CAMINHO)"`.
- **Arquivos:**
  - `api-ponto/test/controllers/admin/cascata_cobertura_test.rb:44-45` (stub `Admin::NaoHerdaBaseAdminTestStubController < ApplicationController`)
  - `api-ponto/test/controllers/admin/cascata_cobertura_test.rb:153-165` (o teste do critério por CAMINHO)
  - `api-ponto/test/controllers/admin/cascata_cobertura_test.rb:21` (o `module Admin do ... end` que envolve os stubs)
- **Passos (reprodução via `bin/rails runner`, nos termos do próprio teste):**
  1. `require` do `test_helper` + do arquivo de teste; ler `Admin::NaoHerdaBaseAdminTestStubController.superclass` →
     `Admin::ApplicationController` (**não** a raiz).
  2. `Admin::NaoHerdaBaseAdminTestStubController < Admin::ApplicationController` → `true`; `respond_to?(:cascata_postura)` → `true`.
  3. No teste (linha 153), o arquivo criado em `Dir.mktmpdir` declara `class Admin::NaoHerdaBaseAdminTestStubController < ApplicationController` — **top-level**, logo `< ApplicationController` (raiz). Mas o nome da constante **já existe** (definido pelo stub do próprio arquivo de teste, carregado antes). `CoberturaCascata.classe_do_controller` faz `safe_constantize` → devolve essa constante **já carregada**, que **herda a base admin**.
  4. Mutação: remover `|| sob_admin` de `cobertura_cascata.rb:104` e rodar `bin/rails test test/controllers/admin/cascata_cobertura_test.rb` →
- **Atual:** (a) o stub `NaoHerdaBaseAdminTestStubController` **herda a base admin** (o nesting `module Admin` faz `ApplicationController` resolver para `Admin::ApplicationController`), contrariando o comentário "herda a raiz" e o nome do teste (linhas 40-45); (b) a retenção no teste vem da **ANCESTRALIDADE** (constante pré-carregada que herda a base), **não** do critério por CAMINHO; (c) **remover `sob_admin` do detector mantém a suíte 16/51/0F/0E** — ou seja, **nenhum** teste cobre o critério de caminho do M1 (o único arquivo real retido só por caminho é `admin/application_controller.rb`, que é imediatamente excluído por identidade em `:104`).
- **Esperado:** um teste que **de fato** exercite `sob_admin` — um arquivo sob `admin/**` cuja classe resolva e **não** herde a base admin (sem colidir com constante já carregada) — e, uma vez corrigido o Bug 1, que o detector o reporte como drift limpo. Alternativamente, remover o critério e documentar o limite. O comentário "herda a raiz" deve ser corrigido (é factualmente falso).
- **Interação com o Bug 1:** os dois achados são faces do mesmo defeito — o critério por CAMINHO (M1) **não é exercitado** e, quando fosse, **quebraria** com `NoMethodError`.

---

### ⚪ Observação 1 — O assert "conjunto fechado" é (hoje) tautológico: compara a expressão derivada com ela mesma

- **Severidade:** ⚪ Baixo
- **Arquivo:** `api-ponto/test/controllers/admin/cascata_cobertura_test.rb:55-56`
- **Observado:** `assert_equal Ability::RECURSOS_FREQUENCIA.map(&:name) + [ "Pessoas::Vinculo" ], CoberturaCascata::RECURSOS_SENSIVEIS` — como `RECURSOS_SENSIVEIS` **é** literalmente `Ability::RECURSOS_FREQUENCIA.map(&:name) + ["Pessoas::Vinculo"]` (helper linha 35), os dois lados são a **mesma** expressão; o assert **nunca pode falhar** no código atual. O que de fato ancora o conjunto é o `assert_includes` de `%w[...]` (linhas 58-62), que é uma lista **paralela** hardcoded (não derivada).
- **Esperado:** o assert só tem valor se alguém **regredir** `RECURSOS_SENSIVEIS` para uma lista paralela (aí falharia), mas como está não guarda nada novo. Sugestão: manter como documentação do vínculo e adicionar um assert que prove a **derivação viva** (ex.: assertar que o conjunto **não** é uma constante literal — ou marcar explicitamente como contrato documental). Vale registrar que o `assert_includes` reintroduz a lista paralela no nível do teste (embora a derivação garanta a cobertura do lado do detector).

---

### ⚪ Observação 2 — Falso-positivo latente: base abstrata **intermediária** sob `admin/` que cite um recurso (padrão do menu) é acusada de drift

- **Severidade:** ⚪ Baixo (só ocorre após refatoração estrutural futura; hoje a árvore real tem só uma base)
- **Arquivo:** `api-ponto/test/support/cobertura_cascata.rb:104` (exclusão por **identidade**: `next if klass == base`)
- **Passos (reprodução via `bin/rails runner`, `Dir.mktmpdir`):** criar `admin/base_abstrata_probe_controller.rb` com
  `module Admin; class BaseAbstrataProbeController < Admin::ApplicationController; MENU = [{ permission_check: TimeRecord }]; end; end` →
  `arquivos_do_app(raiz: tmp)` retém; `sensivel?` → `true`; `detectores` → devolve o arquivo (drift).
- **Observado:** a **única** base abstrata excluída é `Admin::ApplicationController` (por identidade). Qualquer outra base abstrata sob `admin/**` que **cite um recurso no menu** — exatamente o padrão da base real (`application_controller.rb:235`, `permission_check: TimeRecord`) — é marcada como sensível e, se não declarar postura, vira **drift → build vermelho indevido**. É a assimetria deixada pela correção M1 (por caminho): ela amplia a **retenção** sem ampliar a **exclusão** de abstratas.
- **Esperado:** excluir bases abstratas por outro critério (ex.: classe sem actions roteáveis / `abstract_class` / nome terminando em `ApplicationController`/`BaseController`) ou documentar que só a base canônica é excluída. Como o padrão de refatoração "extrair base com menu" é plausível, vale registrar.

---

### ⚪ Observação 3 — O helper não é autossuficiente: referencia `Ability` no **load** (acopla-se ao ambiente Rails)

- **Severidade:** ⚪ Baixo
- **Arquivo:** `api-ponto/test/support/cobertura_cascata.rb:35` (`RECURSOS_SENSIVEIS = (Ability::RECURSOS_FREQUENCIA.map(&:name) + ...)`)
- **Observado:** a derivação é **avaliada no load** do arquivo e referencia `Ability` diretamente. Carregado fora do contexto Rails (ex.: `require` cru, sem autoload), o arquivo levanta `NameError: uninitialized constant Ability`. No uso atual (sempre após `test_helper`, que sobe o Rails) é inócuo; é apenas um acoplamento a registrar (o `require "pathname"` do topo sugere intenção de ser “puro”, mas ele depende do autoload do Rails para `Ability`).
- **Esperado:** documentar o acoplamento ou derivar sob demanda (memoizado) para permitir teste unitário isolado.

---

### 💡 Sugestão 1 — `sensivel?` não enxerga leitura por nome de **tabela**/SQL cru nem por indireção (limite declarado)

- **Arquivo:** `api-ponto/test/support/cobertura_cascata.rb:138-140` (`cita_recurso?`) e escopo estático de `sensivel?`.
- **Sondado (13 casos):** casam → `Pessoas::Vinculo.frequentadores_ativos`, `::Pessoas::Vinculo.all`, `"TimeRecord".constantize`, `x = 1 # TimeRecord` (comentário inline), bloco `=begin/=end` com `TimeRecord`, heredoc com `TimeRecord`, `RECURSO = TimeRecord; RECURSO.all`. **NÃO** casam → `TimeRecordsController` (correto), `:time_record`, `time_records`, `ActiveRecord::Base.connection.execute("select * from time_records")`, `vinculos.frequentadores_ativos`, `authorize! :read, :all`.
- **Ponto:** a fronteira de palavra para `Pessoas::Vinculo` e `TimeRecord` funciona como documentado (bom — `::Pessoas::Vinculo` e `.constantize` são pegos). O escape real é a leitura **sem o nome do recurso no texto** (SQL cru por nome de tabela, associação `current_user.vinculos...`, service intermediário) — que é o **limite declarado** (nota (33.2) item 10 e §"Riscos" 🟡 do `iteration_33.md:426`). Sem ação; apenas reconfirmado.

### 💡 Sugestão 2 — `=begin/=end` não é tratado como comentário (sobre-inclusão fail-closed)

- **Arquivo:** `api-ponto/test/support/cobertura_cascata.rb:132-134` (`linhas_de_codigo` só descarta linhas que **começam** com `#`).
- **Sondado:** um bloco `=begin ... =end` contendo `TimeRecord` faz `sensivel?` → `true` (a linha do meio não começa com `#`). É a mesma direção fail-closed do comentário inline (M4) — intencional e documentada; registro apenas para completude (hoje não gera drift, pois toda a árvore declara).

---

## Cenários Testados (sem bugs)

1. **Determinismo/ordem:** meta-teste isolado (16/51/0F/0E), com `--seed 1` e `--seed 6000` (idênticos), e **junto** da 33.1 (`cascata_cobertura_test.rb` + `cascata_enforcement_test.rb` = 33/138/0F/0E). Sem dependência de ordem de `Dir[]`, de `require_relative` ou de estado global. `parallelize` (`test_helper.rb:18`, limiar 50) mantém o meta-teste em processo único — sem interação.
2. **Varredura real:** `arquivos_do_app` devolve **exatamente os 14 controllers concretos** (`admin/application_controller.rb` excluído por identidade; `api_controller.rb`, `application_controller.rb` raiz, `Presenca::*`, `Users::*` fora). **6 sensíveis** (`dashboard`, `frequencia`, `frequencia_por_orgao`, `frequentadores`, `time_records`, `users`), **0 drift** — confirma a nota (33.2) item 4.
3. **Falso-negativo (sem build verde):** para os caminhos plausíveis de escape (constante alias `RECURSO = TimeRecord`, `"TimeRecord".constantize`, `::Pessoas::Vinculo`), o detector **pega** (sensível). O único escape é a indireção sem o nome do recurso no texto — limite declarado (Sugestão 1). Os demais casos de "escape" (classe admin que não herda a base) **não** escapam: geram ERRO (Bug 1), não build verde.
4. **Base abstrata (`application_controller.rb`) excluída:** confirmado (`refute_includes` + varredura real).
5. **Comentário de linha inteira ignorado / inline mantido (M2/M4):** confirmado por sonda (`# só comenta...` → `false`; `x = 1 # TimeRecord` → `true`).
6. **`skip_before_action :verificar_postura_cascata`:** `grep` confirmou que **nenhum** controller real usa o skip (só comentários e o teste da 33.1). Débito já registrado (`iteration_33.md:446-450`); nem a Camada 1 nem a 33.2 o detectam — comportamento conhecido, não é bug novo.
7. **Flag-independência:** `grep` confirmou que o helper não referencia `FREQUENCIA_AUTORIZACAO_CASCATA`/`FREQUENCIA_CASCATA_ENFORCEMENT` (só o teste, via `com_env`). Resultado idêntico sob {off,shadow,on}×{log,raise}.
8. **Derivação de `RECURSOS_SENSIVEIS`:** um recurso novo em `Ability::RECURSOS_FREQUENCIA` passa a ser coberto automaticamente (a constante deriva da fonte no load) — o vínculo existe; só o assert de teste que o documenta é tautológico (Observação 1).

---

## Ações corretivas

- [ ] **(Obrigatório para fechar o M1 de verdade) Bug 1:** guardar `declarado?` contra classe sem `cascata_postura`
      (`return false unless klass.respond_to?(:cascata_postura)`) — ou remover `sob_admin` e documentar o limite.
- [ ] **Bug 2:** corrigir o teste/stub do critério por CAMINHO (stub que **realmente** não herde a base + não colida com
      constante pré-carregada) e o comentário "herda a raiz"; garantir que remover `sob_admin` **derrube** um teste.
- [ ] (Opcional) **Observações 1-3 / Sugestões 1-2:** assert de derivação viva; exclusão de bases abstratas genéricas;
      doc do acoplamento a `Ability`; nota sobre `=begin/=end`.

## Nota de rastreabilidade

- Conforme as restrições do teste adversarial, **não** alterei código de produção, testes, `iteration_33.md`, o plano
  aprovado nem ADRs. Este relatório é a fonte de verdade em `docs/quality/`; o registro no `iteration_33.md`
  (seção de bugs) fica a cargo do Orchestrator/Code Specialist.
- Sondas executadas via `bin/rails runner` (arquivos em `/tmp`, removidos) + **1 mutação temporária** de
  `test/support/cobertura_cascata.rb` (remoção de `|| sob_admin`), **restaurada** — md5 antes/depois idêntico
  (`373119360ac9aee8d25d1b15f99f0645`), `git status` do helper = `??` (inalterado, não commitado). Nenhum resíduo na árvore.
