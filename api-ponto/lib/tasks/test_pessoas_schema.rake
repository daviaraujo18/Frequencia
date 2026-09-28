# frozen_string_literal: true

# ADR-0006: carrega o schema de teste do espelho Pessoas no banco local
# `frequencia_pessoas_espelho_test`. Rodar UMA vez antes da suíte (nunca
# dentro de worker do parallelize):
#
#   RAILS_ENV=test bin/rails test:pessoas_schema:load
namespace :test do
  namespace :pessoas_schema do
    desc "Load test/support/pessoas_schema.rb into the pessoas test database (RAILS_ENV=test only)"
    task load: :environment do
      require Rails.root.join("test/support/pessoas_schema_loader").to_s

      database = PessoasSchemaLoader.new.load!
      puts "Pessoas mirror test schema loaded into #{database}"
    rescue PessoasSchemaLoader::GuardError => e
      abort e.message
    end
  end
end
