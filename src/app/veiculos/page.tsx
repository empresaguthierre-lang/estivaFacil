'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/lib/auth'
import { createClient } from '@/lib/supabase/client'
import {
  Truck,
  Plus,
  Pencil,
  Trash2,
  X,
  Activity,
  Weight,
  Box,
  Ruler,
} from 'lucide-react'

interface Vehicle {
  id: string
  company_id: string
  name: string
  kind: string
  body_type: string | null
  length_cm: number
  width_cm: number
  height_cm: number
  max_weight_kg: number
  max_volume_m3: number
  active: boolean
}

type VehicleForm = Omit<Vehicle, 'id' | 'company_id'>

const emptyForm: VehicleForm = {
  name: '',
  kind: 'VUC',
  body_type: 'Baú',
  length_cm: 0,
  width_cm: 0,
  height_cm: 0,
  max_weight_kg: 0,
  max_volume_m3: 0,
  active: true,
}

const VEHICLE_KINDS = [
  { value: 'VUC', label: 'VUC', description: 'Veículo Urbano de Carga' },
  { value: '3/4', label: '3/4', description: 'Três quartos' },
  { value: 'Toco', label: 'Toco', description: 'Caminhão Toco' },
  { value: 'Truck', label: 'Truck', description: 'Caminhão Truck' },
  { value: 'Bi-Truck', label: 'Bi-Truck', description: 'Bi-Truck' },
  { value: 'Carreta', label: 'Carreta', description: 'Carreta' },
  { value: 'Carreta LS', label: 'Carreta LS', description: 'Carreta LS' },
  { value: 'Bitrem', label: 'Bitrem', description: 'Bitrem' },
  { value: 'Rodotrem', label: 'Rodotrem', description: 'Rodotrem' },
]

const BODY_TYPES = ['Baú', 'Sider', 'Graneleiro', 'Tanque', 'Prancha', 'Aberto', 'Refrigerado', 'Outro']

function getVehicleIcon(kind: string): string {
  switch (kind) {
    case 'VUC':
    case '3/4':
      return '🚐'
    case 'Toco':
      return '🚚'
    case 'Truck':
    case 'Bi-Truck':
      return '🚛'
    case 'Carreta':
    case 'Carreta LS':
    case 'Bitrem':
    case 'Rodotrem':
      return '🚛'
    default:
      return '🚚'
  }
}

function getVehicleSizeLabel(kind: string): string {
  switch (kind) {
    case 'VUC':
    case '3/4':
      return 'Pequeno'
    case 'Toco':
      return 'Médio'
    case 'Truck':
    case 'Bi-Truck':
      return 'Grande'
    case 'Carreta':
    case 'Carreta LS':
    case 'Bitrem':
    case 'Rodotrem':
      return 'Extra Grande'
    default:
      return ''
  }
}

function getSizeBadgeClass(kind: string): string {
  switch (kind) {
    case 'VUC':
    case '3/4':
      return 'badge badge-blue'
    case 'Toco':
      return 'badge badge-green'
    case 'Truck':
    case 'Bi-Truck':
      return 'badge badge-yellow'
    default:
      return 'badge badge-violet'
  }
}

