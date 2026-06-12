class Cargo < ApplicationRecord
  belongs_to :company
  belongs_to :user
  belongs_to :recommended_vehicle, class_name: "Vehicle", optional: true
  has_many :cargo_items, dependent: :destroy
  has_one :stowage_plan, dependent: :destroy
  has_one_attached :invoice

  accepts_nested_attributes_for :cargo_items, allow_destroy: true, reject_if: :all_blank

  enum :status, {
    rascunho: 0,
    calculada: 1,
    aguardando_aprovacao: 2,
    aprovada: 3,
    em_separacao: 4,
    em_carregamento: 5,
    carregada: 6,
    despachada: 7,
    entregue: 8,
    cancelada: 9
  }

  validates :customer_name, :origin, :destination, presence: true
  validates :cargo_items, presence: true
  validates_associated :cargo_items

  before_validation :recalculate_totals

  def recalculate_totals
    cargo_items.each(&:valid?)
    self.total_units = cargo_items.sum { |item| item.total_units.to_i }
    self.total_packages = cargo_items.sum { |item| item.total_packages.to_i }
    self.total_pallets = cargo_items.sum { |item| item.total_pallets.to_i }
    self.total_weight_kg = cargo_items.sum(&:total_weight_kg)
    self.total_volume_m3 = cargo_items.sum(&:total_volume_m3)
    self.recommended_vehicle = StowagePlanner.recommend_vehicle_for(self) if company.present?
  end
end
