class PackageBox < ApplicationRecord
  belongs_to :company
  has_many :products, dependent: :restrict_with_error

  scope :ativos, -> { where(active: true) }

  validates :name, :length_cm, :width_cm, :height_cm, :units_per_package, :package_weight_kg, presence: true
  validates :name, uniqueness: { scope: :company_id }
  validates :length_cm, :width_cm, :height_cm, numericality: { greater_than: 0 }
  validates :units_per_package, numericality: { only_integer: true, greater_than: 0 }
  validates :package_weight_kg, numericality: { greater_than_or_equal_to: 0 }

  def volume_m3
    (length_cm * width_cm * height_cm) / 1_000_000
  end
end
