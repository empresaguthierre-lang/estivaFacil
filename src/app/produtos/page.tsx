'use client'

import { useEffect, useState, useMemo } from 'react'
import { useAuth } from '@/lib/auth'
import { createClient } from '@/lib/supabase/client'
import {
  Package,
  Plus,
  Search,
  Pencil,
  Trash2,
  X,
  Activity,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react'

interface Product {
  id: string
  company_id: string
  internal_code: string | null
  ref_code: string | null
  name: string
  description: string | null
  unit: string | null
  weight_per_unit_kg: number | null
  package_length_cm: number
  package_width_cm: number
  package_height_cm: number
  package_weight_kg: number
  units_per_package: number
  volume_multiplier: number
  active: boolean
}

type ProductForm = Omit<Product, 'id' | 'company_id'>

const emptyForm: ProductForm = {
  internal_code: '',
  ref_code: '',
  name: '',
  description: '',
  unit: 'UN',
  weight_per_unit_kg: null,
  package_length_cm: 0,
  package_width_cm: 0,
  package_height_cm: 0,
  package_weight_kg: 0,
  units_per_package: 1,
  volume_multiplier: 1,
  active: true,
}

const ITEMS_PER_PAGE = 15

export default function ProdutosPage() {
  const { profile, loading: authLoading } = useAuth()
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [showModal, setShowModal] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<ProductForm>(emptyForm)
  const [saving, setSaving] = useState(false)

  const supabase = createClient()

  useEffect(() => {
    if (!profile?.company_id) return
    fetchProducts()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profile])

  async function fetchProducts() {
    setLoading(true)
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .eq('company_id', profile!.company_id)
      .order('name', { ascending: true })

    if (!error && data) {
      setProducts(data as Product[])
    }
    setLoading(false)
  }

  const filtered = useMemo(() => {
    if (!search.trim()) return products
    const q = search.toLowerCase()
    return products.filter(
      (p) =>
        p.name.toLowerCase().includes(q) ||
        (p.ref_code && p.ref_code.toLowerCase().includes(q)) ||
        (p.internal_code && p.internal_code.toLowerCase().includes(q))
    )
  }, [products, search])

  const totalPages = Math.max(1, Math.ceil(filtered.length / ITEMS_PER_PAGE))
  const paginated = filtered.slice(
    (page - 1) * ITEMS_PER_PAGE,
    page * ITEMS_PER_PAGE
  )

  function openCreate() {
    setForm(emptyForm)
    setEditingId(null)
    setShowModal(true)
  }

  function openEdit(product: Product) {
    setForm({
      internal_code: product.internal_code ?? '',
      ref_code: product.ref_code ?? '',
      name: product.name,
      description: product.description ?? '',
      unit: product.unit ?? 'UN',
      weight_per_unit_kg: product.weight_per_unit_kg,
      package_length_cm: product.package_length_cm,
      package_width_cm: product.package_width_cm,
      package_height_cm: product.package_height_cm,
      package_weight_kg: product.package_weight_kg,
      units_per_package: product.units_per_package,
      volume_multiplier: product.volume_multiplier,
      active: product.active,
    })
    setEditingId(product.id)
    setShowModal(true)
  }

  async function handleSave() {
    if (!profile?.company_id || !form.name.trim()) return
    setSaving(true)

    const payload = {
      company_id: profile.company_id,
      internal_code: form.internal_code || null,
      ref_code: form.ref_code || null,
      name: form.name.trim(),
      description: form.description || null,
      unit: form.unit || 'UN',
      weight_per_unit_kg: form.weight_per_unit_kg,
      package_length_cm: Number(form.package_length_cm) || 0,
      package_width_cm: Number(form.package_width_cm) || 0,
      package_height_cm: Number(form.package_height_cm) || 0,
      package_weight_kg: Number(form.package_weight_kg) || 0,
      units_per_package: Number(form.units_per_package) || 1,
      volume_multiplier: Number(form.volume_multiplier) || 1,
      active: form.active,
    }

    if (editingId) {
      await supabase.from('products').update(payload).eq('id', editingId)
    } else {
      await supabase.from('products').insert(payload)
    }

    setSaving(false)
    setShowModal(false)
    fetchProducts()
  }

  async function handleDelete(id: string) {
    if (!confirm('Tem certeza que deseja excluir este produto?')) return
    await supabase.from('products').delete().eq('id', id)
    fetchProducts()
  }

  function calcCubagem(p: Product): number {
    return (p.package_length_cm * p.package_width_cm * p.package_height_cm) / 1_000_000
  }

  function multiplierBadgeClass(m: number): string {
    if (m >= 3) return 'badge badge-red'
    if (m === 2) return 'badge badge-yellow'
    return 'badge badge-gray'
  }

  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="flex flex-col items-center gap-4">
          <Activity className="w-8 h-8 text-accent-violet animate-pulse" />
          <p className="text-text-secondary text-sm">Carregando produtos...</p>
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
            <Package className="w-5 h-5 text-accent-violet" />
          </div>
          <div>
            <h1
              className="text-2xl font-bold text-text-primary tracking-tight"
              style={{ fontFamily: 'var(--font-heading)' }}
            >
              Produtos
            </h1>
            <p className="text-text-muted text-sm">
              {filtered.length} produto{filtered.length !== 1 ? 's' : ''} encontrado{filtered.length !== 1 ? 's' : ''}
            </p>
          </div>
        </div>
        <button className="btn-primary" onClick={openCreate}>
          <Plus className="w-4 h-4" />
          Novo Produto
        </button>
      </div>

      {/* Search */}
      <div className="relative max-w-md">
        <Search className="w-4 h-4 absolute left-4 top-1/2 -translate-y-1/2 text-text-muted" />
        <input
          type="text"
          placeholder="Buscar por nome ou referência..."
          className="input-field pl-11"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(1)
          }}
        />
      </div>

      {/* Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>REF</th>
                <th>Nome</th>
                <th>Dimensões (L×A×P)</th>
                <th>Peso CX</th>
                <th>QTD/CX</th>
                <th>Multiplicador</th>
                <th>Cubagem</th>
                <th>Status</th>
                <th className="text-right">Ações</th>
              </tr>
            </thead>
            <tbody>
              {paginated.length === 0 ? (
                <tr>
                  <td colSpan={9} className="text-center py-12 text-text-muted">
                    {search
                      ? 'Nenhum produto encontrado para a busca.'
                      : 'Nenhum produto cadastrado. Clique em "Novo Produto" para começar.'}
                  </td>
                </tr>
              ) : (
                paginated.map((p) => (
                  <tr key={p.id}>
                    <td className="font-mono text-accent-blue text-sm">
                      {p.ref_code || '—'}
                    </td>
                    <td>
                      <div className="font-medium text-text-primary">{p.name}</div>
                      {p.internal_code && (
                        <div className="text-xs text-text-muted">
                          Cód: {p.internal_code}
                        </div>
                      )}
                    </td>
                    <td className="font-mono text-sm">
                      {p.package_length_cm}×{p.package_width_cm}×{p.package_height_cm} cm
                    </td>
                    <td>{p.package_weight_kg.toFixed(2)} kg</td>
                    <td className="text-center">{p.units_per_package}</td>
                    <td>
                      <span className={multiplierBadgeClass(p.volume_multiplier)}>
                        ×{p.volume_multiplier}
                      </span>
                    </td>
                    <td className="font-mono text-sm">
                      {calcCubagem(p).toFixed(6)} m³
                    </td>
                    <td>
                      <span
                        className={`badge ${p.active ? 'badge-green' : 'badge-gray'}`}
                      >
                        {p.active ? 'Ativo' : 'Inativo'}
                      </span>
                    </td>
                    <td>
                      <div className="flex items-center justify-end gap-2">
                        <button
                          className="btn-secondary !p-2"
                          onClick={() => openEdit(p)}
                          title="Editar"
                        >
                          <Pencil className="w-4 h-4" />
                        </button>
                        <button
                          className="btn-danger !p-2"
                          onClick={() => handleDelete(p.id)}
                          title="Excluir"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between px-6 py-4 border-t border-[rgba(139,92,246,0.06)]">
            <span className="text-sm text-text-muted">
              Página {page} de {totalPages}
            </span>
            <div className="flex gap-2">
              <button
                className="btn-secondary !p-2"
                disabled={page === 1}
                onClick={() => setPage((p) => p - 1)}
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <button
                className="btn-secondary !p-2"
                disabled={page === totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-6">
              <h2
                className="text-xl font-semibold text-text-primary"
                style={{ fontFamily: 'var(--font-heading)' }}
              >
                {editingId ? 'Editar Produto' : 'Novo Produto'}
              </h2>
              <button
                className="text-text-muted hover:text-text-primary transition-colors"
                onClick={() => setShowModal(false)}
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Row: Codes */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-text-secondary mb-1 block">
                    Código Interno
                  </label>
                  <input
                    type="text"
                    className="input-field"
                    placeholder="EX-001"
                    value={form.internal_code ?? ''}
                    onChange={(e) =>
                      setForm({ ...form, internal_code: e.target.value })
                    }
                  />
                </div>
                <div>
                  <label className="text-sm text-text-secondary mb-1 block">
                    Código Referência
                  </label>
                  <input
                    type="text"
                    className="input-field"
                    placeholder="REF-001"
                    value={form.ref_code ?? ''}
                    onChange={(e) =>
                      setForm({ ...form, ref_code: e.target.value })
                    }
                  />
                </div>
              </div>

              {/* Name */}
              <div>
                <label className="text-sm text-text-secondary mb-1 block">
                  Nome do Produto *
                </label>
                <input
                  type="text"
                  className="input-field"
                  placeholder="Nome do produto"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>

              {/* Description */}
              <div>
                <label className="text-sm text-text-secondary mb-1 block">
                  Descrição
                </label>
                <input
                  type="text"
                  className="input-field"
                  placeholder="Descrição opcional"
                  value={form.description ?? ''}
                  onChange={(e) =>
                    setForm({ ...form, description: e.target.value })
                  }
                />
              </div>

              {/* Dimensions */}
              <div>
                <label className="text-sm text-text-secondary mb-2 block">
                  Dimensões da Caixa (cm)
                </label>
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className="text-xs text-text-muted mb-1 block">
                      Comprimento
                    </label>
                    <input
                      type="number"
                      step="0.1"
                      min="0"
                      className="input-field"
                      value={form.package_length_cm || ''}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          package_length_cm: parseFloat(e.target.value) || 0,
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
                      step="0.1"
                      min="0"
                      className="input-field"
                      value={form.package_width_cm || ''}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          package_width_cm: parseFloat(e.target.value) || 0,
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
                      step="0.1"
                      min="0"
                      className="input-field"
                      value={form.package_height_cm || ''}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          package_height_cm: parseFloat(e.target.value) || 0,
                        })
                      }
                    />
                  </div>
                </div>
              </div>

              {/* Weight & Units */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-text-secondary mb-1 block">
                    Peso da Caixa (kg)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    className="input-field"
                    value={form.package_weight_kg || ''}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        package_weight_kg: parseFloat(e.target.value) || 0,
                      })
                    }
                  />
                </div>
                <div>
                  <label className="text-sm text-text-secondary mb-1 block">
                    Unidades por Caixa
                  </label>
                  <input
                    type="number"
                    step="1"
                    min="1"
                    className="input-field"
                    value={form.units_per_package || ''}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        units_per_package: parseInt(e.target.value) || 1,
                      })
                    }
                  />
                </div>
              </div>

              {/* Volume Multiplier */}
              <div>
                <label className="text-sm text-text-secondary mb-1 block">
                  Multiplicador de Volume
                </label>
                <select
                  className="input-field"
                  value={form.volume_multiplier}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      volume_multiplier: parseInt(e.target.value),
                    })
                  }
                >
                  <option value={1}>×1 — Normal</option>
                  <option value={2}>×2 — Pote (pote + tampa)</option>
                  <option value={3}>×3 — Kit (pote + tampa + acessório)</option>
                  <option value={4}>×4 — Kit Especial</option>
                  <option value={5}>×5 — Kit Grande</option>
                </select>
              </div>

              {/* Active Toggle */}
              <div className="flex items-center justify-between py-2">
                <label className="text-sm text-text-secondary">
                  Produto Ativo
                </label>
                <button
                  type="button"
                  className={`toggle-switch ${form.active ? 'active' : ''}`}
                  onClick={() => setForm({ ...form, active: !form.active })}
                />
              </div>

              {/* Cubagem Preview */}
              <div className="glass-card p-4 !border-accent-violet/20">
                <div className="text-xs text-text-muted mb-1">
                  Cubagem unitária (por caixa)
                </div>
                <div className="text-lg font-bold text-accent-violet font-mono">
                  {(
                    (form.package_length_cm *
                      form.package_width_cm *
                      form.package_height_cm) /
                    1_000_000
                  ).toFixed(6)}{' '}
                  m³
                </div>
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
                {saving ? 'Salvando...' : editingId ? 'Salvar Alterações' : 'Criar Produto'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
