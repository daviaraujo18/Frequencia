# Relatório Bug Finder — Tarefa 33.3 (Sprint 33, Camada 2: testes de conteúdo por tela)

> **Branch:** `feat/sprint-33-camada-2-conteudo-por-tela` (working tree, **NÃO commitado** — `COMMIT_MODE=manual`)
> **HEAD:** `86da982`
> **Data:** 2026-10-15
> **Alvo analisado:** `api-ponto/test/controllers/admin/cascata_conteudo_test.rb` (novo, 9 testes) +
> `api-ponto/test/controllers/admin/users_controller_test.rb` (alterado) + `docs/progress/iteration_33.md`
> **Modo:** adversarial (sondas de mutação aplicadas e **restauradas**; `git diff app/**` = vazio)
> **Não duplica** os achados A1/M1/M2/B1/B2 do `review_report_33_3.md` — este relatório procura **outros**.

## Resumo

| Métrica | Valor |
|---------|-------|
| Cenários/mutações executados | 11 |
| Bugs encontrados | 4 |
| 🔴 Crítico | 0 |
| 🟠 Alto | 0 |
| 🟡 Médio | 1 |
| 🟢 Baixo | 0 |
| ⚪ Observação | 3 |

**Veredito:** **NÃO contradiz** o veredicto do review (0 blockers). Nenhuma vulnerabilidade de runtime
revelada — as 4 telas com fonte real efetivamente falham sob mutação da cascata (reproduzi: 5 failures).
Os achados abaixo são de **poder probatório do teste** (classe "teste que não pode falhar"), não de correção.

---

## Bug 1 — `/frequencia_por_orgao`: teste não distingue INTERSEÇÃO de SUBSTITUIÇÃO (não pega um vazamento real)

- **Severidade:** 🟡 Médio
- **Arquivo:linha:** `api-ponto/test/controllers/admin/cascata_conteudo_test.rb:195-219`
  (contra-produção `api-ponto/app/controllers/admin/frequencia_por_orgao_controller.rb:58-60`)
- **RF/RN violado:** critério de aceite 33.3 ("CPF de terceiro ausente do agregado", §3 do plano);
  é o único teste da tarefa que protege a tela agregada por CPF.
- **Passos de reprodução:**
  1. No controller, trocar a **interseção** pela **substituição**
     (`cpfs &= frequentadores_visiveis_cpfs` → `cpfs = frequentadores_visiveis_cpfs`).
  2. `bin/rails test test/controllers/admin/cascata_conteudo_test.rb -n "/frequencia_por_orgao/"`
- **Observed:** **1 run / 7 assertions / 0 failures** — o teste **PASSA** com a regressão aplicada.
- **Esperado:** o teste deveria falhar (a substituição agrega presenças de **qualquer** frequentador
  visível na linha do órgão — um vazamento de dado de outro órgão — mesmo mantendo o terceiro fora).
- **Causa raiz do teste:** o `setup` só cria frequentadores **dentro** de "Vara Cível" (`CPF_VISIVEL` e
  `CPF_TERCEIRO`). Os dois conjuntos (`ó órgão` e `visíveis`) coincidem no único CPF visível, então
  `ó ∩ visíveis == visíveis`. Sem um **frequentador VISÍVEL que esteja FORA do órgão**, as duas
  semânticas produzem o mesmo `presencas` ("1") e o teste não as separa.
- **Teste sugerido:** adicionar um terceiro CPF **visível mas de outro órgão** (ex.: `orgaos_em_uso` →
  `["Vara Cível", "Outro Órgão"]`, com `cpfs_por_orgao("Vara Cível")` **sem** esse CPF) e assertar que a
  linha "Vara Cível" **não** é inflada pela presença dele; e/ou assertar que a linha "Outro Órgão"
  conserva a sua própria contagem. Assim uma substituição (que somaria todas as presenças visíveis em
  toda linha) passa a falhar.

## Bug 2 (⚪) — `/time_records` `:on`: o `TimeRecord` criado para o PRÓPRIO ator é dead weight; o teste não prova a preservação do "vê os próprios registros"

- **Severidade:** ⚪ Observação (cobertura lacunar — não é falso-verde)
- **Arquivo:linha:** `api-ponto/test/controllers/admin/cascata_conteudo_test.rb:152-155`
  (contra-produção `time_records_controller.rb:35-36` e `:43-43`)
- **Passos de reprodução:** ler o teste; o ator (`login_como_nao_global`) **não tem CPF**, e o stub
  `com_visiveis([CPF_VISIVEL])` é um CPF que **não** corresponde a nenhum `User` local criado no teste.
