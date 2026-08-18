module Admin
  class DashboardController < Admin::ApplicationController
    before_action -> { require_admin(time_records_path) }, only: [:index]

    def index
      hoje = Time.current.beginning_of_day

      @total_usuarios = User.count
      @usuarios_ativos = User.ativos.count
      @usuarios_inativos = @total_usuarios - @usuarios_ativos
      @usuarios_com_digitais = User.com_digitais.count

      @registros_hoje = TimeRecord.where("punched_at >= ?", hoje).count
      @registros_semana = TimeRecord.where("punched_at >= ?", 7.days.ago).count
      @registros_mes = TimeRecord.where("punched_at >= ?", 30.days.ago).count

      # "Últimas Batidas" exibe entradas e saídas em colunas separadas
      # (esquerda/direita) — buscamos os dois tipos independentemente para
      # que ambos os lados fiquem preenchidos mesmo se um tipo for muito
      # mais frequente que o outro no momento.
      @ultimas_entradas = TimeRecord.includes(:user)
                                     .where(punch_type: "entry")
                                     .order(created_at: :desc)
                                     .limit(5)
      @ultimas_saidas = TimeRecord.includes(:user)
                                   .where(punch_type: "exit")
                                   .order(created_at: :desc)
                                   .limit(5)
    end
  end
end
