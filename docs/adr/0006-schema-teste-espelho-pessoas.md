# ADR-0006: Schema de teste para o espelho readonly do Pessoas (`frequencia_pessoas_espelho_test`)

> **[⌂ Home](../README.md)**

## Status

Aceito (CTO, 2026-09-25). É pré-requisito das tarefas 29.4 e 29.6 da Sprint 29 e é executado na tarefa 29.0 (`docs/progress/iteration_29.md`).

## Contexto

- Os models `Pessoas::*` (`api-ponto/app/models/pessoas/`) herdam de `PessoasRecord`, que é readonly e usa a conexão `pessoas` (`config/database.yml`). No ambiente de teste, essa conexão aponta para o banco `frequencia_pessoas_espelho_test` com `database_tasks: false`, de propósito: o Frequencia nunca gerencia o schema do Pessoas2. Não há migrations nem `schema_migrations` desse banco no Frequencia.
- Por isso, o banco de teste do espelho (na época, `pessoas_test`; ver Revisão 2026-09-25) existia mas **não tinha tabelas** (o Code Reviewer confirmou em `review_report_29_cs.md` R1, e o Bug Finder também, em `bug_report_29_bug-finder.md`). Todos os testes dos espelhos usam stubs de singleton (`define_singleton_method(:where, ...)`), e isso gerou o LOW-2 do review (monkey-patch que não é revertido).
- A 29.6 exige três coisas: um scope **SQL** (`frequentadores_visiveis`), um **teste de propriedade** que compare esse scope com `pode_ver?` item a item e um **teste de contagem de queries**. Nenhuma delas pode ser verificada com stubs. A 29.4 precisa de uma árvore real de `unidades` com `lotacoes`, `vinculos` e `pessoas` para testar a precedência e a negação até a raiz.
- Restrições: não alterar migrations nem o schema do Pessoas2; manter `database_tasks: false` (sem isso, `db:test:prepare` tenta criar `schema_migrations` no banco do Pessoas); não adicionar gem; o usuário de produção `app.frequencia` só tem `SELECT`.

## Alternativas Consideradas

### Alternativa A: manter só os stubs (status quo)

- **Prós:** custo zero e nenhuma dependência de infraestrutura.
- **Contras:** os critérios da 29.6 continuam impossíveis de verificar. Os stubs não percebem erro de SQL, de join, de tipo de coluna ou N+1. O LOW-2 continua aberto. A autorização ficaria validada só "no papel".

### Alternativa B: schema mínimo, versionado no Frequencia e carregado só no `frequencia_pessoas_espelho_test` (escolhida)

- **Descrição:** um arquivo de schema **exclusivo de teste** com o subconjunto das tabelas e colunas do Pessoas2 que os espelhos leem. Ele é copiado de `pessoas2/db/schema.rb`, não é migration e não fica em `db/`. Uma task rake carrega esse arquivo no `frequencia_pessoas_espelho_test` antes da suíte. Os dados de cada teste são criados por helpers, dentro da transação do próprio teste.
- **Prós:** usa PostgreSQL real, igual à produção (mesmo dialeto, tipos, `ancestry` como string e índices). A 29.6 fica verificável. Não usa gem e não acopla o Frequencia ao repositório do Pessoas2 na hora de rodar os testes. Também elimina o LOW-2.
- **Contras:** o schema copiado pode ficar desatualizado em relação ao Pessoas2 (mitigação abaixo). O usuário do `frequencia_pessoas_espelho_test` precisa de permissão de DDL **só localmente e no CI**.

### Alternativa C: apontar os testes para o banco de teste do próprio Pessoas2 (`db:schema:load` do pessoas2)

- **Prós:** schema completo e sempre fiel.
- **Contras:** a suíte do Frequencia passaria a depender do checkout, do Ruby e do bundle do Pessoas2 no CI. O schema tem mais de 5.900 linhas e FKs para dezenas de tabelas, o que torna o setup dos dados caro. O acoplamento entre os repositórios fica frágil.

### Alternativa D: SQLite em memória para a conexão `pessoas`

- **Contras:** dialeto diferente do de produção, e o teste de SQL da 29.6 perderia o valor. Descartada.

## Decisão

> **ADOTAMOS A ALTERNATIVA B.**

Regras de implementação (o Code Specialist executa na tarefa 29.0):

