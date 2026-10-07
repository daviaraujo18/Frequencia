# frozen_string_literal: true

# Tarefa 30.10 (Sprint 30, frente 5) — garante o `User` local dos gestores de
# unidade a partir do Pessoas (furo dos gestores sem lotação vigente).
#
#   bin/rails frequencia:importar_gestores_unidade
#   DRY_RUN=1 bin/rails frequencia:importar_gestores_unidade
#
# A lógica vive em `ImportarGestoresDeUnidadeService` (testável sem tocar o
# Pessoas); aqui fica só a borda operacional: ler `DRY_RUN`, chamar o serviço e
# imprimir o relatório. Reexecutar é seguro ("2ª execução = 0 criações") — a
# criação é idempotente por CPF. `DRY_RUN=1` percorre o mesmo caminho sem
# escrever — é o modo de conferência recomendado antes da execução real.
namespace :frequencia do
  desc "Garante (idempotente) o User local dos gestores de unidade (Pessoas). DRY_RUN=1 simula sem escrever."
  task importar_gestores_unidade: :environment do
    dry_run = ENV["DRY_RUN"] == "1"

    resultado = ImportarGestoresDeUnidadeService.call(dry_run: dry_run)

    puts resultado.resumo

    # Padrão S2 (mesmo do frequencia:migrar_roles_cascata): falha de LEITURA do
    # Pessoas é distinta de "não há gestores". Aborta com exit != 0 MESMO em
    # DRY_RUN — um dry-run que não conseguiu ler a fonte não é conferência
    # válida nem uma importação silenciosamente vazia.
    if resultado.falha_leitura
      abort "FALHA DE LEITURA do Pessoas — nenhum gestor lido; a garantia do User local NÃO foi executada. Ver o log."
    end

    # Sinal honesto para scripts/encadeamento: uma execução REAL com erros
    # (exceções, ex.: colisão de username) não deve sair com status de sucesso.
    # Em DRY_RUN o exit code permanece 0: "achar pendências" é o esperado dele.
    if resultado.erros.positive? && !resultado.dry_run
      abort "Importação concluída com erros — ver relatório acima."
    end
  end
end
