# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_25_180100) do
  create_schema "extensions"

  # These are extensions that must be enabled in order to support this database
  enable_extension "extensions.pg_stat_statements"
  enable_extension "extensions.pgcrypto"
  enable_extension "extensions.uuid-ossp"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vault.supabase_vault"

  create_table "public.active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "public.active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "public.active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "public.cargo_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "calculated_packages", default: 0, null: false
    t.integer "calculated_pallets", default: 0, null: false
    t.decimal "calculated_volume_m3", precision: 10, scale: 3, default: "0.0", null: false
    t.decimal "calculated_weight_kg", precision: 10, scale: 2, default: "0.0", null: false
    t.boolean "can_rotate", default: true, null: false
    t.uuid "cargo_id", null: false
    t.string "count_method", default: "unidade", null: false
    t.decimal "count_quantity", precision: 12, scale: 3
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.boolean "fragile", default: false, null: false
    t.boolean "hazardous", default: false, null: false
    t.decimal "height_cm", precision: 10, scale: 2, null: false
    t.decimal "length_cm", precision: 10, scale: 2, null: false
    t.string "loading_priority", default: "normal", null: false
    t.integer "max_stack_layers", default: 1, null: false
    t.text "notes"
    t.string "package_label"
    t.string "package_name_snapshot"
    t.integer "packages_per_pallet"
    t.uuid "product_id"
    t.string "product_imp_code_snapshot"
    t.string "product_internal_code_snapshot"
    t.string "product_name_snapshot"
    t.string "product_ref_code_snapshot"
    t.integer "quantity", default: 1, null: false
    t.boolean "stackable", default: true, null: false
    t.decimal "stowage_factor", precision: 10, scale: 3
    t.integer "total_packages", default: 0, null: false
    t.integer "total_pallets", default: 0, null: false
    t.integer "total_units", default: 0, null: false
    t.integer "units_per_package"
    t.datetime "updated_at", null: false
    t.decimal "weight_kg", precision: 10, scale: 2, null: false
    t.decimal "weight_per_unit_kg", precision: 10, scale: 3
    t.decimal "width_cm", precision: 10, scale: 2, null: false
    t.index ["cargo_id"], name: "index_cargo_items_on_cargo_id"
    t.index ["product_id"], name: "index_cargo_items_on_product_id"
  end

  create_table "public.cargos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "customer_name", null: false
    t.string "destination", null: false
    t.string "origin", null: false
    t.uuid "recommended_vehicle_id"
    t.integer "status", default: 0, null: false
    t.integer "total_packages", default: 0, null: false
    t.integer "total_pallets", default: 0, null: false
    t.integer "total_units", default: 0, null: false
    t.decimal "total_volume_m3", precision: 10, scale: 3, default: "0.0", null: false
    t.decimal "total_weight_kg", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["company_id", "status"], name: "index_cargos_on_company_id_and_status"
    t.index ["company_id"], name: "index_cargos_on_company_id"
    t.index ["recommended_vehicle_id"], name: "index_cargos_on_recommended_vehicle_id"
    t.index ["user_id"], name: "index_cargos_on_user_id"
  end

  create_table "public.companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "document", null: false
    t.string "name", null: false
    t.string "plan", default: "essencial", null: false
    t.integer "status", default: 0, null: false
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
    t.index ["document"], name: "index_companies_on_document", unique: true
    t.index ["stripe_customer_id"], name: "index_companies_on_stripe_customer_id", unique: true
  end

  create_table "public.package_boxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.decimal "height_cm", precision: 10, scale: 2, null: false
    t.decimal "length_cm", precision: 10, scale: 2, null: false
    t.string "name", null: false
    t.decimal "package_weight_kg", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "units_per_package", default: 1, null: false
    t.datetime "updated_at", null: false
    t.decimal "width_cm", precision: 10, scale: 2, null: false
    t.index ["company_id", "name"], name: "index_package_boxes_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_package_boxes_on_company_id"
  end

  create_table "public.products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "can_rotate", default: true, null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "default_count_method", default: "unidade", null: false
    t.text "description"
    t.boolean "fragile", default: false, null: false
    t.boolean "hazardous", default: false, null: false
    t.string "imp_code"
    t.string "internal_code", null: false
    t.integer "max_stack_layers", default: 1, null: false
    t.string "name", null: false
    t.uuid "package_box_id"
    t.decimal "package_height_cm", precision: 10, scale: 2
    t.string "package_label"
    t.decimal "package_length_cm", precision: 10, scale: 2
    t.decimal "package_weight_kg", precision: 10, scale: 3
    t.decimal "package_width_cm", precision: 10, scale: 2
    t.integer "packages_per_pallet", default: 1, null: false
    t.decimal "pallet_height_cm", precision: 10, scale: 2
    t.decimal "pallet_length_cm", precision: 10, scale: 2
    t.decimal "pallet_weight_kg", precision: 10, scale: 3
    t.decimal "pallet_width_cm", precision: 10, scale: 2
    t.string "ref_code"
    t.string "reference_code"
    t.string "sku"
    t.boolean "stackable", default: true, null: false
    t.decimal "stowage_factor", precision: 10, scale: 3, default: "1.0", null: false
    t.string "unit", default: "un", null: false
    t.decimal "unit_height_cm", precision: 10, scale: 2
    t.decimal "unit_length_cm", precision: 10, scale: 2
    t.decimal "unit_weight_kg", precision: 10, scale: 3
    t.decimal "unit_width_cm", precision: 10, scale: 2
    t.integer "units_per_package"
    t.datetime "updated_at", null: false
    t.decimal "weight_per_unit_kg", precision: 10, scale: 3, null: false
    t.index ["company_id", "imp_code"], name: "index_products_on_company_id_and_imp_code"
    t.index ["company_id", "internal_code"], name: "index_products_on_company_id_and_internal_code", unique: true
    t.index ["company_id", "name"], name: "index_products_on_company_id_and_name"
    t.index ["company_id", "ref_code"], name: "index_products_on_company_id_and_ref_code"
    t.index ["company_id", "reference_code"], name: "index_products_on_company_id_and_reference_code"
    t.index ["company_id", "sku"], name: "index_products_on_company_id_and_sku"
    t.index ["company_id"], name: "index_products_on_company_id"
    t.index ["package_box_id"], name: "index_products_on_package_box_id"
  end

  create_table "public.stowage_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cargo_id", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.text "loading_sequence"
    t.text "notes"
    t.integer "package_count", default: 0, null: false
    t.integer "pallet_count", default: 0, null: false
    t.text "recommendations"
    t.decimal "score", precision: 5, scale: 2, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.integer "unit_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "vehicle_id", null: false
    t.decimal "volume_usage_percent", precision: 6, scale: 2, default: "0.0", null: false
    t.text "warnings"
    t.decimal "weight_usage_percent", precision: 6, scale: 2, default: "0.0", null: false
    t.index ["cargo_id"], name: "index_stowage_plans_on_cargo_id"
    t.index ["company_id", "cargo_id"], name: "index_stowage_plans_on_company_id_and_cargo_id"
    t.index ["company_id"], name: "index_stowage_plans_on_company_id"
    t.index ["vehicle_id"], name: "index_stowage_plans_on_vehicle_id"
  end

  create_table "public.subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.string "status", default: "trialing", null: false
    t.string "stripe_price_id"
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_subscriptions_on_company_id"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
  end

  create_table "public.users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "email"], name: "index_users_on_company_id_and_email", unique: true
    t.index ["company_id"], name: "index_users_on_company_id"
  end

  create_table "public.vehicles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "allows_hazardous", default: true, null: false
    t.string "body_type"
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.decimal "height_cm", precision: 10, scale: 2, null: false
    t.string "kind", null: false
    t.decimal "length_cm", precision: 10, scale: 2, null: false
    t.decimal "max_volume_m3", precision: 10, scale: 3, null: false
    t.decimal "max_weight_kg", precision: 10, scale: 2, null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "pallet_capacity"
    t.boolean "refrigerated", default: false, null: false
    t.datetime "updated_at", null: false
    t.decimal "usable_height_cm", precision: 10, scale: 2
    t.decimal "usable_length_cm", precision: 10, scale: 2
    t.decimal "usable_width_cm", precision: 10, scale: 2
    t.decimal "width_cm", precision: 10, scale: 2, null: false
    t.index ["company_id", "name"], name: "index_vehicles_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_vehicles_on_company_id"
  end

  add_foreign_key "public.active_storage_attachments", "public.active_storage_blobs", column: "blob_id"
  add_foreign_key "public.active_storage_variant_records", "public.active_storage_blobs", column: "blob_id"
  add_foreign_key "public.cargo_items", "public.cargos"
  add_foreign_key "public.cargo_items", "public.products"
  add_foreign_key "public.cargos", "public.companies"
  add_foreign_key "public.cargos", "public.users"
  add_foreign_key "public.cargos", "public.vehicles", column: "recommended_vehicle_id"
  add_foreign_key "public.package_boxes", "public.companies"
  add_foreign_key "public.products", "public.companies"
  add_foreign_key "public.products", "public.package_boxes"
  add_foreign_key "public.stowage_plans", "public.cargos"
  add_foreign_key "public.stowage_plans", "public.companies"
  add_foreign_key "public.stowage_plans", "public.vehicles"
  add_foreign_key "public.subscriptions", "public.companies"
  add_foreign_key "public.users", "public.companies"
  add_foreign_key "public.vehicles", "public.companies"

end
