import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Feed · Lumen Web' }

/**
 * Feed social do usuário autenticado.
 * Exibe atividade de pessoas que o usuário segue:
 * - Livros adicionados / finalizados
 * - Reviews publicadas
 * - Conquistas desbloqueadas
 * - Sessões de leitura (se perfil público)
 *
 * Spec: funcionalidades sociais nunca são obrigatórias — o feed é opt-in.
 */
export default async function FeedPage() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // Busca quem o usuário segue
  const { data: following } = await supabase
    .from('follows')
    .select('following_id')
    .eq('follower_id', user.id)

  const followingIds = (following ?? []).map((f) => f.following_id as string)

  // Busca atividade recente das pessoas seguidas (últimos 30 dias)
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  type FeedEvent = {
    id: string
    type: 'book_finished' | 'review_created' | 'achievement_unlocked' | 'book_started'
    user_id: string
    payload: Record<string, unknown>
    created_at: string
    profile: { username: string; avatar_url: string | null } | null
  }

  let feedItems: FeedEvent[] = []

  if (followingIds.length > 0) {
    const { data: events } = await supabase
      .from('feed_events')
      .select('id, type, user_id, payload, created_at, profile:profiles!user_id(username, avatar_url)')
      .in('user_id', followingIds)
      .gte('created_at', thirtyDaysAgo.toISOString())
      .order('created_at', { ascending: false })
      .limit(60)

    feedItems = (events ?? []) as unknown as FeedEvent[]
  }

  const eventLabel: Record<string, string> = {
    book_finished: 'terminou de ler',
    book_started: 'começou a ler',
    review_created: 'avaliou',
    achievement_unlocked: 'desbloqueou conquista',
  }

  const eventIcon: Record<string, string> = {
    book_finished: '✅',
    book_started: '📖',
    review_created: '⭐',
    achievement_unlocked: '🏆',
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="mb-8">
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Feed</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Atividade de quem você segue · últimos 30 dias
        </p>
      </div>

      {/* Sem ninguém seguindo */}
      {followingIds.length === 0 && (
        <div className="text-center py-24 text-[#6B6863]">
          <p className="font-[Fraunces] text-xl mb-2">Feed vazio</p>
          <p className="text-sm">
            Você ainda não segue ninguém.
            <br />
            Explore perfis e clubes pelo app para descobrir leitores.
          </p>
        </div>
      )}

      {/* Seguindo alguém mas sem atividade */}
      {followingIds.length > 0 && feedItems.length === 0 && (
        <div className="text-center py-24 text-[#6B6863]">
          <p className="font-[Fraunces] text-xl mb-2">Nenhuma atividade recente</p>
          <p className="text-sm">
            Nenhum dos leitores que você segue teve atividade nos últimos 30 dias.
          </p>
        </div>
      )}

      {/* Feed de eventos */}
      <div className="space-y-3">
        {feedItems.map((event) => (
          <div
            key={event.id}
            className="bg-[#FAF9F7] border border-[#ECEAE9] rounded-2xl p-4 flex items-start gap-4"
          >
            {/* Avatar */}
            <div className="w-9 h-9 rounded-full bg-[#E8F0EE] flex items-center justify-center text-sm font-[Fraunces] font-bold text-[#3D6B5A] flex-shrink-0">
              {event.profile?.username?.[0]?.toUpperCase() ?? '?'}
            </div>

            {/* Conteúdo */}
            <div className="flex-1 min-w-0">
              <div className="flex items-start justify-between gap-2">
                <p className="text-sm text-[#1A1918]">
                  <span className="font-medium">@{event.profile?.username ?? '?'}</span>
                  {' '}
                  <span className="text-[#6B6863]">{eventLabel[event.type] ?? event.type}</span>
                  {event.payload?.book_title != null && (
                    <>
                      {' '}
                      <span className="font-medium">{String(event.payload.book_title)}</span>
                    </>
                  )}
                  {event.payload?.achievement_name != null && (
                    <>
                      {' '}
                      <span className="font-medium">&ldquo;{String(event.payload.achievement_name)}&rdquo;</span>
                    </>
                  )}
                </p>
                <span className="text-xl flex-shrink-0">{eventIcon[event.type] ?? '•'}</span>
              </div>

              {/* Rating inline para reviews */}
              {event.type === 'review_created' && event.payload?.rating != null && (
                <p className="text-sm text-[#3D6B5A] mt-1">
                  {'★'.repeat(Number(event.payload.rating))}{'☆'.repeat(5 - Number(event.payload.rating))}
                </p>
              )}

              {/* Trecho da review */}
              {event.type === 'review_created' && event.payload?.content != null && (
                <p className="text-sm text-[#6B6863] mt-1 line-clamp-2 leading-relaxed">
                  &ldquo;{String(event.payload.content)}&rdquo;
                </p>
              )}

              <p className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] mt-2">
                {timeAgo(event.created_at)}
              </p>
            </div>
          </div>
        ))}
      </div>

      {/* Rodapé discreto */}
      {feedItems.length > 0 && (
        <p className="text-center text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-8">
          Mostrando atividade dos últimos 30 dias
        </p>
      )}
    </div>
  )
}
