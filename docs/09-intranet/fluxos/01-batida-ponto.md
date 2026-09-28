# Fluxo — Batida de Ponto (Fase 2: Engenharia Reversa)

> **[⌂ Home](../../README.md)**

## Propósito

Documentar o **fluxo completo de registro de batida de ponto** no módulo `presenca` da Intranet legada: desde o envio da batida pela EstaçãoPonto até a persistência do `RegistroFrequencia`, com as regras de negócio aplicadas e seu **estado posterior ao cálculo diário**.

> **Fase 2 (Engenharia Reversa).** Cada regra traz uma **EVIDÊNCIA** (`arquivo:linha`). Regras implícitas/hardcoded estão marcadas como `PENDÊNCIA`/`APRENDIZADO`. A fonte é `intranet/src/modules/presenca/`.

**Escopo de entrada:** Este fluxo cobre a **ingestão da batida** e a criação do `RegistroFrequencia`. O **cálculo de horas** (que consome este registro) é domínio B e será diagramado em fluxo próprio (ver `03-calculo-diario.md`).

---

## Visão Geral (Mapa de Dependências)

```
EstaçãoPonto (desktop)
   │ POST /presenca/ajax/SincronizarRegistrosPonto   (EP-05)
   ▼
SincronizarRegistrosPonto (AjaxAction)  ─┐
   │ cria/salva RegistroEstacaoPonto ────┤ (arquivo criptografado bruto)
   ▼                                       │
[Job] ProcessarArquivoSincronizado  ◄──────┘ cron cada 5min (7h-21h)
   │ pega não-processados, descriptografa DES, parseia lotes
   ▼
cria RegistroFrequencia (BIOMETRICO)  → [regras de dedup + prédio + intervenção]
   │
   ▼
RegistroFrequencia ativo persistido → consumido pelo Cálculo Diário (Fase 2, fluxo B)
```

> **DECISÃO (ADR-0003):** o novo Frequência deve **reproduzir o endpoint EP-05** para compatibilidade com a EstaçãoPonto (zero alteração no desktop). Ver `07-estacao-ponto/02-endpoints-consumidos.md`.

---

## Diagrama de Sequência — Ingestão Online

```
 EstaçãoPonto          SincronizarRegistrosPonto         RegistroEstacaoPonto          MySQL
     │  POST registros DES+UrlBase64, codAtivacao                  │                     │
     │──────────────────────────────────────────▶│                  │                     │
     │                                          │  getEstacaoPontoByCodAtivacao(codAtivacao)  │
     │                                          │──────────────────▶│
     │                                          │                  │                     │
     │                                          │  cria RegistroEstacaoPonto:                │
     │                                          │    estacao, arquivoCriptografado(registros),
     │                                          │    momentoSinc, ip(getIpsFromClient)
     │                                          │──────────────────▶ Dao.save + flush + commit
     │                                          │                  │──────────────────────▶ INSERT
     │   "sincronizado"  ◄─────────────────────│                  │                     │
     │◀──────────────────────────────────────────│                  │                     │
     │                                          │                  │                     │
     │  (resposta imediata ao desktop;          │                  │                     │
     │   processamento real é ASSÍNCRONO)       │                  │                     │
```

**EVIDÊNCIAS:**
- `SincronizarRegistrosPonto.java:34-51` — `@Transactional`, validação `registros != null && !registros.isEmpty()`, salva `RegistroEstacaoPonto` e responde `ajaxSuccess("sincronizado")`.
- `SincronizarRegistrosPonto.java:40-49` — persistência do lote bruto: `registroEstacao.setArquivoCriptografado(registros)`, `setMomentoSinc(momentoSinc)`, `setIp(getIpsFromClient())`, `Dao.save`.
- `SincronizarRegistrosPonto.java:37` — valida a estação pelo `codAtivacao` (sem ele, não sincroniza).

> ⚠️ **APRENDIZADO (assincronia):** o endpoint NÃO cria o `RegistroFrequencia`. Ele apenas **persiste o lote criptografado bruto** em `presenca_registroestacaoponto`. O parsing/descriptografia acontece em job agendado. Isso significa que o cálculo/registro real é **eventualmente consistente** — a estação recebe `"sincronizado"` mesmo que o processamento posterior falhe (a falha só fica visível no log do job).

---

## Diagrama de Sequência — Processamento Assíncrono (Job)

