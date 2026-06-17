'use client'

import { useEffect, useState, useMemo } from 'react'
import { useAuth } from '@/lib/auth'
import { createClient } from '@/lib/supabase/client'
import { calculateCubage, type CubageResult } from '@/server/services/cubageCalculator'
import { suggestVehicles, type Vehicle, type VehicleSuggestion, getOccupationColor } from '@/server/services/vehicleSuggestion'
import {
  Calculator,
  Plus,
  Trash2,
  Save,
  Printer,
  Search,
  Loader2,
  Calendar,
  User,
  Building2,
  FileText,
  MapPin,
  Truck,
  Activity,
  CheckCircle,
} from 'lucide-react'

interface Product {
  id: string
  company_id: string
  internal_code: string
  ref_code: string | null
  name: string
  package_length_cm: number
  package_width_cm: number
  package_height_cm: number
  package_weight_kg: number
  units_per_package: number
  volume_multiplier: number
  weight_per_unit_kg: number
  packages_per_pallet: number
  stackable: boolean
  max_stack_layers: number
  can_rotate: boolean
  stowage_factor: number
  fragile: boolean
  hazardous: boolean
}

interface QuoteItem {
  tempId: string // Unique front-end ID
  product: Product | null
  refCodeInput: string
  quantity: number
  packages: number
  volumes: number
  weight: number
  cubage: number
}

