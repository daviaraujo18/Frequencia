module Admin
  class TimeRecordsController < Admin::ApplicationController
    PER_PAGE = 50

    def index
      @records = TimeRecord.includes(:user).order(punched_at: :desc)

      if params[:id].present?
        @records = @records.where(id: params[:id])
      end

      # Usuários não-admin (basic) veem apenas os próprios registros,
      # ignorando qualquer filtro de user_id vindo dos params.
      if current_user.admin?
        if params[:user_id].present?
          @records = @records.where(user_id: params[:user_id])
          @user = User.find(params[:user_id])
        end

        if params[:start_date].present?
          parsed = Time.zone.parse(params[:start_date])
          @records = @records.where("punched_at >= ?", parsed.beginning_of_day) if parsed
        end

        if params[:end_date].present?
          parsed = Time.zone.parse(params[:end_date])
          @records = @records.where("punched_at <= ?", parsed.end_of_day) if parsed
        end

        @records = @records.limit(PER_PAGE)
        @total = @records.unscope(:limit, :order).count
      else
        # Usuário basic: busca os registros e agrupa por dia
        registros = current_user.time_records.order(punched_at: :asc)

        if params[:start_date].present?
          parsed = Time.zone.parse(params[:start_date])
          registros = registros.where("punched_at >= ?", parsed.beginning_of_day) if parsed
        end

        if params[:end_date].present?
          parsed = Time.zone.parse(params[:end_date])
          registros = registros.where("punched_at <= ?", parsed.end_of_day) if parsed
        end

        @daily_records = registros.group_by { |r| r.punched_at.to_date }
                                  .sort_by { |data, _| data }
                                  .reverse
                                  .first(PER_PAGE)

        @total = registros.count
        @user = current_user
      end
    end
  end
end
