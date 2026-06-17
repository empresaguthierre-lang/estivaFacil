export interface CubageInput {
  quantity: number
  unitsPerPackage: number
  packageLengthCm: number
  packageWidthCm: number
  packageHeightCm: number
  packageWeightKg: number
  volumeMultiplier: number
}

export interface CubageResult {
  totalPackages: number
  totalVolumes: number
  totalWeightKg: number
  totalVolumeM3: number
  unitVolumeM3: number
}

export function calculateCubage(input: CubageInput): CubageResult {
  const {
    quantity,
    unitsPerPackage,
    packageLengthCm,
    packageWidthCm,
    packageHeightCm,
    packageWeightKg,
    volumeMultiplier,
  } = input

  const safeUnitsPerPackage = Math.max(unitsPerPackage, 1)
  const safeMultiplier = Math.max(volumeMultiplier, 1)

  const totalPackages = Math.ceil(quantity / safeUnitsPerPackage)
  const totalVolumes = totalPackages * safeMultiplier
  const unitVolumeM3 = (packageLengthCm * packageWidthCm * packageHeightCm) / 1_000_000
  const totalVolumeM3 = totalPackages * unitVolumeM3
  const totalWeightKg = totalPackages * packageWeightKg

  return {
    totalPackages,
    totalVolumes,
    totalWeightKg,
    totalVolumeM3: Math.round(totalVolumeM3 * 1_000_000) / 1_000_000,
    unitVolumeM3: Math.round(unitVolumeM3 * 1_000_000) / 1_000_000,
  }
}
