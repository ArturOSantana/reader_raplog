import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { formatMinutes } from '@lumen/ui'
import { isAdminRole } from '@lumen/types'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Dashboard · Admin Lumen' }

export default async function AdminDashboardPage() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  if (!isAdminRole(profile?.role)) redirect('/login?error=unauthorized')

  const now = new Date()
  const today = new Date(now)
  today.setHours(0, 0, 0, 0)
  const weekAgo = new Date(now)
  weekAgo.setDate(weekAgo.getDate() - 7)
  const monthAgo = new Date(now)
  monthAgo.setDate(monthAgo.getDate() - 30)
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)

  const [
    { count: totalUsers },
    { count: newUsersMonth },
    { count: activeUsers7d },
    { count: activeUsers30d },
    { count: totalClubs },
    { count: newClubsMonth },
    { count: checkinsToday },
    { count: sessionsToday },
    { count: openReports },
    { count: activeSubscriptions },
    { data: todaySessions },
  ] = await Promise.all([
    supabase.from('profiles').select('*', { count: 'exact', head: true }),
    supabase.from('profiles').select('*', { count: 'exact', head: true }).gte('created_at', monthStart.toISOString()),
    supabase.from('reading_sessions').select('user_id', { count: 'exact', head: true }).gte('started_at', weekAgo.toISOString()),
    supabase.from('reading_sessions').select('user_id', { count: 'exact', head: true }).gte('started_at', monthAgo.toISOString()),
    supabase.from('book_clubs').select('*', { count: 'exact', head: true }),
    supabase.from('book_clubs').select('*', { count: 'exact', head: true }).gte('created_at', monthStart.toISOString()),
    supabase.from('book_club_checkins').select('*', { count: 'exact', head: true }).gte('created_at', today.toISOString()),
    supabase.from('reading_sessions').select('*', { count: 'exact', head: true }).gte('started_at', today.toISOString()),
    supabase.from('reports').select('*', { count: 'exact', head: true }).eq('status', 'open'),
    supabase.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'active'),
    supabase.from('reading_sessions').select('duration_minutes').gte('started_at', today.toISOString()),
  ])

  const minutesToday = todaySessions?.reduce((s, r) => s + (r.duration_minutes ?? 0), 0) ?? 0

  const metrics = [
    { label: 'Usuários totais', value: totalUsers ?? 0, sub: `+${newUsersMonth ?? 0} este mês`, color: '#3D6B5A' },
    { label: 'Ativos (7 dias)', value: activeUsers7d ?? 0, sub: `${activeUsers30d ?? 0} em 30 dias`, color: '#5A9480' },
    { label: 'Assinantes ativos', value: activeSubscriptions ?? 0, sub: 'plano Pro', color: '#3D6B5A' },
    { label: 'Sessões hoje', value: sessionsToday ?? 0, sub: formatMinutes(minutesToday) + ' lidos', color: '#5A9480' },
    { label: 'Check-ins hoje', value: checkinsToday ?? 0, sub: 'em clubes', color: '#3D6B5A' },
    { label: 'Clubes totais', value: totalClubs ?? 0, sub: `+${newClubsMonth ?? 0} este mês`, color: '#5A9480' },
  ]

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="flex items-start justify-between mb-8">
        <div>
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">
            Admin
          </p>
          <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">
            Dashboard
          </h1>
          <p className="text-sm text-[#6B6863] mt-1">
            {now.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}
          </p>
        </div>
        {(openReports ?? 0) > 0 && (
          <Link
            href="/moderation"
            className="flex items-center gap-2 bg-[#8B2E2E]/10 border border-[#8B2E2E]/30 text-[#8B2E2E] px-4 py-2 rounded-xl text-sm font-[IBM_Plex_Mono] hover:bg-[#8B2E2E]/20 transition-colors"
          >
            🚩 {openReports} denúncia{openReports !== 1 ? 's' : ''} aberta{openReports !== 1 ? 's' : ''}
          </Link>
        )}
      </div>

      {/* Métricas */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-10">
        {metrics.map(({ label, value, sub, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[Fraunces] text-3xl font-bold" style={{ color }}>
              {value}
            </p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
            <p className="text-xs text-[#B0AEA9] mt-0.5 font-[IBM_Plex_Mono]">{sub}</p>
          </div>
        ))}
      </div>

      {/* Módulos */}
      <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">Módulos</h2>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        {modules.map(({ href, label, icon, desc }) => (
          <Link
            key={href}
            href={href}
            className="group bg-white border border-[#ECEAE9] rounded-2xl p-5 hover:border-[#B0AEA9] hover:shadow-sm transition-all"
          >
            <span className="text-2xl block mb-3">{icon}</span>
            <p className="font-[Fraunces] font-semibold text-[#1A1918] group-hover:text-[#3D6B5A] transition-colors">
              {label}
            </p>
            <p className="text-xs text-[#6B6863] mt-0.5 leading-relaxed">{desc}</p>
          </Link>
        ))}
      </div>
    </div>
  )
}

const modules = [
  { href: '/users', label: 'Usuários', icon: '👥', desc: 'Pesquisar, suspender, alterar plano' },
  { href: '/clubs', label: 'Clubes', icon: '🏛️', desc: 'Moderar, transferir, excluir' },
  { href: '/books', label: 'Livros', icon: '📖', desc: 'Metadados, capas, duplicatas' },
  { href: '/moderation', label: 'Moderação', icon: '🚩', desc: 'Denúncias, spam, spoilers' },
  { href: '/billing', label: 'Financeiro', icon: '💳', desc: 'Assinaturas, MRR, cancelamentos' },
  { href: '/analytics', label: 'Analytics', icon: '📈', desc: 'Retenção, telas, livros, clubes' },
  { href: '/feature-flags', label: 'Feature Flags', icon: '🚀', desc: 'Rollout gradual sem deploy' },
  { href: '/support', label: 'Suporte', icon: '🛟', desc: 'Busca de usuário, erros recentes, auditoria' },
  { href: '/audit-logs', label: 'Audit Logs', icon: '🔒', desc: 'Histórico imutável de operações' },
  { href: '/lgpd', label: 'LGPD', icon: '⚖️', desc: 'Exclusão e exportação de dados' },
  { href: '/health', label: 'Health Check', icon: '🩺', desc: 'Status das integrações em tempo real' },
  { href: '/cron-jobs', label: 'Cron Jobs', icon: '⏱', desc: 'Monitor de jobs agendados' },
  { href: '/storage', label: 'Storage', icon: '🗂️', desc: 'Uso de disco, capas, avatares' },
  { href: '/push', label: 'Push Notifications', icon: '📣', desc: 'Fila, envio manual, entrega' },
  { href: '/email-queue', label: 'Fila de Emails', icon: '📧', desc: 'Erros, reenvio, templates' },
  { href: '/invites', label: 'Convites', icon: '🎟️', desc: 'Early Access, cotas, beta fechado' },
]
