# DUV-007 — Divergência de esquema: `calculoDiario_id` inexistente em RetificadorDeBancoHoras

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

O DAO `dao/RetificadorDeBancoHorasDao.java:60` — método `findByCalculoDiario(int calculoDiarioId)` — usa `field("calculoDiario_id")`.

O bean `beans/RetificadorDeBancoHoras.java` **não possui** o campo `calculoDiario`/`calculoDiario_id` (os comentários nas linhas 13-24 chegam a discutir o vínculo opcional a um `CalculoDiario`, mas **nunca foi materializado** no bean).

O método **nunca é chamado** no `src/` — método morto referenciando campo inexistente.

## Origem

- `docs/01-inventario/05-banco-horas-fechamento.md` (DIVERG-002)

## Por que importa

Reconciliação do esquema BD×classes antes da migração. Indica que o esquema real pode divergir do mapeamento atual.

## Como Resolver

- [ ] Consultar esquema real de `presenca_retificadorbancohoras` (existe `calculoDiario_id`?).
- [ ] Remover/corrigir o método morto na migração.

## Resolução

**Resolvida por inspeção exaustiva do código (2026-08-05).**

### Confirmado (lado Java)

1. **O campo `calculoDiario`/`calculoDiario_id` NÃO existe em `beans/RetificadorDeBancoHoras.java`.** Os campos declarados são: `id`, `frequentador`, `mes`, `ano`, `excluido`, `tipo`, `segundosARetificar`, `observacao`, `informacao`, `momentoRegistro`, `responsavel` (linhas 29-62).
2. O **comentário nas linhas 12-24** confirma que o vínculo a um `CalculoDiario` foi **cogitado mas nunca materializado**: discute o vínculo opcional para `CREDITO_TRABALHO_EXTRAORDINARIO`/`DEBITO_INDEVIDO`, mas não foi implementado no mapeamento.
3. O DAO `dao/RetificadorDeBancoHorasDao.java:59-63` — `findByCalculoDiario(int calculoDiarioId)` usa `field("calculoDiario_id")` — é a **única ocorrência** da string no repositório.
4. **`findByCalculoDiario` nunca é chamado** em lugar nenhum do `src/` (a única ocorrência é a definição).

→ **É código morto, referenciando campo inexistente.** Quebraria o HQL se invocado.

### Decisão para a migração

- **Não portar** `findByCalculoDiario`. No Frequência, modelar `RetificadorDeBancoHoras` **sem** vínculo a `CalculoDiario` (já que o mapeamento atual não o possui e nada o usa).
- Se, no futuro, for necessário relacionar retificador de horas extraordinárias a um dia de cálculo, mapear explicitamente (novo campo `calculoDiario`) — decisão de modelagem, não de compatibilidade.

> ⚠️ **Limite da resolução:** confirmar se a coluna `calculoDiario_id` existe **no banco de produção** (`presenca_retificadorbancohoras`) exige consulta ao MySQL (não há schema SQL desse módulo no repositório). Recomenda-se auditoria.
