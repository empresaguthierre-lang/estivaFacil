class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product, only: [ :show, :edit, :update, :destroy ]
  before_action :set_package_boxes, only: [ :new, :edit, :create, :update ]

  def index
    @products = current_company.products.includes(:package_box).search(params[:q]).order(:name)
  end

  def show; end

  def new
    @product = current_company.products.new(
      active: true,
      unit: "un",
      stowage_factor: 1,
      default_count_method: "unidade",
      units_per_package: 1,
      packages_per_pallet: 1,
      stackable: true,
      max_stack_layers: 1,
      can_rotate: true
    )
  end

  def edit; end

  def create
    @product = current_company.products.new(product_params)

    if @product.save
      redirect_to @product, notice: "Produto cadastrado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: "Produto atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @product.destroy
      redirect_to products_path, notice: "Produto removido com sucesso."
    else
      redirect_to @product, alert: @product.errors.full_messages.to_sentence
    end
  end

  private

  def set_product
    @product = current_company.products.includes(:package_box).find(params[:id])
  end

  def set_package_boxes
    @package_boxes = current_company.package_boxes.ativos.order(:name)
  end

  def product_params
    params.require(:product).permit(
      :internal_code, :ref_code, :imp_code, :sku, :reference_code, :name, :description, :unit,
      :default_count_method, :package_label, :units_per_package, :packages_per_pallet,
      :weight_per_unit_kg, :unit_weight_kg, :package_weight_kg, :pallet_weight_kg,
      :unit_length_cm, :unit_width_cm, :unit_height_cm,
      :package_length_cm, :package_width_cm, :package_height_cm,
      :pallet_length_cm, :pallet_width_cm, :pallet_height_cm,
      :stowage_factor, :package_box_id, :stackable, :max_stack_layers, :fragile, :can_rotate,
      :hazardous, :active
    )
  end
end
