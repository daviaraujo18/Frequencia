# Coleta do Schema Físico — Módulo `presenca` (MySQL de Produção)

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Oferecer o **roteiro de consultas de LEITURA (read-only)** para extrair o **schema físico real** das tabelas do módulo `presenca` no MySQL de produção (banco **`intranet`**). É o último passo para **concluir o inventário**, fechando a lacuna entre o mapeamento Java (JPA/Hibernate) e o banco efetivo.

> **Por que:** o inventário documenta as **entidades e colunas mapeadas no Java** (`01-inventario/06-tabelas-banco.md`), mas o **schema físico real** (tipos MySQL, `NULL/NOT NULL`, índices, FKs) exige consulta ao banco de produção — pendência registrada nas DUV-006/007/008.
>
> **Como usar:** rodar os comandos abaixo em modo **leitura** (`SELECT`/`SHOW`, sem `DROP`/`ALTER`/`INSERT`). O resultado (saída de `SHOW CREATE TABLE`) deve ser colado no documento `01-inventario/09-schema-confirmado.md` (ou anexado), reconciliado com `06-tabelas-banco.md`.

---

## Conexão (somente leitura)

```sql
-- Banco: intranet (confirmado em intranet/src/conf/hibernate.properties:11 e web/META-INF/context.xml:10)
-- Usar conta com privilégio READ (SELECT/SHOW) apenas, nunca com DDL/DML de escrita.
SHOW DATABASES;
USE intranet;
```

---

## 1. Script de coleta — todas as tabelas do módulo `presenca` (19)

Copiar e executar o bloco a seguir (rodará `SHOW CREATE TABLE` para cada tabela):

```sql
USE intranet;
SHOW CREATE TABLE presenca_calculodiario;
SHOW CREATE TABLE presenca_debitoremanscentenegociavel;
SHOW CREATE TABLE presenca_diaexcepcional;
SHOW CREATE TABLE presenca_direito;
SHOW CREATE TABLE presenca_estacaoponto;
SHOW CREATE TABLE presenca_estacaoponto_ping;
SHOW CREATE TABLE presenca_frequentador;
SHOW CREATE TABLE presenca_gestorindividual;
SHOW CREATE TABLE presenca_historicotarefa;
SHOW CREATE TABLE presenca_regime;
SHOW CREATE TABLE presenca_regimefrequentador;
SHOW CREATE TABLE presenca_registroestacaoponto;
SHOW CREATE TABLE presenca_registrofrequencia;
SHOW CREATE TABLE presenca_registromensalfrequencia;
SHOW CREATE TABLE presenca_relatoriofrequenciafinal;
SHOW CREATE TABLE presenca_relatoriofrequentador;
SHOW CREATE TABLE presenca_retificadorbancohoras;
SHOW CREATE TABLE presenca_valorretroativo;
SHOW CREATE TABLE presenca_versaoestacaoponto;
```

## 2. Tabelas de junção (N:M / ElementCollection) — 3

```sql
USE intranet;
SHOW CREATE TABLE presenca_estacao_predio;          -- @JoinTable EstacaoPonto.predios (beans/EstacaoPonto.java:64)
SHOW CREATE TABLE presenca_frequentador_predio;     -- @JoinTable Frequentador.prediosPermitidos (beans/Frequentador.java:73)
SHOW CREATE TABLE presenca_regime_categoriavinculo; -- @CollectionOfElements Regime (beans/Regime.java:67)
```

## 3. View (presenca) — 1

```sql
USE intranet;
SHOW CREATE TABLE presenca_frequentadorestacao;     -- view FrequentadorEstacao (@View) — alimenta as estações
```

> **Nota:** a view pode estar no schema `intranet` e depender de tabelas de outros módulos (ex.: `tjpi`, `global`). Capturar também o `SHOW CREATE VIEW` se necessário.

## 4. Tabelas referenciadas por FK (outros módulos, mesmo schema `intranet`)

