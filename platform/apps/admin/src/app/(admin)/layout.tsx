import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { isAdminRole } from '@lumen/types'

/**
 * Layout do Admin Console (admin.lumen.app).
 *
 * Rotas:
 *   /                 → Dashboard
 *   /users            → Usuários
 *   /clubs            → Clubes
 *   /books            → Livros
 *   /moderation       → Moderação
 *   /billing          → Financeiro
 *   /analytics        → Analytics
 *   /feature-flags    → Feature Flags
 *   /support          → Suporte
 *   /audit-logs       → Audit Logs
 *   /lgpd             → LGPD
 *   /health           → Health Check
 *   /cron-jobs        → Cron Jobs
 *   /storage          → Storage
 *   /push             → Push Notifications
 *   /email-queue      → Fila de Emails
 *   /invites          → Convites
 */
export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('username, role')
    .eq('id', user.id)
    .single()

  if (!isAdminRole(profile?.role)) redirect('/login?error=unauthorized')

  const mainNav = [
    { href: '/', label: 'Dashboard' },
    { href: '/users', label: 'Usuários' },
    { href: '/clubs', label: 'Clubes' },
    { href: '/books', label: 'Livros' },
    { href: '/moderation', label: 'Moderação' },
    { href: '/billing', label: 'Financeiro' },
    { href: '/analytics', label: 'Analytics' },
    { href: '/feature-flags', label: 'Feature Flags' },
    { href: '/support', label: 'Suporte' },
  ]

  const opsNav = [
    { href: '/audit-logs', label: 'Audit Logs' },
    { href: '/lgpd', label: 'LGPD' },
    { href: '/health', label: 'Health Check' },
    { href: '/cron-jobs', label: 'Cron Jobs' },
    { href: '/storage', label: 'Storage' },
    { href: '/push', label: 'Push Notifications' },
    { href: '/email-queue', label: 'Fila de Emails' },
    { href: '/invites', label: 'Convites' },
  ]

  return (
    <div className="min-h-screen bg-[#F8F9FA] flex">
      {/* ── Sidebar ─────────────────────────────────────── */}
      <aside className="w-56 border-r border-[#E9ECEF] bg-white flex-shrink-0 hidden md:flex flex-col sticky top-0 h-screen">
        <div className="px-5 h-14 flex items-center border-b border-[#E9ECEF] gap-2">
          <span className="font-[Fraunces] font-bold text-xl text-[#1A1A2E]">lumen</span>
          <span className="font-[IBM_Plex_Mono] text-[10px] bg-[#1A1A2E] text-white px-1.5 py-0.5 rounded uppercase tracking-widest">
            admin
          </span>
        </div>

        <nav className="flex-1 p-3 space-y-0.5 overflow-y-auto">
          {mainNav.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              className="flex items-center px-3 py-2 rounded text-sm text-[#6C757D] hover:bg-[#F1F3F5] hover:text-[#1A1A2E]"
            >
              {label}
            </Link>
          ))}

          <div className="pt-4 pb-1 px-3">
            <p className="text-[10px] font-[IBM_Plex_Mono] text-[#ADB5BD] uppercase tracking-widest">
              Operações
            </p>
          </div>

          {opsNav.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              className="flex items-center px-3 py-2 rounded text-sm text-[#6C757D] hover:bg-[#F1F3F5] hover:text-[#1A1A2E]"
            >
              {label}
            </Link>
          ))}
        </nav>

        <div className="p-4 border-t border-[#E9ECEF]">
          <div className="flex items-center gap-3">
            <div className="w-7 h-7 rounded bg-[#E8F0EE] flex items-center justify-center text-xs font-medium text-[#3D6B5A] flex-shrink-0">
              {profile?.username?.[0]?.toUpperCase() ?? 'A'}
            </div>
            <div className="min-w-0">
              <p className="text-sm text-[#1A1A2E] font-medium truncate">@{profile?.username}</p>
              <p className="text-[10px] font-[IBM_Plex_Mono] text-[#6C757D]">{profile?.role}</p>
            </div>
          </div>
        </div>
      </aside>

      {/* ── Conteúdo ──────────────────────────────────────── */}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="md:hidden border-b border-[#E9ECEF] bg-white px-4 h-14 flex items-center justify-between flex-shrink-0">
          <span className="font-[Fraunces] font-bold text-lg text-[#1A1A2E]">lumen admin</span>
          <span className="w-7 h-7 rounded bg-[#E8F0EE] flex items-center justify-center text-xs font-medium text-[#3D6B5A]">
            {profile?.username?.[0]?.toUpperCase() ?? 'A'}
          </span>
        </header>

        <main className="flex-1 overflow-auto">
          {children}
        </main>
      </div>
    </div>
  )
}
