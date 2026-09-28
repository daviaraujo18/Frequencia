# Entidades e Value Objects — Domínio Frequência

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Catalogar as **entidades** (com identidade e ciclo de vida) e os **value objects** (imutáveis, valorados por atributos) do contexto FREQUÊNCIA, distinguindo do que é proveniente do contexto PESSOAS (ACL).

> Origem: fluxos A–D (Fase 2) + inventário de tabelas (`01-inventario/06-tabelas-banco.md`).

---

## Entidades (identidade própria)

| Entidade | Agregado (raiz) | Identidade | Observação |
|----------|-----------------|------------|------------|
| `Frequentador` | AG-1 (raiz) | id | Domínio central; ref de frequentador ativo |
| `Regime` | AG-2 (raiz) | id | Jornada/modalidade |
| `RegimeFrequentador` | AG-2 (membro) | id | Vínculo regime×frequentador com vigência |
| `Dia` | AG-3 (raiz) | frequentador + data | **Agregado de cálculo diário** |
| `RegistroFrequencia` | AG-3 (membro) | id | Batida (identidade por batida; dedup por momento) |
| `CalculoDiario` | AG-3 (membro) | id (um por dia/frequentador) | Resultado diário |
| `RegistroMensalFrequencia` | AG-4 (raiz) | frequentador + mês/ano | Fechamento mensal |
| `RelatorioFrequenciaFinal` | AG-5 (raiz) | mês/ano | Fechamento definitivo |
| `RelatorioFrequentador` | AG-5 (membro) | id | Item do relatório final |
| `EstacaoPonto` | AG-6 (raiz) | id + `codAtivacao` | Estação |
| `RegistroEstacaoPonto` | AG-7 (raiz) | id | Lote bruto de batidas |
| `RetificadorDeBancoHoras` | (transação p/ AG-4) | id | Ajuste de banco de horas |
| `ValorRetroativo` | (insumo AG-5) | id | Ajuste financeiro |
| `VersaoEstacaoPonto` | AG-6 (membro) | id | Versão de firmware |
| `EstacaoPing` | AG-6 (membro) | id | Heartbeat |
| `HistoricoTarefa` | (infra/fila) | id | Fila assíncrona de recálculo |

> **Entidades MORRAS (não portar):** `DebitoRemanescenteNegociado` (DUV-009, módulo `aproc`).

---

## Value Objects (imutáveis)

| Value Object | Em | Definição / atributos | Evidência |
|--------------|----|-----------------------|-----------|
| `DigitaisHash` | Frequentador | Hash biométrico (`FIR_TEXTENCODE`), tratado como dado sensível | `06-integracoes/00-digitais-estacao-intranet.md` |
| `ConfiguracaoFrequencia` | Regime | Configurações embutidas (`@Embeddable`): limites de crédito/débito, permitido acumular/compensar etc. | `02-regime-jornada.md` |
| `Periodo` | global | Intervalo `[início, fim]`; usado em períodos a cumprir, direitos | `02-regime-jornada.md` |
| `Tempo` (segundos) | vários | Toda medida de saldo/meta/trabalhado é em **segundos** | Fluxo C F1 |
| `Horario` (enum) | RegistroFrequencia | Classificação da batida (NORMAL, MUITO_CEDO, ...) | `TipoRegistroFrequenciaEnum.Horario` |
| `Zona` (enum) | RegistroFrequencia | NORMAL/ANORMAL (dentro/fora do expediente) | Fluxo B C8 |
| `Operacao` (enum) | RegistroFrequencia | ENTRADA/SAIDA/INDEFINIDO | `TipoRegistroFrequenciaEnum.Operacao` |
| `Modo` (enum) | RegistroFrequencia | BIOMETRICO/MANUAL/LOGIN_SENHA | `TipoRegistroFrequenciaEnum.Modo` |
| `Modalidade` (enum) | Regime | HORAS / HORAS_COM_INTERVALO / OCORRENCIAS | Fluxo B C1 |
| `EstadoDia` (flags) | CalculoDiario | aberto/falta/ausencia/faltaCompensada/faltaADescontar/saidaAntecipada | `beans/CalculoDiario` |
| `CorteTemporal` | cálculo | Datas de corte para troca de algoritmo (ver fluxo B) | Fluxo B (§ cortes) |

---

## Relação Entidade ↔ Tabela (referência rápida)

> Detalhe completo em `01-inventario/06-tabelas-banco.md`. Aqui apenas a correspondência conceito→persistência.

| Entidade (DDD) | Tabela legada |
|----------------|---------------|
| Frequentador | `presenca_frequentador` |
| Regime / RegimeFrequentador | `presenca_regime` / `presenca_regimefrequentador` / `presenca_regime_categoriavinculo` |
| Dia (agregado) | (`presenca_calculodiario` + `presenca_registrofrequencia`) |
| RegistroFrequencia | `presenca_registrofrequencia` |
| CalculoDiario | `presenca_calculodiario` |
| RegistroMensalFrequencia | `presenca_registromensalfrequencia` |
| RelatorioFrequenciaFinal / RelatorioFrequentador | `presenca_relatoriofrequenciafinal` / `...frequentador` |
| EstacaoPonto (+predios/ping/versao) | `presenca_estacaoponto` / `..._predio` / `..._ping` / `..._versao` |
| RegistroEstacaoPonto | `presenca_registroestacaoponto` |
| RetificadorDeBancoHoras | `presenca_retificadorbancohoras` |
| ValorRetroativo | `presenca_valorretroativo` |
| HistoricoTarefa | `presenca_historicotarefa` |
| GestorIndividual | `presenca_gestorindividual` |

---

## Distinção Pessoas → ACL (não são entidades do FREQUÊNCIA)

| Conceito (legado referenciado) | Contexto dono | Como tratar no alvo |
|--------------------------------|---------------|---------------------|
| `Vinculado`, `Vinculo`, `Orgao`, `Predio` | PESSOAS | ID local + consulta via API canônica (ACL) |
| `User` (usuário/responsável) | PESSOAS | ID/sessão; autorização via PESSOAS |
| `PreVinculadoIntervencao` | PESSOAS/RH (tjpi) | serviço externo; extrair para domínio correto |
| `Feriado` | global | manter como dado de referência no FREQUÊNCIA (cache) |

---
**Última atualização:** 2026-08-05
**Fase:** 3 — Mapeamento de Domínio (DDD)
