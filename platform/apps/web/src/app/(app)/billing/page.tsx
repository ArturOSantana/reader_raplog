import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Assinatura · Lumen' }

interface PageProps {
  searchParams: Promise<{ action?: string }>
}

export default async function BillingPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { action } = await searchParams

  // Assinatura ativa
  const { data: sub } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(1)
    .single()

  const planLabel: Record<string, string> = {
    free:             'Gratuito',
    premium_monthly:  'Premium Mensal',
    premium_annual:   'Premium Anual',
  }

  const statusLabel: Record<string, { label: string; color: string }> = {
    active:   { label: 'Ativo',           color: 'bg-[#E8F0EE] text-[#3D6B5A]' },
    trialing: { label: 'Trial',           color: 'bg-blue-50 text-blue-700' },
    past_due: { label: 'Pagamento falhou', color: 'bg-yellow-50 text-yellow-700' },
    canceled: { label: 'Cancelado',       color: 'bg-[#F2F1EF] text-[#6B6863]' },
    expired:  { label: 'Expirado',        color: 'bg-[#F2F1EF] text-[#6B6863]' },
  }

  const isFree    = !sub || sub.plan === 'free' || sub.status === 'canceled'
  const isPremium = !isFree && (sub.status === 'active' || sub.status === 'trialing')
  const isPastDue = sub?.status === 'past_due'

  const status = statusLabel[sub?.status ?? 'canceled'] ?? { label: 'Sem plano', color: 'bg-[#F2F1EF] text-[#6B6863]' }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <Link href="/settings" className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] hover:text-[#1A1918] mb-4 inline-block">
        ← Configurações
      </Link>
      <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">
        Conta
      </p>
      <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918] mb-8">Assinatura</h1>

      {/* Feedback */}
      {action === 'canceled' && (
        <div className="mb-6 bg-[#F2F1EF] border border-[#ECEAE9] text-[#6B6863] px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          Assinatura cancelada. Você mantém o acesso até o fim do período atual.
        </div>
      )}

      {/* Alerta past_due */}
      {isPastDue && (
        <div className="mb-6 bg-yellow-50 border border-yellow-200 text-yellow-800 px-4 py-3 rounded-xl text-sm">
          ⚠️ Tivemos um problema com seu pagamento. Atualize sua forma de pagamento para não perder o acesso Premium.
          {sub.grace_period_end_at && (
            <span className="block mt-1 font-[IBM_Plex_Mono] text-xs">
              Acesso garantido até {formatDate(sub.grace_period_end_at)}
            </span>
          )}
        </div>
      )}

      {/* Card do plano atual */}
      <div className={`rounded-2xl p-6 mb-6 border ${isPremium ? 'bg-[#1A1918] border-[#1A1918] text-white' : 'bg-white border-[#ECEAE9]'}`}>
        <div className="flex items-start justify-between mb-4">
          <div>
            <p className={`text-xs font-[IBM_Plex_Mono] uppercase tracking-widest mb-1 ${isPremium ? 'text-white/60' : 'text-[#6B6863]'}`}>
              Plano atual
            </p>
            <p className={`font-[Fraunces] text-3xl font-bold ${isPremium ? 'text-white' : 'text-[#1A1918]'}`}>
              {planLabel[sub?.plan ?? 'free'] ?? 'Gratuito'}
            </p>
          </div>
          <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-1 rounded uppercase ${status.color}`}>
            {status.label}
          </span>
        </div>

        {sub?.current_period_end && isPremium && (
          <p className={`text-sm ${isPremium ? 'text-white/70' : 'text-[#6B6863]'}`}>
            {sub.canceled_at ? 'Acesso até' : 'Renova em'}: <strong>{formatDate(sub.current_period_end)}</strong>
          </p>
        )}

        {sub?.trial_end_at && sub.status === 'trialing' && (
          <p className={`text-sm mt-1 ${isPremium ? 'text-white/70' : 'text-[#6B6863]'}`}>
            Trial termina em: <strong>{formatDate(sub.trial_end_at)}</strong>
          </p>
        )}

        {sub?.channel && (
          <p className={`text-xs font-[IBM_Plex_Mono] mt-2 ${isPremium ? 'text-white/50' : 'text-[#B0AEA9]'}`}>
            Canal: {sub.channel}
          </p>
        )}
      </div>

      {/* Plano Free — opções para assinar */}
      {isFree && (
        <div className="space-y-4">
          <p className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Torne-se Premium</p>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Mensal */}
            <div className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
              <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-2">Mensal</p>
              <p className="font-[Fraunces] text-3xl font-bold text-[#1A1918] mb-1">R$ 14,90</p>
              <p className="text-xs text-[#6B6863] mb-4">por mês · 7 dias grátis</p>
              <form action={async () => {
                'use server'
                // Em produção: criar Stripe Checkout Session via Edge Function
                // Por ora, redireciona para onboarding de pagamento
                redirect('https://billing.lumen.app/subscribe?plan=monthly')
              }}>
                <button
                  type="submit"
                  className="w-full bg-[#1A1918] text-white py-2.5 rounded-xl text-sm hover:bg-[#3D6B5A] transition-colors"
                >
                  Assinar mensal
                </button>
              </form>
            </div>

            {/* Anual */}
            <div className="bg-[#1A1918] border border-[#1A1918] rounded-2xl p-5 relative">
              <span className="absolute -top-2.5 left-4 bg-[#3D6B5A] text-white text-[10px] font-[IBM_Plex_Mono] px-2.5 py-1 rounded-full uppercase tracking-wider">
                Melhor valor
              </span>
              <p className="font-[IBM_Plex_Mono] text-xs text-white/60 uppercase tracking-widest mb-2">Anual</p>
              <p className="font-[Fraunces] text-3xl font-bold text-white mb-1">R$ 99,90</p>
              <p className="text-xs text-white/60 mb-4">por ano · 14 dias grátis · economize 44%</p>
              <form action={async () => {
                'use server'
                redirect('https://billing.lumen.app/subscribe?plan=annual')
              }}>
                <button
                  type="submit"
                  className="w-full bg-white text-[#1A1918] py-2.5 rounded-xl text-sm hover:bg-[#FAF9F7] transition-colors font-medium"
                >
                  Assinar anual
                </button>
              </form>
            </div>
          </div>

          {/* Funcionalidades Premium */}
          <div className="bg-[#F8F9FA] border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-3">Incluso no Premium</p>
            <ul className="space-y-2 text-sm text-[#6B6863]">
              {[
                'Importação de bibliotecas (Goodreads, CSV)',
                'Estatísticas avançadas e Wrapped anual',
                'MFA (autenticação em dois fatores)',
                'Exportação completa de dados',
                'Acesso antecipado a novas funcionalidades',
                'Suporte prioritário',
              ].map((f) => (
                <li key={f} className="flex items-center gap-2">
                  <span className="text-[#3D6B5A]">✓</span> {f}
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {/* Plano Premium — gerenciar */}
      {isPremium && !isPastDue && (
        <div className="space-y-3">
          {sub?.channel === 'stripe' && (
            <a
              href="https://billing.lumen.app/portal"
              className="flex items-center justify-between w-full bg-white border border-[#ECEAE9] rounded-2xl px-5 py-4 hover:border-[#B0AEA9] transition-colors group"
            >
              <div>
                <p className="text-sm font-medium text-[#1A1918]">Gerenciar forma de pagamento</p>
                <p className="text-xs text-[#6B6863]">Atualizar cartão, ver faturas</p>
              </div>
              <span className="text-[#B0AEA9] group-hover:text-[#1A1918]">→</span>
            </a>
          )}

          {sub?.channel === 'apple' && (
            <div className="bg-white border border-[#ECEAE9] rounded-2xl px-5 py-4">
              <p className="text-sm font-medium text-[#1A1918]">Assinatura via App Store</p>
              <p className="text-xs text-[#6B6863] mt-1">
                Gerencie em: iPhone → Ajustes → [seu nome] → Assinaturas.
              </p>
            </div>
          )}

          {sub?.channel === 'google' && (
            <div className="bg-white border border-[#ECEAE9] rounded-2xl px-5 py-4">
              <p className="text-sm font-medium text-[#1A1918]">Assinatura via Google Play</p>
              <p className="text-xs text-[#6B6863] mt-1">
                Gerencie em: Play Store → Menu → Assinaturas.
              </p>
            </div>
          )}

          {/* Cancelar (apenas Stripe) */}
          {sub?.channel === 'stripe' && !sub.canceled_at && (
            <details className="group">
              <summary className="text-xs text-[#8B2E2E] font-[IBM_Plex_Mono] cursor-pointer hover:underline">
                Cancelar assinatura
              </summary>
              <div className="mt-3 bg-white border border-[#ECEAE9] rounded-2xl p-5">
                <p className="text-sm text-[#6B6863] mb-4">
                  Ao cancelar, você mantém acesso Premium até <strong>{sub.current_period_end ? formatDate(sub.current_period_end) : 'o fim do período'}</strong>.
                  Após isso, voltará para o plano gratuito. Seus dados são mantidos.
                </p>
                <a
                  href="https://billing.lumen.app/cancel"
                  className="inline-block text-sm px-5 py-2.5 border border-red-200 text-[#8B2E2E] rounded-xl hover:bg-red-50 font-[IBM_Plex_Mono]"
                >
                  Confirmar cancelamento
                </a>
              </div>
            </details>
          )}
        </div>
      )}
    </div>
  )
}
