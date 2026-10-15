# Relatório de Revisão — Tarefa 33.1 (Camada 1: contrato de postura + guard fail-closed)

**Revisor:** Code Reviewer (AI Workflow)
**Data:** 2026-10-15
**Branch de origem:** `feat/sprint-33-camada-1-guard-cascata` (working tree, **NÃO commitado** — `COMMIT_MODE=manual`)
**HEAD:** `8a315bd`
**Repo/app:** `Frequencia/` — app `api-ponto/`
**Especificação medida contra:** `docs/progress/iteration_33_plano_autorizacao_32_O1.md` (§0.1/§0.2, §0.5 D1–D5, §2.1, §7.1) + `docs/progress/iteration_33.md` (tarefa 33.1).

## Escopo revisado

| Arquivo | Natureza |
|---|---|
| `api-ponto/app/controllers/concerns/frequencia_authorization.rb` | produção — vira `ActiveSupport::Concern` + hook `included do` (`:coberto`) |
| `api-ponto/app/controllers/admin/application_controller.rb` | produção — `class_attribute`, macro `fora_da_cascata_justificativa`, `before_action :verificar_postura_cascata` |
| `api-ponto/app/models/frequencia_cascata_enforcement.rb` | produção (novo) — PORO da flag `FREQUENCIA_CASCATA_ENFORCEMENT` |
| `api-ponto/app/models/cascata_nao_declarada_error.rb` | produção (novo) — erro top-level |
| 7 controllers `Admin::*` não participantes (`dashboard`, `direitos_deveres`, `estacoes`, `gestores_individuais`, `regimes`, `sessions`, `versoes`) | produção — `fora_da_cascata_justificativa("…")` |
| `api-ponto/test/controllers/admin/cascata_enforcement_test.rb` | testes (novo, 13 testes) |
| `docs/progress/iteration_33.md` | rastreabilidade (status 33.1 ✅) |

Fora de escopo (ruído de ambiente, não avaliado): `config/credentials.yml.enc`, `config/environments/development.rb`, `log/*`, `tmp/cache/*`.

## Veredito

✅ **Aprovado** — **sem Blockers (🔴)**. A implementação cumpre a especificação aprovada (§2.1 do plano para o guard; D1/D2/D3/D4 codificadas na §7.1) e os critérios de aceite da 33.1. Os dois pontos que mais me preocupavam foram verificados empiricamente e **não** se confirmaram como defeiro:

- **Independência fail-closed × cascata (D2):** o guard é **genuinamente independente**. `verificar_postura_cascata` (`application_controller.rb:91-100`) referencia **apenas** `FrequenciaCascataEnforcement.log?`, que lê **somente** `FREQUENCIA_CASCATA_ENFORCEMENT`. Não há leitura de `FrequenciaAutorizacaoCascata`/`FREQUENCIA_AUTORIZACAO_CASCATA` no caminho do guard. Ausência de acoplamento escondido confirmada por leitura de código.
- **`class_attribute :cascata_postura` re-declarado no hook `included do`:** **seguro no Rails 8.1** — verificado por execução (`bin/rails runner`): sem warning, `Admin::ApplicationController.cascata_postura == nil`, `Admin::FrequenciaController == :coberto`, `Admin::DashboardController == :dispensado`; a re-declaração cria um atributo **próprio** no includer (`owner = #<Class:Admin::FrequenciaController>`) — isola, não mascara nem propaga valor indevido à base.

**Blockers: 0 | Sugestões: 5 (Melhoria: 4 / Débito: 1) | Elogios: 2**

## Evidências executadas (medidas neste review)

