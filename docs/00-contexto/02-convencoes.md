# Convenções de Documentação

> **[⌂ Home](../README.md)**

## Estrutura de Arquivos

```
docs/
├── 00-contexto/           # Visão geral, framework, convenções
├── 01-inventario/         # Mapeamento do legado (classes, tabelas, etc.)
├── 02-arquitetura/        # Arquitetura do novo sistema
├── 03-dominio/            # DDD, bounded contexts, agregados, eventos
├── 04-decisoes/           # Decisões técnicas (atalho para ADRs)
├── 05-migracao/           # Estratégia e plano de migração
├── 06-integracoes/        # Integrações entre sistemas
├── 07-estacao-ponto/      # Tudo sobre a EstaçãoPonto
├── 08-pessoas/            # Tudo sobre o sistema Pessoas
├── 09-intranet/           # Tudo sobre o sistema Intranet (legado)
├── 10-testes/             # Estratégia e planos de teste
├── 11-deploy/             # CI/CD, implantação, monitoramento
└── adr/                   # Architecture Decision Records
```

## Formato dos Documentos

### Cabeçalho Obrigatório

Todo documento deve começar com:

```markdown
# Título Descritivo

## Propósito
[Uma frase explicando por que este documento existe.]
```

### Metadados (opcional, no final)

```markdown
---
**Autor:** [Nome]
**Data:** [YYYY-MM-DD]
**Revisão:** [Número]
**Última atualização:** [YYYY-MM-DD]
**Referências:** [Links para documentos relacionados]
---
```

## Marcadores Especiais

Use estes marcadores para sinalizar informações importantes:

| Marcador | Significado | Exemplo |
|----------|------------|---------|
| `PENDÊNCIA:` | Algo não resolvido, precisa de investigação | `PENDÊNCIA: Não encontrei a procedure que calcula horas noturnas.` |
| `DECISÃO:` | Uma decisão tomada (referenciar ADR se existir) | `DECISÃO: Usaremos API REST síncrona para consulta de servidores (ver ADR-0001).` |
| `APRENDIZADO:` | Algo descoberto durante o processo | `APRENDIZADO: A procedure sp_calcula_horas é chamada por um job noturno, não por trigger.` |
| `EVIDÊNCIA:` | Referência a código-fonte que comprova uma afirmação | `EVIDÊNCIA: /intranet/src/FrequenciaService.java:42` |
| `⚠️ RISCO:` | Algo que pode dar errado | `⚠️ RISCO: A tabela batidas tem 12 milhões de registros. Migração de dados precisa de janela.` |
| `🤔 DÚVIDA:` | Questão em aberto que precisa ser respondida | `🤔 DÚVIDA: O campo flag_compensado na tabela banco_horas é calculado ou manual?` |

## Nomenclatura de Arquivos

- Usar `kebab-case`: `00-visao-geral.md`, `fluxo-batida.md`
- Prefixo numérico de 2 dígitos para ordenação: `00`, `01`, `02`, etc.
- Evitar acentos e caracteres especiais no nome do arquivo.

## Como Registrar uma Descoberta

Ao finalizar uma sessão de análise:

1. Atualize ou crie o arquivo Markdown relevante.
2. Inclua **Descobertas**, **Evidências**, **Impacto**, **Riscos** e **Próximos passos**.
3. Liste os **Arquivos alterados** no final da resposta.
4. Liste **Pendências** que ficaram em aberto.

## Como Criar um ADR

Quando uma decisão arquitetural precisa ser tomada:

1. Copie o template de `docs/adr/0000-template.md`.
2. Nomeie como `docs/adr/NNNN-titulo-curto.md`.
3. Preencha o template.
4. Se a decisão substituir outra, atualize o ADR antigo.
5. Referencie o ADR nos documentos relevantes com `(ver ADR-NNNN)`.
