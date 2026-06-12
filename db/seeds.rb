company = Company.find_or_create_by!(document: "00.000.000/0001-00") do |record|
  record.name = "EstivaFácil Demo"
  record.plan = "profissional"
  record.status = :ativa
end

User.find_or_create_by!(company: company, email: "admin@estivafacil.local") do |record|
  record.name = "Admin Demo"
  record.password = "senha123"
  record.password_confirmation = "senha123"
  record.role = :admin
  record.active = true
end

[
  [ "VUC", "Urbano", 1_500, 12.0, 320, 190, 190, 4, "Baú" ],
  [ "Toco", "Distribuição", 6_000, 32.0, 620, 240, 220, 12, "Baú" ],
  [ "Truck", "Rodoviário", 14_000, 54.0, 800, 250, 270, 18, "Sider" ],
  [ "Carreta", "Rodoviário", 27_000, 90.0, 1_360, 250, 280, 28, "Sider" ]
].each do |name, kind, weight, volume, length, width, height, pallets, body_type|
  vehicle = Vehicle.find_or_initialize_by(company: company, name: name)
  vehicle.assign_attributes(
    kind: kind,
    max_weight_kg: weight,
    max_volume_m3: volume,
    length_cm: length,
    width_cm: width,
    height_cm: height,
    usable_length_cm: length,
    usable_width_cm: width,
    usable_height_cm: height,
    pallet_capacity: pallets,
    body_type: body_type,
    allows_hazardous: true,
    refrigerated: false,
    active: true
  )
  vehicle.save!
end

standard_box = PackageBox.find_or_create_by!(company: company, name: "Caixa padrão 60x40x40") do |record|
  record.length_cm = 60
  record.width_cm = 40
  record.height_cm = 40
  record.units_per_package = 12
  record.package_weight_kg = 0.4
  record.active = true
end

products = [
  {
    name: "Coca-Cola 2L",
    sku: "REF-COCA-2L",
    reference_code: "REF-COCA-2L",
    package_label: "caixa",
    default_count_method: "caixa",
    units_per_package: 6,
    packages_per_pallet: 80,
    package_weight_kg: 13,
    package_length_cm: 40,
    package_width_cm: 30,
    package_height_cm: 32,
    pallet_weight_kg: 1040,
    pallet_length_cm: 120,
    pallet_width_cm: 100,
    pallet_height_cm: 180,
    stackable: true,
    max_stack_layers: 5,
    fragile: false,
    can_rotate: true,
    hazardous: false
  },
  {
    name: "Água mineral 500ml",
    sku: "REF-AGUA-500",
    reference_code: "REF-AGUA-500",
    package_label: "fardo",
    default_count_method: "fardo",
    units_per_package: 24,
    packages_per_pallet: 60,
    package_weight_kg: 13,
    package_length_cm: 40,
    package_width_cm: 25,
    package_height_cm: 22,
    pallet_weight_kg: 780,
    pallet_length_cm: 120,
    pallet_width_cm: 100,
    pallet_height_cm: 160,
    stackable: true,
    max_stack_layers: 6,
    fragile: false,
    can_rotate: true,
    hazardous: false
  },
  {
    name: "Caixa de vidro",
    sku: "REF-VIDRO-001",
    reference_code: "REF-VIDRO-001",
    package_label: "caixa",
    default_count_method: "caixa",
    units_per_package: 12,
    packages_per_pallet: 40,
    package_weight_kg: 18,
    package_length_cm: 50,
    package_width_cm: 35,
    package_height_cm: 30,
    stackable: false,
    max_stack_layers: 1,
    fragile: true,
    can_rotate: false,
    hazardous: false
  },
  {
    name: "Tambor químico 200L",
    sku: "REF-TAMBOR-200",
    reference_code: "REF-TAMBOR-200",
    package_label: "unidade",
    default_count_method: "unidade",
    units_per_package: 1,
    packages_per_pallet: 4,
    unit_weight_kg: 220,
    unit_length_cm: 60,
    unit_width_cm: 60,
    unit_height_cm: 90,
    stackable: false,
    max_stack_layers: 1,
    fragile: false,
    hazardous: true,
    can_rotate: false
  },
  {
    name: "Saco de ração 25kg",
    sku: "REF-RACAO-25",
    reference_code: "REF-RACAO-25",
    package_label: "saco",
    default_count_method: "unidade",
    units_per_package: 1,
    packages_per_pallet: 50,
    unit_weight_kg: 25,
    unit_length_cm: 70,
    unit_width_cm: 45,
    unit_height_cm: 12,
    stackable: true,
    max_stack_layers: 10,
    fragile: false,
    can_rotate: true,
    hazardous: false
  }
]

products.each_with_index do |attributes, index|
  product = Product.find_or_initialize_by(company: company, sku: attributes[:sku])
  product.assign_attributes(
    attributes.merge(
      internal_code: "LOG-#{index + 1001}",
      ref_code: attributes[:reference_code],
      unit: "un",
      description: "#{attributes[:name]} para testes de cubagem e estiva.",
      stowage_factor: 1,
      package_box: standard_box,
      weight_per_unit_kg: attributes[:unit_weight_kg] || attributes[:package_weight_kg] || 1,
      active: true
    )
  )
  product.save!
end
