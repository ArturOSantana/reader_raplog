import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { isAdminRole } from '@lumen/types'
import { timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Suporte · Admin Lumen' }

interface PageProps {
  searchParams: Promise<{ q?: string; tab?: string }>
}

export default async function SupportPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()
  if (!isAdminRole(profile?.role)) redirect('/login?error=unauthorized')

  const { q = '', tab = 'user' } = await searchParams

  // ── Busca de usuário ──────────────────────────────────────────────────────
  let searchResults: Array<{
    id: string
    username: string | null
    full_name: string | null
    email: string | null
    role: string | null
    status: string | null
    created_at: string | null
  }> = []

  if (q.trim().length >= 2) {
    const term = `%${q.trim()}%`
    const { data } = await supabase
      .from('profiles')
      .select('id, username, full_name, email, role, status, created_at')
      .or(`username.ilike.${term},full_name.ilike.${term},email.ilike.${term}`)
      .order('created_at', { ascending: false })
      .limit(20)
    searchResults = data ?? []
  }

  // ── Últimas ações de auditoria do admin (excluindo leitura) ───────────────
  const { data: recentAdminActions } = await supabase
    .from('audit_logs')
    .select('id, actor_id, action, target_id, metadata, ip_address, created_at')
    .or(
      'action.like.admin.%,' +
      'action.like.club.%,' +
      'action.eq.report.resolved,' +
      'action.eq.payment.approved,' +
      'action.eq.payment.failed'
    )
    .order('created_at', { ascending: false })
    .limit(25)

  // ── Erros recentes nos logs (nível error) ─────────────────────────────────
  const { data: recentErrors } = await supabase
    .from('audit_logs')
    .select('id, actor_id, action, metadata, created_at')
    .or('action.like.%.failed,action.like.%.error,action.eq.payment.failed')
    .order('created_at', { ascending: false })
    .limit(15)

  // ── Contas recém-suspensas / banidas ─────────────────────────────────────
  const { data: restrictedAccounts } = await supabase
    .from('profiles')
    .select('id, username, full_name, status, updated_at')
    .in('status', ['suspended', 'banned'])
    .order('updated_at', { ascending: false })
    .limit(20)

  const tabs = [
    { key: 'user', label: 'Busca de Usuário' },
    { key: 'actions', label: 'Ações Recentes' },
    { key: 'errors', label: 'Erros do Sistema' },
    { key: 'restricted', label: 'Contas Restritas' },
  ]

  const statusBadge = (status: string | null) => {
    if (!status || status === 'active') return null
    const map: Record<string, string> = {
      suspended: 'bg-yellow-100 text-yellow-800',
      banned: 'bg-red-100 text-red-800',
      pending: 'bg-blue-100 text-blue-800',
    }
    return (
      <span className={`text-[10px] font-[IBM_Plex_Mono] px-1.5 py-0.5 rounded uppercase tracking-wider ${map[status] ?? 'bg-gray-100 text-gray-600'}`}>
        {status}
      </span>
    )
  }

  const roleBadge = (role: string | null) => {
    if (!role || role === 'user') return null
    const map: Record<string, string> = {
      premium: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
      moderator: 'bg-purple-100 text-purple-700',
      admin: 'bg-[#1A1A2E]/10 text-[#1A1A2E]',
      super_admin: 'bg-[#1A1A2E] text-white',
      support: 'bg-blue-100 text-blue-700',
      club_owner: 'bg-orange-100 text-orange-700',
    }
    return (
      <span className={`text-[10px] font-[IBM_Plex_Mono] px-1.5 py-0.5 rounded uppercase tracking-wider ${map[role] ?? 'bg-gray-100 text-gray-600'}`}>
        {role}
      </span>
    )
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Suporte</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Busca de usuário, ações administrativas recentes, erros do sistema e contas restritas.
        </p>
      </div>

      {/* Barra de busca global */}
      <form method="GET" className="mb-6">
        <input type="hidden" name="tab" value={tab} />
        <div className="flex gap-2">
          <input
            name="q"
            defaultValue={q}
            placeholder="Buscar por username, nome ou email..."
            className="flex-1 border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm bg-white focus:outline-none focus:border-[#3D6B5A] font-[IBM_Plex_Mono]"
          />
          <button
            type="submit"
            className="bg-[#1A1918] text-white text-sm px-5 py-2.5 rounded-xl hover:bg-[#3D6B5A] transition-colors font-[IBM_Plex_Mono]"
          >
            Buscar
          </button>
        </div>
      </form>

      {/* Resultados de busca inline (quando há query) */}
      {q.trim().length >= 2 && (
        <div className="mb-8 bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
          <div className="px-5 py-3 border-b border-[#ECEAE9] flex items-center justify-between">
            <p className="text-sm font-[IBM_Plex_Mono] text-[#1A1918]">
              {searchResults.length} resultado{searchResults.length !== 1 ? 's' : ''} para &ldquo;{q}&rdquo;
            </p>
            {searchResults.length > 0 && (
              <Link href={`/users?q=${encodeURIComponent(q)}`} className="text-xs text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]">
                Ver em Usuários →
              </Link>
            )}
          </div>
          {searchResults.length === 0 ? (
            <div className="py-10 text-center text-sm text-[#6B6863] font-[IBM_Plex_Mono]">
              Nenhum usuário encontrado
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[#ECEAE9] text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] uppercase tracking-widest">
                  <th className="text-left px-5 py-3">Usuário</th>
                  <th className="text-left px-5 py-3 hidden sm:table-cell">Email</th>
                  <th className="text-left px-5 py-3 hidden md:table-cell">Desde</th>
                  <th className="text-left px-5 py-3">Status</th>
                  <th className="px-5 py-3" />
                </tr>
              </thead>
              <tbody>
                {searchResults.map((u) => (
                  <tr key={u.id} className="border-b border-[#ECEAE9] last:border-0 hover:bg-[#F8F9FA]">
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-[#E8F0EE] flex items-center justify-center text-xs font-medium text-[#3D6B5A] flex-shrink-0">
                          {(u.username ?? u.full_name ?? '?')[0]?.toUpperCase()}
                        </div>
                        <div>
                          <p className="font-medium text-[#1A1918]">@{u.username ?? '—'}</p>
                          {u.full_name && <p className="text-xs text-[#6B6863]">{u.full_name}</p>}
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3 text-[#6B6863] hidden sm:table-cell">
                      {u.email ?? '—'}
                    </td>
                    <td className="px-5 py-3 text-[#B0AEA9] font-[IBM_Plex_Mono] text-xs hidden md:table-cell">
                      {u.created_at ? new Date(u.created_at).toLocaleDateString('pt-BR') : '—'}
                    </td>
                    <td className="px-5 py-3">
                      <div className="flex gap-1.5 flex-wrap">
                        {roleBadge(u.role)}
                        {statusBadge(u.status)}
                      </div>
                    </td>
                    <td className="px-5 py-3 text-right">
                      <Link
                        href={`/users/${u.id}`}
                        className="text-xs text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]"
                      >
                        Ver →
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 mb-6 border-b border-[#ECEAE9]">
        {tabs.map(({ key, label }) => (
          <Link
            key={key}
            href={`/support?tab=${key}${q ? `&q=${encodeURIComponent(q)}` : ''}`}
            className={`px-4 py-2 text-sm font-[IBM_Plex_Mono] transition-colors border-b-2 -mb-px ${
              tab === key
                ? 'border-[#3D6B5A] text-[#3D6B5A]'
                : 'border-transparent text-[#6B6863] hover:text-[#1A1918]'
            }`}
          >
            {label}
          </Link>
        ))}
      </div>

      {/* Tab: Ações recentes do admin */}
      {tab === 'actions' && (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
          <div className="px-5 py-3 border-b border-[#ECEAE9]">
            <p className="text-sm font-[IBM_Plex_Mono] text-[#6B6863]">
              Últimas {recentAdminActions?.length ?? 0} ações administrativas
            </p>
          </div>
          {!recentAdminActions?.length ? (
            <div className="py-12 text-center text-sm text-[#6B6863] font-[IBM_Plex_Mono]">
              Nenhuma ação registrada
            </div>
          ) : (
            <div className="divide-y divide-[#ECEAE9]">
              {recentAdminActions.map((log) => (
                <div key={log.id} className="px-5 py-3 flex items-start justify-between gap-4 hover:bg-[#F8F9FA]">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <code className="text-xs font-[IBM_Plex_Mono] text-[#3D6B5A] bg-[#3D6B5A]/5 px-1.5 py-0.5 rounded">
                        {log.action}
                      </code>
                      {log.target_id && (
                        <span className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] truncate max-w-[160px]">
                          → {String(log.target_id).slice(0, 8)}…
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-3 mt-1">
                      <Link
                        href={`/users/${log.actor_id}`}
                        className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] hover:underline"
                      >
                        ator: {String(log.actor_id).slice(0, 8)}…
                      </Link>
                      {log.ip_address && (
                        <span className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">{log.ip_address}</span>
                      )}
                    </div>
                  </div>
                  <span className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] flex-shrink-0">
                    {log.created_at ? timeAgo(log.created_at) : '—'}
                  </span>
                </div>
              ))}
            </div>
          )}
          <div className="px-5 py-3 border-t border-[#ECEAE9]">
            <Link href="/audit-logs" className="text-xs text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]">
              Ver audit logs completos →
            </Link>
          </div>
        </div>
      )}

      {/* Tab: Erros do sistema */}
      {tab === 'errors' && (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
          <div className="px-5 py-3 border-b border-[#ECEAE9]">
            <p className="text-sm font-[IBM_Plex_Mono] text-[#6B6863]">
              Últimos {recentErrors?.length ?? 0} erros registrados
            </p>
          </div>
          {!recentErrors?.length ? (
            <div className="py-12 text-center">
              <p className="text-2xl mb-2">✅</p>
              <p className="text-sm text-[#6B6863] font-[IBM_Plex_Mono]">Nenhum erro registrado</p>
            </div>
          ) : (
            <div className="divide-y divide-[#ECEAE9]">
              {recentErrors.map((err) => (
                <div key={err.id} className="px-5 py-3 flex items-start justify-between gap-4 hover:bg-[#F8F9FA]">
                  <div className="min-w-0 flex-1">
                    <code className="text-xs font-[IBM_Plex_Mono] text-[#8B2E2E] bg-[#8B2E2E]/5 px-1.5 py-0.5 rounded">
                      {err.action}
                    </code>
                    {err.metadata && typeof err.metadata === 'object' && (
                      <p className="text-xs text-[#6B6863] mt-1 truncate">
                        {JSON.stringify(err.metadata).slice(0, 120)}
                      </p>
                    )}
                  </div>
                  <span className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] flex-shrink-0">
                    {err.created_at ? timeAgo(err.created_at) : '—'}
                  </span>
                </div>
              ))}
            </div>
          )}
          <div className="px-5 py-3 border-t border-[#ECEAE9]">
            <Link href="/health" className="text-xs text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]">
              Ver Health Check →
            </Link>
          </div>
        </div>
      )}

      {/* Tab: Contas restritas */}
      {tab === 'restricted' && (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
          <div className="px-5 py-3 border-b border-[#ECEAE9]">
            <p className="text-sm font-[IBM_Plex_Mono] text-[#6B6863]">
              {restrictedAccounts?.length ?? 0} conta{restrictedAccounts?.length !== 1 ? 's' : ''} suspensa{restrictedAccounts?.length !== 1 ? 's' : ''} ou banida{restrictedAccounts?.length !== 1 ? 's' : ''}
            </p>
          </div>
          {!restrictedAccounts?.length ? (
            <div className="py-12 text-center">
              <p className="text-2xl mb-2">✅</p>
              <p className="text-sm text-[#6B6863] font-[IBM_Plex_Mono]">Nenhuma conta restrita</p>
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[#ECEAE9] text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] uppercase tracking-widest">
                  <th className="text-left px-5 py-3">Usuário</th>
                  <th className="text-left px-5 py-3">Status</th>
                  <th className="text-left px-5 py-3 hidden sm:table-cell">Atualizado</th>
                  <th className="px-5 py-3" />
                </tr>
              </thead>
              <tbody>
                {restrictedAccounts.map((acc) => (
                  <tr key={acc.id} className="border-b border-[#ECEAE9] last:border-0 hover:bg-[#F8F9FA]">
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-red-50 flex items-center justify-center text-xs font-medium text-red-500 flex-shrink-0">
                          {(acc.username ?? acc.full_name ?? '?')[0]?.toUpperCase()}
                        </div>
                        <div>
                          <p className="font-medium text-[#1A1918]">@{acc.username ?? '—'}</p>
                          {acc.full_name && <p className="text-xs text-[#6B6863]">{acc.full_name}</p>}
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3">
                      {statusBadge(acc.status)}
                    </td>
                    <td className="px-5 py-3 text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] hidden sm:table-cell">
                      {acc.updated_at ? timeAgo(acc.updated_at) : '—'}
                    </td>
                    <td className="px-5 py-3 text-right">
                      <Link
                        href={`/users/${acc.id}`}
                        className="text-xs text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]"
                      >
                        Ver →
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <div className="px-5 py-3 border-t border-[#ECEAE9]">
            <Link href="/users?status=banned" className="text-xs text-[#8B2E2E] hover:underline font-[IBM_Plex_Mono]">
              Ver todos os banidos →
            </Link>
          </div>
        </div>
      )}

      {/* Tab: Busca de usuário (padrão) */}
      {tab === 'user' && (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-8 text-center">
          <p className="text-4xl mb-4">🔍</p>
          <p className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-2">
            Busca de Usuário
          </p>
          <p className="text-sm text-[#6B6863] max-w-sm mx-auto leading-relaxed">
            Use a barra de busca acima para encontrar um usuário por username, nome completo ou email.
            Os resultados aparecem diretamente nesta página.
          </p>
          <div className="mt-6 grid grid-cols-3 gap-3 max-w-md mx-auto text-left">
            <div className="bg-[#F8F9FA] rounded-xl p-3 text-center">
              <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863]">Username</p>
              <p className="text-xs text-[#B0AEA9] mt-0.5">@joao</p>
            </div>
            <div className="bg-[#F8F9FA] rounded-xl p-3 text-center">
              <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863]">Nome</p>
              <p className="text-xs text-[#B0AEA9] mt-0.5">João Silva</p>
            </div>
            <div className="bg-[#F8F9FA] rounded-xl p-3 text-center">
              <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863]">Email</p>
              <p className="text-xs text-[#B0AEA9] mt-0.5">j@email.com</p>
            </div>
          </div>
          <div className="mt-6 flex justify-center gap-4">
            <Link href="/users" className="text-sm text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]">
              → Gerenciar todos os usuários
            </Link>
            <Link href="/moderation" className="text-sm text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]">
              → Fila de moderação
            </Link>
          </div>
        </div>
      )}
    </div>
  )
}
