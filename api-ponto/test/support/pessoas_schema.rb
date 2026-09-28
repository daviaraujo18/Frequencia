# frozen_string_literal: true

# rubocop:disable all -- cópia literal do pessoas2/db/schema.rb (o teste de
# divergência compara byte a byte; não reformatar).

# Schema de TESTE do espelho readonly do Pessoas (ADR-0006, tarefa 29.0).
#
# NÃO é migration e não fica em db/: o Frequencia nunca gerencia o schema do
# Pessoas2. Este arquivo só é carregado pela task `test:pessoas_schema:load`
# no banco local `frequencia_pessoas_espelho_test` (conexão `pessoas` em
# RAILS_ENV=test), que tem guardas contra qualquer outro ambiente/banco.
#
# Fonte: pessoas2/db/schema.rb, version 2026_08_20_184036 (commit daf3b579,
# 2026-08-20), copiado em 2026-09-25. As definições das tabelas abaixo são
# cópia literal (colunas, tipos, defaults e índices); só ficaram de fora as
# FKs para tabelas fora deste subconjunto. Única alteração nas FKs mantidas:
# `column:` explícito, porque o Pessoas2 tem inflexões próprias
# (tipos_vinculo -> tipo_vinculo_id) que o Frequencia não tem, e sem isso o
# Rails daqui infere `tipos_vinculo_id`. `ActiveRecord::Schema[6.0]` porque
# o Pessoas2 roda Rails 6.0 — sem isso o Rails 8 criaria `datetime` com
# precisão 6, diferente do banco real.
#
# Tabelas: as lidas pelos espelhos da cascata de autorização
# (app/models/pessoas/{pessoa,unidade,vinculo,lotacao}.rb) e as de apoio de
# `Vinculo.ativos` e da categoria do vínculo (D4): vinculos_estados,
# configuracoes_cadastro, tipos_vinculo, categorias_trabalhador.
#
# Ao mudar o Pessoas2, atualize este arquivo no mesmo ciclo — o teste
# test/lib/pessoas_schema_drift_test.rb acusa a divergência.
#
# Sem `version:` de propósito: não queremos registrar versões de migration
# do Pessoas2 no schema_migrations deste banco de teste.
ActiveRecord::Schema[6.0].define do
  create_table "categorias_trabalhador", force: :cascade do |t|
    t.text "descricao"
    t.string "codigo_esocial"
    t.string "nome_grupo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "grupo_categoria_trabalhador_id"
    t.index ["grupo_categoria_trabalhador_id"], name: "index_categorias_trabalhador_on_grupo_categoria_trabalhador_id"
  end

  create_table "tipos_vinculo", force: :cascade do |t|
    t.string "nome"
    t.string "descricao"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "nome_plural"
    t.string "nome_feminino"
    t.integer "seq_matricula"
    t.datetime "seq_matricula_updated_at"
    t.bigint "categoria_trabalhador_id"
    t.bigint "orgao_id"
    t.bigint "tipo_regime_trabalhista_id"
    t.bigint "tipo_regime_previdenciario_id"
    t.bigint "tipo_provimento_id"
    t.boolean "vinculo_da_ativa", default: true, null: false
    t.boolean "presente_intranet", default: false, null: false
    t.boolean "escala_ferias", default: false, null: false
    t.boolean "sujeito_regime_cota"
    t.boolean "docencia_exige_avaliacao", default: false, null: false
    t.index ["categoria_trabalhador_id"], name: "index_tipos_vinculo_on_categoria_trabalhador_id"
    t.index ["orgao_id"], name: "index_tipos_vinculo_on_orgao_id"
    t.index ["tipo_provimento_id"], name: "index_tipos_vinculo_on_tipo_provimento_id"
    t.index ["tipo_regime_previdenciario_id"], name: "index_tipos_vinculo_on_tipo_regime_previdenciario_id"
    t.index ["tipo_regime_trabalhista_id"], name: "index_tipos_vinculo_on_tipo_regime_trabalhista_id"
  end

  create_table "vinculos_estados", force: :cascade do |t|
    t.string "nome"
    t.string "descricao"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color"
    t.string "label"
  end

  create_table "configuracoes_cadastro", force: :cascade do |t|
    t.bigint "tipo_vinculo_id"
    t.date "inicio"
    t.date "fim"
    t.bigint "ato_normativo_id"
    t.bigint "diario_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "codigo_de_para"
    t.bigint "vinculo_estado_inicial_id"
    t.bigint "vinculo_estado_final_id"
    t.string "nome"
    t.string "icon"
    t.string "permissao"
    t.jsonb "campos", default: {}, null: false
    t.string "label"
    t.string "render_path"
    t.string "submit_path"
    t.string "submit_method"
    t.boolean "aceita_salvar_parcial", default: false, null: false
    t.index ["ato_normativo_id"], name: "index_configuracoes_cadastro_on_ato_normativo_id"
    t.index ["campos"], name: "index_configuracoes_cadastro_on_campos", using: :gin
    t.index ["diario_id"], name: "index_configuracoes_cadastro_on_diario_id"
    t.index ["tipo_vinculo_id"], name: "index_configuracoes_cadastro_on_tipo_vinculo_id"
    t.index ["vinculo_estado_final_id"], name: "index_configuracoes_cadastro_on_vinculo_estado_final_id"
    t.index ["vinculo_estado_inicial_id"], name: "index_configuracoes_cadastro_on_vinculo_estado_inicial_id"
  end

  create_table "pessoas", force: :cascade do |t|
    t.string "foto"
    t.string "nome"
    t.string "nome_social"
    t.string "cpf", null: false
    t.string "pai_nome"
    t.string "mae_nome"
    t.date "nascimento"
    t.date "obito"
    t.bigint "sexo_id"
    t.bigint "estado_civil_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.string "nis"
    t.boolean "primeiro_emprego"
    t.boolean "tem_aposentadoria"
    t.string "cpf_pai"
    t.string "cpf_mae"
    t.string "nome_avo_materno_masculino"
    t.string "nome_avo_materno_feminino"
    t.string "nome_avo_paterno_masculino"
    t.string "nome_avo_paterno_feminino"
    t.bigint "raca_id"
    t.bigint "informacao_deficiencias_id"
    t.bigint "grau_instrucao_id"
    t.bigint "nacionalidade_id"
    t.bigint "pais_nascimento_id"
    t.bigint "cidade_nascimento_id"
    t.jsonb "foto_settings", default: {}, null: false
    t.bigint "conjuge_id"
    t.string "conjuge_cpf"
    t.string "conjuge_nome"
    t.bigint "user_id"
    t.bigint "mae_id"
    t.bigint "pai_id"
    t.boolean "pai_nao_informado"
    t.boolean "uniao_estavel"
    t.date "conjuge_nascimento"
    t.time "momento_cadastro_intranet"
    t.string "username"
    t.bigint "sexo_cnj_id"
    t.bigint "identidade_genero_id"
    t.integer "seq_dependente_mentorh", default: 0, null: false
    t.boolean "portador_molestia_grave"
    t.boolean "doador_orgaos"
    t.date "data_laudo_molestia_grave"
    t.boolean "possui_curso_libras"
    t.boolean "egresso_sistema_prisional"
    t.binary "foto_biometria_binario"
    t.jsonb "foto_biometria_settings", default: {}, null: false
    t.index ["cidade_nascimento_id"], name: "index_pessoas_on_cidade_nascimento_id"
    t.index ["conjuge_id"], name: "index_pessoas_on_conjuge_id"
    t.index ["cpf"], name: "index_pessoas_on_cpf", unique: true
    t.index ["deleted_at"], name: "index_pessoas_on_deleted_at"
    t.index ["estado_civil_id"], name: "index_pessoas_on_estado_civil_id"
    t.index ["grau_instrucao_id"], name: "index_pessoas_on_grau_instrucao_id"
    t.index ["identidade_genero_id"], name: "index_pessoas_on_identidade_genero_id"
    t.index ["informacao_deficiencias_id"], name: "index_pessoas_on_informacao_deficiencias_id"
    t.index ["mae_id"], name: "index_pessoas_on_mae_id"
    t.index ["nacionalidade_id"], name: "index_pessoas_on_nacionalidade_id"
    t.index ["pai_id"], name: "index_pessoas_on_pai_id"
    t.index ["pais_nascimento_id"], name: "index_pessoas_on_pais_nascimento_id"
    t.index ["raca_id"], name: "index_pessoas_on_raca_id"
    t.index ["sexo_cnj_id"], name: "index_pessoas_on_sexo_cnj_id"
    t.index ["sexo_id"], name: "index_pessoas_on_sexo_id"
    t.index ["user_id"], name: "index_pessoas_on_user_id"
  end

  create_table "unidades", force: :cascade do |t|
    t.string "sigla"
    t.string "nome"
    t.string "descricao"
    t.bigint "unidade_id"
    t.jsonb "sip_record"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "codigo_de_para"
    t.string "ancestry"
    t.boolean "lotavel"
    t.string "codigo_jn"
    t.integer "grau"
    t.bigint "competencia_judicial_id"
    t.boolean "active", default: false
    t.bigint "classificacao_judiciaria_id"
    t.string "codigo_unidade_origem"
    t.date "data_instalacao_serventia"
    t.bigint "entrancia_id"
    t.boolean "incluir_relatorio_cnj", default: false
    t.bigint "gestor_id"
    t.bigint "gestor_substituto_id"
    t.bigint "gestor_excepcional_id"
    t.bigint "competencia_judicial_jn_id"
    t.date "data_extincao_serventia"
    t.bigint "tipo_nucleo_justica_id"
    t.bigint "orgao_jurisdicao_id"
    t.bigint "tipo_orgao_id"
    t.bigint "regiao_id"
    t.bigint "avaliador_imediato_id"
    t.bigint "avaliador_mediato_id"
    t.boolean "gera_ficha_premio_excelencia", default: false, null: false
    t.bigint "comarca_id"
    t.bigint "area_atuacao_id"
    t.boolean "compoe_secretaria_unificada", default: false, null: false
    t.index ["ancestry"], name: "index_unidades_on_ancestry"
    t.index ["area_atuacao_id"], name: "index_unidades_on_area_atuacao_id"
    t.index ["avaliador_imediato_id"], name: "index_unidades_on_avaliador_imediato_id"
    t.index ["avaliador_mediato_id"], name: "index_unidades_on_avaliador_mediato_id"
    t.index ["classificacao_judiciaria_id"], name: "index_unidades_on_classificacao_judiciaria_id"
    t.index ["codigo_de_para"], name: "index_unidades_on_codigo_de_para"
    t.index ["comarca_id"], name: "index_unidades_on_comarca_id"
    t.index ["competencia_judicial_id"], name: "index_unidades_on_competencia_judicial_id"
    t.index ["competencia_judicial_jn_id"], name: "index_unidades_on_competencia_judicial_jn_id"
    t.index ["entrancia_id"], name: "index_unidades_on_entrancia_id"
    t.index ["gestor_excepcional_id"], name: "index_unidades_on_gestor_excepcional_id"
    t.index ["gestor_id"], name: "index_unidades_on_gestor_id"
    t.index ["gestor_substituto_id"], name: "index_unidades_on_gestor_substituto_id"
    t.index ["orgao_jurisdicao_id"], name: "index_unidades_on_orgao_jurisdicao_id"
    t.index ["regiao_id"], name: "index_unidades_on_regiao_id"
    t.index ["tipo_nucleo_justica_id"], name: "index_unidades_on_tipo_nucleo_justica_id"
    t.index ["tipo_orgao_id"], name: "index_unidades_on_tipo_orgao_id"
    t.index ["unidade_id"], name: "index_unidades_on_unidade_id"
  end

  create_table "vinculos", force: :cascade do |t|
    t.bigint "pessoa_id"
    t.string "matricula"
    t.date "inicio"
    t.date "fim"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "conta_bancaria_id"
    t.bigint "configuracao_cadastro_id"
    t.bigint "ato_normativo_id"
    t.bigint "diario_id"
    t.string "codigo_de_para"
    t.bigint "vinculo_estado_id"
    t.bigint "cargo_id"
    t.bigint "tipo_provimento_id"
    t.bigint "tipo_regime_trabalhista_id"
    t.bigint "tipo_regime_previdenciario_id"
    t.bigint "tipo_plano_segregacao_id"
    t.boolean "sujeito_teto_rgps"
    t.boolean "recebe_abono_permanencia"
    t.date "data_inicio_abono_permanencia"
    t.bigint "orgao_id"
    t.bigint "importacao_id"
    t.bigint "cloned_from_id"
    t.string "status_esocial"
    t.string "matricula_esocial"
    t.bigint "seq_matricula_esocial"
    t.datetime "seq_matricula_esocial_updated_at"
    t.bigint "beneficiario_id"
    t.bigint "tipo_evento_remuneracao_id"
    t.bigint "tipo_cota_id"
    t.bigint "situacao_magistrado_id"
    t.bigint "cargo_magistrado_id"
    t.date "inicio_situacao_magistrado"
    t.bigint "tipo_regime_previdenciario_mentorh_id"
    t.index ["ato_normativo_id"], name: "index_vinculos_on_ato_normativo_id"
    t.index ["beneficiario_id"], name: "index_vinculos_on_beneficiario_id"
    t.index ["cargo_id"], name: "index_vinculos_on_cargo_id"
    t.index ["cargo_magistrado_id"], name: "index_vinculos_on_cargo_magistrado_id"
    t.index ["cloned_from_id"], name: "index_vinculos_on_cloned_from_id"
    t.index ["configuracao_cadastro_id"], name: "index_vinculos_on_configuracao_cadastro_id"
    t.index ["conta_bancaria_id"], name: "index_vinculos_on_conta_bancaria_id"
    t.index ["diario_id"], name: "index_vinculos_on_diario_id"
    t.index ["importacao_id"], name: "index_vinculos_on_importacao_id"
    t.index ["orgao_id"], name: "index_vinculos_on_orgao_id"
    t.index ["pessoa_id", "matricula", "inicio"], name: "index_vinculos_unique_pessoa_matricula_inicio", unique: true, where: "((matricula IS NOT NULL) AND (inicio IS NOT NULL))"
    t.index ["pessoa_id"], name: "index_vinculos_on_pessoa_id"
    t.index ["situacao_magistrado_id"], name: "index_vinculos_on_situacao_magistrado_id"
    t.index ["tipo_cota_id"], name: "index_vinculos_on_tipo_cota_id"
    t.index ["tipo_evento_remuneracao_id"], name: "index_vinculos_on_tipo_evento_remuneracao_id"
    t.index ["tipo_plano_segregacao_id"], name: "index_vinculos_on_tipo_plano_segregacao_id"
    t.index ["tipo_provimento_id"], name: "index_vinculos_on_tipo_provimento_id"
    t.index ["tipo_regime_previdenciario_id"], name: "index_vinculos_on_tipo_regime_previdenciario_id"
    t.index ["tipo_regime_previdenciario_mentorh_id"], name: "index_vinculos_on_tipo_regime_previdenciario_mentorh_id"
    t.index ["tipo_regime_trabalhista_id"], name: "index_vinculos_on_tipo_regime_trabalhista_id"
    t.index ["vinculo_estado_id"], name: "index_vinculos_on_vinculo_estado_id"
  end

  create_table "lotacoes", force: :cascade do |t|
    t.bigint "vinculo_id"
    t.bigint "unidade_id"
    t.boolean "principal"
    t.date "inicio"
    t.date "fim"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.bigint "ato_normativo_id"
    t.bigint "diario_id"
    t.bigint "configuracao_cadastro_id"
    t.bigint "vinculo_vantagem_id"
    t.date "data_sessao"
    t.bigint "exercicio_funcao_id"
    t.bigint "area_atuacao_id"
    t.boolean "area_atuacao_sobrescrita", default: false, null: false
    t.index ["area_atuacao_id"], name: "index_lotacoes_on_area_atuacao_id"
    t.index ["ato_normativo_id"], name: "index_lotacoes_on_ato_normativo_id"
    t.index ["configuracao_cadastro_id"], name: "index_lotacoes_on_configuracao_cadastro_id"
    t.index ["deleted_at"], name: "index_lotacoes_on_deleted_at"
    t.index ["diario_id"], name: "index_lotacoes_on_diario_id"
    t.index ["exercicio_funcao_id"], name: "index_lotacoes_on_exercicio_funcao_id"
    t.index ["unidade_id"], name: "index_lotacoes_on_unidade_id"
    t.index ["vinculo_id", "fim"], name: "index_lotacoes_on_vinculo_id_and_fim"
    t.index ["vinculo_id", "inicio"], name: "index_lotacoes_on_vinculo_id_and_inicio"
    t.index ["vinculo_id", "principal"], name: "index_lotacoes_on_vinculo_id_and_principal"
    t.index ["vinculo_id"], name: "index_lotacoes_on_vinculo_id"
    t.index ["vinculo_vantagem_id"], name: "index_lotacoes_on_vinculo_vantagem_id"
  end

  add_foreign_key "configuracoes_cadastro", "tipos_vinculo", column: "tipo_vinculo_id"
  add_foreign_key "configuracoes_cadastro", "vinculos_estados", column: "vinculo_estado_final_id"
  add_foreign_key "configuracoes_cadastro", "vinculos_estados", column: "vinculo_estado_inicial_id"
  add_foreign_key "lotacoes", "configuracoes_cadastro", column: "configuracao_cadastro_id"
  add_foreign_key "lotacoes", "unidades", column: "unidade_id"
  add_foreign_key "lotacoes", "vinculos", column: "vinculo_id"
  add_foreign_key "pessoas", "pessoas", column: "conjuge_id"
  add_foreign_key "pessoas", "pessoas", column: "mae_id"
  add_foreign_key "pessoas", "pessoas", column: "pai_id"
  add_foreign_key "tipos_vinculo", "categorias_trabalhador", column: "categoria_trabalhador_id"
  add_foreign_key "unidades", "pessoas", column: "avaliador_imediato_id"
  add_foreign_key "unidades", "pessoas", column: "avaliador_mediato_id"
  add_foreign_key "unidades", "pessoas", column: "gestor_excepcional_id"
  add_foreign_key "unidades", "pessoas", column: "gestor_id"
  add_foreign_key "unidades", "pessoas", column: "gestor_substituto_id"
  add_foreign_key "unidades", "unidades", column: "comarca_id"
  add_foreign_key "vinculos", "configuracoes_cadastro", column: "configuracao_cadastro_id"
  add_foreign_key "vinculos", "pessoas", column: "pessoa_id"
  add_foreign_key "vinculos", "vinculos", column: "cloned_from_id"
  add_foreign_key "vinculos", "vinculos_estados", column: "vinculo_estado_id"
end
