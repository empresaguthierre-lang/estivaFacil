class CreatePackageBoxes < ActiveRecord::Migration[8.1]
  def change
    create_table :package_boxes, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.decimal :length_cm, precision: 10, scale: 2, null: false
      t.decimal :width_cm, precision: 10, scale: 2, null: false
      t.decimal :height_cm, precision: 10, scale: 2, null: false
      t.integer :units_per_package, null: false, default: 1
      t.decimal :package_weight_kg, precision: 10, scale: 2, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :package_boxes, [ :company_id, :name ], unique: true
  end
end
