# Inventário de Tabelas do Módulo `presenca`

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Consolidar em um único documento o **mapeamento de tabelas/entidades** do módulo **Presença/Frequência** da Intranet legada (Java 6 + MySQL 5), extraído do código-fonte (anotações JPA `@Entity`/`@Table`/`@Column`).

**Fonte:** `intranet/src/modules/presenca/beans/` (inspeção 2026-08-05) + `09-intranet/00-indice-modulo-presenca.md`.

> **Limitação:** este inventário documenta as **entidades e colunas mapeadas no Java**. O **schema real** (tipos MySQL, `NULL`/`NOT NULL`, índices, FKs físicas) **requer consulta ao MySQL de produção** — indicado como pendência (ver DUV-006/007/008). Colunas sem `@Column(name=...)` usam o nome do atributo Java como nome de coluna (convenção Hibernate).

## Convenções

- **FK** = associação (`@ManyToOne`, `@OneToOne`, `@OneToMany`, `@ManyToMany`) → vira coluna/relação no banco.
- **@Embedded** = objeto embutido que expande em colunas na tabela dona (`Periodo`, `ConfiguracaoFrequencia`).
- **@Lob** = campo de texto grande (String).
- **`@View`** = view (não tabela física).
- **herança** = campos herdados de `@MappedSuperclass` (`Excepcional`).

---

## Sumário das tabelas (entidades principais)

| # | Tabela | Entidade | Domínio | Observação |
|---|--------|----------|---------|------------|
| 1 | `presenca_regime` | Regime | Jornada/Horário | inclui N:M `presenca_regime_categoriavinculo` |
| 2 | `presenca_regimefrequentador` | RegimeFrequentador | Vínculo regime↔frequentador | |
| 3 | `presenca_calculodiario` | CalculoDiario | Cálculo diário | |
| 4 | `presenca_registrofrequencia` | RegistroFrequencia | Batidas | unicidade composta (6 col) |
| 5 | `presenca_registromensalfrequencia` | RegistroMensalFrequencia | Fechamento mensal | muitos saldos (segundos) |
| 6 | `presenca_frequentador` | Frequentador | Frequentador | inclui N:M `presenca_frequentador_predio` |
| 7 | `presenca_direito` | Direito | Afastamentos/férias | herda `Excepcional` |
| 8 | `presenca_diaexcepcional` | DiaExcepcional | Dias excepcionais | herda `Excepcional` |
| 9 | `presenca_estacaoponto` | EstacaoPonto | Estações | inclui N:M `presenca_estacao_predio` |
| 10 | `presenca_estacaoponto_ping` | EstacaoPing | Heartbeat | |
| 11 | `presenca_registroestacaoponto` | RegistroEstacaoPonto | Registro por estação | |
| 12 | `presenca_gestorindividual` | GestorIndividual | Gestão individual | |
| 13 | `presenca_historicotarefa` | HistoricoTarefa | Recomputação assíncrona | |
| 14 | `presenca_retificadorbancohoras` | RetificadorDeBancoHoras | Ajuste banco de horas | |
| 15 | `presenca_valorretroativo` | ValorRetroativo | Valor retroativo | |
| 16 | `presenca_relatoriofrequenciafinal` | RelatorioFrequenciaFinal | Fechamento definitivo | |
| 17 | `presenca_relatoriofrequentador` | RelatorioFrequentador | Item do relatório final | |
| 18 | `presenca_versaoestacaoponto` | VersaoEstacaoPonto | Versão da estação | |
| 19 | `presenca_debitoremanscentenegociavel` | DebitoRemanescenteNegociado | (entidade **morta**) | código morto (DUV-009) |
| — | `presenca_frequentadorestacao` | FrequentadorEstacao | (view p/ estações) | **@View**, não é tabela física |

**Tabelas de apoio (join/embedded, não-entidade):** `presenca_estacao_predio` (N:M), `presenca_frequentador_predio` (N:M), `presenca_regime_categoriavinculo` (ElementCollection).

---

## Detalhamento por entidade

### 1. `presenca_regime` — Entidade `Regime`
- **id** (long, **@Id**)
- nome (String), global (boolean), modalidade (enum `Modalidade`, `@Enumerated`), configuracao (**@Embedded** `ConfiguracaoFrequencia` → colunas), hashExpediente (**@Lob**, JSON), inicio (DATE)
- **anterior** (**FK** auto-ref `Regime`), **padrao** (**FK** auto-ref `Regime`)
- categorias (**@CollectionOfElements** via `presenca_regime_categoriavinculo`), excluido, visivel
- `expediente` é `@Transient` (não persiste)

