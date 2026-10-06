# Relatório de Revisão — Tarefa 30.6 (Fechar 🟡S2: testes PORO + twin SQL no passo compartilhado)

> **[⌂ Home](../README.md)** · Sprint 30 · Frente 3 · Tarefa **30.6** (2 pts · Dev A)
> **Veredito:** ✅ **Aprovado** — **Blockers: 0** | Sugestões: 2 (Melhoria: 1 / Débito: 1)

## Metadados

| Campo | Valor |
|-------|-------|
| Data da revisão | 2026-10-06 |
| Revisor | Code Reviewer |
| Worktree | `wt-30.6` — branch `feature/demanda-30-6-s2-twin-sql` @ `987ff39` |
| Origem → destino | `feature/demanda-30-6-s2-twin-sql` → `integration/sprint-29` |
| Insumo-contrato | ADR-0010 **regra 7** (`docs/adr/0010-arquitetura-cascata-autorizacao-frequencia.md`) |
| COMMIT_MODE | `manual` (sem commit/push nesta revisão) |

### Arquivos alterados revisados

| Arquivo | Δ | Papel |
|---------|-----|-------|
| `api-ponto/test/models/frequentadores_visiveis_test.rb` | +39 | teste novo: PORO + twin SQL no mesmo cenário (baseline regra 7) |

> **Não revisados como entrega (artefatos de ambiente):** `api-ponto/log/test.log`, `api-ponto/tmp/cache/bootsnap/load-path-cache` — **excluir do stage**. `app/assets/builds/application.css` (cópia de ambiente, **gitignore**) foi **removida ao fim** da revisão.
>
> **`git diff -- app/ lib/ config/ db/` = vazio** — nenhum arquivo de produção tocado (critério 4). ✅

---

## Resultado por item solicitado

### 1. Fidelidade à ADR-0010 regra 7 (ponto central) — ✅ CONFORME

A regra 7 exige prova nos **dois corpos**, no **mesmo cenário**, **ambos no baseline**. O teste novo (linhas 113–136) satisfaz literalmente:

- **PORO** (`AutorizacaoFrequencia#motivo`) com `GestorIndividual` **INATIVO** → `assert_equal :negado` (linha 122). ✅
- **Twin SQL** (`FrequentadoresVisiveis.para`) com o **mesmo cenário** → `assert_not_includes ... , vinculo_inativo.id` (linha 125). ✅
- **Controle positivo no mesmo teste** (não-degenerado, lição 33): o gerido com vínculo **ATIVO** é liberado pelo PORO (`:gestor_individual`, linha 132) **e** aparece no scope (`assert_includes`, linha 134). Sem esse controle, a negação poderia passar por cenário degenerado ("veria nada mesmo"). **Comprovadamente não-degenerado:** o `assert_includes` positivo falha se o passo 4 sumir por completo. ✅

O cenário é *compartilhado* e *não-degenerado*: ambos os alvos (`gerido`/`gerido_inativo`) são lotados na mesma unidade `sem_gestor` (sem gestor → sem via de hierarquia), têm pessoa no Pessoas, vínculo ATIVO e CPF. A ÚNICA diferença entre eles é `GestorIndividualGerenciado#ativo` (true × false). Isso é exatamente o discriminador do passo 4. ✅

### 2. Mutation testing — ✅ AS DUAS MUTAÇÕES MORREM PELO LADO CERTO (reproduzido por mim)

Reproduzi as mutações no trabalho isolado (`wt-30.6`), restaurando por `git checkout` (os dois modelos de produção estão em `HEAD` — sem risco de perder a entrega, que é um arquivo de teste, preservado).

| # | Mutação | Resultado observado | Assert de morte |
|---|---------|---------------------|-----------------|
| 1 | Remover `.ativos` do **PORO** (`autorizacao_frequencia.rb:157`) | **3F**: teste novo + fixture + propriedade | teste novo falha na **linha 122** (lado **PORO**) ✅ |
| 2 | Remover `.ativos` do **twin SQL** (`frequentadores_visiveis.rb:128`) | **2F**: teste novo + propriedade | teste novo falha na **linha 125** (lado **SQL**) ✅ |
| 3 | Mutação **DUPLA** (mesmo bug nos 2 corpos) | **3F**: teste novo (linha 122) + fixture (linha 83) + propriedade (contagem congelada, linha 62) | **pega** ✅ |