1. **Arquivo de schema:** `api-ponto/test/support/pessoas_schema.rb`, escrito na DSL `ActiveRecord::Schema.define`. Contém apenas as tabelas lidas pelos espelhos usados na cascata (`pessoas`, `unidades`, `vinculos`, `lotacoes` e as tabelas de apoio de que o scope de terceirizados depender, conforme D4, como `tipos_vinculo`/`categorias_trabalhador`) e só as colunas que os espelhos usam, com o **mesmo nome, tipo, default e índice** do `pessoas2/db/schema.rb`. As FKs de fora desse subconjunto ficam de fora. O cabeçalho do arquivo informa a fonte (`pessoas2/db/schema.rb`, versão e data da cópia).
2. **Carga:** a task `bin/rails test:pessoas_schema:load` aplica o schema na conexão `pessoas` com `force: :cascade`. Ela tem **guardas obrigatórias**: aborta se `Rails.env` não for `test` e aborta se o nome do banco não terminar em `_test`. Nunca pode rodar contra o banco real do Pessoas. `database_tasks: false` continua como está.
3. **Pipeline:** o step `test` do CI e o fluxo local de testes rodam essa task antes de `bin/rails test` (é preciso documentar isso na skill ou no README de testes). É idempotente.
4. **Dados:** não criar YAML em `test/fixtures/` para essas tabelas, porque `fixtures :all` quebraria em qualquer máquina sem o schema. Usar helpers explícitos em `api-ponto/test/support/pessoas_espelho_helper.rb` (ex.: `criar_arvore_unidades`, `criar_pessoa_lotada`) que inserem pela conexão `pessoas` (`insert_all`/SQL, sem passar pelo `readonly?`). Os testes transacionais revertem essas inserções.
5. **Stubs:** continuam permitidos só para lógica pura, sem banco (ex.: parse de `ancestry` malformado sem query). Os critérios de SQL, propriedade, contagem de queries e precedência da 29.4 e da 29.6 **devem** usar o schema real. Os stubs de singleton da 29.1 são trocados por dados reais ou por `Minitest::Mock#stub` com escopo de bloco (isso fecha o LOW-2).
6. **Proteção contra divergência:** um teste que compara as colunas e os tipos do `pessoas_schema.rb` com `pessoas2/db/schema.rb` quando o checkout irmão (`../../pessoas2`) existe. Quando não existe, o teste é marcado como `skip`, com uma mensagem explícita. Sempre que o Pessoas2 mudar uma coluna lida pelos espelhos, o schema de teste precisa ser atualizado no mesmo ciclo.
7. **Paralelismo:** como `database_tasks: false`, os workers de `parallelize` compartilham o `frequencia_pessoas_espelho_test` sem sufixo. Isso é aceitável porque cada teste insere dentro da própria transação, que não é commitada. A carga do schema acontece **uma única vez, antes** da suíte, nunca dentro de um worker. O Code Specialist precisa confirmar esse comportamento na versão instalada do Rails e registrar o resultado em `lessons.md` se ele for diferente do esperado.

## Consequências

### Positivas

- A 29.4 e a 29.6 passam a ser verificáveis com SQL real, e a contagem de queries e o teste de propriedade ganham valor.
- O LOW-2 da 29.1 é eliminado, e os testes de espelho que já existem (`servidores`, lotação) podem migrar aos poucos.

### Negativas / Trade-offs

- É um artefato a mais para manter em sincronia com o Pessoas2 (mitigado pela regra 6).
- O usuário do `frequencia_pessoas_espelho_test` precisa de `CREATE` localmente e no CI. A credencial de produção continua só com `SELECT`, e isso não muda.

### Neutras

- Não muda nenhuma migration, nenhum schema do Frequencia, nenhum schema do Pessoas2 nem nenhuma gem.

## Compliance

- É proibido rodar a task de carga fora de `RAILS_ENV=test` (a guarda precisa ter teste próprio).
- Nenhum teste da 29.4 ou da 29.6 pode ser aprovado pelo Code Reviewer só com stubs nos critérios que envolvem SQL.

## Notas

- ADRs relacionados: 0001 (integração com o Pessoas).
- Fontes: `review_report_29_cs.md` (R1, LOW-2), `bug_report_29_bug-finder.md` (sinalização ao CTO), `pessoas2/db/schema.rb:3289` (`pessoas`) e `:4800` (`unidades`).

## Revisão 2026-09-25 — banco de teste renomeado para `frequencia_pessoas_espelho_test`

- **Motivo:** o nome original, `pessoas_test`, é o banco de teste do **próprio Pessoas2**. Carregar o schema do espelho nele (com `force: :cascade`) apagaria ou misturaria as tabelas da suíte do Pessoas2 na mesma máquina. Com aprovação do usuário, a conexão `pessoas` de `test` em `api-ponto/config/database.yml` passou a apontar para um banco local exclusivo do Frequencia, `frequencia_pessoas_espelho_test` (Postgres local, dono `app.frequencia`). Referências a `pessoas_test` nos relatórios de `docs/quality/` e na `iteration_23.md` são históricas e não foram alteradas.
- **Criação do banco (outras máquinas e CI):** o `app.frequencia` não tem `CREATEDB`, então um superusuário cria o banco uma vez e a task carrega o schema:

  ```bash
  createdb -h localhost -U postgres -O app.frequencia frequencia_pessoas_espelho_test
  RAILS_ENV=test bin/rails test:pessoas_schema:load   # idempotente; rodar de novo a cada mudança do schema de teste
  bin/rails test
  ```

  No CI, os mesmos dois passos entram antes de `bin/rails test`, com o role `app.frequencia` criado no serviço Postgres e as credenciais `pessoas_db` de teste disponíveis (hoje o `.github/workflows/ci.yml` ainda **não** faz isso; pendência registrada na 29.0).
- **Ajustes de implementação (29.0):**
  - As tabelas foram copiadas **inteiras** (todas as colunas, defaults e índices), não só as colunas lidas pelos espelhos (regra 1). Assim a cópia é literal e o teste de divergência (regra 6) compara cada bloco `create_table` byte a byte. As FKs internas ao subconjunto foram mantidas, com `column:` explícito, porque o Pessoas2 tem inflexões próprias (`tipos_vinculo` → `tipo_vinculo_id`) que o Frequencia não tem.
  - Tabelas: `pessoas`, `unidades`, `vinculos`, `lotacoes`, `vinculos_estados`, `configuracoes_cadastro`, `tipos_vinculo`, `categorias_trabalhador`.
  - A regra 5 cita `Minitest::Mock#stub`; o projeto usa Minitest 6, que não traz mais `minitest/mock`. Os testes da 29.1 foram migrados para dados reais, sem stub.
  - Regra 7 confirmada no Rails 8.0.5: com `parallelize`, só o banco `primary` ganha sufixo por worker (`api_ponto_test-N`); todos os workers usam o mesmo `frequencia_pessoas_espelho_test`, cada teste roda em transação aberta nessa conexão e não enxerga as linhas dos outros workers. Nenhum banco `frequencia_pessoas_espelho_test-N` é criado.
