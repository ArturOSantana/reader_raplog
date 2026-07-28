import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'
import { sendManualPush } from './actions'

export const metadata: Metadata = { title: 'Push Notifications · Admin Lumen' }

export default async function PushPage() {
  const supabase = await createServerSupabase()

  const [
    { data: queue },
    { count: sentToday },
    { count: failedTotal },
    { count: devicesTotal },
  ] = await Promise.all([
    supabase
      .from('push_queue')
      .select('id, title, body, status, sent_at, created_at, error_message, target_type')
      .order('created_at', { ascending: false })
      .limit(30),
    supabase
      .from('push_queue')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'sent')
      .gte('sent_at', new Date(new Date().setHours(0, 0, 0, 0)).toISOString()),
    supabase
      .from('push_queue')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'failed'),
    supabase
      .from('push_tokens')
      .select('*', { count: 'exact', head: true }),
  ])

  type PushItem = {
    id: string
    title: string | null
    body: string | null
    status: 'pending' | 'sent' | 'failed'
    sent_at: string | null
    created_at: string
    error_message: string | null
    target_type: 'all' | 'segment' | 'user' | null
  }

  const items = (queue ?? []) as unknown as PushItem[]

  const statusConfig: Record<string, { label: string; cls: string }> = {
    pending: { label: 'Pendente', cls: 'bg-[#8B5E2E]/10 text-[#8B5E2E]' },
    sent:    { label: 'Enviado',  cls: 'bg-[#3D6B5A]/10 text-[#3D6B5A]' },
    failed:  { label: 'Falhou',   cls: 'bg-[#8B2E2E]/10 text-[#8B2E2E]' },
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Push Notifications</h1>
        <p className="text-sm text-[#6B6863] mt-1">Fila de envio, erros e dispositivos registrados</p>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { value: devicesTotal ?? 0, label: 'Dispositivos',  color: '#3D6B5A' },
          { value: sentToday ?? 0,    label: 'Enviados hoje', color: '#5A9480' },
          { value: items.filter((i) => i.status === 'pending').length, label: 'Na fila', color: '#8B5E2E' },
          { value: failedTotal ?? 0,  label: 'Com falha',     color: (failedTotal ?? 0) > 0 ? '#8B2E2E' : '#B0AEA9' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[Fraunces] text-2xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Alerta de falhas */}
      {(failedTotal ?? 0) > 0 && (
        <div className="bg-[#8B2E2E]/10 border border-[#8B2E2E]/30 text-[#8B2E2E] rounded-xl px-4 py-3 text-sm font-medium mb-6">
          {failedTotal} notificaç{failedTotal !== 1 ? 'ões' : 'ão'} com falha de entrega
        </div>
      )}

      {/* Formulário de envio manual */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-8">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-5">
          Enviar push manual
        </h2>
        <form action={sendManualPush} className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">
                Título <span className="text-[#8B2E2E]">*</span>
              </label>
              <input
                name="title"
                required
                placeholder="Ex: Nova conquista desbloqueada!"
                className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7]"
              />
            </div>
            <div>
              <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">
                Alvo
              </label>
              <select
                name="target_type"
                className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7]"
              >
                <option value="all">Todos os usuários</option>
                <option value="user">Usuário específico</option>
              </select>
            </div>
          </div>
          <div>
            <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">
              Mensagem <span className="text-[#8B2E2E]">*</span>
            </label>
            <textarea
              name="body"
              required
              rows={2}
              placeholder="Texto da notificação…"
              className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7] resize-none"
            />
          </div>
          <div>
            <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">
              ID do usuário <span className="text-[#B0AEA9]">(apenas para alvo &quot;específico&quot;)</span>
            </label>
            <input
              name="user_id"
              placeholder="uuid do usuário"
              className="w-full border border-[#ECEAE9] rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#3D6B5A] bg-[#FAF9F7] font-[IBM_Plex_Mono]"
            />
          </div>
          <div className="flex justify-end">
            <button
              type="submit"
              className="bg-[#1A1918] text-white px-6 py-2.5 rounded-xl text-sm font-medium hover:bg-[#3D6B5A] transition-colors"
            >
              Enviar notificação
            </button>
          </div>
        </form>
      </div>

      {/* Fila */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <div className="p-5 border-b border-[#ECEAE9]">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Fila de envio</h2>
        </div>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[#ECEAE9]">
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Mensagem</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Alvo</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Status</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden md:table-cell">Criado</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => {
              const cfg = statusConfig[item.status]
              return (
                <tr key={item.id} className="border-b border-[#ECEAE9]/50 hover:bg-[#FAF9F7] transition-colors">
                  <td className="p-4">
                    <p className="font-medium text-[#1A1918] text-sm">{item.title ?? '—'}</p>
                    {item.body && (
                      <p className="text-xs text-[#6B6863] mt-0.5 truncate max-w-[200px]">{item.body}</p>
                    )}
                    {item.error_message && (
                      <p className="text-[10px] text-[#8B2E2E] mt-1 font-[IBM_Plex_Mono]">{item.error_message}</p>
                    )}
                  </td>
                  <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden sm:table-cell">
                    {item.target_type ?? 'all'}
                  </td>
                  <td className="p-4">
                    <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${cfg?.cls ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                      {cfg?.label ?? item.status}
                    </span>
                  </td>
                  <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden md:table-cell">
                    {timeAgo(item.created_at)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {items.length === 0 && (
          <div className="p-12 text-center text-[#6B6863] text-sm">Fila vazia.</div>
        )}
      </div>
    </div>
  )
}
