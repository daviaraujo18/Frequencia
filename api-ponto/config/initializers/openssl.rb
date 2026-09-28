if OpenSSL::Provider.respond_to?(:load)
  OpenSSL::Provider.load("legacy")
end
