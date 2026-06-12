class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :vehicles, dependent: :destroy
  has_many :package_boxes, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :cargos, dependent: :destroy
  has_many :stowage_plans, dependent: :destroy
  has_one :subscription, dependent: :destroy

  enum :status, { ativa: 0, suspensa: 1, cancelada: 2 }

  validates :name, :document, :plan, presence: true
  validates :document, uniqueness: true
end
