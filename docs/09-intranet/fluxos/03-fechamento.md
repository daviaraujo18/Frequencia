# Fluxo — Fechamento de Frequência (Fase 2: Engenharia Reversa)

> **[⌂ Home](../../README.md)**

## Propósito

Documentar o **fluxo de fechamento do módulo `presenca`**: a consolidação dos `CalculoDiario` (fluxo B) em um **`RegistroMensalFrequencia`** (fechamento mensal), o ajuste de banco de horas via **Retificador**, e o **Relatório Final definitivo** (com valor retroativo) por frequentador.

> **Fase 2 (Engenharia Reversa).** Regras com **EVIDÊNCIA** (`arquivo:linha`). Fonte: `intranet/src/modules/presenca/`. Complementa o inventário estrutural em `01-inventario/05-banco-horas-fechamento.md`; aqui o foco é **fluxo + regras + disparo**.

**Escopo:** entrada = `CalculoDiario` do mês (fluxo B); saída = `RelatorioFrequenciaFinal` + itens `RelatorioFrequentador`. Inclui retificador e valor retroativo como insumos de ajuste.

---

## Mapa de Dependências

```
[Job] GerarRegistroMensalFrequencia (cron 2º dia, 00:10)
   │ cria RegistroMensalFrequencia do mês (se ausente) via CalculoDiarioServiceV2.atualizarMesNoAno
   ▼
RegistroMensalFrequenciaServices.calcular(f, mes)
   ├─ listRetificadoresDoMes          (presenca_retificadorbancohoras)
   ├─ zerarRegistro                   (zera saldos/metas do mês)
   ├─ mensal.aplicarRetificadoresDeBancoHoras(retificadores)   → retificado
   ├─ aplicarCalculosDiarios(mensal, calculos)                  → consolida os CalculoDiario
   └─ calcularSaldoAcumulo(mensal, regime.conf, saldoMesAnterior)
        → saldoLiquido, retido, acumulado (com limite crédito/débito)
   ▼
RegistroMensalFrequencia (saldoLiquido/retido/acumulado/retificado)  → insumo do relatório
   │
[Manual/UI] RetificadorActions.adicionar/excluir/estornar ──▶ RetificadorServices.retifica
   │         (se ehPraRecalcular → CalculoDiarioServiceV2.atualizarMesNoAno)
   ▼
[Manual/UI] RelatorioFrequenciaFinalActions.create/update
   │  (validator: só no mês seguinte; sem duplicata)
   ▼
RelatorioFrequenciaFinalServices.montarRelatorio/atualizarRelatorio
   ├─ para cada frequentador: criarRelatorioFrequentador
   │     • RegistroMensalFrequencia.getSaldoBruto()
   │     • calcularValorRetroativo()  (ValorRetroativoDao, insumo presenca_valorretroativo)
   │     • resultado = valorRetroativo (± saldoBruto)
   └─ RelatorioFrequenciaFinal + itens RelatorioFrequentador persistidos
```

---

## Diagrama de Sequência — Fechamento Mensal

```
[Job GerarRegistroMensal  |  cálculo contínuo]   RegistroMensalFrequenciaServices      DAOs                          RegistroMensalFrequencia
        │  calcular(freq, mes)                         │                               │                                │
        │────────────────────────────────────────────▶│                               │                                │
        │                                             │  getRegistroMensal(freq, mes)  │                                │
        │                                             │───────────────────────────────▶│                                │
        │                                             │  listPorMes (CalculoDiario)    │                                │
        │                                             │───────────────────────────────▶│                                │
        │                                             │  listRetificadoresDoMes        │                                │
        │                                             │───────────────────────────────▶│                                │
        │                                             │                               │                                │
        │                                             │  calcular(mensal, calculos):   │                                │
        │                                             │    zerarRegistro(mensal)       │                                │
        │                                             │    aplicarRetificadores(...)   │──▶ mensal.setRetificado         │
        │                                             │    aplicarCalculosDiarios(...) │──▶ seta meta/saldo/trabalhado    │
        │                                             │      (regra isPodeCalcular)    │                                │
        │                                             │    calcularSaldoAcumulo(...)   │──▶ saldoLiquido/retido/acumulado │
        │◀────────────────────────────────────────────│────────────────────────────────│────────────────────────────────│
```

**EVIDÊNCIAS:**
- `RegistroMensalFrequenciaServices.java:41-44` — `calcular(freq, mes)` → `getRegistroMensal` + `CalculoDiarioDao.listPorMes`.
- `RegistroMensalFrequenciaServices.java:47-65` — `calcular(mensal, calculos)`: zera, aplica retificadores, aplica calculos diários, calcula saldo acumulado.
- `RegistroMensalFrequenciaServices.java:67-83` — `zerarRegistro`.
- `RegistroMensalFrequenciaServices.java:84-104` — `calcularSaldoAcumulo`: saldo líquido, limite crédito/débito, excedente → `retido`.
- `RegistroMensalFrequenciaServices.java:106-152` — `aplicarCalculosDiarios`: soma metas/saldos com a regra `isPodeCalcular` (dias anteriores/hoje fechado).

