import { createServerSupabase } from '@lumen/supabase/server'
import { notFound } from 'next/navigation'
import type { Metadata } from 'next'

interface PageProps {
  params: Promise<{ username: string }>
}

export const revalidate = 3600 // 1 hora — perfis mudam mais do que livros

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { username } = await params
  const supabase = await createServerSupabase()

  const { data: profile } = await supabase
    .from('profiles')
    .select('username, full_name, bio, avatar_url, privacy_profile')
    .eq('username', username)
    .single()

  if (!profile || profile.privacy_profile === 'private') {
    return { title: 'Perfil · Lumen' }
  }

  return {
    title: `@${profile.username} — ${profile.full_name ?? 'Leitor'}`,
    description: profile.bio
      ? profile.bio.slice(0, 155)
      : `Perfil de leitura de @${profile.username} na plataforma Lumen.`,
    openGraph: {
      title: `@${profile.username} no Lumen`,
      description: profile.bio?.slice(0, 155),
      images: profile.avatar_url ? [{ url: profile.avatar_url }] : [],
    },
    // Perfis privados não devem ser indexados — protegido também no robots.txt
    robots: { index: true, follow: true },
  }
}

export default async function PublicProfilePage({ params }: PageProps) {
  const { username } = await params
  const supabase = await createServerSupabase()

  const { data: profile } = await supabase
    .from('profiles')
    .select(`
      id,
      username,
      full_name,
      bio,
      avatar_url,
      privacy_profile,
      privacy_library,
      privacy_stats,
      created_at
    `)
    .eq('username', username)
    .single()

  if (!profile) notFound()

  // Perfil privado — não exibir (spec §9: padrão público, mas respeitando configuração)
  if (profile.privacy_profile === 'private') notFound()

  // ── Estatísticas públicas (se configurado) ────────────────────────────────
  let stats: { total_sessions: number; total_minutes: number; total_books_finished: number } | null = null

  if (profile.privacy_stats !== 'private') {
    const [{ count: sessions }, { data: minutesData }, { count: booksFinished }] = await Promise.all([
      supabase
        .from('reading_sessions')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', profile.id),
      supabase
        .from('reading_sessions')
        .select('duration_minutes')
        .eq('user_id', profile.id),
      supabase
        .from('books')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', profile.id)
        .eq('status', 'finished'),
    ])
    stats = {
      total_sessions: sessions ?? 0,
      total_minutes: minutesData?.reduce((a, r) => a + (r.duration_minutes ?? 0), 0) ?? 0,
      total_books_finished: booksFinished ?? 0,
    }
  }

  // ── Reviews públicas do usuário ───────────────────────────────────────────
  const { data: reviews } = await supabase
    .from('reviews')
    .select(`
      id,
      rating,
      content,
      created_at,
      book:book_catalog ( title, slug, cover_url, author )
    `)
    .eq('user_id', profile.id)
    .eq('visibility', 'public')
    .order('created_at', { ascending: false })
    .limit(6)

  // JSON-LD schema.org/Person
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Person',
    name: profile.full_name ?? profile.username,
    alternateName: `@${profile.username}`,
    description: profile.bio,
    image: profile.avatar_url,
    url: `https://lumen.app/@${profile.username}`,
  }

  const stars = (rating: number) => '★'.repeat(rating) + '☆'.repeat(5 - rating)
  const hours = Math.floor((stats?.total_minutes ?? 0) / 60)

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
            <a href="https://app.lumen.app" className="text-sm text-[#6B6863] hover:text-[#1A1918]">
              Entrar
            </a>
          </div>
        </nav>

        <div className="max-w-4xl mx-auto px-6 py-12">
          {/* Cabeçalho do perfil */}
          <div className="flex flex-col sm:flex-row gap-6 items-start mb-10">
            {profile.avatar_url ? (
              <img
                src={profile.avatar_url}
                alt={profile.username ?? ''}
                className="w-24 h-24 rounded-full object-cover flex-shrink-0 shadow-sm"
              />
            ) : (
              <div className="w-24 h-24 rounded-full bg-[#E8F0EE] flex items-center justify-center flex-shrink-0">
                <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-3xl">
                  {(profile.username ?? '?')[0]?.toUpperCase()}
                </span>
              </div>
            )}

            <div className="flex-1">
              <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-1">@{profile.username}</p>
              <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918] mb-2">
                {profile.full_name ?? profile.username}
              </h1>
              {profile.bio && (
                <p className="text-sm text-[#6B6863] leading-relaxed max-w-xl">{profile.bio}</p>
              )}
              {profile.created_at && (
                <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-2">
                  Leitor desde {new Date(profile.created_at).toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })}
                </p>
              )}
            </div>
          </div>

          {/* Estatísticas */}
          {stats && (
            <div className="grid grid-cols-3 gap-4 mb-10">
              <div className="bg-white border border-[#ECEAE9] rounded-2xl p-5 text-center">
                <p className="font-[Fraunces] text-3xl font-bold text-[#3D6B5A]">
                  {stats.total_books_finished}
                </p>
                <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">livros lidos</p>
              </div>
              <div className="bg-white border border-[#ECEAE9] rounded-2xl p-5 text-center">
                <p className="font-[Fraunces] text-3xl font-bold text-[#3D6B5A]">
                  {stats.total_sessions}
                </p>
                <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">sessões</p>
              </div>
              <div className="bg-white border border-[#ECEAE9] rounded-2xl p-5 text-center">
                <p className="font-[Fraunces] text-3xl font-bold text-[#3D6B5A]">
                  {hours}h
                </p>
                <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">lidas</p>
              </div>
            </div>
          )}

          {/* Reviews públicas */}
          {reviews && reviews.length > 0 && (
            <section>
              <h2 className="font-[Fraunces] text-2xl font-bold text-[#1A1918] mb-6">
                Resenhas de @{profile.username}
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {reviews.map((review) => {
                  const book = Array.isArray(review.book) ? review.book[0] : review.book
                  return (
                    <a
                      key={review.id}
                      href={book?.slug ? `/books/${book.slug}` : '#'}
                      className="bg-white border border-[#ECEAE9] rounded-2xl p-5 hover:border-[#B0AEA9] transition-colors"
                    >
                      <div className="flex gap-3 mb-3">
                        {book?.cover_url && (
                          <img
                            src={book.cover_url}
                            alt={book?.title ?? ''}
                            className="w-12 h-16 object-cover rounded-lg flex-shrink-0"
                          />
                        )}
                        <div className="min-w-0">
                          <p className="font-medium text-[#1A1918] text-sm truncate">
                            {book?.title ?? 'Livro removido'}
                          </p>
                          {book?.author && (
                            <p className="text-xs text-[#6B6863]">{book.author}</p>
                          )}
                          {review.rating && (
                            <p className="text-[#F5A623] text-xs mt-1">{stars(review.rating)}</p>
                          )}
                        </div>
                      </div>
                      {review.content && (
                        <p className="text-xs text-[#6B6863] leading-relaxed line-clamp-3">
                          {review.content}
                        </p>
                      )}
                    </a>
                  )
                })}
              </div>
            </section>
          )}

          {/* CTA */}
          <div className="mt-12 bg-[#1A1918] rounded-2xl p-8 text-center text-white">
            <p className="font-[Fraunces] text-2xl font-bold mb-2">
              Registre sua leitura também
            </p>
            <p className="text-sm text-white/70 mb-6">
              Acompanhe seu progresso, escreva resenhas e participe de clubes do livro.
            </p>
            <a
              href="https://app.lumen.app"
              className="inline-block bg-white text-[#1A1918] px-6 py-3 rounded-xl text-sm font-medium hover:bg-[#FAF9F7] transition-colors"
            >
              Criar conta grátis
            </a>
          </div>
        </div>
      </main>
    </>
  )
}
