## Relatório Bug Finder — Iteração 29, Tarefa 29.1 (Dev A)

> **Branch:** feature/demanda-29-correcoes-review (working tree, sem commit)
> **Data:** 2026-09-25
> **Propósito:** Testes adversariais de `Pessoas::Unidade` (associations de gestor, `#gestor?`, `#cadeia_ascendente`) e `Pessoas::Pessoa.por_user`, que serão a base da cascata `AutorizacaoFrequencia` (29.4/29.6).
> **Não repete** achados do `review_report_29_cs.md` (MEDIUM-1/2, LOW-1..3, débitos N+1/log/`.distinct`).

### Resumo

| Métrica | Valor |
|---------|-------|
| Total de cenários testados | 18 |
| Bugs encontrados | 3 |
| 🔴 Crítico | 0 |
| 🟠 Alto | 0 |
| 🟡 Médio | 0 |
| 🟢 Baixo | 2 |
| ⚪ Info | 1 |

### Bugs por Severidade

## Bug 1 — A checagem de auto-referência em `cadeia_ascendente` é contornada por um ID com zero à esquerda

- Severidade: 🟢 Baixo
- RF/RN violado: Tarefa 29.1, critério "ancestry vazio/corrompido" (falha fechada); PRD §3 passo 5
- Arquivo: `api-ponto/app/models/pessoas/unidade.rb:31-33`
- Passos:
  1. Unidade `id=5` com `ancestry = "1/05"` (dado corrompido).
  2. O regex `\A\d+\z` aceita `"05"`, mas `ancestor_ids.include?(id.to_s)` compara `"05"` com `"5"` e não encontra o ciclo.
  3. O `to_i` normaliza para `5` e o `where` devolve a própria unidade.
- Atual: `[5, 5, 1]`: a própria unidade aparece duplicada e a cadeia continua até a raiz. Isso foi reproduzido com uma spec temporária.
- Esperado: fail-closed `[self]`, como no caso `"1/3"`. O ideal é comparar depois do `to_i`, ou rejeitar zeros à esquerda com `\A[1-9]\d*\z`.
- Impacto: baixo. A gem `ancestry` nunca grava zeros à esquerda, então isso só acontece com edição manual do banco. Não amplia acesso além da raiz real, mas quebra o contrato de fail-closed da própria tarefa.
- Teste sugerido: `build_unidade(id: 3, ancestry: "1/03").cadeia_ascendente == [unidade]`, sem consultar o banco.

## Bug 2 — IDs repetidos no caminho não são deduplicados nem tratados como corrupção

- Severidade: 🟢 Baixo
- RF/RN violado: Tarefa 29.1, critério "ancestry corrompido"
- Arquivo: `api-ponto/app/models/pessoas/unidade.rb:35-37`
- Passos: unidade `id=5`, `ancestry = "1/1"`.
- Atual: `[5, 1, 1]`, com o ancestral duplicado. Um caminho gerado pela gem nunca repete IDs, então isso indica corrupção e não é tratado como tal.
- Esperado: fail-closed `[self]` quando `ancestor_ids.uniq.size != ancestor_ids.size`, ou no mínimo devolver uma lista sem duplicatas.
- Impacto: baixo. Não amplia acesso. Na 29.4/29.6 pode gerar checagens repetidas de `gestor?` (mais queries) e contagens infladas.
- Teste sugerido: `ancestry: "1/1"` resulta em `[unidade]`, sem consultar o banco.

## Bug 3 — Um ancestral inexistente é pulado em silêncio e a cadeia continua até a raiz (decisão não documentada no PRD)

- Severidade: ⚪ Info
- RF/RN: PRD §3 passo 5 (hierarquia)
- Arquivo: `api-ponto/app/models/pessoas/unidade.rb:37`; o teste `pessoas_unidade_test.rb` "keeps existing ancestors when one path id is missing" fixa esse comportamento
- Cenário: `ancestry = "1/2"`, e a unidade 2 não existe mais.
- Atual: devolve `[folha, 1]`. O gestor da raiz continua com acesso, mas sem log. Isso não é consistente com a política fail-closed aplicada ao caminho malformado.
- Esperado: a decisão precisa ser explícita na 29.4. Opções: (a) manter como está e registrar no log, ou (b) tratar como corrupção. Também é preciso decidir se unidades inativas ou extintas (`active=false`, `data_extincao_serventia`) continuam liberando acesso pelos seus gestores. Hoje o espelho não filtra essas unidades.
- Teste sugerido: na 29.4, um teste de política com o ancestral ausente e outro com o ancestral inativo.

