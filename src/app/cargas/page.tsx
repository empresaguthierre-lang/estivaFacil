'use client'

import { useEffect, useState, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/lib/auth'
import { createClient } from '@/lib/supabase/client'
import {
  Boxes,
  Plus,
  MapPin,
  Truck,
  Weight,
  Layers,
  Calendar,
  ChevronDown,
  ChevronUp,
  Trash2,
  CheckCircle,
  Clock,
  Navigation,
  Check,
  Loader2,
  Package,
} from 'lucide-react'

interface Cargo {
  id: string
  company_id: string
  user_id: string
  customer_name: string
  origin: string
  destination: string
  recommended_vehicle_id: string | null
  status: number // 0: Planejando, 1: Fechado, 2: Carregado, 3: Entregue
  total_units: number
  total_packages: number
  total_pallets: number
  total_weight_kg: number
  total_volume_m3: number
  created_at: string
}

interface CargoItem {
  id: string
  cargo_id: string
  product_name_snapshot: string
  product_ref_code_snapshot: string | null
  quantity: number
  calculated_packages: number
  calculated_weight_kg: number
  calculated_volume_m3: number
}

interface Vehicle {
  id: string
  name: string
  kind: string
}

const STATUS_LABELS = ['Planejando', 'Fechado', 'Carregado', 'Entregue']

export default function CargasPage() {
  const { profile, loading: authLoading } = useAuth()
  const router = useRouter()
  const [cargos, setCargos] = useState<Cargo[]>([])
  const [cargoItems, setCargoItems] = useState<Record<string, CargoItem[]>>({})
  const [vehicles, setVehicles] = useState<Vehicle[]>([])
  const [loading, setLoading] = useState(true)
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<number | 'all'>('all')
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null)

  const supabase = createClient()

  useEffect(() => {
    if (!profile?.company_id) return
    fetchData()
  }, [profile])

  async function fetchData() {
    setLoading(true)
    const companyId = profile!.company_id

    const [cargosRes, vehiclesRes] = await Promise.all([
      supabase
        .from('cargos')
        .select('*')
        .eq('company_id', companyId)
        .order('created_at', { ascending: false }),
      supabase.from('vehicles').select('id, name, kind').eq('company_id', companyId),
    ])

    if (!cargosRes.error && cargosRes.data) {
      setCargos(cargosRes.data as Cargo[])
      
      // Fetch items for these cargos
      const cargoIds = cargosRes.data.map((c) => c.id)
      if (cargoIds.length > 0) {
        const { data: itemsData, error: itemsError } = await supabase
          .from('cargo_items')
          .select('id, cargo_id, product_name_snapshot, product_ref_code_snapshot, quantity, calculated_packages, calculated_weight_kg, calculated_volume_m3')
          .in('cargo_id', cargoIds)

        if (!itemsError && itemsData) {
          const grouped: Record<string, CargoItem[]> = {}
          itemsData.forEach((item: any) => {
            if (!grouped[item.cargo_id]) {
              grouped[item.cargo_id] = []
            }
            grouped[item.cargo_id].push(item as CargoItem)
          })
          setCargoItems(grouped)
        }
      }
    }

    if (!vehiclesRes.error && vehiclesRes.data) {
      setVehicles(vehiclesRes.data as Vehicle[])
    }

    setLoading(false)
  }

  // Get vehicle name by ID
  function getVehicleName(id: string | null): string {
    if (!id) return 'Nenhum'
    const v = vehicles.find((veh) => veh.id === id)
    return v ? `${v.name} (${v.kind})` : 'Veículo Desconhecido'
  }

  // Filter cargos by tab
  const filteredCargos = useMemo(() => {
    if (activeTab === 'all') return cargos
    return cargos.filter((c) => c.status === activeTab)
  }, [cargos, activeTab])

  // Update Status
  async function updateStatus(id: string, currentStatus: number) {
    if (currentStatus >= 3) return // Already Entregue
    
    setActionLoadingId(id)
    const nextStatus = currentStatus + 1

    const { error } = await supabase
      .from('cargos')
      .update({ status: nextStatus })
      .eq('id', id)

    if (error) {
      console.error('Erro ao atualizar status:', error)
      alert('Não foi possível atualizar o status: ' + error.message)
    } else {
      setCargos((prev) =>
        prev.map((c) => (c.id === id ? { ...c, status: nextStatus } : c))
      )
    }
    setActionLoadingId(null)
  }

  // Delete Cargo
  async function handleDelete(id: string) {
    if (!confirm('Deseja realmente excluir esta carga e todos os seus itens?')) return
    
    setActionLoadingId(id)
    const { error } = await supabase.from('cargos').delete().eq('id', id)

    if (error) {
      console.error('Erro ao excluir carga:', error)
      alert('Não foi possível excluir a carga: ' + error.message)
    } else {
      setCargos((prev) => prev.filter((c) => c.id !== id))
    }
    setActionLoadingId(null)
  }

  function toggleExpand(id: string) {
    setExpandedId(expandedId === id ? null : id)
  }

  function getStatusBadgeClass(status: number): string {
    switch (status) {
      case 0:
        return 'badge-violet'
      case 1:
        return 'badge-yellow'
      case 2:
        return 'badge-blue'
      case 3:
        return 'badge-green'
      default:
        return 'badge-gray'
    }
  }

  function getStatusIcon(status: number) {
    switch (status) {
      case 0:
        return <Clock className="w-3.5 h-3.5" />
      case 1:
        return <Layers className="w-3.5 h-3.5" />
      case 2:
        return <Navigation className="w-3.5 h-3.5" />
      case 3:
        return <CheckCircle className="w-3.5 h-3.5" />
      default:
        return null
    }
  }

  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="flex flex-col items-center gap-4">
          <Boxes className="w-8 h-8 text-accent-indigo animate-bounce" />
          <p className="text-text-secondary text-sm">Carregando painel de cargas...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500/20 to-violet-500/20 flex items-center justify-center">
            <Boxes className="w-5 h-5 text-accent-indigo" />
          </div>
          <div>
            <h1
              className="text-2xl font-bold text-text-primary tracking-tight"
              style={{ fontFamily: 'var(--font-heading)' }}
            >
              Gestão de Cargas
            </h1>
            <p className="text-text-muted text-sm">
              Monitore simulações de cubagem, fechamento de frete e status de carregamento.
            </p>
          </div>
        </div>
        <button className="btn-primary" onClick={() => router.push('/cotacoes')}>
          <Plus className="w-4 h-4" />
          Nova Carga / Cotação
        </button>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-border/30 gap-1 overflow-x-auto pb-px">
        <button
          className={`px-4 py-2 text-sm font-semibold transition-all duration-200 border-b-2 whitespace-nowrap ${
            activeTab === 'all'
              ? 'border-accent-indigo text-accent-indigo bg-accent-indigo/5'
              : 'border-transparent text-text-secondary hover:text-text-primary hover:bg-surface-hover/30'
          }`}
          onClick={() => setActiveTab('all')}
        >
          Todas ({cargos.length})
        </button>
        {STATUS_LABELS.map((label, statusIdx) => {
          const count = cargos.filter((c) => c.status === statusIdx).length
          return (
            <button
              key={label}
              className={`px-4 py-2 text-sm font-semibold transition-all duration-200 border-b-2 whitespace-nowrap ${
                activeTab === statusIdx
                  ? 'border-accent-indigo text-accent-indigo bg-accent-indigo/5'
                  : 'border-transparent text-text-secondary hover:text-text-primary hover:bg-surface-hover/30'
              }`}
              onClick={() => setActiveTab(statusIdx)}
            >
              {label} ({count})
            </button>
          )
        })}
      </div>

      {/* Cargos List Grid */}
      <div className="space-y-4">
        {filteredCargos.length === 0 ? (
          <div className="glass-card p-12 text-center text-text-muted text-sm italic">
            Nenhuma carga encontrada nesta categoria.
          </div>
        ) : (
          filteredCargos.map((cargo) => {
            const isExpanded = expandedId === cargo.id
            const itemsList = cargoItems[cargo.id] || []
            const isActionLoading = actionLoadingId === cargo.id

            return (
              <div
                key={cargo.id}
                className={`glass-card overflow-hidden transition-all duration-300 ${
                  isExpanded ? 'ring-1 ring-accent-indigo/30 bg-surface/40' : ''
                }`}
              >
                {/* Card Main Info */}
                <div
                  className="p-5 flex flex-col md:flex-row md:items-center justify-between gap-4 cursor-pointer hover:bg-surface-hover/20 select-none"
                  onClick={() => toggleExpand(cargo.id)}
                >
                  <div className="flex items-start gap-4">
                    <div className="mt-1 flex flex-col items-center">
                      <span className="text-2xl">
                        {cargo.status === 3 ? '🏢' : '📦'}
                      </span>
                    </div>

                    <div className="space-y-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <h3 className="text-base font-bold text-text-primary">
                          {cargo.customer_name}
                        </h3>
                        <span className={`badge text-[10px] gap-1 px-2 py-0.5 ${getStatusBadgeClass(cargo.status)}`}>
                          {getStatusIcon(cargo.status)}
                          {STATUS_LABELS[cargo.status]}
                        </span>
                      </div>

                      <div className="flex flex-wrap items-center gap-y-1 gap-x-4 text-xs text-text-muted">
                        <span className="flex items-center gap-1">
                          <MapPin className="w-3.5 h-3.5 text-accent-indigo" />
                          {cargo.origin}
                        </span>
                        <span className="text-text-muted">→</span>
                        <span className="flex items-center gap-1 font-medium text-text-secondary">
                          <MapPin className="w-3.5 h-3.5 text-accent-blue" />
                          {cargo.destination}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Summary Metrics */}
                  <div className="flex flex-wrap items-center gap-x-6 gap-y-2 text-xs md:text-sm">
                    <div className="space-y-0.5">
                      <p className="text-text-muted text-[10px] uppercase tracking-wider">Peso</p>
                      <p className="font-semibold text-text-primary flex items-center gap-1">
                        <Weight className="w-3.5 h-3.5 text-text-muted" />
                        {cargo.total_weight_kg.toFixed(0)} kg
                      </p>
                    </div>

                    <div className="space-y-0.5">
                      <p className="text-text-muted text-[10px] uppercase tracking-wider">Volume</p>
                      <p className="font-semibold text-text-primary flex items-center gap-1">
                        <Boxes className="w-3.5 h-3.5 text-text-muted" />
                        {cargo.total_volume_m3.toFixed(3)} m³
                      </p>
                    </div>

                    <div className="space-y-0.5">
                      <p className="text-text-muted text-[10px] uppercase tracking-wider">Veículo</p>
                      <p className="font-semibold text-accent-violet flex items-center gap-1">
                        <Truck className="w-3.5 h-3.5 text-text-muted" />
                        {getVehicleName(cargo.recommended_vehicle_id)}
                      </p>
                    </div>

                    <div className="space-y-0.5">
                      <p className="text-text-muted text-[10px] uppercase tracking-wider">Data</p>
                      <p className="font-semibold text-text-primary flex items-center gap-1">
                        <Calendar className="w-3.5 h-3.5 text-text-muted" />
                        {new Date(cargo.created_at).toLocaleDateString('pt-BR')}
                      </p>
                    </div>

                    <div className="pt-2 md:pt-0 pl-2 flex items-center gap-2 border-t md:border-t-0 md:border-l border-border/30">
                      {isExpanded ? (
                        <ChevronUp className="w-5 h-5 text-text-muted" />
                      ) : (
                        <ChevronDown className="w-5 h-5 text-text-muted" />
                      )}
                    </div>
                  </div>
                </div>

                {/* Expanded Details */}
                {isExpanded && (
                  <div className="border-t border-border/30 bg-surface/20 p-5 space-y-4 animate-fade-in">
                    <div>
                      <h4 className="text-xs font-bold text-text-secondary uppercase tracking-wider mb-2 flex items-center gap-1.5">
                        <Package className="w-3.5 h-3.5 text-accent-indigo" />
                        Itens Carregados ({itemsList.length})
                      </h4>
                      {itemsList.length === 0 ? (
                        <p className="text-xs text-text-muted italic">Nenhum item cadastrado nesta carga.</p>
                      ) : (
                        <div className="overflow-hidden rounded-lg border border-border/20">
                          <table className="min-w-full divide-y divide-border/20 text-xs">
                            <thead className="bg-surface/50">
                              <tr>
                                <th className="px-4 py-2 text-left text-text-muted">REF</th>
                                <th className="px-4 py-2 text-left text-text-muted">Produto</th>
                                <th className="px-4 py-2 text-right text-text-muted">Qtd Peças</th>
                                <th className="px-4 py-2 text-right text-text-muted">Volume Cx</th>
                                <th className="px-4 py-2 text-right text-text-muted">Peso Total</th>
                                <th className="px-4 py-2 text-right text-text-muted">Cubagem Total</th>
                              </tr>
                            </thead>
                            <tbody className="divide-y divide-border/10 bg-transparent">
                              {itemsList.map((item) => (
                                <tr key={item.id} className="hover:bg-surface-hover/20">
                                  <td className="px-4 py-2 font-mono text-text-secondary">
                                    {item.product_ref_code_snapshot || '—'}
                                  </td>
                                  <td className="px-4 py-2 text-text-primary font-medium">
                                    {item.product_name_snapshot}
                                  </td>
                                  <td className="px-4 py-2 text-right font-medium">{item.quantity}</td>
                                  <td className="px-4 py-2 text-right text-text-secondary">
                                    {item.calculated_packages}
                                  </td>
                                  <td className="px-4 py-2 text-right text-text-secondary">
                                    {item.calculated_weight_kg.toFixed(1)} kg
                                  </td>
                                  <td className="px-4 py-2 text-right text-accent-blue font-medium">
                                    {item.calculated_volume_m3.toFixed(3)} m³
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      )}
                    </div>

                    {/* Actions Panel */}
                    <div className="flex flex-wrap items-center justify-between gap-4 pt-4 border-t border-border/20">
                      <button
                        type="button"
                        className="btn-danger py-1.5 px-3 text-xs"
                        onClick={(e) => {
                          e.stopPropagation()
                          handleDelete(cargo.id)
                        }}
                        disabled={isActionLoading}
                      >
                        {isActionLoading ? (
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        ) : (
                          <Trash2 className="w-3.5 h-3.5" />
                        )}
                        Excluir Carga
                      </button>

                      <div className="flex items-center gap-2">
                        {cargo.status < 3 ? (
                          <button
                            type="button"
                            className="btn-primary py-1.5 px-4 text-xs"
                            onClick={(e) => {
                              e.stopPropagation()
                              updateStatus(cargo.id, cargo.status)
                            }}
                            disabled={isActionLoading}
                          >
                            {isActionLoading ? (
                              <Loader2 className="w-3.5 h-3.5 animate-spin" />
                            ) : (
                              <Check className="w-3.5 h-3.5" />
                            )}
                            Avançar para: {STATUS_LABELS[cargo.status + 1]}
                          </button>
                        ) : (
                          <span className="text-xs font-semibold text-green-400 flex items-center gap-1 px-3 py-1.5 rounded-lg bg-green-500/10 border border-green-500/20">
                            <CheckCircle className="w-3.5 h-3.5" /> Entregue com Sucesso
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
