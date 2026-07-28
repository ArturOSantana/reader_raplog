import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate } from '@lumen/ui'
import { isAdminRole } from '@lumen/types'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Configurações · Lumen Web' }

/**
 * Configurações de conta e privacidade.
 * Spec §9: cada item de privacidade é individualmente configurável; padrão é Privado.
 * Spec §11: exportação disponível a qualquer momento (LGPD).
 */
export default async function SettingsPage() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, username, full_name, email, bio, avatar_url, is_public, role, created_at')
    .eq('id', user.id)
    .single()

  const { data: privacySettings } = await supabase
    .from('privacy_settings')
    .select('*')
    .eq('user_id', user.id)
    .maybeSingle()

  const isAdmin = isAdminRole(profile?.role)

  // Valores com fallback nos padrões da spec
  const privacy = {
    current_book: (privacySettings as Record<string, unknown> | null)?.current_book ?? 'private',
    library: (privacySettings as Record<string, unknown> | null)?.library ?? 'private',
    reviews: (privacySettings as Record<string, unknown> | null)?.reviews ?? 'public',
    stats: (privacySettings as Record<string, unknown> | null)?.stats ?? 'private',
    lists: (privacySettings as Record<string, unknown> | null)?.lists ?? 'private',
    favorites: (privacySettings as Record<string, unknown> | null)?.favorites ?? 'private',
    followers: (privacySettings as Record<string, unknown> | null)?.followers ?? 'visible',
    profile: (privacySettings as Record<string, unknown> | null)?.profile ?? 'public',
  }

  const privacyItems = [
    { key: 'profile', label: 'Perfil', options: ['public', 'private'], default_: 'public' },
    { key: 'current_book', label: 'Leitura atual', options: ['public', 'friends', 'clubs', 'private'], default_: 'private' },
    { key: 'library', label: 'Biblioteca', options: ['public', 'friends', 'private'], default_: 'private' },
    { key: 'reviews', label: 'Reviews', options: ['public', 'friends', 'private'], default_: 'public' },
    { key: 'stats', label: 'Estatísticas', options: ['public', 'friends', 'private'], default_: 'private' },
    { key: 'lists', label: 'Listas', options: ['public', 'friends', 'private'], default_: 'private' },
    { key: 'favorites', label: 'Favoritos', options: ['public', 'friends', 'private'], default_: 'private' },
    { key: 'followers', label: 'Seguidores', options: ['visible', 'hidden'], default_: 'visible' },
  ] as const

  const optionLabel: Record<string, string> = {
    public: 'Público',
    friends: 'Amigos',
    clubs: 'Clube',
    private: 'Privado',
    visible: 'Visível',
    hidden: 'Oculto',
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="mb-8">
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Configurações</h1>
        <p className="text-sm text-[#6B6863] mt-1">Conta, privacidade e dados</p>
      </div>

      {/* ─── Informações da conta ──────────────────── */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-5">Conta</h2>
        <div className="flex items-center gap-4 mb-6">
          <div className="w-14 h-14 rounded-full bg-[#E8F0EE] flex items-center justify-center text-2xl font-[Fraunces] font-bold text-[#3D6B5A] flex-shrink-0">
            {profile?.username?.[0]?.toUpperCase() ?? 'U'}
          </div>
          <div>
            <p className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">@{profile?.username}</p>
            {profile?.full_name && <p className="text-sm text-[#6B6863]">{profile.full_name}</p>}
            {profile?.email && <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">{profile.email}</p>}
            {isAdmin && (
              <span className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A] bg-[#3D6B5A]/10 px-2 py-0.5 rounded-full mt-1 inline-block">
                {profile?.role}
              </span>
            )}
          </div>
        </div>

        <dl className="space-y-3 text-sm">
          {[
            { label: 'Username', value: `@${profile?.username}` },
            { label: 'Membro desde', value: profile?.created_at ? formatDate(profile.created_at) : '—' },
            { label: 'Perfil', value: profile?.is_public ? 'Público' : 'Privado' },
          ].map(({ label, value }) => (
            <div key={label} className="flex items-center justify-between py-2 border-b border-[#F2F1EF] last:border-0">
              <dt className="text-[#6B6863] font-[IBM_Plex_Mono] text-xs">{label}</dt>
              <dd className="text-[#1A1918] font-medium">{value}</dd>
            </div>
          ))}
        </dl>

        <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-4">
          Para alterar username ou nome, use o app Lumen no celular.
        </p>
      </section>

      {/* ─── Privacidade ───────────────────────────── */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <div className="flex items-center justify-between mb-2">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Privacidade</h2>
          <span className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">padrão: privado</span>
        </div>
        <p className="text-xs text-[#6B6863] mb-6">
          Notas e destaques são sempre privados e não aparecem aqui.
        </p>

        <div className="space-y-0">
          {privacyItems.map(({ key, label, options, default_ }) => {
            const current = String(privacy[key as keyof typeof privacy])
            return (
              <div key={key} className="flex items-center justify-between py-3 border-b border-[#F2F1EF] last:border-0">
                <div>
                  <p className="text-sm text-[#1A1918] font-medium">{label}</p>
                  {current === default_ && (
                    <p className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono]">padrão</p>
                  )}
                </div>
                <div className="flex gap-1">
                  {options.map((opt) => (
                    <span
                      key={opt}
                      className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-1 rounded-lg cursor-default ${
                        current === opt
                          ? 'bg-[#1A1918] text-[#FAF9F7]'
                          : 'bg-[#F2F1EF] text-[#6B6863]'
                      }`}
                    >
                      {optionLabel[opt]}
                    </span>
                  ))}
                </div>
              </div>
            )
          })}
        </div>

        <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-4">
          Para alterar configurações de privacidade, use o app Lumen no celular.
        </p>
      </section>

      {/* ─── LGPD / Seus dados ─────────────────────── */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-2">Seus dados</h2>
        <p className="text-xs text-[#6B6863] mb-6">
          Você tem controle total sobre seus dados. Exportação entregue em até 15 dias.
        </p>

        <div className="space-y-3">
          <Link
            href="/settings/export"
            className="flex items-center justify-between w-full bg-[#F2F1EF] hover:bg-[#ECEAE9] rounded-xl px-4 py-3 transition-colors"
          >
            <div>
              <p className="text-sm font-medium text-[#1A1918]">Exportar meus dados</p>
              <p className="text-xs text-[#6B6863]">JSON + CSV com toda sua biblioteca, sessões e notas</p>
            </div>
            <span className="text-[#6B6863] text-xs">→</span>
          </Link>

          <div className="flex items-center justify-between w-full bg-[#F2F1EF] rounded-xl px-4 py-3">
            <div>
              <p className="text-sm font-medium text-[#8B2E2E]">Excluir minha conta</p>
              <p className="text-xs text-[#6B6863]">Remoção definitiva em até 30 dias. Esta ação é irreversível.</p>
            </div>
            <span className="text-xs font-[IBM_Plex_Mono] text-[#B0AEA9]">via app</span>
          </div>
        </div>
      </section>

      {/* ─── Link para Admin (se for admin) ──────── */}
      {isAdmin && (
        <section className="bg-[#1A1A2E]/5 border border-[#1A1A2E]/15 rounded-2xl p-5">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-[Fraunces] font-semibold text-[#1A1918] text-sm">Admin Console</p>
              <p className="text-xs text-[#6B6863] mt-0.5">Acesso operacional — role: {profile?.role}</p>
            </div>
            <a
              href="https://admin.lumen.app"
              className="text-xs font-[IBM_Plex_Mono] bg-[#1A1A2E] text-white px-4 py-2 rounded-xl hover:bg-[#2C2B29] transition-colors"
            >
              Abrir Admin →
            </a>
          </div>
        </section>
      )}

      {/* ─── Logout ───────────────────────────────── */}
      <div className="mt-6">
        <a
          href="/auth/logout"
          className="block w-full text-center border border-[#ECEAE9] text-[#6B6863] rounded-xl px-4 py-3 text-sm hover:border-[#8B2E2E] hover:text-[#8B2E2E] transition-colors"
        >
          Sair da conta
        </a>
      </div>
    </div>
  )
}
