import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo, formatDate } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Audit Logs · Admin Lumen' }

/**
 * Registros imutáveis de todas as operações sensíveis da plataforma.
 * Spec: logs nunca são deletados. Retenção mínima: 2 anos.
 * Eventos: user.login, admin.user_suspended, payment.approved, etc.
 */
export default async function AuditLogsPage({
  searchParams,
}: {
  searchParams: Promise<{ actor?: string; action?: string; page?: string }>
}) {
  const supabase = await createServerSupabase()
  const { actor, action, page: pageParam } = await searchParams
  const page = Math.max(1, parseInt(pageParam ?? '1'))
  const pageSize = 40
  const offset = (page - 1) * pageSize

  let query = supabase
    .from('audit_logs')
    .select('id, actor_id, target_id, action, metadata, ip_address, created_at, actor:profiles!actor_id(username)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(offset, offset + pageSize - 1)

  if (actor) query = query.ilike('actor.username', `%${actor}%`)
  if (action) query = query.ilike('action', `%${action}%`)

  const { data: logs, count } = await query
  const totalPages = Math.ceil((count ?? 0) / pageSize)

  // Prefixo de ação → cor
  const actionColor = (act: string): string => {
    if (act.startsWith('admin.')) return 'text-[#8B5E2E] bg-[#8B5E2E]/10'
    if (act.startsWith('user.')) return 'text-[#3D6B5A] bg-[#3D6B5A]/10'
    if (act.startsWith('payment.')) return 'text-[#1A6B5A] bg-[#1A6B5A]/10'
    if (act.includes('delete') || act.includes('ban') || act.includes('suspend')) return 'text-[#8B2E2E] bg-[#8B2E2E]/10'
    return 'text-[#6B6863] bg-[#F2F1EF]'
  }

  const buildHref = (params: Record<string, string | undefined>) => {
    const p = new URLSearchParams()
    if (params.actor) p.set('actor', params.actor)
    if (params.action) p.set('action', params.action)
    if (params.page) p.set('page', params.page)
    const str = p.toString()
    return str ? `?${str}` : '?'
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Audit Logs</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          {count ?? 0} registros · imutáveis · retenção mínima 2 anos
        </p>
      </div>

      {/* Filtros */}
      <form className="flex flex-wrap gap-2 mb-6">
        <input
          name="actor"
          defaultValue={actor}
          placeholder="Filtrar por ator (@username)…"
          className="flex-1 min-w-[180px] border border-[#ECEAE9] bg-white rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-[#3D6B5A]"
        />
        <input
          name="action"
          defaultValue={action}
          placeholder="Filtrar por ação (ex: admin.user_banned)…"
          className="flex-1 min-w-[220px] border border-[#ECEAE9] bg-white rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-[#3D6B5A]"
        />
        <button type="submit" className="bg-[#1A1918] text-white px-5 py-2 rounded-xl text-sm font-medium hover:bg-[#2C2B29] transition-colors">
          Filtrar
        </button>
      </form>

      {/* Referência de ações */}
      <details className="mb-6">
        <summary className="cursor-pointer text-xs font-[IBM_Plex_Mono] text-[#6B6863] hover:text-[#1A1918]">
          Ver ações rastreadas ↓
        </summary>
        <div className="mt-3 grid grid-cols-2 md:grid-cols-3 gap-2">
          {[
            'user.login', 'user.logout', 'user.password_changed', 'user.mfa_enabled',
            'user.account_deleted', 'user.data_exported', 'review.created', 'review.deleted',
            'note.created', 'note.deleted', 'admin.user_suspended', 'admin.user_banned',
            'admin.plan_changed', 'admin.refund_issued', 'admin.feature_flag_toggled',
            'club.owner_transferred', 'club.deleted', 'report.resolved',
            'payment.approved', 'payment.failed',
          ].map((act) => (
            <a
              key={act}
              href={buildHref({ actor, action: act, page: '1' })}
              className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-1 rounded w-fit ${actionColor(act)}`}
            >
              {act}
            </a>
          ))}
        </div>
      </details>

      {/* Tabela de logs */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[#ECEAE9]">
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Ação</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Ator</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden lg:table-cell">IP</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Quando</th>
            </tr>
          </thead>
          <tbody>
            {(logs ?? []).map((log) => {
              type LogRow = typeof log & { actor: { username: string } | null }
              const l = log as unknown as LogRow
              return (
                <tr key={l.id} className="border-b border-[#ECEAE9]/50 hover:bg-[#FAF9F7] transition-colors">
                  <td className="p-4">
                    <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${actionColor(l.action)}`}>
                      {l.action}
                    </span>
                    {l.metadata && Object.keys(l.metadata).length > 0 && (
                      <p className="text-[10px] text-[#B0AEA9] mt-1 font-[IBM_Plex_Mono] truncate max-w-[200px]">
                        {JSON.stringify(l.metadata)}
                      </p>
                    )}
                  </td>
                  <td className="p-4 text-sm text-[#6B6863] hidden sm:table-cell font-[IBM_Plex_Mono]">
                    {l.actor?.username ? `@${l.actor.username}` : l.actor_id?.slice(0, 8) ?? '—'}
                  </td>
                  <td className="p-4 text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] hidden lg:table-cell">
                    {l.ip_address ?? '—'}
                  </td>
                  <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono]" title={formatDate(l.created_at)}>
                    {timeAgo(l.created_at)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {(!logs || logs.length === 0) && (
          <div className="p-12 text-center text-[#6B6863] text-sm">Nenhum log encontrado.</div>
        )}
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm font-[IBM_Plex_Mono] text-[#6B6863]">
          <span>Página {page} de {totalPages}</span>
          <div className="flex gap-2">
            {page > 1 && (
              <a href={buildHref({ actor, action, page: String(page - 1) })}
                className="px-3 py-1.5 border border-[#ECEAE9] rounded-lg hover:border-[#B0AEA9] transition-colors">
                ← Anterior
              </a>
            )}
            {page < totalPages && (
              <a href={buildHref({ actor, action, page: String(page + 1) })}
                className="px-3 py-1.5 border border-[#ECEAE9] rounded-lg hover:border-[#B0AEA9] transition-colors">
                Próxima →
              </a>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
