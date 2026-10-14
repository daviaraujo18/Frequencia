## Relatório Bug Finder — Sprint 32 (tarefas 32.1 e 32.2) — hardening da guarda de mês finalizado

> **Branch:** `feature/demanda-32-2-espelho-handler`
> **Data:** 2026-10-14
> **Alvo:** guarda de mês finalizado por dia em `api-ponto/app/jobs/calcular_frequencia_job.rb` (32.1) e `api-ponto/app/services/recalcular_todos_handler.rb` (32.2)
> **Propósito:** teste adversarial das 4 categorias (virada de mês / guarda por dia · reuso do predicado · TOCTOU residual · memoização), mais idempotência, divergência handler × job, interações e regressão.
> **Restrições respeitadas:** nenhuma correção, nenhum commit/push, nenhuma alteração em código de produção. Testes exploratórios escritos e **removidos** ao final (working tree limpa).

### Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 9 exploratórios + 6 categorias de análise + 88 testes relacionados |
| Bugs NOVOS introduzidos pela 32.1/32.2 | **0** |
| 🔴 Crítico | 0 |
| 🟠 Alto | 0 |
| 🟡 Médio | 0 |
| 🟢 Baixo | 1 (TOCTOU residual — débito conhecido, **confirmado reproduzível**; janela reduzida, não ampliada, pelo hardening) |
| ⚪ Info | 1 (staleness de mês anterior aberto na virada — **pré-existente**, fora de escopo) |

**Veredito curto:** **não há bug funcional novo**. A guarda está correta e é idempotente nos 9 cenários adversariais; handler e job são semanticamente idênticos; o predicado é único; o memo não vaza. O único achado é a confirmação (não a descoberta) do TOCTOU já documentado.

---

## Bugs por Severidade

### 🟢 Bug 1 — TOCTOU residual: dia de mês recém-finalizado ainda pode ser reescrito (débito CONHECIDO e documentado)

- **Severidade:** 🟢 Baixo
- **RF/RN violado:** trava 17.2 (congelamento de mês finalizado) — janela residual, não o caminho determinístico.
- **Arquivos:** `api-ponto/app/jobs/calcular_frequencia_job.rb:96-116` · `api-ponto/app/services/recalcular_todos_handler.rb:131-153` · (mesma classe de `api-ponto/app/services/registro_recalculo_handler.rb:97`)
- **Passos (reprodução):**
  1. Consolidar e finalizar o mês corrente de um usuário (`ConsolidacaoMensalService.consolidar` + `.finalizar`), com um `CalculoDiario` de "snapshot".
  2. Simular a corrida — o predicado `ConsolidacaoMensalService.finalizado?` devolve `false` (leitura feita antes da finalização por outro processo).
  3. Rodar `CalcularFrequenciaJob.perform_now(user.id)`.
- **Atual:** o guard prévio passa (predicado `false`), `CalculoDiarioService.calcular` faz `save!` e **reescreve** o `CalculoDiario` do dia do mês finalizado; em seguida `ConsolidacaoMensalService.consolidar` levanta `MesFinalizadoError`, que é **engolido** pelo `rescue` (o `RegistroMensalFrequencia` congela, mas o `CalculoDiario` do dia já foi sobrescrito → inconsistência entre o diário e o mensal congelado, dentro da janela).
- **Esperado:** o dia de um mês finalizado nunca deveria ser reescrito. O predicado e a escrita são operações **separadas, sem lock compartilhado** — a corrida existe por design.
- **Evidência (teste exploratório ATAQUE 8, removido):**
  - Pré-condição assertada: `finalizado?(user, 2026, 9) == true` (mês finalizado no banco).
  - Com `finalizado?` stubado para `false` (simulando a leitura pré-finalização), o job reescreveu o dia: `refute_equal snapshot_antes, calculo.reload.attributes` **passou**, e `informacao` passou de `"snapshot_pre_race"` para `nil` (recalculado). Ou seja, a janela **é real e reproduzível**, não apenas teórica.
- **Classificação honesta (sem inflar):**
  - **NÃO é introduzido pela 32.1/32.2.** Antes do hardening a janela era **maior** (nenhuma checagem prévia): toda execução reescrevia e ainda `consolidar` levantava no fim. O hardening **reduziu** a janela para o intervalo predicado→escrita. Não há regressão.
  - Gatilho de materialização: a finalização de mês é **manual** (decisão 17.2) e a janela é ínfima. Por isso segue 🟢, coerente com `iteration_32.md:240` e `review_report_32_2.md` ⚪ O2.
  - **Nuance adicional do memo (desta entrega):** a memoização por `[ano, mes]` faz a leitura `false` valer para **todo o restante do processamento daquele usuário** (não é re-consultada a cada dia). Sem memo, uma finalização que ocorresse entre o check do dia-1 e o do dia-2 seria vista no dia-2 (skip). Com memo, o estado `false` é "grudento" até o fim do usuário → a janela intra-usuário fica do tamanho de um usuário, não de um check. Impacto prático desprezível (mesma classe 🟢, finalização manual, janela de microssegundos), mas é uma mudança comportamental **introduzida por esta entrega** — registrada para honestidade.
