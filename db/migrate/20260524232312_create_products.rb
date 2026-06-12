class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :package_box, null: false, foreign_key: true, type: :uuid
      t.string :internal_code, null: false
      t.string :ref_code
      t.string :imp_code
      t.string :name, null: false
      t.text :description
      t.string :unit, null: false, default: "un"
      t.decimal :weight_per_unit_kg, precision: 10, scale: 3, null: false
      t.decimal :stowage_factor, precision: 10, scale: 3, null: false, default: 1
      t.integer :packages_per_pallet, null: false, default: 1
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :products, [ :company_id, :internal_code ], unique: true
    add_index :products, [ :company_id, :ref_code ]
    add_index :products, [ :company_id, :imp_code ]
    add_index :products, [ :company_id, :name ]
  end
end
