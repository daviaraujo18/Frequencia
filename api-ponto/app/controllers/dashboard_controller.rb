class DashboardController < ApplicationController
  def index
    @total_usuarios = User.count
    @usuarios_ativos = User.ativos.count
    @usuarios_inativos = @total_usuarios - @usuarios_ativos
    @usuarios_com_digitais = User.com_digitais.count

    hoje = Time.current.beginning_of_day
    @registros_hoje = TimeRecord.where("punched_at >= ?", hoje).count
    @registros_semana = TimeRecord.where("punched_at >= ?", 7.days.ago).count
    @registros_mes = TimeRecord.where("punched_at >= ?", 30.days.ago).count

    @ultimas_batidas = TimeRecord.includes(:user)
                                 .order(created_at: :desc)
                                 .limit(10)
  end
end
