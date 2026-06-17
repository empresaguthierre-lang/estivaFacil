'use client'

import { usePathname } from 'next/navigation'
import { AuthProvider } from '@/lib/auth'
import Sidebar from './Sidebar'
import type { ReactNode } from 'react'

const PUBLIC_ROUTES = ['/login']

export function LayoutShell({ children }: { children: ReactNode }) {
  const pathname = usePathname()
  const isPublicRoute = PUBLIC_ROUTES.includes(pathname)

  return (
    <AuthProvider>
      {isPublicRoute ? (
        <>{children}</>
      ) : (
        <>
          <Sidebar />
          <main className="main-content">
            <div className="p-6 lg:p-8">{children}</div>
          </main>
        </>
      )}
    </AuthProvider>
  )
}
