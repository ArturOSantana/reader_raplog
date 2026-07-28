import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'
import { formatMinutes, formatDate } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Estatísticas · Lumen Web' }

export default async function StatsPage() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const now = new Date()
  const currentYear = now.getFullYear()
  const yearStart = new Date(currentYear, 0, 1)
  const thirtyDaysAgo = new Date(now)
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  const [
    { data: sessions30d },
    { data: sessionsYear },
    { data: streak },
    { count: booksRead },
    { count: booksReadYear },
    { data: topBooks },
    { data: achievements },
    { data: goals },
  ] = await Promise.all([
    // Sessões últimos 30 dias
    supabase
      .from('reading_sessions')
      .select('duration_minutes, pages_read, started_at')
      .eq('user_id', user.id)
      .gte('started_at', thirtyDaysAgo.toISOString())
      .order('started_at', { ascending: true }),
    // Sessões do ano atual
    supabase
      .from('reading_sessions')
      .select('duration_minutes, pages_read, started_at')
      .eq('user_id', user.id)
      .gte('started_at', yearStart.toISOString()),
    supabase.rpc('calculate_streak', { p_user_id: user.id }),
    // Total de lidos
    supabase
      .from('books')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('status', 'read'),
    // Lidos este ano
    supabase
      .from('books')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('status', 'read')
      .gte('end_date', yearStart.toISOString()),
    // Maiores livros
    supabase
      .from('books')
      .select('title, author, total_pages, end_date, rating')
      .eq('user_id', user.id)
      .eq('status', 'read')
      .not('total_pages', 'is', null)
      .order('total_pages', { ascending: false })
      .limit(5),
    // Conquistas
    supabase
      .from('user_achievements')
      .select('unlocked_at, achievement:achievements(key, name, icon, description)')
      .eq('user_id', user.id)
      .order('unlocked_at', { ascending: false })
      .limit(6),
    // Metas ativas
    supabase
      .from('goals')
      .select('type, target_value, period')
      .eq('user_id', user.id)
      .limit(4),
  ])

  // ─── Métricas 30d ────────────────────────────────────────────
  const totalMinutes30d = sessions30d?.reduce((s, r) => s + (r.duration_minutes ?? 0), 0) ?? 0
  const totalPages30d = sessions30d?.reduce((s, r) => s + (r.pages_read ?? 0), 0) ?? 0
  const avgMin = sessions30d && sessions30d.length > 0
    ? Math.round(totalMinutes30d / sessions30d.length)
    : 0

  // ─── Métricas do ano ────────────────────────────────────────
  const totalMinutesYear = sessionsYear?.reduce((s, r) => s + (r.duration_minutes ?? 0), 0) ?? 0
  const totalPagesYear = sessionsYear?.reduce((s, r) => s + (r.pages_read ?? 0), 0) ?? 0
  const sessionCountYear = sessionsYear?.length ?? 0

  // ─── Heatmap 30d ─────────────────────────────────────────────
  const dayMap: Record<string, number> = {}
  for (const s of sessions30d ?? []) {
    const day = s.started_at.slice(0, 10)
    dayMap[day] = (dayMap[day] ?? 0) + (s.duration_minutes ?? 0)
  }
  const days: { date: string; minutes: number }[] = []
  for (let i = 29; i >= 0; i--) {
    const d = new Date(now)
    d.setDate(d.getDate() - i)
    const key = d.toISOString().slice(0, 10)
    days.push({ date: key, minutes: dayMap[key] ?? 0 })
  }
  const maxMinutes = Math.max(...days.map((d) => d.minutes), 1)

  // ─── Heatmap do ano (mensal) ─────────────────────────────────
  const monthMap: Record<string, number> = {}
  for (const s of sessionsYear ?? []) {
    const month = s.started_at.slice(0, 7)
    monthMap[month] = (monthMap[month] ?? 0) + (s.duration_minutes ?? 0)
  }
  const months: { label: string; key: string; minutes: number }[] = []
  const monthNames = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez']
  for (let m = 0; m < 12; m++) {
    const key = `${currentYear}-${String(m + 1).padStart(2, '0')}`
    months.push({ key, label: monthNames[m], minutes: monthMap[key] ?? 0 })
  }
  const maxMonthMin = Math.max(...months.map((m) => m.minutes), 1)

  const goalTypeLabel: Record<string, string> = {
    daily_pages: 'páginas/dia',
    daily_minutes: 'min/dia',
    yearly_books: 'livros/ano',
    monthly_pages: 'páginas/mês',
  }

  type Achievement = {
    unlocked_at: string
    achievement: { key: string; name: string; icon: string | null; description: string } | null
  }
  const typedAchievements = (achievements ?? []) as unknown as Achievement[]

  type Goal = { type: string; target_value: number; period: string }
  const typedGoals = (goals ?? []) as unknown as Goal[]

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Estatísticas</h1>
        <p className="text-sm text-[#6B6863] mt-1">{currentYear} · histórico pessoal de leitura</p>
      </div>

      {/* ─── KPIs ano ─────────────────────────────── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { value: streak ?? 0, label: 'streak atual', sub: 'dias seguidos' },
          { value: booksReadYear ?? 0, label: `livros em ${currentYear}`, sub: `${booksRead ?? 0} no total` },
          { value: formatMinutes(totalMinutesYear), label: `lidos em ${currentYear}`, sub: `${sessionCountYear} sessões` },
          { value: totalPagesYear.toLocaleString('pt-BR'), label: `páginas em ${currentYear}`, sub: avgMin ? formatMinutes(avgMin) + ' média/sessão' : '' },
        ].map(({ value, label, sub }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[Fraunces] text-2xl font-bold text-[#3D6B5A]">{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
            {sub && <p className="text-[10px] text-[#B0AEA9] mt-0.5 font-[IBM_Plex_Mono]">{sub}</p>}
          </div>
        ))}
      </div>

      {/* ─── Atividade mensal do ano ──────────────── */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-1">
          Atividade em {currentYear}
        </h2>
        <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] mb-5">Minutos lidos por mês</p>
        <div className="flex items-end gap-2 h-24">
          {months.map(({ key, label, minutes }) => (
            <div key={key} className="flex-1 flex flex-col items-center gap-1.5">
              <div
                className="w-full rounded-t-sm min-h-[3px]"
                style={{
                  height: `${Math.max(3, (minutes / maxMonthMin) * 100)}%`,
                  backgroundColor: minutes > 0 ? '#3D6B5A' : '#F2F1EF',
                }}
                title={`${label}: ${formatMinutes(minutes)}`}
              />
              <span className="text-[9px] font-[IBM_Plex_Mono] text-[#B0AEA9]">{label}</span>
            </div>
          ))}
        </div>
      </section>

      {/* ─── Heatmap 30 dias ─────────────────────── */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-1">
          Atividade — últimos 30 dias
        </h2>
        <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] mb-5">
          {formatMinutes(totalMinutes30d)} · {totalPages30d} páginas · {sessions30d?.length ?? 0} sessões
        </p>
        <div className="flex gap-1.5 flex-wrap">
          {days.map(({ date, minutes }) => {
            const intensity = minutes === 0 ? 0 : Math.max(0.15, minutes / maxMinutes)
            return (
              <div
                key={date}
                title={`${date}: ${minutes > 0 ? formatMinutes(minutes) : 'sem leitura'}`}
                className="w-7 h-7 rounded-md"
                style={{
                  backgroundColor: minutes === 0
                    ? '#F2F1EF'
                    : `rgba(61,107,90,${0.2 + intensity * 0.8})`,
                }}
              />
            )
          })}
        </div>
        <p className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] mt-3">
          Cada quadrado = 1 dia · cor mais intensa = mais tempo lido
        </p>
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* ─── Maiores livros ──────────────────────── */}
        {topBooks && topBooks.length > 0 && (
          <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
            <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-1">
              Maiores livros lidos
            </h2>
            <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] mb-5">Por número de páginas</p>
            <div className="space-y-4">
              {topBooks.map((book, i) => {
                const max = topBooks[0]?.total_pages ?? 1
                return (
                  <div key={book.title}>
                    <div className="flex items-center justify-between mb-1.5">
                      <div className="flex items-center gap-3 min-w-0">
                        <span className="w-5 text-xs font-[IBM_Plex_Mono] text-[#B0AEA9]">{i + 1}.</span>
                        <div className="min-w-0">
                          <p className="text-sm font-medium text-[#1A1918] truncate">{book.title}</p>
                          <p className="text-xs text-[#6B6863]">{book.author}</p>
                        </div>
                      </div>
                      <div className="flex-shrink-0 ml-4 text-right">
                        <span className="text-xs font-[IBM_Plex_Mono] text-[#3D6B5A]">{book.total_pages} pág.</span>
                        {book.rating && (
                          <p className="text-[10px] text-[#3D6B5A]">{'★'.repeat(book.rating)}</p>
                        )}
                      </div>
                    </div>
                    <div className="h-1.5 bg-[#F2F1EF] rounded-full overflow-hidden">
                      <div
                        className="h-full bg-[#3D6B5A] rounded-full"
                        style={{ width: `${((book.total_pages ?? 0) / max) * 100}%` }}
                      />
                    </div>
                  </div>
                )
              })}
            </div>
          </section>
        )}

        {/* ─── Conquistas recentes ─────────────────── */}
        {typedAchievements.length > 0 && (
          <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
            <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-1">
              Conquistas recentes
            </h2>
            <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] mb-5">
              {typedAchievements.length} desbloqueadas
            </p>
            <div className="space-y-3">
              {typedAchievements.map((ua) => (
                <div key={ua.unlocked_at + (ua.achievement?.key ?? '')} className="flex items-center gap-3">
                  <div className="w-9 h-9 bg-[#F2F1EF] rounded-xl flex items-center justify-center text-lg flex-shrink-0">
                    {ua.achievement?.icon ?? '🏆'}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium text-[#1A1918]">{ua.achievement?.name ?? '—'}</p>
                    <p className="text-xs text-[#6B6863]">{ua.achievement?.description ?? ''}</p>
                  </div>
                  <p className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] flex-shrink-0">
                    {formatDate(ua.unlocked_at)}
                  </p>
                </div>
              ))}
            </div>
          </section>
        )}
      </div>

      {/* ─── Metas ativas ───────────────────────────── */}
      {typedGoals.length > 0 && (
        <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mt-6">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">Metas ativas</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {typedGoals.map((goal) => (
              <div key={goal.type} className="bg-[#F2F1EF] rounded-xl p-4">
                <p className="font-[Fraunces] text-2xl font-bold text-[#3D6B5A]">{goal.target_value}</p>
                <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">
                  {goalTypeLabel[goal.type] ?? goal.type}
                </p>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