```
[Job] ProcessarArquivoSincronizado        RegistroEstacaoPonto        RegistroFrequencia         [Regras]
   │ listNaoProcessado() ◄───────────────────────────────────────────────────────────────────────┘
   │────────────────────▶│ (lotes com processado=false)
   │  para cada lote:
   │   split(";")  → registrosCriptografados
   │   DES decrypt("cryp:gpf", cada item)  → registrosDescriptografados
   │   para cada registro descrip:
   │     split("-") → [idFrequentador, dd:MM:yyyy:HH:mm:ss]
   │     monta Calendar momento (campos separados por ":")
   │     Frequentador = Dao.get(Frequentador, idFrequentador)
   │     existeRegistro = getRegistroByData(momento, frequentador)
   │        ├── SE existe → SKIP (dedup)                          [R1]
   │        └── SE não existe AND frequentador != null:
   │              cria RegistroFrequencia
   │              verifica limitação de prédio                     [R3]
   │              seta estacaoPonto, lotacaoEpoca, modo BIOMETRICO,
   │              momento, momentoSincOffline, ativo=true
   │              Dao.save(registro)                               [R4]
   │   registroEstacao.setProcessado(true); setMomentoProcessamento
   │   Dao.update(registroEstacao)
   └──────────────────────────────────────────────────────────────────────────────▶ COMMIT
```

**EVIDÊNCIAS:**
- `ProcessarArquivoSincronizado.java:34` — `RegistroEstacaoPontoDao.listNaoProcessado()`.
- `ProcessarArquivoSincronizado.java:45-46` — `split(";")`.
- `ProcessarArquivoSincronizado.java:53` — `CryptoUtil.decryptDES("cryp:gpf", ...)` (mesma chave do endpoint).
- `ProcessarArquivoSincronizado.java:62-73` — parse `idFrequentador-dia:mes:ano:hh:mm:ss`.
- `ProcessarArquivoSincronizado.java:75-76` — `Dao.get(Frequentador, id)` e `getRegistroByData(momento, frequentador)` (dedup).
- `ProcessarArquivoSincronizado.java:117-123` — montagem do registro: `setMomento`, `setMomentoSincOffline`, `setEstacaoPonto`, `setLotacaoEpoca`, `setModo(BIOMETRICO)`, `setRegistroEstacaoPonto`, `setAtivo(true)`, `Dao.save`.
- `ProcessarArquivoSincronizado.java:136-138` — `setProcessado(true)`, `setMomentoProcessamento`, `Dao.update`.

> ⚠️ **PENDÊNCIA:** a linha que **enfileiraria o recálculo** (`HistoricoTarefaServices.addTarefaRegistro` em `ProcessarArquivoSincronizado.java:131`) está **comentada**. O recálculo do cálculo diário para novos registros é disparado por outros mecanismos (jobs `RecalculoDiario`/`CalculoDiarioAusentes`) — a cadeia exata será fechada no diagrama do fluxo de Cálculo (fluxo B).

---

## Regras de Negócio da Ingestão

| # | Regra | Detalhe | Evidência | Tipo |
|---|-------|---------|-----------|------|
| R1 | **Dedup por timestamp** | Um mesmo `(momento, frequentador)` não gera dois registros: se `getRegistroByData` retorna registro (**ativo e sem ressalva**), o novo é **ignorado** | `ProcessarArquivoSincronizado.java:76-78`; `RegistroFrequenciaDao.getRegistroByData` (filtra `ativo=true` e `ressalva=false`) | Regra explícita |
| R2 | **Frequentador inexistente é descartado** | Se `frequentador == null`, não cria registro (e não marca erro — segue o lote) | `ProcessarArquivoSincronizado.java:75,79-80` | Regra explícita |
| R3 | **Restrição de prédio (limitação)** | Se `frequentador.isLimitarPrediosPermitidosBaterPonto()` e há prédios permitidos, valida se a estação pertence a um deles; senão, gera **intervenção** `SOLICITADO_AUTORIZACAO_PREDIO` e marca ressalva | `ProcessarArquivoSincronizado.java:97-116`; `RegistroFrequencia.solicitarBaterPontoEmPredioNaoPermitido` (seta `Horario.SOLICITADO_AUTORIZACAO_PREDIO`, ressalva=true) | Regra explícita |
| R4 | **Modo BIOMETRICO padrão** | Batidas vindas da estação via EP-05 ficam com `modo = BIOMETRICO`, `ativo = true`, `ressalva = false` (padrão), `lotacaoEpoca` da lotação atual do vínculo principal | `ProcessarArquivoSincronizado.java:90,117-123` | Regra explícita |
| R5 | **Registro bruto sempre guardado** | Todo lote sincronizado fica persistido em `presenca_registroestacaoponto` (auditoria + re-processável), independente de sucesso do parse | `SincronizarRegistrosPonto.java:40-49` | Regra explícita |
| R6 | **Timestamp do relógio da estação é a referência** | O `momento` da batida vem do payload da estação, não do servidor; `momentoSincOffline` registra o momento da transmissão | `ProcessarArquivoSincronizado.java:67-73,118` | Regra explícita |

