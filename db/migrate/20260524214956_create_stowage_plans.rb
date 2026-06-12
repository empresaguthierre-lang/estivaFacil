class CreateStowagePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :stowage_plans, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :cargo, null: false, foreign_key: true, type: :uuid
      t.references :vehicle, null: false, foreign_key: true, type: :uuid
      t.integer :status, null: false, default: 0
      t.decimal :score, precision: 5, scale: 2, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :stowage_plans, [ :company_id, :cargo_id ]
  end
end
