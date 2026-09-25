# Serviços de Domínio — Frequência

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Identificar os **serviços de domínio** (operações que não pertencem naturalmente a uma única entidade/agregado) do contexto FREQUÊNCIA, mapeando-os para as classes/serviços do legado. Serviços de aplicação/infraestrutura são descritos na Fase 4.

---

## Serviços de Domínio (coordenam múltiplos agregados)

| Serviço | Responsabilidade | Agregados envolvidos | Legado equivalente | Evidência |
|---------|------------------|----------------------|--------------------|-----------|
| `ServicoDeCalculoDiario` | Transformar batidas do dia em `CalculoDiario` (seleciona estratégia por modalidade + cortes temporais) | AG-3 Dia | `CalculoDiarioServiceV2` | Fluxo B; `CalculoDiarioServiceV2.calcularDia` (l.264) |
| `ServicoDeCriacaoDoMes` | Criar/atualizar `RegistroMensalFrequencia` a partir dos dias do mês (saldo acumulado) | AG-3 → AG-4 | `RegistroMensalFrequenciaServices.calcular` | Fluxo C; `RegistroMensalFrequenciaServices.java:47` |
| `ServicoDeFechamentoDefinitivo` | Gerar/atualizar `RelatorioFrequenciaFinal` (mês seguinte; único) | AG-4 → AG-5 | `RelatorioFrequenciaFinalServices.montarRelatorio/atualizarRelatorio` | Fluxo C; `RelatorioFrequenciaFinalServices.java:70` |
| `ServicoDeGerenciamentoDeRegistro` | Desconsiderar/reconsiderar batidas do dia com validação de gestor | AG-3 Dia + AG-1 (ref) | `RegistroFrequenciaServices.desconsiderarPonto/reconsiderarPonto` | Fluxo D G2-G4 |
| `ServicoDeAutorizacao` | Registrar decisões (deferir/indeferir) de acúmulo de horas e batida em prédio | AG-3 Dia + ACL Pessoas | `RegistroFrequenciaServices.deferir/indeferir*` | Fluxo D G5/G6 |
| `ServicoDeRetificador` | Aplicar ajuste de banco de horas num mês (e recalcular) | AG-4 Mensal | `RetificadorServices.retifica` | Fluxo C F9 |
| `ServicoDeProcessamentoDeLote` | Interpretar lote bruto da estação → gerar `RegistroFrequencia` | AG-7 → AG-3 | `ProcessarArquivoSincronizado` (job) | Fluxo A |

---

## Regras de validação (candidatas a regras de domínio / aplicação)

| Regra | Serviço | Origem legado | Evidência |
|-------|---------|---------------|-----------|
| Gestor do órgão pode desconsiderar | GerenciamentoDeRegistro | `podeDesconsiderarFrequencia` | `RegistroFrequenciaServices.java:91-108` |
| Só edita registro MANUAL | GerenciamentoDeRegistro | `RegistroFrequenciaValidator.validateUpdate` | `RegistroFrequenciaValidator.java:83-90` |
| Relatório só no mês seguinte + único | FechamentoDefinitivo | `RelatorioFrequenciaFinalValidator` | `RelatorioFrequenciaFinalValidator.java:24-50` |
| Limite de faltas compensadas/ano (10→12) | CalculoDiario | `CalculoDiario.getMaxFaltasCompensadasPermitidasPorAno` | `beans/CalculoDiario.java:327-333` |
| Limite de **10 descontos** em folha | CalculoDiario (labels) | hardcoded no `definirLabels` | `CalculoDiarioServiceV2.java` (`faltasADescontar < 10`) |

---

## Serviços de Aplicação (orquestração — não são domínio puro)

> Apenas listados como referência; detalhados na Fase 4.

- **Ingestão EstaçãoPonto** (adapter): `SincronizarRegistrosPonto` (controller/ajax).
- **Jobs assíncronos:** `ExecutaTarefas` (consome fila de eventos), `RecalculoDiario` (noturno), `GerarRegistroMensalFrequencia`, `CalculoDiarioAusentes`.
- **UI CRUD:** `RegimeActions`, `FrequentadorActions`, `EstacaoPontoActions`, `RelatorioFrequenciaFinalActions`, `ValorRetroativoActions`.

---

## Recomendações de modelagem (Fase 4)

1. **Serviços de domínio "puros"** — sem dependência de framework/HQL/SQL nativo; recebem agregados/args e retornam resultado + eventos de domínio. Ex.: `ServicoDeCalculoDiario` deve ser testável em memória (base para testes de caracterização).
2. **Separação infra:** a persistência (`Dao`, `HQLProvider`) e o schedule (Quartz) são **infraestrutura**, não domínio — o legado mistura tudo; no alvo isolar.
3. **Motor único:** consolidar `v2` como oficial (a refatoração baseada em `Dia` é a mais adequada ao agregado AG-3); eliminar v1 dos caminhos de gestão (fluxo D).

---
**Última atualização:** 2026-08-05
**Fase:** 3 — Mapeamento de Domínio (DDD)
