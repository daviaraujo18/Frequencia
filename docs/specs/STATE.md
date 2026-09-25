# STATE — Memória do Projeto de Migração

> **[⌂ Home](../README.md)**

> Este arquivo segue o modelo de memória do TLC Spec-Driven v3 (adaptado para migração).
> Duas seções com ciclos de vida distintos. NUNCA sobrescrever o arquivo inteiro — sempre editar a seção específica.

## Decisions (Decisões de Nível de Projeto)

### AD-001: Integração Pessoas ↔ Frequência
- **Decision**: Integração via API REST + Eventos (não compartilhamento de banco)
- **Reason**: Desacoplamento de bounded contexts; o Pessoas é autoridade cadastral, o Frequência autoridade de ponto
- **Trade-off**: Consistência eventual; dados cadastrais podem ficar desatualizados por segundos
- **Scope**: Integração entre os sistemas Pessoas e Frequência
- **Date**: 2026-08-03
- **Status**: active

### AD-002: Estratégia de Migração
- **Decision**: Strangler Fig Pattern com proxy reverso (3 estágios: sombra → parcial → total)
- **Reason**: Risco controlado; rollback simples; validação contínua com dados reais
- **Trade-off**: Complexidade operacional; dois sistemas rodando em paralelo
- **Scope**: Processo de migração da Intranet para o Frequência
- **Date**: 2026-08-03
- **Status**: active

### AD-003: Compatibilidade EstaçãoPonto
- **Decision**: Camada de compatibilidade (Adapter) + Proxy Reverso (Nginx)
- **Reason**: Zero alterações na EstaçãoPonto; suporte ao Strangler Fig
- **Trade-off**: Serviço extra para manter; latência adicional; complexidade de debug
- **Scope**: Comunicação EstaçãoPonto ↔ Intranet/Frequência
- **Date**: 2026-08-03
- **Status**: active

### AD-004: Ciclo Spec-Driven por Funcionalidade
- **Decision**: Integrar o ciclo Specify → Design → Tasks → Execute (TLC Spec-Driven v3) como motor micro de cada funcionalidade, dentro do framework de 10 fases (macro)
- **Reason**: Disciplina rigorosa anti-invenção de requisitos; rastreabilidade; verificador independente
- **Trade-off**: Overhead de processo; curva de aprendizado; adaptação do TLC (greenfield) para migração
- **Scope**: Execução de cada funcionalidade individual da migração
- **Date**: 2026-08-03
- **Status**: proposed

### AD-005: PoC `api-ponto/` como Base do Sistema Frequência
- **Decision**: RESTAURAR a PoC em NOVO repositório (`frequencia-sistema`) + refactoring arquitetural incremental para DDD. Camada `presenca` controllers mantida como Adapter (ADR-0003); `User` refatorado para cache Pessoas (ADR-0001); dívidas viram features Spec-Driven (ADR-0004)
- **Reason**: Decisão confirmada pelo gestor em 04/08/2026. Equilíbrio entre reaproveitamento de 3316 arquivos testados e liberdade para arquitetura DDD limpa; economia de meses de trabalho sem herdar dívidas perpétuas
- **Trade-off**: Esforço de setup inicial (novo repo, migração de código); possibilidade de divergência temporária entre PoC (referência) e sistema em produção; refactoring incremental exige disciplina
- **Scope**: Base de código do Frequência definitivo
- **Date**: 2026-08-04
- **Status**: accepted
- **Refs**: `docs/adr/0005-destino-poc-api-ponto.md`, ADR-0001, ADR-0002, ADR-0003, ADR-0004

