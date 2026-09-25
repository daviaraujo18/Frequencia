require "test_helper"
require "open3"
require_relative "../support/pessoas_schema_loader"

# Guardas da task `test:pessoas_schema:load` (ADR-0006, Compliance): ela
# executa `force: :cascade`, então nunca pode alcançar o banco real do Pessoas.
class PessoasSchemaLoaderTest < ActiveSupport::TestCase
  DbConfigDouble = Struct.new(:database)

  test "refuses to run outside RAILS_ENV=test" do
    %w[development production staging].each do |env|
      loader = PessoasSchemaLoader.new(env: env, db_config: DbConfigDouble.new("frequencia_pessoas_espelho_test"))

      error = assert_raises(PessoasSchemaLoader::GuardError) { loader.load! }
      assert_match "RAILS_ENV=test", error.message
    end
  end

  test "refuses a database whose name does not end with _test" do
    [ "pessoas", "pessoas_production", "pessoas_test_backup", "", nil ].each do |database|
      loader = PessoasSchemaLoader.new(env: "test", db_config: DbConfigDouble.new(database))

      error = assert_raises(PessoasSchemaLoader::GuardError) { loader.load! }
      assert_match "must end with _test", error.message
    end
  end

  test "accepts the configured test mirror database" do
    db_config = PessoasSchemaLoader.new.verify!

    assert_equal "frequencia_pessoas_espelho_test", db_config.database
  end

  test "rake task aborts before touching any database outside the test environment" do
    # RUBYOPT herdado do processo de teste quebra o boot do subprocesso.
    env = { "RAILS_ENV" => "development", "RUBYOPT" => nil }
    output, status = Open3.capture2e(env, "bin/rails", "test:pessoas_schema:load", chdir: Rails.root.to_s)

    assert_not status.success?
    assert_match "only runs with RAILS_ENV=test (current: development)", output
  end
end
