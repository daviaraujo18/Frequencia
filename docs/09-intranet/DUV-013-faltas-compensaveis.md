# DUV-013 — Faltas compensáveis/ano (10→12) e possível bug `Calendar.MONDAY`

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

Duas questões relacionadas ao cômputo de faltas compensadas/descontadas:

1. **Limite de faltas compensáveis por ano mudou por data:** `beans/CalculoDiario.java:327-333` — `getMaxFaltasCompensadasPermitidasPorAno()` retorna **12** se `data > 26/10/2022`, senão **10**. (v1 usa fixo 10 — `CalculoDiarioService.java:284`; v2 usa o método dinâmico — `CalculoDiarioServiceV2.java:148`.)

2. **Aparente bug semântico:** em `getRestanteACompensar()` (`CalculoDiario.java:324`), `this.data.get(Calendar.MONDAY)` é usado — isso retorna o **dia da semana** (constante de segunda-feira) em vez de `Calendar.DAY_OF_MONTH` — passado como "dia do mês" na consulta do total de faltas compensadas no ano. Consulta potencialmente incorreta.

## Origem

- `docs/01-inventario/03-calculo-diario.md` (seção 3, D9/D8)

## Por que importa

- Regra de negócio (12 vs 10 faltas) precisa ser confirmada.
- O bug `Calendar.MONDAY` pode afetar o cômputo do quanto já foi compensado no ano.

## Como Resolver

- [ ] Confirmar a regra vigente de faltas compensáveis/ano (12 ou 10; corte 26/10/2022).
- [ ] Confirmar/corrigir o uso de `Calendar.MONDAY` (deveria ser `DAY_OF_MONTH`).
- [ ] Reproduzir o comportamento correto no novo sistema.

## Resolução

**Resolvida por inspeção direta do código (2026-08-05).**

### Item 1 — Limite de faltas compensáveis/ano (10 → 12) — CONFIRMADO

`beans/CalculoDiario.java:327-333`:
```java
public int getMaxFaltasCompensadasPermitidasPorAno() {
    if (data.after(CalendarUtil.buildCalendar(2022,10,26))) {
        return 12;
    } else {
        return 10;
    }
}
```
- **CONFIRMADO:** retorna **12** se `data > 26/10/2022`, senão **10**.
- **v1** usa constante fixa **10**: `services/calculo/CalculoDiarioService.java:284` (`int MAX_FALTAS_COMPENSADAS_PERMITIDAS_POR_ANO = 10;`) — não usa o método dinâmico.
- **v2** usa o método dinâmico do bean: `services/calculo/v2/CalculoDiarioServiceV2.java:148` (`faltasCompensadas < calculoDiario.getMaxFaltasCompensadasPermitidasPorAno()`).
- (Cruzamento com DUV-012/DUV-005: v2 é o motor canônico.)

### Item 2 — Bug `Calendar.MONDAY` — CONFIRMADO (com nuance)

`beans/CalculoDiario.java:323-325`:
```java
public int getRestanteACompensar() {
    return CalculoDiarioDao.getTotalFaltasCompensadasNoAnoAteODia(frequentador,
            this.data.get(Calendar.DAY_OF_MONTH),   // 1º arg: dia (correto)
            (this.data.get(Calendar.MONDAY) + 1),   // 2º arg: BUG
            this.data.get(Calendar.YEAR));
}
```
- **CONFIRMADO:** o 2º argumento usa `this.data.get(Calendar.MONDAY)` — semanticamente errado (deveria ser `DAY_OF_MONTH`).
- **Nuance (por que "funciona" na prática):** `Calendar.MONDAY` não é um campo de `Calendar`; é a **constante `Calendar.MONDAY = 2`** do domínio `DAY_OF_WEEK`. Como `Calendar.get(int field)` com `field=2` acessa o campo de índice 2, que é justamente `Calendar.DAY_OF_MONTH`, na prática retorna o dia do mês — **funcionando por coincidência de índice**. É frágil/semanticamente incorreto, mas não quebra o comportamento esperado hoje.

### Decisão para a migração

1. **Regra:** manter o limite dinâmico (12 se data > 26/10/2022, senão 10), extraindo o corte para configuração (ver DUV-012).
2. **Bug `Calendar.MONDAY`:** **corrigir** para `Calendar.DAY_OF_MONTH` no Frequência (não reproduzir o código frágil), pois embora coincida hoje, é correto e eliminaria risco futuro.
3. Adicionar teste de regressão para os cómputos de `getRestanteACompensar` e do limite anual (antes/depois de 26/10/2022).