### 2. `presenca_regimefrequentador` — Entidade `RegimeFrequentador`
- **id** (long, **@Id**)
- tipo (enum `TipoRegimeFrequentadorEnum`)
- **frequentador** (**FK** → `presenca_frequentador`), **regime** (**FK** → `presenca_regime`)
- periodo (**@Embedded** `Periodo`), dataAlteracao (TIMESTAMP), excluido

### 3. `presenca_calculodiario` — Entidade `CalculoDiario`
- **id** (int, **@Id**)
- normal, excepcional, total, meta (int); flags: aberto, ausencia, falta, faltaADescontar, faltaCompensada, descontadoEmFolha, permitidoContabilizarHorasMesmoComMetaZero, permitidoAcumularHoras, permitidoCompensarFalta, permitidoSaidaAntecipada, liberadoLimitacaoInicioHoraExtra, liberadoBloqueioMaxHoraExtra, limitado, saidaAntecipada (booleans); horarioRecalculo (TIMESTAMP); informacao (String)
- **registroMensal** (**FK** → `presenca_registromensalfrequencia`), **frequentador** (**FK** → `presenca_frequentador`)
- data (DATE), segundosParaCompensarFalta (int)

### 4. `presenca_registrofrequencia` — Entidade `RegistroFrequencia`
- Unicidade composta: `{horario, modo, momento, momentoSincOffline, frequentador_id, id}`
- **id** (long, **@Id**)
- momento, momentoSincOffline, momentoParaCalculo (TIMESTAMP); ressalva, ativo (boolean)
- **frequentador** (FK), **registroEstacaoPonto** (FK), **estacaoPonto** (FK), **lotacaoEpoca** (FK → Orgao), **manifestacao** (FK), **intervencao** (FK)
- enums: modo, operacao, horario, zona (todos `@Enumerated`)

### 5. `presenca_registromensalfrequencia` — Entidade `RegistroMensalFrequencia`
- **id** (int, **@Id**)
- data, dataInicio, dataFim (DATE); ano, mes (int); momentoUltimoCalculo (TIMESTAMP)
- **frequentador** (**FK**)
- Muitos saldos em **segundos**: saldoLiquido, retido, acumulado, retificado, metaAtual, metaMensal, metaAtualDias, metaMensalDias, trabalhado, trabalhadoExcepcional, trabalhadoNormal, trabalhadoDias, tempoAusenteDeFalta, ausentes, faltas, diasEmAberto, faltasACompensar, faltasADescontar, creditoADevolver
- **finalizado** (boolean) — ver **DUV-010** (nunca setado true)

### 6. `presenca_frequentador` — Entidade `Frequentador`
- **id** (int, **@Id**)
- **cadastrador** (**FK** → Usuario), **vinculado** (**FK** → Vinculado), **localTrabalhoPresenca** (**FK** → Predio)
- **digitaisHash** (**@Lob**, String — hash FIR, ver `06-integracoes/00-digitais-estacao-intranet.md`)
- dataCadastro (TIMESTAMP), ativo, permitirManual, limitarAcumuloHoras, limitarPrediosPermitidosBaterPonto, observacao (@Lob)
- **regimesFrequentador** (**@OneToMany** mappedBy=frequentador)
- prediosPermitidosBaterPonto (**@ManyToMany** via `presenca_frequentador_predio`)

### 7. `presenca_direito` — Entidade `Direito` (herda `Excepcional`)
- **Herda de `Excepcional` (@MappedSuperclass):** id (@Id), descricao, responsavel (FK Usuario), periodo (@Embedded), momentoRegistro, observacao, ativo
- Próprios: tipoDireito (enum), **frequentador** (FK), **manifestacao** (FK), **intervencao** (FK)

### 8. `presenca_diaexcepcional` — Entidade `DiaExcepcional` (herda `Excepcional`)
- **Herda de `Excepcional`** (mesmos campos da seção 7)
- Próprios: **setorAtingido** (FK Orgao), **frequentador** (FK), **predio** (FK), tipoFrequenciaExcepcional (enum)

### 9. `presenca_estacaoponto` — Entidade `EstacaoPonto`
- **id** (int, **@Id**)
- descricao, obsAdmin, anydesk, teamviewer, codigoUnicoMaquina, versao (String); **codigoAtivacao** (**@Column unique**) ; liberadoBatidaManual, momentoInicio, momentoFim (DATE)
- **responsavel** (**FK** → Usuario)
- **predios** (**@ManyToMany** via `presenca_estacao_predio`)
- vários campos `@Transient` (não persistidos)

