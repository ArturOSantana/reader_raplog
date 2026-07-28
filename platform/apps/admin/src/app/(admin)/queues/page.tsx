/**
 * /admin/queues — Queue Monitor unificado (spec §5 + §24)
 *
 * Exibe estado de todas as filas canônicas da plataforma Lumen.
 * Dados: tabela `queue_jobs` no Supabase (schema simplificado).
 *
 * Filas: email, push, google_books, analytics, reviews,
 *        billing, lgpd, recommendations, media, ai
 */

import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Queue Monitor · Admin Lumen' }

// Filas canônicas (espelho de QueueNames no Flutter)
const QUEUE_NAMES = [
  { id: 'queue:email',           label: 'Email',          color: '#3D6B5A' },
  { id: 'queue:push',            label: 'Push',           color: '#3D6B5A' },
  { id: 'queue:google_books',    label: 'Google Books',   color: '#5A6B3D' },
  { id: 'queue:analytics',       label: 'Analytics',      color: '#3D5A6B' },
  { id: 'queue:reviews',         label: 'Reviews',        color: '#3D5A6B' },
  { id: 'queue:billing',         label: 'Billing',        color: '#8B5E2E' },
  { id: 'queue:lgpd',            label: 'LGPD',           color: '#8B2E2E' },
  { id: 'queue:recommendations', label: 'Recomendações',  color: '#6B3D6B' },
  { id: 'queue:media',           label: 'Mídia',          color: '#2E5B8B' },
  { id: 'queue:ai',              label: 'IA',             color: '#8B2E5B' },
] as const

type QueueId = typeof QUEUE_NAMES[number]['id']

interface QueueJob {
  id: string
  queue: string
  status: 'pending' | 'running' | 'failed' | 'dead_letter' | 'done'
  attempts: number
  max_retries: number
  error: string | null
  created_at: string
  started_at: string | null
  completed_at: string | null
}

interface QueueSummary {
  queueId: QueueId
  label: string
  color: string
  pending: number
  running: number
  failed: number
  dead_letter: number
  total: number
  lastError: string | null
  lastActivity: string | null
}

