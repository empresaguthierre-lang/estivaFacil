class CreateVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicles, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :kind, null: false
      t.decimal :max_weight_kg, precision: 10, scale: 2, null: false
      t.decimal :max_volume_m3, precision: 10, scale: 3, null: false
      t.decimal :length_cm, precision: 10, scale: 2, null: false
      t.decimal :width_cm, precision: 10, scale: 2, null: false
      t.decimal :height_cm, precision: 10, scale: 2, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :vehicles, [ :company_id, :name ], unique: true
  end
end
