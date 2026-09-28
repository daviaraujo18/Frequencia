module CryptoDes
  KEY = "cryp:gpf"
  IV = "cryp:gpf"

  def self.encrypt(plain_text)
    cipher = OpenSSL::Cipher.new("des-cbc")
    cipher.encrypt
    cipher.key = KEY
    cipher.iv = IV
    encrypted = cipher.update(plain_text) + cipher.final
    urlbase64_encode(encrypted)
  end

  def self.decrypt(encoded_text)
    decoded = urlbase64_decode(encoded_text)
    cipher = OpenSSL::Cipher.new("des-cbc")
    cipher.decrypt
    cipher.key = KEY
    cipher.iv = IV
    cipher.update(decoded) + cipher.final
  end

  def self.urlbase64_encode(data)
    Base64.strict_encode64(data)
      .tr("+", "-")
      .tr("/", "_")
      .delete("=")
  end

  def self.urlbase64_decode(str)
    decoded = str.tr("-", "+").tr("_", "/")
    case decoded.length % 4
    when 2 then decoded += "=="
    when 3 then decoded += "="
    end
    Base64.strict_decode64(decoded)
  end
end
