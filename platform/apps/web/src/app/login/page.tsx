import Link from 'next/link'
import type { Metadata } from 'next'
import { LumenWordmark } from '@/lib/lumen-wordmark'

export const metadata: Metadata = {
  title: 'Entrar · Lumen Web',
}

export default function LoginPage() {
  return (
    <main className="min-h-screen bg-[#FAF9F7] flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8 flex flex-col items-center">
          <a href="https://lumen.app" aria-label="Lumen">
            <LumenWordmark className="h-8 w-auto" />
          </a>
          <p className="text-[#6B6863] text-sm mt-3">
            Use a mesma conta do app Lumen
          </p>
        </div>

        <div className="bg-[#FAF9F7] border border-[#ECEAE9] rounded-2xl p-6">
          <a
            href="/auth/google"
            className="flex items-center justify-center gap-3 w-full border border-[#ECEAE9] rounded-xl px-4 py-3 text-sm font-medium text-[#1A1918] hover:bg-[#F2F1EF] transition-colors"
          >
            <GoogleIcon />
            Continuar com Google
          </a>

          <div className="relative my-5">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-[#ECEAE9]" />
            </div>
            <div className="relative flex justify-center">
              <span className="bg-[#FAF9F7] px-3 text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">ou</span>
            </div>
          </div>

          <form action="/auth/magic-link" method="POST" className="space-y-3">
            <input
              type="email"
              name="email"
              placeholder="seu@email.com"
              required
              className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] transition-colors"
            />
            <button
              type="submit"
              className="w-full bg-[#1A1918] text-[#FAF9F7] rounded-xl px-4 py-2.5 text-sm font-medium hover:bg-[#2C2B29] transition-colors"
            >
              Enviar magic link
            </button>
          </form>
        </div>

        <p className="text-center text-xs text-[#B0AEA9] mt-6">
          Não tem conta?{' '}
          <a href="https://lumen.app/download" className="text-[#3D6B5A] hover:underline">
            Baixe o app
          </a>
        </p>
      </div>
    </main>
  )
}

function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
    </svg>
  )
}
