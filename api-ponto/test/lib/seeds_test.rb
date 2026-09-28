require "test_helper"

# Sprint 23, task 23.9 — cobre a migração dos seeds para o modelo de
# auth/autorização (Devise + CanCanCan + Rolify): idempotência, contas/roles
# seedadas e credencial Devise válida (dual-write da task 23.3).
#
# O seed é carregado com `load` dentro do teste transacional — as mudanças
# (usuários, roles, batidas) sofrem rollback ao final de cada caso, sem
# poluir o banco de teste.
class SeedsTest < ActiveSupport::TestCase
  SEEDS_PATH = Rails.root.join("db/seeds.rb")

  test "seed e idempotente: segunda execucao nao cria usuarios, roles nem batidas" do
    load_seeds

    assert_no_difference([ "User.count", "Role.count", "TimeRecord.count" ]) do
      load_seeds
    end
  end

  test "cria a conta admin canonica com role Rolify e coluna boolean admin" do
    load_seeds

    admin = User.find_by(username: "admin.admin")
    assert admin.present?, "conta admin.admin deve existir"
    assert admin.admin?, "admin deve ter a coluna boolean admin = true"
    assert admin.has_role?(:admin), "admin deve ter a role Rolify :admin"
  end

  test "reaproveita a conta admin existente sem criar duplicata" do
    existing = User.create!(username: "admin.admin", nome_completo: "Admin", password: "123456", admin: true)

    load_seeds

    assert_equal 1, User.where(username: "admin.admin").count
    assert_equal existing.id, User.find_by(username: "admin.admin").id
  end

  test "nao sobrescreve credencial Devise ja existente da conta admin" do
    existing = User.create!(
      username: "admin.admin",
      nome_completo: "Admin",
      password: "senha-customizada",
      admin: true
    )

    load_seeds

    assert existing.reload.valid_password?("senha-customizada"),
           "seed nao deve resetar a senha de uma conta com credencial Devise valida"
  end

  test "faz backfill da credencial Devise de conta legada sem encrypted_password" do
    legacy = User.create!(username: "admin.admin", nome_completo: "Admin", password: "123456", admin: true)
    # Simula conta criada antes do Devise (task 23.3): só password_digest.
    legacy.update_column(:encrypted_password, "")
    refute legacy.reload.valid_password?("123456"), "pre-condicao: sem encrypted_password nao autentica via Devise"

    load_seeds

    assert legacy.reload.encrypted_password.present?, "seed deve preencher a credencial Devise ausente"
    assert legacy.valid_password?("123456"), "conta legada volta a autenticar via Devise"
    assert legacy.authenticate("123456"), "autenticacao local (has_secure_password) permanece"
  end

  test "atribui as roles gestor e operador as contas de demonstracao" do
    load_seeds

    gestor = User.find_by(username: "gestor.demo")
    operador = User.find_by(username: "operador.demo")

    assert gestor.has_role?(:gestor)
    assert operador.has_role?(:operador)
    refute gestor.admin?, "gestor de demonstracao nao e admin"
    refute operador.admin?, "operador de demonstracao nao e admin"
  end

  test "contas seedadas tem credencial valida por Devise e por autenticacao local" do
    load_seeds

    User.where(username: %w[admin.admin gestor.demo operador.demo]).find_each do |user|
      assert user.password_digest.present?, "#{user.username}: password_digest (local) ausente"
      assert user.encrypted_password.present?, "#{user.username}: encrypted_password (Devise) ausente"
      assert user.valid_password?("123456"), "#{user.username}: nao autentica via Devise"
      assert user.authenticate("123456"), "#{user.username}: nao autentica localmente"
    end
  end

  test "nao cria contas com cpf: seeds tocam apenas o banco local" do
    load_seeds

    seeded = User.where(username: %w[admin.admin gestor.demo operador.demo joao.biometrico maria.santos carlos.pereira])
    assert_equal 0, seeded.where.not(cpf: nil).count,
                 "seeds nao devem criar credenciais de Pessoas2 (base integrante e somente-leitura)"
  end

  private

  # Silencia o `puts` dos seeds para manter a saída da suíte limpa.
  def load_seeds
    capture_io { load SEEDS_PATH }
  end
end
