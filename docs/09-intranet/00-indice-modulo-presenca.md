# Inventário Detalhado — Módulo Frequência (Intranet Legada)

> **[⌂ Home](../README.md)**

## Propósito

Inventário detalhado (Fase 1) e engenharia reversa inicial (Fase 2) do módulo **Presença/Frequência** da Intranet legada (Java 6 + MySQL 5), localizado em `intranet/src/modules/presenca/`.

**Escopo:** documentar TODAS as funcionalidades que a PoC `api-ponto/` NÃO cobre (cálculos, jornadas/regimes, escalas, férias, banco de horas, fechamento). As funcionalidades já cobertas pela PoC (batida, autenticação, sync) são detalhadas em `07-estacao-ponto/`.

## Visão Geral do Módulo

- **Tamanho:** 178 arquivos Java, ~22.062 linhas, 1.3MB — `intranet/src/modules/presenca/`
- **Persistência:** JPA/Hibernate com anotações `@Entity`/`@Table` (sem arquivos `.hbm.xml`; tabelas 19 principais)
- **Arquitetura interna:** `actions/` (controladores+servlets), `beans/` (entidades), `dao/`, `services/`, `jobs/`, `enums/`, `validators/`, `filters/`, `tags/`, `formatters/`
- **Importante:** existe pasta `services/calculo/` (v1) e `services/calculo/v2/` (engine duplicada)

## Tabelas do Módulo (19 principais)

| Tabela | Entidade | Domínio |
|--------|----------|---------|
| `presenca_regime` | Regime | Jornada/Horário |
| `presenca_regimefrequentador` | RegimeFrequentador | Vínculo regime↔frequentador |
| `presenca_regime_categoriavinculo` | (join) | Categorias do regime |
| `presenca_calculodiario` | CalculoDiario | Cálculo diário |
| `presenca_registrofrequencia` | RegistroFrequencia | Batidas |
| `presenca_registromensalfrequencia` | RegistroMensalFrequencia | Fechamento mensal |
| `presenca_frequentador` | Frequentador | Frequentador |
| `presenca_direito` | Direito | Afastamentos/ferias/licenças |
| `presenca_diaexcepcional` | DiaExcepcional | Dias excepcionais (feriados etc.) |
| `presenca_estacaoponto` | EstacaoPonto | Estações |
| `presenca_estacaoponto_ping` | EstacaoPing | Heartbeat |
| `presenca_registroestacaoponto` | RegistroEstacaoPonto | Registro por estação |
| `presenca_gestorindividual` | GestorIndividual | Gestão individual |
| `presenca_historicotarefa` | HistoricoTarefa | Recomputação assíncrona |
| `presenca_retificadorbancohoras` | RetificadorDeBancoHoras | Ajuste manual banco de horas |
| `presenca_valorretroativo` | ValorRetroativo | Valor retroativo |
| `presenca_relatoriofrequenciafinal` | RelatorioFrequenciaFinal | Fechamento definitivo |
| `presenca_relatoriofrequentador` | RelatorioFrequentador | Item do relatório final |
| `presenca_debitoremanscentenegociavel` | DebitoRemanescenteNegociado | (entidade morta) |
| `presenca_versaoestacaoponto` | VersaoEstacaoPonto | Versão da estação |

## Domínios de Negócio (documentação em `01-inventario/`)

| # | Domínio | Doc | Complexidade migração |
|---|---------|-----|----------------------|
| A | Regime/Jornada/Horário | `01-inventario/02-regime-jornada.md` | 🔴 Alta |
| B | Cálculo Diário | `01-inventario/03-calculo-diario.md` | 🔴 Alta |
| C | Direitos/Afastamentos/Férias/Dia Excepcional | `01-inventario/04-direitos-afastamentos.md` | 🔴 Alta |
| D | Banco de Horas/Fechamento/Retificador | `01-inventario/05-banco-horas-fechamento.md` | 🔴 Alta |

Dúvidas extraídas dos 4 domínios: `01-inventario/07-duvidas-domains.md` + arquivos `DUV-005..013` (realocados nesta pasta).

