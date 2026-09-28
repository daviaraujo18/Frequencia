# ADR-0004: Integração do Ciclo Spec-Driven ao Framework de Migração

> **[⌂ Home](../README.md)**

## Status

Proposto

## Contexto

O framework de migração (10 fases) define o escopo **macro** da migração (o quê fazer em cada fase). No entanto, durante a execução de cada funcionalidade individual (Fase 2 a 7), há risco de:
- Escopo mal definido (o agente entende errado o que deve ser feito).
- Requisitos inventados (o agente assume comportamento em vez de verificar no código legado).
- Testes fracos que não provam a equivalência legado ↔ novo.
- Perda de contexto entre sessões.

A skill **TLC Spec-Driven v3** do Tech Leads Club oferece um ciclo disciplinado (Specify → Design → Tasks → Execute) com:
- Auto-sizing (profundidade proporcional à complexidade).
- Requisitos rastreáveis (IDs, formato WHEN/THEN/SHALL).
- Verificador independente (Author ≠ Verifier).
- Modelo de memória (STATE.md com Decisões + Handoff).
- Test Coverage Matrix.

## Alternativas Consideradas

### Alternativa A: Manter apenas o framework de 10 fases

- **Prós:** Já estabelecido; simples; orientado ao macro.
- **Contras:** Não define disciplina para o micro (funcionalidade individual); agente pode inventar requisitos; testes podem não provar equivalência.

### Alternativa B: Adotar TLC Spec-Driven como substituição do framework

- **Prós:** Disciplina comprovada.
- **Contras:** É voltado para greenfield (construção), NÃO para migração de legado. Não contempla engenharia reversa, inventário, compatibilidade, nem equivalência com sistema existente. Abandonaríamos o desenho macro.

### Alternativa C: Framework de 10 fases (macro) + Spec-Driven (micro) — Híbrido

- **Prós:** O melhor dos dois mundos. O macro define o quê/quando; o micro define o como para cada funcionalidade. A disciplina Spec-Driven (auto-sizing, WHEN/THEN/SHALL, Verifier independente, memória) é aplicada dentro de cada funcionalidade da migração.
- **Contras:** Complexidade de combinar dois sistemas de processos; requer adaptação dos conceitos Spec-Driven para o contexto de migração (validação legado ↔ novo em vez de spec ↔ código).

## Decisão

> **Escolhemos a Alternativa C: Framework de 10 fases (macro) + Ciclo Spec-Driven (micro).**

### Como funcionará na prática:

1. **Escopo Macro:** O framework de 10 fases define a sequência geral (Preparação → Inventário → Engenharia Reversa → Domínio → Arquitetura → Estratégia → Compatibilidade → Implementação → Testes → Implantação).

2. **Escopo Micro:** Para cada funcionalidade individual do módulo de Frequência, aplicamos o ciclo:
   - **Specify:** Documentar o **comportamento real** do legado (from reverse engineering) em formato WHEN/THEN/SHALL, com IDs rastreáveis. Isso vira a `spec.md` da funcionalidade.
   - **Design:** Modelar a arquitetura DDD alvo para aquela funcionalidade (`design.md`).
   - **Tasks:** Quebrar em tasks atômicas com verificação (`tasks.md` + Test Coverage Matrix).
   - **Execute:** Implementar com testes que provam **equivalência de comportamento** com o legado, e ao final, o **Verifier** independente confirma.

3. **Verificação de Migração:** Em vez de validar "spec vs implementação", validamos "comportamento legado vs comportamento do novo sistema" para as mesmas entradas. Isso usa os testes de caracterização gerados durante a engenharia reversa.

### Estruura `.specs/` específica para migração:

```
docs/specs/
├── STATE.md                   # Decisões de migração + Handoff
└── features/
    └── [funcionalidade]/
        ├── spec.md            # Comportamento do legado (WHEN/THEN/SHALL) + IDs
        ├── context.md         # Decisões sobre regras ambíguas
        ├── design.md          # Arquitetura DDD alvo
        ├── tasks.md           # Tasks atômicas + Test Coverage Matrix
        └── validacao-migracao.md  # Verifier: legado vs novo
```

## Consequências

### Positivas

- Disciplina rigorosa para cada funcionalidade, reduzindo risco de invenção de requisitos.
- Rastreabilidade total: cada regra descoberta na engenharia reversa tem um ID que a conduz até a implementação e validação.
- Verificador independente garante equivalência real de comportamento, não apenas "o código compila".
- Modelo de memória (State + Handoff) reduz a perda de contexto entre sessões (essencial com o limite de 500k tokens).

### Negativas / Trade-offs

- **Custo de overhead:** O ciclo completo (Specify → Design → Tasks → Execute → Verify) para cada funcionalidade é mais burocrático que "implementar direto".
- **Curva de aprendizado:** A equipe precisa entender os dois processos e como eles se combinam.
- **Não é greenfield:** Precisamos adaptar os conceitos do TLC (que assume construção nova) para o contexto de migração (que assume réplica de comportamento existente).

### Neutras

- O TLC Spec-Driven já está bem documentado e testado; podemos reutilizar suas referências sem reinventá-las.
- A skill `reverse-engineer` já existente no projeto complementa a engenharia reversa.

## Compliance

- Todo trabalho de implementação de uma funcionalidade deve seguir o ciclo Spec-Driven.
- Os arquivos em `docs/specs/features/` são a fonte oficial de conhecimento para cada funcionalidade.
- Nenhuma regra de negócio deve ser implementada sem primeiro estar documentada na `spec.md` com evidência do código legado.

## Notas

- Fonte: TLC Spec-Driven v3.2.0 — https://github.com/tech-leads-club/agent-skills/tree/main/packages/skills-catalog/skills/(development)/tlc-spec-driven
- Licença: CC-BY-4.0 (atribuição ao Tech Leads Club).
- Próximo passo: criar o template `spec.md` de migração adaptado ao contexto de engenharia reversa.