| Verificação | Comando | Resultado |
|---|---|---|
| Teste focado (novo) | `bin/rails test test/controllers/admin/cascata_enforcement_test.rb` | **13 runs / 57 asserts / 0F / 0E / 0 skips** (reproduz o reportado) |
| Área admin | `bin/rails test test/controllers/admin` | **234 runs / 1279 asserts / 0F / 0E / 0 skips** |
| RuboCop (tocados) | `bin/rubocop <7 arquivos>` | **7 files inspected, no offenses** |
| Zeitwerk | `bin/rails zeitwerk:check` | **All is good!** |
| Prova D3 (`Ability` intocada) | `git diff --stat -- app/models/ability.rb db/schema.rb config/routes.rb db/migrate/` | **vazio** |
| Prova varredura de cobertura | `grep -rn "class .*Controller <" app/controllers/admin/` + `grep -rEn "^\s*include FrequenciaAuthorization"` | **14 concretos**: 7 `:coberto` (include) + 7 `:dispensado` (macro) = **14/14** |

## Análise por requisito

1. **Contrato `:coberto`/`:dispensado` (fonte única)** ✅ — `include FrequenciaAuthorization` marca `:coberto` via hook `included do` (`frequencia_authorization.rb:31-34`); `fora_da_cascata_justificativa` marca `:dispensado`. Os **7** participantes declararam **sem tocar seus corpos** (o `include` já existia).
2. **Guard fail-closed × `log` (D2)** ✅ — `application_controller.rb:91-100`. `log`→`Rails.logger.warn`; `raise`→`CascataNaoDeclaradaError`. Delta testado: mesmo cenário, mesma mensagem, único delta = levantar × WARN.
3. **No-op para quem declarou** ✅ — `return if self.class.cascata_postura.present?` cobre `:coberto` **e** `:dispensado`; testado em ambos.
4. **Macro exige justificativa** ✅ — `raise ArgumentError if motivo.blank?` (`application_controller.rb:35-38`); testado com `""`, `nil`, `"   "` e verifica que a classe **não** foi marcada quando a macro falha.
5. **`FREQUENCIA_CASCATA_ENFORCEMENT` desacoplada, default `raise` em test/CI** ✅ — `frequencia_cascata_enforcement.rb:55-57` (`Rails.env.test? || ENV["CI"]` → `:raise`; demais → `:log`).
6. **Cobertura de anotação (14/14)** ✅ — varredura real confirma nenhum concreto ficou de fora; todos herdam diretamente da base (nenhum intermediário).
7. **Base `Presenca::*` intocada** ✅ — `Presenca::ApplicationController < ::ApplicationController` (não herdá `Admin::ApplicationController`); `respond_to?(:cascata_postura)` = `false` (verificado).
8. **`Ability`/schema/rotas/migrations intocados (D3)** ✅ — `git diff` vazio nos 4; nenhuma dependência nova; nenhuma ADR nova.
9. **Sem regressão** ✅ — área admin 234/1279/0F/0E; RuboCop 0; zeitwerk OK.

## Apontamentos

### 🟡 Melhoria — M1 — A varredura do teste de cobertura é **não-recursiva** e depende de `camelize` do nome do arquivo

- **Local:** `api-ponto/test/controllers/admin/cascata_enforcement_test.rb:199` (`Dir[Rails.root.join("app/controllers/admin/*_controller.rb")]`) e `:138-147`.
- **Problema:** o glob enxerga **apenas** `admin/*_controller.rb` (top-level). Hoje não há subpastas nem herdeiros fora de `admin/`, então a asserção está correta — mas um futuro `app/controllers/admin/<subpasta>/x_controller.rb`, ou um controller que herde `Admin::ApplicationController` de **fora** de `app/controllers/admin/`, escaparia deste teste (embora o guard de runtime ainda o cubra, porque vive na base).
- **Risco concreto:** falso-verde no build (a Camada 2 é justamente quem "fecha a classe" — §0.5/R5). Um controller novo e sensível fora do glob poderia ser mergeado sem que T2/T3 falhassem.
- **Sugestão:** a 33.2 deve usar glob **recursivo** (`app/controllers/admin/**/*_controller.rb`) e, idealmente, localizar os subclasses da base via `Admin::ApplicationController.descendants` (Rails 8 já eager-loads em test) em vez de derivar a constante do nome do arquivo. Registrar o limite explicitamente se a varredura por arquivo for mantida.

### 🟡 Melhoria — M2 — O `ApplicationController` (base) e um **comentário** em `estacoes_controller` casam o grep de recursos sensíveis → falso-positivo que a 33.2 terá que tratar