> **Realocação (2026-08-05):** as dúvidas do módulo presenca/Intranet **DUV-005..013** foram resolvidas e **realocadas** de `duvidas/` para esta pasta (`09-intranet/`), pois pertencem ao domínio deste módulo:
| DUV | Assunto | Status |
|-----|---------|--------|
| `DUV-005-motor-calculo-v1-v2.md` | Motor de cálculo duplicado v1×v2 — qual é o oficial | ✅ Resolvida |
| `DUV-006-campo-segsacumulavelmensal.md` | Divergência `segsAcumulavelMensal` (método morto) | ✅ Resolvida |
| `DUV-007-campo-calculodiario-id.md` | Divergência `calculoDiario_id` (método morto) | ✅ Resolvida |
| `DUV-008-campo-orgao-relatoriofinal.md` | Divergência `orgao` + mistura int/String `mes`/`ano` | ✅ Resolvida |
| `DUV-009-debito-remanescente-morto.md` | `DebitoRemanescenteNegociado` código morto | ✅ Resolvida |
| `DUV-010-finalizado-nunca-setado.md` | `finalizado` nunca setado — lock de fechamento | ✅ Resolvida |
| `DUV-011-bug-cont-valor-retroativo.md` | Bug `cont=+getNumeroHora()` (deveria ser `+=`) | ✅ Resolvida |
| `DUV-012-cortes-temporais-calculo.md` | Cortes temporais do cálculo (datas hardcoded) | ✅ Resolvida |
| `DUV-013-faltas-compensaveis.md` | Faltas 10→12 + bug `Calendar.MONDAY` | ✅ Resolvida |

## Fluxos (Fase 2 — Engenharia Reversa)

| # | Fluxo | Doc | Status |
|---|-------|-----|--------|
| A | Batida de Ponto (ingestão online + processamento assíncrono + regras) | `fluxos/01-batida-ponto.md` | ✅ Feito (2026-08-05) |
| B | Cálculo Diário (motores v1/v2 + disparos + regras + cortes temporais) | `fluxos/02-calculo-diario.md` | ✅ Feito (2026-08-05) |
| C | Fechamento (mensal `RegistroMensalFrequencia` + definitivo `RelatorioFrequenciaFinal` + retificador/retroativo) | `fluxos/03-fechamento.md` | ✅ Feito (2026-08-05) |
| D | Gerenciamento de Registro (desconsiderar/reconsiderar/errata manual/autorizações) | `fluxos/04-gerenciamento-registro.md` | ✅ Feito (2026-08-05) |

> **Fase 2 (Engenharia Reversa) CONCLUÍDA (2026-08-05):** os 4 fluxos principais (A–D) estão diagramados com regras + evidência `arquivo:linha`.

> Cada fluxo traz diagrama de sequência + regras de negócio com **evidência (`arquivo:linha`)** — ver convenções `00-contexto/02-convencoes.md` (marcador `EVIDÊNCIA:`).

## Análise PoC × Legado (o que já está coberto vs o que falta)

**A PoC `api-ponto/` cobre APENAS (ver `docs/05-migracao/00-codigo-preexistente-poc.md`):**
- Registro de batida (`SincronizarRegistrosPonto`, `presenca_registrofrequencia`)
- Autenticação manual (`ValidarFrequentador`)
- Download/verificação de digitais (`DynFrequentadoresEstacao`, `DynHashFrequentadoresEstacao`)
- Sincronização de horário (`CarregaRelogioAtual`)
- Heartbeat (`AdicioneEstacao`)

**A PoC NÃO cobre (e que este inventário documenta):**
- Jornadas/regimes/horários (modalidades HORAS, HORAS_COM_INTERVALO, OCORRENCIAS)
- Cálculo diário de frequência (motor complexo com v1/v2)
- Direitos (férias, licenças, afastamentos) e dias excepcionais
- Banco de horas, retificador, valores retroativos
- Fechamento mensal (Registro Mensal) e definitivo (Relatório Final)
- Estações, gestão individual, heartbeat persistido, versionamento

> **CONCLUSÃO DE ESCALA:** As funcionalidades NÃO cobertas representam a maior parte da complexidade da frequência. O motor de cálculo sozinho (domínios B, C, D interligados) é mais complexo que toda a PoC. A migração desses fluxos é o verdadeiro esforço da Fase 2+.

---
**Última atualização:** 2026-08-04
