class CargoItem < ApplicationRecord
  COUNT_METHODS = Product::COUNT_METHODS
  PACKAGE_METHODS = %w[caixa fardo pacote outro].freeze
  LOADING_PRIORITIES = %w[carregar_primeiro normal carregar_por_ultimo].freeze

  belongs_to :cargo
  belongs_to :product, optional: true

  before_validation :copy_product_snapshot, if: :product
  before_validation :normalize_counting_fields
  before_validation :calculate_from_count_method

  validates :count_method, presence: true, inclusion: { in: COUNT_METHODS }
  validates :count_quantity, presence: true, numericality: { greater_than: 0 }
  validates :loading_priority, inclusion: { in: LOADING_PRIORITIES }
  validates :length_cm, :width_cm, :height_cm, :weight_kg, numericality: { greater_than: 0 }
  validates :units_per_package, numericality: { only_integer: true, greater_than: 0 }, if: :package_count_method?
  validates :packages_per_pallet, numericality: { only_integer: true, greater_than: 0 }, if: :pallet_count_method?
  validate :product_belongs_to_company
  validate :stacking_rules

  def description
    product_name_snapshot.presence || super
  end

  def volume_m3
    length_cm.to_d * width_cm.to_d * height_cm.to_d / 1_000_000
  end

  def total_volume_m3
    calculated_volume_m3
  end

  def total_weight_kg
    calculated_weight_kg
  end

  def package_count_method?
    PACKAGE_METHODS.include?(count_method)
  end

  def pallet_count_method?
    count_method == "palete"
  end

  private

  def normalize_counting_fields
    self.count_quantity ||= quantity
    self.quantity = count_quantity.to_i if count_quantity.present?
    self.count_method = "unidade" if count_method.blank?
    self.loading_priority = "normal" if loading_priority.blank?
    self.max_stack_layers = 1 unless stackable?
  end

  def copy_product_snapshot
    self.product_internal_code_snapshot = product.commercial_code
    self.product_ref_code_snapshot = product.reference_code.presence || product.ref_code
    self.product_imp_code_snapshot = product.imp_code
    self.product_name_snapshot = product.name
    self.description = product.description.presence || product.name if self[:description].blank?
    self.count_method = product.default_count_method if count_method.blank?
    self.package_label = product.package_name if package_label.blank?
    self.package_name_snapshot = product.package_name
    self.units_per_package ||= product.units_per_package
    self.packages_per_pallet ||= product.packages_per_pallet
    self.weight_per_unit_kg ||= product.unit_weight_kg || product.weight_per_unit_kg
    self.stowage_factor ||= product.stowage_factor
    self.stackable = product.stackable if stackable.nil?
    self.max_stack_layers = product.max_stack_layers if max_stack_layers.blank? || max_stack_layers.to_i <= 1
    self.fragile = product.fragile if fragile.nil?
    self.can_rotate = product.can_rotate if can_rotate.nil?
    self.hazardous = product.hazardous if hazardous.nil?
    copy_dimensions_and_weight_from_product
  end

  def copy_dimensions_and_weight_from_product
    case count_method
    when "palete"
      self.length_cm ||= product.pallet_length_cm || product.package_length_cm || product.unit_length_cm
      self.width_cm ||= product.pallet_width_cm || product.package_width_cm || product.unit_width_cm
      self.height_cm ||= product.pallet_height_cm || product.package_height_cm || product.unit_height_cm
      self.weight_kg ||= product.pallet_weight_kg || product.package_weight_kg || product.unit_weight_kg || product.weight_per_unit_kg
    when *PACKAGE_METHODS
      self.length_cm ||= product.package_length_cm || product.unit_length_cm
      self.width_cm ||= product.package_width_cm || product.unit_width_cm
      self.height_cm ||= product.package_height_cm || product.unit_height_cm
      self.weight_kg ||= product.package_weight_kg || product.unit_weight_kg || product.weight_per_unit_kg
    else
      self.length_cm ||= product.unit_length_cm || product.package_length_cm
      self.width_cm ||= product.unit_width_cm || product.package_width_cm
      self.height_cm ||= product.unit_height_cm || product.package_height_cm
      self.weight_kg ||= product.unit_weight_kg || product.weight_per_unit_kg || product.package_weight_kg
    end
  end

  def product_belongs_to_company
    return if product.blank? || cargo.blank? || product.company_id == cargo.company_id

    errors.add(:product, "deve pertencer à mesma empresa da cubagem")
  end

  def stacking_rules
    return unless stackable == false && max_stack_layers.to_i != 1

    errors.add(:max_stack_layers, "deve ser 1 quando o item não pode empilhar")
  end

  def calculate_from_count_method
    return unless count_quantity.present?

    units_per_pack = [ units_per_package.to_i, 1 ].max
    packs_per_pallet = [ packages_per_pallet.to_i, 1 ].max
    quantity_value = count_quantity.to_d

    case count_method
    when "unidade"
      self.total_units = quantity_value.ceil
      self.total_packages = units_per_package.to_i.positive? ? (quantity_value / units_per_pack).ceil : 0
      self.total_pallets = 0
      self.calculated_volume_m3 = volume_m3 * quantity_value
      self.calculated_weight_kg = weight_kg.to_d * quantity_value
    when "palete"
      self.total_pallets = quantity_value.ceil
      self.total_packages = (quantity_value * packs_per_pallet).ceil
      self.total_units = total_packages * units_per_pack
      self.calculated_volume_m3 = volume_m3 * quantity_value
      self.calculated_weight_kg = weight_kg.to_d * quantity_value
    else
      self.total_packages = quantity_value.ceil
      self.total_units = (quantity_value * units_per_pack).ceil
      self.total_pallets = packages_per_pallet.to_i.positive? ? (quantity_value / packs_per_pallet).ceil : 0
      self.calculated_volume_m3 = volume_m3 * quantity_value
      self.calculated_weight_kg = weight_kg.to_d * quantity_value
    end

    self.calculated_packages = total_packages
    self.calculated_pallets = total_pallets
  end
end
