import { createServerSupabase } from '@lumen/supabase/server'
import { notFound } from 'next/navigation'
import type { Metadata } from 'next'

interface PageProps {
  params: Promise<{ id: string }>
}

export const revalidate = 3600

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params
  const supabase = await createServerSupabase()

  const { data: list } = await supabase
    .from('book_lists')
    .select('title, description, cover_url, profile:profiles(username)')
    .eq('id', id)
    .eq('visibility', 'public')
    .single()

  if (!list) return { title: 'Lista não encontrada · Lumen' }

  const profile = Array.isArray(list.profile) ? list.profile[0] : list.profile

  return {
    title: `${list.title} — Lista de @${profile?.username ?? 'leitor'}`,
    description: list.description
      ? list.description.slice(0, 155)
      : `Lista de livros "${list.title}" curada por @${profile?.username} na plataforma Lumen.`,
    openGraph: {
      title: list.title,
      description: list.description?.slice(0, 155),
      images: list.cover_url ? [{ url: list.cover_url }] : [],
    },
  }
}

export default async function PublicListPage({ params }: PageProps) {
  const { id } = await params
  const supabase = await createServerSupabase()

  const { data: list } = await supabase
    .from('book_lists')
    .select(`
      id,
      title,
      description,
      cover_url,
      created_at,
      updated_at,
      profile:profiles ( id, username, full_name, avatar_url )
    `)
    .eq('id', id)
    .eq('visibility', 'public')
    .single()

  if (!list) notFound()

  const profile = Array.isArray(list.profile) ? list.profile[0] : list.profile

  // Itens da lista com dados do catálogo
  const { data: items } = await supabase
    .from('book_list_items')
    .select(`
      id,
      position,
      note,
      book:book_catalog ( id, title, author, slug, cover_url, published_year )
    `)
    .eq('list_id', id)
    .order('position', { ascending: true })
    .limit(100)

  // JSON-LD schema.org/ItemList
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name: list.title,
    description: list.description,
    author: profile
      ? { '@type': 'Person', name: profile.full_name ?? profile.username, alternateName: `@${profile.username}` }
      : undefined,
    numberOfItems: items?.length ?? 0,
    itemListElement: (items ?? []).map((item, i) => {
      const book = Array.isArray(item.book) ? item.book[0] : item.book
      return {
        '@type': 'ListItem',
        position: i + 1,
        name: book?.title,
        url: book?.slug ? `https://lumen.app/books/${book.slug}` : undefined,
      }
    }),
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

        <div className="max-w-4xl mx-auto px-6 py-12">
          {/* Cabeçalho */}
          <div className="mb-10">
            {/* Autor da lista */}
            {profile && (
              <a
                href={`/@${profile.username}`}
                className="inline-flex items-center gap-2 mb-4 group"
              >
                <div className="w-7 h-7 rounded-full bg-[#E8F0EE] flex items-center justify-center text-xs font-medium text-[#3D6B5A]">
                  {(profile.username ?? '?')[0]?.toUpperCase()}
                </div>
                <span className="text-sm text-[#6B6863] group-hover:text-[#1A1918]">
                  @{profile.username}
                </span>
              </a>
            )}

            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
              Lista · {items?.length ?? 0} livro{items?.length !== 1 ? 's' : ''}
            </p>
            <h1 className="font-[Fraunces] text-4xl font-bold text-[#1A1918] mb-3 leading-tight">
              {list.title}
            </h1>
            {list.description && (
              <p className="text-sm text-[#6B6863] leading-relaxed max-w-2xl">
                {list.description}
              </p>
            )}
            {list.updated_at && (
              <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] mt-3">
                Atualizada em {new Date(list.updated_at).toLocaleDateString('pt-BR')}
              </p>
            )}
          </div>

          {/* Livros da lista */}
          {!items?.length ? (
            <div className="text-center py-16 bg-white border border-[#ECEAE9] rounded-2xl">
              <p className="text-[#6B6863]">Lista sem livros ainda.</p>
            </div>
          ) : (
            <div className="space-y-3">
              {items.map((item, index) => {
                const book = Array.isArray(item.book) ? item.book[0] : item.book
                return (
                  <a
                    key={item.id}
                    href={book?.slug ? `/books/${book.slug}` : '#'}
                    className="flex gap-4 items-start bg-white border border-[#ECEAE9] rounded-2xl p-4 hover:border-[#B0AEA9] transition-colors group"
                  >
                    {/* Número */}
                    <span className="w-7 h-7 rounded-full bg-[#F2F1EF] flex items-center justify-center text-xs font-[IBM_Plex_Mono] text-[#6B6863] flex-shrink-0 mt-1">
                      {index + 1}
                    </span>

                    {/* Capa */}
                    {book?.cover_url ? (
                      <img
                        src={book.cover_url}
                        alt={book?.title ?? ''}
                        className="w-12 h-16 object-cover rounded-lg flex-shrink-0 shadow-sm"
                      />
                    ) : (
                      <div className="w-12 h-16 bg-[#E8F0EE] rounded-lg flex items-center justify-center flex-shrink-0">
                        <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-lg">
                          {(book?.title ?? '?')[0]}
                        </span>
                      </div>
                    )}

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-[#1A1918] group-hover:text-[#3D6B5A] transition-colors truncate">
                        {book?.title ?? 'Livro removido'}
                      </p>
                      {book?.author && (
                        <p className="text-xs text-[#6B6863]">{book.author}</p>
                      )}
                      {book?.published_year && (
                        <p className="text-[10px] text-[#B0AEA9] font-[IBM_Plex_Mono] mt-0.5">
                          {book.published_year}
                        </p>
                      )}
                      {item.note && (
                        <p className="text-xs text-[#6B6863] mt-1.5 italic line-clamp-2">
                          &ldquo;{item.note}&rdquo;
                        </p>
                      )}
                    </div>
                  </a>
                )
              })}
            </div>
          )}

          {/* CTA */}
          <div className="mt-12 bg-[#1A1918] rounded-2xl p-8 text-center text-white">
            <p className="font-[Fraunces] text-2xl font-bold mb-2">
              Crie suas próprias listas
            </p>
            <p className="text-sm text-white/70 mb-6">
              Organize seus livros favoritos e compartilhe com outros leitores.
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
