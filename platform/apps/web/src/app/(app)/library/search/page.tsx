import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
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

  // ── Busca via Google Books API (spec §23) ─────────────────────────────────
  let results: GoogleBook[] = []
  let searchError: string | null = null

  if (q.trim().length >= 2) {
    const apiKey = process.env.GOOGLE_BOOKS_API_KEY
    if (!apiKey) {
      searchError = 'Busca temporariamente indisponível.'
    } else {
      try {
        const url = new URL('https://www.googleapis.com/books/v1/volumes')
        url.searchParams.set('q', q.trim())
        url.searchParams.set('maxResults', '12')
        url.searchParams.set('langRestrict', 'pt')
        url.searchParams.set('key', apiKey)
        url.searchParams.set('printType', 'books')
        url.searchParams.set('orderBy', 'relevance')

        const res = await fetch(url.toString(), {
          next: { revalidate: 3600 }, // cache 1h — spec §23: fallback por cota
        })

        if (!res.ok) throw new Error(`Google Books API: ${res.status}`)
        const data = await res.json()
        results = (data.items ?? []).map(parseGoogleBook)
      } catch (err) {
        console.error('Google Books error:', err)
        // Spec §23: fallback com Open Library
        try {
          const olRes = await fetch(
            `https://openlibrary.org/search.json?q=${encodeURIComponent(q)}&limit=12&language=por`,
            { next: { revalidate: 3600 } }
          )
          if (olRes.ok) {
            const olData = await olRes.json()
            results = (olData.docs ?? []).slice(0, 12).map(parseOpenLibraryBook)
          }
        } catch {
          searchError = 'Busca temporariamente indisponível. Tente novamente.'
        }
      }
    }
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

// ── Tipos e parsers ───────────────────────────────────────────

interface GoogleBook {
  googleBooksId: string | null
  title: string
  author: string | null
  coverUrl: string | null
  isbn: string | null
  publisher: string | null
  publishedYear: number | null
  pageCount: number | null
  description: string | null
}

function parseGoogleBook(item: Record<string, unknown>): GoogleBook {
  const info = (item.volumeInfo ?? {}) as Record<string, unknown>
  const ids   = (info.industryIdentifiers as Array<{ type: string; identifier: string }> | undefined) ?? []
  const isbn13 = ids.find((id) => id.type === 'ISBN_13')?.identifier ?? null
  const isbn10 = ids.find((id) => id.type === 'ISBN_10')?.identifier ?? null
  const images = (info.imageLinks ?? {}) as Record<string, string>
  return {
    googleBooksId: item.id as string | null,
    title:         (info.title as string) ?? 'Sem título',
    author:        (info.authors as string[] | undefined)?.[0] ?? null,
    coverUrl:      images.thumbnail?.replace('http:', 'https:') ?? null,
    isbn:          isbn13 ?? isbn10,
    publisher:     (info.publisher as string | undefined) ?? null,
    publishedYear: info.publishedDate ? parseInt(String(info.publishedDate).slice(0, 4)) || null : null,
    pageCount:     (info.pageCount as number | undefined) ?? null,
    description:   (info.description as string | undefined)?.slice(0, 300) ?? null,
  }
}

function parseOpenLibraryBook(doc: Record<string, unknown>): GoogleBook {
  const coverId = (doc.cover_i as number | undefined)
  return {
    googleBooksId: null,
    title:         (doc.title as string) ?? 'Sem título',
    author:        (doc.author_name as string[] | undefined)?.[0] ?? null,
    coverUrl:      coverId ? `https://covers.openlibrary.org/b/id/${coverId}-M.jpg` : null,
    isbn:          ((doc.isbn as string[] | undefined)?.[0]) ?? null,
    publisher:     (doc.publisher as string[] | undefined)?.[0] ?? null,
    publishedYear: (doc.first_publish_year as number | undefined) ?? null,
    pageCount:     (doc.number_of_pages_median as number | undefined) ?? null,
    description:   null,
  }
}
