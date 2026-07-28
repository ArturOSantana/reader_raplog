import { createServerSupabase } from '@lumen/supabase/server'
import type { Metadata } from 'next'

interface PageProps {
  searchParams: Promise<{ q?: string; page?: string }>
}

export const metadata: Metadata = {
  title: 'Catálogo de Livros · Lumen',
  description:
    'Explore o catálogo de livros da plataforma Lumen. Resenhas, autores, ratings e muito mais.',
}

export const revalidate = 3600

const PAGE_SIZE = 24

export default async function BooksIndexPage({ searchParams }: PageProps) {
  const { q = '', page = '1' } = await searchParams
  const currentPage = Math.max(1, parseInt(page, 10))
  const offset = (currentPage - 1) * PAGE_SIZE

  const supabase = await createServerSupabase()

  let query = supabase
    .from('book_catalog')
    .select('id, title, author, slug, cover_url, published_year', { count: 'exact' })
    .order('title')
    .range(offset, offset + PAGE_SIZE - 1)

  if (q.trim()) {
    const term = `%${q.trim()}%`
    query = query.or(`title.ilike.${term},author.ilike.${term}`)
  }

  const { data: books, count } = await query
  const totalPages = Math.ceil((count ?? 0) / PAGE_SIZE)

  return (
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
        <div className="mb-10">
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
            Lumen
          </p>
          <h1 className="font-[Fraunces] text-5xl font-bold text-[#1A1918] mb-4">
            Catálogo de Livros
          </h1>
          <p className="text-[#6B6863] text-lg max-w-xl">
            {count ? `${count.toLocaleString('pt-BR')} livros catalogados` : 'Explore nossa coleção de livros.'}
          </p>
        </div>

        {/* Busca */}
        <form method="GET" className="mb-8">
          <div className="flex gap-2 max-w-xl">
            <input
              name="q"
              defaultValue={q}
              placeholder="Buscar por título ou autor..."
              className="flex-1 border border-[#ECEAE9] rounded-xl px-4 py-3 text-sm bg-white focus:outline-none focus:border-[#3D6B5A]"
            />
            <button
              type="submit"
              className="bg-[#1A1918] text-white px-5 py-3 rounded-xl text-sm hover:bg-[#3D6B5A] transition-colors"
            >
              Buscar
            </button>
            {q && (
              <a
                href="/books"
                className="px-4 py-3 rounded-xl border border-[#ECEAE9] text-sm text-[#6B6863] hover:bg-[#F2F1EF]"
              >
                ×
              </a>
            )}
          </div>
        </form>

        {/* Grade */}
        {!books?.length ? (
          <div className="text-center py-20">
            <p className="font-[Fraunces] text-2xl text-[#1A1918] mb-2">Nenhum livro encontrado</p>
            <p className="text-sm text-[#6B6863]">Tente um termo diferente.</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-5 mb-10">
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
                    className="w-full aspect-[2/3] object-cover rounded-xl shadow-sm group-hover:shadow-md transition-shadow"
                  />
                ) : (
                  <div className="w-full aspect-[2/3] bg-[#E8F0EE] rounded-xl flex items-center justify-center">
                    <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-2xl">
                      {book.title[0]}
                    </span>
                  </div>
                )}
                <p className="text-xs font-medium text-[#1A1918] mt-2 line-clamp-2 group-hover:text-[#3D6B5A]">
                  {book.title}
                </p>
                <p className="text-[10px] text-[#6B6863] mt-0.5 truncate">
                  {book.author}
                </p>
              </a>
            ))}
          </div>
        )}

        {/* Paginação */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between">
            <p className="text-xs font-[IBM_Plex_Mono] text-[#B0AEA9]">
              Pág. {currentPage} de {totalPages}
            </p>
            <div className="flex gap-2">
              {currentPage > 1 && (
                <a
                  href={`/books?page=${currentPage - 1}${q ? `&q=${encodeURIComponent(q)}` : ''}`}
                  className="text-xs font-[IBM_Plex_Mono] px-4 py-2 border border-[#ECEAE9] rounded-lg hover:bg-[#F2F1EF] text-[#1A1918] bg-white"
                >
                  ← Anterior
                </a>
              )}
              {currentPage < totalPages && (
                <a
                  href={`/books?page=${currentPage + 1}${q ? `&q=${encodeURIComponent(q)}` : ''}`}
                  className="text-xs font-[IBM_Plex_Mono] px-4 py-2 border border-[#ECEAE9] rounded-lg hover:bg-[#F2F1EF] text-[#1A1918] bg-white"
                >
                  Próxima →
                </a>
              )}
            </div>
          </div>
        )}
      </div>
    </main>
  )
}