> **Ressalva/código morto (TODO):** em `ProcessarArquivoSincronizado.java:84-95`, há um bloco **comentado** que setaria `ressalva=true` e validaria o prédio do frequentador contra os prédios da estação — comportamento **não ativo** hoje. `setRessalva(false)` é sempre executado.

---

## Diagrama de Atividades — Processamento de Batidas

```
[Job dispara: 0 0/5 7-21 * * ?]
        │
        ▼
[ler lotes não-processados]
        │
        ▼
┌─ para cada lote ──────────────────────────┐
│  split(";") → descriptografar DES         │
│  para cada registro:                      │
│    parse id + horário                     │
│    ├─ momento+frequentador já existe? ── SIM → PULA (R1)
│    │        └─ NÃO
│    │           ├─ frequentador null? ─────── SIM → PULA (R2)
│    │           │        └─ NÃO
│    │           │           ├─ limita prédio? → gera intervenção (R3)
│    │           │           ▼
│    │           │        cria RegistroFrequencia (R4)
│    │           ▼
│  marcar lote processado=true ──────────────┐
└────────────────────────────────────────────┘
        ▼
[COMMIT / ROLLBACK por erro]
```

**EVIDÊNCIA (agendamento):** `ProcessarArquivoSincronizado.java:27` — `@CronTrigger(expression = "0 0/5 7-21 * * ?")` (a cada 5 minutos, entre 07h e 21h). Rollback por erro: `ProcessarArquivoSincronizado.java:142-146`.

---

## Mapa de Estados do RegistroFrequencia (entrada)

Estados relevantes **no momento da ingestão** (campo `horario` do enum `TipoRegistroFrequenciaEnum`):

```
[chegada da batida]
   │
   ├─ NORMAL  (padrão, prédio ok, sem restrição)          → cálculo normal
   ├─ SOLICITADO_AUTORIZACAO_PREDIO  (R3: prédio não permitido)  → aguarda decisão de gestor
   └─ DESCONSIDERADO / DESCONSIDERADO_PREDIO (via desconsiderar, pós-cálculo)
```

**EVIDÊNCIA (enum):** `TipoRegistroFrequenciaEnum.java` — `Horario { NORMAL, MUITO_CEDO, MUITO_TARDE, DESCONSIDERADO, LIMITADO, LIMITADO_INDEFERIDO, SOLICITADO_AUTORIZACAO_PREDIO, DESCONSIDERADO_PREDIO }`.

> O fluxo de **desconsiderar/reconsiderar** e o de **registro manual (errata)** também modificam o estado — será detalhado em fluxo próprio (gerenciamento de registro) porque atravessa o cálculo diário. Referência: `RegistroFrequencia.desconsiderar`/`reconsiderar`/`manualFromForm`.

---

## Regras implícitas / PENDÊNCIAS

| # | Regra Implícita / Risco | Detalhe | Evidência |
|---|-------------------------|---------|-----------|
| P1 | **Falha de processamento "silenciosa"** | Se o parse de um lote falhar, o job faz **rollback de TODO o lote** e apenas loga (`System.out.println`), sem notificação. A estação já recebeu `"sincronizado"`. Risco de perda de batidas não detectada | `ProcessarArquivoSincronizado.java:142-146` |
| P2 | **Dedup por timestamp exato** | `getRegistroByData` compara `momento` **exato** (timestamp completo), não por dia. Dois batimentos no mesmo segundo do mesmo frequentador = dedup; batidas em segundos distintos não são dedupadas por essa consulta | `RegistroFrequenciaDao.getRegistroByData` |
| P3 | **Enfileiramento de recálculo desativado** | Código que enfileiraria `HistoricoTarefa` para recalcular está comentado — a re-cadeia de cálculo para novas batidas precisa ser confirmada (ver fluxo B / `HistoricoTarefaServices`) | `ProcessarArquivoSincronizado.java:131` |

---

## Cross-reference

- **Endpoint consumido (EP-05):** `07-estacao-ponto/02-endpoints-consumidos.md` (§EP-05)
- **Criptografia DES:** `07-estacao-ponto/03-validacao-compatibilidade-des.md`, `06-integracoes/00-digitais-estacao-intranet.md`
- **Entidade/tabela:** `01-inventario/06-tabelas-banco.md` (§4 `presenca_registrofrequencia`, §11 `presenca_registroestacaoponto`)
- **Cálculo que consome o registro:** `01-inventario/03-calculo-diario.md` (fluxo B — a diagramar)
- **Intervenção (módulo tjpi):** `RegistroFrequencia` → `PreVinculadoServices.novaIntervencaoPassiva`

---
**Última atualização:** 2026-08-05
**Fase:** 2 — Engenharia Reversa (fluxo A: batida de ponto)
