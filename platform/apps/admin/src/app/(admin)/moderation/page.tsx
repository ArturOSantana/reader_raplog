import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'
import {
  resolveReport,
  dismissReport,
  markReviewing,
  shadowBanUser,
} from './actions'

export const metadata: Metadata = { title: 'Moderação · Admin Lumen' }

export default async function ModerationPage({
  searchParams,
}: {
  searchParams: Promise<{ action?: string }>
}) {
  const supabase = await createServerSupabase()
  const { action } = await searchParams

  const { data: reports } = await supabase
    .from('reports')
    .select('id, type, reason, status, content_type, created_at, target_id, reporter:profiles!reporter_id(username), target:profiles!target_id(username)')
    .order('created_at', { ascending: false })
    .limit(80)

  type Report = {
    id: string
    type: string | null
    reason: string | null
    status: string
    content_type: string | null
    target_id: string | null
    created_at: string
    reporter: { username: string } | null
    target: { username: string } | null
  }

  const all = (reports ?? []) as unknown as Report[]
  const open = all.filter((r) => r.status === 'open')
  const reviewing = all.filter((r) => r.status === 'reviewing')
  const resolved = all.filter((r) => ['resolved', 'dismissed'].includes(r.status))

  const statusBadge = (status: string) => {
    const colors: Record<string, string> = {
      open: 'bg-[#8B2E2E]/10 text-[#8B2E2E]',
      reviewing: 'bg-[#8B5E2E]/10 text-[#8B5E2E]',
      resolved: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
      dismissed: 'bg-[#F2F1EF] text-[#B0AEA9]',
    }
    const labels: Record<string, string> = {
      open: 'Aberta', reviewing: 'Em análise', resolved: 'Resolvida', dismissed: 'Descartada',
    }
    return { cls: colors[status] ?? 'bg-[#F2F1EF] text-[#B0AEA9]', label: labels[status] ?? status }
  }

  const actionMsgs: Record<string, string> = {
    resolved: '✓ Denúncia marcada como resolvida',
    dismissed: '✓ Denúncia descartada',
    reviewing: '✓ Denúncia movida para análise',
    shadow_banned: '✓ Shadow ban aplicado ao usuário',
  }

  const ReportCard = ({ r, showActions }: { r: Report; showActions: boolean }) => {
    const { cls, label } = statusBadge(r.status)
    return (
      <div className="bg-white border border-[#ECEAE9] rounded-2xl p-4">
        <div className="flex items-start justify-between gap-4 mb-3">
          <div className="min-w-0">
            <p className="text-sm text-[#1A1918]">
              <span className="font-medium">@{r.reporter?.username ?? 'anônimo'}</span>
              {' '}denunciou{' '}
              <span className="font-medium">@{r.target?.username ?? '?'}</span>
            </p>
            {r.reason && (
              <p className="text-sm text-[#6B6863] mt-1 leading-relaxed">{r.reason}</p>
            )}
            <p className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] mt-1.5">
              {r.content_type && `${r.content_type} · `}{r.type && `${r.type} · `}{timeAgo(r.created_at)}
            </p>
          </div>
          <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full flex-shrink-0 ${cls}`}>
            {label}
          </span>
        </div>

        {/* Ações — só em denúncias abertas e em análise */}
        {showActions && (
          <div className="flex flex-wrap gap-2 pt-3 border-t border-[#F2F1EF]">
            {r.status === 'open' && (
              <form action={markReviewing}>
                <input type="hidden" name="report_id" value={r.id} />
                <input type="hidden" name="target_id" value={r.target_id ?? ''} />
                <button type="submit"
                  className="text-[11px] font-[IBM_Plex_Mono] px-3 py-1.5 rounded-lg border border-[#ECEAE9] hover:border-[#8B5E2E] hover:text-[#8B5E2E] transition-colors">
                  Analisar
                </button>
              </form>
            )}
            <form action={resolveReport}>
              <input type="hidden" name="report_id" value={r.id} />
              <input type="hidden" name="target_id" value={r.target_id ?? ''} />
              <button type="submit"
                className="text-[11px] font-[IBM_Plex_Mono] px-3 py-1.5 rounded-lg border border-[#ECEAE9] hover:border-[#3D6B5A] hover:text-[#3D6B5A] transition-colors">
                Resolver
              </button>
            </form>
            <form action={dismissReport}>
              <input type="hidden" name="report_id" value={r.id} />
              <input type="hidden" name="target_id" value={r.target_id ?? ''} />
              <button type="submit"
                className="text-[11px] font-[IBM_Plex_Mono] px-3 py-1.5 rounded-lg border border-[#ECEAE9] hover:border-[#B0AEA9] hover:text-[#B0AEA9] transition-colors">
                Descartar
              </button>
            </form>
            {r.target_id && (
              <form action={shadowBanUser}>
                <input type="hidden" name="user_id" value={r.target_id} />
                <input type="hidden" name="report_id" value={r.id} />
                <button type="submit"
                  className="text-[11px] font-[IBM_Plex_Mono] px-3 py-1.5 rounded-lg border border-[#ECEAE9] hover:border-[#8B2E2E] hover:text-[#8B2E2E] transition-colors">
                  Shadow Ban
                </button>
              </form>
            )}
          </div>
        )}
      </div>
    )
  }

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Moderação</h1>
      </div>

      {/* Toast de feedback */}
      {action && actionMsgs[action] && (
        <div className="bg-[#3D6B5A]/10 border border-[#3D6B5A]/30 text-[#3D6B5A] rounded-xl px-4 py-3 text-sm font-medium mb-6">
          {actionMsgs[action]}
        </div>
      )}

      {/* Contadores */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        {[
          { value: open.length, label: 'Abertas', color: '#8B2E2E' },
          { value: reviewing.length, label: 'Em análise', color: '#8B5E2E' },
          { value: resolved.length, label: 'Resolvidas', color: '#3D6B5A' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-4">
            <p className="font-[Fraunces] text-3xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Abertas */}
      {open.length > 0 && (
        <section className="mb-8">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
            Abertas — requerem ação
          </h2>
          <div className="space-y-3">
            {open.map((r) => <ReportCard key={r.id} r={r} showActions />)}
          </div>
        </section>
      )}

      {/* Em análise */}
      {reviewing.length > 0 && (
        <section className="mb-8">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">Em análise</h2>
          <div className="space-y-3">
            {reviewing.map((r) => <ReportCard key={r.id} r={r} showActions />)}
          </div>
        </section>
      )}

      {/* Resolvidas */}
      {resolved.length > 0 && (
        <section>
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#B0AEA9] mb-4">
            Resolvidas / Descartadas ({resolved.length})
          </h2>
          <div className="space-y-3">
            {resolved.slice(0, 10).map((r) => <ReportCard key={r.id} r={r} showActions={false} />)}
          </div>
        </section>
      )}

      {all.length === 0 && (
        <div className="text-center py-24 text-[#6B6863]">
          <p className="font-[Fraunces] text-xl mb-2">Nenhuma denúncia</p>
          <p className="text-sm">A fila está vazia.</p>
        </div>
      )}
    </div>
  )
}
