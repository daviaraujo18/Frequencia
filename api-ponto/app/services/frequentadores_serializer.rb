module FrequentadoresSerializer
  SEPARADOR_REGISTRO = "'"
  SEPARADOR_CAMPO = ";"

  def self.serialize(users)
    users.map { |u| serializar_usuario(u) }.join(SEPARADOR_REGISTRO)
  end

  def self.hash_md5(users)
    Digest::MD5.hexdigest(serialize(users)).upcase
  end

  def self.serializar_usuario(user)
    [
      user.id,
      user.username,
      user.nome_completo,
      user.digitais_hash.to_s,
      "",
      "false",
      "N",
      "0"
    ].join(SEPARADOR_CAMPO)
  end
end