- **Teste sugerido:** cenário de corrida determinístico já é reproduzível com stub de `finalizado?` (como em ATAQUE 8). Se a finalização de mês passar a ser automatizada, reabrir com lock compartilhado (ex.: `SELECT ... FOR UPDATE` no `RegistroMensalFrequencia` dentro de `consolidar`, ou travar o registro antes de `calcular`).

---

### ⚪ Info — staleness pré-existente: mês ANTERIOR aberto é recalculado mas não reconsolidado na virada

- **Severidade:** ⚪ Info (fora do escopo da 32.1/32.2 — **pré-existente**, filosofia do job preservada de propósito)
- **Arquivos:** `api-ponto/app/jobs/calcular_frequencia_job.rb:96-108` e `:18-19` (comentário: "Consolida o mês corrente").
- **Descrição:** na virada (ex.: `hoje` = 01/11), o job recalcula os últimos 3 dias, que podem incluir 31/10 e 30/10. Se outubro estiver **aberto**, esses dias são recalculados (`CalculoDiario` reescrito) mas **outubro não é reconsolidado** (o job só consolida o mês de `hoje`). Logo o `RegistroMensalFrequencia` de outubro fica **stale** face ao `CalculoDiario` recém-calculado. Como a consolidação de novembro lê o `acumulado` de outubro (`buscar_saldo_mes_anterior`), um carryover de banco de horas pode refletir o valor antigo de outubro.
- **Evidência (teste exploratório ATAQUE 4, removido):** `21/10` consolidado; 3 dias do job recalculam `31/10` e `30/10`; `RegistroMensalFrequencia` de outubro permanece com o valor anterior (não reconsolidado).
- **Classificação honesta:** **NÃO é regressão da 32.1/32.2.** O comportamento é idêntico ao de antes (o loop sempre recalculou os 3 dias e só consolidou o mês corrente — `iteration_32.md` §"Fronteira explícita" e o comentário de topo do job proíbem reabrir essa filosofia). Registro apenas como observação de interação (categoria 7/8); a 32.1 melhora este ponto no caso em que o mês anterior está finalizado (dia não é mais reescrito). Nenhuma ação exigida nesta sprint.

---

## Cenários Testados (sem bugs)

Todos executados com o **motor real** (sem stub de `calcular`/`consolidar`), em arquivo exploratório temporário (removido ao final). Todos passaram (9 runs / 31 asserts / 0F / 0E).

| # | Categoria | Cenário | Resultado |
|---|---|---|---|
| ATAQUE 1 | Virada / fronteira de ano | `hoje`=01/01/2027; dez/2026 **finalizado** → 31/12 e 30/12 pulados; 01/01 calculado; jan consolidado | ✅ correto |
| ATAQUE 2 | Limites / bissexto | `hoje`=01/03/2028 (bissexto); fev/2028 **finalizado** → 29/02 e 28/02 pulados; 01/03 calculado | ✅ correto |
| ATAQUE 3 | Memo não vaza entre usuários | handler com A **finalizado** e B **aberto**: A intocado (0 `CalculoDiario`, snapshot preservado), B calculado (3 dias) e consolidado | ✅ memo é por usuário |
| ATAQUE 4 | Interação (aberto) | virada com ambos abertos: dia do mês anterior recalculado sem reconsolidação (staleness) | ⚪ ver Info |
| ATAQUE 5 | Idempotência cruzada | rodar `CalcularFrequenciaJob` e depois `RecalcularTodosHandler` sobre o mesmo alvo → `CalculoDiario` (data/meta/total) idênticos | ✅ |
| ATAQUE 6 | Reuso do predicado | `finalizado?` × condição de `raise` de `consolidar`: 4 estados (sem registro / não finalizado / finalizado / reaberto) sempre coerentes | ✅ sem segundo crivo |
| ATAQUE 7 | Interação | mês finalizado com `CalculoDiario` **faltando**: guarda bloqueia criação (0 registros) — congelamento preservado | ✅ |
| ATAQUE 8 | TOCTOU | corrida simulada: dia reescrito quando finaliza entre predicado e escrita | 🟢 ver Bug 1 |
| ATAQUE 9 | Regressão (falso-positivo) | mês anterior **sem** `RegistroMensalFrequencia` → `finalizado?` false → 31/10 e 30/10 recalculados (não é falso "finalizado") | ✅ sem falso-positivo |

### Análise das 6 categorias (evidência por leitura de código / grep)

