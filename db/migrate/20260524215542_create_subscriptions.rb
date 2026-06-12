class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :stripe_subscription_id
      t.string :stripe_price_id
      t.string :status, null: false, default: "trialing"
      t.datetime :current_period_end

      t.timestamps
    end

    add_index :subscriptions, :stripe_subscription_id, unique: true
  end
end