- **Local:** `api-ponto/app/controllers/admin/application_controller.rb:214` (`permission_check: TimeRecord`, menu) e `api-ponto/app/controllers/admin/estacoes_controller.rb:4` (menciona `TimeRecord`/`CalculoDiario`/… **em comentário**).
- **Problema:** o detector de drift da 33.2 (§2.2(1)) varre `admin/**/*.rb` procurando o conjunto fechado `TimeRecord | CalculoDiario | RegistroMensalFrequencia | IntervencaoFrequencia | Pessoas::Vinculo`. O **arquivo da base** casa (menu) e `estacoes` casa **por comentário** — nenhum dos dois "lê" o recurso de verdade.
- **Risco concreto:** se o detector não excluir a base abstrata e não descartar comentários, ele acusa drift falso (ou, pior, aceita a base como "sensível e declarada", mascarando o critério). É exatamente o ponto 5 do briefing.
- **Sugestão (para a 33.2):** excluir `application_controller.rb` do conjunto varrido (é a base abstrata, sem rotas — já excluída no teste da 33.1, `:139`); e alinhar o detector para ignorar linhas de comentário (ou aceitar a sobre-inclusão como intencional, documentando-a). Registrar como **risco explícito da 33.2**.

### 🟡 Melhoria — M3 — `fora_da_cascata_justificativa` **não persiste** o motivo: a checagem "justificativa não-vazia" da 33.2 fica refém de grep no fonte

- **Local:** `api-ponto/app/controllers/admin/application_controller.rb:35-38`.
- **Problema:** a macro apenas valida `motivo.blank?` e seta `:dispensado`; **não** guarda a string (nem em `class_attribute`, nem em constante). A 33.2 precisa exigir "justificativa não vazia", e para isso terá de **ler o texto-fonte** com regex. Grep é frágil: `fora_da_cascata_justificativa(MOTIVO_DASHBOARD)`, um heredoc, uma constante, ou uma quebra de linha não-trivial derrubam a heurística — ou o motivo vira **"declaração morta"** (presente no código, nunca consumida por nada em runtime).
- **Risco concreto:** critério de aceite "justificativa obrigatória" afirmado em runtime mas, na prática, só verificável por heurística de texto. Não é blocker (a macro já impede `blank` no load), mas o meta-teste pode passar/falhar por motivo errado.
- **Sugestão:** considerar persistir o motivo num `class_attribute :cascata_justificativa` na própria macro (`self.cascata_justificativa = motivo`), permitindo à 33.2 assertar `present?` de forma **runtime-fiável** (sem grep). Alternativa mínima: aceitar o grep e documentar a forma exigida (`fora_da_cascata_justificativa("…")` literal). Decisão da 33.2, mas registrada agora.

### 🟡 Melhoria — M4 — Divergência doc × código sobre o "kill-switch" `off`

- **Local:** `docs/progress/iteration_33.md` §"Compatibilidade e rollback" (linha ~363: "`FREQUENCIA_CASCATA_ENFORCEMENT=log` (ou `off`) desliga o guard de runtime") vs. `api-ponto/app/models/frequencia_cascata_enforcement.rb:33-39`.
- **Problema:** o código mapeia **qualquer** valor não-`raise` (inclusive `off`) para `:log` — que **não desliga** nada, apenas troca o `raise` por WARN. Não existe estado silencioso/`off` real. A doc sugere que `off` "desliga o guard".
- **Risco concreto:** operador lê a doc, seta `FREQUENCIA_CASCATA_ENFORCEMENT=off` esperando silêncio total e continua vendo WARN por request — ruído de log e expectativa errada. Baixo impacto, mas é promessa não cumprida.
- **Sugestão:** ajustar o texto da doc para "`=log` mantém o guard em modo observação (só WARN); `=raise` liga o fail-closed. Não há modo silencioso" — ou implementar de fato um `:off` que faça `return` sem log. **Não alterar** o `iteration_33.md` neste review (fora do meu mandato); fica como nota ao Code Specialist/Orchestrator.

