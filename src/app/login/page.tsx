'use client'

import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/lib/auth'
import { Container, Eye, EyeOff, Loader2 } from 'lucide-react'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const { signIn } = useAuth()
  const router = useRouter()

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setIsSubmitting(true)

    const { error: authError } = await signIn(email, password)

    if (authError) {
      setIsSubmitting(false)
      switch (authError.message) {
        case 'Invalid login credentials':
          setError('E-mail ou senha incorretos.')
          break
        case 'Email not confirmed':
          setError('E-mail não confirmado. Verifique sua caixa de entrada.')
          break
        default:
          setError(authError.message || 'Erro ao fazer login. Tente novamente.')
      }
      return
    }

    router.push('/dashboard')
  }

  return (
    <div className="gradient-bg min-h-screen flex items-center justify-center px-4 py-12">
      {/* Decorative orbs */}
      <div
        className="fixed top-20 left-10 w-72 h-72 rounded-full opacity-20 blur-3xl pointer-events-none"
        style={{ background: 'radial-gradient(circle, #6366f1, transparent)' }}
      />
      <div
        className="fixed bottom-20 right-10 w-96 h-96 rounded-full opacity-10 blur-3xl pointer-events-none"
        style={{ background: 'radial-gradient(circle, #8b5cf6, transparent)' }}
      />

      <div className="w-full max-w-md animate-slide-up">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-indigo-500 to-violet-600 shadow-xl shadow-indigo-500/25 mb-4">
            <Container size={32} className="text-white" />
          </div>
          <h1
            className="text-3xl font-bold tracking-tight"
            style={{ fontFamily: 'Outfit, sans-serif' }}
          >
            Estiva
            <span className="bg-gradient-to-r from-indigo-400 to-violet-400 bg-clip-text text-transparent">
              Fácil
            </span>
          </h1>
          <p className="mt-2 text-[var(--text-secondary)] text-sm">
            Cubagem e estiva inteligente para sua operação logística
          </p>
        </div>

        {/* Login Card */}
        <div className="glass-card-static p-8">
          <h2 className="text-xl font-semibold mb-6 text-center" style={{ fontFamily: 'Outfit, sans-serif' }}>
            Acesse sua conta
          </h2>

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Email field */}
            <div>
              <label htmlFor="email" className="label">
                E-mail
              </label>
              <input
                id="email"
                type="email"
                required
                autoComplete="email"
                placeholder="seu@email.com"
                className="input"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={isSubmitting}
              />
            </div>

            {/* Password field */}
            <div>
              <label htmlFor="password" className="label">
                Senha
              </label>
              <div className="relative">
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  required
                  autoComplete="current-password"
                  placeholder="••••••••"
                  className="input pr-10"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={isSubmitting}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[var(--text-muted)] hover:text-[var(--text-secondary)] transition-colors"
                  tabIndex={-1}
                  aria-label={showPassword ? 'Ocultar senha' : 'Mostrar senha'}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            {/* Error message */}
            {error && (
              <div className="flex items-start gap-2 p-3 rounded-lg bg-[var(--danger-bg)] border border-red-500/20 animate-fade-in">
                <div className="w-1 h-1 mt-1.5 rounded-full bg-[var(--danger)] flex-shrink-0" />
                <p className="text-sm text-[var(--danger)]">{error}</p>
              </div>
            )}

            {/* Submit button */}
            <button
              type="submit"
              disabled={isSubmitting || !email || !password}
              className="btn btn-primary btn-lg w-full"
            >
              {isSubmitting ? (
                <>
                  <Loader2 size={18} className="animate-spin-slow" />
                  Entrando...
                </>
              ) : (
                'Entrar'
              )}
            </button>
          </form>
        </div>

        {/* Footer */}
        <p className="text-center mt-6 text-xs text-[var(--text-muted)]">
          © {new Date().getFullYear()} EstivaFácil. Todos os direitos reservados.
        </p>
      </div>
    </div>
  )
}
