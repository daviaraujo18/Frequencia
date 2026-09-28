# Domínio: Regime / Jornada / Horário

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## 1. Entidades / Tabelas JPA

### 1.1 `Regime` — `beans/Regime.java` → **`presenca_regime`**
- `@Table(name = "presenca_regime")` (l.35), `@Entity`
- Campos:
  | Campo | Tipo | Anotação | Linha |
  |-------|------|----------|-------|
  | `id` | long | `@Id @GeneratedValue(IDENTITY)` | 38-40 |
  | `nome` | String | — | 42 |
  | `global` | boolean | — | 44 |
  | `modalidade` | `Modalidade` | `@Enumerated(STRING)` | 46-47 |
  | `configuracao` | `ConfiguracaoFrequencia` | `@Embedded` | 49-50 |
  | `expediente` | `List<Horario>` | `@Transient` | 52-53 |
  | `hashExpediente` | String | `@Lob` | 55-56 |
  | `inicio` | Calendar | `@Temporal(DATE)` | 58-59 |
  | `anterior` | Regime | `@ManyToOne(LAZY)` | 61-62 |
  | `categorias` | `List<CategoriaVinculoEnum>` | `@CollectionOfElements @JoinTable("presenca_regime_categoriavinculo")` | 66-70 |
  | `padrao` | Regime | `@ManyToOne` | 72-73 |
  | `excluido` | boolean | — | 75 |
  | `visivel` | boolean | — | 77 |
- **Expediente é JSON** (não normalizado): `hashExpediente` armazena a lista `Horario` serializada via `serializarExpediente()`/`deserializarHash()` (l.300-306, 284-298).

### 1.2 `RegimeFrequentador` — `beans/RegimeFrequentador.java` → **`presenca_regimefrequentador`**
- `@Table(name = "presenca_regimefrequentador")` (l.13)
- Campos: `id`, `tipo` (`TipoRegimeFrequentadorEnum`), `frequentador` (`@ManyToOne`), `regime` (`@ManyToOne`), `periodo` (`@Embedded Periodo`), `dataAlteracao`, `excluido`.
- É a ponte regime↔frequentador com **período de vigência**. `contem(Calendar)` (l.138-147) verifica validade na data.

### 1.3 `Regimento` — `beans/Regimento.java` → **sem tabela própria** (`@Embeddable` l.11)
- Agrega 3 `RegimeFrequentador`: `oficial`, `diferenciado`, `temporario` (cada um `@ManyToOne`). Resolve precedência em `getRegimeFrequentador()` (l.80-93).

### 1.4 `Horario` — `beans/core/Horario.java` → **sem tabela** (POJO JSON embutido em `Regime.hashExpediente`)
- Campos: `inicio`, `fim`, `limiteInicio`, `limiteFim` (strings "HH:mm"), `dias` (códigos de `DiaSemanaEnum`), `diasBinarios` (`@Transient`).

### 1.5 `Estacoes` — `beans/core/Estacoes.java` → **sem tabela** (singleton em memória, não JPA)
- Mantém lista de `EstacaoPonto` em memória com heartbeat (`removeMortos` l.64-75, `TEMPO_INATIVACAO_ESTACAO_MILLS`). Decisão de migração necessária (cache em memória vs persistido).

### 1.6 `ConfiguracaoFrequencia` — `beans/ConfiguracaoFrequencia.java` → **`@Embeddable`** (sem tabela própria, colapsado em `presenca_regime`)
- Campos: `podeFaltar`, `liberadoLimitacaoInicioHoraExtra`, `permitidoAcumularHoras` (default `true`; estagiário/terceirizado/GCET = `false`), `permitidoCompensarFalta`, `permitidoContabilizarHorasMesmoComMetaZero`, `maximoBancoHorasDiarioEmSegundos = 7200` (2h), `limiteCredito`, `limiteDebito`, `percentualCargaMinima`, `limiteDiasCargaMinima`.

## 2. Modalidades de jornada — `enums/Modalidade.java`
```
HORAS               - considera apenas primeira entrada e última saída
HORAS_COM_INTERVALO - considera TODOS os registros efetuados
OCORRENCIAS         - registro único por dia, contabiliza carga horária
```
- Seleção da estratégia de cálculo pela modalidade em `services/calculo/CalculoDiarioService.java:171-183` (e v2).
- **Nota (Q1):** `HORAS_COM_INTERVALO` existe e é calculada, mas NÃO é oferecida no cadastro (`RegimeActions.listDependencies` l.75 só expõe HORAS e OCORRENCIAS). Pode ser modalidade legada.

