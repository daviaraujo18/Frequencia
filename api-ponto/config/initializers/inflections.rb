# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

# NOTE: "estacoes" é plural irregular em português (estação/estações) — o
# inflector padrão (locale :en) singulariza para "estaco", quebrando o path
# helper `estacao_path` usado pelas rotas de `admin/estacoes` (Task 1.3).
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "estacao", "estacoes"
end
