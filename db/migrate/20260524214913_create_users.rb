class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 1
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :users, [ :company_id, :email ], unique: true
  end
end
