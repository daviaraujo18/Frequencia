require "test_helper"

class CryptoDesTest < ActiveSupport::TestCase
  setup do
    @plain_texts = ["jose.silva", "123456", "admin", "a", "test_user"]
  end

  test "encrypt and decrypt roundtrip" do
    @plain_texts.each do |original|
      encrypted = CryptoDes.encrypt(original)
      decrypted = CryptoDes.decrypt(encrypted)
      assert_equal original, decrypted, "Roundtrip failed for '#{original}'"
    end
  end

  test "encrypted output uses UrlBase64 (no +, /, =)" do
    @plain_texts.each do |original|
      encrypted = CryptoDes.encrypt(original)
      refute_match(/[+\/=]/, encrypted, "UrlBase64 contains invalid chars for '#{original}': #{encrypted}")
    end
  end

  test "encrypt produces different output for different inputs" do
    results = @plain_texts.map { |s| CryptoDes.encrypt(s) }
    assert_equal results.uniq.size, results.size, "Different inputs produced same encrypted output"
  end

  test "encrypt is deterministic with fixed key/IV" do
    first = CryptoDes.encrypt("jose.silva")
    second = CryptoDes.encrypt("jose.silva")
    assert_equal first, second, "Same input should produce same output with fixed key/IV"
  end

  test "decrypt with invalid UrlBase64 raises ArgumentError" do
    assert_raises(ArgumentError) do
      CryptoDes.decrypt("invalid!base64")
    end
  end

  test "decrypt with tampered data produces different result" do
    encrypted = CryptoDes.encrypt("jose.silva")
    tampered = encrypted.dup
    tampered[0] = tampered[0] == "a" ? "b" : "a"
    result = CryptoDes.decrypt(tampered) rescue nil
    assert_not_equal "jose.silva", result
  end

  test "empty string roundtrip" do
    encrypted = CryptoDes.encrypt("")
    decrypted = CryptoDes.decrypt(encrypted)
    assert_equal "", decrypted
  end

  test "urlbase64_encode produces no padding" do
    result = CryptoDes.urlbase64_encode("test")
    refute_includes result, "="
  end
end