### AD-006: PADRÃO de API Pessoas → Frequência (PENDENTE)
- **Decision**: Pendente. Proposta: criar namespace `/api/v1/integracoes/` no Pessoas, autenticado via token/JWT, com endpoints canônicos para servidores ativos, e event stream para mudança cadastral. Frequência mantém cache local invalidado por eventos.
- **Reason**: Após análise em `docs/08-pessoas/01-analise-inicial.md`, identificou-se que `utils/*` é voltado para UI interna e `pessoa_info` acopla o Pessoas à Intranet legada via SticapiClient. API canônica service-to-service não existe ainda.
- **Trade-off**: Exige desenvolvimento no Pessoas (fora do repositório Frequência); mas mantém ADR-0001 válido e remove acoplamento Intranet legado.
- **Scope**: Adaptações no Pessoas para integrar com Frequência
- **Date**: 2026-08-04 (pendente)
- **Status**: proposed
- **Refs**: `docs/08-pessoas/01-analise-inicial.md`, ADR-0001

## Handoff (Snapshot de Pausa — sobrescrever a cada pausa)

- **Fase**: Fase 0 — Preparação concluída; Fase 1 — Inventário **CONCLUÍDO**; Fase 2 — Engenharia Reversa **CONCLUÍDA**; Fase 3 — Mapeamento de Domínio (DDD) **CONCLUÍDA**. **Fase 4+ (Arquitetura/Rails) SUSPENSA por decisão do usuário** até o inventário completo e a construção do PRD.
- **Funcionalidade**: N/A — **PARADO ANTES do design de implementação.** Por decisão do usuário (2026-08-05): **não escrever código Rails** nem avançar para Fase 4; o **PRD** só será construído **após a conclusão do inventário**.
- **Completado**:
  - Estrutura do ai-workflow + ADRs 0001–0005 (ACEITOS) + ADR-0006 (PROPOSTO)
  - Leitura das 3 docs pré-existentes em `frequencia/`
  - Descoberta da PoC `api-ponto/` + decisão Alternativa C (ADR-0005 aceito)
  - Ação 1 executada: validação cruzada Pessoas/EstaçãoPonto (routes.rb, Pessoa.da_ativa, vinculo, utils_controller risco, pom.xml, TestCrypto prova empírica DES)
  - **Fase 1 — Inventário do módulo presenca (2026-08-05):**
    - 4 domínios inventariados: `01-inventario/02-regime-jornada.md`, `03-calculo-diario.md`, `04-direitos-afastamentos.md`, `05-banco-horas-fechamento.md`
    - **DÚVIDAS DUV-001..013 TODAS RESOLVIDAS** (2026-08-05):
      - DUV-005..013 resolvidas por inspeção exaustiva do código do módulo presenca (motor v1×v2, esquema, fechamento, bug valor retroativo, cortes temporais, faltas compensáveis, `Calendar.MONDAY`)
      - Arquivos realocados para pastas temáticas: `08-pessoas/DUV-001`, `07-estacao-ponto/DUV-002..004`, `09-intranet/DUV-005..013`; `duvidas/` virou apenas índice (`duvidas/README.md`)
    - **`06-integracoes/00-digitais-estacao-intranet.md`** criado — armazenamento/transmissão/consumo de digitais (hash `FIR_TEXTENCODE`) EstaçãoPonto ⇄ Intranet
    - **`01-inventario/06-tabelas-banco.md`** criado (2026-08-05) — inventário consolidado de 19 tabelas + 1 view do módulo presenca; índice `01-inventario/00-indice.md:16` ✅
    - **SCHEMA FÍSICO COLETADO (2026-08-05):** conexão MySQL `intranet` (MariaDB 10.4.32, via config `hibernate.properties`); todas as **22 tabelas `presenca_*`** registradas em `09-schema-confirmado.md` (tipos, `NOT NULL`, índices, FKs). **Reconciliação com beans resolve:**
      - DUV-006 `segsAcumulavelMensal` → **ausente** no banco (coluna não existe) ✅
      - DUV-007 `calculoDiario_id` → **existe** no banco (FK→`presenca_calculodiario`) mas **não mapeado** no bean ⚠️
      - DUV-008 `mes/ano` String + `orgao` → **`mes`/`ano` varchar(255)**; **`orgao` ausente** ✅
      - Descoberta: `presenca_registrofrequencia` **sem unique index físico** (dedup só por lógica); view `presenca_frequentadorestacao` **não existe** no banco local; charset `latin1`; tabelas volumosas (`ping` 94M, `calculodiario` 14M).
  - `09-intranet/00-indice-modulo-presenca.md` atualizado com DUVs realocadas + seção "Fluxos (Fase 2)"
  - **Fase 2 — Engenharia Reversa (2026-08-05, CONCLUÍDA):**
    - **`09-intranet/fluxos/01-batida-ponto.md`** (fluxo A) — ingestão EP-05 + job assíncrono + regras R1-R6 + pendências P1-P3
    - **`09-intranet/fluxos/02-calculo-diario.md`** (fluxo B) — motor v2 + divergências v1/v2 + disparos T1-T4 + regras C1-C9 + cortes temporais
    - **`09-intranet/fluxos/03-fechamento.md`** (fluxo C) — fechamento mensal/definitivo + retificador/retroativo + regras F1-F9 + riscos I1-I5
    - **`09-intranet/fluxos/04-gerenciamento-registro.md`** (fluxo D) — manual/errata, desconsiderar/reconsiderar, autorizações + regras G1-G9 + riscos I1-I4
  - **Fase 3 — Mapeamento de Domínio (DDD) (2026-08-05, CONCLUÍDA):** `03-dominio/` preenchido (07 documentos):
    - `01-linguagem-ubiqua.md` (glossário + termos a evitar/anticorrupção), `02-bounded-contexts.md` (PESSOAS/FREQUÊNCIA/ESTAÇÃO PONTO + ACL), `03-agregados.md` (AG-1..AG-7; `Dia`=AG-3 raiz do cálculo), `04-entidades-value-objects.md`, `05-eventos-dominio.md` (E1-E11 + P1-P3), `06-servicos-dominio.md`, `07-casos-uso.md` (UC-01..UC-18 priorizados)
  - **Navegação "voltar ao índice" implementada (2026-08-05, CONCLUÍDA):** bloco `> **[⟰ Voltar ao Índice](...)** · **[⌂ Home](...)**` no topo de **59 arquivos `.md`**; formatação normalizada e verificada (`título → blank → nav → blank → conteúdo`); diff vs `ai-workflow/docs` confirmou **zero linhas de conteúdo removidas**; links corretos (índice: só `Home`; conteúdo: `Voltar`+`Home`; subpasta `fluxos/`: só `Home`)
