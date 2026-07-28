import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { searchBooks, type BookMetadata } from '@/lib/book-search-cache'
import { addBookFromSearch } from './search-actions'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Buscar Livros · Lumen' }

interface PageProps {
  searchParams: Promise<{ q?: string; action?: string; added?: string }>
}

export default async function BookSearchPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { q = '', action, added } = await searchParams

  // ── Busca com cache (spec §2 — Google Books Cache Layer) ──────────────────
  let results: BookMetadata[] = []
  let searchError: string | null = null

  if (q.trim().length >= 2) {
    const result = await searchBooks(q, {
      apiKey: process.env.GOOGLE_BOOKS_API_KEY ?? '',
    })
    results = result.books
    searchError = result.error ?? null
  }

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">
          Biblioteca
        </p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Buscar livros</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Encontre um livro e adicione à sua biblioteca.
        </p>
      </div>

      {/* Feedback */}
      {action === 'added' && added && (
        <div className="mb-5 bg-[#3D6B5A]/10 border border-[#3D6B5A]/20 text-[#3D6B5A] px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          ✓ &ldquo;{added}&rdquo; adicionado à biblioteca.
        </div>
      )}

      {/* Busca */}
      <form method="GET" className="mb-8">
        <div className="flex gap-2">
          <input
            name="q"
            defaultValue={q}
            placeholder="Título, autor ou ISBN..."
            autoFocus
            className="flex-1 border border-[#ECEAE9] rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-[#3D6B5A]"
          />
          <button
            type="submit"
            className="bg-[#1A1918] text-white px-6 py-3 rounded-xl text-sm hover:bg-[#3D6B5A] transition-colors font-[IBM_Plex_Mono]"
          >
            Buscar
          </button>
        </div>
      </form>

      {searchError && (
        <div className="bg-yellow-50 border border-yellow-200 text-yellow-800 px-4 py-3 rounded-xl text-sm mb-6">
          {searchError}
        </div>
      )}

      {/* Resultados */}
      {q && results.length === 0 && !searchError && (
        <div className="text-center py-16">
          <p className="font-[Fraunces] text-xl text-[#1A1918] mb-2">Nenhum livro encontrado</p>
          <p className="text-sm text-[#6B6863]">Tente um título ou autor diferente.</p>
        </div>
      )}

      {results.length > 0 && (
        <div className="space-y-3">
          <p className="text-xs font-[IBM_Plex_Mono] text-[#B0AEA9] mb-4">
            {results.length} resultado{results.length !== 1 ? 's' : ''} para &ldquo;{q}&rdquo;
          </p>
          {results.map((book) => (
            <div
              key={book.googleBooksId ?? book.title}
              className="bg-white border border-[#ECEAE9] rounded-2xl p-4 flex gap-4 items-start hover:border-[#B0AEA9] transition-colors"
            >
              {/* Capa */}
              {book.coverUrl ? (
                <img
                  src={book.coverUrl}
                  alt={book.title}
                  className="w-12 h-16 object-cover rounded-lg flex-shrink-0 shadow-sm"
                />
              ) : (
                <div className="w-12 h-16 bg-[#E8F0EE] rounded-lg flex items-center justify-center flex-shrink-0">
                  <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-lg">
                    {book.title[0]}
                  </span>
                </div>
              )}

              {/* Info */}
              <div className="flex-1 min-w-0">
                <p className="font-medium text-[#1A1918] truncate">{book.title}</p>
                <p className="text-xs text-[#6B6863]">{book.author}</p>
                <div className="flex gap-3 mt-1 text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">
                  {book.publisher && <span>{book.publisher}</span>}
                  {book.publishedYear && <span>· {book.publishedYear}</span>}
                  {book.pageCount && <span>· {book.pageCount} pág.</span>}
                </div>
                {book.description && (
                  <p className="text-xs text-[#6B6863] mt-1.5 line-clamp-2 leading-relaxed">
                    {book.description}
                  </p>
                )}
              </div>

              {/* Adicionar */}
              <form action={addBookFromSearch} className="flex-shrink-0">
                <input type="hidden" name="title"           value={book.title} />
                <input type="hidden" name="author"          value={book.author ?? ''} />
                <input type="hidden" name="cover_url"       value={book.coverUrl ?? ''} />
                <input type="hidden" name="isbn"            value={book.isbn ?? ''} />
                <input type="hidden" name="publisher"       value={book.publisher ?? ''} />
                <input type="hidden" name="published_year"  value={book.publishedYear ?? ''} />
                <input type="hidden" name="page_count"      value={book.pageCount ?? ''} />
                <input type="hidden" name="google_books_id" value={book.googleBooksId ?? ''} />
                <input type="hidden" name="redirect_q"      value={q} />
                <button
                  type="submit"
                  className="text-xs font-[IBM_Plex_Mono] px-3 py-2 bg-[#1A1918] text-white rounded-xl hover:bg-[#3D6B5A] transition-colors whitespace-nowrap"
                >
                  + Biblioteca
                </button>
              </form>
            </div>
          ))}
        </div>
      )}

      {!q && (
        <div className="text-center py-16">
          <p className="text-5xl mb-4">🔍</p>
          <p className="font-[Fraunces] text-xl text-[#1A1918] mb-2">Busque por qualquer livro</p>
          <p className="text-sm text-[#6B6863]">
            Pesquise por título, autor ou ISBN. Powered by Google Books.
          </p>
          <div className="mt-6">
            <Link
              href="/library/import"
              className="text-sm text-[#3D6B5A] hover:underline font-[IBM_Plex_Mono]"
            >
              Prefere importar uma lista? →
            </Link>
          </div>
        </div>
      )}
    </div>
  )
}

