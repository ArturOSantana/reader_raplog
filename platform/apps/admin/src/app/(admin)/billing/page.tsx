import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Financeiro · Admin Lumen' }

export default async function BillingPage() {
  const supabase = await createServerSupabase()

  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)

  const [
    { data: subs },
    { count: activeCount },
    { count: trialingCount },
    { count: canceledMonth },
    { count: newMonth },
    { count: pastDueCount },
  ] = await Promise.all([
    supabase
      .from('subscriptions')
      .select('*, profile:profiles(username, full_name)')
      .order('created_at', { ascending: false })
      .limit(60),
    supabase.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'active'),
    supabase.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'trialing'),
    supabase.from('subscriptions').select('*', { count: 'exact', head: true })
      .eq('status', 'canceled').gte('updated_at', monthStart.toISOString()),
    supabase.from('subscriptions').select('*', { count: 'exact', head: true })
      .eq('status', 'active').gte('created_at', monthStart.toISOString()),
    supabase.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'past_due'),
  ])

  // MRR estimado — R$14,90/mês por assinante ativo mensal (spec)
  const MRR_MONTHLY = 14.9
  const mrr = (activeCount ?? 0) * MRR_MONTHLY

  const planLabel: Record<string, string> = {
    free: 'Gratuito',
    pro: 'Pro',
    premium_monthly: 'Premium Mensal',
    premium_annual: 'Premium Anual',
    annual: 'Anual',
  }

  const statusBadge: Record<string, string> = {
    active: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
    canceled: 'bg-[#F2F1EF] text-[#B0AEA9]',
    past_due: 'bg-[#8B2E2E]/10 text-[#8B2E2E]',
    trialing: 'bg-[#8B5E2E]/10 text-[#8B5E2E]',
  }

  const statusLabel: Record<string, string> = {
    active: 'Ativo',
    canceled: 'Cancelado',
    past_due: 'Em atraso',
    trialing: 'Trial',
  }

  const kpis = [
    { value: `R$ ${mrr.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`, label: 'MRR estimado', sub: `${activeCount ?? 0} assinantes × R$14,90`, color: '#3D6B5A' },
    { value: activeCount ?? 0, label: 'Assinantes ativos', sub: `+${newMonth ?? 0} este mês`, color: '#5A9480' },
    { value: trialingCount ?? 0, label: 'Em trial', sub: '7 ou 14 dias', color: '#8B5E2E' },
    { value: canceledMonth ?? 0, label: 'Cancelamentos no mês', sub: 'churn mensal', color: (canceledMonth ?? 0) > 0 ? '#8B2E2E' : '#B0AEA9' },
    { value: pastDueCount ?? 0, label: 'Em atraso', sub: 'período de carência', color: (pastDueCount ?? 0) > 0 ? '#8B2E2E' : '#B0AEA9' },
    { value: newMonth ?? 0, label: 'Novos este mês', sub: 'conversões', color: '#3D6B5A' },
  ]

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Financeiro</h1>
        <p className="text-sm text-[#6B6863] mt-1">Assinaturas, MRR e ciclo de vida</p>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-8">
        {kpis.map(({ value, label, sub, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[Fraunces] text-2xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
            <p className="text-[10px] text-[#B0AEA9] mt-0.5 font-[IBM_Plex_Mono]">{sub}</p>
          </div>
        ))}
      </div>

      {/* Tabela de assinaturas */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <div className="p-5 border-b border-[#ECEAE9] flex items-center justify-between">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Assinaturas</h2>
          <span className="text-xs font-[IBM_Plex_Mono] text-[#6B6863]">{subs?.length ?? 0} registros</span>
        </div>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[#ECEAE9]">
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Usuário</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden md:table-cell">Plano</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Status</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Início</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden lg:table-cell">Próx. cobrança</th>
            </tr>
          </thead>
          <tbody>
            {subs?.map((sub) => (
              <tr key={sub.id} className="border-b border-[#ECEAE9]/50 hover:bg-[#FAF9F7] transition-colors">
                <td className="p-4">
                  <p className="font-medium text-[#1A1918]">@{sub.profile?.username ?? '?'}</p>
                  {sub.profile?.full_name && <p className="text-xs text-[#6B6863]">{sub.profile.full_name}</p>}
                </td>
                <td className="p-4 text-[#6B6863] hidden md:table-cell">{planLabel[sub.plan] ?? sub.plan ?? '—'}</td>
                <td className="p-4">
                  <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${statusBadge[sub.status] ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                    {statusLabel[sub.status] ?? sub.status}
                  </span>
                </td>
                <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden sm:table-cell">
                  {sub.created_at ? formatDate(sub.created_at) : '—'}
                </td>
                <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden lg:table-cell">
                  {sub.current_period_end ? formatDate(sub.current_period_end) : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!subs || subs.length === 0) && (
          <div className="p-12 text-center text-[#6B6863] text-sm">Nenhuma assinatura ainda.</div>
        )}
      </div>
    </div>
  )
}
