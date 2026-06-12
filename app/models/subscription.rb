class Subscription < ApplicationRecord
  belongs_to :company

  validates :stripe_subscription_id, uniqueness: true, allow_blank: true
  validates :status, presence: true
end