Detalhe da discriminação (evidência bruta):
- Mutação 1 → `Expected: :negado` na linha 122 do teste novo + divergência `gestor × gerido_inativo: scope=false poro=true (motivo=:gestor_individual)` na propriedade.
- Mutação 2 → `Expected [..] to not include 2320` na linha 125 + divergência `scope=true poro=false (motivo=:negado)` na propriedade.
- Mutação 3 → o alvo inativo **desaparece** como divergência (os dois corpos concordam no bug), mas é pego pela contagem congelada (`mudou o número de pares VISÍVEIS: Expected 34`).

**Mutação que NÃO morre?** Nenhuma relevante ao passo 4-ativo. A única mutação que não é detectada pelo escopo do débito é a quebra do `where.not(cpf: nil)` em `cpfs_dos_geridos` — irrelevante aqui porque todos os geridos do cenário têm CPF (não é o alvo da regra 7). Não há blocker.

**Observação adversarial (não-bloqueante):** dentro *deste* arquivo o twin **não** era totalmente cego no estado pré-30.6 — o teste de propriedade já sinalizava mutação unilateral como **divergência** scope×PORO, e o teste de fixture pré-existente (linha 83, `assert_equal :negado, motivos[:gerido_inativo]`) já matava a **mutação dupla**. O valor incremental real do teste novo é tornar o **par explícito no MESMO cenário** (com controle positivo), que é o gatilho binário que a regra 7 pede — e isso ele cumpre. A premissa da ADR ("mutar o PORO não derruba nenhum teste de listagem") refere-se à **matriz de aceite 29.8**, não a este arquivo (ver 🟡M1).

### 3. Só teste? — ✅ CONFORME

`git diff --name-only` = `test/models/frequentadores_visiveis_test.rb` (+ `log/test.log` e `tmp/cache/bootsnap/load-path-cache`, ruído de ambiente). `git diff -- app/ lib/ config/ db/` = **vazio**. Nenhum arquivo de produção tocado (critério 4). ✅

### 4. Regressão (adversarial) — ✅ O 2º F NÃO É REGRESSÃO DO TESTE NOVO

- **Arquivo-alvo isolado (sem mutação):** `26 runs / 93 assertions / 0F / 0E`. ✅
- **Arquivo-alvo sob paralelização** (junto de `test/lib`, total 55 runs > limiar 50): **nenhuma falha do teste novo** (o teste novo passa também em worker paralelo; não é flaky/order-dependent). ✅
- **O 2º F é `PessoasSchemaLoaderTest#test_rake_task_aborts_before_touching_any_database_outside_the_test_environment`** (`test/lib/pessoas_schema_loader_test.rb:40`), que faz **shell-out** a `bin/rails` (`Open3.capture2e`, `RUBYOPT=nil`). **É dependente de AMBIENTE, não de ordem, e não tem relação com o teste novo:**
  - Isolado no meu shell (`/usr/bin/ruby bin/rails test ...` mas com `PATH` ruby = **mise 3.3.8** herdado pelo subprocesso): **1F** — o subprocesso `bin/rails` (`#!/usr/bin/env ruby`) resolve o ruby do PATH (mise), que **não boota o bundle** (`Bundler::GemNotFound`) e a saída não casa o regex do guard.
  - Isolado com o ruby do **subprocesso** forçado a `/usr/bin/ruby` (que boota o bundle): **4 runs / 28 assertions / 0F / 0E** — passa, **idêntico** ao observado pelo Code Reviewer da 30.2 ("passa isolado: 4/28/0/0").
  - **Conclusão:** o F é artefato da resolução do ruby do **subprocesso** (PATH), não do teste novo. Não é regressão; não é blocker. O agente rotulou como "order-dependent" — a caracterização correta é **environment/invocation-dependent** (qual `ruby` o subprocesso `bin/rails` encontra). A conclusão substantiva do agente (não é regressão) está **correta**.
  - **Nuance adicional:** sob paralelização, `PessoasSchemaLoaderTest#test_accepts_the_configured_test_mirror_database` também aparece como **1E** (o Rails sufixa o nome do banco com o id do worker: `..._test_4` → `GuardError: must end with _test`). Pré-existente, inerente à configuração `parallelize` — não relacionado à 30.6.

