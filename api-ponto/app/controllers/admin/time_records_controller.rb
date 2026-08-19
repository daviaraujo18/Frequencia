module Admin
  class TimeRecordsController < Admin::ApplicationController
    PER_PAGE = 50

    def index
      # Monta a query base
      registros = TimeRecord.includes(:user).order(punched_at: :asc)

      if params[:id].present?
        registros = registros.where(id: params[:id])
      end

      # Usuários não-admin (basic) veem apenas os próprios registros,
      # ignorando qualquer filtro de user_id vindo dos params.
      if current_user.admin?
        if params[:user_id].present?
          registros = registros.where(user_id: params[:user_id])
          @user = User.find(params[:user_id])
        end
      else
        registros = registros.where(user_id: current_user.id)
        @user = current_user
      end

      if params[:start_date].present?
        parsed = Time.zone.parse(params[:start_date])
        registros = registros.where("punched_at >= ?", parsed.beginning_of_day) if parsed
      end

      if params[:end_date].present?
        parsed = Time.zone.parse(params[:end_date])
        registros = registros.where("punched_at <= ?", parsed.end_of_day) if parsed
      end

      @total = registros.count

      # Agrupa por data (e por usuário para admin)
      agrupado = if current_user.admin?
        registros.group_by { |r| [r.punched_at.to_date, r.user_id] }
      else
        registros.group_by { |r| r.punched_at.to_date }
      end

      # Limita e formata os pares entrada-saída
      @daily_records = agrupado.sort_by { |chave, _| chave }
                               .reverse
                               .first(PER_PAGE)
                               .map { |chave, regs|
        pares = []
        regs.each_slice(2) do |par|
          entrada = par[0]
          saida = par[1]
          pares << "#{I18n.l(entrada.punched_at, format: :short)}-#{saida ? I18n.l(saida.punched_at, format: :short) : '---'}"
        end

        if current_user.admin?
          data, user_id = chave
          usuario = regs.first.user
          [data, usuario, pares.join(", ")]
        else
          [chave, pares.join(", ")]
        end
      }
    end
  end
end
