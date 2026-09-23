# DUV-012 — Cortes temporais do cálculo (01/12/2018, 01/05/2017, GCET, 26/10/2022)

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

O motor de cálculo diário **muda de comportamento por data** através de cortes temporais hardcoded. Para reproduzir fielmente o histórico, todos estes cortes precisam ser confirmados/validados com o negócio:

| Regra | Corte | V1 | V2 |
|-------|-------|----|----|
| Algoritmo Old vs New (modalidade HORAS) | 01/12/2018 | `CalculoDiarioService.java:175` | `CalculoDiarioServiceV2.java:273` |
| Intervalo 15min p/ acumular horas | 01/05/2017 | `CalculoDiarioStrategy.java:456-457` | `CalculoStrategyV2.java:382-383` |
| Labels de faltas compensadas | >31/03/2017 | `CalculoDiarioService.java:130-131` | `CalculoDiarioServiceV2.java:84-85` |
| Máximo banco GCET (45min) | v1 após 2018-12-01; v2 2018-12-01..2022-10-26 | `CalculoDiarioStrategy.java:491-492` | `CalculoStrategyV2.java:419-421` |
| Limite faltas compensáveis/ano (10→12) | >26/10/2022 | fixo 10 | `getMaxFaltasCompensadasPermitidasPorAno()` |

Há ainda inconsistência de **períodos** entre v1 e v2 no limite GCET (v1 sem fim vs v2 `before(2022,10,26)`) e datas especiais hardcoded **21-23/11/2022** (`CalculoStrategyV2.java:423-429`).

## Origem

- `docs/01-inventario/03-calculo-diario.md` (seção 3, itens 3.3/3.4)
- `docs/01-inventario/02-regime-jornada.md` (Q8)

## Por que importa

- A migração precisa **reproduzir o comportamento histórico** para não recalcular incorretamente registros passados.
- Regras temporais não documentadas fora do código → risco alto.

## Como Resolver

- [ ] Confirmar cada corte com o negócio (existe razão para cada data?).
- [ ] Definir quais cortes serão preservados no novo sistema e quais serão removidos (novos cálculos provavelmente usam apenas a regra vigente — definir a partir de quando).
- [ ] Extrair datas/constantes para configuração.
- [ ] Criar testes de contraste com dados históricos por janela de data.

## Resolução

**Resolvida por inspeção direta do código — todos os cortes LOCALIZADOS e CONFIRMADOS (2026-08-05).**

### Mapa completo de cortes temporais confirmado

| Regra | Corte | V1 (arquivo:linha) | V2 (arquivo:linha) |
|-------|-------|---------------------|---------------------|
| Labels de faltas compensadas | > 31/03/2017 | `CalculoDiarioService.java:130` | `CalculoDiarioServiceV2.java:84` |
| Retirar 15min de hora extra | ≥ 01/05/2017 | `CalculoDiarioStrategy.java:456` | `CalculoStrategyV2.java:382` |
| Algoritmo Old vs New (HORAS) | ≥ 01/12/2018 | `CalculoDiarioService.java:175` | `CalculoDiarioServiceV2.java:273` |
| Máximo banco GCET (45min) | v1: após 01/12/2018 (sem fim) · v2: 01/12/2018 a 26/10/2022 | `CalculoDiarioStrategy.java:491` | `CalculoStrategyV2.java:419` |
| Faltas compensáveis/ano (10→12) | > 26/10/2022 | fixo 10 (`CalculoDiarioService.java:284`) | `getMaxFaltasCompensadasPermitidasPorAno()` (`CalculoDiarioServiceV2.java:148`) |
| Banco de horas liberado (exceção) | 21/22/23/11/2022 | ❌ não existe no v1 | `CalculoStrategyV2.java:424-426` (`return 99999`) |

### Inconsistência de períodos v1 × v2 confirmada

- **GCET:** v1 aplica 45min para **toda data após 01/12/2018** (`if (meta>=28800 && data.after(2018,12,1))` — sem limite superior). v2 restringe ao intervalo `after(2018,12,1) && before(2022,10,26)` (`CalculoStrategyV2.java:419`).
- **Dias 21-23/11/2022:** só o v2 libera banco de horas (`return 99999`); o v1 não tem essa exceção.
- Todas as datas usam `CalendarUtil.buildCalendar(ano,mes,dia)` (não `Calendar.set(...)` direto).

### Conclusão / decisão para a migração

- Os cortes são **regras de negócio temporais hardcoded** que precisam ser **reproduzidas para histórico** (para não recalcular incorretamente registros passados).
- **V2 como referência** (motor canônico — ver DUV-005): os cortes de **v2** (janela GCET com fim, exceção 21-23/11/2022, faltas dinâmicas) refletem a regra vigente.
- **Recomendação:**
  1. **Extrair todas as datas/constantes para configuração** no Frequência (não hardcoded), mantendo o histórico por data.
  2. Para **cálculos retroativos**, aplicar o corte correspondente à data do registro `CalculoDiario.data`.
  3. Para **novos cálculos (recalc), aplicar apenas a regra vigente** (ex.: limite GCET após 26/10/2022).
  4. **Criar testes de contraste** v1×v2 e por janela de data (antes/depois de cada corte) para garantir paridade e reprodução histórica.
  5. Confirmar com o negócio a razão de cada data (31/03/2017, 01/05/2017, 01/12/2018, 26/10/2022, 21-23/11/2022) para documentar adequadamente (ex.: mudanças de jornada/legislação).
