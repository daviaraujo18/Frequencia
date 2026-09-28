require "test_helper"

# Proteção contra divergência (ADR-0006, regra 6): as tabelas de
# test/support/pessoas_schema.rb são cópia literal de pessoas2/db/schema.rb.
# Se o Pessoas2 mudar uma delas, este teste falha até o schema de teste ser
# atualizado. Sem o checkout irmão (ex.: CI só com o Frequencia), é pulado.
class PessoasSchemaDriftTest < ActiveSupport::TestCase
  LOCAL_SCHEMA = Rails.root.join("test/support/pessoas_schema.rb")
  PESSOAS2_SCHEMA = Rails.root.join("../../pessoas2/db/schema.rb").expand_path

  setup do
    skip "Pessoas2 checkout not found at #{PESSOAS2_SCHEMA}; drift check skipped" unless PESSOAS2_SCHEMA.exist?

    @local = LOCAL_SCHEMA.read
    @source = PESSOAS2_SCHEMA.read
  end

  test "every mirrored table is identical to the Pessoas2 definition" do
    tables = table_blocks(@local)

    assert_not_empty tables
    tables.each do |table, local_block|
      source_block = table_blocks(@source)[table]

      assert source_block, "table #{table} no longer exists in pessoas2/db/schema.rb"
      assert_equal source_block, local_block, "table #{table} diverged from pessoas2/db/schema.rb"
    end
  end

  test "every mirrored foreign key exists in Pessoas2" do
    source_keys = foreign_keys(@source)

    foreign_keys(@local).each do |from, to, column|
      assert source_keys.include?([ from, to, column ]) || source_keys.include?([ from, to, nil ]),
             "foreign key #{from} -> #{to} (#{column}) not found in pessoas2/db/schema.rb"
    end
  end

  private

  def table_blocks(schema)
    schema.scan(/^  create_table "([^"]+)".*?^  end$/m).to_h do |(name)|
      [ name, schema[/^  create_table "#{Regexp.escape(name)}".*?^  end$/m] ]
    end
  end

  def foreign_keys(schema)
    schema.scan(/^  add_foreign_key "([^"]+)", "([^"]+)"(?:, column: "([^"]+)")?/)
  end
end
