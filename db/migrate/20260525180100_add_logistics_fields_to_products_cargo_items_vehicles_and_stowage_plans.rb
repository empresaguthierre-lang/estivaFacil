class AddLogisticsFieldsToProductsCargoItemsVehiclesAndStowagePlans < ActiveRecord::Migration[8.1]
  def change
    change_column_null :products, :package_box_id, true

    change_table :products, bulk: true do |t|
      t.string :sku
      t.string :reference_code
      t.string :default_count_method, null: false, default: "unidade"
      t.string :package_label
      t.integer :units_per_package
      t.decimal :unit_weight_kg, precision: 10, scale: 3
      t.decimal :package_weight_kg, precision: 10, scale: 3
      t.decimal :pallet_weight_kg, precision: 10, scale: 3
      t.decimal :unit_length_cm, precision: 10, scale: 2
      t.decimal :unit_width_cm, precision: 10, scale: 2
      t.decimal :unit_height_cm, precision: 10, scale: 2
      t.decimal :package_length_cm, precision: 10, scale: 2
      t.decimal :package_width_cm, precision: 10, scale: 2
      t.decimal :package_height_cm, precision: 10, scale: 2
      t.decimal :pallet_length_cm, precision: 10, scale: 2
      t.decimal :pallet_width_cm, precision: 10, scale: 2
      t.decimal :pallet_height_cm, precision: 10, scale: 2
      t.boolean :stackable, null: false, default: true
      t.integer :max_stack_layers, null: false, default: 1
      t.boolean :fragile, null: false, default: false
      t.boolean :can_rotate, null: false, default: true
      t.boolean :hazardous, null: false, default: false
    end

    add_index :products, [ :company_id, :sku ]
    add_index :products, [ :company_id, :reference_code ]

    change_table :cargo_items, bulk: true do |t|
      t.string :count_method, null: false, default: "unidade"
      t.decimal :count_quantity, precision: 12, scale: 3
      t.string :package_label
      t.integer :total_units, null: false, default: 0
      t.integer :total_packages, null: false, default: 0
      t.integer :total_pallets, null: false, default: 0
      t.boolean :can_rotate, null: false, default: true
      t.boolean :hazardous, null: false, default: false
      t.integer :max_stack_layers, null: false, default: 1
      t.string :loading_priority, null: false, default: "normal"
      t.text :notes
    end

    add_column :cargos, :total_units, :integer, null: false, default: 0

    change_table :vehicles, bulk: true do |t|
      t.integer :pallet_capacity
      t.string :body_type
      t.decimal :usable_height_cm, precision: 10, scale: 2
      t.decimal :usable_width_cm, precision: 10, scale: 2
      t.decimal :usable_length_cm, precision: 10, scale: 2
      t.boolean :allows_hazardous, null: false, default: true
      t.boolean :refrigerated, null: false, default: false
      t.text :notes
    end

    change_table :stowage_plans, bulk: true do |t|
      t.decimal :volume_usage_percent, precision: 6, scale: 2, null: false, default: 0
      t.decimal :weight_usage_percent, precision: 6, scale: 2, null: false, default: 0
      t.integer :pallet_count, null: false, default: 0
      t.integer :package_count, null: false, default: 0
      t.integer :unit_count, null: false, default: 0
      t.text :warnings
      t.text :recommendations
      t.text :loading_sequence
    end
  end
end