Para reconciliar as FKs dos `presenca_*` (ex.: `frequentador.lotacao_epoca → orgao`, `frequentador.user_id`, `registrofrequencia.lotacaoEpoca`, intervenções), capturar também:

```sql
USE intranet;
SHOW CREATE TABLE orgao;
SHOW CREATE TABLE vinculado;
SHOW CREATE TABLE vinculo;
SHOW CREATE TABLE predio;
SHOW CREATE TABLE user;
SHOW CREATE TABLE feriado;
SHOW CREATE TABLE manifestacao;         -- módulo aproc (referenciado p/ intervenção; ver status do módulo)
SHOW CREATE TABLE previnculadointervencao;  -- confirmar nome real (módulo tjpi)
```

> **Nota:** os nomes exatos dessas tabelas de outros módulos devem ser confirmados; ajuste conforme o `SHOW TABLES LIKE` local (seção 5).

## 5. Inventário geral de tabelas do schema (verificação)

```sql
-- Listar todas as tabelas e views do schema (para conferir se há tabelas presenca_* não mapeadas)
SHOW TABLES LIKE 'presenca\_%';
-- Contagem de linhas (apenas para dimensionamento da migração — opcional, em leitura)
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = 'intranet' AND table_name LIKE 'presenca\_%'
ORDER BY table_name;
```

---

## 6. O que comparar com o inventário (checklist de reconciliação)

Após coletar o `SHOW CREATE TABLE`, preencher/confirmar em `01-inventario/06-tabelas-banco.md`:

| Verificação | Detalhe da lacuna | Pendência que resolve |
|-------------|-------------------|------------------------|
| Tipos MySQL reais | ex.: `digitaisHash` (@Lob) → tipo real (`mediumblob`/`text`?); flags boolean → `tinyint(1)`? | DUV-006/007/008 + `06-tabelas-banco.md` |
| `NULL/NOT NULL` | Confirmar colunas obrigatórias vs opcionais | `06-tabelas-banco.md` |
| Índices/unicidade | Confirmar `uniqueConstraints` (ex.: `presenca_registrofrequencia` unique de 6 col; `estacaoponto.codigoAtivacao` unique) | `06-tabelas-banco.md` |
| FKs físicas | Confirmar nomes/colunas das `foreign key` (alguns `@ManyToOne` podem não ter FK física) | `06-tabelas-banco.md` |
| `mes`/`ano` String vs int | `RelatorioFrequenciaFinal.mes/ano` (String no bean) vs tipo real no banco | DUV-008 |
| `calculoDiario_id` | Verificar **existência real** da coluna na `presenca_retificadorbancohoras` (bean não mapeia; DAO referencia) | DUV-007 |
| `segsAcumulavelMensal` | Verificar se a coluna existe na `presenca_registromensalfrequencia` (bean não mapeia; DAO referencia) | DUV-006 |
| `orgao` | Verificar se existe coluna na `presenca_relatoriofrequenciafinal` (campo comentado no bean) | DUV-008 |

---

## 7. Riscos / boas práticas

- **Somente leitura:** não executar `CREATE`, `ALTER`, `DROP`, `INSERT`, `UPDATE`, `DELETE`.
- **Volume:** `SHOW CREATE TABLE` não acessa dados por linha — seguro. A query `information_schema.table_rows` é aproximada e barata.
- **Horário:** preferir janela de baixa carga se for rodar muitas consultas.
- **Padrão de nomes:** caso algum nome de tabela não exista (ex.: `previnculadointervencao`), localizar pelo `SHOW TABLES LIKE '%vinculado%intervencao%'`.

---
**Última atualização:** 2026-08-05
**Próximo:** rodar as consultas na produção → preencher `09-schema-confirmado.md` → reconciliar `06-tabelas-banco.md` → fechar DUV-006/007/008 → marcar inventário CONCLUÍDO.
