class CreateCargos < ActiveRecord::Migration[8.1]
  def change
    create_table :cargos, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :customer_name, null: false
      t.string :origin, null: false
      t.string :destination, null: false
      t.integer :status, null: false, default: 0
      t.decimal :total_weight_kg, precision: 10, scale: 2, null: false, default: 0
      t.decimal :total_volume_m3, precision: 10, scale: 3, null: false, default: 0
      t.references :recommended_vehicle, null: true, foreign_key: { to_table: :vehicles }, type: :uuid

      t.timestamps
    end

    add_index :cargos, [ :company_id, :status ]
  end
end
