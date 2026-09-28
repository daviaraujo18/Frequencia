# DUV-011 — Bug `cont=+valor.getNumeroHora()` (deveria ser `+=`) — soma corrompida

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

Em `services/RelatorioFrequenciaFinalServices.java:142`, dentro de `calcularValorRetroativo`:

```java
cont=+valor.getNumeroHora();
```

O operador usado é **atribuição** `=` em vez de **acumulação** `+=`. Com múltiplos valores retroativos (mais de um registro para o frequentador/mês), o contador **é sobrescrito** a cada iteração em vez de somado, corrompendo o total de valor retroativo.

## Origem

- `docs/01-inventario/05-banco-horas-fechamento.md` (BUG-001)

## Por que importa

Impacta diretamente o **resultado financeiro/cálculo de valor retroativo** no relatório final de frequência. Correção trivial no código, mas precisa ser validada contra o comportamento esperado.

## Como Resolver

- [ ] Confirmar que deve ser `cont += valor.getNumeroHora()`.
- [ ] Validar o comportamento correto esperado de valor retroativo com o negócio.
- [ ] Corrigir na migração (não reproduzir o bug).

## Resolução

**Resolvida por inspeção direta do código — BUG CONFIRMADO (2026-08-05).**

### Confirmado no código-fonte

`services/RelatorioFrequenciaFinalServices.java`, método `calcularValorRetroativo` (linhas 128-149):

```java
private static int calcularValorRetroativo(Frequentador frequentador, int mes, int ano) {
    List<ValorRetroativo> valores =  ValorRetroativoDao.getByMesAno(frequentador,mes,ano);
    if (valores.size()==1){
        return valores.get(0).getNumeroHora();
    }
    if (valores.size()>1){
        int cont =0;
        for (ValorRetroativo valor: valores){
            Calendar dataGeracao = valor.getDataGeracao();
            int mesDoValor = dataGeracao.get(Calendar.MONTH) + 1;
            if (mesDoValor == mes){
                cont=+valor.getNumeroHora();   // ← linha 142: BUG (deveria ser +=)
            }
        }
        return cont;
    }
    return 0;
}
```

**Bug confirmado:** linha 142 usa `cont=+valor.getNumeroHora();` (atribuição `=` + unário `+`) em vez de `cont += valor.getNumeroHora();`.

### Impacto

- Com **um único** `ValorRetroativo` (`valores.size()==1`), o resultado é correto (retorno direto na linha 133).
- Com **múltiplos** valores retroativos (`valores.size()>1`) para o mesmo frequentador/mês, `cont` é **sobrescrito** a cada iteração (mantém apenas o último valor do mês) em vez de **acumulado** → o total de valor retroativo fica **incorreto**.
- Na prática, `cont=+x` equivale a `cont = (+x)` = `cont = x`, ou seja, **sempre retorna o último registro** em vez da soma.

### Decisão para a migração

- **Corrigir** na migração para `cont += valor.getNumeroHora();` **(não reproduzir o bug)**.
- Registrar como bug conhecido do legado; se for necessário reproduzir o relatório histórico exatamente como era, validar com o negócio se o "bug" deve ser corrigido retroativamente (valores históricos foram afetados) ou se o relatório final sempre teve 0-1 valores por frequentador/mês (caso em que o bug nunca disparava).
- Adicionar teste de regressão no Frequência cobrindo múltiplos valores retroativos no mesmo mês.
