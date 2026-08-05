import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { isAdminRole } from '@lumen/types'
import {
  CalendarIcon,
  HomeIcon,
  LibraryIcon,
  NotesIcon,
  ProfileIcon,
  SearchIcon,
  SessionIcon,
  SettingsIcon,
} from '@/lib/lumen-icons'
import { LumenWordmark } from '@/lib/lumen-wordmark'
import { MobileNav } from '@/components/mobile-nav'

/**
 * Layout principal do Web Platform (app.lumen.app).
 *
 * Rotas:
 *   /              → Dashboard
 *   /library       → Biblioteca
 *   /library/search → Busca Google Books
 *   /library/import → Importar livros
 *   /sessions      → Sessões de leitura
 *   /clubs         → Clubes
 *   /clubs/create  → Criar clube
 *   /feed          → Feed social
 *   /stats         → Estatísticas
 *   /wrapped       → Wrapped anual
 *   /notes         → Notas
 *   /settings      → Configurações
 *   /settings/devices → Sessões e dispositivos
 *   /settings/mfa  → MFA
 *   /billing       → Assinatura
 */
export default async function WebLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('username, avatar_url, role')
    .eq('id', user.id)
    .single()

  const isAdmin = isAdminRole(profile?.role)

  const nav = [
    { href: '/', label: 'Início', icon: HomeIcon },
    { href: '/library', label: 'Biblioteca', icon: LibraryIcon },
    { href: '/library/search', label: 'Buscar livros', icon: SearchIcon },
    { href: '/sessions', label: 'Sessões', icon: SessionIcon },
    { href: '/clubs', label: 'Clubes', icon: HomeIcon },
    { href: '/feed', label: 'Feed', icon: HomeIcon },
    { href: '/wrapped', label: 'Wrapped', icon: CalendarIcon },
    { href: '/stats', label: 'Estatísticas', icon: CalendarIcon },
    { href: '/notes', label: 'Notas', icon: NotesIcon },
  ]

  const accountNav = [
    { href: '/settings', label: 'Configurações', icon: SettingsIcon },
    { href: '/billing', label: 'Assinatura', icon: CalendarIcon },
    { href: '/settings/devices', label: 'Dispositivos', icon: ProfileIcon },
    { href: '/settings/mfa', label: 'MFA', icon: SettingsIcon },
  ]

  return (
    <div className="min-h-screen bg-[#FAF9F7] flex">
      {/* ── Sidebar ─────────────────────────────────────── */}
      <aside className="w-52 border-r border-[#ECEAE9] bg-[#FAF9F7] flex-shrink-0 hidden md:flex flex-col sticky top-0 h-screen">
        <div className="px-5 h-14 flex items-center border-b border-[#ECEAE9]">
          <a href="https://lumen.app" aria-label="Lumen">
            <LumenWordmark className="h-7 w-auto" />
          </a>
        </div>

        <nav className="flex-1 p-3 space-y-0.5 overflow-y-auto">
          {nav.map(({ href, label, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              className="flex items-center gap-2.5 px-3 py-2 rounded text-sm text-[#6B6863] hover:bg-[#F2F1EF] hover:text-[#1A1918]"
            >
              <Icon className="h-4 w-4 flex-shrink-0" />
              <span>{label}</span>
            </Link>
          ))}

          <div className="pt-4 pb-1 px-3">
            <p className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] uppercase tracking-widest">
              Conta
            </p>
          </div>
          {accountNav.map(({ href, label, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              className="flex items-center gap-2.5 px-3 py-2 rounded text-sm text-[#6B6863] hover:bg-[#F2F1EF] hover:text-[#1A1918]"
            >
              <Icon className="h-4 w-4 flex-shrink-0" />
              <span>{label}</span>
            </Link>
          ))}

          {/* Link para o Admin Console — só aparece para quem tem role admin */}
          {isAdmin && (
            <>
              <div className="pt-4 pb-1 px-3">
                <p className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] uppercase tracking-widest">
                  Operações
                </p>
              </div>
              <a
                href="https://admin.lumen.app"
                className="flex items-center gap-2 px-3 py-2 rounded text-sm text-[#6B6863] hover:bg-[#F2F1EF] hover:text-[#1A1918]"
              >
                Admin Console
                <span className="text-[10px] font-[IBM_Plex_Mono] bg-[#1A1918] text-white px-1.5 py-0.5 rounded ml-auto">
                  {profile?.role}
                </span>
              </a>
            </>
          )}
        </nav>

        <div className="p-4 border-t border-[#ECEAE9]">
          <Link href="/settings" className="flex items-center gap-3">
            <div className="w-7 h-7 rounded-full bg-[#E8F0EE] flex items-center justify-center text-[#3D6B5A] flex-shrink-0 overflow-hidden">
              {profile?.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={profile.avatar_url} alt="" className="h-full w-full object-cover" />
              ) : profile?.username ? (
                <span className="text-xs font-medium">{profile.username[0]?.toUpperCase() ?? 'U'}</span>
              ) : (
                <ProfileIcon className="h-4 w-4" />
              )}
            </div>
            <div className="min-w-0">
              <p className="text-sm text-[#1A1918] font-medium truncate">
                @{profile?.username}
              </p>
              {isAdmin && (
                <p className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">{profile?.role}</p>
              )}
            </div>
          </Link>
        </div>
      </aside>

      {/* ── Conteúdo ──────────────────────────────────────── */}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="md:hidden border-b border-[#ECEAE9] bg-[#FAF9F7] px-4 flex items-center justify-between flex-shrink-0" style={{ paddingTop: 'env(safe-area-inset-top)', minHeight: 'calc(3.5rem + env(safe-area-inset-top))' }}>
          <a href="https://lumen.app" aria-label="Lumen">
            <LumenWordmark className="h-6 w-auto" />
          </a>
          <Link
            href="/settings"
            className="w-7 h-7 rounded-full bg-[#E8F0EE] flex items-center justify-center text-[#3D6B5A] overflow-hidden"
          >
            {profile?.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={profile.avatar_url} alt="" className="h-full w-full object-cover" />
            ) : profile?.username ? (
              <span className="text-xs font-medium">{profile.username[0]?.toUpperCase() ?? 'U'}</span>
            ) : (
              <SettingsIcon className="h-4 w-4" />
            )}
          </Link>
        </header>

        <main className="flex-1 overflow-auto md:pb-0 pb-16">
          {/* page-enter: fade + micro-slide ao navegar — casado com o grain */}
          <div className="page-enter">
            {children}
          </div>
        </main>

        {/* ── Bottom nav (mobile only) ─────────────────────── */}
        <MobileNav />
      </div>
    </div>
  )
}
