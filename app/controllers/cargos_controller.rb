class CargosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cargo, only: [ :show, :edit, :update, :duplicate ]

  def index
    @cargos = current_company.cargos.includes(:recommended_vehicle).order(created_at: :desc)
  end

  def show
  end

  def new
    @cargo = current_company.cargos.new
    @cargo.cargo_items.build
    set_products
  end

  def edit
    set_products
  end

  def create
    @cargo = current_company.cargos.new(cargo_params)
    @cargo.user = current_user
    @cargo.status = :calculada

    if @cargo.save
      StowagePlanner.call(@cargo)
      redirect_to @cargo, notice: "Cubagem calculada e veículo sugerido."
    else
      set_products
      flash.now[:alert] = "Revise os campos destacados."
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @cargo.update(cargo_params)
      @cargo.stowage_plan&.destroy
      StowagePlanner.call(@cargo)
      redirect_to @cargo, notice: "Cubagem atualizada com sucesso."
    else
      set_products
      flash.now[:alert] = "Revise os campos destacados."
      render :edit, status: :unprocessable_entity
    end
  end

  def duplicate
    duplicated = current_company.cargos.new(
      customer_name: "#{@cargo.customer_name} (cópia)",
      origin: @cargo.origin,
      destination: @cargo.destination,
      user: current_user,
      status: :rascunho
    )

    @cargo.cargo_items.each do |item|
      duplicated.cargo_items.build(
        product: item.product,
        description: item.description,
        count_method: item.count_method,
        count_quantity: item.count_quantity,
        package_label: item.package_label,
        units_per_package: item.units_per_package,
        packages_per_pallet: item.packages_per_pallet,
        length_cm: item.length_cm,
        width_cm: item.width_cm,
        height_cm: item.height_cm,
        weight_kg: item.weight_kg,
        stackable: item.stackable,
        max_stack_layers: item.max_stack_layers,
        fragile: item.fragile,
        can_rotate: item.can_rotate,
        hazardous: item.hazardous,
        loading_priority: item.loading_priority,
        notes: item.notes
      )
    end

    if duplicated.save
      redirect_to edit_cargo_path(duplicated), notice: "Carga duplicada. Ajuste as quantidades e recalcule."
    else
      redirect_to @cargo, alert: duplicated.errors.full_messages.to_sentence
    end
  end

  private

  def set_cargo
    @cargo = current_company.cargos.includes(:recommended_vehicle, :stowage_plan, cargo_items: :product).find(params[:id])
  end

  def set_products
    @products = current_company.products.ativos.includes(:package_box).order(:name)
  end

  def cargo_params
    params.require(:cargo).permit(
      :customer_name, :origin, :destination, :invoice,
      cargo_items_attributes: [
        :id, :product_id, :description, :quantity, :count_method, :count_quantity,
        :package_label, :units_per_package, :packages_per_pallet, :length_cm, :width_cm,
        :height_cm, :weight_kg, :stackable, :max_stack_layers, :fragile, :can_rotate,
        :hazardous, :loading_priority, :notes, :_destroy
      ]
    )
  end
end
