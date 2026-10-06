# frozen_string_literal: true

# Tarefa 30.9b (Sprint 30) — migração 1:1 das 2 roles da cascata a partir do
# Intranet legado (ruling D-6 = (i), dev 2026-10-06).
#
#   bin/rails frequencia:migrar_roles_cascata
#   DRY_RUN=1 bin/rails frequencia:migrar_roles_cascata
#
# A lógica vive em `Intranet::MigrarRolesCascataService` (testável sem tocar a
# rede); aqui fica só a borda operacional: ler `DRY_RUN`, chamar o serviço e
# imprimir o relatório. Reexecutar é seguro ("segunda execução = 0 criações") —
# a atribuição é idempotente (checagem `has_role?` + `add_role`).
#
# `DRY_RUN=1` percorre o mesmo caminho de resolução, mas não escreve nada — é o
# modo de conferência recomendado antes da primeira execução real.
namespace :frequencia do
  desc "Migra (1:1, idempotente) as 2 roles da cascata do Intranet. DRY_RUN=1 simula sem escrever."
  task migrar_roles_cascata: :environment do
    dry_run = ENV["DRY_RUN"] == "1"

    resultado = Intranet::MigrarRolesCascataService.call(dry_run: dry_run)

    puts resultado.resumo

    # S2: falha de LEITURA do legado é distinta de "nada a migrar". Aborta com
    # exit != 0 MESMO em DRY_RUN — um dry-run que não conseguiu ler a fonte não
    # é uma conferência válida nem uma migração silenciosamente vazia.
    if resultado.falha_leitura
      abort "FALHA DE LEITURA do legado — nenhuma atribuição lida; a migração NÃO foi executada. Ver o log."
    end

    # Sinal honesto para scripts/encadeamento: uma execução REAL com pendências
    # não deve sair com status de sucesso. Em DRY_RUN o exit code permanece 0:
    # "achar pendências" é o resultado esperado dele.
    #
    # Q11 (dev, 2026-10-06): o gatilho de não-resolvidos é um LIMIAR (>10%),
    # não "qualquer um". Um punhado de logins legítimos sem `User` local (ex.:
    # desligados) não deve bloquear a migração; >10% é sinal de eixo de
    # casamento errado e aborta. Erros (exceções) seguem abortando sempre.
    if (resultado.abortar_por_nao_resolvidos? || resultado.erros.positive?) && !resultado.dry_run
      abort "Migração concluída com pendências — ver relatório acima."
    end
  end
end
