# Visão Geral do Projeto de Migração

> **[⌂ Home](../README.md)**

## Propósito

Este documento é a **fonte oficial de conhecimento** do processo de migração do módulo de **Frequência** do sistema legado **Intranet (Java 6 + MySQL 5)** para o novo sistema **Frequência (Ruby on Rails)**.

## Sistemas Envolvidos

| Sistema | Tecnologia | Estado | Função |
|---------|-----------|--------|--------|
| **Intranet** | Java 6 + MySQL 5 | Legado (a ser descontinuado) | Módulo de RH completo, incluindo Frequência |
| **Pessoas** | Ruby on Rails | Novo (ativo) | Dados cadastrais dos servidores |
| **EstaçãoPonto** | Desktop (desconhecido) | Legado (a ser adaptado) | Captura biométrica e envio de batidas |
| **Frequência** | Ruby on Rails | Novo (a ser criado) | Processamento completo de frequência |

## Objetivo Arquitetural

```
Pessoas (fonte de dados cadastrais)
    ↓ (API/Eventos)
Frequência (autoridade das regras de ponto)
    ↓ (API compatível)
EstaçãoPonto (envio de batidas)
```

Após a migração:
- **Intranet** será desligada.
- **EstaçãoPonto** sofrerá o mínimo de alterações (idealmente apenas endpoint).
- **Frequência** será a autoridade máxima em regras de ponto eletrônico.

## Restrições Fundamentais

1. **Não alterar regras de negócio sem evidências.** Nunca assumir comportamento. Sempre localizar no código.
2. **Toda regra encontrada deve ser documentada.** Toda descoberta registrada em Markdown.
3. **Não consumir contexto desnecessariamente.** Sempre reutilizar documentação entre sessões.
4. **Nunca gerar código antes de entender completamente o comportamento.**
5. **Cada funcionalidade passa por:** descoberta → documentação → validação → modelagem → implementação → testes → migração.

## Limite de Contexto

Trabalhamos com um limite aproximado de **500 mil tokens de contexto** no OpenCode. Os arquivos Markdown são a fonte oficial de conhecimento — nunca depender apenas do contexto da conversa.

## Convenções

- Arquivos Markdown em português (idioma do time).
- ADRs em formato padronizado (Problema, Alternativas, Decisão, Consequências).
- Um diretório por fase/grupo de conhecimento.
- `PENDÊNCIA:` marca itens não resolvidos.
- `DECISÃO:` marca decisões arquiteturais registradas.
- `APRENDIZADO:` marca lições aprendidas.
