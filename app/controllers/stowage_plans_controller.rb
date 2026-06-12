class StowagePlansController < ApplicationController
  before_action :authenticate_user!

  def show
    @stowage_plan = current_company.stowage_plans.includes(:cargo, :vehicle).find(params[:id])
  end
end
