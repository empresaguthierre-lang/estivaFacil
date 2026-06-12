class User < ApplicationRecord
  belongs_to :company

  has_secure_password

  enum :role, { admin: 0, operador: 1, vendedor: 2 }

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, :email, :role, presence: true
  validates :email, uniqueness: { scope: :company_id }
end
