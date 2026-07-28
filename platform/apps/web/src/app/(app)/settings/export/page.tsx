import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Exportar dados · Lumen Web' }

/**
 * Exportação de dados (LGPD - Art. 15 - Portabilidade).
 * Spec §11: exportação completa em até 15 dias — JSON + CSV.
 *
 * Esta página permite ao usuário:
 * 1. Ver solicitações de exportação anteriores
 * 2. Criar nova solicitação de exportação
 *
 * O processamento real ocorre em uma Edge Function assíncrona.
 */
export default async function ExportPage() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // Busca solicitações anteriores de exportação deste usuário
  const { data: requests } = await supabase
    .from('lgpd_requests')
    .select('id, type, status, created_at, resolved_at')
    .eq('user_id', user.id)
    .eq('type', 'export')
    .order('created_at', { ascending: false })
    .limit(10)

  type LgpdRequest = {
    id: string
    type: string
    status: 'pending' | 'processing' | 'completed' | 'failed'
    created_at: string
    resolved_at: string | null
  }

  const exportRequests = (requests ?? []) as unknown as LgpdRequest[]

  const hasPending = exportRequests.some((r) => ['pending', 'processing'].includes(r.status))

  const statusConfig: Record<string, { label: string; cls: string }> = {
    pending: { label: 'Aguardando processamento', cls: 'text-[#8B5E2E] bg-[#8B5E2E]/10' },
    processing: { label: 'Processando…', cls: 'text-[#8B5E2E] bg-[#8B5E2E]/10' },
    completed: { label: 'Pronto para download', cls: 'text-[#3D6B5A] bg-[#3D6B5A]/10' },
    failed: { label: 'Falhou — contate o suporte', cls: 'text-[#8B2E2E] bg-[#8B2E2E]/10' },
  }

  // Dados que serão incluídos na exportação
  const exportContents = [
    { icon: '📚', label: 'Biblioteca completa', desc: 'Todos os livros, status, datas e avaliações' },
    { icon: '⏱', label: 'Sessões de leitura', desc: 'Histórico completo de sessões com duração e páginas' },
    { icon: '✍️', label: 'Notas e destaques', desc: 'Todas as anotações e trechos marcados' },
    { icon: '🏆', label: 'Conquistas', desc: 'Histórico de conquistas desbloqueadas' },
    { icon: '🎯', label: 'Metas', desc: 'Metas criadas e progresso' },
    { icon: '📋', label: 'Perfil', desc: 'Dados do perfil público e configurações' },
  ]

  return (
    <div className="p-6 max-w-2xl mx-auto">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-6">
        <Link href="/settings" className="hover:text-[#3D6B5A]">Configurações</Link>
        <span>/</span>
        <span className="text-[#1A1918]">Exportar dados</span>
      </div>

      <div className="mb-8">
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Exportar meus dados</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Portabilidade de dados — LGPD Art. 18, V
        </p>
      </div>

      {/* O que está incluído */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-5">
          O que está incluído
        </h2>
        <div className="space-y-3">
          {exportContents.map(({ icon, label, desc }) => (
            <div key={label} className="flex items-start gap-3">
              <span className="text-xl">{icon}</span>
              <div>
                <p className="text-sm font-medium text-[#1A1918]">{label}</p>
                <p className="text-xs text-[#6B6863]">{desc}</p>
              </div>
            </div>
          ))}
        </div>
        <div className="mt-5 pt-4 border-t border-[#F2F1EF]">
          <p className="text-xs text-[#6B6863]">
            Formato: <span className="font-[IBM_Plex_Mono] text-[#1A1918]">JSON + CSV</span> · 
            Prazo de entrega: <span className="font-[IBM_Plex_Mono] text-[#1A1918]">até 15 dias</span> · 
            Entregue via email cadastrado
          </p>
        </div>
      </section>

      {/* Solicitação */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
          Solicitar exportação
        </h2>

        {hasPending ? (
          <div className="bg-[#8B5E2E]/10 border border-[#8B5E2E]/30 rounded-xl p-4">
            <p className="text-sm text-[#8B5E2E] font-medium">
              Você já tem uma solicitação em andamento.
            </p>
            <p className="text-xs text-[#6B6863] mt-1">
              Aguarde o processamento antes de solicitar novamente.
            </p>
          </div>
        ) : (
          <form action="/api/lgpd/export" method="POST">
            <input type="hidden" name="user_id" value={user.id} />
            <p className="text-sm text-[#6B6863] mb-4">
              Ao solicitar, você receberá um email com o link para download dentro do prazo legal de 15 dias.
            </p>
            <button
              type="submit"
              className="bg-[#1A1918] text-[#FAF9F7] rounded-xl px-6 py-2.5 text-sm font-medium hover:bg-[#2C2B29] transition-colors"
            >
              Solicitar exportação completa
            </button>
          </form>
        )}
      </section>

      {/* Histórico de solicitações */}
      {exportRequests.length > 0 && (
        <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
            Solicitações anteriores
          </h2>
          <div className="space-y-3">
            {exportRequests.map((req) => {
              const config = statusConfig[req.status]
              return (
                <div key={req.id} className="flex items-center justify-between py-2 border-b border-[#F2F1EF] last:border-0">
                  <div>
                    <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${config?.cls ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                      {config?.label ?? req.status}
                    </span>
                    {req.status === 'completed' && req.resolved_at && (
                      <p className="text-xs text-[#6B6863] mt-1">Processado {timeAgo(req.resolved_at)}</p>
                    )}
                  </div>
                  <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">
                    {timeAgo(req.created_at)}
                  </p>
                </div>
              )
            })}
          </div>
        </section>
      )}
    </div>
  )
}
