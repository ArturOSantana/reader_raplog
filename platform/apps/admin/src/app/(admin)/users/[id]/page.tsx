import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate, timeAgo, formatMinutes } from '@lumen/ui'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import type { Metadata } from 'next'
import {
  suspendUser,
  unsuspendUser,
  banUser,
  changeUserPlan,
} from './actions'

export const metadata: Metadata = { title: 'Detalhe do Usuário · Admin Lumen' }

export default async function UserDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ action?: string }>
}) {
  const { id } = await params
  const { action } = await searchParams
  const supabase = await createServerSupabase()

  const [
    { data: profile },
    { data: sessions },
    { data: books },
    { data: subscription },
    { data: auditLogs },
  ] = await Promise.all([
    supabase
      .from('profiles')
      .select('id, username, full_name, email, bio, avatar_url, role, is_public, suspended, banned, created_at, updated_at')
      .eq('id', id)
      .single(),
    supabase
      .from('reading_sessions')
      .select('id, started_at, duration_minutes, pages_read')
      .eq('user_id', id)
      .order('started_at', { ascending: false })
      .limit(10),
    supabase
      .from('books')
      .select('id, title, author, status')
      .eq('user_id', id)
      .order('created_at', { ascending: false })
      .limit(10),
    supabase
      .from('subscriptions')
      .select('plan, status, created_at, current_period_end')
      .eq('user_id', id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from('audit_logs')
      .select('id, action, metadata, ip_address, created_at')
      .or(`actor_id.eq.${id},target_id.eq.${id}`)
      .order('created_at', { ascending: false })
      .limit(15),
  ])

  if (!profile) notFound()

  const totalMinutes = sessions?.reduce((a, s) => a + (s.duration_minutes ?? 0), 0) ?? 0
  const booksByStatus = {
    reading: books?.filter((b) => b.status === 'reading').length ?? 0,
    read: books?.filter((b) => b.status === 'read').length ?? 0,
  }

  const roleBadge: Record<string, string> = {
    user: 'bg-[#F2F1EF] text-[#6B6863]',
    admin: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
    super_admin: 'bg-[#1A1A2E]/10 text-[#1A1A2E]',
    moderator: 'bg-[#8B5E2E]/10 text-[#8B5E2E]',
    support: 'bg-[#5A9480]/10 text-[#5A9480]',
    analyst: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
  }

  const subStatusBadge: Record<string, string> = {
    active: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
    trialing: 'bg-[#8B5E2E]/10 text-[#8B5E2E]',
    canceled: 'bg-[#F2F1EF] text-[#B0AEA9]',
    past_due: 'bg-[#8B2E2E]/10 text-[#8B2E2E]',
  }

  const statusLabel: Record<string, string> = {
    reading: 'Lendo', read: 'Lido', want_to_read: 'Quero ler', abandoned: 'Abandonado',
  }

  const actionColor = (act: string): string => {
    if (act.startsWith('admin.')) return 'text-[#8B5E2E] bg-[#8B5E2E]/10'
    if (act.startsWith('user.')) return 'text-[#3D6B5A] bg-[#3D6B5A]/10'
    if (act.includes('delete') || act.includes('ban') || act.includes('suspend')) return 'text-[#8B2E2E] bg-[#8B2E2E]/10'
    return 'text-[#6B6863] bg-[#F2F1EF]'
  }

  const actionMsgs: Record<string, string> = {
    suspended: '✓ Usuário suspenso',
    unsuspended: '✓ Suspensão removida',
    banned: '✓ Usuário banido',
    plan_changed: '✓ Plano atualizado',
  }

  const isSuspended = !!(profile as Record<string, unknown>).suspended
  const isBanned = !!(profile as Record<string, unknown>).banned

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-6">
        <Link href="/users" className="hover:text-[#3D6B5A]">Usuários</Link>
        <span>/</span>
        <span className="text-[#1A1918]">@{profile.username}</span>
      </div>

      {/* Toast de feedback */}
      {action && actionMsgs[action] && (
        <div className="bg-[#3D6B5A]/10 border border-[#3D6B5A]/30 text-[#3D6B5A] rounded-xl px-4 py-3 text-sm font-medium mb-6">
          {actionMsgs[action]}
        </div>
      )}

      {/* Alertas de status */}
      {isBanned && (
        <div className="bg-[#8B2E2E]/10 border border-[#8B2E2E]/30 text-[#8B2E2E] rounded-xl px-4 py-3 text-sm font-medium mb-6">
          ⛔ Este usuário está banido da plataforma
        </div>
      )}
      {!isBanned && isSuspended && (
        <div className="bg-[#8B5E2E]/10 border border-[#8B5E2E]/30 text-[#8B5E2E] rounded-xl px-4 py-3 text-sm font-medium mb-6">
          ⏸ Este usuário está suspenso temporariamente
        </div>
      )}

      {/* Header do usuário */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-full bg-[#E8F0EE] flex items-center justify-center text-xl font-[Fraunces] font-bold text-[#3D6B5A] flex-shrink-0">
              {profile.username?.[0]?.toUpperCase() ?? 'U'}
            </div>
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <h1 className="font-[Fraunces] text-2xl font-bold text-[#1A1918]">@{profile.username}</h1>
                <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${roleBadge[profile.role ?? 'user'] ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                  {profile.role ?? 'user'}
                </span>
              </div>
              {profile.full_name && <p className="text-sm text-[#6B6863]">{profile.full_name}</p>}
              {profile.email && <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-0.5">{profile.email}</p>}
              {profile.bio && <p className="text-sm text-[#6B6863] mt-2 max-w-md">{profile.bio}</p>}
            </div>
          </div>
          <div className="text-right flex-shrink-0">
            {subscription && (
              <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${subStatusBadge[subscription.status] ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                {subscription.plan ?? 'free'} · {subscription.status}
              </span>
            )}
            <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-2">
              Cadastro: {formatDate(profile.created_at)}
            </p>
            <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">
              {profile.is_public ? 'Perfil público' : 'Perfil privado'}
            </p>
            <p className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono] mt-1 break-all max-w-[180px]">
              {profile.id}
            </p>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        {[
          { value: sessions?.length ?? 0, label: 'Sessões' },
          { value: formatMinutes(totalMinutes), label: 'Total lido' },
          { value: booksByStatus.read, label: 'Livros lidos' },
          { value: booksByStatus.reading, label: 'Lendo agora' },
        ].map(({ value, label }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-4">
            <p className="font-[Fraunces] text-2xl font-bold text-[#3D6B5A]">{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* ─── Ações administrativas ─────────────────── */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-5">Ações</h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {/* Suspender / Reativar */}
          <div className="border border-[#ECEAE9] rounded-xl p-4">
            <p className="text-sm font-medium text-[#1A1918] mb-1">
              {isSuspended ? 'Reativar conta' : 'Suspender conta'}
            </p>
            <p className="text-xs text-[#6B6863] mb-3">
              {isSuspended
                ? 'Remove a suspensão e restaura o acesso do usuário.'
                : 'Bloqueia o acesso temporariamente. O usuário pode ser reativado.'}
            </p>
            {isSuspended ? (
              <form action={unsuspendUser}>
                <input type="hidden" name="user_id" value={id} />
                <button type="submit"
                  className="text-xs font-[IBM_Plex_Mono] bg-[#3D6B5A] text-white px-4 py-2 rounded-lg hover:bg-[#5A9480] transition-colors">
                  Reativar conta
                </button>
              </form>
            ) : (
              <form action={suspendUser} className="space-y-2">
                <input type="hidden" name="user_id" value={id} />
                <input
                  name="reason"
                  placeholder="Motivo da suspensão…"
                  className="w-full border border-[#ECEAE9] rounded-lg px-3 py-1.5 text-xs focus:outline-none focus:border-[#8B5E2E]"
                />
                <button type="submit"
                  className="text-xs font-[IBM_Plex_Mono] border border-[#8B5E2E] text-[#8B5E2E] px-4 py-2 rounded-lg hover:bg-[#8B5E2E]/10 transition-colors">
                  Suspender
                </button>
              </form>
            )}
          </div>

          {/* Banir */}
          {!isBanned && (
            <div className="border border-[#ECEAE9] rounded-xl p-4">
              <p className="text-sm font-medium text-[#8B2E2E] mb-1">Banir permanentemente</p>
              <p className="text-xs text-[#6B6863] mb-3">
                Banimento irreversível. O usuário não poderá criar nova conta com o mesmo email.
              </p>
              <form action={banUser} className="space-y-2">
                <input type="hidden" name="user_id" value={id} />
                <input
                  name="reason"
                  placeholder="Motivo do banimento…"
                  required
                  className="w-full border border-[#ECEAE9] rounded-lg px-3 py-1.5 text-xs focus:outline-none focus:border-[#8B2E2E]"
                />
                <button type="submit"
                  className="text-xs font-[IBM_Plex_Mono] border border-[#8B2E2E] text-[#8B2E2E] px-4 py-2 rounded-lg hover:bg-[#8B2E2E]/10 transition-colors">
                  Banir usuário
                </button>
              </form>
            </div>
          )}

          {/* Alterar plano */}
          <div className="border border-[#ECEAE9] rounded-xl p-4">
            <p className="text-sm font-medium text-[#1A1918] mb-1">Alterar plano</p>
            <p className="text-xs text-[#6B6863] mb-3">
              Plano atual: <span className="font-[IBM_Plex_Mono]">{subscription?.plan ?? 'free'}</span>
            </p>
            <form action={changeUserPlan} className="flex gap-2 flex-wrap">
              <input type="hidden" name="user_id" value={id} />
              <select
                name="plan"
                defaultValue={subscription?.plan ?? 'free'}
                className="border border-[#ECEAE9] rounded-lg px-3 py-1.5 text-xs focus:outline-none focus:border-[#3D6B5A]"
              >
                <option value="free">Gratuito</option>
                <option value="premium_monthly">Premium Mensal</option>
                <option value="premium_annual">Premium Anual</option>
              </select>
              <button type="submit"
                className="text-xs font-[IBM_Plex_Mono] bg-[#1A1918] text-white px-4 py-2 rounded-lg hover:bg-[#2C2B29] transition-colors">
                Aplicar
              </button>
            </form>
          </div>
        </div>
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Últimas sessões */}
        <section>
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
            Últimas sessões
          </h2>
          {sessions && sessions.length > 0 ? (
            <div className="space-y-2">
              {sessions.map((s) => (
                <div key={s.id} className="bg-white border border-[#ECEAE9] rounded-xl px-4 py-3 flex items-center justify-between">
                  <p className="text-sm text-[#1A1918] font-[IBM_Plex_Mono]">
                    {formatMinutes(s.duration_minutes ?? 0)}
                    {s.pages_read != null && <span className="text-[#6B6863] ml-2">+{s.pages_read} pág.</span>}
                  </p>
                  <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">{timeAgo(s.started_at)}</p>
                </div>
              ))}
            </div>
          ) : (
            <div className="bg-[#F2F1EF] rounded-xl p-6 text-center text-[#6B6863] text-sm">Sem sessões registradas.</div>
          )}
        </section>

        {/* Livros recentes */}
        <section>
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
            Livros recentes
          </h2>
          {books && books.length > 0 ? (
            <div className="space-y-2">
              {books.map((b) => (
                <div key={b.id} className="bg-white border border-[#ECEAE9] rounded-xl px-4 py-3 flex items-center justify-between">
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-[#1A1918] truncate">{b.title}</p>
                    <p className="text-xs text-[#6B6863]">{b.author}</p>
                  </div>
                  <span className="text-[10px] font-[IBM_Plex_Mono] text-[#6B6863] bg-[#F2F1EF] px-2 py-0.5 rounded-full flex-shrink-0 ml-3">
                    {statusLabel[b.status] ?? b.status}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <div className="bg-[#F2F1EF] rounded-xl p-6 text-center text-[#6B6863] text-sm">Sem livros na biblioteca.</div>
          )}
        </section>
      </div>

      {/* Audit log do usuário */}
      {auditLogs && auditLogs.length > 0 && (
        <section className="mt-6">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
            Histórico de auditoria
          </h2>
          <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[#ECEAE9]">
                  <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Ação</th>
                  <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">IP</th>
                  <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Quando</th>
                </tr>
              </thead>
              <tbody>
                {auditLogs.map((log) => (
                  <tr key={log.id} className="border-b border-[#ECEAE9]/50 hover:bg-[#FAF9F7]">
                    <td className="p-4">
                      <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${actionColor(log.action)}`}>
                        {log.action}
                      </span>
                    </td>
                    <td className="p-4 text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] hidden sm:table-cell">{log.ip_address ?? '—'}</td>
                    <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono]">{timeAgo(log.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  )
}
