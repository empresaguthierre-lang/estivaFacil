import type { Metadata } from 'next'
import './globals.css'
import { LayoutShell } from './components/LayoutShell'

export const metadata: Metadata = {
  title: {
    default: 'EstivaFácil - Cubagem e Estiva Inteligente',
    template: '%s | EstivaFácil',
  },
  description:
    'Plataforma inteligente para cubagem de cargas, planejamento de estiva e seleção de veículos. Otimize sua operação logística com EstivaFácil.',
  keywords: [
    'cubagem',
    'estiva',
    'logística',
    'cargas',
    'veículos',
    'frete',
    'cotação',
    'transporte',
  ],
  authors: [{ name: 'EstivaFácil' }],
  openGraph: {
    title: 'EstivaFácil - Cubagem e Estiva Inteligente',
    description:
      'Otimize sua operação logística com cubagem inteligente e planejamento de estiva.',
    type: 'website',
    locale: 'pt_BR',
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="pt-BR" className="h-full antialiased">
      <body className="min-h-full">
        <LayoutShell>{children}</LayoutShell>
      </body>
    </html>
  )
}