export default function VeiculosPage() {
  const { profile, loading: authLoading } = useAuth()
  const [vehicles, setVehicles] = useState<Vehicle[]>([])
  const [loading, setLoading] = useState(true)
  const [showModal, setShowModal] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<VehicleForm>(emptyForm)
  const [saving, setSaving] = useState(false)

  const supabase = createClient()

  useEffect(() => {
    if (!profile?.company_id) return
    fetchVehicles()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profile])

  async function fetchVehicles() {
    setLoading(true)
    const { data, error } = await supabase
      .from('vehicles')
      .select('*')
      .eq('company_id', profile!.company_id)
      .order('name', { ascending: true })

    if (!error && data) {
      setVehicles(data as Vehicle[])
    }
    setLoading(false)
  }

  function openCreate() {
    setForm(emptyForm)
    setEditingId(null)
    setShowModal(true)
  }

  function openEdit(v: Vehicle) {
    setForm({
      name: v.name,
      kind: v.kind,
      body_type: v.body_type ?? 'Baú',
      length_cm: v.length_cm,
      width_cm: v.width_cm,
      height_cm: v.height_cm,
      max_weight_kg: v.max_weight_kg,
      max_volume_m3: v.max_volume_m3,
      active: v.active,
    })
    setEditingId(v.id)
    setShowModal(true)
  }

  async function handleSave() {
    if (!profile?.company_id || !form.name.trim()) return
    setSaving(true)

    const volumeCalc =
      (Number(form.length_cm) * Number(form.width_cm) * Number(form.height_cm)) /
      1_000_000

    const payload = {
      company_id: profile.company_id,
      name: form.name.trim(),
      kind: form.kind,
      body_type: form.body_type || null,
      length_cm: Number(form.length_cm) || 0,
      width_cm: Number(form.width_cm) || 0,
      height_cm: Number(form.height_cm) || 0,
      max_weight_kg: Number(form.max_weight_kg) || 0,
      max_volume_m3:
        Number(form.max_volume_m3) > 0 ? Number(form.max_volume_m3) : volumeCalc,
      active: form.active,
    }

    if (editingId) {
      await supabase.from('vehicles').update(payload).eq('id', editingId)
    } else {
      await supabase.from('vehicles').insert(payload)
    }

    setSaving(false)
    setShowModal(false)
    fetchVehicles()
  }

  async function handleDelete(id: string) {
    if (!confirm('Tem certeza que deseja excluir este veículo?')) return
    await supabase.from('vehicles').delete().eq('id', id)
    fetchVehicles()
  }

  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="flex flex-col items-center gap-4">
          <Activity className="w-8 h-8 text-accent-violet animate-pulse" />
          <p className="text-text-secondary text-sm">Carregando veículos...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-500/20 to-purple-500/20 flex items-center justify-center">
            <Truck className="w-5 h-5 text-accent-violet" />
          </div>
          <div>
            <h1
              className="text-2xl font-bold text-text-primary tracking-tight"
              style={{ fontFamily: 'var(--font-heading)' }}
            >
              Veículos
            </h1>
            <p className="text-text-muted text-sm">
              {vehicles.length} veículo{vehicles.length !== 1 ? 's' : ''} cadastrado{vehicles.length !== 1 ? 's' : ''}
            </p>
          </div>
        </div>
        <button className="btn-primary" onClick={openCreate}>
          <Plus className="w-4 h-4" />
          Novo Veículo
        </button>
      </div>

      {/* Vehicle Cards */}
      {vehicles.length === 0 ? (
        <div className="glass-card p-12 text-center">
          <Truck className="w-12 h-12 text-text-muted mx-auto mb-4" />
          <p className="text-text-muted">
            Nenhum veículo cadastrado. Clique em &quot;Novo Veículo&quot; para
            começar.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
          {vehicles.map((v) => {
            const maxCapKg = Math.max(v.max_weight_kg, 1)
            const maxCapM3 = Math.max(v.max_volume_m3, 0.01)

            return (
              <div
                key={v.id}
                className={`glass-card p-6 relative ${
                  !v.active ? 'opacity-50' : ''
                }`}
              >
                {/* Header */}
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <span className="text-3xl">{getVehicleIcon(v.kind)}</span>
                    <div>
                      <h3 className="font-semibold text-text-primary text-lg">
                        {v.name}
                      </h3>
                      <div className="flex items-center gap-2 mt-1">
                        <span className={getSizeBadgeClass(v.kind)}>
                          {v.kind}
                        </span>
                        {v.body_type && (
                          <span className="badge badge-gray">{v.body_type}</span>
                        )}
                      </div>
                    </div>
                  </div>
                  <span className="text-xs text-text-muted">
                    {getVehicleSizeLabel(v.kind)}
                  </span>
                </div>

                {/* Capacity Bars */}
                <div className="space-y-3 mb-4">
                  <div>
                    <div className="flex items-center justify-between text-sm mb-1">
                      <span className="text-text-muted flex items-center gap-1.5">
                        <Weight className="w-3.5 h-3.5" />
                        Peso Máximo
                      </span>
                      <span className="text-text-secondary font-medium">
                        {v.max_weight_kg.toLocaleString('pt-BR')} kg
                      </span>
                    </div>
                    <div className="progress-bar">
                      <div
                        className="progress-bar-fill"
                        style={{
                          width: '100%',
                          background:
                            'linear-gradient(90deg, #3b82f6, #6366f1)',
                        }}
                      />
                    </div>
                  </div>

                  <div>
                    <div className="flex items-center justify-between text-sm mb-1">
                      <span className="text-text-muted flex items-center gap-1.5">
                        <Box className="w-3.5 h-3.5" />
                        Volume Máximo
                      </span>
                      <span className="text-text-secondary font-medium">
                        {maxCapM3.toFixed(2)} m³
                      </span>
                    </div>
                    <div className="progress-bar">
                      <div
                        className="progress-bar-fill"
                        style={{
                          width: '100%',
                          background:
                            'linear-gradient(90deg, #8b5cf6, #a78bfa)',
                        }}
                      />
                    </div>
                  </div>
                </div>

                {/* Dimensions */}
                <div className="flex items-center gap-2 text-sm text-text-muted mb-5">
                  <Ruler className="w-3.5 h-3.5" />
                  <span className="font-mono">
                    {v.length_cm}×{v.width_cm}×{v.height_cm} cm
                  </span>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-2">
                  <button
                    className="btn-secondary flex-1 justify-center"
                    onClick={() => openEdit(v)}
                  >
                    <Pencil className="w-4 h-4" />
                    Editar
                  </button>
                  <button
                    className="btn-danger"
                    onClick={() => handleDelete(v.id)}
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-6">
              <h2
                className="text-xl font-semibold text-text-primary"
                style={{ fontFamily: 'var(--font-heading)' }}
              >
                {editingId ? 'Editar Veículo' : 'Novo Veículo'}
              </h2>
              <button
                className="text-text-muted hover:text-text-primary transition-colors"
                onClick={() => setShowModal(false)}
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Name */}
              <div>
                <label className="text-sm text-text-secondary mb-1 block">
                  Nome do Veículo *
                </label>
                <input
                  type="text"
                  className="input-field"
                  placeholder="Ex: VUC Baú 3.5t"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>

              {/* Kind + Body Type */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-text-secondary mb-1 block">
                    Tipo
                  </label>
                  <select
                    className="input-field"
                    value={form.kind}
                    onChange={(e) => setForm({ ...form, kind: e.target.value })}
                  >
                    {VEHICLE_KINDS.map((k) => (
                      <option key={k.value} value={k.value}>
                        {k.label} — {k.description}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-sm text-text-secondary mb-1 block">
                    Carroceria
                  </label>
                  <select
                    className="input-field"
                    value={form.body_type ?? 'Baú'}
                    onChange={(e) =>
                      setForm({ ...form, body_type: e.target.value })
                    }
                  >
                    {BODY_TYPES.map((bt) => (
                      <option key={bt} value={bt}>
                        {bt}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Dimensions */}
              <div>
                <label className="text-sm text-text-secondary mb-2 block">
                  Dimensões Internas (cm)
                </label>
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className="text-xs text-text-muted mb-1 block">
                      Comprimento
                    </label>
                    <input
                      type="number"
                      step="1"
                      min="0"
                      className="input-field"
                      value={form.length_cm || ''}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          length_cm: parseFloat(e.target.value) || 0,
                        })
                      }
                    />
                  </div>
                  <div>
                    <label className="text-xs text-text-muted mb-1 block">
                      Largura
                    </label>
                    <input
                      type="number"
                      step="1"
                      min="0"
                      className="input-field"
                      value={form.width_cm || ''}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          width_cm: parseFloat(e.target.value) || 0,
                        })
                      }
                    />
                  </div>
                  <div>
                    <label className="text-xs text-text-muted mb-1 block">
                      Altura
                    </label>
                    <input
                      type="number"
                      step="1"
                      min="0"
                      className="input-field"
                      value={form.height_cm || ''}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          height_cm: parseFloat(e.target.value) || 0,
                        })
                      }
                    />
                  </div>
                </div>
              </div>

              {/* Max Weight & Volume */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-text-secondary mb-1 block">
                    Peso Máximo (kg)
                  </label>
                  <input
                    type="number"
                    step="1"
                    min="0"
                    className="input-field"
                    value={form.max_weight_kg || ''}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        max_weight_kg: parseFloat(e.target.value) || 0,
                      })
                    }
                  />
                </div>
                <div>
                  <label className="text-sm text-text-secondary mb-1 block">
                    Volume Máximo (m³)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    className="input-field"
                    placeholder="Auto-calculado se vazio"
                    value={form.max_volume_m3 || ''}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        max_volume_m3: parseFloat(e.target.value) || 0,
                      })
                    }
                  />
                </div>
              </div>

              {/* Volume Preview */}
              <div className="glass-card p-4 !border-accent-violet/20">
                <div className="text-xs text-text-muted mb-1">
                  Volume calculado pelas dimensões
                </div>
                <div className="text-lg font-bold text-accent-violet font-mono">
                  {(
                    (Number(form.length_cm) *
                      Number(form.width_cm) *
                      Number(form.height_cm)) /
                    1_000_000
                  ).toFixed(2)}{' '}
                  m³
                </div>
              </div>

              {/* Active Toggle */}
              <div className="flex items-center justify-between py-2">
                <label className="text-sm text-text-secondary">
                  Veículo Ativo
                </label>
                <button
                  type="button"
                  className={`toggle-switch ${form.active ? 'active' : ''}`}
                  onClick={() => setForm({ ...form, active: !form.active })}
                />
              </div>
            </div>

            {/* Actions */}
            <div className="flex items-center justify-end gap-3 mt-8">
              <button
                className="btn-secondary"
                onClick={() => setShowModal(false)}
              >
                Cancelar
              </button>
              <button
                className="btn-primary"
                onClick={handleSave}
                disabled={saving || !form.name.trim()}
              >
                {saving
                  ? 'Salvando...'
                  : editingId
                  ? 'Salvar Alterações'
                  : 'Criar Veículo'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
