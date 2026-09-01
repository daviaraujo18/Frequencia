require "test_helper"

module Admin
  class FrequenciaPorOrgaoControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = User.create!(nome_completo: "Admin Teste", password: "123456", admin: true)
      post login_path, params: { username: @admin.username, password: "123456" }
    end

    test "deve funcionar com base vazia" do
      get frequencia_por_orgao_path

      assert_response :success
      assert_select "td", text: "Nenhum registro encontrado"
    end

    test "agrupa presencas por orgao contando dias distintos com batida" do
      user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")
      FrequentadorCache.create!(cpf: "11122233344", nome: "Fulano", orgao: "Vara Cível")

      dia1 = Time.zone.local(2026, 7, 10, 8, 0)
      dia1_tarde = Time.zone.local(2026, 7, 10, 17, 0)
      dia2 = Time.zone.local(2026, 7, 11, 8, 0)

      TimeRecord.create!(user: user, raw_data: "a", punched_at: dia1, authentication_mode: "biometric")
      TimeRecord.create!(user: user, raw_data: "b", punched_at: dia1_tarde, authentication_mode: "biometric")
      TimeRecord.create!(user: user, raw_data: "c", punched_at: dia2, authentication_mode: "biometric")

      get frequencia_por_orgao_path

      assert_response :success
      assert_select "td", text: "Vara Cível"
      # 2 batidas no mesmo dia contam como 1 presença + 1 batida no outro dia = 2
      assert_select "td", text: "2"
    end

    test "conta afastamentos como ausencias por orgao" do
      FrequentadorCache.create!(cpf: "11122233344", nome: "Fulano", orgao: "Vara Cível")
      AfastamentoCache.create!(afastamento_id_pessoas: 1, cpf: "11122233344", tipo: "Férias", momento_inicial: Time.zone.local(2026, 7, 5))
      AfastamentoCache.create!(afastamento_id_pessoas: 2, cpf: "11122233344", tipo: "Licença", momento_inicial: Time.zone.local(2026, 7, 15))

      get frequencia_por_orgao_path

      assert_response :success
      assert_select "td", text: "2"
    end

    test "trabalhado aparece como travessao (nao computado, pendente Fase B)" do
      FrequentadorCache.create!(cpf: "11122233344", nome: "Fulano", orgao: "Vara Cível")

      get frequencia_por_orgao_path

      assert_response :success
      assert_select "td.text-muted", text: "—", minimum: 1
    end

    test "trabalhado continua travessao mesmo com batidas de entrada e saida completas" do
      # Prova que a coluna "Trabalhado" nao esconde calculo algum: mesmo com
      # dados suficientes para calcular horas trabalhadas (entrada + saida no
      # mesmo dia), a tela nao deve computar nada - isso e Fase B (Sprint 16).
      user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")
      FrequentadorCache.create!(cpf: "11122233344", nome: "Fulano", orgao: "Vara Cível")

      TimeRecord.create!(user: user, raw_data: "entrada", punched_at: Time.zone.local(2026, 7, 10, 8, 0), authentication_mode: "biometric")
      TimeRecord.create!(user: user, raw_data: "saida", punched_at: Time.zone.local(2026, 7, 10, 17, 0), authentication_mode: "biometric")

      get frequencia_por_orgao_path

      assert_response :success
      assert_select "td.text-muted", text: "—", minimum: 1
      # Nenhum valor numerico deve aparecer na coluna "Trabalhado" (ex: "9" horas)
      assert_select "td:nth-child(2)" do |cells|
        cells.each { |cell| assert_equal "—", cell.text.strip }
      end
    end

    test "filtra por orgao" do
      FrequentadorCache.create!(cpf: "11122233344", nome: "Fulano", orgao: "Vara Cível")
      FrequentadorCache.create!(cpf: "55566677788", nome: "Beltrano", orgao: "Vara Criminal")

      get frequencia_por_orgao_path, params: { orgao: "Cível" }

      assert_response :success
      assert_select "td", text: "Vara Cível"
      assert_select "td", text: "Vara Criminal", count: 0
    end

    test "filtra por mes e ano" do
      user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")
      FrequentadorCache.create!(cpf: "11122233344", nome: "Fulano", orgao: "Vara Cível")

      TimeRecord.create!(user: user, raw_data: "julho", punched_at: Time.zone.local(2026, 7, 10, 8, 0), authentication_mode: "biometric")
      TimeRecord.create!(user: user, raw_data: "agosto", punched_at: Time.zone.local(2026, 8, 10, 8, 0), authentication_mode: "biometric")

      get frequencia_por_orgao_path, params: { mes: 7, ano: 2026 }

      assert_response :success
      assert_select "td", text: "1"
    end

    test "orgao sem frequentador algum nao aparece" do
      get frequencia_por_orgao_path

      assert_response :success
      assert_select "td", text: "Nenhum registro encontrado"
    end

    test "deve redirecionar para login se nao autenticado" do
      delete logout_path
      get frequencia_por_orgao_path
      assert_redirected_to login_path
    end
  end
end
