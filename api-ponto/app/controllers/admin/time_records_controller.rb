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
      unless current_user.admin?
        @records = @records.where(user_id: current_user.id)
        @user = current_user
      elsif params[:user_id].present?
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
    end
  end
end
