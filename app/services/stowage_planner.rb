class StowagePlanner
  def self.call(cargo)
    new(cargo).call
  end

  def self.recommend_vehicle_for(cargo)
    new(cargo).recommend_vehicle
  end

  def initialize(cargo)
    @cargo = cargo
  end

  def call
    vehicle = @cargo.recommended_vehicle || recommend_vehicle
    return nil unless vehicle

    StowagePlan.create!(
      company: @cargo.company,
      cargo: @cargo,
      vehicle: vehicle,
      score: score_for(vehicle),
      volume_usage_percent: volume_usage_for(vehicle),
      weight_usage_percent: weight_usage_for(vehicle),
      pallet_count: @cargo.total_pallets,
      package_count: @cargo.total_packages,
      unit_count: @cargo.total_units,
      warnings: warnings_for(vehicle).join("\n"),
      recommendations: recommendations_for(vehicle).join("\n"),
      loading_sequence: loading_sequence.join("\n"),
      notes: notes_for(vehicle)
    )
  end

  def recommend_vehicle
    @cargo.company.vehicles.ativos
      .select { |vehicle| vehicle_supports_basic_load?(vehicle) }
      .min_by { |vehicle| [ score_for(vehicle), vehicle.max_volume_m3, vehicle.max_weight_kg ] }
  end

  private

  def vehicle_supports_basic_load?(vehicle)
    vehicle.suporta?(volume_m3: @cargo.total_volume_m3, peso_kg: @cargo.total_weight_kg) &&
      vehicle.usable_height.to_d >= max_item_height &&
      (vehicle.pallet_capacity.blank? || vehicle.pallet_capacity >= @cargo.total_pallets) &&
      (vehicle.allows_hazardous? || hazardous_items.empty?)
  end

  def score_for(vehicle)
    volume_usage = volume_usage_for(vehicle)
    weight_usage = weight_usage_for(vehicle)
    target_usage = ((volume_usage + weight_usage) / 2)
    free_space_penalty = [ 55 - target_usage, 0 ].max * 0.45
    fragility_penalty = fragile_items.any? ? 4 : 0
    hazardous_penalty = hazardous_items.any? ? 5 : 0
    stacking_penalty = non_stackable_items.count * 2
    pallet_penalty = vehicle.pallet_capacity.present? ? [ @cargo.total_pallets - vehicle.pallet_capacity, 0 ].max * 20 : 0

    raw_score = 100 - target_usage + free_space_penalty + fragility_penalty + hazardous_penalty + stacking_penalty + pallet_penalty
    raw_score.clamp(0, 100).round(2)
  end

  def volume_usage_for(vehicle)
    return 0 if vehicle.max_volume_m3.to_d.zero?

    ((@cargo.total_volume_m3.to_d / vehicle.max_volume_m3.to_d) * 100).round(2)
  end

  def weight_usage_for(vehicle)
    return 0 if vehicle.max_weight_kg.to_d.zero?

    ((@cargo.total_weight_kg.to_d / vehicle.max_weight_kg.to_d) * 100).round(2)
  end

  def warnings_for(vehicle)
    warnings = []
    warnings << "Carga acima do peso permitido para #{vehicle.name}." if @cargo.total_weight_kg.to_d > vehicle.max_weight_kg.to_d
    warnings << "Volume acima da capacidade útil de #{vehicle.name}." if @cargo.total_volume_m3.to_d > vehicle.max_volume_m3.to_d
    warnings << "Existem #{fragile_items.count} item(ns) frágil(is) que não devem receber carga por cima." if fragile_items.any?
    warnings << "Existem #{non_stackable_items.count} item(ns) não empilhável(is)." if non_stackable_items.any?
    warnings << "Existem #{hazardous_items.count} item(ns) perigoso(s) que exigem segregação e conferência." if hazardous_items.any?
    warnings << "Existem item(ns) que não podem ser girados no carregamento." if fixed_rotation_items.any?
    warnings << "Altura de item/palete maior que a altura útil do veículo." if max_item_height > vehicle.usable_height.to_d
    warnings << "Baixa ocupação do veículo: volume abaixo de 45%." if volume_usage_for(vehicle) < 45
    warnings << "Veículo escolhido com folga excessiva de peso." if weight_usage_for(vehicle) < 35
    warnings
  end

  def recommendations_for(vehicle)
    recommendations = []
    recommendations << "Carregar os itens pesados primeiro e manter o centro de gravidade baixo."
    recommendations << "Separar produtos perigosos e conferir compatibilidade com a carroceria." if hazardous_items.any?
    recommendations << "Manter itens frágeis por último e sem empilhamento sobre eles." if fragile_items.any?
    recommendations << "Respeitar limite de camadas informado para cada produto empilhável." if @cargo.cargo_items.any?(&:stackable?)
    recommendations << "Conferir amarração e distribuição lateral antes da saída."
    recommendations << "Veículo sugerido: #{vehicle.name}. Ocupação por volume: #{volume_usage_for(vehicle)}%. Ocupação por peso: #{weight_usage_for(vehicle)}%."
    recommendations
  end

  def loading_sequence
    first = @cargo.cargo_items.select { |item| item.loading_priority == "carregar_primeiro" }
    normal = @cargo.cargo_items.select { |item| item.loading_priority == "normal" }
    last = @cargo.cargo_items.select { |item| item.loading_priority == "carregar_por_ultimo" }

    (first + normal + last).map.with_index(1) do |item, index|
      "#{index}. #{item.description} - #{item.count_quantity.to_i} #{item.count_method}"
    end
  end

  def notes_for(vehicle)
    warning_text = warnings_for(vehicle).presence&.join(" ") || "Sem alertas críticos."
    recommendation_text = recommendations_for(vehicle).join(" ")
    "Veículo sugerido: #{vehicle.name}. Ocupação por volume: #{volume_usage_for(vehicle)}%. Ocupação por peso: #{weight_usage_for(vehicle)}%. #{warning_text} #{recommendation_text}"
  end

  def fragile_items
    @fragile_items ||= @cargo.cargo_items.select(&:fragile?)
  end

  def hazardous_items
    @hazardous_items ||= @cargo.cargo_items.select(&:hazardous?)
  end

  def non_stackable_items
    @non_stackable_items ||= @cargo.cargo_items.reject(&:stackable?)
  end

  def fixed_rotation_items
    @fixed_rotation_items ||= @cargo.cargo_items.reject(&:can_rotate?)
  end

  def max_item_height
    @max_item_height ||= @cargo.cargo_items.map { |item| item.height_cm.to_d }.max || 0
  end
end
