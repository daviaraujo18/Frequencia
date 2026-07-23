module Admin
  class TimeRecordsController < Admin::ApplicationController
    PER_PAGE = 50

    def index
      @records = TimeRecord.includes(:user).order(punched_at: :desc)

      if params[:user_id].present?
        @records = @records.where(user_id: params[:user_id])
        @user = User.find(params[:user_id])
      end

      if params[:start_date].present?
        @records = @records.where("punched_at >= ?", Time.zone.parse(params[:start_date]).beginning_of_day)
      end

      if params[:end_date].present?
        @records = @records.where("punched_at <= ?", Time.zone.parse(params[:end_date]).end_of_day)
      end

      @records = @records.limit(PER_PAGE)
      @total = @records.unscope(:limit, :order).count
    end
  end
end
