# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_08_28_133924) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "estacoes_ponto", force: :cascade do |t|
    t.string "descricao", null: false
    t.string "versao"
    t.datetime "ultimo_contato"
    t.string "vnc"
    t.string "anydesk"
    t.string "teamviewer"
    t.text "observacao"
    t.string "cod_ativacao", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cod_ativacao"], name: "index_estacoes_ponto_on_cod_ativacao", unique: true
  end

  create_table "frequentador_caches", force: :cascade do |t|
    t.string "cpf"
    t.integer "pessoa_id_pessoas"
    t.string "nome"
    t.string "orgao"
    t.string "vinculo"
    t.datetime "sincronizado_em"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cpf"], name: "index_frequentador_caches_on_cpf", unique: true
  end

  create_table "time_records", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "raw_data"
    t.datetime "punched_at"
    t.string "authentication_mode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "punch_type"
    t.boolean "punch_type_explicit", default: false, null: false
    t.index ["punched_at"], name: "index_time_records_on_punched_at"
    t.index ["user_id"], name: "index_time_records_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "nome_completo", null: false
    t.string "username", null: false
    t.string "password_digest", null: false
    t.integer "status", default: 1, null: false
    t.text "digitais_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.string "cpf"
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["cpf"], name: "index_users_on_cpf", unique: true
    t.index ["status"], name: "index_users_on_status"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "time_records", "users"
end
