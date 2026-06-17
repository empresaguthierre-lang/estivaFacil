'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useAuth } from '@/lib/auth'
import {
  LayoutDashboard,
  Package,
  Truck,
  Boxes,
  Calculator,
  Settings,
  LogOut,
  Menu,
  X,
  Container,
} from 'lucide-react'

const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { name: 'Produtos', href: '/produtos', icon: Package },
  { name: 'Veículos', href: '/veiculos', icon: Truck },
  { name: 'Cargas', href: '/cargas', icon: Boxes },
  { name: 'Cotações', href: '/cotacoes', icon: Calculator },
  { name: 'Configurações', href: '/configuracoes', icon: Settings },
]

const roleLabels: Record<string, string> = {
  admin: 'Administrador',
  operador: 'Operador',
  vendedor: 'Vendedor',
}

export default function Sidebar() {
  const [mobileOpen, setMobileOpen] = useState(false)
  const pathname = usePathname()
  const { profile, signOut, loading } = useAuth()

  const isActive = (href: string) => {
    if (href === '/dashboard') {
      return pathname === '/dashboard'
    }
    return pathname.startsWith(href)
  }

  const closeMobile = () => setMobileOpen(false)

  return (
    <>
      {/* Mobile hamburger button */}
      <button
        type="button"
        onClick={() => setMobileOpen(true)}
        className="fixed top-4 left-4 z-50 lg:hidden btn btn-ghost"
        aria-label="Abrir menu"
      >
        <Menu size={22} />
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="sidebar-overlay lg:hidden"
          onClick={closeMobile}
          aria-hidden="true"
        />
      )}

      {/* Sidebar */}
      <aside
        className={`sidebar ${mobileOpen ? 'sidebar-open' : ''}`}
        role="navigation"
        aria-label="Menu principal"
      >
        {/* Header / Logo */}
        <div className="flex items-center justify-between px-5 py-6 border-b border-[var(--border)]">
          <Link
            href="/dashboard"
            className="flex items-center gap-3 group"
            onClick={closeMobile}
          >
            <div className="flex items-center justify-center w-9 h-9 rounded-lg bg-gradient-to-br from-indigo-500 to-violet-600 shadow-lg shadow-indigo-500/20 transition-transform duration-200 group-hover:scale-105">
              <Container size={20} className="text-white" />
            </div>
            <div>
              <h1 className="text-lg font-bold tracking-tight" style={{ fontFamily: 'Outfit, sans-serif' }}>
                Estiva<span className="bg-gradient-to-r from-indigo-400 to-violet-400 bg-clip-text text-transparent">Fácil</span>
              </h1>
            </div>
          </Link>

          {/* Mobile close button */}
          <button
            type="button"
            onClick={closeMobile}
            className="lg:hidden btn btn-ghost"
            aria-label="Fechar menu"
          >
            <X size={20} />
          </button>
        </div>

        {/* Navigation Links */}
        <nav className="flex-1 py-4 space-y-1 overflow-y-auto">
          {navigation.map((item) => {
            const Icon = item.icon
            const active = isActive(item.href)

            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={closeMobile}
                className={`nav-link ${active ? 'nav-link-active' : ''}`}
              >
                <Icon size={20} strokeWidth={active ? 2.2 : 1.8} />
                <span>{item.name}</span>
              </Link>
            )
          })}
        </nav>

        {/* User Info Footer */}
        <div className="border-t border-[var(--border)] p-4">
          {loading ? (
            <div className="flex items-center gap-3 px-2">
              <div className="w-9 h-9 rounded-full animate-shimmer" />
              <div className="flex-1 space-y-1.5">
                <div className="w-24 h-3 rounded animate-shimmer" />
                <div className="w-16 h-2.5 rounded animate-shimmer" />
              </div>
            </div>
          ) : profile ? (
            <div className="flex items-center gap-3 px-2">
              {/* Avatar */}
              <div className="flex items-center justify-center w-9 h-9 rounded-full bg-gradient-to-br from-indigo-500 to-violet-600 text-white text-sm font-semibold flex-shrink-0">
                {profile.name
                  .split(' ')
                  .slice(0, 2)
                  .map((n) => n[0])
                  .join('')
                  .toUpperCase()}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-[var(--text-primary)] truncate">
                  {profile.name}
                </p>
                <span className="badge badge-accent">
                  {roleLabels[profile.role] || profile.role}
                </span>
              </div>
              <button
                onClick={signOut}
                className="btn btn-ghost flex-shrink-0"
                title="Sair"
                aria-label="Sair da conta"
              >
                <LogOut size={18} />
              </button>
            </div>
          ) : null}
        </div>
      </aside>
    </>
  )
}
