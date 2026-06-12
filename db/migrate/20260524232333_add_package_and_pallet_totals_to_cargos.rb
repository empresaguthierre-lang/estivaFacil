class AddPackageAndPalletTotalsToCargos < ActiveRecord::Migration[8.1]
  def change
    add_column :cargos, :total_packages, :integer, null: false, default: 0
    add_column :cargos, :total_pallets, :integer, null: false, default: 0
  end
end
