import { createServerSupabase } from '@lumen/supabase/server'
import { notFound } from 'next/navigation'
import type { Metadata } from 'next'

interface PageProps {
  params: Promise<{ slug: string }>
}

// ISR — revalida a cada 24h (spec §12: P95 < 300ms)
export const revalidate = 86400

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params
  const supabase = await createServerSupabase()

  const { data: book } = await supabase
    .from('book_catalog')
    .select('title, author, description, cover_url, isbn')
    .eq('slug', slug)
    .single()

  if (!book) return { title: 'Livro não encontrado · Lumen' }

  return {
    title: `${book.title} — ${book.author}`,
    description: book.description
      ? book.description.slice(0, 155)
      : `Resenhas, citações e dados de leitura de "${book.title}" por ${book.author} na plataforma Lumen.`,
    openGraph: {
      title: `${book.title} — ${book.author}`,
      description: book.description?.slice(0, 155),
      images: book.cover_url ? [{ url: book.cover_url, width: 400, height: 600 }] : [],
      type: 'book',
    },
    twitter: {
      card: 'summary_large_image',
      title: `${book.title} — ${book.author}`,
    },
  }
}

export default async function BookPage({ params }: PageProps) {
  const { slug } = await params
  const supabase = await createServerSupabase()

  // ── Dados do livro do catálogo público ────────────────────────────────────
  const { data: book } = await supabase
    .from('book_catalog')
    .select(`
      id,
      title,
      author,
      isbn,
      publisher,
      published_year,
      page_count,
      description,
      cover_url,
      categories,
      language,
      google_books_id
    `)
    .eq('slug', slug)
    .single()

  if (!book) notFound()

  // ── Reviews públicas agregadas ────────────────────────────────────────────
  const { data: reviews } = await supabase
    .from('reviews')
    .select(`
      id,
      rating,
      content,
      created_at,
      profile:profiles ( username, avatar_url )
    `)
    .eq('book_catalog_id', book.id)
    .eq('visibility', 'public')
    .order('created_at', { ascending: false })
    .limit(10)

  // ── Agregados de rating ───────────────────────────────────────────────────
  const { data: ratingAgg } = await supabase
    .from('reviews')
    .select('rating')
    .eq('book_catalog_id', book.id)
    .eq('visibility', 'public')

  const ratings = ratingAgg?.map((r) => r.rating).filter(Boolean) ?? []
  const avgRating = ratings.length
    ? (ratings.reduce((a, b) => a + b, 0) / ratings.length).toFixed(1)
    : null

  // JSON-LD schema.org/Book
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Book',
    name: book.title,
    author: {
      '@type': 'Person',
      name: book.author,
    },
    isbn: book.isbn,
    publisher: book.publisher
      ? { '@type': 'Organization', name: book.publisher }
      : undefined,
    numberOfPages: book.page_count,
    inLanguage: book.language ?? 'pt-BR',
    image: book.cover_url,
    description: book.description,
    datePublished: book.published_year ? String(book.published_year) : undefined,
    ...(avgRating && ratings.length > 0
      ? {
          aggregateRating: {
            '@type': 'AggregateRating',
            ratingValue: avgRating,
            reviewCount: ratings.length,
            bestRating: 5,
            worstRating: 1,
          },
        }
      : {}),
  }

  const stars = (rating: number) => '★'.repeat(rating) + '☆'.repeat(5 - rating)

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <main className="min-h-screen bg-[#FAF9F7]">
        {/* Nav */}
        <nav className="border-b border-[#ECEAE9] bg-[#FAF9F7] sticky top-0 z-50">
          <div className="max-w-5xl mx-auto px-6 h-14 flex items-center justify-between">
            <a href="/" className="font-[Fraunces] font-bold text-xl text-[#1A1918]">lumen</a>
            <a
              href="https://app.lumen.app"
              className="text-sm text-[#6B6863] hover:text-[#1A1918]"
            >
              Entrar
            </a>
          </div>
        </nav>

        <div className="max-w-5xl mx-auto px-6 py-12">
          {/* Cabeçalho do livro */}
          <div className="flex flex-col sm:flex-row gap-8 mb-12">
            {book.cover_url ? (
              <img
                src={book.cover_url}
                alt={`Capa de ${book.title}`}
                className="w-40 h-56 object-cover rounded-xl flex-shrink-0 shadow-sm"
              />
            ) : (
              <div className="w-40 h-56 bg-[#E8F0EE] rounded-xl flex items-center justify-center flex-shrink-0">
                <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-4xl">
                  {book.title[0]}
                </span>
              </div>
            )}

            <div className="flex-1">
              <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
                Livro
              </p>
              <h1 className="font-[Fraunces] text-4xl font-bold text-[#1A1918] mb-2 leading-tight">
                {book.title}
              </h1>
              <p className="text-lg text-[#6B6863] mb-4">
                por{' '}
                <a
                  href={`/authors/${encodeURIComponent(book.author.toLowerCase().replace(/\s+/g, '-'))}`}
                  className="text-[#3D6B5A] hover:underline"
                >
                  {book.author}
                </a>
              </p>

              {avgRating && (
                <div className="flex items-center gap-2 mb-4">
                  <span className="text-[#F5A623] text-lg tracking-wider">
                    {stars(Math.round(parseFloat(avgRating)))}
                  </span>
                  <span className="font-[IBM_Plex_Mono] text-sm text-[#1A1918] font-medium">
                    {avgRating}
                  </span>
                  <span className="text-xs text-[#6B6863]">({ratings.length} resenha{ratings.length !== 1 ? 's' : ''})</span>
                </div>
              )}

              <div className="flex flex-wrap gap-3 text-xs font-[IBM_Plex_Mono] text-[#6B6863]">
                {book.page_count && <span>{book.page_count} páginas</span>}
                {book.publisher && <span>· {book.publisher}</span>}
                {book.published_year && <span>· {book.published_year}</span>}
                {book.isbn && <span>· ISBN {book.isbn}</span>}
              </div>

              {book.description && (
                <p className="text-sm text-[#6B6863] mt-4 leading-relaxed max-w-xl">
                  {book.description}
                </p>
              )}

              <div className="mt-6">
                <a
                  href="https://app.lumen.app"
                  className="inline-block bg-[#1A1918] text-white px-6 py-3 rounded-xl text-sm font-medium hover:bg-[#3D6B5A] transition-colors"
                >
                  Adicionar à minha biblioteca
                </a>
              </div>
            </div>
          </div>

          {/* Resenhas */}
          {reviews && reviews.length > 0 && (
            <section>
              <h2 className="font-[Fraunces] text-2xl font-bold text-[#1A1918] mb-6">
                Resenhas ({ratings.length})
              </h2>
              <div className="space-y-4">
                {reviews.map((review) => {
                  const profile = Array.isArray(review.profile) ? review.profile[0] : review.profile
                  return (
                    <div
                      key={review.id}
                      className="bg-white border border-[#ECEAE9] rounded-2xl p-5"
                      itemScope
                      itemType="https://schema.org/Review"
                    >
                      <div className="flex items-center gap-3 mb-3">
                        <div className="w-8 h-8 rounded-full bg-[#E8F0EE] flex items-center justify-center text-xs font-medium text-[#3D6B5A]">
                          {(profile?.username ?? '?')[0]?.toUpperCase()}
                        </div>
                        <div>
                          <p className="text-sm font-medium text-[#1A1918]" itemProp="author">
                            @{profile?.username ?? '—'}
                          </p>
                          {review.rating && (
                            <p className="text-[#F5A623] text-xs" itemProp="reviewRating">
                              {stars(review.rating)}
                            </p>
                          )}
                        </div>
                        {review.created_at && (
                          <time
                            dateTime={review.created_at}
                            className="ml-auto text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]"
                          >
                            {new Date(review.created_at).toLocaleDateString('pt-BR')}
                          </time>
                        )}
                      </div>
                      {review.content && (
                        <p className="text-sm text-[#6B6863] leading-relaxed" itemProp="reviewBody">
                          {review.content}
                        </p>
                      )}
                    </div>
                  )
                })}
              </div>
            </section>
          )}

          {!reviews?.length && (
            <div className="text-center py-12 bg-white border border-[#ECEAE9] rounded-2xl">
              <p className="font-[Fraunces] text-lg text-[#1A1918] mb-2">
                Nenhuma resenha pública ainda
              </p>
              <p className="text-sm text-[#6B6863] mb-4">
                Seja o primeiro a registrar este livro e escrever uma resenha.
              </p>
              <a
                href="https://app.lumen.app"
                className="inline-block bg-[#1A1918] text-white px-5 py-2.5 rounded-xl text-sm hover:bg-[#3D6B5A] transition-colors"
              >
                Começar a usar o Lumen
              </a>
            </div>
          )}
        </div>
      </main>
    </>
  )
}