- **Observed:** sob `:on`, `restritir_frequencia` → `where(user_id: frequentadores_visiveis_user_ids)`
  com `frequentadores_visiveis_user_ids == []` (nenhum `User` com `CPF_VISIVEL` existe) → o **próprio**
  ator também deixa de aparecer; `primeiro_ano` cai no default (`Time.current.year`). O teste passa.
- **Esperado:** o comentário do controller (`:35-36`) afirma que o "usuário básico vê os próprios
  registros é preservado sob a flag" — mas nenhuma assertiva da tarefa cobre isso, e o
  `TimeRecord.create!(user: ator, ...)` (L153) nunca é verificado. Um ator **com** CPF visível a si
  (passo 1) não é exercido.
- **Teste sugerido:** cenário com ator **com CPF** e `com_visiveis([cpf_do_ator])` assertando que o
  registro do próprio ator **aparece** sob `:on` (controle positivo de "não over-restrict" nessa tela).

## Bug 3 (⚪) — Redundância não contabilizada: `/users` já era coberto por `users_cascata_controller_test.rb` (Task 31)

- **Severidade:** ⚪ Observação (rotação de expectativa / duplicação)
- **Arquivo:linha:** `cascata_conteudo_test.rb:84-106` vs.
  `api-ponto/test/controllers/admin/users_cascata_controller_test.rb:38-51,53-65,67-78,84-96,102-120`
- **Problema:** o teste de `/users` adicionado na 33.3 é **equivalente** ao que já existia em
  `users_cascata_controller_test.rb` (Task 31) — mesmas constantes de CPF (`30030030030`/`20020020020`),
  mesmo stub `stub_vinculos` que **já honrava** `incluir_cpfs`, mesmo `com_flag`/`com_visiveis`. O arquivo
  pré-existente é **mais completo**: cobre o contraste `:on`×`:off`, o **fail-closed** (`com_visiveis([])`),
  o **controle positivo de admin** (passo 2 vê tudo) e o gate admin-only de `@users_sem_cpf`.
- **Impacto:** a 33.3 **não adiciona cobertura nova** para `/users` (apenas realoca a mesma assertiva).
  O review **S1** subconta a duplicação ao listar só 2 arquivos; são **3**. E a linha "`@users_sem_cpf`
  admin-only" do §3 para `/users` é coberta pelo arquivo da Task 31, **não** pelo da 33.3.
- **Sugestão:** registrar a paridade no `iteration_33.md` (o critério "8 telas" já foi corrigido para 4/8
  por mutação; `/users` é o 4º "real", mas por herança da Task 31) e, se houver DRY (33.5), extrair os
  helpers triplicados.

## Bug 4 (⚪) — Nenhuma assertiva de conteúdo em `:shadow` no arquivo novo

- **Severidade:** ⚪ Observação
- **Arquivo:linha:** `cascata_conteudo_test.rb` (o helper `com_flag` só é chamado com `nil` e `"on"` —
  9×`"on"`, 6×`nil`; `"shadow"` = 0×)
- **Problema:** o contrato do modo `:shadow` ("mostra tudo, só loga") não é asserido em nenhuma das 8
  telas do arquivo novo. Se uma regressão fizesse o `:shadow` **restringir** indevidamente, nenhum teste
  da 33.3 pega. (`:shadow` é exercido para a tela de frequência em
  `frequencia_cascata_controller_test.rb:60,313,342,384`, mas **não** para as outras 7 telas.)
- **Risco:** baixo (o `:shadow` é observável por outro caminho), mas é o espelho da honestidade do
  critério: o arquivo é explícito sobre `:on`×`:off` e **omite** `:shadow`.

---

## Observações sobre o próprio review (não são bugs do entregável)

### 💡 O1 — `review_report_33_3.md` B1: premissa factualmente incorreta ("String vira regex / substring")

O review (B1, linha ~127) afirma: *"`assert_select … text: NOME` casa por **substring** (String vira
regex)…"*. **É incorreto.** No `rails-dom-testing` instalado
(`vendor/bundle/ruby/4.0.0/gems/rails-dom-testing-2.3.0/lib/rails/dom/testing/assertions/selector_assertions/html_selector.rb:66`):

```ruby
next if regex_matching ? (content =~ match_with) : (content == match_with)
```

Ou seja, **String ⇒ `==` (igualdade EXATA após `strip`/`collapse_whitespace`)**; só `Regexp` faz match.
Consequência prática (oposta à do review):
- As assertivas de **ausência** (`count: 0`) são **mais fracas** que o review sugere: só falham se o texto
  do `td` for **exatamente** igual ao nome. Se um `td` renderizasse o nome com qualquer texto extra
  (ex.: `<td>Nome Ativo</td>`), o `count: 0` **passaria** sob `:on`.
