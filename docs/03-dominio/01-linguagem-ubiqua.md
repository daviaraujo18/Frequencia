# Linguagem Ubíqua — Domínio Frequência

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Glossário único e canônico do domínio **Frequência**, extraído do código legado e dos fluxos documentados na **Fase 2** (`09-intranet/fluxos/`). O objetivo é que **equipe técnica e de negócio (RH) usem exatamente os mesmos termos** na Fase 4+ (arquitetura) e nos testes de aceite.

> **Fonte:** `intranet/src/modules/presenca/`, fluxos A–D (`09-intranet/fluxos/01..04-*.md`), inventários (`01-inventario/02..06-*.md`). Termos têm **evidência** (`arquivo:linha` ou fluxo/regra).

---

## Glossário — Termos Centrais

| Termo (ubíquo) | Sinônimo legado | Definição | Evidência |
|----------------|-----------------|-----------|-----------|
| **Batida** | RegistroFrequencia | Registro de um momento de passagem do servidor (entrada/saída), capturado na estação ou manual | Fluxo A; `beans/RegistroFrequencia.java` |
| **Frequentador** | Frequentador | Servidor habilitado a bater ponto (vínculo com Pessoas); possui digitais (hash) e restrições | `beans/Frequentador.java`; tabela `presenca_frequentador` |
| **Estação de ponto** | EstacaoPonto | Terminal (desktop com leitor biométrico) onde as batidas são capturadas; identificada por `codAtivacao` | Fluxo A EP-05/06; `beans/EstacaoPonto.java` |
| **Regime** | Regime | Definição de jornada: modalidade (HORAS, HORAS_COM_INTERVALO, OCORRENCIAS), expedientes e configurações | Fluxo B C1; `05-banco-horas-fechamento.md` |
| **Modalidade** | Modalidade | Tipo de regime que define a estratégia de cálculo: HORAS / HORAS_COM_INTERVALO / OCORRENCIAS | `CalculoDiarioServiceV2.calcularDia` |
| **Período a cumprir** | Periodo | Janela(s) de tempo em que o servidor deve cumprir a jornada (normal/excepcional + meta) | Fluxo B C2; `BuscaPeriodosV2` |
| **Meta** | meta | Quantidade diária de trabalho esperada (em segundos); base para falta/compensação | Fluxo B C3; `beans/CalculoDiario` |
| **Cálculo diário** | CalculoDiario | Resultado diário: horas normal/excepcional/total, estado (falta, ausência, aberto, saída antecipada) | Fluxo B; `beans/CalculoDiario.java` |
| **Falta** | falta | Dia não trabalhado (meta>0, total=0, dia anterior a hoje) | Fluxo B C3 |
| **Falta compensada** | faltaCompensada | Falta abatida do saldo de horário (compensada com horas acumuladas) | Fluxo B C7 |
| **Falta a descontar** | faltaADescontar | Falta que será descontada em folha (após limite de compensação) | Fluxo B C7 |
| **Ausência** | ausencia | Dia com jornada parcial (< percentual mínimo exigido) | Fluxo B C4 |
| **Banco de horas** | saldo | Saldo acumulado (segundos) entre trabalhado e meta; diário e mensal com limites de crédito/débito | Fluxo C F2/F3 |
| **Saldo líquido** | saldoLiquido | `saldoMesAnterior + saldoBruto + retificado` antes do teto de retenção | Fluxo C F2; `calcularSaldoAcumulo` |
| **Saldo retido** | retido | Excedente além do limite de crédito/débito que não migra | Fluxo C F3 |
| **Fechamento mensal** | RegistroMensalFrequencia | Consolidação mensal dos cálculos diários + saldo do banco de horas | Fluxo C |
| **Relatório final** | RelatorioFrequenciaFinal | Fechamento definitivo mensal por frequentador, com valor retroativo | Fluxo C |
| **Retificador** | RetificadorDeBancoHoras | Ajuste manual de banco de horas (crédito/débito) num mês | Fluxo C; `RetificadorServices` |
| **Valor retroativo** | ValorRetroativo | Ajuste financeiro (saldo) aplicado no relatório final | Fluxo C; `ValorRetroativoActions` |
| **Desconsiderar ponto** | desconsiderar | Anular as batidas de um dia (gestor), com intervenção de auditoria | Fluxo D G2 |
| **Ressalva** | ressalva | Marca de que a batida tem pendência/está em prédio não permitido e não conta no cálculo normal | Fluxo A; `beans/RegistroFrequencia` |
| **Intervenção** | PreVinculadoIntervencao | Trilha de auditoria/autorização (módulo `tjpi`) criada em operações de gestão | Fluxo D |
| **Direito** | Direito | Afastamento, licença ou férias que altera a jornada do dia | `01-inventario/04-direitos-afastamentos.md` |
| **Dia excepcional** | DiaExcepcional | Feriado/oneração/abono que modifica os períodos a cumprir | Fluxo B C2; `BuscaPeriodosV2` |
| **Horário** | Horario (enum) | Classificação da batida: NORMAL, MUITO_CEDO, MUITO_TARDE, DESCONSIDERADO, LIMITADO etc. | Fluxo A/D; `TipoRegistroFrequenciaEnum` |
| **Zona** | Zona (enum) | Indica se a batida está dentro (NORMAL) ou fora (ANORMAL) do expediente | Fluxo B C8 |

