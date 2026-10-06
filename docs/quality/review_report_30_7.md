# Relatório de Revisão — Tarefa 30.7 (🟡S3: matriz de aceite no grão `frequencia_por_orgao`)

- **Revisor:** Code Reviewer (AI Workflow)
- **Data:** 2026-10-06
- **Worktree:** `wt-30.7` | **Branch:** `feature/demanda-30-7-s3-matriz-orgao` @ `987ff39`
- **Origem → Destino:** `feature/demanda-30-7-s3-matriz-orgao` → `integration/sprint-29` (a definir no push)
- **Arquivos alterados (working tree):**
  - `api-ponto/test/controllers/admin/frequencia_matriz_aceite_test.rb` (+156) — **staged**
  - `api-ponto/log/test.log`, `api-ponto/tmp/cache/bootsnap/load-path-cache` — ruído de execução, **excluir do commit**
- **Produção tocada:** **NENHUMA** — `git diff -- app/ config/ lib/` vazio (confirmado antes, durante e depois das mutações; reversões verificadas).
- **Tarefa revisada:** 30.7 — fechar 🟡S3 (ADR-0010 §Consequências; PRD §3; `iteration_29_closure.md`).

## Veredito: ✅ **APROVADO** — 0 Blockers 🔴

Hardening de teste correto, discriminante e fiel ao 🟡S3. A matriz passa a cobrir `frequencia_por_orgao` no grão por CPF exercitando a cascata **real** (sem stub), com prova de mutação verificada independentemente por este revisor (5 mutações, todas mortas pelo lado certo).

---

## 1. Fidelidade ao 🟡S3

O débito (ADR-0010 linhas 162-163; PRD §3) é que `frequencia_por_orgao` agrega por órgão, mas o denominador da negação da cascata é o **CPF** — a interseção `cpfs do órgão ∩ frequentadores visíveis` (`frequencia_por_orgao_controller.rb:59`). As três sub-exigências do critério estão cobertas:

| Sub-exigência | Cenário | Resultado |
|---|---|---|
| CPF **visível mas fora do órgão** não vaza | `fora` (visível ao gestor, lotado em `outra_unidade`) | ✅ prova o lado `∩ cpfs do órgão` (M3 morre) |
| CPF **do órgão mas não-visível** não aparece | `negado` (mesmo órgão, sem vínculo de visibilidade) | ✅ prova o lado `∩ visíveis` (M1 morre) |
| **sem-CPF** fail-closed | `sem_cpf` (conta local sem CPF, não-admin) | ✅ 30.7b: off=1 → `:on`=0 |

O controle sem-flag (`off`) em cada cenário é correto e prova o setup (evita "verde por vacuidade"). O 30.7b usa ator **não-admin** (`criar_usuario` default `admin: false`), alinhado ao critério — a visão global (`frequencia_visao_global?`) curto-circuita a filtragem e não é o alvo aqui.

## 2. Testes discriminantes (adversarial — lição 33)

Reproduzi **5 mutações** independentes no controller/concern, uma a uma, com restauração (`cp` backup + `git diff -- app/` vazio após cada ciclo). Todas morreram, pelo lado certo:

| Mutação | Descrição | O que falha | Observado |
|---|---|---|---|
| **M1** | `cpfs &= frequentadores_visiveis_cpfs` → no-op | 30.7a **e** 30.7b | `"3"` vs `"2"`; `"1"` vs `"0"` — 2F |
| **M2** | remover `registrar_negacoes_por_cpf(cpfs)` | 30.7c | mensagem "deve logar a negação EFETIVA do CPF oculto" — 1F |
| **M3** | `cpfs = frequentadores_visiveis_cpfs` (ignora os do órgão) | 30.7a | `"3"` vs `"2"` — 1F (pega pelo visível-de-outro-órgão) |
| **M4** (extra) | logar **todos** os CPFs (incl. visível) como negação | 30.7c | controle negativo "o CPF visível não deve ser logado como negado" — 1F |
| **M5** (extra) | `cpfs \|= frequentadores_visiveis_cpfs` (união) | 30.7a **e** 30.7b | `"4"` vs `"2"`; `"1"` vs `"0"` — 2F |

Nenhuma sobreviveu. **M4 valida que o controle negativo do 30.7c é discriminante (não decorativo).** M5 confirma que a asserção de valor ("2") segura a direção de união, que o agente não listou.

**Limite conhecido (não bloqueante):** remover apenas o guard `!frequencia_visao_global?` (linha 58) não é pego — os atores dos cenários são não-admin. Esse é o passo 2 da cascata (visão global), coberto por outros testes (matriz 2a/2b, cascata); fora do grão do 🟡S3.

## 3. Cascata REAL (sem stub) — confirmado

`grep` no arquivo: **nenhum** stub de `Pessoas::Vinculo.cpfs_por_orgao` / `cpfs_frequentadores_visiveis`. O único `com_metodo_de_classe_stubado` é em `login_como` (`Pessoas::User.buscar_por_cpf`, ponto de entrada do login). Isso contrasta com `frequencia_cascata_controller_test.rb`, que usa `stub_orgao_por_cpf(...)`.

