import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate, timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'
import { createInvite, revokeInvite, extendInvite } from './actions'

export const metadata: Metadata = { title: 'Sistema de Convites · Admin Lumen' }

/**
 * Sistema de Convites — Early Access, beta fechado e cotas.
 * Spec §15: gerenciar Early Access, cotas, beta fechado.
 */
export default async function InvitesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string }>
}) {
  const supabase = await createServerSupabase()
  const { q, status } = await searchParams

  const [
    { data: invites },
    { count: totalInvites },
    { count: usedInvites },
    { count: pendingInvites },
    { data: waitlist },
  ] = await Promise.all([
    (() => {
      let query = supabase
        .from('invites')
        .select('id, code, email, status, type, used_at, created_at, created_by, expires_at, invitee:profiles!invitee_id(username)')
        .order('created_at', { ascending: false })
        .limit(60)
      if (q) query = query.ilike('email', `%${q}%`)
      if (status) query = query.eq('status', status)
      return query
    })(),
    supabase.from('invites').select('*', { count: 'exact', head: true }),
    supabase.from('invites').select('*', { count: 'exact', head: true }).eq('status', 'used'),
    supabase.from('invites').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    supabase
      .from('waitlist')
      .select('id, email, created_at, invited_at')
      .is('invited_at', null)
      .order('created_at', { ascending: true })
      .limit(20),
  ])

  type Invite = {
    id: string
    code: string
    email: string | null
    status: 'pending' | 'used' | 'expired' | 'revoked'
    type: 'early_access' | 'beta' | 'referral' | null
    used_at: string | null
    created_at: string
    expires_at: string | null
    created_by: string | null
    invitee: { username: string } | null
  }
  type Waitlister = {
    id: string
    email: string
    created_at: string
    invited_at: string | null
  }

  const typedInvites  = (invites ?? []) as unknown as Invite[]
  const typedWaitlist = (waitlist ?? []) as unknown as Waitlister[]

  const statusConfig: Record<string, { label: string; cls: string }> = {
    pending: { label: 'Pendente', cls: 'bg-[#8B5E2E]/10 text-[#8B5E2E]' },
    used:    { label: 'Usado',    cls: 'bg-[#3D6B5A]/10 text-[#3D6B5A]' },
    expired: { label: 'Expirado', cls: 'bg-[#F2F1EF] text-[#B0AEA9]' },
    revoked: { label: 'Revogado', cls: 'bg-[#8B2E2E]/10 text-[#8B2E2E]' },
  }

  const typeLabel: Record<string, string> = {
    early_access: 'Early Access',
    beta:         'Beta',
    referral:     'Referral',
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Sistema de Convites</h1>
        <p className="text-sm text-[#6B6863] mt-1">Early Access, cotas e beta fechado</p>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { value: totalInvites ?? 0,    label: 'Total gerados',   color: '#1A1918' },
          { value: usedInvites ?? 0,     label: 'Usados',          color: '#3D6B5A' },
          { value: pendingInvites ?? 0,  label: 'Disponíveis',     color: '#8B5E2E' },
          { value: typedWaitlist.length, label: 'Na fila de espera', color: '#B0AEA9' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[Fraunces] text-2xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Formulário de criação */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-8">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-5">
          Gerar convite
        </h2>
        <form action={createInvite} className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">Tipo</label>
              <select
                name="type"
                className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7]"
              >
                <option value="early_access">Early Access</option>
                <option value="beta">Beta</option>
                <option value="referral">Referral</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">
                Email <span className="text-[#B0AEA9]">(opcional)</span>
              </label>
              <input
                name="email"
                type="email"
                placeholder="usuario@email.com"
                className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7]"
              />
            </div>
            <div>
              <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">
                Usos máximos
              </label>
              <input
                name="max_uses"
                type="number"
                min={1}
                max={100}
                defaultValue={1}
                className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7]"
              />
            </div>
            <div>
              <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">
                Validade (dias)
              </label>
              <input
                name="expires_days"
                type="number"
                min={1}
                max={365}
                defaultValue={30}
                className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7]"
              />
            </div>
          </div>
          <div>
            <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">
              Observação <span className="text-[#B0AEA9]">(interna)</span>
            </label>
            <input
              name="notes"
              placeholder="Ex: Influencer campanha Jan/25"
              className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7]"
            />
          </div>
          <div className="flex justify-end">
            <button
              type="submit"
              className="bg-[#1A1918] text-white px-6 py-2.5 rounded-xl text-sm font-medium hover:bg-[#3D6B5A] transition-colors"
            >
              Gerar código
            </button>
          </div>
        </form>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Convites */}
        <div className="lg:col-span-2">
          {/* Filtros */}
          <form className="flex gap-2 mb-4">
            <input
              name="q"
              defaultValue={q}
              placeholder="Buscar por email…"
              className="flex-1 border border-[#ECEAE9] bg-white rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-[#3D6B5A]"
            />
            <select
              name="status"
              defaultValue={status}
              className="border border-[#ECEAE9] bg-white rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-[#3D6B5A]"
            >
              <option value="">Todos</option>
              <option value="pending">Pendente</option>
              <option value="used">Usado</option>
              <option value="expired">Expirado</option>
              <option value="revoked">Revogado</option>
            </select>
            <button
              type="submit"
              className="bg-[#1A1918] text-white px-5 py-2 rounded-xl text-sm font-medium"
            >
              Filtrar
            </button>
          </form>

          <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[#ECEAE9]">
                  <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Código</th>
                  <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden md:table-cell">Email / Usuário</th>
                  <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Status</th>
                  <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Criado</th>
                  <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Ações</th>
                </tr>
              </thead>
              <tbody>
                {typedInvites.map((inv) => {
                  const cfg       = statusConfig[inv.status]
                  const canRevoke = inv.status === 'pending'
                  const canExtend = inv.status === 'pending' || inv.status === 'expired'
                  return (
                    <tr key={inv.id} className="border-b border-[#ECEAE9]/50 hover:bg-[#FAF9F7] transition-colors">
                      <td className="p-4">
                        <code className="font-[IBM_Plex_Mono] text-xs text-[#1A1918] bg-[#F2F1EF] px-2 py-0.5 rounded">
                          {inv.code}
                        </code>
                        {inv.type && (
                          <p className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono] mt-1">
                            {typeLabel[inv.type] ?? inv.type}
                          </p>
                        )}
                        {inv.expires_at && (
                          <p className="text-[10px] text-[#6B6863] font-[IBM_Plex_Mono] mt-0.5">
                            Expira {formatDate(inv.expires_at)}
                          </p>
                        )}
                      </td>
                      <td className="p-4 hidden md:table-cell">
                        {inv.invitee ? (
                          <p className="text-sm text-[#1A1918]">@{inv.invitee.username}</p>
                        ) : inv.email ? (
                          <p className="text-sm text-[#6B6863] font-[IBM_Plex_Mono]">{inv.email}</p>
                        ) : (
                          <span className="text-[#B0AEA9]">—</span>
                        )}
                      </td>
                      <td className="p-4">
                        <span
                          className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${
                            cfg?.cls ?? 'bg-[#F2F1EF] text-[#B0AEA9]'
                          }`}
                        >
                          {cfg?.label ?? inv.status}
                        </span>
                      </td>
                      <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden sm:table-cell">
                        {timeAgo(inv.created_at)}
                      </td>
                      <td className="p-4">
                        <div className="flex items-center gap-1.5">
                          {canRevoke && (
                            <form action={revokeInvite}>
                              <input type="hidden" name="invite_id" value={inv.id} />
                              <button
                                type="submit"
                                className="text-[10px] font-[IBM_Plex_Mono] px-2.5 py-1 rounded-lg bg-[#8B2E2E]/10 text-[#8B2E2E] hover:bg-[#8B2E2E]/20 transition-colors whitespace-nowrap"
                              >
                                Revogar
                              </button>
                            </form>
                          )}
                          {canExtend && (
                            <form action={extendInvite}>
                              <input type="hidden" name="invite_id" value={inv.id} />
                              <input type="hidden" name="days" value="7" />
                              <button
                                type="submit"
                                className="text-[10px] font-[IBM_Plex_Mono] px-2.5 py-1 rounded-lg bg-[#8B5E2E]/10 text-[#8B5E2E] hover:bg-[#8B5E2E]/20 transition-colors whitespace-nowrap"
                              >
                                +7 dias
                              </button>
                            </form>
                          )}
                          {!canRevoke && !canExtend && (
                            <span className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono]">—</span>
                          )}
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
            {typedInvites.length === 0 && (
              <div className="p-12 text-center text-[#6B6863] text-sm">Nenhum convite encontrado.</div>
            )}
          </div>
        </div>

        {/* Fila de espera */}
        <div>
          <h2 className="font-[Fraunces] text-base font-semibold text-[#1A1918] mb-4">
            Fila de espera ({typedWaitlist.length})
          </h2>
          {typedWaitlist.length > 0 ? (
            <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
              <div className="divide-y divide-[#ECEAE9]">
                {typedWaitlist.map((w) => (
                  <div key={w.id} className="px-4 py-3">
                    <p className="text-xs font-[IBM_Plex_Mono] text-[#1A1918]">{w.email}</p>
                    <p className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono] mt-0.5">
                      {timeAgo(w.created_at)}
                    </p>
                    {w.invited_at && (
                      <p className="text-[10px] text-[#3D6B5A] font-[IBM_Plex_Mono]">
                        Convidado {formatDate(w.invited_at)}
                      </p>
                    )}
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="bg-[#F2F1EF] rounded-2xl p-6 text-center text-[#6B6863] text-sm">
              Fila vazia.
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
