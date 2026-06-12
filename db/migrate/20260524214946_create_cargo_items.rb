class CreateCargoItems < ActiveRecord::Migration[8.1]
  def change
    create_table :cargo_items, id: :uuid do |t|
      t.references :cargo, null: false, foreign_key: true, type: :uuid
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :length_cm, precision: 10, scale: 2, null: false
      t.decimal :width_cm, precision: 10, scale: 2, null: false
      t.decimal :height_cm, precision: 10, scale: 2, null: false
      t.decimal :weight_kg, precision: 10, scale: 2, null: false
      t.boolean :stackable, null: false, default: true
      t.boolean :fragile, null: false, default: false

      t.timestamps
    end
  end
end
