# Garante o `User` local a partir de uma pessoa lida no Pessoas — colaborador
# COMPARTILHADO pela importação por lotação (`ImportarServidoresUnidadeJob`) e
# pela importação de gestores de unidade (`ImportarGestoresDeUnidadeService`).
#
# Tarefa 30.10 (Sprint 30): extração MÍNIMA da regra de criação do `User` local
# (antes privada em `ImportarServidoresUnidadeJob#criar_user_se_necessario`)
# para que os dois caminhos de importação NÃO dupliquem a regra. Comportamento
# externo do job preservado.
#
# Decisões de campo (movidas do job, sem mudança de semântica):
# - password: aleatória/inutilizável (`SecureRandom.hex(16)`) — ninguém a
#   conhece, é só um placeholder para satisfazer `has_secure_password`. Login
#   por senha de conta com `cpf` passa pela senha REAL do Pessoas2 (ver
#   `User#authenticate`); a biometria não depende de senha.
# - username: usa o `username` real da tabela `pessoas` (`pessoa.username`); só
#   cai no `generate_username` local (callback do model) quando o Pessoas não
#   tem username preenchido — e só na criação.
# - status: usa o default do schema (`status: 1`, ativo) — não setado aqui de
#   propósito, para não duplicar a regra do banco/model.
#
# NÃO atualiza o `FrequentadorCache`: cada chamador decide o momento.
#   - o job por lotação chama `AtualizarFrequentadorCacheService` SEMPRE (como
#     antes), inclusive quando o `User` já existia;
#   - a importação de gestores chama o cache SÓ quando cria o `User` — assim a
#     "2ª execução = 0 escritas" fica honesta (não há escrita em conta que já
#     existia).
#
# Retorna `true` quando criou o `User` e `false` quando ele já existia (por
# CPF). Nunca sobrescreve um `User` existente (nem nome nem username).
class GarantirUserLocalService
  def self.call(cpf:, pessoa:)
    user = User.find_or_initialize_by(cpf: cpf)
    return false unless user.new_record?

    user.nome_completo = pessoa.nome
    user.username = pessoa.username if pessoa.username.present?
    user.password = SecureRandom.hex(16)
    user.save!
    true
  end
end