### Cenários Testados (sem bugs)

1. O formato de `ancestry` no Pessoas2 é `ancestry 4.1.0` com `has_ancestry` padrão, ou seja, `materialized_path` `"1/2/3"`. É compatível com o parser (verificado em `pessoas2/Gemfile.lock` e `pessoas2/app/models/unidade.rb:3`).
2. O CPF no Pessoas2 é gravado sem máscara (`before_save :unmask_cpf`), e `users.cpf` é validado como `\A\d{11}\z`. A normalização de `por_user` é compatível.
3. As colunas `gestor_id`, `gestor_substituto_id` e `gestor_excepcional_id` existem em `unidades` (pessoas2 `db/schema.rb`).
4. `ancestry` nil ou vazio resulta em `[self]`, sem query.
5. Caminhos malformados (`"invalido"`, `"1//2"`, `"/1"`, `"1/"`) resultam em `[self]`. `\z` também rejeita `"1/2\n"`.
6. Auto-referência com ID canônico (`"1/3"` para id 3) resulta em `[self]`.
7. Ordem folha→raiz com uma única query `where(id: [...])`.
8. `gestor?(nil)` e `gestor?("")` resultam em false. Pessoa de outra classe (ex.: `User` com o mesmo id) resulta em false, porque o `==` do AR compara classe e id.
9. `gestor?` com um registro `Pessoas::Pessoa` não persistido não dá falso positivo: o `==` do AR em new records é por identidade.
10. `por_user(nil)` e CPF nil, `""` ou `"---"` resultam em nil, sem query.
11. `por_user` com CPF mascarado é normalizado para 11 dígitos.
12. `por_user(objeto sem #cpf)` levanta `NoMethodError`. Só `User` é esperado aqui, então não conta como bug.
13. O espelho é readonly (`PessoasRecord#readonly?`), e o diff não traz nenhuma escrita.
14. Regressão: a suíte completa não mostra falhas novas (ver comandos).
15. Um ID gigante no caminho é aceito pelo regex. `where` com bigint fora do range devolve vazio no Rails 7+, então não levanta exceção (não reproduzido em banco real).

### Comandos executados

| Comando | Resultado |
|---------|-----------|
| `bin/rails test test/models/pessoas_pessoa_test.rb test/models/pessoas_unidade_test.rb` | 13 runs / 53 assertions / 0 failures |
| Spec temporária `test/tmp_bugfinder/bf_29_1_test.rb` (removida depois) | Reproduziu os Bugs 1 (`[5, 5, 1]`) e 2 (`[5, 1, 1]`). O banco `pessoas` de teste não tem as tabelas `unidades`/`pessoas`, então não houve teste de integração com AR real |
| `bin/rails test` (suíte completa) | 793 runs / 2886 assertions / 1 failure: `presenca_endpoints_test.rb:187` (timezone), a baseline pré-existente já registrada em `review_report_29_cs.md` e na Sprint 23. Não tem relação com a 29.1 |
| `bin/rails test test/integration/presenca_endpoints_test.rb` (2x) | 1 failure determinística, a mesma baseline |

### Veredito Final

Nenhum bug crítico, alto ou médio. A 29.1 cumpre os critérios de aceite. Os Bugs 1 e 2 são reforços de fail-closed para dados corrompidos e podem ser corrigidos juntos numa mudança pequena em `cadeia_ascendente`. O Bug 3 é uma decisão de política para a 29.4.

Prioridade: Bugs 1 e 2 são opcionais antes do commit (BUG_LEVEL). O Bug 3 entra como entrada de design da 29.4.

### Sinalização ao CTO

- O banco `pessoas` de teste não tem schema, então todos os testes dos espelhos `Pessoas::*` dependem de stubs de singleton. Para a 29.4/29.6 (scope SQL, teste de propriedade e contagem de queries), o CTO deveria definir uma estratégia de schema de teste para o espelho, por exemplo um `structure.sql` mínimo carregado no banco `pessoas_test`. Sem isso, os critérios da 29.6 não são verificáveis.
