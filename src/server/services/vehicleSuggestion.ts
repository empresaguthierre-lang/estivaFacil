export interface Vehicle {
  id?: string
  name: string
  kind: string
  body_type?: string
  maxWeightKg: number
  maxVolumeM3: number
}

export interface VehicleSuggestion {
  vehicle: Vehicle
  weightPercent: number
  volumePercent: number
  fits: boolean
  score: number
}

export function suggestVehicles(
  totalWeightKg: number,
  totalVolumeM3: number,
  vehicles: Vehicle[]
): VehicleSuggestion[] {
  if (vehicles.length === 0) return []

  const suggestions: VehicleSuggestion[] = vehicles.map((vehicle) => {
    const weightPercent =
      vehicle.maxWeightKg > 0
        ? Math.round((totalWeightKg / vehicle.maxWeightKg) * 10000) / 100
        : 999

    const volumePercent =
      vehicle.maxVolumeM3 > 0
        ? Math.round((totalVolumeM3 / vehicle.maxVolumeM3) * 10000) / 100
        : 999

    const fits = weightPercent <= 100 && volumePercent <= 100
    const score = Math.max(weightPercent, volumePercent)

    return {
      vehicle,
      weightPercent,
      volumePercent,
      fits,
      score,
    }
  })

  suggestions.sort((a, b) => {
    // Vehicles that fit come first
    if (a.fits && !b.fits) return -1
    if (!a.fits && b.fits) return 1
    // Then sort by score ascending (lowest occupation = best fit)
    return a.score - b.score
  })

  return suggestions
}

export function getOccupationColor(percent: number): string {
  if (percent <= 70) return '#22c55e' // green
  if (percent <= 90) return '#eab308' // yellow
  return '#ef4444' // red
}

export function getOccupationLabel(percent: number): string {
  if (percent <= 70) return 'Ideal'
  if (percent <= 90) return 'Atenção'
  if (percent <= 100) return 'Limite'
  return 'Excede'
}
