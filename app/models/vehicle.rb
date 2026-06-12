class Vehicle < ApplicationRecord
  belongs_to :company

  scope :ativos, -> { where(active: true) }

  validates :name, :kind, :max_weight_kg, :max_volume_m3, :length_cm, :width_cm, :height_cm, presence: true
  validates :name, uniqueness: { scope: :company_id }
  validates :max_weight_kg, :max_volume_m3, :length_cm, :width_cm, :height_cm, numericality: { greater_than: 0 }
  validates :pallet_capacity, numericality: { only_integer: true, greater_than: 0 }, allow_blank: true

  def suporta?(volume_m3:, peso_kg:)
    max_volume_m3 >= volume_m3 && max_weight_kg >= peso_kg
  end

  def usable_length
    usable_length_cm || length_cm
  end

  def usable_width
    usable_width_cm || width_cm
  end

  def usable_height
    usable_height_cm || height_cm
  end
end