1. **Virada de mês / guarda por dia:** `next if finalizado.call(dia.year, dia.month)` usa `dia.year/dia.month`, não o mês de `hoje` → cobre a virada (provado em ATAQUE 1, 2, 9 e pelos testes da suíte "virada de mes"). `hoje - dias_atras` (aritmética de `Date`) atravessa fevereiro/ano bissexto/ano com segurança.
2. **Reuso do predicado (sem 2º crivo):** `grep -rn "finalizado"` mostra que o ÚNICO predicado de finalização é `ConsolidacaoMensalService.finalizado?` (`consolidacao_mensal_service.rb:78-81`), consumido por job (32.1), `RecalcularTodosHandler` (32.2), `RegistroRecalculoHandler` (31.3) e `VincularDesvincularHandler` (31.5). A regra é `!registro.nil? && registro.finalizado?` e equivale à condição de `raise` de `consolidar` (`registro.persisted? && registro.finalizado?`) para todo par persistido — ATAQUE 6 confirma os 4 estados. **Nenhuma segunda condição divergente.**
3. **TOCTOU residual:** ver Bug 1 (reproduzido; severidade honesta 🟢).
4. **Memoização:** chave `[ano, mes]` com `Hash#key?` — correto no caminho `false` (a suíte prova 1 consulta por mês; `||=` falharia, mutation C do review). A chave é sempre `[Integer, Integer]` (`dia.year`/`dia.month`, `hoje.year`/`hoje.month`), **sem colisão/ambigüidade** possível; `Array` como chave de Hash é comparado por valor. O hash é **local** a `processar_usuario` (recriado por usuário) → **não vaza** entre usuários (ATAQUE 3).
5. **Idempotência:** `calcular` (`find_or_initialize_by`) e `consolidar` (`find_or_initialize_by`) idempotentes; rodar 2× e rodar job+handler produzem a mesma saída (ATAQUE 5).
6. **Divergência handler × job:** `#processar_usuario` dos dois é idêntico em semântica (mesma guarda `cpf.blank?`, mesmo memo, mesma guarda por dia, mesma guarda pré-consolidação, mesmos rescues na mesma ordem). Única diferença: prefixo do log e a seleção de alvo (`User.where.not(cpf:)` × `Pessoas::Vinculo.ativos`), ambas **não-semânticas para a guarda** e intencionais (documentadas na 31.4). **0 divergência de regra.**
7. **Interação:** usuário sem `cpf` → skip; sem `TimeRecord`/regime → `calcular` grava meta/total zerados e segue; múltiplos vínculos → `distinct.pluck` deduplica CPF; mês parcialmente consolidado → guarda só olha `finalizado`; `RegistroMensalFrequencia` inexistente → `false` (recalcula, correto).
8. **Regressão (falso-positivo de "finalizado"):** `finalizado?` só é `true` com registro persistido **e** `finalizado == true`; só `finalizar!` liga esse flag, `reabrir!` desliga. ATAQUE 9 prova que a ausência de registro não gera falso "finalizado".

### Evidências de execução

| Verificação | Comando | Resultado |
|---|---|---|
| Testes focados 32.1+32.2 | `bin/rails test test/jobs/calcular_frequencia_job_test.rb test/services/recalcular_todos_handler_test.rb` | **20 runs / 54 asserts / 0F / 0E / 0 skips** |
| Suíte relacionada (sem contaminação) | `+ registro_recalculo_handler_test, vincular_desvincular_handler_test, consolidacao_mensal_service_test, calculo_diario_service_test` | **88 runs / 245 asserts / 0F / 0E / 0 skips** |
| Exploratórios adversariais (arquivo temporário, removido) | 9 testes / 31 asserts | **0F / 0E** — as únicas falhas "esperadas" foram as asserções que COMPROVAM o Bug 1 (não falharam) |

`git status` final: apenas ruído de ambiente pré-existente (`config/credentials.yml.enc`, `config/environments/development.rb`, `log/*`, `tmp/cache/*`). **Nenhuma alteração de código de produção; nenhum commit/push.**

---

## Veredito Final

**Não há bug funcional novo introduzido pelas tarefas 32.1 e 32.2.** O hardening está correto: a guarda é por dia (cobre virada de mês, ano bissexto e fronteira de ano), reusa o único predicado canônico (sem segundo crivo), memoiza corretamente no caminho `false` sem vazar entre usuários, é idempotente e mantém paridade semântica total com o job.

Prioridade de ação:
1. **Nenhuma correção obrigatória.**
2. 🟢 **TOCTOU residual** — permanece débito conhecido/documentado; reabrir **somente** se a finalização de mês deixar de ser manual (ADR-0011/`iteration_32.md:240`). A nuance do memo (janela "grudenta" por usuário) fica registrada aqui.
3. ⚪ **Staleness de mês anterior aberto na virada** — pré-existente e fora de escopo; registrar como observação, sem ação nesta sprint.