Prova empírica adicional: **M3 morreu com `Actual "3"`** — ou seja, a cascata real devolveu `frequentadores_visiveis_cpfs = {visivel, fora}` (2+1=3). Se a visibilidade estivesse stubada/vazia ou limitada a `{visivel}`, M3 não distinguiria e o valor seria `2` (teste verde por engano). O conjunto real **inclui o visível de outro órgão**, que é exatamente o valor de teste do lado `∩ cpfs do órgão`. O teste depende do schema real do espelho (`skip_sem_espelho!` no `setup`; pré-requisito `test:pessoas_schema:load`) — e **0 skips** na execução confirma que o espelho estava disponível (não rodou em falso-verde por skip).

## 4. Só teste?

✅ `git diff -- app/ config/ lib/` **vazio** — nenhum arquivo de produção alterado. As mutações de revisão foram integralmente revertidas (linhas 53/59 do controller e 168 do concern restauradas ao original; `git diff -- app/` reconfirmado vazio após).

## 5. Regressão

| Suíte | Medido pelo agente | Reproduzido por este revisor |
|---|---|---|
| Arquivo-alvo | 16/72/0F/0E/0 skip | ✅ **16/72/0F/0E/0 skip** |
| Direcionada (matriz + por_orgao + cascata) | 40/188/0/0 | ✅ **40/188/0/0** |
| Completa (1 worker, `PARALLEL_WORKERS=1`) | 1095/3865/1F+11E/0 skip | ✅ **1095/3865/1F+11E/0 skip** |

**F/E catalogados (todos em arquivos alheios ao diff, pré-existentes):**
- 1 Failure: `PresencaEndpointsTest` — timezone (`Expected "15/07/2026 11:30:45"`).
- 11 Errors: **11×** `NoMethodError: private method 'redirect_to'` — 9× `Users::SessionsControllerTest` + 2× `Users::PasswordsControllerTest` (incompatibilidade Devise × Rails 8.1, não relacionada).

Nenhum dos cenários 30.7a/b/c aparece em F/E; **0 skips** prova que os 3 novos testes executaram de fato. O "+12º erro" (`PessoasSchemaLoaderTest`, DB shardado) **não** aparece no run de 1 worker — consistente com a afirmação de que só surge sob paralelização. Não executei a suíte paralelizada (custo; e o run de 1 worker é o que importa para regressão). **Sem regressão.**

## 6. Qualidade

- **RuboCop** no arquivo: `1 file inspected, no offenses detected`.
- **Zeitwerk:** `All is good!`.
- Helper `presencas_do_orgao` isola a leitura à **linha** do órgão (não a um `<td>` solto) — evita falso-verde por outro número da página. Bom.
- `criar_batida` usa datas fixas (2026-07-10/11) e `Time.zone.local(...08:00)` — robusto a fuso (mesmo com deslocamento de TZ, as datas não colapsam em contagem distinta por `user_id`).

---

## Blockers 🔴

Nenhum.

## Sugestões 🟡 / 🟠 (não bloqueantes)

| ID | Tipo | Descrição |
|---|---|---|
| S1 | 🟠 Débito | Cobertura restrita à coluna **Presenças**. `trabalhado`/`ausências` compartilham o mesmo conjunto `cpfs`/`user_ids`, então o filtro está provado por transitividade — aceitável, mas explicitar essa decisão no comentário ajudaria. |
| S2 | 🟡 Melhoria | O modo `:shadow` de `frequencia_por_orgao` (`observar_cascata_por_cpf`) não é coberto aqui — pertence à 30.8 (insumo de rollout shadow), não ao 🟡S3. |
| S3 | 🟠 Débito | Persiste a divergência de conteúdo de `docs/progress/iteration_30.md` entre o worktree (committed: 30.7 "⬜ Pendente") e a cópia principal em `Frequencia/` (uncommitted, com o relato do Code Specialist). Consolidar na reconciliação pós-paralelização. |

## Elogios 🟢

| ID | Elogio |
|---|---|
| E1 | Controle `off` em cada cenário (prova o setup) + controle negativo explícito no 30.7c — matriz não degenerada. |
| E2 | Uso da cascata REAL em vez de stub, contrário ao padrão do `frequencia_cascata_controller_test.rb` — é o que dá valor ao teste e o que faz M3 discriminar. |
| E3 | O caso `fora` (visível de outro órgão) fecha a direção `∩ cpfs do órgão` que, sem ele, passaria batido. |

---

## Recomendação de commit (`COMMIT_MODE=manual` — não commitar)

Stage **seletivo**, apenas o artefato da tarefa:

```
git add api-ponto/test/controllers/admin/frequencia_matriz_aceite_test.rb
# NÃO incluir: api-ponto/log/test.log (160k+ linhas) e api-ponto/tmp/cache/bootsnap/load-path-cache
```

Mensagem semântica sugerida:

```
test: estende a matriz de aceite ao grão por CPF de frequencia_por_orgao (Sprint 30, task 30.7)

- 30.7a interseção `cpfs do órgão ∩ visíveis` (cascata real, sem stub)
- 30.7b sem-CPF fail-closed sob :on
- 30.7c trilha de negação :on por CPF (com controle negativo)
- fecha o débito 🟡S3 (ADR-0010 §Consequências)
```

## Ações corretivas

- [x] Nenhuma ação corretiva para desbloquear. Entrega aprovada sem blockers.
- [ ] (Ao commitar) excluir `log/test.log` e `tmp/cache/*` do stage.
