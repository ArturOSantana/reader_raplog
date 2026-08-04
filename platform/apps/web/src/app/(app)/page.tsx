import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { formatMinutes } from '@lumen/ui'
import type { Metadata } from 'next'
import { CalendarIcon, ChevronRightIcon, HomeIcon, LibraryIcon, NotesIcon, SessionIcon } from '@/lib/lumen-icons'

export const metadata: Metadata = {
  title: 'Início · Lumen',
}

export default async function WebDashboardPage() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('username, full_name')
    .eq('id', user.id)
    .single()

  const [
    { count: booksRead },
    { count: totalSessions },
    { data: streak },
    { data: reading },
    { data: recentSessions },
    { data: activeSession },
  ] = await Promise.all([
    supabase.from('books').select('*', { count: 'exact', head: true }).eq('user_id', user.id).eq('status', 'read'),
    supabase.from('reading_sessions').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
    supabase.rpc('calculate_streak', { p_user_id: user.id }),
    supabase.from('books').select('title, author, cover_url, current_page, total_pages').eq('user_id', user.id).eq('status', 'reading').limit(3),
    supabase.from('reading_sessions').select('duration_minutes, pages_read, started_at').eq('user_id', user.id).order('started_at', { ascending: false }).limit(5),
    supabase.from('reading_sessions')
      .select('id, started_at, books(title)')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .order('started_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
  ])

  const name = profile?.full_name ?? profile?.username ?? 'Leitor'
  const hour = new Date().getHours()
  const greeting = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite'

  // Calcula tempo decorrido da sessão ativa (server-side, sem timer)
  const activeSessionElapsed = activeSession
    ? Math.max(0, Math.floor((Date.now() - new Date(activeSession.started_at).getTime()) / 1000))
    : null
  const activeBookTitle = activeSession
    ? (Array.isArray(activeSession.books)
        ? ((activeSession.books as { title: string }[])[0]?.title ?? 'Leitura')
        : ((activeSession.books as unknown as { title: string } | null)?.title ?? 'Leitura'))
    : null

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Banner de sessão ativa */}
      {activeSession && (
        <div className="mb-6 flex items-center gap-3 px-4 py-3 rounded-lg border border-[#3D6B5A]/20 bg-[#F2F1EF]">
          {/* Dot de presença */}
          <span
            className="inline-block w-2 h-2 rounded-full flex-shrink-0"
            style={{ backgroundColor: '#3D6B5A' }}
            aria-hidden
          />
          {/* Info */}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-[#1A1918] truncate">
              {activeBookTitle}
            </p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#3D6B5A]">em leitura</p>
          </div>
          {/* Tempo decorrido (snapshot no momento do render) */}
          {activeSessionElapsed !== null && (
            <span className="text-sm font-[IBM_Plex_Mono] text-[#3D6B5A] flex-shrink-0">
              {activeSessionElapsed >= 3600
                ? `${String(Math.floor(activeSessionElapsed / 3600)).padStart(2, '0')}:${String(Math.floor((activeSessionElapsed % 3600) / 60)).padStart(2, '0')}:${String(activeSessionElapsed % 60).padStart(2, '0')}`
                : `${String(Math.floor(activeSessionElapsed / 60)).padStart(2, '0')}:${String(activeSessionElapsed % 60).padStart(2, '0')}`}
            </span>
          )}
        </div>
      )}

      {/* Saudação */}
      <div className="mb-8">
        <div className="flex items-center gap-2 text-[#6B6863] mb-2">
          <HomeIcon className="h-4 w-4" />
          <p className="font-[IBM_Plex_Mono] text-sm">{greeting},</p>
        </div>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">{name}</h1>
      </div>

      {/* Métricas rápidas */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        {[
          { value: streak ?? 0, label: 'dias seguidos' },
          { value: booksRead ?? 0, label: 'livros lidos' },
          { value: totalSessions ?? 0, label: 'sessões totais' },
        ].map(({ value, label }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-lg p-5">
            <p className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Lendo agora */}
        <section>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <LibraryIcon className="h-4 w-4 text-[#6B6863]" />
              <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Lendo agora</h2>
            </div>
            <Link href="/library" className="text-xs text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono] inline-flex items-center gap-1">
              Ver biblioteca <ChevronRightIcon className="h-3.5 w-3.5" />
            </Link>
          </div>
          {reading && reading.length > 0 ? (
            <div className="space-y-3">
              {reading.map((b) => (
                <div key={b.title} className="bg-white border border-[#ECEAE9] rounded-lg p-4">
                  <p className="font-medium text-[#1A1918] text-sm">{b.title}</p>
                  <p className="text-xs text-[#6B6863] mb-2">{b.author}</p>
                  {b.current_page && b.total_pages && (
                    <>
                      <div className="h-1.5 bg-[#F2F1EF] rounded-full overflow-hidden">
                        <div
                          className="h-full bg-[#3D6B5A] rounded-full transition-all"
                          style={{ width: `${Math.min(100, (b.current_page / b.total_pages) * 100)}%` }}
                        />
                      </div>
                      <p className="text-[10px] text-[#6B6863] mt-1 font-[IBM_Plex_Mono]">
                        {b.current_page} / {b.total_pages} páginas
                      </p>
                    </>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="bg-[#F2F1EF] rounded-lg p-6 text-center text-[#6B6863] text-sm">
              Nenhum livro em leitura.{' '}
              <Link href="/library" className="text-[#3D6B5A] hover:underline">
                Ver biblioteca →
              </Link>
            </div>
          )}
        </section>

        {/* Sessões recentes */}
        <section>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <SessionIcon className="h-4 w-4 text-[#6B6863]" />
              <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Sessões recentes</h2>
            </div>
            <Link href="/stats" className="text-xs text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono] inline-flex items-center gap-1">
              Ver estatísticas <ChevronRightIcon className="h-3.5 w-3.5" />
            </Link>
          </div>
          {recentSessions && recentSessions.length > 0 ? (
            <div className="space-y-2">
              {recentSessions.map((s, i) => (
                <div key={i} className="bg-white border border-[#ECEAE9] rounded-lg px-4 py-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm text-[#1A1918] font-medium">
                      {formatMinutes(s.duration_minutes ?? 0)}
                    </p>
                    <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono]">
                      {new Date(s.started_at).toLocaleDateString('pt-BR')}
                    </p>
                  </div>
                  {s.pages_read != null && (
                    <span className="text-xs font-[IBM_Plex_Mono] text-[#3D6B5A]">
                      +{s.pages_read} pág.
                    </span>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="bg-[#F2F1EF] rounded-lg p-6 text-center text-[#6B6863] text-sm">
              Nenhuma sessão registrada ainda.
            </div>
          )}
        </section>
      </div>

      {/* Atalhos */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-8">
        {[
          { href: '/library', label: 'Biblioteca', icon: LibraryIcon },
          { href: '/clubs', label: 'Clubes', icon: HomeIcon },
          { href: '/notes', label: 'Notas', icon: NotesIcon },
          { href: '/stats', label: 'Estatísticas', icon: CalendarIcon },
        ].map(({ href, label, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            className="bg-white border border-[#ECEAE9] rounded-lg p-4 hover:border-[#B0AEA9] text-sm font-medium text-[#1A1918] flex flex-col items-center gap-2"
          >
            <Icon className="h-5 w-5 text-[#6B6863]" />
            <span>{label}</span>
          </Link>
        ))}
      </div>
    </div>
  )
}