### 5. Teste degenerado? — ✅ NÃO-DEGENERADO (confirmado por mutação)

O controle positivo (linhas 128–135) prova que o cenário tem via de acesso real (passo 4 ativo) — a negação não passa "por acaso" (não é o caso "o cenário veria nada mesmo"). A mutação do SQL (item 2) prova que a asserção negativa **discrimina** (o id inativo aparece quando `.ativos` some). ✅

---

## Blockers 🔴

**Nenhum.**

## Sugestões

| ID | Tipo | Descrição | Tarefa |
|----|------|-----------|--------|
| 🟡M1 | Melhoria | **Precisão da premissa/comentário (não-bloqueante).** O comentário do teste (linhas 103–112) e a premissa da ADR-0010 regra 7 dizem que o twin era "cego" e que o "mesmo bug nos 2 corpos escapava". Neste arquivo isso é **parcialmente impreciso**: o teste de propriedade já pegava mutação unilateral (divergência) e o teste de fixture pré-existente (linha 83) já pegava a mutação dupla. O real valor incremental é o **par explícito no mesmo cenário com controle positivo** (o gatilho binário que a regra 7 exige). Recomendação: (a) no teste, ajustar o comentário para não sugerir que a mutação dupla era totalmente indetectável antes; (b) ao CTO, registrar que o "cegueira do twin" é da **matriz 29.8**, não de `frequentadores_visiveis_test.rb`. Sem alteração de código necessária. | 30.6 / doc |
| 🟠D1 | Débito | **`PessoasSchemaLoaderTest` é frágil por depender do ruby do subprocesso.** O `test_rake_task_aborts...` faz shell-out a `bin/rails` e falha/passa conforme o `PATH` ruby do runner (mise × `/usr/bin/ruby`). Pré-existente (não é da 30.6), mas é uma armadilha de ambiente que contamina a leitura da suíte como baseline. Sugestão: fixar o ruby do subprocesso no teste (ex.: invocar `RbConfig.ruby bin/rails ...` em vez de `bin/rails`) ou documentar a invocação canônica. Registrado como débito, não blocker. | (chore) |

## Elogios 🟢

| ID | Elogio | Tarefa |
|----|--------|--------|
| 🟢E1 | **Controle positivo no mesmo teste** — evita o padrão degenerado (lição 33) e prova que a negação não passa por acaso. Exatamente o que a regra 7 pede. | 30.6 |
| 🟢E2 | **Discriminação correta e medida** — as mutações PORO e SQL morrem nos asserts dos lados correspondentes (linhas 122 e 125), e a mutação dupla é pega. Não é teste decorativo. | 30.6 |
| 🟢E3 | **Teste roda verde sob paralelização** — não depende de ordem; o baseline congelado da propriedade (34/70/104) permanece coerente. | 30.6 |

---

## Ações corretivas

- [ ] (Opcional / não-bloqueante) Endereçar 🟡M1 (ajuste de comentário + registro ao CTO) e registrar 🟠D1 como débito de chore.
- [ ] **Stage seletivo** — incluir apenas: `api-ponto/test/models/frequentadores_visiveis_test.rb`. **Excluir** `api-ponto/log/test.log` e `api-ponto/tmp/cache/bootsnap/load-path-cache`.
- [ ] Commits atômicos conforme o protocolo de entrega (Code Specialist).

## Recomendação de commit

Entrega técnica **aprovada** (0 blockers 🔴). Commit sugerido:

```
test: prova PORO + twin SQL no passo 4 (GI inativo) — fecha debito S2 (ADR-0010 regra 7)

Teste explicito do par no MESMO cenario: PORO AutorizacaoFrequencia#motivo com
GestorIndividual inativo -> :negado; twin SQL FrequentadoresVisiveis sem o alvo;
controle positivo com GI ativo. Mutation testing: mutar .ativos do PORO derruba o
teste do PORO; mutar o twin SQL derruba o do SQL; mutacao dupla tambem e pega.
Sem alteracao de codigo de producao (hardening de teste).
```

O fechamento da rastreabilidade (agrupamento de commits atômicos + protocolo de entrega) é **pré-requisito** para o início da próxima tarefa.