**Disparo (criação mensal):**
- `GerarRegistroMensalFrequencia.java:22,33-55` — cron `0 10 0 2 1/1 ? *` (2º dia do mês, 00:10); itera frequentadores ativos por id, cria `RegistroMensalFrequencia` se `rmf == null` via `atualizarMesNoAno`.

---

## Diagrama de Sequência — Relatório Final Definitivo

```
[UI: RelatorioFrequenciaFinalActions.create(mes,ano)]
   │  (Validator)                                  RelatorioFrequenciaFinalServices        RegistroMensalFreqServices      ValorRetroativoDao
   │  validaMesCorreto (mês seguinte) + sem duplicata                        │                        │                            │
   │────────────────────────────────────────────────────────────────────────▶│                        │                            │
   │  montarRelatorio(listaFrequentadores, mes, ano)                         │                        │                            │
   │    cria RelatorioFrequenciaFinal                                        │                        │                            │
   │    para cada frequentador:                                              │                        │                            │
   │        getRegistro(f, ano, mes)  ──────────────────────────────────────▶│                        │                            │
   │        saldoBruto = registroMensal.getSaldoBruto()  ◄───────────────────│                        │                            │
   │        calcularValorRetroativo(f, mes, ano)  ──────────────────────────────────────────────────────▶│ (getByMesAno)
   │        valorRetroativo  ◄───────────────────────────────────────────────────────────────┤                           │
   │        resultado = (saldoBruto>=0)? valorRetroativo : saldoBruto+valorRetroativo        │                           │
   ▼
   RelatorioFrequenciaFinal + RelatorioFrequentador (saldoBruto, valorRetroativo, resultado) persistidos
```

**EVIDÊNCIAS:**
- `RelatorioFrequenciaFinalServices.java:70-78` — `montarRelatorio` (cria cabeçalho, dataGeracao, mes/ano como String, chama `construirRelatorioFrequentadores`). *(nota: `setAno(String.valueOf(ano))` — campo String)*
- `RelatorioFrequenciaFinalServices.java:88-108` — `criarRelatorioFrequentador`: `getSaldoBruto`, `calcularValorRetroativo`, `resultado` (positivo = só valor retroativo; negativo = soma).
- `RelatorioFrequenciaFinalServices.java:128-149` — `calcularValorRetroativo`: `ValorRetroativoDao.getByMesAno`; se 1 valor retorna; se >1 soma pelos do mês — **BUG-001** em `:142` (`cont=+valor...`).
- `RelatorioFrequenciaFinalValidator.java:24-43,59-70` — `validateCreate`/`validateUpdate`: relatório só no **mês seguinte** (`verificaMesDoRelatorio` l.69-73) e sem duplicata (create).
- `ValorRetroativoActions.java:29-46` — create: `numeroHora*3600` (para segundos), nega se débito.

---

## Diagrama de Atividades — Retificador de Banco de Horas

```
[UI: RetificadorActions.adicionar(mes,ano,horas,min,tipo)]
   │
   ▼
RetificadorServices.retifica(freq, mes, ano, horas, minutos, tipo, ..., ehPraRecalcular)
   │  horas→seg (H*3600 + M*60)
   ▼
criarRetificador(...)
   ├─ RetificadorDeBancoHoras(freq, mes, ano, segundosARetificar, tipo, informacao, obs, userRoot)
   ├─ Dao.saveOrUpdate
   ├─ SE ehPraRecalcular:
   │     p = Periodo(inicioMes, hoje)
   │     CalculoDiarioServiceV2.atualizarMesNoAno(freq, mes, ano)  → recalcula mês (fluxo B)
   ▼
(no próximo calcular mensal) → aplicarRetificadoresDeBancoHoras → setRetificado
```

**EVIDÊNCIAS:**
- `RetificadorServices.java:21-33` — `retifica(...)` converte horas/minutos em segundos.
- `RetificadorServices.java:62-77` — `criarRetificador`: `Dao.saveOrUpdate`, e se `ehPraRecalcular` → `CalculoDiarioServiceV2.atualizarMesNoAno` (linha do `CalculoDiarioService.INSTANCE.corrigir` comentada).
- `RegistroMensalFrequenciaServices.java:47-49` — `mensal.aplicarRetificadoresDeBancoHoras(retificadores)` → acumula em `retificado`.

---

## Regras de Negócio do Fechamento

