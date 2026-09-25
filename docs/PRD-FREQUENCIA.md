# PRD — Sistema Frequência (Migração do Módulo Presença da Intranet)

> **Versão:** 1.0 — consolidado a partir de `docs/` (Fases 1–3, concluídas) + ADRs 0001–0005 + PoC `Frequencia/api-ponto`.
> **Data:** 2026-08-26
> **Status:** Rascunho para validação com o gestor do projeto.
> **Nota de origem:** este documento substitui a necessidade de navegar por duas árvores de documentação paralelas (`docs/` e `docs2/`). `docs2/` é um scaffold criado em 2026-08-10 que **não chegou a ser executado** (Fase 0 "em andamento", Fases 1–9 vazias) — é o framework genérico de 10 fases, sem conteúdo de domínio. Todo o conhecimento real (inventário, engenharia reversa, DDD, ADRs) está em `docs/`. Recomenda-se arquivar `docs2/` para eliminar a duplicidade (ver seção 9).

---

## 1. Objetivo

Migrar o módulo **Frequência** (registro de ponto, jornadas, escalas, afastamentos, banco de horas, fechamento) do sistema legado **Intranet** (Java 6 + MySQL 5) para um novo sistema **Frequência** (Ruby on Rails), mantendo a **EstaçãoPonto** (cliente desktop JavaFX, instalada em centenas de unidades) funcionando **sem alterações**, e ao final desligar o módulo `presenca` da Intranet.

O sistema **Pessoas** (Rails, já em produção) permanece como autoridade única dos dados cadastrais (matrícula, nome, CPF, cargo, vínculo, lotação). Frequência não duplica esse cadastro — consome-o.

## 2. Contexto e histórico

- Já existe uma **PoC funcional** (`Frequencia/api-ponto`, Rails, ~3316 arquivos, 25 testes Minitest, Sprints 1–5 concluídas) que implementa a compatibilidade de baixo nível com a EstaçãoPonto: autenticação (username/senha com DES+UrlBase64), download de digitais, sincronização de horário e recebimento de batidas. Ver `Frequencia/PRD-POC-API-PONTO.md`.
- Essa PoC **não cobre** as regras de negócio de frequência propriamente ditas (jornadas, cálculo diário, banco de horas, fechamento, afastamentos) — apenas o canal de comunicação com a estação.
- **ADR-0005 (aceito):** a PoC será restaurada como base do sistema real, em um **novo repositório** (`frequencia-sistema`, nome provisório), com refactoring incremental para estrutura DDD (`domain/`, `application/`, `infrastructure/` separados de Rails/ActiveRecord), preservando o namespace de controllers `presenca` como camada de compatibilidade obrigatória com a EstaçãoPonto (ADR-0003).
- Débitos técnicos herdados da PoC e já identificados: `User` local (precisa virar cache do Pessoas, ADR-0001), `codAtivacao` fixo, DES hardcoded (mantido por compatibilidade, não é prioridade remover).

## 3. Arquitetura alvo (visão de contextos)

```
PESSOAS (Rails, autoridade cadastral)
   │  API REST canônica + eventos assíncronos (ADR-0001)
   ▼
FREQUÊNCIA (Rails, autoridade de ponto — coração do domínio)
   │  Open Host Service — contratos EP-01..EP-12 (ADR-0003)
   ▼
ESTAÇÃO PONTO (desktop JavaFX, legado — conformist, zero alterações)
```

- **PESSOAS → FREQUÊNCIA:** Supplier/Customer. Frequência **nunca** acessa o banco do Pessoas diretamente (proibido em code review). Consulta via API REST + cache local (tabela espelho) atualizado por eventos. Consistência eventual é aceitável — batidas não dependem de dado cadastral em tempo real.
- **FREQUÊNCIA → ESTAÇÃO PONTO:** Open Host Service. A Estação é conformista: adere ao contrato compatível (endpoints EP-01..EP-12, mesmo formato de payload/DES/UrlBase64 do legado). Nenhuma mudança no cliente desktop.
- **Anti-corruption layers pendentes (débito de Fase 4):** o legado acopla `Frequentador`/`RegistroFrequencia` a `Orgao`/`Vinculado`/`User` do Pessoas via Hibernate direto — no alvo, Frequência mantém apenas IDs/refs.

