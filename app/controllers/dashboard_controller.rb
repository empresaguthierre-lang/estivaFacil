class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @cargos = current_company.cargos.includes(:recommended_vehicle).order(created_at: :desc).limit(6)
    @cargos_count = current_company.cargos.count
    @vehicles_count = current_company.vehicles.ativos.count
    @products_count = current_company.products.ativos.count
    @packages_count = current_company.package_boxes.ativos.count
    @cargo_volume = current_company.cargos.sum(:total_volume_m3)
    @cargo_weight = current_company.cargos.sum(:total_weight_kg)
    @total_packages = current_company.cargos.sum(:total_packages)
    @total_pallets = current_company.cargos.sum(:total_pallets)
  end
end
