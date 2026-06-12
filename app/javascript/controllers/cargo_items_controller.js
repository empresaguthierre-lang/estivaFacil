import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  connect() {
    this.listTarget.querySelectorAll("[data-cargo-items-row]").forEach((row) => this.previewRow(row))
  }

  add(event) {
    event.preventDefault()
    const id = new Date().getTime().toString()
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", id)
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-cargo-items-row]")
    const destroyField = row.querySelector("input[name*='[_destroy]']")

    if (destroyField) {
      destroyField.value = "1"
    }

    row.remove()
  }

  productChanged(event) {
    const row = event.target.closest("[data-cargo-items-row]")
    const option = event.target.selectedOptions[0]
    const product = option?.dataset.product ? JSON.parse(option.dataset.product) : null

    if (!product) return

    this.setValue(row, "description", product.description)
    this.setValue(row, "method", product.count_method)
    this.setValue(row, "packageLabel", product.package_label)
    this.setValue(row, "unitsPerPackage", product.units_per_package || 1)
    this.setValue(row, "packagesPerPallet", product.packages_per_pallet || 1)
    this.setChecked(row, "stackableCheckbox", product.stackable)
    this.setValue(row, "maxStackLayersInput", product.max_stack_layers || 1)
    this.setChecked(row, "fragileCheckbox", product.fragile)
    this.setChecked(row, "canRotateCheckbox", product.can_rotate)
    this.setChecked(row, "hazardousCheckbox", product.hazardous)
    this.applyDimensions(row, product)
    this.previewRow(row)
  }

  preview(event) {
    const row = event.target.closest("[data-cargo-items-row]")
    const product = this.selectedProduct(row)
    if (product && event.target.dataset.cargoItemsTarget === "method") this.applyDimensions(row, product)
    this.previewRow(row)
  }

  manualFlagsChanged(event) {
    this.previewRow(event.target.closest("[data-cargo-items-row]"))
  }

  applyDimensions(row, product) {
    const method = this.value(row, "method")
    const dimensions = this.dimensionsFor(method, product)

    this.setValue(row, "length", dimensions.length)
    this.setValue(row, "width", dimensions.width)
    this.setValue(row, "height", dimensions.height)
    this.setValue(row, "weight", dimensions.weight)
  }

  selectedProduct(row) {
    const option = this.target(row, "product")?.selectedOptions[0]
    return option?.dataset.product ? JSON.parse(option.dataset.product) : null
  }

  dimensionsFor(method, product) {
    if (method === "palete") {
      return {
        length: product.pallet_length_cm || product.package_length_cm || product.unit_length_cm,
        width: product.pallet_width_cm || product.package_width_cm || product.unit_width_cm,
        height: product.pallet_height_cm || product.package_height_cm || product.unit_height_cm,
        weight: product.pallet_weight_kg || product.package_weight_kg || product.unit_weight_kg
      }
    }

    if (["caixa", "fardo", "pacote", "outro"].includes(method)) {
      return {
        length: product.package_length_cm || product.unit_length_cm,
        width: product.package_width_cm || product.unit_width_cm,
        height: product.package_height_cm || product.unit_height_cm,
        weight: product.package_weight_kg || product.unit_weight_kg
      }
    }

    return {
      length: product.unit_length_cm || product.package_length_cm,
      width: product.unit_width_cm || product.package_width_cm,
      height: product.unit_height_cm || product.package_height_cm,
      weight: product.unit_weight_kg || product.package_weight_kg
    }
  }

  previewRow(row) {
    if (!row) return

    const quantity = Number(this.value(row, "quantity")) || 0
    const method = this.value(row, "method") || "unidade"
    const unitsPerPackage = Math.max(Number(this.value(row, "unitsPerPackage")) || 1, 1)
    const packagesPerPallet = Math.max(Number(this.value(row, "packagesPerPallet")) || 1, 1)
    const length = Number(this.value(row, "length")) || 0
    const width = Number(this.value(row, "width")) || 0
    const height = Number(this.value(row, "height")) || 0
    const weight = Number(this.value(row, "weight")) || 0
    const packageLabel = this.value(row, "packageLabel") || "embalagem"

    let totalUnits = 0
    let totalPackages = 0
    let totalPallets = 0

    if (method === "unidade") {
      totalUnits = Math.ceil(quantity)
      totalPackages = unitsPerPackage > 0 ? Math.ceil(quantity / unitsPerPackage) : 0
    } else if (method === "palete") {
      totalPallets = Math.ceil(quantity)
      totalPackages = Math.ceil(quantity * packagesPerPallet)
      totalUnits = Math.ceil(totalPackages * unitsPerPackage)
    } else {
      totalPackages = Math.ceil(quantity)
      totalUnits = Math.ceil(quantity * unitsPerPackage)
      totalPallets = packagesPerPallet > 0 ? Math.ceil(quantity / packagesPerPallet) : 0
    }

    const volume = (length * width * height / 1000000) * quantity
    const totalWeight = weight * quantity
    const stackable = this.checked(row, "stackableCheckbox")
    const fragile = this.checked(row, "fragileCheckbox")
    const canRotate = this.checked(row, "canRotateCheckbox")
    const hazardous = this.checked(row, "hazardousCheckbox")
    const maxLayers = this.value(row, "maxStackLayersInput") || 1

    this.syncQuantity(row, quantity)

    const badges = [
      stackable ? `Empilhável: Sim, máximo ${maxLayers} camadas` : "Não empilhável",
      fragile ? "Alerta: produto frágil" : null,
      hazardous ? "Alerta: produto perigoso" : null,
      canRotate ? null : "Não pode girar"
    ].filter(Boolean)

    const preview = this.target(row, "preview")
    preview.innerHTML = `
      <div class="grid gap-2 md:grid-cols-3">
        <span>${quantity || 0} ${method}${method === "unidade" ? "" : "s"}</span>
        <span>${totalUnits.toLocaleString("pt-BR")} unidades</span>
        <span>${totalPackages.toLocaleString("pt-BR")} ${packageLabel}${totalPackages === 1 ? "" : "s"}</span>
        <span>${totalPallets.toLocaleString("pt-BR")} palete(s)</span>
        <span>Peso total: ${totalWeight.toLocaleString("pt-BR", { maximumFractionDigits: 2 })} kg</span>
        <span>Volume total: ${volume.toLocaleString("pt-BR", { maximumFractionDigits: 3 })} m³</span>
      </div>
      <div class="mt-2 flex flex-wrap gap-2">
        ${badges.map((badge) => `<span class="rounded-full border border-[#334155] bg-[#1F2937] px-2 py-1 text-xs text-[#F8FAFC]">${badge}</span>`).join("")}
      </div>
    `
  }

  syncQuantity(row, quantity) {
    const quantityInput = row.querySelector("input[name*='[quantity]']")
    if (quantityInput) quantityInput.value = Math.ceil(quantity || 0)
  }

  target(row, name) {
    return row.querySelector(`[data-cargo-items-target='${name}']`)
  }

  value(row, name) {
    return this.target(row, name)?.value
  }

  setValue(row, name, value) {
    const field = this.target(row, name)
    if (field && value !== null && value !== undefined) field.value = value
  }

  checked(row, name) {
    return this.target(row, name)?.checked
  }

  setChecked(row, name, value) {
    const field = this.target(row, name)
    if (field) field.checked = Boolean(value)
  }
}