## 4. Modelagem de domínio (Fase 3 — DDD, concluída)

### 4.1 Bounded contexts
| Contexto | Autoridade | Papel |
|---|---|---|
| **Pessoas** | Cadastro (matrícula, cargo, vínculo, lotação) | Provedor |
| **Frequência** | Ponto eletrônico (regras de negócio) | Núcleo do domínio |
| **Estação Ponto** | Captura biométrica | Conformist, sem regra de negócio própria |

### 4.2 Agregados (raízes)
| ID | Agregado | Consistência |
|---|---|---|
| AG-1 | `Frequentador` | forte (estado + restrições de prédio) |
| AG-2 | `Regime` (+ `RegimeFrequentador`) | forte (períodos/jornadas) |
| AG-3 | `Dia` (+ `RegistroFrequencia` + `CalculoDiario`) | **forte — unidade diária, núcleo do motor de cálculo** |
| AG-4 | `RegistroMensalFrequencia` | forte (mês inteiro, saldo/banco de horas) |
| AG-5 | `RelatorioFrequenciaFinal` | forte (mês/ano, gerado no mês seguinte, único) |
| AG-6 | `EstacaoPonto` | forte (cadastro + validação por `codAtivacao`) |
| AG-7 | `RegistroEstacaoPonto` | forte (lote bruto de batidas, processado assíncrono) |

Fluxo de consistência entre agregados: `AG-7 (lote) → job assíncrono (5min) → AG-3 (Dia) → fechamento → AG-4 (Mensal) → AG-5 (Relatório Final)`.

**Nota de modelagem crítica:** `CalculoDiario` e `RegistroFrequencia` **não são raízes** — são membros internos de `Dia` (AG-3). Manter essa relação no Rails evita o erro do legado de tratá-los como tabelas/recursos independentes.

### 4.3 Inventário físico do legado (22 tabelas `presenca_*`, schema MySQL confirmado)
Principais: `presenca_regime`, `presenca_regimefrequentador`, `presenca_calculodiario`, `presenca_registrofrequencia`, `presenca_registromensalfrequencia`, `presenca_frequentador`, `presenca_direito`, `presenca_diaexcepcional`, `presenca_estacaoponto` (+ ping/versão), `presenca_registroestacaoponto`, `presenca_gestorindividual`, `presenca_historicotarefa`, `presenca_retificadorbancohoras`, `presenca_valorretroativo`, `presenca_relatoriofrequenciafinal` (+ item), view `presenca_frequentadorestacao` (não replicada localmente — validar em produção).

Entidade morta identificada (não migrar): `presenca_debitoremanscentenegociavel` (`DebitoRemanescenteNegociado`, código morto — DUV-009).

Detalhe completo: `docs/01-inventario/06-tabelas-banco.md` e `09-schema-confirmado.md`.

## 5. Casos de uso priorizados

| Corte | UCs | Conteúdo |
|---|---|---|
| **Corte 1 (P0 — manter EstaçãoPonto viva)** | UC-01 a UC-06 | Ingestão de lote (EP-05), processamento assíncrono, autenticação do frequentador, sync de digitais/relógio/heartbeat, cálculo diário |
| **Corte 2 (P1 — fechamento e gestão)** | UC-07 a UC-13 | Relatório final mensal, batida manual/errata, desconsiderar/reconsiderar ponto, autorizar horas extras/prédio, retificador de banco de horas, gestão de regimes |
| **Corte 3 (P2/P3 — cadastro/relatórios)** | UC-14 a UC-18 | Sync de frequentador com Pessoas, cadastro de estações, valores retroativos, recálculo em lote, dashboards |

Dependência técnica fixa: UC-06 (consolidar mês) depende de UC-05 (calcular dia); UC-07 (relatório final) depende de UC-06.

Detalhe: `docs/03-dominio/07-casos-uso.md`.

## 6. Escopo

### Dentro do escopo (sistema Frequência completo)
- Compatibilidade total com a EstaçãoPonto (11-12 endpoints `presenca/*`, protocolo DES+UrlBase64) — **já prototipado na PoC**.
- Cálculo diário de frequência (motor único — o legado tinha v1/v2 duplicados, **v2 é o oficial**, DUV-005).
- Jornadas/regimes, direitos/afastamentos/dias excepcionais.
- Banco de horas, fechamento mensal, relatório final definitivo, retificador.
- Gestão de registro (manual/errata, desconsiderar/reconsiderar, autorizações de gestor).
- Integração cadastral com Pessoas via API REST + eventos (não via banco compartilhado).

