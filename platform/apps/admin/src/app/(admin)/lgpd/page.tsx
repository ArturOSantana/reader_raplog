import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo, formatDate } from '@lumen/ui'
import type { Metadata } from 'next'
import { processLgpdRequest, rejectLgpdRequest } from './actions'

export const metadata: Metadata = { title: 'LGPD · Admin Lumen' }

/**
 * Módulo LGPD — processa solicitações de exclusão e exportação de dados.
 * Spec:
 *   - Exportação completa em até 15 dias
 *   - Exclusão definitiva em até 30 dias
 *   - Dados pessoais anonimizados após 2 anos de inatividade
 */
export default async function LgpdPage() {
  const supabase = await createServerSupabase()

  const { data: requests } = await supabase
    .from('lgpd_requests')
    .select('id, user_id, type, status, created_at, resolved_at, notes, profile:profiles(username, email, full_name)')
    .order('created_at', { ascending: false })
    .limit(60)

  type LgpdRequest = {
    id: string
    user_id: string
    type: 'deletion' | 'export' | 'access'
    status: 'pending' | 'processing' | 'completed' | 'failed'
    created_at: string
    resolved_at: string | null
    notes: string | null
    profile: { username: string; email: string | null; full_name: string | null } | null
  }

  const all = (requests ?? []) as unknown as LgpdRequest[]

  const pending    = all.filter((r) => r.status === 'pending')
  const processing = all.filter((r) => r.status === 'processing')
  const completed  = all.filter((r) => r.status === 'completed')

  // Prazo: 15 dias para exportação, 30 dias para exclusão
  const deadlineDays = (type: string) => (type === 'deletion' ? 30 : 15)

  const isOverdue = (r: LgpdRequest): boolean => {
    const created  = new Date(r.created_at)
    const limit    = deadlineDays(r.type)
    const deadline = new Date(created)
    deadline.setDate(deadline.getDate() + limit)
    return new Date() > deadline && r.status !== 'completed'
  }

  const typeBadge: Record<string, { label: string; cls: string }> = {
    deletion: { label: 'Exclusão',   cls: 'bg-[#8B2E2E]/10 text-[#8B2E2E]' },
    export:   { label: 'Exportação', cls: 'bg-[#8B5E2E]/10 text-[#8B5E2E]' },
    access:   { label: 'Acesso',     cls: 'bg-[#3D6B5A]/10 text-[#3D6B5A]' },
  }

  const statusBadge: Record<string, string> = {
    pending:    'bg-[#8B2E2E]/10 text-[#8B2E2E]',
    processing: 'bg-[#8B5E2E]/10 text-[#8B5E2E]',
    completed:  'bg-[#3D6B5A]/10 text-[#3D6B5A]',
    failed:     'bg-[#F2F1EF] text-[#B0AEA9]',
  }
  const statusLabel: Record<string, string> = {
    pending:    'Pendente',
    processing: 'Processando',
    completed:  'Concluído',
    failed:     'Falhou',
  }

  const overdueCount = all.filter(isOverdue).length

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">LGPD</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Direitos do usuário · exclusão em 30 dias · exportação em 15 dias
        </p>
      </div>

      {/* Alerta de prazo vencido */}
      {overdueCount > 0 && (
        <div className="bg-[#8B2E2E]/10 border border-[#8B2E2E]/30 text-[#8B2E2E] rounded-2xl p-4 mb-6 flex items-center gap-3">
          <span className="text-lg">⚠️</span>
          <p className="text-sm font-medium">
            {overdueCount} solicitaç{overdueCount !== 1 ? 'ões' : 'ão'} com prazo vencido — requer ação imediata
          </p>
        </div>
      )}

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { value: pending.length,    label: 'Pendentes',        color: '#8B2E2E' },
          { value: processing.length, label: 'Processando',      color: '#8B5E2E' },
          { value: completed.length,  label: 'Concluídas',       color: '#3D6B5A' },
          { value: overdueCount,      label: 'Com prazo vencido', color: overdueCount > 0 ? '#8B2E2E' : '#B0AEA9' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-4">
            <p className="font-[Fraunces] text-3xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Solicitações */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <div className="p-5 border-b border-[#ECEAE9]">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Solicitações</h2>
        </div>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[#ECEAE9]">
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Usuário</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Tipo</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Status</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Solicitado</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden md:table-cell">Prazo</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Ações</th>
            </tr>
          </thead>
          <tbody>
            {all.map((r) => {
              const overdue  = isOverdue(r)
              const deadline = new Date(r.created_at)
              deadline.setDate(deadline.getDate() + deadlineDays(r.type))
              const isActive = r.status === 'pending' || r.status === 'processing'
              return (
                <tr
                  key={r.id}
                  className={`border-b border-[#ECEAE9]/50 transition-colors ${
                    overdue ? 'bg-[#8B2E2E]/5' : 'hover:bg-[#FAF9F7]'
                  }`}
                >
                  <td className="p-4">
                    <p className="font-medium text-[#1A1918]">@{r.profile?.username ?? '?'}</p>
                    {r.profile?.email && <p className="text-xs text-[#6B6863]">{r.profile.email}</p>}
                  </td>
                  <td className="p-4">
                    <span
                      className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${
                        typeBadge[r.type]?.cls ?? 'bg-[#F2F1EF] text-[#B0AEA9]'
                      }`}
                    >
                      {typeBadge[r.type]?.label ?? r.type}
                    </span>
                  </td>
                  <td className="p-4">
                    <span
                      className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${
                        statusBadge[r.status] ?? 'bg-[#F2F1EF] text-[#B0AEA9]'
                      }`}
                    >
                      {statusLabel[r.status] ?? r.status}
                    </span>
                  </td>
                  <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden sm:table-cell">
                    {timeAgo(r.created_at)}
                  </td>
                  <td className="p-4 text-xs font-[IBM_Plex_Mono] hidden md:table-cell">
                    <span className={overdue ? 'text-[#8B2E2E] font-medium' : 'text-[#6B6863]'}>
                      {r.status === 'completed'
                        ? (r.resolved_at ? formatDate(r.resolved_at) : 'Concluído')
                        : formatDate(deadline.toISOString())}
                      {overdue && ' ⚠️'}
                    </span>
                  </td>
                  <td className="p-4">
                    {isActive ? (
                      <div className="flex items-center gap-2">
                        {/* Processar */}
                        <form action={processLgpdRequest}>
                          <input type="hidden" name="request_id" value={r.id} />
                          <input
                            type="hidden"
                            name="action"
                            value={r.type === 'deletion' ? 'delete' : 'export'}
                          />
                          <button
                            type="submit"
                            className="text-[10px] font-[IBM_Plex_Mono] px-3 py-1 rounded-lg bg-[#3D6B5A]/10 text-[#3D6B5A] hover:bg-[#3D6B5A]/20 transition-colors whitespace-nowrap"
                          >
                            Processar
                          </button>
                        </form>
                        {/* Rejeitar */}
                        <form action={rejectLgpdRequest}>
                          <input type="hidden" name="request_id" value={r.id} />
                          <input
                            type="hidden"
                            name="notes"
                            value="Rejeitado pelo administrador."
                          />
                          <button
                            type="submit"
                            className="text-[10px] font-[IBM_Plex_Mono] px-3 py-1 rounded-lg bg-[#8B2E2E]/10 text-[#8B2E2E] hover:bg-[#8B2E2E]/20 transition-colors whitespace-nowrap"
                          >
                            Rejeitar
                          </button>
                        </form>
                      </div>
                    ) : (
                      <span className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono]">—</span>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {all.length === 0 && (
          <div className="p-12 text-center text-[#6B6863] text-sm">
            Nenhuma solicitação LGPD registrada.
          </div>
        )}
      </div>

      {/* Referência legal */}
      <div className="mt-6 bg-[#F2F1EF] border border-[#ECEAE9] rounded-2xl p-5">
        <h3 className="font-[Fraunces] text-sm font-semibold text-[#1A1918] mb-3">Prazos legais (LGPD)</h3>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          {[
            { title: 'Exportação de dados',        deadline: '15 dias', desc: 'JSON + CSV com todos os dados do usuário' },
            { title: 'Exclusão de conta',          deadline: '30 dias', desc: 'Remove ou anonimiza todos os dados pessoais' },
            { title: 'Retenção de logs financeiros', deadline: '5 anos', desc: 'Histórico de pagamentos por obrigação legal' },
          ].map(({ title, deadline, desc }) => (
            <div key={title} className="bg-white border border-[#ECEAE9] rounded-xl p-4">
              <p className="font-[Fraunces] font-semibold text-[#1A1918] text-sm">{title}</p>
              <p className="font-[IBM_Plex_Mono] text-xs text-[#3D6B5A] mt-1">{deadline}</p>
              <p className="text-xs text-[#6B6863] mt-1">{desc}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