### ⚪ Baixo — B1 — Re-declaração de `class_attribute` é redundante nos 7 controllers que herdam a base (mas segura)

- **Local:** `api-ponto/app/controllers/concerns/frequencia_authorization.rb:31-34`.
- **Problema:** para os 7 `Admin::*` (que já herdam o atributo da base) a re-declaração é redundante; ela só é **necessária** para o 8º includer não-controller (`Intranet::MigrarRolesCascataServiceTest::HostComCascata`, `test/services/intranet/migrar_roles_cascata_service_test.rb:68`), que não herda a base. Verificado seguro (sem warning, valor correto). O único risco residual é de **divergência futura**: se a base mudar a declaração (ex.: `instance_accessor: false`, novo default), os controllers cobertos **não** herdarão a mudança.
- **Sugestão:** opcionalmente condicionar (`class_attribute :cascata_postura, default: nil unless respond_to?(:cascata_postura)`) para deixar clara a intenção de "só se ainda não houver", ou manter como está e registrar que a base é a fonte canônica. **Não bloqueia.**

### 💡 Sugestão — S1 — `class_attribute` adiciona accessor de **instância** público aos controllers

- **Local:** `application_controller.rb:27` + concern `:32`.
- **Problema:** por default, `class_attribute` define também `cascata_postura`/`cascata_postura=` como métodos de instância. É superfície nova (mínima) em todo controller admin. Nada hoje consome o reader de instância.
- **Sugestão:** `class_attribute :cascata_postura, default: nil, instance_accessor: false` reduz a superfície e deixa explícito que a postura é decisão de **classe**, não de request. Cosmético.

### 💡 Sugestão — S2 — O teste `Presenca::* nao herda o guard` é fraco (quase tautológico)

- **Local:** `cascata_enforcement_test.rb:152-156`.
- **Problema:** `refute Presenca::ApplicationController <= Admin::ApplicationController` prova uma relação de herança estática, não o **efeito** (não prova que uma action de `Presenca::*` não dispara o guard). Verifica o que já é verdade por arquitetura.
- **Sugestão:** opcional — se quiser um teste com poder real, exercitar uma action `Presenca::*` real e assertar que `verificar_postura_cascata` **não** está na cadeia de callbacks dela (`_process_action_callbacks`). Baixa prioridade.

## Elogios

- 🟢 **E1 — Prova de intocabilidade embutida no deliverable.** O critério "`Ability` inalterada (D3)" é verificável por `git diff` e foi cumprido; a separação entre o guard (contrato de declaração) e a cascata (restrição de conteúdo) está honestamente documentada nos comentários do PORO e do guard — a equipe não vendeu "default-deny" onde não há.
- 🟢 **E2 — PORO da flag espelha fielmente o irmão `FrequenciaAutorizacaoCascata`** (mesma cultura: leitura a cada chamada, `VARIAVEL` como fonte única, `class << self`), e a mensagem WARN/raise é **uma só** (`msg`), garantindo o "único delta" prometido. Testes cobrem `raise`/`levantar`/`RAISE` e o default de test/CI.

## Ações corretivas

- [ ] **Nenhuma ação corretiva obrigatória para a 33.1** (sem Blockers). Os apontamentos M1/M2/M3 são insumos **para a 33.2** e M4 é precisão de doc.
- [ ] (33.2) Detector de drift: glob **recursivo** + excluir a base abstrata + tratar comentários (M1, M2).
- [ ] (33.2) Decidir entre persistir a justificativa (runtime-fiável) ou formalizar o grep (M3).
- [ ] (Orchestrator/Code Specialist) Corrigir o texto do "kill-switch" na doc de compatibilidade (M4) — **sem** eu editar `iteration_33.md` neste review.

## Nota de rastreabilidade

Conforme as restrições do review, **não** alterei `docs/progress/iteration_33.md` (o mandato do review proíbe editar o `iteration_33.md`). Este relatório é a fonte de verdade em `docs/quality/`; o registro no `iteration_33.md` (seção de review) fica a cargo do Orchestrator/Code Specialist.
