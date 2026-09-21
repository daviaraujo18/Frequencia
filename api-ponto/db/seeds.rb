# db/seeds.rb — contas base e dados de demonstração do Frequencia.
#
# Sprint 23, task 23.9 — MIGRAÇÃO dos seeds para o modelo de
# auth/autorização (Devise + CanCanCan + Rolify). Decisões registradas:
#
# 1) CONTA ADMIN CANÔNICA POR `username`: o seed antigo localizava o admin por
#    `nome_completo: "Admin Admin"`, que NÃO casa com o admin legado
#    (`nome_completo: "Admin"`) — cada execução criava uma conta duplicada
#    (`admin.admin.2`) e a role `admin` ia para a duplicata, deixando o admin
#    REAL sem role. Agora a localização é pelo username estável `admin.admin`.
# 2) CREDENCIAL DEVISE (dual-write): contas locais criadas ANTES do Devise
#    (tasks 23.1/23.3) têm `password_digest` mas `encrypted_password` vazio.
#    Como bcrypt é unidirecional, não há como derivar o hash Devise do digest
#    legado. Para as contas SEEDADAS, quando `encrypted_password` está vazio o
#    seed regrava a senha padrão (dual-write da 23.3), reativando o login via
#    Devise. O backfill é conservador: NUNCA sobrescreve `encrypted_password`
#    já existente (credencial Devise válida é preservada).
# 3) `admin` (coluna boolean legada) × role Rolify `:admin`: a conta admin
#    recebe AMBOS (`admin = true` + role `:admin`), porque views e controllers
#    ainda ramificam em `current_user.admin?` (layouts/admin, time_records,
#    dashboard) enquanto a Ability (task 23.5) aceita a role OU a coluna.
# 4) PESSOAS2 (base integrante): os seeds tocam SOMENTE o banco local. A
#    conexão `pessoas` é somente-leitura (SELECT-only — ver PessoasRecord) e os
#    usuários do Pessoas2 são espelhados por outros fluxos; criar/alterar
#    credencial lá está fora do escopo (e seria bloqueado pelo grant).
# 5) CONTAS ATIVAS: os seeds criam/garantem apenas contas ativas (o default
#    `status: 1` do schema é preservado). Não há criação de inativos, e um
#    usuário existente inativado NÃO é reativado pelo seed.
#
# Sprint 23, task 23.9 — DECISÃO: `status: 1` NÃO foi migrado para Devise
# `confirmed_at`. Investigado antes de decidir:
#   - O model `User` (app/models/user.rb) habilita apenas
#     `:database_authenticatable, :registerable, :recoverable, :rememberable,
#     :validatable, :trackable` — o módulo `:confirmable` NÃO está na lista.
#   - Não existe coluna `confirmed_at` no schema (`db/schema.rb`) nem na
#     migration `20260910000000_add_devise_to_users.rb` (task 23.1), que é
#     explicitamente aditiva e documenta as colunas criadas — `confirmed_at`
#     não é uma delas.
#   - `status` continua sendo o mecanismo REAL de "ativo/inativo": usado no
#     scope `User.ativos` (`where(status: 1)`) e em
#     `active_for_authentication?` (`super && status == 1`, task 23.6), que é
#     o guard efetivo de login via Devise. Migrar/duplicar esse sinal para
#     `confirmed_at` sem o módulo `:confirmable` ativo não teria efeito algum
#     no fluxo de autenticação (Devise só verifica `confirmed_at` quando
#     `:confirmable` está incluso) — seria apenas uma coluna inerte, e
#     arriscaria (se `:confirmable` fosse ativado no futuro sem migração de
#     dados correspondente) bloquear login de usuários existentes com
#     `status: 1` mas `confirmed_at: nil`.
# Conclusão: manter `status` como fonte de verdade de "ativo" (sem alteração
# nesta task). Se o produto decidir adotar confirmação de e-mail via Devise
# no futuro, isso exige uma nova migration (`add_confirmable_to_users` com
# `confirmed_at`/`confirmation_token`/etc.), habilitar `:confirmable` no
# model, e um plano explícito de backfill de `confirmed_at` a partir de
# `status: 1` — decisão arquitetural fora do escopo desta task (seeds).

