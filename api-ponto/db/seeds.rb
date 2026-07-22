User.find_or_create_by!(nome_completo: "Usuário Teste") do |u|
  u.password = "123456"
end

User.find_or_create_by!(nome_completo: "João Biométrico") do |u|
  u.password = "123456"
  u.digitais_hash = "FIR_TEXTENCODE_SAMPLE_HASH_1234567890"
end
