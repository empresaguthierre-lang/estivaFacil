class AddProductSnapshotsAndTotalsToCargoItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :cargo_items, :product, null: true, foreign_key: true, type: :uuid
    add_column :cargo_items, :product_internal_code_snapshot, :string
    add_column :cargo_items, :product_ref_code_snapshot, :string
    add_column :cargo_items, :product_imp_code_snapshot, :string
    add_column :cargo_items, :product_name_snapshot, :string
    add_column :cargo_items, :package_name_snapshot, :string
    add_column :cargo_items, :units_per_package, :integer
    add_column :cargo_items, :packages_per_pallet, :integer
    add_column :cargo_items, :weight_per_unit_kg, :decimal, precision: 10, scale: 3
    add_column :cargo_items, :stowage_factor, :decimal, precision: 10, scale: 3
    add_column :cargo_items, :calculated_packages, :integer, null: false, default: 0
    add_column :cargo_items, :calculated_pallets, :integer, null: false, default: 0
    add_column :cargo_items, :calculated_weight_kg, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :cargo_items, :calculated_volume_m3, :decimal, precision: 10, scale: 3, null: false, default: 0
  end
end