- **Em andamento** (arquivo:linha): — (**Inventário CONCLUÍDO** + navegação OK; aguardando aprovação do usuário para iniciar o PRD)
- **Próximo passo (inventário → PRD → sprints/tasks)**:
  1. **Validar em produção**: confirmar com o time de dados que o schema capturado (banco local `intranet`, MariaDB) é **idêntico em estrutura** ao de produção, e verificar a **view `presenca_frequentadorestacao`** (não existe no banco local).
  2. **Construir o PRD** a partir do inventário completo (inventário + fluxos/engenharia reversa + domínio + schema confirmado).
  3. **Elaborar o Plano de Desenvolvimento** com **Sprints e Tasks** (a partir do PRD) — Fase 7 do framework.
  4. **SÓ ENTÃO** retomar Fase 4 (Arquitetura Alvo / Rails) / ADRs de design que o plano exigir. **Não-bloqueante:** ADR-0006.
- **Blockers**: Nenhum para documentação. **DECISÃO DO USUÁRIO:** não escrever código Rails nem construir PRD antes do inventário fechado — **inventário agora fechado** (schema coletado). Validação em produção é recomendada, não-bloqueante p/ começar o PRD.
- **Arquivos não commitados**: Nenhum (repositório local, sem remoto; documentação em `ai-workflow/` é estática — não alterar)
- **Branch**: `main`
