# DUV-006 — Divergência de esquema: campo `segsAcumulavelMensal` inexistente

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

O método `getUltimoAcumulavel` em `dao/RegistroMensalFrequenciaDao.java:66` executa:

```java
select("segsAcumulavelMensal"),
from(RegistroMensalFrequencia.class),
...
```

O bean `beans/RegistroMensalFrequencia.java` **não possui** o campo `segsAcumulavelMensal` (nem getter/setter). A documentação de BD (`docs/relatorio-bd.md`, tabela 1971-1989) **também não lista** a coluna.

O método **nunca é chamado** em lugar nenhum do `src/` — é um **método morto referenciando campo inexistente** (quebraria o HQL se invocado).

## Origem

- `docs/01-inventario/05-banco-horas-fechamento.md` (DIVERG-001)

## Por que importa

Indício de que o **esquema efetivo do BD pode divergir das classes Java** (campo possivelmente existia/foi removido no código, ou vice-versa). Antes de migrar é obrigatório **reconciliar o esquema real** (consultar o MySQL de produção ou scripts de schema).

## Hipóteses

1. Campo existia em versão antiga do bean e foi removido (código esquecido).
2. Campo existe no BD mas não está mais mapeado.
3. Método nunca foi usado desde a criação.

## Como Resolver

- [ ] Consultar o esquema real do BD (`presenca_registromensalfrequencia`) — verificar se `segsAcumulavelMensal` existe.
- [ ] Remover ou corrigir o método morto na migração.
- [ ] Validar se há outros campos divergentes (ver DUV-007, DUV-008).

## Resolução

**Resolvida por inspeção exaustiva do código (2026-08-05).**

### Confirmado (lado Java)

1. **O campo `segsAcumulavelMensal` NÃO existe no bean** `beans/RegistroMensalFrequencia.java`. O bean (380 linhas) declara saldos como `saldoLiquido`, `retido`, `acumulado`, `retificado` — não há campo/getter/setter `segsAcumulavelMensal`.
2. **A única ocorrência de `segsAcumulavelMensal` em todo `src/`** é no DAO: `dao/RegistroMensalFrequenciaDao.java:66` — `select("segsAcumulavelMensal")` dentro de `getUltimoAcumulavel(int frequentador)` (linhas 62-74).
3. **`getUltimoAcumulavel` nunca é chamado** em lugar nenhum do `src/` (a única ocorrência é a própria definição na linha 62).

→ **É código morto, referenciando um campo inexistente no mapeamento Java.** O HQL quebraria se o método fosse invocado.

### Decisão para a migração

- **Não portar** o método `getUltimoAcumulavel` nem buscar por `segsAcumulavelMensal`.
- A coluna `segsAcumulavelMensal` (se existir no banco) indica esquema legado divergente do código. **Recomendação:** ao reconciliar o esquema real do MySQL de produção, decidir entre remover a coluna (se órfã) ou mapeá-la. Se o saldo acumulável mensal for regra de negócio necessária, mapear explicitamente no Frequência (campos claros `saldoLiquido`/`acumulado` etc.).
- Confirmar com os demais campos divergentes (DUV-007, DUV-008) se há um padrão de colunas órfãs no módulo.

> ⚠️ **Limite da resolução:** a confirmação de que a coluna `segsAcumulavelMensal` existe/não existe **no banco de produção** exige consulta ao MySQL (não disponível no repositório — o módulo `presenca` não possui schema SQL das tabelas de banco de horas, apenas a view de frequentadores). Recomenda-se auditoria de `presenca_registromensalfrequencia`.
