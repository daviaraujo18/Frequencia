# Admin (username: admin.admin)
User.find_or_create_by!(nome_completo: "Admin Admin") do |u|
  u.password = "123456"
end

# Usuários de demonstração
User.find_or_create_by!(nome_completo: "João Biométrico") do |u|
  u.password = "123456"
  u.digitais_hash = "FIR_TEXTENCODE_SAMPLE_HASH_1234567890"
end

User.find_or_create_by!(nome_completo: "Maria Santos") do |u|
  u.password = "123456"
  u.digitais_hash = "FIR_TEXTENCODE_MARIA_HASH_0987654321"
end

User.find_or_create_by!(nome_completo: "Carlos Pereira") do |u|
  u.password = "123456"
end

# Registros de ponto falsos para demonstração
joao = User.find_by(nome_completo: "João Biométrico")
maria = User.find_by(nome_completo: "Maria Santos")
carlos = User.find_by(nome_completo: "Carlos Pereira")

if TimeRecord.count == 0
  agora = Time.current

  # Batidas de hoje
  [[joao, "biometric"], [maria, "biometric"], [carlos, "manual"]].each do |user, mode|
    TimeRecord.create!(
      user: user,
      raw_data: "#{user.id}-#{agora.strftime("%d:%m:%Y:%H:%M:%S")}",
      punched_at: agora - rand(1..8).hours,
      authentication_mode: mode
    )
  end

  # Batidas de dias anteriores
  [1, 2, 3, 5, 7].each do |day_ago|
    [joao, maria].each do |user|
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