### 10. `presenca_estacaoponto_ping` — Entidade `EstacaoPing`
- **id** (int, @Id); **estacaoPonto** (FK), momento (TIMESTAMP), ip (String), versao (String)

### 11. `presenca_registroestacaoponto` — Entidade `RegistroEstacaoPonto`
- **id** (long, @Id); **estacao** (FK), arquivoCriptografado (@Lob), processado (boolean), momentoSinc / momentoProcessamento (TIMESTAMP), ip

### 12. `presenca_gestorindividual` — Entidade `GestorIndividual`
- **id** (int, @Id); **gestor** (**@OneToOne** `@JoinColumn(name="vinculado_id")` → Vinculado), **frequentador** (**@OneToOne** — NOTE: aqui é OneToOne), dataCriacao/dataExclusao (TIMESTAMP), ativo, observacao (@Lob)
- ⚠️ Atenção: `gestor` aponta para `Vinculado` (não `Frequentador` de forma direta)

### 13. `presenca_historicotarefa` — Entidade `HistoricoTarefa`
- **id** (int, @Id); hashTarefa (@Lob), tipoEntidade (enum `TipoEntidade`), dtAdicao/dtExecucao (TIMESTAMP) — **sem FKs**

### 14. `presenca_retificadorbancohoras` — Entidade `RetificadorDeBancoHoras`
- **id** (long, @Id); **frequentador** (FK), **responsavel** (**FK** → `User` admin), mes, ano (int), excluido (boolean), tipo (enum `TipoRetificadorEnum`), segundosARetificar (int), observacao/informacao (@Lob), momentoRegistro (TIMESTAMP)
- Implementa `PresencaExcepcional` mas **não** herda `Excepcional`
- ⚠️ `calculoDiario_id` referenciado em DAO mas **inexistente** → ver **DUV-007**

### 15. `presenca_valorretroativo` — Entidade `ValorRetroativo`
- **id** (long, @Id); **frequentador** (**@OneToOne** FK), mes, ano (int), dataGeracao (TIMESTAMP), processo (String), numeroHora (int)

### 16. `presenca_relatoriofrequenciafinal` — Entidade `RelatorioFrequenciaFinal`
- **id** (long, @Id); dataGeracao/dataAlteracao (TIMESTAMP); **mes/ano (String)** — ⚠️ divergência de tipo → ver **DUV-008**
- **relatorioFrequentadores** (**@OneToMany** mappedBy, CascadeType.ALL)
- ⚠️ campo `orgao` comentado no bean → ver **DUV-008**

### 17. `presenca_relatoriofrequentador` — Entidade `RelatorioFrequentador`
- **id** (long, @Id); **frequentador** (**@OneToOne** FK), **relatorioFrequenciaFinal** (**@ManyToOne** FK); valorRetroativo, saldoBruto, resultado (int)

### 18. `presenca_versaoestacaoponto` — Entidade `VersaoEstacaoPonto`
- **id** (Long, @Id); numVersao (**@Column unique**), novidade (String), releaseDate (TIMESTAMP) — **sem FKs**

### 19. `presenca_debitoremanscentenegociavel` — Entidade `DebitoRemanescenteNegociado` ⚠️ **MORTA**
- **id** (int, @Id); **manifestacao** (FK → módulo **aproc** `Manifestacao`), **responsavel** (FK → Usuario), **registroMensalFrequencia** (oneToOne FK)
- ⚠️ **Nenhum código a utiliza** (só o bean) → ver **DUV-009**. Não portar para o Frequência.

### 20. `presenca_frequentadorestacao` — **VIEW** `FrequentadorEstacao`
- Não é tabela física (`@View` + `@Entity(name=...)`).
- id, matricula, nomeCompleto, digitalHash, arquivoFoto, sexo, predioId (`@Column("predio_id")`)
- Alimenta as estações (via `DynFrequentadoresEstacao`). Ver **DUV-005** e `06-integracoes/00-digitais-estacao-intranet.md`.

---

## Relações entre tabelas (mapa de dependências)

