class Product < ApplicationRecord
  COUNT_METHODS = %w[unidade caixa fardo pacote palete outro].freeze

  belongs_to :company
  belongs_to :package_box, optional: true

  has_many :cargo_items, dependent: :restrict_with_error

  scope :ativos, -> { where(active: true) }
  scope :search, ->(term) {
    next all if term.blank?

    where("name ILIKE :term OR sku ILIKE :term OR reference_code ILIKE :term OR internal_code ILIKE :term OR ref_code ILIKE :term", term: "%#{sanitize_sql_like(term)}%")
  }

  validates :name, :default_count_method, presence: true
  validates :internal_code, uniqueness: { scope: :company_id }, allow_blank: true
  validates :default_count_method, inclusion: { in: COUNT_METHODS }
  validates :units_per_package, :packages_per_pallet, numericality: { only_integer: true, greater_than: 0 }, allow_blank: true
  validates :unit_weight_kg, :package_weight_kg, :pallet_weight_kg, :weight_per_unit_kg, numericality: { greater_than: 0 }, allow_blank: true
  validates :unit_length_cm, :unit_width_cm, :unit_height_cm,
            :package_length_cm, :package_width_cm, :package_height_cm,
            :pallet_length_cm, :pallet_width_cm, :pallet_height_cm,
            numericality: { greater_than: 0 }, allow_blank: true
  validates :max_stack_layers, numericality: { only_integer: true, greater_than: 0 }
  validate :package_box_belongs_to_company
  validate :stacking_rules
  validate :count_method_requirements

  before_validation :normalize_legacy_fields

  def search_label
    [ commercial_code, sku, reference_code, name ].compact_blank.join(" | ")
  end

  def commercial_code
    internal_code.presence || sku
  end

  def package_name
    package_label.presence || package_box&.name
  end

  def product_payload
    {
      id: id,
      name: name,
      description: description.presence || name,
      count_method: default_count_method,
      package_label: package_name,
      units_per_package: units_per_package,
      packages_per_pallet: packages_per_pallet,
      unit_weight_kg: unit_weight_kg || weight_per_unit_kg,
      package_weight_kg: package_weight_kg,
      pallet_weight_kg: pallet_weight_kg,
      unit_length_cm: unit_length_cm,
      unit_width_cm: unit_width_cm,
      unit_height_cm: unit_height_cm,
      package_length_cm: package_length_cm,
      package_width_cm: package_width_cm,
      package_height_cm: package_height_cm,
      pallet_length_cm: pallet_length_cm,
      pallet_width_cm: pallet_width_cm,
      pallet_height_cm: pallet_height_cm,
      stackable: stackable,
      max_stack_layers: max_stack_layers,
      fragile: fragile,
      can_rotate: can_rotate,
      hazardous: hazardous
    }
  end

  private

  def normalize_legacy_fields
    self.internal_code = sku if internal_code.blank? && sku.present?
    self.sku = internal_code if sku.blank? && internal_code.present?
    self.reference_code = ref_code if reference_code.blank? && ref_code.present?
    self.ref_code = reference_code if ref_code.blank? && reference_code.present?
    self.unit = "un" if unit.blank?
    self.stowage_factor = 1 if stowage_factor.blank?
    self.package_label = package_box&.name if package_label.blank? && package_box.present?
    self.units_per_package ||= package_box&.units_per_package
    self.package_weight_kg ||= package_box&.package_weight_kg
    self.package_length_cm ||= package_box&.length_cm
    self.package_width_cm ||= package_box&.width_cm
    self.package_height_cm ||= package_box&.height_cm
    self.unit_weight_kg ||= weight_per_unit_kg
    self.weight_per_unit_kg ||= unit_weight_kg || package_weight_kg || pallet_weight_kg || 1
    self.packages_per_pallet ||= 1
    self.max_stack_layers = 1 unless stackable?
  end

  def package_box_belongs_to_company
    return if package_box.blank? || package_box.company_id == company_id

    errors.add(:package_box, "deve pertencer à mesma empresa")
  end

  def stacking_rules
    return unless stackable == false && max_stack_layers.to_i != 1

    errors.add(:max_stack_layers, "deve ser 1 quando o produto não pode empilhar")
  end

  def count_method_requirements
    if %w[caixa fardo pacote].include?(default_count_method) && units_per_package.to_i <= 0
      errors.add(:units_per_package, "deve ser maior que zero para contagem por embalagem")
    end

    return unless default_count_method == "palete" && packages_per_pallet.to_i <= 0

    errors.add(:packages_per_pallet, "deve ser maior que zero para contagem por palete")
  end
end
