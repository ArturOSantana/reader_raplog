import { createServerSupabase } from '@lumen/supabase/server'
import { notFound } from 'next/navigation'
import type { Metadata } from 'next'

interface PageProps {
  params: Promise<{ slug: string }>
}

export const revalidate = 86400

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params
  const supabase = await createServerSupabase()

  const { data: author } = await supabase
    .from('authors')
    .select('name, bio, photo_url')
    .eq('slug', slug)
    .single()

  if (!author) return { title: 'Autor não encontrado · Lumen' }

  return {
    title: author.name,
    description: author.bio
      ? author.bio.slice(0, 155)
      : `Livros e resenhas de ${author.name} na plataforma Lumen.`,
    openGraph: {
      title: author.name,
      description: author.bio?.slice(0, 155),
      images: author.photo_url ? [{ url: author.photo_url }] : [],
    },
  }
}

export default async function AuthorPage({ params }: PageProps) {
  const { slug } = await params
  const supabase = await createServerSupabase()

  const { data: author } = await supabase
    .from('authors')
    .select('id, name, bio, photo_url, nationality, born_year, website_url')
    .eq('slug', slug)
    .single()

  if (!author) notFound()

  const { data: books } = await supabase
    .from('book_catalog')
    .select('id, title, slug, cover_url, published_year, page_count')
    .eq('author_id', author.id)
    .order('published_year', { ascending: false })
    .limit(24)

  // JSON-LD schema.org/Person
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Person',
    name: author.name,
    description: author.bio,
    image: author.photo_url,
    nationality: author.nationality,
    birthDate: author.born_year ? String(author.born_year) : undefined,
    sameAs: author.website_url ? [author.website_url] : undefined,
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
            <a href="https://app.lumen.app" className="text-sm text-[#6B6863] hover:text-[#1A1918]">
              Entrar
            </a>
          </div>
        </nav>

        <div className="max-w-5xl mx-auto px-6 py-12">
          {/* Cabeçalho do autor */}
          <div className="flex flex-col sm:flex-row gap-8 mb-12">
            {author.photo_url ? (
              <img
                src={author.photo_url}
                alt={author.name}
                className="w-32 h-32 object-cover rounded-full flex-shrink-0 shadow-sm"
              />
            ) : (
              <div className="w-32 h-32 bg-[#E8F0EE] rounded-full flex items-center justify-center flex-shrink-0">
                <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-4xl">
                  {author.name[0]}
                </span>
              </div>
            )}

            <div>
              <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
                Autor
              </p>
              <h1 className="font-[Fraunces] text-4xl font-bold text-[#1A1918] mb-3">
                {author.name}
              </h1>

              <div className="flex flex-wrap gap-3 text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-4">
                {author.nationality && <span>{author.nationality}</span>}
                {author.born_year && <span>· n. {author.born_year}</span>}
                {books && books.length > 0 && (
                  <span>· {books.length} livro{books.length !== 1 ? 's' : ''} no catálogo</span>
                )}
              </div>

              {author.bio && (
                <p className="text-sm text-[#6B6863] leading-relaxed max-w-2xl">
                  {author.bio}
                </p>
              )}

              {author.website_url && (
                <a
                  href={author.website_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-block mt-4 text-sm text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]"
                >
                  Site oficial →
                </a>
              )}
            </div>
          </div>

          {/* Grade de livros */}
          {books && books.length > 0 && (
            <section>
              <h2 className="font-[Fraunces] text-2xl font-bold text-[#1A1918] mb-6">
                Livros no catálogo
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
                {books.map((book) => (
                  <a
                    key={book.id}
                    href={`/books/${book.slug}`}
                    className="group"
                  >
                    {book.cover_url ? (
                      <img
                        src={book.cover_url}
                        alt={`Capa de ${book.title}`}
                        className="w-full aspect-[2/3] object-cover rounded-lg shadow-sm group-hover:shadow-md transition-shadow"
                      />
                    ) : (
                      <div className="w-full aspect-[2/3] bg-[#E8F0EE] rounded-lg flex items-center justify-center">
                        <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-xl">
                          {book.title[0]}
                        </span>
                      </div>
                    )}
                    <p className="text-xs font-medium text-[#1A1918] mt-2 line-clamp-2 group-hover:text-[#3D6B5A]">
                      {book.title}
                    </p>
                    {book.published_year && (
                      <p className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono]">
                        {book.published_year}
                      </p>
                    )}
                  </a>
                ))}
              </div>
            </section>
          )}
        </div>
      </main>
    </>
  )
}