| # | Regra | Detalhe | Evidência | Tipo |
|---|-------|---------|-----------|------|
| F1 | **Tudo em segundos** | Saldos, metas, retificadores e valores retroativos são armazenados em **segundos**; conversão de UI (horas/min) ocorre na entrada | `RegistroMensalFrequenciaServices.calcular`; `RetificadorServices.java:24-30`; `ValorRetroativoActions.java:34-36` (`*3600`) | Regra explícita |
| F2 | **Saldo líquido do mês** | `saldoLiquido = saldoMesAnterior + saldoBruto(trabalhado−metaMensal) + retificado`; excedente além do limite crédito/débito vira `retido` | `RegistroMensalFrequenciaServices.java:84-104` (calcularSaldoAcumulo) | Regra explícita |
| F3 | **Limite de crédito/débito** | `limite = config.limiteCredito*3600` (saldo pos) ou `−config.limiteDebito*3600` (saldo neg); excedente → `retido`; `acumulado = saldoLiquido − retido` | `calcularSaldoAcumulo` | Regra explícita |
| F4 | **Saldo mes anterior recursivo** | `getSaldoMesAnterior` percorre mês a mês para trás até haver registro | `RegistroMensalFrequenciaServices.java:154-162` + bean `getSaldoMesAnterior` (l.344-355) | Regra explícita |
| F5 | **isPodeCalcular (agregação diária)** | Soma um `CalculoDiario` ao mensal se: ano anterior, OU (mesmo ano E dia anterior), OU dia de hoje fechado (`!aberto` e `total!=0`) | `aplicarCalculosDiarios` (l.115-137) | Regra explícita |
| F6 | **Relatório só no mês seguinte** | Relatório do mês M só pode ser gerado/alterado no mês **M+1** | `RelatorioFrequenciaFinalValidator.java:59-73` | Regra explícita |
| F7 | **Sem duplicata de relatório** | Não existe mais de um `RelatorioFrequenciaFinal` para o mesmo (mês, ano) | `RelatorioFrequenciaFinalValidator.java:46-50` | Regra explícita |
| F8 | **Resultado do relatório** | `resultado = valorRetroativo` se `saldoBruto>=0`; senão `saldoBruto+valorRetroativo` | `RelatorioFrequenciaFinalServices.java:101-107` | Regra explícita |
| F9 | **Retificador pode recalcular** | `ehPraRecalcular` dispara `atualizarMesNoAno` (motor v2); `estornar` só para créditos de DESCONTO_EM_FOLHA (débito inverso) | `RetificadorServices.java:66-77`; `RetificadorActions.estornar` | Regra explícita |

### Regras implícitas / RISCO (fechamento)

| # | Implícita / Risco | Detalhe | Evidência |
|---|-------------------|---------|-----------|
| I1 | **Lock de fechamento nunca efetivado** | `finalizado` **nunca** é setado `true` em código → o recálculo condicional `rmf == null || !rmf.isFinalizado()` sempre recalcula; não há "congelamento" real do mês (o guarda é só lógico) | `RegistroMensalFrequencia.java:316`; `CalculoDiarioServiceV2.java:78`; **DUV-010** |
| I2 | **BUG-001 — soma retroativa corrompida** | `cont=+valor.getNumeroHora()` (deveria ser `+=`) → soma errada quando há múltiplos valores retroativos no mesmo mês | `RelatorioFrequenciaFinalServices.java:142`; **BUG-001** / DUV-011 |
| I3 | **Divergência de esquema (mes/ano String vs int)** | `RelatorioFrequenciaFinal.mes/ano` são **String** (nome/valor) mas verificados como int; `orgao` comentado no bean mas referenciado no DAO | `RelatorioFrequenciaFinalServices.java:75-76`; `05-banco-horas-fechamento.md` DIVERG-003 / **DUV-008** |
| I4 | **Relatório sempre de TODOS os ativos** | `create` usa todos os frequentadores ativos (validação por órgão está comentada) | `RelatorioFrequenciaFinalValidator.java:22-24,53-55` (comentado) |
| I5 | **Retificado reaplicado a cada calcular** | `zerarRegistro` zera `retificado`, depois `aplicarRetificadoresDeBancoHoras` volta a somar — consistente, mas sensível a duplicidade de retificadores | `RegistroMensalFrequenciaServices.java:47-49,67-83` |

---

## Cross-reference

- **Entidades/tabelas:** `01-inventario/06-tabelas-banco.md` (§5 `registromensalfrequencia`, §14 `retificadorbancohoras`, §15 `valorretroativo`, §16/17 `relatoriofrequenciafinal`/`frequentador`)
- **Domínio detalhado:** `01-inventario/05-banco-horas-fechamento.md`
- **Entrada (cálculo diário):** `09-intranet/fluxos/02-calculo-diario.md` (fluxo B)
- **DUVs relacionadas:** `DUV-008` (mes/ano + orgao), `DUV-010` (finalizado nunca setado), `DUV-011` (bug cont retroativo), `DUV-007` (calculoDiario_id morto), `DUV-009` (debito remanescente morto)

---
**Última atualização:** 2026-08-05
**Fase:** 2 — Engenharia Reversa (fluxo C: fechamento de frequência)