---

## Termos de Estado (enum legado → linguagem ubíqua)

**Horário de uma batida (modo como o sistema trata a batida):**

| Valor legado | Significado ubíquo |
|--------------|--------------------|
| `NORMAL` | Batida válida, conta no cálculo |
| `MUITO_CEDO` | Antes do início permitido |
| `MUITO_TARDE` | Após o fim/tolerância |
| `DESCONSIDERADO` | Batida anulada pelo gestor |
| `DESCONSIDERADO_PREDIO` | Anulada por prédio não permitido (indeferido) |
| `LIMITADO` | Acúmulo de horas limitado (aguardando/negado autorização) |
| `LIMITADO_INDEFERIDO` | Acúmulo de horas indeferido |
| `SOLICITADO_AUTORIZACAO_PREDIO` | Aguardando autorização de prédio não permitido |

**Modo de captura:** `BIOMETRICO` (batida em estação), `MANUAL` (registro manual/errata), `LOGIN_SENHA` (autenticado na estação).

**Operação:** `ENTRADA`, `SAIDA`, `INDEFINIDO` (manual).

**Estado do dia (`CalculoDiario`):** `aberto` (incompleto/em curso), `falta`, `ausencia`, `faltaCompensada`, `faltaADescontar`, `saidaAntecipada`, `descontadoEmFolha`.

---

## Termos que NÃO devem ser usados (anticorrupção)

| Termo a evitar | Por quê | Alternativa ubíqua |
|----------------|---------|--------------------|
| `segsAcumulavelMensal` | Campo inexistente no bean (código morto/DUV-006) | usar `saldoAcumulado` |
| `calculoDiario_id` (em retificador) | Coluna inexistente (DUV-007) | usar vínculo mensal/diário correto |
| `DebitoRemanescenteNegociado` | Entidade morta, módulo `aproc` (DUV-009) | remover / negociar débito via retificador |
| `Orgao orgao` no relatório | Campo comentado + divergência (DUV-008) | lotação vem do contexto Pessoas |

---

## Relação com Bounded Contexts

Este glossário é a **linguagem ubíqua do contexto FREQUÊNCIA**. Termos como **Frequentador**, **Lotação**, **Vínculo**, **Matrícula** são de **origem Pessoas** e devem ser importados como referência/anti-corrupção (ver `02-bounded-contexts.md`), não duplicados como autoridade.

---
**Última atualização:** 2026-08-05
**Fase:** 3 — Mapeamento de Domínio (DDD)
