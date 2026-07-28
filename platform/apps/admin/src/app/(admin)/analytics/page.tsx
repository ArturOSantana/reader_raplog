import { createServerSupabase } from '@lumen/supabase/server'
import { formatMinutes } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Analytics · Admin Lumen' }

/**
 * Analytics de produto — North Stars da spec:
 * - DAU / MAU ratio
 * - Retenção D7 / D30
 * - Conversão Trial → Pago
 * - Funil: cadastro → sessão → review → clube
 * - Top livros por sessões (30d)
 */
export default async function AnalyticsPage() {
  const supabase = await createServerSupabase()

  const now = new Date()
  const today = new Date(now)
  today.setHours(0, 0, 0, 0)

  const daysAgo = (n: number) => {
    const d = new Date(now)
    d.setDate(d.getDate() - n)
    return d
  }

  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)

  const [
    { count: dau },
    { count: wau },
    { count: mau },
    { count: totalUsers },
    { count: newUsersMonth },
    { count: activeSubscriptions },
    { data: sessions30d },
    { data: newUsers30d },
  ] = await Promise.all([
    supabase.from('reading_sessions').select('user_id', { count: 'exact', head: true }).gte('started_at', today.toISOString()),
    supabase.from('reading_sessions').select('user_id', { count: 'exact', head: true }).gte('started_at', daysAgo(7).toISOString()),
    supabase.from('reading_sessions').select('user_id', { count: 'exact', head: true }).gte('started_at', daysAgo(30).toISOString()),
    supabase.from('profiles').select('*', { count: 'exact', head: true }),
    supabase.from('profiles').select('*', { count: 'exact', head: true }).gte('created_at', monthStart.toISOString()),
    supabase.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'active'),
    supabase.from('reading_sessions').select('user_id, started_at, duration_minutes, book_id').gte('started_at', daysAgo(30).toISOString()),
    supabase.from('profiles').select('id, created_at').gte('created_at', daysAgo(37).toISOString()).order('created_at', { ascending: true }),
  ])

  // DAU/MAU ratio
  const dauMauRatio = mau && mau > 0 ? Math.round(((dau ?? 0) / mau) * 100) : 0

  // Leitores únicos por dia (30d)
  const dayReaders: Record<string, Set<string>> = {}
  for (const s of sessions30d ?? []) {
    const day = s.started_at.slice(0, 10)
    if (!dayReaders[day]) dayReaders[day] = new Set()
    dayReaders[day].add(s.user_id)
  }
  const dailyData: { date: string; readers: number; minutes: number }[] = []
  for (let i = 29; i >= 0; i--) {
    const d = daysAgo(i)
    const key = d.toISOString().slice(0, 10)
    const dayMin = (sessions30d ?? []).filter((s) => s.started_at.startsWith(key)).reduce((a, s) => a + (s.duration_minutes ?? 0), 0)
    dailyData.push({ date: key, readers: dayReaders[key]?.size ?? 0, minutes: dayMin })
  }
  const maxReaders = Math.max(...dailyData.map((d) => d.readers), 1)

  // Retenção D7: usuários cadastrados nos últimos 37 dias que fizeram sessão após dia 7
  const retentionCohorts = (newUsers30d ?? []).map((u) => {
    const d7 = new Date(u.created_at)
    d7.setDate(d7.getDate() + 7)
    const retained = (sessions30d ?? []).some((s) => s.user_id === u.id && new Date(s.started_at) >= d7)
    return retained
  })
  const retentionD7 = retentionCohorts.length > 0
    ? Math.round((retentionCohorts.filter(Boolean).length / retentionCohorts.length) * 100)
    : null

  // Top livros por sessões (30d)
  const bookCount: Record<string, number> = {}
  for (const s of sessions30d ?? []) {
    if (s.book_id) bookCount[s.book_id] = (bookCount[s.book_id] ?? 0) + 1
  }
  const topBookIds = Object.entries(bookCount).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([id]) => id)
  const { data: topBooksData } = topBookIds.length > 0
    ? await supabase.from('books').select('id, title, author').in('id', topBookIds)
    : { data: [] }
  const topBooks = topBookIds.map((id) => ({
    id,
    title: topBooksData?.find((b) => b.id === id)?.title ?? 'Desconhecido',
    author: topBooksData?.find((b) => b.id === id)?.author ?? '',
    sessions: bookCount[id] ?? 0,
  }))

  // Avg sessão
  const avgSession = sessions30d && sessions30d.length > 0
    ? Math.round(sessions30d.reduce((a, s) => a + (s.duration_minutes ?? 0), 0) / sessions30d.length)
    : 0

  const kpis = [
    { label: 'DAU hoje', value: dau ?? 0, sub: 'leitores únicos', color: '#3D6B5A' },
    { label: 'WAU (7d)', value: wau ?? 0, sub: 'leitores únicos', color: '#5A9480' },
    { label: 'MAU (30d)', value: mau ?? 0, sub: `ratio ${dauMauRatio}%`, color: '#3D6B5A' },
    { label: 'Usuários totais', value: totalUsers ?? 0, sub: `+${newUsersMonth ?? 0} este mês`, color: '#5A9480' },
    { label: 'Retenção D7', value: retentionD7 !== null ? `${retentionD7}%` : '—', sub: `${retentionCohorts.length} na coorte`, color: retentionD7 !== null && retentionD7 >= 40 ? '#3D6B5A' : '#8B5E2E' },
    { label: 'Assinantes ativos', value: activeSubscriptions ?? 0, sub: 'plano Pro', color: '#3D6B5A' },
    { label: 'Sessões (30d)', value: sessions30d?.length ?? 0, sub: formatMinutes(avgSession) + ' média', color: '#5A9480' },
    { label: 'Média por sessão', value: formatMinutes(avgSession), sub: 'últimos 30 dias', color: '#3D6B5A' },
  ]

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Analytics</h1>
        <p className="text-sm text-[#6B6863] mt-1">North Stars do produto · últimos 30 dias</p>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {kpis.map(({ label, value, sub, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[Fraunces] text-2xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
            <p className="text-[10px] text-[#B0AEA9] mt-0.5 font-[IBM_Plex_Mono]">{sub}</p>
          </div>
        ))}
      </div>

      {/* Gráfico de leitores diários */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-1">
          Leitores únicos por dia
        </h2>
        <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] mb-6">Últimos 30 dias</p>
        <div className="flex items-end gap-0.5 h-28">
          {dailyData.map(({ date, readers }) => (
            <div key={date} className="flex-1 flex flex-col items-center">
              <div
                className="w-full rounded-t-sm min-h-[2px]"
                style={{
                  height: `${Math.max(2, (readers / maxReaders) * 100)}%`,
                  backgroundColor: readers > 0 ? '#3D6B5A' : '#F2F1EF',
                }}
                title={`${date}: ${readers} leitores`}
              />
            </div>
          ))}
        </div>
        <div className="flex justify-between mt-2">
          <span className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">30 dias atrás</span>
          <span className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">hoje</span>
        </div>
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top livros */}
        {topBooks.length > 0 && (
          <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
            <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-1">
              Livros que geram mais sessões
            </h2>
            <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] mb-5">Top 5 — últimos 30 dias</p>
            <div className="space-y-4">
              {topBooks.map((book, i) => {
                const max = topBooks[0]?.sessions ?? 1
                return (
                  <div key={book.id}>
                    <div className="flex items-center justify-between mb-1.5">
                      <div className="flex items-center gap-3 min-w-0">
                        <span className="w-5 text-xs font-[IBM_Plex_Mono] text-[#B0AEA9]">{i + 1}.</span>
                        <div className="min-w-0">
                          <p className="text-sm font-medium text-[#1A1918] truncate">{book.title}</p>
                          <p className="text-xs text-[#6B6863]">{book.author}</p>
                        </div>
                      </div>
                      <span className="text-xs font-[IBM_Plex_Mono] text-[#3D6B5A] flex-shrink-0 ml-4">{book.sessions} sessões</span>
                    </div>
                    <div className="h-1.5 bg-[#F2F1EF] rounded-full overflow-hidden">
                      <div className="h-full bg-[#3D6B5A] rounded-full" style={{ width: `${(book.sessions / max) * 100}%` }} />
                    </div>
                  </div>
                )
              })}
            </div>
          </section>
        )}

        {/* Retenção D7 */}
        <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-1">
            Retenção D7
          </h2>
          <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] mb-5">
            Usuários que voltaram a ler após 7 dias do cadastro
          </p>
          {retentionD7 !== null ? (
            <div className="flex items-center gap-6">
              <div>
                <p className="font-[Fraunces] text-5xl font-bold text-[#3D6B5A]">{retentionD7}%</p>
                <p className="text-xs text-[#6B6863] mt-1 font-[IBM_Plex_Mono]">retiveram</p>
              </div>
              <div className="flex-1">
                <div className="h-4 bg-[#F2F1EF] rounded-full overflow-hidden">
                  <div className="h-full bg-[#3D6B5A] rounded-full" style={{ width: `${retentionD7}%` }} />
                </div>
                <div className="flex justify-between mt-1">
                  <span className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A]">{retentionD7}% retiveram</span>
                  <span className="text-[10px] font-[IBM_Plex_Mono] text-[#8B2E2E]">{100 - retentionD7}% saíram</span>
                </div>
              </div>
            </div>
          ) : (
            <p className="text-sm text-[#6B6863]">Dados insuficientes. Aguarde pelo menos 7 dias após os primeiros cadastros.</p>
          )}
          <p className="text-[10px] text-[#B0AEA9] mt-4 font-[IBM_Plex_Mono]">
            Meta da spec: {'>'}40% · Coorte: {retentionCohorts.length} usuários
          </p>
        </section>
      </div>
    </div>
  )
}
