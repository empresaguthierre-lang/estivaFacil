'use client'

import { useAuth } from '@/lib/auth'
import { LayoutDashboard, Package, Truck, Boxes, TrendingUp, Loader2 } from 'lucide-react'

export default function DashboardPage() {
  const { profile, loading } = useAuth()

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <Loader2 size={32} className="animate-spin-slow text-[var(--accent)]" />
      </div>
    )
  }

  const stats = [
    {
      label: 'Produtos Cadastrados',
      value: '—',
      icon: Package,
      color: 'from-indigo-500 to-violet-500',
    },
    {
      label: 'Veículos Disponíveis',
      value: '—',
      icon: Truck,
      color: 'from-emerald-500 to-teal-500',
    },
    {
      label: 'Cargas em Andamento',
      value: '—',
      icon: Boxes,
      color: 'from-amber-500 to-orange-500',
    },
    {
      label: 'Cotações do Mês',
      value: '—',
      icon: TrendingUp,
      color: 'from-rose-500 to-pink-500',
    },
  ]

  return (
    <div className="animate-fade-in">
      {/* Header */}
      <div className="page-header">
        <div>
          <h1 className="page-title flex items-center gap-3">
            <LayoutDashboard size={28} />
            Dashboard
          </h1>
          <p className="text-[var(--text-secondary)] mt-1">
            Bem-vindo{profile?.name ? `, ${profile.name.split(' ')[0]}` : ''}! Aqui está o resumo da sua operação.
          </p>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4 mb-8 stagger-children">
        {stats.map((stat) => {
          const Icon = stat.icon
          return (
            <div
              key={stat.label}
              className="glass-card stat-card p-5 flex items-start gap-4"
            >
              <div
                className={`flex items-center justify-center w-11 h-11 rounded-xl bg-gradient-to-br ${stat.color} shadow-lg flex-shrink-0`}
              >
                <Icon size={22} className="text-white" />
              </div>
              <div>
                <p className="text-sm text-[var(--text-secondary)]">{stat.label}</p>
                <p className="text-2xl font-bold mt-0.5" style={{ fontFamily: 'Outfit, sans-serif' }}>
                  {stat.value}
                </p>
              </div>
            </div>
          )
        })}
      </div>

      {/* Quick Actions */}
      <div className="glass-card-static p-6">
        <h2
          className="text-lg font-semibold mb-4"
          style={{ fontFamily: 'Outfit, sans-serif' }}
        >
          Início Rápido
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {[
            { label: 'Cadastrar Produto', desc: 'Adicione produtos ao catálogo', href: '/produtos', icon: Package },
            { label: 'Adicionar Veículo', desc: 'Cadastre veículos da frota', href: '/veiculos', icon: Truck },
            { label: 'Nova Carga', desc: 'Monte e cube uma nova carga', href: '/cargas', icon: Boxes },
          ].map((action) => {
            const Icon = action.icon
            return (
              <a
                key={action.label}
                href={action.href}
                className="flex items-center gap-3 p-4 rounded-xl border border-[var(--border)] bg-[var(--bg-input)] hover:border-[var(--border-hover)] hover:bg-[var(--accent-muted)] transition-all duration-200 group"
              >
                <Icon
                  size={20}
                  className="text-[var(--accent)] group-hover:text-[var(--accent-hover)] transition-colors"
                />
                <div>
                  <p className="text-sm font-medium text-[var(--text-primary)]">
                    {action.label}
                  </p>
                  <p className="text-xs text-[var(--text-muted)]">{action.desc}</p>
                </div>
              </a>
            )
          })}
        </div>
      </div>
    </div>
  )
}