export default function CotacoesPage() {
  const { profile, loading: authLoading } = useAuth()
  const [products, setProducts] = useState<Product[]>([])
  const [vehicles, setVehicles] = useState<Vehicle[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [success, setSuccess] = useState(false)

  // Header State
  const [dateStr, setDateStr] = useState('')
  const [solicitante, setSolicitante] = useState('')
  const [razaoSocial, setRazaoSocial] = useState('')
  const [cnpj, setCnpj] = useState('')
  const [cep, setCep] = useState('')
  const [origin, setOrigin] = useState('Matriz EstivaFácil')
  const [destination, setDestination] = useState('')
  const [cepLoading, setCepLoading] = useState(false)

  // Items State
  const [items, setItems] = useState<QuoteItem[]>([
    { tempId: '1', product: null, refCodeInput: '', quantity: 0, packages: 0, volumes: 0, weight: 0, cubage: 0 }
  ])

  // Active product search suggestion lists per item row
  const [activeSearches, setActiveSearches] = useState<Record<string, Product[]>>({})

  const supabase = createClient()

  useEffect(() => {
    // Set current date
    const today = new Date()
    setDateStr(today.toLocaleDateString('pt-BR'))

    if (!profile?.company_id) return
    
    async function fetchData() {
      setLoading(true)
      const [prodRes, vehRes] = await Promise.all([
        supabase
          .from('products')
          .select('*')
          .eq('company_id', profile!.company_id)
          .eq('active', true),
        supabase
          .from('vehicles')
          .select('*')
          .eq('company_id', profile!.company_id)
          .eq('active', true)
      ])

      if (!prodRes.error && prodRes.data) {
        setProducts(prodRes.data as Product[])
      }
      if (!vehRes.error && vehRes.data) {
        const formattedVehicles: Vehicle[] = (vehRes.data as any[]).map((v) => ({
          id: v.id,
          name: v.name,
          kind: v.kind,
          body_type: v.body_type,
          maxWeightKg: Number(v.max_weight_kg) || 0,
          maxVolumeM3: Number(v.max_volume_m3) || 0,
        }))
        setVehicles(formattedVehicles)
      }
      setLoading(false)
    }

    fetchData()
  }, [profile])

  // CNPJ Mask (XX.XXX.XXX/XXXX-XX)
  function handleCnpjChange(val: string) {
    const cleaned = val.replace(/\D/g, '').slice(0, 14)
    let masked = cleaned
    if (cleaned.length > 12) {
      masked = cleaned.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5')
    } else if (cleaned.length > 8) {
      masked = cleaned.replace(/^(\d{2})(\d{3})(\d{3})(\d{0,4})/, '$1.$2.$3/$4')
    } else if (cleaned.length > 5) {
      masked = cleaned.replace(/^(\d{2})(\d{3})(\d{0,3})/, '$1.$2.$3')
    } else if (cleaned.length > 2) {
      masked = cleaned.replace(/^(\d{2})(\d{0,3})/, '$1.$2')
    }
    setCnpj(masked)
  }

  // CEP Mask (XXXXX-XXX) and Auto Lookup
  async function handleCepChange(val: string) {
    const cleaned = val.replace(/\D/g, '').slice(0, 8)
    let masked = cleaned
    if (cleaned.length > 5) {
      masked = cleaned.replace(/^(\d{5})(\d{0,3})/, '$1-$2')
    }
    setCep(masked)

    if (cleaned.length === 8) {
      setCepLoading(true)
      try {
        const res = await fetch(`https://viacep.com.br/ws/${cleaned}/json/`)
        const data = await res.json()
        if (!data.erro) {
          const addr = `${data.localidade} - ${data.uf}`
          const fullAddr = data.bairro ? `${data.logradouro}, ${data.bairro} - ${addr}` : addr
          setDestination(fullAddr)
        }
      } catch (err) {
        console.error('Erro ao buscar CEP:', err)
      } finally {
        setCepLoading(false)
      }
    }
  }

  // Search product per row
  function handleProductSearch(tempId: string, searchVal: string) {
    const item = items.find((i) => i.tempId === tempId)
    if (!item) return

    // Update the ref code input locally
    setItems((prev) =>
      prev.map((i) => (i.tempId === tempId ? { ...i, refCodeInput: searchVal } : i))
    )

    if (!searchVal.trim()) {
      setActiveSearches((prev) => ({ ...prev, [tempId]: [] }))
      return
    }

    const matched = products.filter(
      (p) =>
        (p.ref_code && p.ref_code.toLowerCase().includes(searchVal.toLowerCase())) ||
        p.name.toLowerCase().includes(searchVal.toLowerCase()) ||
        p.internal_code.toLowerCase().includes(searchVal.toLowerCase())
    )

    setActiveSearches((prev) => ({ ...prev, [tempId]: matched.slice(0, 5) }))
  }

  // Select Product for a Row
  function selectProduct(tempId: string, product: Product) {
    setActiveSearches((prev) => ({ ...prev, [tempId]: [] }))

    setItems((prev) =>
      prev.map((i) => {
        if (i.tempId !== tempId) return i

        const qty = i.quantity || 1
        const res = calculateCubage({
          quantity: qty,
          unitsPerPackage: product.units_per_package,
          packageLengthCm: product.package_length_cm,
          packageWidthCm: product.package_width_cm,
          packageHeightCm: product.package_height_cm,
          packageWeightKg: product.package_weight_kg,
          volumeMultiplier: product.volume_multiplier,
        })

        return {
          ...i,
          product,
          refCodeInput: product.ref_code || product.internal_code,
          quantity: qty,
          packages: res.totalPackages,
          volumes: res.totalVolumes,
          weight: res.totalWeightKg,
          cubage: res.totalVolumeM3,
        }
      })
    )
  }

  // Update quantity on row
  function handleQuantityChange(tempId: string, qty: number) {
    setItems((prev) =>
      prev.map((i) => {
        if (i.tempId !== tempId) return i

        const safeQty = Math.max(0, qty)
        if (!i.product) {
          return { ...i, quantity: safeQty }
        }

        const res = calculateCubage({
          quantity: safeQty,
          unitsPerPackage: i.product.units_per_package,
          packageLengthCm: i.product.package_length_cm,
          packageWidthCm: i.product.package_width_cm,
          packageHeightCm: i.product.package_height_cm,
          packageWeightKg: i.product.package_weight_kg,
          volumeMultiplier: i.product.volume_multiplier,
        })

        return {
          ...i,
          quantity: safeQty,
          packages: res.totalPackages,
          volumes: res.totalVolumes,
          weight: res.totalWeightKg,
          cubage: res.totalVolumeM3,
        }
      })
    )
  }

  // Add empty row
  function addRow() {
    const newId = (Math.max(...items.map((i) => Number(i.tempId))) + 1).toString()
    setItems((prev) => [
      ...prev,
      { tempId: newId, product: null, refCodeInput: '', quantity: 0, packages: 0, volumes: 0, weight: 0, cubage: 0 }
    ])
  }

  // Remove row
  function removeRow(tempId: string) {
    if (items.length === 1) {
      setItems([{ tempId: '1', product: null, refCodeInput: '', quantity: 0, packages: 0, volumes: 0, weight: 0, cubage: 0 }])
      return
    }
    setItems((prev) => prev.filter((i) => i.tempId !== tempId))
  }

  // Calculate Totals
  const totals = useMemo(() => {
    return items.reduce(
      (acc, item) => {
        acc.pieces += item.quantity || 0
        acc.packages += item.packages || 0
        acc.volumes += item.volumes || 0
        acc.weight += item.weight || 0
        acc.cubage += item.cubage || 0
        return acc
      },
      { pieces: 0, packages: 0, volumes: 0, weight: 0, cubage: 0 }
    )
  }, [items])

  // Vehicle Suggestions based on Totals
  const suggestions = useMemo<VehicleSuggestion[]>(() => {
    return suggestVehicles(totals.weight, totals.cubage, vehicles)
  }, [totals, vehicles])

  const recommended = suggestions.find((s) => s.fits) || suggestions[0]

  // Save Quote to database
  async function handleSaveQuote() {
    if (!profile?.company_id || !profile?.id) return
    if (!razaoSocial.trim()) {
      alert('Por favor, informe a Razão Social do Destinatário.')
      return
    }
    const validItems = items.filter((i) => i.product && i.quantity > 0)
    if (validItems.length === 0) {
      alert('Adicione pelo menos um item válido com quantidade.')
      return
    }

    setSaving(true)

    // Notes JSON string to capture extra data
    const notesJson = JSON.stringify({
      solicitante,
      cnpj,
      cep,
      salvo_como: 'cotacao',
    })

    // 1. Insert Cargo
    const { data: cargoData, error: cargoError } = await supabase
      .from('cargos')
      .insert({
        company_id: profile.company_id,
        user_id: profile.id,
        customer_name: razaoSocial.trim(),
        origin: origin.trim(),
        destination: destination.trim() || 'Não especificado',
        recommended_vehicle_id: recommended?.vehicle?.id || null,
        status: 0, // 0: Planejando
        total_units: totals.pieces,
        total_packages: totals.packages,
        total_pallets: 0, // Optional or calculated if palletized
        total_weight_kg: totals.weight,
        total_volume_m3: totals.cubage,
      })
      .select('id')
      .single()

    if (cargoError) {
      console.error('Erro ao salvar carga:', cargoError)
      alert('Erro ao salvar cotação: ' + cargoError.message)
      setSaving(false)
      return
    }

    // 2. Insert Items
    const itemsToInsert = validItems.map((item) => {
      const prod = item.product!
      return {
        cargo_id: cargoData.id,
        product_id: prod.id,
        product_name_snapshot: prod.name,
        product_internal_code_snapshot: prod.internal_code,
        product_ref_code_snapshot: prod.ref_code,
        package_name_snapshot: `Multiplicador: x${prod.volume_multiplier}`,
        quantity: item.quantity,
        count_method: 'unidade',
        total_units: item.quantity,
        total_packages: item.packages,
        total_pallets: 0,
        length_cm: prod.package_length_cm,
        width_cm: prod.package_width_cm,
        height_cm: prod.package_height_cm,
        weight_kg: prod.package_weight_kg,
        units_per_package: prod.units_per_package,
        packages_per_pallet: prod.packages_per_pallet || 1,
        weight_per_unit_kg: prod.weight_per_unit_kg || 0,
        stackable: prod.stackable,
        max_stack_layers: prod.max_stack_layers,
        can_rotate: prod.can_rotate,
        stowage_factor: prod.stowage_factor,
        fragile: prod.fragile,
        hazardous: prod.hazardous,
        calculated_weight_kg: item.weight,
        calculated_volume_m3: item.cubage,
        calculated_packages: item.packages,
        calculated_pallets: 0,
        notes: notesJson,
      }
    })

    const { error: itemsError } = await supabase.from('cargo_items').insert(itemsToInsert)

    if (itemsError) {
      console.error('Erro ao salvar itens da carga:', itemsError)
      alert('Carga criada, mas ocorreu um erro ao salvar os itens: ' + itemsError.message)
    } else {
      setSuccess(true)
      setTimeout(() => setSuccess(false), 4000)
    }
    setSaving(false)
  }

  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="flex flex-col items-center gap-4">
          <Activity className="w-8 h-8 text-accent-violet animate-pulse" />
          <p className="text-text-secondary text-sm">Carregando formulário de cotação...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6 print:space-y-4 print:p-0">
      {/* Header Controls */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 print:hidden">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500/20 to-violet-500/20 flex items-center justify-center">
            <Calculator className="w-5 h-5 text-accent-violet" />
          </div>
          <div>
            <h1
              className="text-2xl font-bold text-text-primary tracking-tight"
              style={{ fontFamily: 'var(--font-heading)' }}
            >
              Cotação de Frete
            </h1>
            <p className="text-text-muted text-sm">
              Calcule volumes de expedição e cubagem com regras de multiplicadores aplicadas.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button className="btn-secondary" onClick={() => window.print()}>
            <Printer className="w-4 h-4" />
            Imprimir / PDF
          </button>
          <button className="btn-primary" onClick={handleSaveQuote} disabled={saving}>
            {saving ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Save className="w-4 h-4" />
            )}
            Salvar Cotação
          </button>
        </div>
      </div>

      {/* Success Notification */}
      {success && (
        <div className="glass-card border-green-500/30 bg-green-500/10 p-4 rounded-xl flex items-center gap-3 animate-fade-in print:hidden">
          <CheckCircle className="w-5 h-5 text-green-500" />
          <p className="text-green-400 font-medium text-sm">
            Cotação salva com sucesso na lista de Cargas (Planejando)!
          </p>
        </div>
      )}

      {/* Print-only Header (renders on PDF) */}
      <div className="hidden print:block border-b border-gray-700 pb-4 mb-6">
        <div className="flex justify-between items-start">
          <div>
            <h1 className="text-2xl font-bold text-white">EstivaFácil — Cotação de Cubagem</h1>
            <p className="text-gray-400 text-xs mt-1">Cálculo automatizado de estiva e cubagem</p>
          </div>
          <div className="text-right">
            <p className="text-sm font-semibold text-white">Data: {dateStr}</p>
            <p className="text-gray-400 text-xs">Empresa ID: {profile?.company_id?.slice(0, 8)}</p>
          </div>
        </div>
      </div>

      {/* Form Grid */}
      <div className="glass-card p-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 print:border-none print:bg-transparent print:p-0">
        <div className="space-y-2">
          <label className="text-xs font-semibold text-text-secondary flex items-center gap-2">
            <Calendar className="w-3.5 h-3.5 text-text-muted" /> DATA DA COTAÇÃO
          </label>
          <input type="text" className="input-field bg-transparent" value={dateStr} disabled />
        </div>

        <div className="space-y-2">
          <label className="text-xs font-semibold text-text-secondary flex items-center gap-2">
            <User className="w-3.5 h-3.5 text-text-muted" /> SOLICITANTE
          </label>
          <input
            type="text"
            placeholder="Nome do vendedor/solicitante"
            className="input-field"
            value={solicitante}
            onChange={(e) => setSolicitante(e.target.value)}
          />
        </div>

        <div className="space-y-2">
          <label className="text-xs font-semibold text-text-secondary flex items-center gap-2">
            <Building2 className="w-3.5 h-3.5 text-text-muted" /> RAZÃO SOCIAL (DESTINATÁRIO) *
          </label>
          <input
            type="text"
            placeholder="Razão Social ou Nome do Cliente"
            className="input-field"
            value={razaoSocial}
            onChange={(e) => setRazaoSocial(e.target.value)}
          />
        </div>

        <div className="space-y-2">
          <label className="text-xs font-semibold text-text-secondary flex items-center gap-2">
            <FileText className="w-3.5 h-3.5 text-text-muted" /> CNPJ DESTINATÁRIO
          </label>
          <input
            type="text"
            placeholder="00.000.000/0000-00"
            className="input-field"
            value={cnpj}
            onChange={(e) => handleCnpjChange(e.target.value)}
          />
        </div>

        <div className="space-y-2">
          <label className="text-xs font-semibold text-text-secondary flex items-center gap-2">
            <MapPin className="w-3.5 h-3.5 text-text-muted" /> CEP DESTINATÁRIO
          </label>
          <div className="relative">
            <input
              type="text"
              placeholder="00000-000"
              className="input-field pr-10"
              value={cep}
              onChange={(e) => handleCepChange(e.target.value)}
            />
            {cepLoading && (
              <Loader2 className="w-4 h-4 absolute right-3 top-1/2 -translate-y-1/2 animate-spin text-accent-violet" />
            )}
          </div>
        </div>

        <div className="space-y-2">
          <label className="text-xs font-semibold text-text-secondary flex items-center gap-2">
            <MapPin className="w-3.5 h-3.5 text-text-muted" /> ORIGEM DA CARGA
          </label>
          <input
            type="text"
            className="input-field"
            value={origin}
            onChange={(e) => setOrigin(e.target.value)}
          />
        </div>

        <div className="space-y-2 md:col-span-2 lg:col-span-3">
          <label className="text-xs font-semibold text-text-secondary flex items-center gap-2">
            <MapPin className="w-3.5 h-3.5 text-text-muted" /> DESTINO (ENDEREÇO / CIDADE-UF)
          </label>
          <input
            type="text"
            placeholder="Cidade - UF (Preenchido automaticamente ao digitar CEP)"
            className="input-field"
            value={destination}
            onChange={(e) => setDestination(e.target.value)}
          />
        </div>
      </div>

      {/* Items Quotation Table */}
      <div className="glass-card overflow-hidden print:border-none print:bg-transparent">
        <div className="overflow-x-auto">
          <table className="data-table print:text-xs">
            <thead>
              <tr className="print:bg-gray-800 print:text-white">
                <th className="w-10 text-center">#</th>
                <th className="w-32">REF / CÓDIGO</th>
                <th>PRODUTO</th>
                <th className="w-28 text-right">QTD PEÇAS</th>
                <th className="w-24 text-right">VOL CXS</th>
                <th className="w-20 text-center">MULT.</th>
                <th className="w-24 text-right">VOL SHP</th>
                <th className="w-40 text-center">MEDIDAS CX</th>
                <th className="w-24 text-right">PESO CX</th>
                <th className="w-28 text-right">PESO TOT</th>
                <th className="w-28 text-right">CUB TOT m³</th>
                <th className="w-12 text-center print:hidden"></th>
              </tr>
            </thead>
            <tbody>
              {items.map((item, idx) => {
                const p = item.product
                const matchedSuggestions = activeSearches[item.tempId] || []
                return (
                  <tr key={item.tempId} className="group hover:bg-[var(--surface-hover)]">
                    <td className="text-center font-medium text-text-muted text-sm">{idx + 1}</td>
                    
                    {/* REF Code input with suggestion search */}
                    <td className="relative">
                      <input
                        type="text"
                        placeholder="Ex: 83914"
                        className="input-field py-1 px-2 text-sm bg-transparent border-0 group-hover:border-b group-hover:border-accent-violet/30 focus:border-b focus:border-accent-violet focus:ring-0"
                        value={item.refCodeInput}
                        onChange={(e) => handleProductSearch(item.tempId, e.target.value)}
                      />
                      
                      {/* Search suggestions dropdown */}
                      {matchedSuggestions.length > 0 && (
                        <div className="absolute z-50 left-0 right-0 mt-1 bg-surface border border-border rounded-lg shadow-lg max-h-60 overflow-y-auto">
                          {matchedSuggestions.map((prod) => (
                            <button
                              key={prod.id}
                              type="button"
                              className="w-full text-left px-3 py-2 text-xs hover:bg-surface-hover text-text-primary border-b border-border/50 last:border-0 flex justify-between"
                              onClick={() => selectProduct(item.tempId, prod)}
                            >
                              <span className="font-semibold">{prod.ref_code || prod.internal_code}</span>
                              <span className="truncate max-w-[150px] text-text-secondary">{prod.name}</span>
                              <span className="text-accent-violet">×{prod.volume_multiplier}</span>
                            </button>
                          ))}
                        </div>
                      )}
                    </td>

                    {/* Product Name */}
                    <td>
                      <span className="text-sm font-medium text-text-primary block truncate max-w-[240px]">
                        {p ? p.name : <span className="text-text-muted italic">Selecione o produto</span>}
                      </span>
                    </td>

                    {/* Pieces Qty */}
                    <td>
                      <input
                        type="number"
                        min="0"
                        placeholder="0"
                        className="input-field py-1 px-2 text-sm text-right bg-transparent border-0 group-hover:border-b group-hover:border-accent-violet/30 focus:border-b focus:border-accent-violet focus:ring-0"
                        value={item.quantity || ''}
                        onChange={(e) => handleQuantityChange(item.tempId, parseInt(e.target.value) || 0)}
                      />
                    </td>

                    {/* Packages / Boxes */}
                    <td className="text-right text-sm text-text-secondary font-medium">
                      {p ? item.packages : '—'}
                    </td>

                    {/* Volume Multiplier Badge */}
                    <td className="text-center">
                      {p ? (
                        <span
                          className={`badge text-[10px] px-2 py-0.5 ${
                            p.volume_multiplier >= 3
                              ? 'badge-red'
                              : p.volume_multiplier === 2
                              ? 'badge-yellow'
                              : 'badge-gray'
                          }`}
                        >
                          ×{p.volume_multiplier}
                        </span>
                      ) : (
                        '—'
                      )}
                    </td>

                    {/* Calculated Volumes (Shipping volumes) */}
                    <td className="text-right text-sm text-text-primary font-semibold">
                      {p ? item.volumes : '—'}
                    </td>

                    {/* Box Dimensions */}
                    <td className="text-center text-xs text-text-muted">
                      {p ? `${p.package_length_cm} × ${p.package_width_cm} × ${p.package_height_cm} cm` : '—'}
                    </td>

                    {/* Box Weight */}
                    <td className="text-right text-sm text-text-muted">
                      {p ? `${p.package_weight_kg.toFixed(2)} kg` : '—'}
                    </td>

                    {/* Total Weight */}
                    <td className="text-right text-sm text-text-primary font-medium">
                      {p ? `${item.weight.toFixed(2)} kg` : '—'}
                    </td>

                    {/* Total Cubage */}
                    <td className="text-right text-sm text-text-primary font-medium">
                      {p ? `${item.cubage.toFixed(3)} m³` : '—'}
                    </td>

                    {/* Remove Action Button */}
                    <td className="text-center print:hidden">
                      <button
                        type="button"
                        className="p-1.5 hover:bg-danger-bg rounded-lg text-text-muted hover:text-danger transition-colors"
                        onClick={() => removeRow(item.tempId)}
                        title="Remover linha"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                )
              })}

              {/* Totals Row */}
              <tr className="bg-surface/50 font-bold border-t-2 border-border/80">
                <td colSpan={3} className="text-right text-sm text-text-secondary uppercase tracking-wider">
                  TOTAIS
                </td>
                <td className="text-right text-sm text-text-primary">{totals.pieces}</td>
                <td className="text-right text-sm text-text-secondary">{totals.packages}</td>
                <td></td>
                <td className="text-right text-sm text-accent-violet">{totals.volumes}</td>
                <td colSpan={2}></td>
                <td className="text-right text-sm text-text-primary">{totals.weight.toFixed(2)} kg</td>
                <td className="text-right text-sm text-accent-blue">{totals.cubage.toFixed(3)} m³</td>
                <td className="print:hidden"></td>
              </tr>
            </tbody>
          </table>
        </div>

        {/* Add Row Action */}
        <div className="p-4 bg-surface/20 border-t border-border/50 flex justify-start print:hidden">
          <button className="btn-secondary py-1.5 px-4 text-xs" onClick={addRow}>
            <Plus className="w-4 h-4" />
            Adicionar Item
          </button>
        </div>
      </div>

      {/* Vehicle Recommendation Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recommendation Panel */}
        <div className="glass-card p-6 lg:col-span-1 flex flex-col justify-between border-l-4 border-l-accent-violet">
          <div>
            <h2 className="text-lg font-bold text-text-primary mb-1 flex items-center gap-2">
              <Truck className="w-5 h-5 text-accent-violet" />
              Veículo Recomendado
            </h2>
            <p className="text-text-muted text-xs mb-6">
              Sugestão gerada com base no peso e cubagem totais da carga.
            </p>

            {recommended ? (
              <div className="space-y-4">
                <div className="flex items-center gap-4">
                  <span className="text-4xl">
                    {recommended.vehicle.kind === 'VUC' || recommended.vehicle.kind === '3/4'
                      ? '🚐'
                      : recommended.vehicle.kind === 'Carreta' || recommended.vehicle.kind === 'Rodotrem'
                      ? '🚛'
                      : '🚚'}
                  </span>
                  <div>
                    <h3 className="text-xl font-bold text-text-primary">{recommended.vehicle.name}</h3>
                    <p className="text-text-muted text-xs uppercase tracking-wider">
                      {recommended.vehicle.kind} {recommended.vehicle.body_type ? `• ${recommended.vehicle.body_type}` : ''}
                    </p>
                  </div>
                </div>

                <div className="pt-4 space-y-3 border-t border-border/30">
                  <div className="flex justify-between text-xs">
                    <span className="text-text-secondary">Capacidade de Peso:</span>
                    <span className="font-semibold text-text-primary">
                      {totals.weight.toFixed(0)} / {recommended.vehicle.maxWeightKg} kg
                    </span>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-text-secondary">Capacidade de Volume:</span>
                    <span className="font-semibold text-text-primary">
                      {totals.cubage.toFixed(2)} / {recommended.vehicle.maxVolumeM3} m³
                    </span>
                  </div>
                </div>
              </div>
            ) : (
              <div className="py-6 text-center text-text-muted text-sm italic">
                Nenhum veículo ativo disponível para sugestão.
              </div>
            )}
          </div>

          {recommended && (
            <div className="mt-6 pt-4 border-t border-border/30">
              <div className="flex items-center justify-between text-xs">
                <span className="text-text-secondary">Status de Lotação:</span>
                <span
                  className="font-bold uppercase"
                  style={{ color: getOccupationColor(Math.max(recommended.weightPercent, recommended.volumePercent)) }}
                >
                  {Math.max(recommended.weightPercent, recommended.volumePercent) > 100
                    ? '⚠️ Carga Excede Limite'
                    : '✓ Veículo Adequado'}
                </span>
              </div>
            </div>
          )}
        </div>

        {/* Capacity Occupancy Details */}
        <div className="glass-card p-6 lg:col-span-2 space-y-6">
          <h2 className="text-lg font-bold text-text-primary flex items-center gap-2">
            <Activity className="w-5 h-5 text-accent-blue" />
            Lotação dos Veículos Disponíveis
          </h2>

          <div className="space-y-5">
            {suggestions.map((s) => {
              const maxPercent = Math.max(s.weightPercent, s.volumePercent)
              const weightColor = getOccupationColor(s.weightPercent)
              const volumeColor = getOccupationColor(s.volumePercent)

              return (
                <div key={s.vehicle.id} className="p-4 rounded-xl bg-surface/30 border border-border/20 space-y-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-bold text-text-primary">{s.vehicle.name}</span>
                      <span className="text-[10px] bg-surface-hover text-text-secondary px-2 py-0.5 rounded border border-border/30">
                        {s.vehicle.kind}
                      </span>
                    </div>
                    <span
                      className="text-xs font-semibold"
                      style={{ color: getOccupationColor(maxPercent) }}
                    >
                      Max: {maxPercent.toFixed(0)}%
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {/* Weight Capacity Progress */}
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-[11px] text-text-muted">
                        <span>Peso ({s.weightPercent.toFixed(0)}%)</span>
                        <span>{s.vehicle.maxWeightKg} kg</span>
                      </div>
                      <div className="w-full h-2 rounded-full bg-surface-hover overflow-hidden">
                        <div
                          className="h-full rounded-full transition-all duration-500"
                          style={{
                            width: `${Math.min(100, s.weightPercent)}%`,
                            backgroundColor: weightColor,
                          }}
                        />
                      </div>
                    </div>

                    {/* Volume Capacity Progress */}
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-[11px] text-text-muted">
                        <span>Volume ({s.volumePercent.toFixed(0)}%)</span>
                        <span>{s.vehicle.maxVolumeM3} m³</span>
                      </div>
                      <div className="w-full h-2 rounded-full bg-surface-hover overflow-hidden">
                        <div
                          className="h-full rounded-full transition-all duration-500"
                          style={{
                            width: `${Math.min(100, s.volumePercent)}%`,
                            backgroundColor: volumeColor,
                          }}
                        />
                      </div>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
