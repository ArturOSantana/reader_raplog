import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'
import { formatMinutes } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Wrapped · Lumen' }

interface PageProps {
  searchParams: Promise<{ year?: string }>
}

export default async function WrappedPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { year: yearParam } = await searchParams
  const year = parseInt(yearParam ?? '') || new Date().getFullYear()
  const yearStart = `${year}-01-01T00:00:00.000Z`
  const yearEnd   = `${year}-12-31T23:59:59.999Z`

  // ── Sessões do ano ────────────────────────────────────────────────────────
  const { data: sessions } = await supabase
    .from('reading_sessions')
    .select('duration_minutes, pages_read, started_at, book_id')
    .eq('user_id', user.id)
    .gte('started_at', yearStart)
    .lte('started_at', yearEnd)

  const totalMinutes = sessions?.reduce((s, r) => s + (r.duration_minutes ?? 0), 0) ?? 0
  const totalPages   = sessions?.reduce((s, r) => s + (r.pages_read ?? 0), 0) ?? 0
  const totalSessions = sessions?.length ?? 0

  // ── Livros concluídos no ano ──────────────────────────────────────────────
  const { data: finishedBooks } = await supabase
    .from('books')
    .select('id, title, author, cover_url, rating, page_count, finished_at')
    .eq('user_id', user.id)
    .eq('status', 'finished')
    .gte('finished_at', yearStart)
    .lte('finished_at', yearEnd)
    .order('finished_at', { ascending: true })

  const totalBooks = finishedBooks?.length ?? 0

  // ── Livro mais lido (mais sessões) ────────────────────────────────────────
  const bookSessionCount: Record<string, number> = {}
  for (const s of sessions ?? []) {
    if (s.book_id) bookSessionCount[s.book_id] = (bookSessionCount[s.book_id] ?? 0) + 1
  }
  const topBookId = Object.entries(bookSessionCount).sort((a, b) => b[1] - a[1])[0]?.[0]
  const topBook = topBookId
    ? finishedBooks?.find((b) => b.id === topBookId) ?? null
    : null

  // ── Sessões por mês (para gráfico) ───────────────────────────────────────
  const monthlyMinutes: number[] = Array(12).fill(0)
  for (const s of sessions ?? []) {
    const m = new Date(s.started_at).getMonth()
    monthlyMinutes[m] += s.duration_minutes ?? 0
  }
  const maxMonthly = Math.max(...monthlyMinutes, 1)

  // ── Dia mais ativo ────────────────────────────────────────────────────────
  const dayCount: Record<string, number> = {}
  for (const s of sessions ?? []) {
    const d = s.started_at.slice(0, 10)
    dayCount[d] = (dayCount[d] ?? 0) + (s.duration_minutes ?? 0)
  }
  const bestDay = Object.entries(dayCount).sort((a, b) => b[1] - a[1])[0]

  // ── Nota média dos livros lidos ───────────────────────────────────────────
  const ratedBooks = finishedBooks?.filter((b) => b.rating) ?? []
  const avgRating = ratedBooks.length
    ? (ratedBooks.reduce((s, b) => s + (b.rating ?? 0), 0) / ratedBooks.length).toFixed(1)
    : null

  // ── Conquistas desbloqueadas no ano ───────────────────────────────────────
  const { data: achievements } = await supabase
    .from('user_achievements')
    .select('unlocked_at, achievement:achievements(key, name, icon)')
    .eq('user_id', user.id)
    .gte('unlocked_at', yearStart)
    .lte('unlocked_at', yearEnd)
    .order('unlocked_at', { ascending: false })

  const months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez']
  const hours = Math.floor(totalMinutes / 60)
  const mins  = totalMinutes % 60

  // Anos disponíveis (a partir de quando o usuário se registrou)
  const { data: profile } = await supabase
    .from('profiles')
    .select('created_at')
    .eq('id', user.id)
    .single()

  const firstYear = profile?.created_at ? new Date(profile.created_at).getFullYear() : year
  const availableYears = Array.from(
    { length: new Date().getFullYear() - firstYear + 1 },
    (_, i) => new Date().getFullYear() - i,
  )

  return (
    <div className="p-6 max-w-4xl mx-auto">
      {/* Cabeçalho */}
      <div className="mb-8 flex items-start justify-between">
        <div>
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">
            Lumen Wrapped
          </p>
          <h1 className="font-[Fraunces] text-4xl font-bold text-[#1A1918]">
            Seu {year} em livros
          </h1>
        </div>
        {availableYears.length > 1 && (
          <div className="flex gap-1.5 flex-wrap justify-end">
            {availableYears.map((y) => (
              <a
                key={y}
                href={`/wrapped?year=${y}`}
                className={`text-xs font-[IBM_Plex_Mono] px-3 py-1.5 rounded-lg transition-colors ${
                  y === year ? 'bg-[#1A1918] text-white' : 'bg-[#F2F1EF] text-[#6B6863] hover:bg-[#ECEAE9]'
                }`}
              >
                {y}
              </a>
            ))}
          </div>
        )}
      </div>

      {totalBooks === 0 && totalSessions === 0 ? (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-16 text-center">
          <p className="text-4xl mb-4">📖</p>
          <p className="font-[Fraunces] text-xl text-[#1A1918] mb-2">Nenhuma leitura em {year}</p>
          <p className="text-sm text-[#6B6863]">
            {year < new Date().getFullYear() ? 'Não há dados de leitura para este ano.' : 'Complete sua primeira sessão de leitura!'}
          </p>
        </div>
      ) : (
        <>
          {/* KPIs hero */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            {[
              { label: 'livros lidos', value: String(totalBooks), accent: true },
              { label: 'horas lidas', value: `${hours}h${mins > 0 ? ` ${mins}min` : ''}`, accent: false },
              { label: 'páginas lidas', value: totalPages.toLocaleString('pt-BR'), accent: false },
              { label: 'sessões', value: String(totalSessions), accent: false },
            ].map(({ label, value, accent }) => (
              <div key={label} className={`rounded-2xl p-5 border ${accent ? 'bg-[#1A1918] border-[#1A1918]' : 'bg-white border-[#ECEAE9]'}`}>
                <p className={`font-[Fraunces] text-4xl font-bold ${accent ? 'text-white' : 'text-[#3D6B5A]'}`}>
                  {value}
                </p>
                <p className={`text-xs font-[IBM_Plex_Mono] mt-1 ${accent ? 'text-white/70' : 'text-[#6B6863]'}`}>
                  {label}
                </p>
              </div>
            ))}
          </div>

          {/* Gráfico mensal */}
          <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
            <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-5">
              Minutos por mês
            </p>
            <div className="flex items-end gap-2 h-24">
              {monthlyMinutes.map((m, i) => (
                <div key={i} className="flex-1 flex flex-col items-center gap-1">
                  <div
                    className="w-full rounded-t bg-[#3D6B5A] transition-all"
                    style={{ height: `${Math.round((m / maxMonthly) * 80)}px`, minHeight: m > 0 ? '4px' : '0' }}
                  />
                  <span className="text-[8px] font-[IBM_Plex_Mono] text-[#B0AEA9]">
                    {months[i]}
                  </span>
                </div>
              ))}
            </div>
            {bestDay && (
              <p className="text-xs text-[#6B6863] mt-4 font-[IBM_Plex_Mono]">
                🔥 Melhor dia:{' '}
                <strong className="text-[#1A1918]">
                  {new Date(bestDay[0]).toLocaleDateString('pt-BR', { day: 'numeric', month: 'long' })}
                </strong>
                {' '}— {formatMinutes(bestDay[1])}
              </p>
            )}
          </div>

          {/* Livros lidos + destaque */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
            {/* Livro do ano */}
            {topBook && (
              <div className="bg-[#1A1918] rounded-2xl p-6 text-white">
                <p className="text-xs font-[IBM_Plex_Mono] text-white/60 uppercase tracking-widest mb-3">
                  Livro do ano
                </p>
                {topBook.cover_url && (
                  <img
                    src={topBook.cover_url}
                    alt={topBook.title}
                    className="w-16 h-22 object-cover rounded-lg mb-3 shadow-lg"
                  />
                )}
                <p className="font-[Fraunces] text-xl font-bold leading-tight mb-1">
                  {topBook.title}
                </p>
                <p className="text-sm text-white/60">{topBook.author}</p>
                {topBook.rating && (
                  <p className="text-[#F5A623] mt-2">{'★'.repeat(topBook.rating)}</p>
                )}
              </div>
            )}

            {/* Grade de capas dos livros lidos */}
            <div className={topBook ? 'lg:col-span-2' : 'lg:col-span-3'}>
              <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-3">
                {totalBooks} livro{totalBooks !== 1 ? 's' : ''} concluído{totalBooks !== 1 ? 's' : ''}
                {avgRating && <span className="ml-2 text-[#F5A623]">· média {avgRating}★</span>}
              </p>
              {finishedBooks && finishedBooks.length > 0 ? (
                <div className="grid grid-cols-4 sm:grid-cols-6 gap-2">
                  {finishedBooks.slice(0, 24).map((book) => (
                    <div key={book.id} title={book.title}>
                      {book.cover_url ? (
                        <img
                          src={book.cover_url}
                          alt={book.title}
                          className="w-full aspect-[2/3] object-cover rounded-lg"
                        />
                      ) : (
                        <div className="w-full aspect-[2/3] bg-[#E8F0EE] rounded-lg flex items-center justify-center">
                          <span className="text-[#3D6B5A] font-[Fraunces] font-bold text-sm">
                            {book.title[0]}
                          </span>
                        </div>
                      )}
                    </div>
                  ))}
                  {(finishedBooks?.length ?? 0) > 24 && (
                    <div className="w-full aspect-[2/3] bg-[#F2F1EF] rounded-lg flex items-center justify-center">
                      <span className="text-xs font-[IBM_Plex_Mono] text-[#6B6863]">
                        +{(finishedBooks?.length ?? 0) - 24}
                      </span>
                    </div>
                  )}
                </div>
              ) : (
                <p className="text-sm text-[#6B6863]">Nenhum livro concluído em {year}.</p>
              )}
            </div>
          </div>

          {/* Conquistas do ano */}
          {achievements && achievements.length > 0 && (
            <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
              <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-4">
                {achievements.length} conquista{achievements.length !== 1 ? 's' : ''} desbloqueada{achievements.length !== 1 ? 's' : ''}
              </p>
              <div className="flex flex-wrap gap-2">
                {achievements.map((ua) => {
                  const a = Array.isArray(ua.achievement) ? ua.achievement[0] : ua.achievement
                  return (
                    <div
                      key={ua.unlocked_at}
                      title={a?.name ?? ''}
                      className="flex items-center gap-2 bg-[#F2F1EF] rounded-xl px-3 py-2 text-sm"
                    >
                      <span>{a?.icon ?? '🏆'}</span>
                      <span className="font-medium text-[#1A1918] text-xs">{a?.name ?? '—'}</span>
                    </div>
                  )
                })}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  )
}
