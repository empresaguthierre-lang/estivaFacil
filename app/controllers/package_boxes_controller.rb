class PackageBoxesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_package_box, only: [ :show, :edit, :update, :destroy ]

  def index
    @package_boxes = current_company.package_boxes.order(:name)
  end

  def show; end

  def new
    @package_box = current_company.package_boxes.new(active: true, units_per_package: 1, package_weight_kg: 0)
  end

  def edit; end

  def create
    @package_box = current_company.package_boxes.new(package_box_params)

    if @package_box.save
      redirect_to @package_box, notice: "Embalagem cadastrada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @package_box.update(package_box_params)
      redirect_to @package_box, notice: "Embalagem atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @package_box.destroy
      redirect_to package_boxes_path, notice: "Embalagem removida com sucesso."
    else
      redirect_to @package_box, alert: @package_box.errors.full_messages.to_sentence
    end
  end

  private

  def set_package_box
    @package_box = current_company.package_boxes.find(params[:id])
  end

  def package_box_params
    params.require(:package_box).permit(:name, :length_cm, :width_cm, :height_cm, :units_per_package, :package_weight_kg, :active)
  end
end
