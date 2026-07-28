import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate } from '@lumen/ui'
import { toggleFlag, updateRollout, createFlag, deleteFlag } from './actions'
import type { FeatureFlag } from '@lumen/types'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Feature Flags · Admin Lumen' }

interface PageProps {
  searchParams: Promise<{ action?: string; error?: string }>
}

export default async function FeatureFlagsPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { action, error } = await searchParams

  const { data: flags } = await supabase
    .from('feature_flags')
    .select('*')
    .order('key', { ascending: true })

  const rolloutColor = (pct: number) => {
    if (pct === 100) return '#3D6B5A'
    if (pct >= 50) return '#5A9480'
    if (pct >= 10) return '#8B5E2E'
    return '#B0AEA9'
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="flex items-start justify-between mb-8">
        <div>
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
          <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Feature Flags</h1>
        </div>
        {/* Nova flag inline */}
        <form action={async (fd) => {
          'use server'
          const result = await createFlag(fd)
          redirect(result.error
            ? `/feature-flags?error=${encodeURIComponent(result.error)}`
            : '/feature-flags?action=created')
        }} className="flex gap-2">
          <input
            name="key"
            placeholder="nova_flag"
            className="border border-[#ECEAE9] rounded-xl px-3 py-2 text-xs font-[IBM_Plex_Mono] w-36 focus:outline-none focus:border-[#3D6B5A]"
          />
          <input
            name="description"
            placeholder="Descrição breve"
            className="border border-[#ECEAE9] rounded-xl px-3 py-2 text-xs w-40 focus:outline-none focus:border-[#3D6B5A]"
          />
          <button
            type="submit"
            className="bg-[#1A1918] text-white text-xs px-4 py-2 rounded-xl hover:bg-[#3D6B5A] transition-colors font-[IBM_Plex_Mono]"
          >
            + Criar
          </button>
        </form>
      </div>

      {/* Feedback */}
      {action === 'created' && (
        <div className="mb-5 bg-[#3D6B5A]/10 border border-[#3D6B5A]/20 text-[#3D6B5A] px-4 py-2.5 rounded-xl text-sm font-[IBM_Plex_Mono]">
          ✓ Flag criada.
        </div>
      )}
      {error && (
        <div className="mb-5 bg-red-50 border border-red-200 text-red-700 px-4 py-2.5 rounded-xl text-sm font-[IBM_Plex_Mono]">
          {error}
        </div>
      )}

      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-[#ECEAE9]">
            <tr className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] uppercase tracking-widest">
              <th className="text-left px-5 py-3">Flag</th>
              <th className="text-left px-5 py-3">Ativo</th>
              <th className="text-left px-5 py-3">Rollout</th>
              <th className="text-left px-5 py-3 hidden md:table-cell">Atualizado</th>
              <th className="px-5 py-3" />
            </tr>
          </thead>
          <tbody className="divide-y divide-[#ECEAE9]">
            {((flags ?? []) as FeatureFlag[]).map((flag) => (
              <tr key={flag.id} className="hover:bg-[#F8F9FA]">
                <td className="px-5 py-3">
                  <p className="font-[IBM_Plex_Mono] text-xs font-medium text-[#1A1918]">{flag.key}</p>
                  <p className="text-xs text-[#6B6863] mt-0.5">{flag.description}</p>
                </td>

                {/* Toggle enabled */}
                <td className="px-5 py-3">
                  <form action={async (fd) => {
                    'use server'
                    await toggleFlag(fd)
                    redirect('/feature-flags')
                  }}>
                    <input type="hidden" name="flag_id" value={flag.id} />
                    <input type="hidden" name="enabled" value={String(flag.enabled)} />
                    <button
                      type="submit"
                      className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                        flag.enabled ? 'bg-[#3D6B5A]' : 'bg-[#E9ECEF]'
                      }`}
                      title={flag.enabled ? 'Desativar' : 'Ativar'}
                    >
                      <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                        flag.enabled ? 'translate-x-4' : 'translate-x-0.5'
                      }`} />
                    </button>
                  </form>
                </td>

                {/* Rollout slider → form de update */}
                <td className="px-5 py-3">
                  <form action={async (fd) => {
                    'use server'
                    await updateRollout(fd)
                    redirect('/feature-flags')
                  }} className="flex items-center gap-2">
                    <input type="hidden" name="flag_id" value={flag.id} />
                    <input
                      type="number"
                      name="rollout_percent"
                      defaultValue={flag.rollout_percent}
                      min={0}
                      max={100}
                      className="w-16 border border-[#ECEAE9] rounded-lg px-2 py-1 text-xs font-[IBM_Plex_Mono] focus:outline-none focus:border-[#3D6B5A]"
                    />
                    <span className="text-xs font-[IBM_Plex_Mono]" style={{ color: rolloutColor(flag.rollout_percent) }}>
                      %
                    </span>
                    <button
                      type="submit"
                      className="text-[10px] font-[IBM_Plex_Mono] px-2 py-1 bg-[#F2F1EF] rounded-lg hover:bg-[#ECEAE9]"
                    >
                      OK
                    </button>
                  </form>
                </td>

                <td className="px-5 py-3 text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] hidden md:table-cell">
                  {formatDate(flag.updated_at)}
                </td>

                {/* Deletar */}
                <td className="px-5 py-3 text-right">
                  <form action={async (fd) => {
                    'use server'
                    await deleteFlag(fd)
                    redirect('/feature-flags')
                  }}>
                    <input type="hidden" name="flag_id" value={flag.id} />
                    <button
                      type="submit"
                      className="text-[10px] text-[#8B2E2E] hover:underline font-[IBM_Plex_Mono]"
                      onClick={undefined}
                    >
                      Remover
                    </button>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {(!flags || flags.length === 0) && (
          <div className="py-16 text-center text-[#6B6863]">
            <p className="font-[Fraunces] text-xl mb-2">Nenhuma flag cadastrada</p>
            <p className="text-sm">Crie a primeira usando o formulário acima.</p>
          </div>
        )}
      </div>

      {/* Rollout guide */}
      <div className="mt-6 bg-[#F8F9FA] border border-[#ECEAE9] rounded-2xl p-5">
        <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-3">
          Processo de rollout (spec §19)
        </p>
        <ol className="space-y-1 text-xs text-[#6B6863]">
          {[
            '1. Criar flag desligada (enabled: off, rollout: 0%)',
            '2. Ativar para equipe interna via target_user_ids',
            '3. Rollout 5% → monitorar métricas',
            '4. Rollout 20% → 50% → 100%',
            '5. Remover flag do código após estabilizar',
          ].map((s) => <li key={s}>{s}</li>)}
        </ol>
      </div>
    </div>
  )
}