```
presenca_frequentador  ◄── FK ──  quase todas (frequentador_id)
   ├── vinculado (OneToOne → tjpi_vinculado)
   ├── localTrabalhoPresenca (ManyToOne → Predio)
   ├── cadastrador (ManyToOne → sistema Usuario)
   └── prediosPermitidosBaterPonto (ManyToMany → presenca_frequentador_predio)

presenca_regime  ── anteriores/padrao (auto-FK) ── categorias (regime_categoriavinculo)
presenca_regimefrequentador  → frequentador, regime

presenca_calculodiario → frequentador, registroMensal
presenca_registrofrequencia → frequentador, estacaoPonto, registroEstacaoPonto, lotacaoEpoca(Orgao), manifestacao(aproc), intervencao
presenca_registromensalfrequencia → frequentador
presenca_relatoriofrequenciafinal → (OneToMany) relatoriofrequentador
presenca_relatoriofrequentador → frequentador, relatoriofrequenciafinal
presenca_retificadorbancohoras → frequentador, responsavel(User admin)
presenca_valorretroativo → frequentador
presenca_estacaoponto → responsavel(Usuario) ── predios (estacao_predio N:M)
presenca_estacaoponto_ping → estacaoPonto
presenca_registroestacaoponto → estacaoPonto
presenca_gestorindividual → gestor(Vinculado), frequentador
presenca_direito / presenca_diaexcepcional → frequentador, manifestacao/intervencao, setorAtingido(Orgao), predio
presenca_debitoremanscentenegociavel (MORTA) → manifestacao(aproc), responsavel, registroMensal
```

**FKs recorrentes:** `frequentador_id` (na maioria), `responsavel_id`/`cadastrador_id` (Usuario), `manifestacao_id` (módulo aproc — **inativo**), `intervencao_id`, `estacaoPonto_id`, `regime_id`, `vinculado_id`.

---

## Observações / sinalizações de migração

| # | Observação | Referência |
|---|-------------|------------|
| 1 | `presenca_debitoremanscentenegociavel` = **entidade morta**, ligada a módulo `aproc` (inativo) → **não portar** | DUV-009 |
| 2 | `presenca_frequentadorestacao` é **view** (não tabela) — replicar como *query/view* no Frequência | `07-estacao-ponto/02-endpoints-consumidos.md` |
| 3 | `presenca_registromensalfrequencia.finalizado` **nunca é setado true** → lock de fechamento ausente no legado | DUV-010 |
| 4 | Campos `segsAcumulavelMensal`, `orgao` **ausentes no banco** → não portar. **`calculoDiario_id` EXISTE no banco** (FK→`presenca_calculodiario`) mas **não é mapeado no bean** — inconsistência de camada a resolver | DUV-006, DUV-007, DUV-008; `09-schema-confirmado.md` |
| 5 | `digitaisHash` (`@Lob`) armazena **hash FIR_TEXTENCODE** (não imagem) — tratar como dado sensível; tipo físico = `text` | `06-integracoes/00-digitais-estacao-intranet.md`; `09-schema-confirmado.md` |
| 6 | `Regime.configuracao` (@Embedded `ConfiguracaoFrequencia`) e `Periodo` expandem em múltiplas colunas — mapear no Frequência | `01-inventario/02-regime-jornada.md` |
| 7 | N:M joins: `estacao_predio`, `frequentador_predio`, ElementCollection `regime_categoriavinculo` | — |
| 8 | **`presenca_registrofrequencia` NÃO tem unique index físico** (o `uniqueConstraints` de 6 col do Java não existe no banco) → dedup é só por lógica de aplicação | `09-schema-confirmado.md` |
| 9 | **View `presenca_frequentadorestacao` NÃO existe no banco local** — verificar em produção / modelo equivalente | `07-estacao-ponto/02-endpoints-consumidos.md`; `09-schema-confirmado.md` |
| 10 | Tabelas volumosas p/ dimensionar migração: `registroestacaoponto` (AUTO_INC 4.97M), `ping` (94M), `calculodiario` (14M), `historicotarefa` (2.6M) | `09-schema-confirmado.md` |

---

## Pendência para schema definitivo

- ✅ **Coletado (2026-08-05):** schema físico de todas as 22 tabelas `presenca_*` obtido via conexão MySQL (`intranet`) — registrado em `09-schema-confirmado.md` (inclui tipos, `NOT NULL`, índices, FKs, e reconciliação com os beans JPA). ⚠️ Banco é **teste/amostra** (estrutura autêntica, dados não-produtivos).
- [ ] **Validar em produção (estrutura):** confirmar com o time de dados que o schema capturado da base local é **idêntico em estrutura** ao de produção (dados serão diferentes).
- [ ] **View `presenca_frequentadorestacao`:** confirmar existência/definição em produção (não existe no banco local).
- Decidir no Frequência a modelagem DDD (Fase 3) a partir deste inventário físico — **feito** (ver `03-dominio/`).

---
**Última atualização:** 2026-08-05
