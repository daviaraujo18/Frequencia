require "test_helper"

class UserTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid with nome_completo, username and password" do
    user = User.new(nome_completo: "Novo Usuario", username: "novo.usuario", password: "123456")
    assert user.valid?
  end

  test "invalid without nome_completo" do
    user = User.new(username: "sem.nome", password: "123456")
    assert_not user.valid?
    assert_includes user.errors[:nome_completo], "não pode ficar em branco"
  end

  test "invalid without username" do
    user = User.new(nome_completo: "Sem Username", username: nil, password: "123456")
    user.define_singleton_method(:generate_username) { } # impede a geração automática
    assert_not user.valid?
    assert_includes user.errors[:username], "não pode ficar em branco"
  end

  test "invalid with duplicated username (case insensitive)" do
    existing = users(:one)
    user = User.new(nome_completo: "Duplicado", username: existing.username.upcase, password: "123456")
    assert_not user.valid?
    assert_includes user.errors[:username], "já está em uso"
  end

  test "invalid without status" do
    user = User.new(nome_completo: "Sem Status", password: "123456")
    user.status = nil
    assert_not user.valid?
    assert_includes user.errors[:status], "não pode ficar em branco"
  end

  test "invalid with password shorter than 6 characters" do
    user = User.new(nome_completo: "Senha Curta", password: "123")
    assert_not user.valid?
    assert_includes user.errors[:password], "é muito curto (mínimo: 6 caracteres)"
  end

  test "valid without password when updating existing record" do
    user = users(:one)
    user.nome_completo = "Usuario Teste Um Atualizado"
    assert user.valid?
  end

  # --- generate_username callback ---

  test "generates username automatically from nome_completo when blank" do
    user = User.create!(nome_completo: "Fulano de Tal", password: "123456")
    assert_equal "fulano.tal", user.username
  end

  test "does not overwrite username when already present" do
    user = User.create!(nome_completo: "Ciclano", username: "usuario.manual", password: "123456")
    assert_equal "usuario.manual", user.username
  end

  test "generates unique username when there is a collision" do
    User.create!(nome_completo: "Fulano de Tal", password: "123456")
    outro = User.create!(nome_completo: "Fulano de Tal", password: "123456")
    assert_equal "fulano.tal.2", outro.username
  end

  # --- has_secure_password ---

  test "authenticates with correct password" do
    user = users(:one)
    assert user.authenticate("123456")
  end

  test "does not authenticate with incorrect password" do
    user = users(:one)
    assert_not user.authenticate("senha-errada")
  end

  # --- Scopes ---

  test "scope ativos returns only users with status 1" do
    inativo = User.create!(nome_completo: "Usuario Inativo", password: "123456", status: 0)
    assert_includes User.ativos, users(:one)
    assert_not_includes User.ativos, inativo
  end

  test "scope com_digitais returns only users with digitais_hash present" do
    com_digital = User.create!(nome_completo: "Com Digital", password: "123456", digitais_hash: "HASH123")
    assert_includes User.com_digitais, com_digital
    assert_not_includes User.com_digitais, users(:one)
  end

  # --- Associations ---

  test "has many time_records via TimeRecord#user association" do
    user = users(:one)
    record = TimeRecord.create!(
      user: user,
      raw_data: "raw",
      punched_at: Time.zone.now,
      authentication_mode: "biometric"
    )
    assert_equal user, record.user
  end
end
