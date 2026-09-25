# Análise e Integração: TLC Spec-Driven v3

> **[⌂ Home](../README.md)**

## Propósito

Analisar a abordagem **Spec-Driven Development v3** do Tech Leads Club e definir como integrá-la ao nosso framework de migração.

## O que é TLC Spec-Driven v3?

O TLC Spec-Driven é uma skill para agentes de IA que estrutura o desenvolvimento de features em 4 fases adaptativas:

```
┌──────────┐   ┌──────────┐   ┌─────────┐   ┌─────────┐
│ SPECIFY  │ → │  DESIGN  │ → │  TASKS  │ → │ EXECUTE │
└──────────┘   └──────────┘   └─────────┘   └─────────┘
   required      optional*      optional*     required
```

A grande inovação é o **Auto-Sizing**: a profundidade de cada fase é determinada pela complexidade da feature, não por um pipeline fixo.

## Princípios-Chave Extraídos

### 1. Auto-Sizing (Determinação de Profundidade)

| Escopo | Especificar | Design | Tasks | Executar |
|--------|------------|--------|-------|----------|
| **Pequeno** (≤3 arquivos) | One-liner | Pular | Pular | Inline |
| **Médio** (<10 tasks) | Spec breve | Pular (design inline) | Pular (tasks implícitas) | Implementar + verificar |
| **Grande** (multi-componente) | Spec completo + IDs | Arquitetura + componentes | Breakdown completo | Implementar + verificar por task |
| **Complexo** (ambiguidade) | Spec + Discussão | Pesquisa + arquitetura | Breakdown + plano de fases | Implementar + UAT interativo |

### 2. Estrutura de Memória (`.specs/`)

```
.specs/
├── STATE.md              # Decisões (append-only) + Handoff (snapshot)
├── LESSONS.md            # Lições aprendidas (auto-gerado)
├── lessons.json          # Estado canônico das lições
└── features/
    └── [feature]/
        ├── spec.md       # Requisitos com IDs traçáveis
        ├── context.md    # Decisões do usuário (gray areas)
        ├── design.md     # Arquitetura e componentes
        ├── tasks.md      # Tasks atômicas com verificação
        └── validation.md # Relatório do Verificador
```

### 3. Verificador Independente (Author ≠ Verifier)

Após a última task, UM VERIFICADOR FRESCO é disparado automaticamente. Ele:
- Refaz a cobertura do zero (evidence-or-zero)
- Confirma que cada assertion corresponde ao **resultado esperado definido na spec**
- Executa um **discrimination sensor** (injeta falhas em scratch state, confirma que os testes detectam)
- Gera `validation.md` com PASS/FAIL por critério de aceite

### 4. Gatilhos de Discussão (Implicit-Requirement Dimensions)

Dimensões que disparam discussão com o usuário antes de prosseguir:

| Dimensão | O que cobrir |
|----------|-------------|
| Validação de input e limites | Formatos, sanitização |
| Falha / estados parciais | Timeouts, rollbacks parciais |
| Idempotência / retry / dedup | Retentativas seguras |
| Auth e rate limits | Quem pode chamar o quê |
| Concorrência / ordering | Race conditions |
| Ciclo de vida de dados / expiração | TTL, arquivamento |
| Observabilidade | Logs, métricas, tracing |
| Falha de dependência externa | Circuit breakers |
| Integridade de transição de estado | Transições válidas, guards |

### 5. Commits Atômicos