export default async function QueuesPage() {
  const supabase = await createServerSupabase()

  // Busca os últimos 200 jobs para calcular métricas client-side
  const { data: jobs } = await supabase
    .from('queue_jobs')
    .select('id, queue, status, attempts, max_retries, error, created_at, started_at, completed_at')
    .order('created_at', { ascending: false })
    .limit(200)

  const allJobs = (jobs ?? []) as QueueJob[]

  // Agrupa por fila
  const summaries: QueueSummary[] = QUEUE_NAMES.map(({ id, label, color }) => {
    const qJobs = allJobs.filter((j) => j.queue === id)
    const lastJob = qJobs[0]
    return {
      queueId: id,
      label,
      color,
      pending:    qJobs.filter((j) => j.status === 'pending').length,
      running:    qJobs.filter((j) => j.status === 'running').length,
      failed:     qJobs.filter((j) => j.status === 'failed').length,
      dead_letter: qJobs.filter((j) => j.status === 'dead_letter').length,
      total:      qJobs.length,
      lastError:  qJobs.find((j) => j.error)?.error ?? null,
      lastActivity: lastJob?.created_at ?? null,
    }
  })

  const totalPending    = summaries.reduce((a, s) => a + s.pending, 0)
  const totalFailed     = summaries.reduce((a, s) => a + s.failed, 0)
  const totalDeadLetter = summaries.reduce((a, s) => a + s.dead_letter, 0)
  const totalRunning    = summaries.reduce((a, s) => a + s.running, 0)

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6C757D] uppercase tracking-widest mb-1">Operações</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1A2E]">Queue Monitor</h1>
        <p className="text-sm text-[#6C757D] mt-1">
          Todas as filas canônicas da plataforma — tamanho, erros, dead-letter e atividade.
        </p>
      </div>

      {/* KPIs globais */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { value: totalPending,    label: 'Pendentes',   color: '#8B5E2E' },
          { value: totalRunning,    label: 'Em execução', color: '#3D6B5A' },
          { value: totalFailed,     label: 'Com falha',   color: totalFailed > 0 ? '#8B2E2E' : '#ADB5BD' },
          { value: totalDeadLetter, label: 'Dead-letter', color: totalDeadLetter > 0 ? '#8B2E2E' : '#ADB5BD' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#E9ECEF] rounded-2xl p-5">
            <p className="font-[Fraunces] text-2xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6C757D] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Alerta de dead-letter */}
      {totalDeadLetter > 0 && (
        <div className="bg-[#8B2E2E]/10 border border-[#8B2E2E]/30 text-[#8B2E2E] rounded-xl px-4 py-3 text-sm font-medium mb-6">
          {totalDeadLetter} job{totalDeadLetter !== 1 ? 's' : ''} em dead-letter — requer atenção manual
        </div>
      )}

      {/* Grade de filas */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
        {summaries.map((q) => (
          <div key={q.queueId} className="bg-white border border-[#E9ECEF] rounded-2xl p-5">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <span
                  className="w-2 h-2 rounded-full"
                  style={{ backgroundColor: q.color }}
                />
                <p className="font-medium text-[#1A1A2E] text-sm">{q.label}</p>
                <span className="font-[IBM_Plex_Mono] text-[10px] text-[#ADB5BD]">{q.queueId}</span>
              </div>
              {q.dead_letter > 0 && (
                <span className="text-[10px] font-[IBM_Plex_Mono] bg-[#8B2E2E]/10 text-[#8B2E2E] px-2 py-0.5 rounded-full">
                  {q.dead_letter} DL
                </span>
              )}
            </div>

            <div className="grid grid-cols-4 gap-2 text-center">
              {[
                { count: q.pending,    label: 'Pendente',    dimmed: q.pending === 0 },
                { count: q.running,    label: 'Rodando',     dimmed: q.running === 0 },
                { count: q.failed,     label: 'Falhou',      dimmed: q.failed === 0 },
                { count: q.dead_letter, label: 'Dead-letter', dimmed: q.dead_letter === 0 },
              ].map(({ count, label, dimmed }) => (
                <div key={label}>
                  <p
                    className="font-[Fraunces] text-xl font-bold"
                    style={{ color: dimmed ? '#ADB5BD' : count > 0 && (label === 'Falhou' || label === 'Dead-letter') ? '#8B2E2E' : '#1A1A2E' }}
                  >
                    {count}
                  </p>
                  <p className="text-[10px] font-[IBM_Plex_Mono] text-[#ADB5BD]">{label}</p>
                </div>
              ))}
            </div>

            {q.lastError && (
              <p className="mt-3 text-[10px] font-[IBM_Plex_Mono] text-[#8B2E2E] bg-[#8B2E2E]/5 rounded px-2 py-1 truncate">
                {q.lastError}
              </p>
            )}

            {q.lastActivity && (
              <p className="mt-2 text-[10px] font-[IBM_Plex_Mono] text-[#ADB5BD]">
                última atividade: {timeAgo(q.lastActivity)}
              </p>
            )}
          </div>
        ))}
      </div>

      {/* Jobs recentes (últimos 30) */}
      {allJobs.length > 0 && (
        <div className="bg-white border border-[#E9ECEF] rounded-2xl overflow-hidden">
          <div className="p-5 border-b border-[#E9ECEF]">
            <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1A2E]">Jobs recentes</h2>
          </div>
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[#E9ECEF]">
                <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6C757D] text-xs">Fila</th>
                <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6C757D] text-xs">Status</th>
                <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6C757D] text-xs hidden sm:table-cell">Tentativas</th>
                <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6C757D] text-xs hidden md:table-cell">Criado</th>
              </tr>
            </thead>
            <tbody>
              {allJobs.slice(0, 30).map((job) => {
                const queueMeta = QUEUE_NAMES.find((q) => q.id === job.queue)
                const statusCls: Record<string, string> = {
                  pending:    'bg-[#8B5E2E]/10 text-[#8B5E2E]',
                  running:    'bg-[#3D6B5A]/10 text-[#3D6B5A]',
                  done:       'bg-[#ADB5BD]/10 text-[#6C757D]',
                  failed:     'bg-[#8B2E2E]/10 text-[#8B2E2E]',
                  dead_letter:'bg-[#8B2E2E]/20 text-[#8B2E2E] font-bold',
                }
                return (
                  <tr key={job.id} className="border-b border-[#E9ECEF]/50 hover:bg-[#F8F9FA] transition-colors">
                    <td className="p-4">
                      <p className="text-xs font-[IBM_Plex_Mono] text-[#1A1A2E]">
                        {queueMeta?.label ?? job.queue}
                      </p>
                      {job.error && (
                        <p className="text-[10px] text-[#8B2E2E] mt-0.5 truncate max-w-[200px]">{job.error}</p>
                      )}
                    </td>
                    <td className="p-4">
                      <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${statusCls[job.status] ?? 'bg-[#F1F3F5] text-[#ADB5BD]'}`}>
                        {job.status}
                      </span>
                    </td>
                    <td className="p-4 text-xs font-[IBM_Plex_Mono] text-[#6C757D] hidden sm:table-cell">
                      {job.attempts}/{job.max_retries}
                    </td>
                    <td className="p-4 text-xs font-[IBM_Plex_Mono] text-[#6C757D] hidden md:table-cell">
                      {timeAgo(job.created_at)}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}

      {allJobs.length === 0 && (
        <div className="bg-white border border-[#E9ECEF] rounded-2xl p-12 text-center">
          <p className="font-[Fraunces] text-lg text-[#1A1A2E] mb-1">Nenhum job registrado</p>
          <p className="text-sm text-[#6C757D]">
            Jobs aparecem aqui quando a tabela <code className="font-[IBM_Plex_Mono] bg-[#F1F3F5] px-1 rounded">queue_jobs</code> for populada.
          </p>
        </div>
      )}
    </div>
  )
}
