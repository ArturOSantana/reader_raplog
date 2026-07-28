import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'MFA · Lumen' }

interface PageProps {
  searchParams: Promise<{ action?: string; error?: string }>
}

export default async function MFAPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { action, error } = await searchParams

  // Verifica se MFA já está ativo
  const { data: factors } = await supabase.auth.mfa.listFactors()
  const totpFactor = factors?.totp?.find((f) => f.status === 'verified')
  const hasMFA = !!totpFactor

  // Perfil para verificar plano (spec §7: MFA disponível para Premium)
  const { data: profile } = await supabase
    .from('profiles')
    .select('role, mfa_enabled')
    .eq('id', user.id)
    .single()

  const { data: subscription } = await supabase
    .from('subscriptions')
    .select('plan, status')
    .eq('user_id', user.id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(1)
    .single()

  const isPremium = subscription?.plan !== 'free'
  const isAdminRole = ['admin', 'super_admin', 'support', 'moderator'].includes(profile?.role ?? '')
  const canUseMFA = isPremium || isAdminRole

  // Gera QR para enrollment (se não tem MFA ainda)
  let enrollData: { qr: string; secret: string; factorId: string } | null = null

  if (!hasMFA && canUseMFA && action === 'enroll') {
    const { data: enroll } = await supabase.auth.mfa.enroll({ factorType: 'totp' })
    if (enroll?.type === 'totp') {
      enrollData = {
        qr:       enroll.totp.qr_code,
        secret:   enroll.totp.secret,
        factorId: enroll.id,
      }
    }
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <Link href="/settings" className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] hover:text-[#1A1918] mb-4 inline-block">
        ← Configurações
      </Link>
      <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Segurança</p>
      <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918] mb-2">
        Autenticação em dois fatores
      </h1>
      <p className="text-sm text-[#6B6863] mb-8">
        Proteja sua conta com um app autenticador (TOTP).
      </p>

      {/* Feedback */}
      {action === 'enabled' && (
        <div className="mb-6 bg-[#3D6B5A]/10 border border-[#3D6B5A]/20 text-[#3D6B5A] px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          ✓ MFA ativado com sucesso.
        </div>
      )}
      {action === 'disabled' && (
        <div className="mb-6 bg-[#3D6B5A]/10 border border-[#3D6B5A]/20 text-[#3D6B5A] px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          MFA desativado.
        </div>
      )}
      {error && (
        <div className="mb-6 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          {error}
        </div>
      )}

      {/* Bloqueado para Free */}
      {!canUseMFA && (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-8 text-center">
          <p className="text-4xl mb-4">🔒</p>
          <p className="font-[Fraunces] text-xl text-[#1A1918] mb-2">Disponível no plano Premium</p>
          <p className="text-sm text-[#6B6863] mb-6">
            MFA (autenticação em dois fatores) está disponível para assinantes Premium.
          </p>
          <Link
            href="/billing"
            className="inline-block bg-[#1A1918] text-white px-6 py-3 rounded-xl text-sm hover:bg-[#3D6B5A] transition-colors"
          >
            Ver planos
          </Link>
        </div>
      )}

      {/* MFA já ativo */}
      {canUseMFA && hasMFA && (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <span className="w-10 h-10 bg-[#E8F0EE] rounded-xl flex items-center justify-center text-lg">🔐</span>
            <div>
              <p className="font-medium text-[#1A1918]">MFA ativo</p>
              <p className="text-xs text-[#3D6B5A] font-[IBM_Plex_Mono]">App autenticador configurado</p>
            </div>
            <span className="ml-auto text-[10px] font-[IBM_Plex_Mono] bg-[#E8F0EE] text-[#3D6B5A] px-2 py-1 rounded uppercase">
              ativo
            </span>
          </div>

          <p className="text-sm text-[#6B6863] mb-5">
            Seu app autenticador está vinculado. A cada login, você precisará digitar o código de 6 dígitos.
          </p>

          <form action={async () => {
            'use server'
            const sb = await createServerSupabase()
            const { data: f } = await sb.auth.mfa.listFactors()
            const factor = f?.totp?.find((t) => t.status === 'verified')
            if (factor) {
              await sb.auth.mfa.unenroll({ factorId: factor.id })
              const { data: { user: u } } = await sb.auth.getUser()
              if (u) {
                await sb.from('profiles').update({ mfa_enabled: false }).eq('id', u.id)
                await sb.from('audit_logs').insert({
                  actor_id: u.id,
                  action: 'user.mfa_enabled',
                  metadata: { state: 'disabled' },
                })
              }
            }
            redirect('/settings/mfa?action=disabled')
          }}>
            <button
              type="submit"
              className="text-sm px-5 py-2.5 border border-red-200 text-[#8B2E2E] rounded-xl hover:bg-red-50 font-[IBM_Plex_Mono]"
            >
              Desativar MFA
            </button>
          </form>
        </div>
      )}

      {/* Enroll — passo 1: botão para iniciar */}
      {canUseMFA && !hasMFA && !enrollData && (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
          <p className="text-sm text-[#6B6863] mb-5 leading-relaxed">
            MFA não está ativo. Ao ativar, você precisará de um app autenticador (Google Authenticator,
            Authy, etc.) a cada novo login.
          </p>
          <Link
            href="/settings/mfa?action=enroll"
            className="inline-block bg-[#1A1918] text-white px-6 py-3 rounded-xl text-sm hover:bg-[#3D6B5A] transition-colors"
          >
            Ativar MFA
          </Link>
        </div>
      )}

      {/* Enroll — passo 2: QR Code */}
      {canUseMFA && !hasMFA && enrollData && (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
          <p className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
            1. Escaneie o QR Code
          </p>
          <p className="text-sm text-[#6B6863] mb-5">
            Abra seu app autenticador e escaneie o código abaixo.
          </p>

          {/* QR Code como SVG/img inline vindo do Supabase */}
          <div className="flex justify-center mb-5">
            <img
              src={enrollData.qr}
              alt="QR Code MFA"
              className="w-48 h-48 border border-[#ECEAE9] rounded-xl p-2"
            />
          </div>

          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">Ou insira manualmente:</p>
          <code className="block bg-[#F2F1EF] px-4 py-2 rounded-xl text-xs font-[IBM_Plex_Mono] text-[#1A1918] break-all mb-6">
            {enrollData.secret}
          </code>

          <p className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-3">
            2. Digite o código de verificação
          </p>

          <form action={async (fd) => {
            'use server'
            const code = (fd.get('code') as string)?.trim()
            const factorId = fd.get('factor_id') as string
            if (!code || code.length !== 6) {
              redirect('/settings/mfa?action=enroll&error=Código inválido. Digite os 6 dígitos.')
            }
            const sb = await createServerSupabase()
            const { data: challenge } = await sb.auth.mfa.challenge({ factorId })
            if (!challenge) redirect('/settings/mfa?action=enroll&error=Falha ao iniciar verificação.')

            const { error } = await sb.auth.mfa.verify({
              factorId,
              challengeId: challenge.id,
              code,
            })

            if (error) {
              redirect(`/settings/mfa?action=enroll&error=${encodeURIComponent('Código incorreto. Tente novamente.')}`)
            }

            const { data: { user: u } } = await sb.auth.getUser()
            if (u) {
              await sb.from('profiles').update({ mfa_enabled: true }).eq('id', u.id)
              await sb.from('audit_logs').insert({
                actor_id: u.id,
                action: 'user.mfa_enabled',
                metadata: { state: 'enabled' },
              })
            }

            redirect('/settings/mfa?action=enabled')
          }}>
            <input type="hidden" name="factor_id" value={enrollData.factorId} />
            <input
              type="text"
              name="code"
              inputMode="numeric"
              pattern="[0-9]{6}"
              maxLength={6}
              required
              placeholder="000000"
              className="w-full border border-[#ECEAE9] rounded-xl px-4 py-3 text-center text-2xl font-[IBM_Plex_Mono] tracking-widest focus:outline-none focus:border-[#3D6B5A] mb-4"
            />
            <button
              type="submit"
              className="w-full bg-[#1A1918] text-white py-3 rounded-xl text-sm font-medium hover:bg-[#3D6B5A] transition-colors"
            >
              Verificar e ativar
            </button>
          </form>
        </div>
      )}
    </div>
  )
}