Uma task = um commit. Formato: [Conventional Commits](https://www.conventionalcommits.org/).

### 6. Test Coverage Matrix

Gerada antes da execução, define para cada camada:
- Tipo de teste necessário (unit/integration/e2e/none)
- Expectativa de cobertura
- Padrão de localização
- Comando para executar

---

## O que Já Temos Similar em Nosso Framework

Nosso framework de migração (10 fases) já contempla:

1. **Descoberta → Documentação → Validação → Modelagem → Implementação → Testes → Migração**
2. **ADRs** para decisões arquiteturais (similar ao `STATE.md` → Decisions)
3. **Estrutura de diretórios organizada** em `docs/`
4. **Restrições de não assumir comportamento** e sempre documentar evidências

## O que Podemos Absorver do TLC Spec-Driven

### Para Adotar Já:

1. **Auto-Sizing (profundidade adaptativa)** → Nosso framework de 10 fases também usa auto-sizing conceitualmente (Fase 1 é mais pesada, Fase 2 é mais leve), mas podemos explicitar isso.

2. **Formato WHEN/THEN/SHALL para critérios de aceite** → Muito mais testável que linguagem solta.

3. **Requirement Traceability IDs** → Mapear cada regra de negócio descoberta na engenharia reversa para IDs únicos, garantindo rastreabilidade até a implementação.

4. **Verificador Independente (Author ≠ Verifier)** → Após migrar cada funcionalidade, um verificador separado confere se o comportamento do novo sistema equivale ao legado.

5. **Handoff Snapshot** → Já criamos `context/00-sessao-atual.md` com propósito similar. Podemos padronizar no formato do TLC Spec-Driven.

6. **Test Coverage Matrix** → Essencial para a Fase 8 (Testes), especialmente na comparação entre legado e novo sistema.

7. **Discrimination Sensor** → Adaptado para migração: injetar mudanças no código legado para confirmar que os testes de caracterização detectam regressões.

### Para Adaptar:

1. **`context.md` para gray areas** → Em vez de "discutir com usuário sobre layout", usaremos para documentar decisões sobre regras de negócio ambíguas encontradas na engenharia reversa.

2. **`validate.md` → `validacao-migracao.md`** → Em vez de validar spec vs implementação, validaremos comportamento legado vs novo comportamento.

3. **Sistema de Lições (`lessons.py`)** → Adaptaremos para registrar "armadilhas de migração" descobertas durante o processo.

### O Que Já Temos e É Superior:

1. **ADR formal** → Mais robusto que o `STATE.md` Decisions simples do TLC.
2. **Framework de 10 fases** → Mais abrangente para o cenário de migração (que envolve inventário, engenharia reversa, compatibilidade legada, etc.).
3. **Camada de compatibilidade** → Ausente no TLC Spec-Driven (é para greenfield, não para migração).

## Proposta de Integração

Vamos criar uma **skill híbrida** que combina:

1. **As 10 fases do framework de migração** (escopo macro)
2. **O ciclo Spec-Driven** (escopo micro — para cada funcionalidade individual)

Isto é, o framework de migração define **o quê** fazer em cada fase macro, e o Spec-Driven define **como** executar cada funcionalidade individual dentro da Fase 7 (Implementação).

### Exemplo Prático

```
Fase 2: Engenharia Reversa (macro)
  └── Para cada funcionalidade (ex: "Registro de Batida"):
        ├── SPECIFY: Documentar o comportamento observado no código legado
        │   └── Formato WHEN/THEN/SHALL
        ├── DESIGN: Modelar a arquitetura alvo para esta funcionalidade
        ├── TASKS: Quebrar em tasks atômicas de implementação
        └── EXECUTE: Implementar, testar, verificar equivalência
            └── VERIFIER: Confirmar que novo sistema produz mesmos resultados
                que o legado para mesmas entradas
```

## Estrutura de Diretórios Adicional

Vamos adicionar ao nosso framework:

```
docs/
└── specs/                     # Spec-Driven específico para migração
    ├── STATE.md               # Decisões + Handoff (formato TLC)
    └── features/
        └── [funcionalidade]/
            ├── spec.md        # Comportamento documentado (eng. reversa)
            ├── design.md      # Modelagem DDD / arquitetura alvo
            ├── tasks.md       # Tasks de implementação
            └── validacao-migracao.md  # Validação: legado vs novo
```

## Decisão

**DECISÃO:** Integrar o ciclo Spec-Driven (Specify → Design → Tasks → Execute) como o **motor de execução** de cada funcionalidade dentro das fases 2 a 7 do nosso framework de migração.

O framework de 10 fases continua sendo o **mapa macro** (o "o quê" e "quando"). O Spec-Driven é o **mapa micro** (o "como" para cada funcionalidade).

(Ver ADR-0004)

---
**Autor:** Arquiteto de Migração
**Data:** 2026-08-03
