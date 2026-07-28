import { createServerSupabase } from '@lumen/supabase/server'
import { notFound } from 'next/navigation'
import { clubCategoryLabel, timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'

interface PageProps {
  params: Promise<{ id: string }>
}

export const revalidate = 3600

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params
  const supabase = await createServerSupabase()

  const { data: club } = await supabase
    .from('book_clubs')
    .select('name, description, cover_url, category')
    .or(`slug.eq.${id},id.eq.${id}`)
    .single()

  if (!club) return { title: 'Clube não encontrado · Lumen' }

  return {
    title: `${club.name} — Clube de Leitura`,
    description: club.description
      ? club.description.slice(0, 155)
      : `Participe do clube "${club.name}" na plataforma Lumen e leia em comunidade.`,
    openGraph: {
      title: club.name,
      description: club.description?.slice(0, 155),
      images: club.cover_url ? [{ url: club.cover_url }] : [],
    },
  }
}

export default async function PublicClubPage({ params }: PageProps) {
  const { id } = await params
  const supabase = await createServerSupabase()

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
      created_at
    `)
    .or(`slug.eq.${id},id.eq.${id}`)
    .single()

  if (!club) notFound()
  // Clubes encerrados ou privados não são indexáveis
  if (club.status === 'closed' || club.status === 'archived') notFound()

  // Contagem de membros
  const { count: memberCount } = await supabase
    .from('book_club_members')
    .select('*', { count: 'exact', head: true })
    .eq('club_id', club.id)

  // Check-ins recentes públicos
  const { data: recentCheckins } = await supabase
    .from('book_club_checkins')
    .select(`
      id,
      pages_read,
      note,
      created_at,
      profile:profiles ( username, full_name )
    `)
    .eq('club_id', club.id)
    .order('created_at', { ascending: false })
    .limit(8)

  // JSON-LD schema.org/BookClub (usando Organization como tipo mais próximo)
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: club.name,
    description: club.description,
    image: club.cover_url,
    url: `https://lumen.app/clubs/${club.slug ?? club.id}`,
    foundingDate: club.created_at ? club.created_at.slice(0, 10) : undefined,
    numberOfEmployees: { '@type': 'QuantitativeValue', value: memberCount ?? 0 },
  }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <main className="min-h-screen bg-[#FAF9F7]">
        <nav className="border-b border-[#ECEAE9] bg-[#FAF9F7] sticky top-0 z-50">
          <div className="max-w-5xl mx-auto px-6 h-14 flex items-center justify-between">
            <a href="/" className="font-[Fraunces] font-bold text-xl text-[#1A1918]">lumen</a>
            <div className="flex items-center gap-4">
              <a href="/clubs" className="text-sm text-[#6B6863] hover:text-[#1A1918] hidden sm:block">
                Clubes
              </a>
              <a
                href="https://app.lumen.app"
                className="text-sm text-[#6B6863] hover:text-[#1A1918]"
              >
                Entrar
              </a>
            </div>
          </div>
        </nav>

        <div className="max-w-4xl mx-auto px-6 py-12">
          {/* Cabeçalho */}
          <div className="flex flex-col sm:flex-row gap-6 items-start mb-10">
            {club.cover_url ? (
              <img
                src={club.cover_url}
                alt={club.name}
                className="w-24 h-24 rounded-2xl object-cover flex-shrink-0 shadow-sm"
              />
            ) : (
              <div className="w-24 h-24 bg-[#E8F0EE] rounded-2xl flex items-center justify-center flex-shrink-0">
                <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-3xl">{club.name[0]}</span>
              </div>
            )}

            <div className="flex-1">
              <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
                {clubCategoryLabel(club.category)} · {memberCount ?? 0} membro{memberCount !== 1 ? 's' : ''}
              </p>
              <h1 className="font-[Fraunces] text-4xl font-bold text-[#1A1918] mb-3 leading-tight">
                {club.name}
              </h1>
              {club.description && (
                <p className="text-sm text-[#6B6863] leading-relaxed max-w-xl">
                  {club.description}
                </p>
              )}
              {club.created_at && (
                <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-3">
                  Criado em {new Date(club.created_at).toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })}
                </p>
              )}
            </div>
          </div>

          {/* Livro atual */}
          {club.current_book_title && (
            <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-8 flex gap-5 items-center">
              {club.current_book_cover_url && (
                <img
                  src={club.current_book_cover_url}
                  alt={club.current_book_title}
                  className="w-14 h-20 object-cover rounded-lg flex-shrink-0 shadow-sm"
                />
              )}
              <div>
                <p className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A] uppercase tracking-wider mb-1">
                  Lendo agora
                </p>
                <p className="font-[Fraunces] text-xl font-semibold text-[#1A1918]">
                  {club.current_book_title}
                </p>
                {club.current_book_author && (
                  <p className="text-sm text-[#6B6863]">{club.current_book_author}</p>
                )}
              </div>
            </div>
          )}

          {/* Check-ins recentes */}
          {recentCheckins && recentCheckins.length > 0 && (
            <section className="mb-10">
              <h2 className="font-[Fraunces] text-2xl font-bold text-[#1A1918] mb-5">
                Atividade recente
              </h2>
              <div className="space-y-3">
                {recentCheckins.map((checkin) => {
                  const p = Array.isArray(checkin.profile) ? checkin.profile[0] : checkin.profile
                  return (
                    <div
                      key={checkin.id}
                      className="bg-white border border-[#ECEAE9] rounded-2xl p-4 flex items-start gap-3"
                    >
                      <div className="w-8 h-8 rounded-full bg-[#E8F0EE] flex items-center justify-center text-xs font-medium text-[#3D6B5A] flex-shrink-0 mt-0.5">
                        {(p?.username ?? '?')[0]?.toUpperCase()}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 justify-between">
                          <p className="text-sm font-medium text-[#1A1918]">
                            @{p?.username ?? '—'}
                          </p>
                          <span className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">
                            {checkin.created_at ? timeAgo(checkin.created_at) : '—'}
                          </span>
                        </div>
                        <div className="flex items-center gap-3 mt-1">
                          {checkin.pages_read != null && (
                            <span className="text-xs font-[IBM_Plex_Mono] text-[#3D6B5A] bg-[#3D6B5A]/5 px-2 py-0.5 rounded">
                              {checkin.pages_read} pág.
                            </span>
                          )}
                        </div>
                        {checkin.note && (
                          <p className="text-xs text-[#6B6863] mt-1.5 italic line-clamp-2">
                            &ldquo;{checkin.note}&rdquo;
                          </p>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            </section>
          )}

          {/* CTA */}
          <div className="bg-[#1A1918] rounded-2xl p-8 text-center text-white">
            <p className="font-[Fraunces] text-2xl font-bold mb-2">
              Quer participar deste clube?
            </p>
            <p className="text-sm text-white/70 mb-6">
              Baixe o Lumen e leia junto com {memberCount ?? 0} pessoas.
            </p>
            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <a
                href="https://app.lumen.app"
                className="inline-block bg-white text-[#1A1918] px-6 py-3 rounded-xl text-sm font-medium hover:bg-[#FAF9F7] transition-colors"
              >
                Entrar no clube
              </a>
              <a
                href="/download"
                className="inline-block border border-white/30 text-white px-6 py-3 rounded-xl text-sm font-medium hover:bg-white/10 transition-colors"
              >
                Baixar o app
              </a>
            </div>
          </div>
        </div>
      </main>
    </>
  )
}
