import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Fila de Emails · Admin Lumen' }

export default async function EmailQueuePage() {
  const supabase = await createServerSupabase()

  const [
    { data: emails },
    { count: failedCount },
    { count: sentToday },
    { count: pendingCount },
  ] = await Promise.all([
    supabase
      .from('email_queue')
      .select('id, to_email, subject, template, status, error_message, created_at, sent_at, retry_count')
      .order('created_at', { ascending: false })
      .limit(50),
    supabase
      .from('email_queue')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'failed'),
    supabase
      .from('email_queue')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'sent')
      .gte('sent_at', new Date(new Date().setHours(0, 0, 0, 0)).toISOString()),
    supabase
      .from('email_queue')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'pending'),
  ])

  type EmailItem = {
    id: string
    to_email: string
    subject: string | null
    template: string | null
    status: 'pending' | 'sent' | 'failed'
    error_message: string | null
    created_at: string
    sent_at: string | null
    retry_count: number | null
  }

  const items = (emails ?? []) as unknown as EmailItem[]

  const statusConfig: Record<string, { label: string; cls: string }> = {
    pending: { label: 'Pendente', cls: 'bg-[#8B5E2E]/10 text-[#8B5E2E]' },
    sent: { label: 'Enviado', cls: 'bg-[#3D6B5A]/10 text-[#3D6B5A]' },
    failed: { label: 'Falhou', cls: 'bg-[#8B2E2E]/10 text-[#8B2E2E]' },
  }

  const templateLabel: Record<string, string> = {
    welcome: 'Boas-vindas',
    magic_link: 'Magic Link',
    password_reset: 'Redefinição de senha',
    export_ready: 'Dados prontos',
    subscription_confirmed: 'Assinatura confirmada',
    subscription_canceled: 'Assinatura cancelada',
    payment_failed: 'Pagamento falhou',
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Fila de Emails</h1>
        <p className="text-sm text-[#6B6863] mt-1">Erros de entrega, reenvio e templates</p>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { value: pendingCount ?? 0, label: 'Na fila', color: '#8B5E2E' },
          { value: sentToday ?? 0, label: 'Enviados hoje', color: '#3D6B5A' },
          { value: failedCount ?? 0, label: 'Com falha', color: (failedCount ?? 0) > 0 ? '#8B2E2E' : '#B0AEA9' },
          { value: items.filter((e) => (e.retry_count ?? 0) > 0).length, label: 'Com retentativa', color: '#B0AEA9' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[Fraunces] text-2xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Alerta de falhas */}
      {(failedCount ?? 0) > 0 && (
        <div className="bg-[#8B2E2E]/10 border border-[#8B2E2E]/30 text-[#8B2E2E] rounded-xl px-4 py-3 text-sm font-medium mb-6">
          {failedCount} email{failedCount !== 1 ? 's' : ''} com falha de entrega — verifique o provedor de email
        </div>
      )}

      {/* Tabela */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <div className="p-5 border-b border-[#ECEAE9]">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Fila</h2>
        </div>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[#ECEAE9]">
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Destinatário</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden md:table-cell">Template</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Status</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Criado</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => {
              const cfg = statusConfig[item.status]
              return (
                <tr key={item.id} className="border-b border-[#ECEAE9]/50 hover:bg-[#FAF9F7] transition-colors">
                  <td className="p-4">
                    <p className="text-sm font-[IBM_Plex_Mono] text-[#1A1918]">{item.to_email}</p>
                    {item.subject && <p className="text-xs text-[#6B6863] mt-0.5">{item.subject}</p>}
                    {item.error_message && (
                      <p className="text-[10px] text-[#8B2E2E] mt-1 font-[IBM_Plex_Mono] truncate max-w-[240px]">{item.error_message}</p>
                    )}
                    {(item.retry_count ?? 0) > 0 && (
                      <p className="text-[10px] text-[#B0AEA9] mt-1 font-[IBM_Plex_Mono]">{item.retry_count} retentativa{item.retry_count !== 1 ? 's' : ''}</p>
                    )}
                  </td>
                  <td className="p-4 text-xs text-[#6B6863] hidden md:table-cell">
                    {templateLabel[item.template ?? ''] ?? item.template ?? '—'}
                  </td>
                  <td className="p-4">
                    <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${cfg?.cls ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                      {cfg?.label ?? item.status}
                    </span>
                  </td>
                  <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden sm:table-cell">
                    {timeAgo(item.created_at)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {items.length === 0 && (
          <div className="p-12 text-center text-[#6B6863] text-sm">Fila de emails vazia.</div>
        )}
      </div>
    </div>
  )
}
