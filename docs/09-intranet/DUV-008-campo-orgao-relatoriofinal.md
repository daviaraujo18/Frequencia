# DUV-008 — Divergência de esquema: campo `orgao` em RelatorioFrequenciaFinal

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

O DAO `dao/RelatorioFrequenciaFinalDao.java:30` (em `paginateList`) usa `field("orgao").equalsTo(idOrgao)`.

O bean `beans/RelatorioFrequenciaFinal.java` tem o campo `Orgao orgao` **comentado** (l.36-37), e o validador também tem `lotacaoAtual` comentado.

**Fragilidade adicional:** há mistura de tipos para a mesma coluna:
- `paginateList` recebe `mes` como **int** e `ano` como int;
- `getByMesAnoOrgao` (l.40-53) filtra `mes` como **String** (nome do mês);
- o bean guarda `mes`/`ano` como **String** (l.33-34).

## Origem

- `docs/01-inventario/05-banco-horas-fechamento.md` (DIVERG-003)

## Por que importa

- Divergência de esquema (campo `orgao` referenciado mas não mapeado).
- Ambiguidade int/String para a mesma coluna pode causar erros de consulta.

## Como Resolver

- [ ] Confirmar esquema real de `presenca_relatoriofrequenciafinal` (existe coluna `orgao`? qual tipo de `mes`/`ano`?).
- [ ] Decidir tipo definitivo (int ou String) para `mes`/`ano` no novo sistema.
- [ ] Corrigir DAO/bean para consistência.

## Resolução

**Resolvida por inspeção do código (2026-08-05).**

### Confirmado (lado Java)

1. **Campo `orgao` comentado:** `beans/RelatorioFrequenciaFinal.java` linhas 36-37:
   ```java
   //	@OneToOne
   //    private Orgao orgao;
   ```
   O campo está **comentado/descartado** no bean, mas `RelatorioFrequenciaFinalDao.paginateList:30` usa `field("orgao").equalsTo(idOrgao)`.
2. **Mistura de tipos `mes`/`ano`:**
   - Bean: `private String mes; private String ano;` (l.33-34); getters/setters `String` (l.58-72).
   - `paginateList(int pageNum, int pageSize, int mes, int ano, int idOrgao)` (DAO:14) — `mes`/`ano` **int**, filtra `field("mes")`/`field("ano")`.
   - `getByMesAnoOrgao(String mes, int ano)` (DAO:40) — `mes` **String**; filtro de `orgao` **comentado** (DAO:45).
3. **Usos em código vivo:**
   - `paginateList` é chamado em `actions/RelatorioFrequenciaFinalActions.java:41,107` passando `mes, ano, lotacaoAtual` (ints).
   - `getByMesAnoOrgao` é chamado em `validators/RelatorioFrequenciaFinalValidator.java:28` passando `construirMeses().get(mes)` (String do nome do mês) e `ano`.

### Decisão para a migração

- **`orgao`:** o campo não está no mapeamento ativo (comentado). O filtro `field("orgao")` em `paginateList` referencia coluna possivelmente não mapeada. **Recomendação:** remover o filtro de `orgao` do `paginateList` (ou mapear explicitamente `orgao_id` no Frequência), pois provavelmente está desativado (o `getByMesAnoOrgao` já o deixou comentado).
- **`mes`/`ano`:** padronizar no Frequência. Como o bean e o `getByMesAnoOrgao` usam `mes` como **String** (nome do mês) e `paginateList` como **int**, definir a coluna de forma única e consistente. Recomenda-se **int para `mes` e `ano`** (número) e converter nome↔número na camada de serviço, evitando ambiguidade.
- Consolidar DAO/bean/validador para um único tipo.

> ⚠️ **Limite da resolução:** o tipo definitivo da coluna `mes`/`ano` e a existência de `orgao` no **banco de produção** exigem consulta ao MySQL (não há schema SQL deste módulo no repositório).
