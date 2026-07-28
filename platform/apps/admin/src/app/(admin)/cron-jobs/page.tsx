import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo, formatDate } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Cron Jobs · Admin Lumen' }

/**
 * Monitor de Cron Jobs — spec: monitorar, forçar execução, ver histórico de erros.
 * Tabela esperada: cron_jobs { id, key, description, schedule, last_run_at, last_status, last_error, next_run_at, created_at }
 */
export default async function CronJobsPage() {
  const supabase = await createServerSupabase()

  const { data: jobs } = await supabase
    .from('cron_jobs')
    .select('*')
    .order('next_run_at', { ascending: true })

  type CronJob = {
    id: string
    key: string
    description: string | null
    schedule: string
    last_run_at: string | null
    last_status: 'success' | 'error' | 'running' | null
    last_error: string | null
    next_run_at: string | null
    created_at: string
  }

  const all = (jobs ?? []) as unknown as CronJob[]

  const statusConfig: Record<string, { label: string; cls: string }> = {
    success: { label: 'OK', cls: 'bg-[#3D6B5A]/10 text-[#3D6B5A]' },
    error: { label: 'Erro', cls: 'bg-[#8B2E2E]/10 text-[#8B2E2E]' },
    running: { label: 'Executando', cls: 'bg-[#8B5E2E]/10 text-[#8B5E2E]' },
  }

  const errored = all.filter((j) => j.last_status === 'error')

  // Verifica se job está atrasado (next_run_at no passado e status não é running)
  const isLate = (job: CronJob): boolean => {
    if (!job.next_run_at) return false
    if (job.last_status === 'running') return false
    return new Date(job.next_run_at) < new Date()
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Cron Jobs</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          {all.length} jobs registrados · {errored.length} com erro
        </p>
      </div>

      {/* Alertas de erro */}
      {errored.length > 0 && (
        <div className="bg-[#8B2E2E]/10 border border-[#8B2E2E]/30 rounded-2xl p-4 mb-6">
          <p className="text-sm font-medium text-[#8B2E2E] mb-3">
            {errored.length} job{errored.length !== 1 ? 's' : ''} com falha na última execução
          </p>
          <div className="space-y-2">
            {errored.map((job) => (
              <div key={job.id} className="bg-white/60 rounded-xl p-3">
                <p className="font-[IBM_Plex_Mono] text-xs font-medium text-[#1A1918]">{job.key}</p>
                {job.last_error && (
                  <p className="text-xs text-[#8B2E2E] mt-1 font-[IBM_Plex_Mono] break-all">{job.last_error}</p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* KPIs */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        {[
          { value: all.filter((j) => j.last_status === 'success').length, label: 'Executando OK', color: '#3D6B5A' },
          { value: errored.length, label: 'Com erro', color: errored.length > 0 ? '#8B2E2E' : '#B0AEA9' },
          { value: all.filter(isLate).length, label: 'Atrasados', color: all.filter(isLate).length > 0 ? '#8B5E2E' : '#B0AEA9' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-4">
            <p className="font-[Fraunces] text-3xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Tabela de jobs */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[#ECEAE9]">
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Job</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden md:table-cell">Schedule</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Última execução</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Status</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden lg:table-cell">Próxima execução</th>
            </tr>
          </thead>
          <tbody>
            {all.map((job) => {
              const late = isLate(job)
              return (
                <tr key={job.id} className={`border-b border-[#ECEAE9]/50 transition-colors ${late ? 'bg-[#8B5E2E]/5' : 'hover:bg-[#FAF9F7]'}`}>
                  <td className="p-4">
                    <p className="font-[IBM_Plex_Mono] text-xs font-medium text-[#1A1918]">{job.key}</p>
                    {job.description && (
                      <p className="text-xs text-[#6B6863] mt-0.5">{job.description}</p>
                    )}
                    {job.last_error && (
                      <p className="text-[10px] text-[#8B2E2E] mt-1 font-[IBM_Plex_Mono] truncate max-w-[200px]">{job.last_error}</p>
                    )}
                  </td>
                  <td className="p-4 hidden md:table-cell">
                    <span className="font-[IBM_Plex_Mono] text-xs text-[#6B6863]">{job.schedule}</span>
                  </td>
                  <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono]">
                    {job.last_run_at ? timeAgo(job.last_run_at) : '—'}
                  </td>
                  <td className="p-4">
                    {job.last_status ? (
                      <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${statusConfig[job.last_status]?.cls ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                        {statusConfig[job.last_status]?.label ?? job.last_status}
                      </span>
                    ) : (
                      <span className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">Nunca executou</span>
                    )}
                  </td>
                  <td className="p-4 text-xs font-[IBM_Plex_Mono] hidden lg:table-cell">
                    {job.next_run_at ? (
                      <span className={late ? 'text-[#8B5E2E] font-medium' : 'text-[#6B6863]'}>
                        {formatDate(job.next_run_at)}{late ? ' ⚠️' : ''}
                      </span>
                    ) : '—'}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {all.length === 0 && (
          <div className="p-12 text-center text-[#6B6863] text-sm">
            Nenhum cron job registrado.
          </div>
        )}
      </div>
    </div>
  )
}
