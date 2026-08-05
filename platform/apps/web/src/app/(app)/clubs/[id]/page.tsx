import { redirect, notFound } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo, clubCategoryLabel } from '@lumen/ui'
import { getDominantColor, rgbToCss } from '@/lib/dominant-color'
import type { Metadata } from 'next'

interface PageProps {
  params: Promise<{ id: string }>
  searchParams: Promise<{ action?: string }>
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params
  return { title: `Clube · Lumen` }
}

export default async function ClubDetailPage({ params, searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { id } = await params
  const { action } = await searchParams

  // ── Busca o clube (por slug ou id) ───────────────────────────────────────
  const { data: club } = await supabase
    .from('book_clubs')
    .select(`
      id,
      slug,
      name,
      description,
      cover_url,
      category,
      status,
      current_book_title,
      current_book_author,
      current_book_cover_url,
      created_at,
      owner_id
    `)
    .or(`slug.eq.${id},id.eq.${id}`)
    .single()

  if (!club) notFound()

  // ── Membership do usuário atual ───────────────────────────────────────────
  const { data: myMembership } = await supabase
    .from('book_club_members')
    .select('role, joined_at')
    .eq('club_id', club.id)
    .eq('user_id', user.id)
    .single()

  if (!myMembership) {
    // Não é membro deste clube
    redirect('/clubs')
  }

  const isOwnerOrAdmin = myMembership.role === 'owner' || myMembership.role === 'admin'

  // ── Lista de membros ──────────────────────────────────────────────────────
  const { data: members } = await supabase
    .from('book_club_members')
    .select(`
      user_id,
      role,
      joined_at,
      profile:profiles (
        id,
        username,
        full_name,
        avatar_url
      )
    `)
    .eq('club_id', club.id)
    .order('joined_at', { ascending: true })

  // ── Checkins recentes ─────────────────────────────────────────────────────
  const { data: recentCheckins } = await supabase
    .from('book_club_checkins')
    .select(`
      id,
      user_id,
      pages_read,
      note,
      created_at,
      profile:profiles ( username, full_name, avatar_url )
    `)
    .eq('club_id', club.id)
    .order('created_at', { ascending: false })
    .limit(10)

  const memberCount = members?.length ?? 0

  const roleBadge = (role: string) => {
    if (role === 'owner') return (
      <span className="text-[10px] font-[IBM_Plex_Mono] bg-[#3D6B5A]/10 text-[#3D6B5A] px-1.5 py-0.5 rounded uppercase">
        Dono
      </span>
    )
    if (role === 'admin') return (
      <span className="text-[10px] font-[IBM_Plex_Mono] bg-orange-100 text-orange-700 px-1.5 py-0.5 rounded uppercase">
        Admin
      </span>
    )
    return null
  }

  const feedbackMsg: Record<string, string> = {
    left: 'Você saiu do clube.',
    removed: 'Membro removido.',
  }

  // ── Cor dominante da capa do livro atual ────────────────────────────────
  // Extraída server-side (sharp). Aplicada como wash 2-3% por trás do grain.
  // Telas pessoais (Home, Perfil) ficam sem tint — só o clube tem identidade.
  const dominantColor = club.current_book_cover_url
    ? await getDominantColor(club.current_book_cover_url)
    : null
  const colorCss = dominantColor ? rgbToCss(dominantColor) : null

  return (
    <div
      className="p-6 max-w-4xl mx-auto relative"
      style={
        colorCss
          ? ({
              '--club-tint': colorCss,
            } as React.CSSProperties)
          : undefined
      }
    >
      {/* Color wash — camada antes do grain (z-index 9999).
          2 % de opacidade: dá personalidade sem inventar decoração.
          A cor vem do próprio livro que o clube está lendo. */}
      {colorCss && (
        <div
          aria-hidden
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: `rgba(var(--club-tint), 0.025)`,
            pointerEvents: 'none',
            zIndex: 10,
          }}
        />
      )}
      {/* Feedback de ação */}
      {action && feedbackMsg[action] && (
        <div className="mb-6 bg-[#3D6B5A]/10 border border-[#3D6B5A]/20 text-[#3D6B5A] text-sm px-4 py-3 rounded-xl font-[IBM_Plex_Mono]">
          {feedbackMsg[action]}
        </div>
      )}

      {/* Cabeçalho do clube */}
      <div className="mb-8 flex items-start gap-5">
        {club.cover_url ? (
          <Image
            src={club.cover_url}
            alt={club.name}
            width={64}
            height={64}
            className="rounded-xl object-cover flex-shrink-0"
          />
        ) : (
          <div className="w-16 h-16 bg-[#E8F0EE] rounded-xl flex items-center justify-center flex-shrink-0">
            <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-2xl">{club.name[0]}</span>
          </div>
        )}
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">
                {clubCategoryLabel(club.category)} · {memberCount} membro{memberCount !== 1 ? 's' : ''}
              </p>
              <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">{club.name}</h1>
            </div>
            <div className="flex items-center gap-2 flex-shrink-0">
              {roleBadge(myMembership.role)}
            </div>
          </div>
          {club.description && (
            <p className="text-sm text-[#6B6863] mt-2 leading-relaxed">{club.description}</p>
          )}
        </div>
      </div>

      {/* Livro atual */}
      {club.current_book_title && (
        <div className="bg-[#F2F1EF] rounded-2xl p-4 mb-8 flex gap-4 items-center">
          {club.current_book_cover_url && (
            <Image
              src={club.current_book_cover_url}
              alt={club.current_book_title}
              width={48}
              height={64}
              className="rounded-lg object-cover flex-shrink-0"
            />
          )}
          <div>
            <p className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A] uppercase tracking-wider mb-1">
              Lendo agora
            </p>
            <p className="font-[Fraunces] font-semibold text-[#1A1918]">{club.current_book_title}</p>
            {club.current_book_author && (
              <p className="text-xs text-[#6B6863]">{club.current_book_author}</p>
            )}
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Membros */}
        <div className="lg:col-span-2">
          <div className="bg-[#FAF9F7] border border-[#ECEAE9] rounded-2xl overflow-hidden">
            <div className="px-5 py-3 border-b border-[#ECEAE9] flex items-center justify-between">
              <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest">
                Membros ({memberCount})
              </p>
            </div>
            <div className="divide-y divide-[#ECEAE9]">
              {members?.map((m) => {
                const profile = Array.isArray(m.profile) ? m.profile[0] : m.profile
                const isMe = m.user_id === user.id
                const canRemove = isOwnerOrAdmin && !isMe && m.role !== 'owner'
                return (
                  <div key={m.user_id} className="px-5 py-3 flex items-center justify-between gap-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-8 h-8 rounded-full bg-[#E8F0EE] flex items-center justify-center text-xs font-medium text-[#3D6B5A] flex-shrink-0">
                        {(profile?.username ?? profile?.full_name ?? '?')[0]?.toUpperCase()}
                      </div>
                      <div className="min-w-0">
                        <p className="text-sm text-[#1A1918] font-medium truncate">
                          @{profile?.username ?? '—'}
                          {isMe && <span className="text-[#B0AEA9] font-normal ml-1">(você)</span>}
                        </p>
                        {m.joined_at && (
                          <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">
                            entrou {timeAgo(m.joined_at)}
                          </p>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      {roleBadge(m.role)}
                      {canRemove && (
                        <form action={`/api/clubs/${club.id}/members/${m.user_id}`} method="POST">
                          <input type="hidden" name="_method" value="DELETE" />
                          <button
                            type="submit"
                            className="text-xs text-[#8B2E2E] hover:underline font-[IBM_Plex_Mono]"
                          >
                            Remover
                          </button>
                        </form>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>

            {/* Sair do clube (apenas membros não-dono) */}
            {myMembership.role !== 'owner' && (
              <div className="px-5 py-3 border-t border-[#ECEAE9]">
                <form action={`/api/clubs/${club.id}/leave`} method="POST">
                  <button
                    type="submit"
                    className="text-xs text-[#8B2E2E] hover:underline font-[IBM_Plex_Mono]"
                  >
                    Sair do clube
                  </button>
                </form>
              </div>
            )}
          </div>
        </div>

        {/* Checkins recentes */}
        <div>
          <div className="bg-[#FAF9F7] border border-[#ECEAE9] rounded-2xl overflow-hidden">
            <div className="px-5 py-3 border-b border-[#ECEAE9]">
              <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest">
                Atividade recente
              </p>
            </div>
            {!recentCheckins?.length ? (
              <div className="py-8 text-center">
                <p className="text-sm text-[#6B6863]">Nenhum check-in ainda</p>
              </div>
            ) : (
              <div className="divide-y divide-[#ECEAE9]">
                {recentCheckins.map((checkin) => {
                  const p = Array.isArray(checkin.profile) ? checkin.profile[0] : checkin.profile
                  return (
                    <div key={checkin.id} className="px-4 py-3">
                      <div className="flex items-center gap-2 mb-1">
                        <div className="w-5 h-5 rounded-full bg-[#E8F0EE] flex items-center justify-center text-[10px] font-medium text-[#3D6B5A] flex-shrink-0">
                          {(p?.username ?? '?')[0]?.toUpperCase()}
                        </div>
                        <p className="text-xs font-medium text-[#1A1918]">@{p?.username ?? '—'}</p>
                        <span className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono] ml-auto">
                          {checkin.created_at ? timeAgo(checkin.created_at) : '—'}
                        </span>
                      </div>
                      {checkin.pages_read != null && (
                        <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono]">
                          {checkin.pages_read} pág.
                        </p>
                      )}
                      {checkin.note && (
                        <p className="text-xs text-[#6B6863] mt-1 italic line-clamp-2">
                          &ldquo;{checkin.note}&rdquo;
                        </p>
                      )}
                    </div>
                  )
                })}
              </div>
            )}
          </div>

          {/* Info */}
          <div className="mt-4 bg-[#FAF9F7] border border-[#ECEAE9] rounded-2xl p-4">
            <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-3">
              Sobre o clube
            </p>
            <dl className="space-y-2 text-xs">
              <div className="flex justify-between">
                <dt className="text-[#B0AEA9] font-[IBM_Plex_Mono]">Categoria</dt>
                <dd className="text-[#1A1918]">{clubCategoryLabel(club.category)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-[#B0AEA9] font-[IBM_Plex_Mono]">Status</dt>
                <dd className="text-[#1A1918] capitalize">{club.status ?? 'Ativo'}</dd>
              </div>
              {club.created_at && (
                <div className="flex justify-between">
                  <dt className="text-[#B0AEA9] font-[IBM_Plex_Mono]">Criado</dt>
                  <dd className="text-[#1A1918]">
                    {new Date(club.created_at).toLocaleDateString('pt-BR')}
                  </dd>
                </div>
              )}
              <div className="flex justify-between">
                <dt className="text-[#B0AEA9] font-[IBM_Plex_Mono]">Seu papel</dt>
                <dd className="text-[#3D6B5A] font-medium capitalize">{myMembership.role}</dd>
              </div>
            </dl>
          </div>
        </div>
      </div>

      <div className="mt-6">
        <Link href="/clubs" className="text-sm text-[#6B6863] hover:text-[#1A1918] font-[IBM_Plex_Mono]">
          ← Voltar para Clubes
        </Link>
      </div>
    </div>
  )
}
