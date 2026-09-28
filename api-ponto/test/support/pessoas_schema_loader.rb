# frozen_string_literal: true

# Carrega test/support/pessoas_schema.rb na conexão `pessoas` (ADR-0006).
#
# As guardas existem porque a mesma conexão `pessoas`, fora de test, aponta
# para o banco REAL do Pessoas2: rodar `force: :cascade` lá apagaria dados de
# outra aplicação. Por isso as duas verificações são independentes e ambas
# obrigatórias (ambiente E nome do banco).
class PessoasSchemaLoader
  class GuardError < StandardError; end

  SCHEMA_PATH = File.expand_path("pessoas_schema.rb", __dir__)
  DATABASE_NAME = "pessoas"

  def initialize(env: Rails.env, db_config: nil)
    @env = env.to_s
    @db_config = db_config || ActiveRecord::Base.configurations.configs_for(
      env_name: @env, name: DATABASE_NAME, include_hidden: true
    )
  end

  def verify!
    unless @env == "test"
      raise GuardError, "test:pessoas_schema:load only runs with RAILS_ENV=test (current: #{@env})"
    end

    database = @db_config&.database.to_s
    unless database.end_with?("_test")
      raise GuardError, "test:pessoas_schema:load refuses database #{database.inspect}: name must end with _test"
    end

    @db_config
  end

  def load!
    db_config = verify!

    # O Schema.define executa na conexão de ActiveRecord::Base (a mesma que o
    # `db:schema:load` do Rails usa). Apontamos Base temporariamente para o
    # banco `pessoas` e restauramos a conexão original ao final — mesmo
    # molde do `with_temporary_pool` do Rails, que é API privada no 8.0.
    original_config = ActiveRecord::Base.connection_db_config
    begin
      ActiveRecord::Base.establish_connection(db_config)
      ActiveRecord::Migration.suppress_messages { load SCHEMA_PATH }
    ensure
      ActiveRecord::Base.establish_connection(original_config)
    end

    db_config.database
  end
end