default_password = "123456"

# Roles padrão do sistema (task 23.4). Criadas antes dos usuários para que
# possam ser atribuídas logo abaixo. `find_or_create_by!` mantém a
# idempotência (roles já existentes são reaproveitadas).
%w[admin gestor operador].each { |name| Role.find_or_create_by!(name: name) }

puts "Roles disponíveis: #{Role.order(:name).pluck(:name).join(', ')}"

# Helper local do seed. Localiza a conta pelo `username` estável (não pelo
# nome), cria se não existir e só (re)grava a senha quando a credencial Devise
# ainda não existe (ver decisão 2 no topo). É um lambda para não definir um
# método global no carregamento dos seeds.
seed_user = lambda do |username:, nome_completo:, admin: false, digitais_hash: nil|
  user = User.find_or_initialize_by(username: username)

  # Só completa o nome quando ausente — não renomeia contas já existentes.
  user.nome_completo = nome_completo if user.nome_completo.blank?
  user.admin = admin
  user.digitais_hash = digitais_hash if digitais_hash.present? && user.digitais_hash.blank?

  # Backfill conservador: cria a credencial Devise quando ainda não existe.
  user.password = default_password if user.new_record? || user.encrypted_password.blank?

  user.save!
  user
end

# Conta admin canônica (username: admin.admin). Recebe role `:admin` E a
# coluna boolean `admin = true` (decisão 3).
admin_user = seed_user.call(username: "admin.admin", nome_completo: "Admin Admin", admin: true)

# Contas de demonstração de autorização (roles gestor/operador). Não são
# admins; a role é atribuída logo abaixo.
gestor_user = seed_user.call(username: "gestor.demo", nome_completo: "Gestor Demo")
operador_user = seed_user.call(username: "operador.demo", nome_completo: "Operador Demo")

# Usuários de demonstração de frequência (biometria).
joao = seed_user.call(
  username: "joao.biometrico",
  nome_completo: "João Biométrico",
  digitais_hash: "FIR_TEXTENCODE_SAMPLE_HASH_1234567890"
)
maria = seed_user.call(
  username: "maria.santos",
  nome_completo: "Maria Santos",
  digitais_hash: "FIR_TEXTENCODE_MARIA_HASH_0987654321"
)
carlos = seed_user.call(username: "carlos.pereira", nome_completo: "Carlos Pereira")

# Atribuição idempotente das roles (task 23.4). `add_role` já é idempotente,
# mas o guard evita query/escrita desnecessária e deixa a intenção explícita.
[ [ admin_user, :admin ], [ gestor_user, :gestor ], [ operador_user, :operador ] ].each do |user, role|
  next if user.has_role?(role)

  user.add_role(role)
  puts "Role '#{role}' atribuída ao usuário #{user.username}"
end

# Registros de ponto falsos para demonstração.
if TimeRecord.count.zero?
  agora = Time.current

  # Batidas de hoje.
  [ [ joao, "biometric" ], [ maria, "biometric" ], [ carlos, "manual" ] ].each do |user, mode|
    TimeRecord.create!(
      user: user,
      raw_data: "#{user.id}-#{agora.strftime("%d:%m:%Y:%H:%M:%S")}",
      punched_at: agora - rand(1..8).hours,
      authentication_mode: mode
    )
  end

  # Batidas de dias anteriores.
  [ 1, 2, 3, 5, 7 ].each do |day_ago|
    [ joao, maria ].each do |user|
      t = agora - day_ago.days - rand(4..10).hours
      TimeRecord.create!(
        user: user,
        raw_data: "#{user.id}-#{t.strftime("%d:%m:%Y:%H:%M:%S")}",
        punched_at: t,
        authentication_mode: "biometric"
      )
    end
  end
end
