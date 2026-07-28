import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Dispositivos · Lumen' }

interface PageProps {
  searchParams: Promise<{ action?: string }>
}

export default async function DevicesPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { action } = await searchParams

  // Sessões ativas via Supabase Auth
  const { data: sessionsData } = await supabase.auth.admin
    ? { data: null }
    : { data: null }

  // Supabase não expõe listagem de sessões via client-side por padrão.
  // Usamos a tabela de audit_logs (logins) como proxy para mostrar o histórico.
  const { data: loginLogs } = await supabase
    .from('audit_logs')
    .select('id, action, ip_address, user_agent, created_at, metadata')
    .eq('actor_id', user.id)
    .in('action', ['user.login', 'user.logout'])
    .order('created_at', { ascending: false })
    .limit(20)

  // Sessão atual do usuário
  const { data: sessionInfo } = await supabase.auth.getSession()
  const currentSession = sessionInfo.session

  const parseUA = (ua: string | null): string => {
    if (!ua) return 'Dispositivo desconhecido'
    if (ua.includes('iPhone') || ua.includes('iOS')) return 'iPhone · iOS'
    if (ua.includes('Android')) return 'Android'
    if (ua.includes('iPad')) return 'iPad · iOS'
    if (ua.includes('Mac')) return 'Mac'
    if (ua.includes('Windows')) return 'Windows'
    if (ua.includes('Linux')) return 'Linux'
    return 'Navegador'
  }

  const parseBrowser = (ua: string | null): string => {
    if (!ua) return ''
    if (ua.includes('Chrome')) return 'Chrome'
    if (ua.includes('Safari') && !ua.includes('Chrome')) return 'Safari'
    if (ua.includes('Firefox')) return 'Firefox'
    if (ua.includes('Edge')) return 'Edge'
    return 'Navegador'
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">
          Configurações
        </p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Sessões e Dispositivos</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Gerencie onde você está conectado.
        </p>
      </div>

      {action === 'signed_out' && (
        <div className="mb-6 bg-[#3D6B5A]/10 border border-[#3D6B5A]/20 text-[#3D6B5A] px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          Sessão encerrada com sucesso.
        </div>
      )}

      {/* Sessão atual */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden mb-6">
        <div className="px-5 py-3 border-b border-[#ECEAE9]">
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest">
            Sessão atual
          </p>
        </div>
        <div className="px-5 py-4 flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="w-2 h-2 rounded-full bg-green-500 inline-block" />
              <p className="text-sm font-medium text-[#1A1918]">Este dispositivo</p>
              <span className="text-[10px] font-[IBM_Plex_Mono] bg-green-50 text-green-700 px-1.5 py-0.5 rounded uppercase">
                ativo agora
              </span>
            </div>
            <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono]">
              {currentSession?.expires_at
                ? `Expira ${timeAgo(new Date(currentSession.expires_at * 1000).toISOString())}`
                : 'Sessão ativa'}
            </p>
          </div>
          <form action={async () => {
            'use server'
            const sb = await createServerSupabase()
            await sb.auth.signOut()
            redirect('/login')
          }}>
            <button
              type="submit"
              className="text-xs text-[#8B2E2E] hover:underline font-[IBM_Plex_Mono]"
            >
              Encerrar
            </button>
          </form>
        </div>
      </div>

      {/* Histórico de logins */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden mb-6">
        <div className="px-5 py-3 border-b border-[#ECEAE9] flex items-center justify-between">
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest">
            Histórico de acesso
          </p>
          <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">
            Últimos {loginLogs?.length ?? 0} eventos
          </p>
        </div>
        {!loginLogs?.length ? (
          <div className="py-10 text-center text-sm text-[#6B6863]">
            Nenhum registro de login encontrado.
          </div>
        ) : (
          <div className="divide-y divide-[#ECEAE9]">
            {loginLogs.map((log) => {
              const ua = (log.metadata as { user_agent?: string } | null)?.user_agent ?? log.user_agent
              return (
                <div key={log.id} className="px-5 py-3 flex items-center justify-between gap-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="text-sm text-[#1A1918]">
                        {parseUA(ua)} · {parseBrowser(ua)}
                      </p>
                      <span className={`text-[10px] font-[IBM_Plex_Mono] px-1.5 py-0.5 rounded uppercase ${
                        log.action === 'user.login'
                          ? 'bg-green-50 text-green-700'
                          : 'bg-[#F2F1EF] text-[#6B6863]'
                      }`}>
                        {log.action === 'user.login' ? 'login' : 'logout'}
                      </span>
                    </div>
                    {log.ip_address && (
                      <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-0.5">
                        {log.ip_address}
                      </p>
                    )}
                  </div>
                  <span className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] flex-shrink-0">
                    {timeAgo(log.created_at)}
                  </span>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Encerrar todas as sessões */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
        <h2 className="font-[Fraunces] text-base font-semibold text-[#1A1918] mb-2">
          Encerrar todas as outras sessões
        </h2>
        <p className="text-sm text-[#6B6863] mb-4">
          Isso encerrará todas as sessões em outros dispositivos. Você continuará conectado aqui.
        </p>
        <form action={async () => {
          'use server'
          const sb = await createServerSupabase()
          const { data: { user: u } } = await sb.auth.getUser()
          if (!u) return
          // Revoga tokens via sign out em outros dispositivos
          await sb.auth.admin?.signOut(u.id, 'others')
          await sb.from('audit_logs').insert({
            actor_id: u.id,
            action: 'user.logout',
            metadata: { scope: 'all_other_sessions' },
          })
          redirect('/settings/devices?action=signed_out')
        }}>
          <button
            type="submit"
            className="text-sm px-5 py-2.5 border border-red-200 text-[#8B2E2E] rounded-xl hover:bg-red-50 transition-colors font-[IBM_Plex_Mono]"
          >
            Encerrar outras sessões
          </button>
        </form>
      </div>
    </div>
  )
}