### Fora do escopo (nesta fase / por decisão explícita)
- Alterações na EstaçãoPonto desktop (zero mudanças, ADR-0003).
- Big Bang: a migração é incremental (Strangler Fig), nunca substituição total de uma vez.
- Novo motor de cálculo com regras diferentes das já vigentes — regras de negócio só mudam com evidência e decisão explícita, nunca por suposição.
- Endpoints periféricos ainda não confirmados como necessários (`PrediosPermitidos`, fotos, auto-update de estação) — tratar caso a caso conforme uso real (ver DUV-003).

## 7. Decisões já tomadas (ADRs 0001–0005)

| ADR | Decisão |
|---|---|
| 0001 | Integração Pessoas↔Frequência via **API REST + eventos assíncronos** (não banco compartilhado, não réplica) |
| 0002 | Estratégia de migração — Strangler Fig |
| 0003 | Compatibilidade EstaçãoPonto via camada Adapter/Open Host Service, zero alteração no desktop |
| 0004 | Desenvolvimento conduzido por ciclo Spec-Driven (spec → design → tasks → execute) por funcionalidade |
| 0005 | PoC restaurada como base, em **novo repositório**, com refactoring DDD incremental |

## 8. Riscos e pendências abertas

- **View `presenca_frequentadorestacao`** não existe na base local usada para o inventário — precisa ser validada contra o schema de produção antes de qualquer réplica/cache.
- **Coexistência de 2 motores de cálculo (v1/v2) no legado** — confirmado que v2 é o oficial (DUV-005), mas exige atenção ao migrar dados históricos calculados pelo v1.
- **`finalizado` (lock do fechamento mensal) nunca é efetivado no legado** (DUV-010) — o sistema novo precisa de um mecanismo real de congelamento, não replicar o bug.
- **Bug conhecido no legado:** `cont=+valor` em vez de `cont+=valor` no cálculo de valor retroativo (DUV-011) — não replicar.
- Todas as DUV-001 a DUV-013 foram resolvidas com evidência (`docs/duvidas/README.md`) — nenhuma pendência bloqueante de entendimento do legado.
- Débito técnico da PoC (User local, codAtivacao fixo) — plano de refatoração já desenhado no ADR-0005, execução via Spec-Driven.

## 9. Recomendação sobre a duplicidade `docs/` vs `docs2/`

`docs2/` foi criado em 2026-08-10 como uma segunda tentativa de framework de documentação, mas **nunca avançou além do scaffold** (nenhuma Fase executada, conteúdo todo genérico/template). Isso está gerando confusão e dupla fonte de verdade. Sugestão:
1. **Arquivar `docs2/`** (mover para `docs2/_ARCHIVED` ou anexar um aviso no topo do README apontando para `docs/`) — decisão sua, não executei por ser uma reorganização de diretórios que prefiro confirmar antes.
2. Manter **`docs/` como única fonte de verdade** daqui para frente — é onde está todo o trabalho real (Fases 1–3 + ADRs).
3. Próximo passo natural segundo o próprio `docs/README.md`: **Fase 4 (Arquitetura Alvo)**, hoje suspensa aguardando este PRD.

## 10. Próximos passos

1. Validar este PRD com o gestor do projeto.
2. Decidir o destino de `docs2/` (arquivar ou apagar).
3. Iniciar Fase 4 (Arquitetura Alvo) em `docs/02-arquitetura/`, usando este PRD + os bounded contexts/agregados como insumo.
4. Executar a Etapa 1 do ADR-0005: restaurar `api-ponto/` da PoC para o novo repositório `frequencia-sistema`.
5. Detalhar ADR-0006 (proposto, ainda não criado): contrato da API canônica do Pessoas para consulta cadastral.

---
**Fontes consolidadas:** `docs/README.md`, `docs/adr/0001..0005`, `docs/03-dominio/*`, `docs/01-inventario/*`, `docs/duvidas/README.md`, `Frequencia/PRD-POC-API-PONTO.md`, `docs2/README.md` (apenas para confirmar que está vazio).
