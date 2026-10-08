require "test_helper"

# Task 31 (fix de cobertura da cascata) — prova que o dropdown de ANOS de
# `admin/time_records#index` deixou de vazar a data da batida mais antiga da
# BASE a um não-admin (achado 🟡 do
# `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md`).
#
# Antes da correção, `@anos_disponiveis` era calculado com
# `TimeRecord.minimum(:punched_at)` GLOBAL, antes de `restringir_frequencia` e
# do filtro `where(user_id: current_user.id)` do não-admin — revelando anos que
# só existiam por causa de registros de TERCEIROS. Agora deriva apenas dos
# registros visíveis.
module Admin
  class TimeRecordsAnosCascataTest < ActionDispatch::IntegrationTest
    ANO_ANTIGO = 2019

    test "nao-admin NAO ve no dropdown o ano de uma batida antiga de terceiro" do
      terceiro = User.create!(nome_completo: "Terceiro Ano Antigo", password: "123456", cpf: "60060060060")
      TimeRecord.create!(
        user: terceiro, raw_data: "old",
        punched_at: Time.zone.local(ANO_ANTIGO, 3, 1, 8, 0, 0), authentication_mode: "biometric"
      )

      comum = login_como_nao_admin
      TimeRecord.create!(
        user: comum, raw_data: "meu",
        punched_at: Time.zone.now, authentication_mode: "biometric"
      )

      get time_records_path

      assert_response :success
      assert_select "select#filtro_ano option[value='#{ANO_ANTIGO}']", { count: 0 },
                    "o ano de batida de TERCEIRO nao pode aparecer para o nao-admin"
      # O próprio ano do usuário aparece (o dropdown não some por completo).
      assert_select "select#filtro_ano option[value='#{Time.current.year}']"
    end

    test "admin ve no dropdown o ano de uma batida antiga de terceiro (controle positivo)" do
      terceiro = User.create!(nome_completo: "Terceiro Ano Antigo", password: "123456", cpf: "60060060061")
      TimeRecord.create!(
        user: terceiro, raw_data: "old",
        punched_at: Time.zone.local(ANO_ANTIGO, 3, 1, 8, 0, 0), authentication_mode: "biometric"
      )

      login_como_admin

      get time_records_path

      assert_response :success
      assert_select "select#filtro_ano option[value='#{ANO_ANTIGO}']"
    end

    private

    def login_como_admin
      delete logout_path
      admin = User.create!(nome_completo: "Admin Anos Cascata", password: "123456", admin: true)
      post login_path, params: { username: admin.username, password: "123456" }
      admin
    end

    def login_como_nao_admin
      delete logout_path
      comum = User.create!(nome_completo: "Usuario Comum Anos", password: "123456", admin: false)
      post login_path, params: { username: comum.username, password: "123456" }
      comum
    end
  end
end