## 3. Regras de negócio do regime

### 3.1 Carga horária / meta
- `Horario.metaDiariaEmMinutos()` = `fim - inicio` (l.99-103); `metaSemanal()` (l.91-97) distingue HORAS (diária × qtd dias) das demais.
- `Regime.metaSemanal()` (l.390-399), `metaSemanalInMilis()` (l.401-414).
- Máximo permitido: **30h semanais = 100%** (`CalculoDiarioStrategy.calcularMetaDoDia` l.191).

### 3.2 Vínculo regime↔frequentador por categoria
- `Regime.categorias` (l.66-70) → join `presenca_regime_categoriavinculo`.
- Categorias usadas: SERVIDOR_CARREIRA, CARGO_COMISSIONADO, ESTAGIARIO, RESIDENTE, TERCEIRIZADO, AUXILIAR_DA_JUSTICA, CEDIDO (fonte `modules/tjpi/enums/CategoriaVinculoEnum.java`).
- Alteração em massa: `RegimentoServices.alterarRegimeByCategoria` (l.244-257).

### 3.3 Precedência e versionamento
- Precedência: TEMPORARIO > DIFERENCIADO > OFICIAL (`Regimento.getRegimeFrequentador` l.80-93).
- `RegimentoServices.updateRegimeAnterior` (l.142-230): recorte/exclusão de períodos conflitantes (complexa; TODO na l.207).
- `mapRegimesFrequentador` (l.320-373): mapa dia→regime do mês.

### 3.4 Propagação de configuração
- `RegimentoServices.atualizarCalculosDiario` (l.45-69): propaga `permitidoAcumularHoras`, `permitidoCompensarFalta`, etc. para os `CalculoDiario` do período.

### 3.5 Validações — `validators/RegimeValidator.java`
- `validateExpediente` (l.44-92): horários vazios/dias/`inicio < fim`; limites obrigatórios **somente para HORAS**.
- `validateHorarios`/`temConflito` (l.94-113, 163-178): conflito de sobreposição de horários no mesmo dia.

## 4. Ações / Endpoints
- `RegimeActions` (rota `/presenca/Regime`): `execute`/`listDependencies` (modalidades+categorias)/`create`/`explore`/`restoreObject`/`update`.
  - **Nota (Q3):** `update` (l.172-207) está majoritariamente comentado — não atualiza expediente/modalidade/inicio/configuração (l.187-200).
- `RegimeFrequentadorActions` (rota `/presenca/RegimeFrequentador`): `execute`/`listDependencies`.

## 5. Dúvidas / ambiguidades
| Q | Localização | Dúvida |
|---|-------------|--------|
| Q1 | `RegimeActions.java:75,138` | `HORAS_COM_INTERVALO` calculada mas não cadastrável (legada?) |
| Q2 | `Frequentador.java:304-307` | `isPermitidoModalidadeOcorrencias()` sem uso em Java (só backend enforcement ausente) |
| Q3 | `RegimeActions.java:172-207` | `update` comentado — edição de expediente desativada |
| Q4 | `ConfiguracaoFrequencia.java:77` | Bug de clone: `clone.setLimiteDebito(this.limiteCredito)` copia crédito no lugar do débito |
| Q5 | `RegimeValidator.java:71` | Comparação de string formatada vs `Modalidade.HORAS.toString()` — frágil/incorreta |
| Q6 | `RegimentoServices.java:248` | Compara objeto `Regime` com `long id` (`equals(regimeAnterior.getId())`) — sempre inválido |
| Q7 | `services/calculo/` vs `services/calculo/v2/` | Duplicação de motor de cálculo (ver `03-calculo-diario.md`) |
| Q8 | `CalculoDiarioService.java:175-178` | Corte temporal hardcoded 01/12/2018 (Old vs New) |
| Q9 | `beans/core/Estacoes.java` | Singleton em memória — decisão de migração |
| Q10 | `RegimentoServices.java:206-208` | Recorte de períodos complexo com TODO e restabelecimento incompleto |

## 6. Complexidade de migração
**ALTA.** O cadastro de regime (entidades/validações/CRUD) é baixa a média; mas o motor de cálculo de frequência (duplicado v1/v2, com regras temporais e constantes mágicas) eleva a complexidade. **Recomenda-se consolidar v1→v2 e extrair constantes para config antes da migração.**

---
**Origem da análise:** agente de engenharia reversa sobre `intranet/src/modules/presenca/` (2026-08-04).