- Em contrapartida, a fragilidade **não** é silenciosa: o mesmo texto extra faria a assertiva de
  **presença** do controle `:off` (`count: 1`/presença) **falhar**, denunciando o arquivo.
  Logo, o "falso-verde silencioso" do B1 é **superestimado** — o controle positivo guarda o caso.
- **Recomendação (reforça B1):** nas assertivas de ausência usar `refute_match NOME, response.body`
  (substring, independente de layout) — mas mantendo o `assert_select` de **presença** como está, pois
  ele é o que denuncia a quebra.

### 💡 O2 — `/relatorio_terceirizados` segue sendo a única tela sem NENHUM poder probatório (confirmação independente do A1)

Reproduzi: `assert_select "table", count: 0` em `relatorio_terceirizados/index.html.erb` (não há `<table>`
no corpo **nem no layout** — verifiquei `app/views/layouts/*`) passa **independentemente da flag** e da
cascata. Não é bug novo (é o A1), mas registro que a correção A1 **não** deu a essa tela o mesmo assert
não-vacuoso que deu a `/parcial` (que assere o empty-state). Sem fonte real, o único assert honesto
possível seria um `skip`/TO-DO explícito (opção (b) já sugerida no review).

---

## Cenários testados SEM bugs (evidência)

| # | Cenário / mutação | Resultado |
|---|---|---|
| 1 | `cascata_conteudo_test.rb` + `users_controller_test.rb` (baseline) | **18 runs / 72 asserts / 0F / 0E** |
| 2 | Mesmos 2 arquivos, seeds 1 / 2 / 999 / 12345 | **18/72/0F/0E** em todos (estável, sem ordem-dependência) |
| 3 | Diretório `test/controllers/admin/` inteiro, seeds 4242 e 7 | **264 / 1398 / 0F / 0E** em ambos (sem vazamento de stub/ENV entre arquivos) |
| 4 | Meta-testes 33.2 + 33.1 (`cascata_cobertura_test.rb`, `cascata_enforcement_test.rb`) | **34 / 130 / 0F / 0E** (o arquivo novo **não** afeta o meta-teste de drift, que varre `app/**`) |
| 5 | **Mutação A** (concern `frequencia_cascata_ligada? → false`) | **5 failures** (4 no arquivo novo: frequentadores/users/frequencia/frequencia_por_orgao; 1 em users_controller) — reproduz o review |
| 6 | `users_controller_test.rb` — `stub_vinculos` com `nil` (todos) e `[]` (fail-closed) | honra o contrato real `where(pessoas: { cpf: incluir_cpfs })`; nenhum teste existente enfraqueceu |
| 7 | `com_flag(nil)` vs `:off` (default) | equivalentes (`modo` → `else :off`); o controle é auto-guardado (se o default virasse `:shadow`, o controle `:off` quebra) |
| 8 | `assert `/parcial`: `tbody tr count: 1` + texto do empty-state | não-vácuo: o assert de **texto** ("Nenhum registro encontrado") quebra quando a fonte real popular a tabela — guarda robusta |
| 9 | Cobertura de rota × §3 do plano | os 8 endpoints do §3 = os 8 testados; os 7 controllers `:coberto` têm teste de conteúdo; `dashboard` = `:dispensado` (testado como gate) |
| 10 | `git diff` de `app/**`, `config/routes.rb`, `db/schema.rb` | **vazio** (nenhum resíduo de sonda) |
| 11 | `users_controller_test.rb` inteiro | **9 runs / 32 asserts / 0F / 0E**; a reescrita **não removeu** cobertura (a Task 31 já cobria o mesmo contrato em `users_cascata_controller_test.rb`) |

## Veredito Final

- **0 blockers / 0 alto.** O veredicto do review (✅ aprovado, 0 blockers) **NÃO é contradito**.
- **Correção prioritária (🟡 Bug 1):** dar a `/frequencia_por_orgao` um CPF **visível fora do órgão**,
  para separar interseção de substituição — hoje um vazamento de agregado entre órgãos passa despercebido.
- Demais achados são de **calibração do critério de aceite** (roteiro de mutação/`skip`/`:shadow`),
  coerentes com o espírito da lição da 33.2 ("teste que não prova o que nomeia").
- Suíte da tarefa estável e reprodutível; footprint de `app/**` intocado após as sondas.
