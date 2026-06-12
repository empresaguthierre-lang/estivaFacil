class VehiclesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_vehicle, only: [ :show, :edit, :update, :destroy ]

  def index
    @vehicles = current_company.vehicles.order(:name)
  end

  def show; end

  def new
    @vehicle = current_company.vehicles.new(active: true)
  end

  def edit; end

  def create
    @vehicle = current_company.vehicles.new(vehicle_params)

    if @vehicle.save
      redirect_to @vehicle, notice: "Veículo cadastrado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vehicle.update(vehicle_params)
      redirect_to @vehicle, notice: "Veículo atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @vehicle.destroy
      redirect_to vehicles_path, notice: "Veículo removido com sucesso."
    else
      redirect_to @vehicle, alert: @vehicle.errors.full_messages.to_sentence
    end
  end

  private

  def set_vehicle
    @vehicle = current_company.vehicles.find(params[:id])
  end

  def vehicle_params
    params.require(:vehicle).permit(
      :name, :kind, :max_weight_kg, :max_volume_m3, :length_cm, :width_cm, :height_cm,
      :pallet_capacity, :body_type, :usable_height_cm, :usable_width_cm, :usable_length_cm,
      :allows_hazardous, :refrigerated, :notes, :active
    )
  end
end
