# DUV-009 — `DebitoRemanescenteNegociado` é código morto (referencia módulo aproc)

> **[⟰ Voltar ao Índice](00-indice-modulo-presenca.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-05) — ver `## Resolução`

## Dúvida

O bean `beans/DebitoRemanescenteNegociado.java` (tabela `presenca_debitoremanscentenegociavel`) referencia o módulo **`aproc`** (`import modules.aproc.beans.Manifestacao`, l.11/26-27) e `RegistroMensalFrequencia`.

Busca no `src/` inteiro: retorna **apenas** ocorrências no próprio bean. **Não há DAO dedicado, nem ação/serviço utilizador.** O `ModuleManager.java` **não o registra** (grep por "debito" no ModuleManager vazio).

→ **Entidade/entidade morta**; a tabela existe mas é legado/órfã.

## Origem

- `docs/01-inventario/05-banco-horas-fechamento.md` (DIVERG-004 / DEAD-CODE-001)
- Confirma a suspeita preexistente de que `Manifestacao` (módulo aproc) está morto.

## Por que importa

Decidir se **ignora/remove** na migração. Também confirma que o módulo `aproc` pode ser tratado como inativo.

## Como Resolver

- [ ] Confirmar com o time que a funcionalidade de "débito remanescente negociado" não é mais utilizada.
- [ ] Remover/ignorar na migração (não criar tabela/model no Frequência).

## Resolução

**Resolvida por inspeção exaustiva do código (2026-08-05).**

### Confirmado (lado Java)

1. **Bean:** `beans/DebitoRemanescenteNegociado.java` (linha 19) mapeia `@Table(name = "presenca_debitoremanscentenegociavel")` e referencia o módulo `aproc`:
   - linha 11: `import modules.aproc.beans.Manifestacao;`
   - linha 27: `private Manifestacao manifestacao;`
   - Construtor (l.39) e getter/setter (l.46/50) de `Manifestacao`.
2. **Não há utilização:** busca em todo `src/` por `DebitoRemanescenteNegociado` retorna **apenas** o próprio bean (linhas 20, 36, 39). **Nenhum** DAO, serviço, ação, schema ou installer o referencia.
3. **`ModuleManager.java`** (módulo presenca) **não** registra nada com "debito"/`DebitoRemanescente` (busca vazia).

→ **Entidade completamente órfã/código morto.** A tabela existe no banco mas nenhum código a opera. Confirma também que o módulo `aproc` (`Manifestacao`) está inativo/morto.

### Decisão para a migração

- **Não portar** a entidade `DebitoRemanescenteNegociado` nem criar a tabela `presenca_debitoremanscentenegociavel` no Frequência.
- Tratar o **módulo `aproc` como inativo** (não migrar).
- Confirmação prévia com o time (negócio): garantir que a funcionalidade de "débito remanescente negociado" não é mais usada. Evidência de código fortemente sugere que não.
