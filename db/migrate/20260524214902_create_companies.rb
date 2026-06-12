class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies, id: :uuid do |t|
      t.string :name, null: false
      t.string :document, null: false
      t.string :stripe_customer_id
      t.string :plan, null: false, default: "essencial"
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :companies, :document, unique: true
    add_index :companies, :stripe_customer_id, unique: true
  end
end
