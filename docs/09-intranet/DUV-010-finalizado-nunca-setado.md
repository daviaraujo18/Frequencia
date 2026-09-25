# DUV-010 — `finalizado` do RegistroMensalFrequencia nunca é setado `true`

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

O campo `finalizado` (boolean) de `beans/RegistroMensalFrequencia.java` tem a intenção documentada nos comentários (l.76-79): "após rodar o algoritmo de desconto em folha, todos são finalizados = true e só podem ser alterados via retificadores".

**Porém** `setFinalizado` **nunca é chamado** em lugar nenhum do código (busca retornou apenas a definição no bean). Consequência prática:

- O guard `if (rmf == null || !rmf.isFinalizado())` em `CalculoDiarioServiceV2` (l.69) e `CalculoDiarioService` v1 (l.114) está **sempre verdadeiro**;
- → meses **sempre recalculáveis**; o mecanismo de "lock" de fechamento **nunca é efetivado** via essa flag.

## Origem

- `docs/01-inventario/05-banco-horas-fechamento.md` (AMBIG-001)

## Por que importa

Regra de negócio de fechamento: como o mês fica "fechado" na prática? Se via `finalizado`, falta o código que o seta; se por convenção via desconto em folha, precisamos entender. Impacta a correção do fluxo de fechamento no novo sistema.

## Hipóteses

1. A flag é setada por um processo externo/folha não encontrado nesta busca.
2. O controle é feito por outra coluna/regra (ex. validação de data no relatório final).
3. O mecanismo de lock simplesmente não existe efetivamente no legado.

## Como Resolver

- [ ] Investigar onde/quando um `RegistroMensalFrequencia` deve ser considerado fechado.
- [ ] Verificar o fluxo de "desconto em folha" que o comentário menciona.
- [ ] Definir o mecanismo de fechamento correto no novo sistema.

## Resolução

**Resolvida por inspeção exaustiva do código (2026-08-05).**

### Confirmado (lado Java)

1. **Comentário de intenção:** `beans/RegistroMensalFrequencia.java` linhas 76-78:
   ```java
   // apos rodar o algoritmo de desconto em folha definir todos os registros mensais como finalizado = true
   // para que nao possa mais ser recalculado
   // modificacoes passadas devem ser feitas utilizando retificadores
   ```
   Campo `private boolean finalizado;` (l.79); getter `isFinalizado()` (l.312) e setter `setFinalizado(boolean)` (l.316). Inicializado `false` no construtor (l.87).
2. **`setFinalizado(...)` NUNCA é chamado** em lugar nenhum do `src/` (a única ocorrência é a definição no bean, l.316).
3. **`isFinalizado()` é usado** somente em:
   - `services/calculo/v2/CalculoDiarioServiceV2.java:69` → `if (rmf == null || !rmf.isFinalizado()) {`
   - `services/calculo/CalculoDiarioService.java:114` (v1) → idem.

→ Como o setter nunca é chamado, `finalizado` é `false` para sempre em produção, e o guard `if (rmf == null || !rmf.isFinalizado())` é **sempre verdadeiro** → os meses **permanecem sempre recalculáveis** e o "lock" previsto no comentário **nunca é efetivado** por essa flag.

> Observação: `modules/tjpi/beans/concurso/Concurso.java:184` também tem um `isFinalizado()` — é um **homônimo** de outra classe (bean de concurso do módulo tjpi), sem relação com o `RegistroMensalFrequencia`.

### Conclusão / decisão para a migração

- **Hipótese 3 confirmada (efetivamente):** o mecanismo de lock via `finalizado` **não opera no legado** — a flag existe e é checada, mas nunca é acionada. O "fechamento de mês" **não é garantido** por essa flag no código.
- **Como o mês efetivamente "fecha" na prática?** A inspeção no código do módulo **não encontrou** outro mecanismo de lock explícito. Isso sugere que: ou o fechamento real acontece por processo externo de folha (fora deste repositório/folha separada), ou simplesmente não há trava no legado.
- **Recomendação para o novo sistema:** implementar um **mecanismo explícito de fechamento de mês** (estado `fechado`) que seja de fato setado (ex.: após o cálculo de desconto em folha, um job marca registros do mês como fechados e bloqueia recálculo, permitindo só retificadores). Confirmar com o time de folha se o fechamento é feito hoje por processo externo.

> ⚠️ **Limite da resolução:** confirmar se um processo externo de folha seta `finalizado` via SQL direto no banco (fora do Java) exige investigação junto à equipe de folha/dados.
