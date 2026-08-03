/**
 * book-search-cache.ts
 *
 * Cache server-side para resultados de busca de livros (Google Books / Open Library).
 *
 * Arquitetura (spec §2 — Google Books Cache Layer):
 *   Usuário pesquisa → cache LRU em memória → Google Books API → normalização → salvar → responder
 *=6h por query (queries com mesmo texto normalizado reutilizam hit)
 */

// ── Tipo normalizado (BookMetadata) ─────────────────────────────────────────

export interface BookMetadata {
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

// ── Interface CacheProvider (para troca futura por Redis/Upstash) ────────────

interface BookSearchCacheProvider {
  get(key: string): BookMetadata[] | null
  set(key: string, value: BookMetadata[], ttlMs: number): void
}

// ── Impl: LRU in-process (servidor Node.js / Edge runtime) ──────────────────

interface CacheEntry {
  value: BookMetadata[]
  expiresAt: number
}

const MAX_ENTRIES = 200 // ~200 queries em memória (~4–8 MB)
const DEFAULT_TTL_MS = 6 * 60 * 60 * 1000 // 6 horas

class MemoryLruCache implements BookSearchCacheProvider {
  private readonly store = new Map<string, CacheEntry>()

  get(key: string): BookMetadata[] | null {
    const entry = this.store.get(key)
    if (!entry) return null
    if (Date.now() > entry.expiresAt) {
      this.store.delete(key)
      return null
    }
    // LRU: move para o fim ao acessar
    this.store.delete(key)
    this.store.set(key, entry)
    return entry.value
  }

  set(key: string, value: BookMetadata[], ttlMs: number): void {
    if (this.store.size >= MAX_ENTRIES) {
      // Evict o mais antigo (primeiro da Map)
      const oldest = this.store.keys().next().value
      if (oldest) this.store.delete(oldest)
    }
    this.store.set(key, { value, expiresAt: Date.now() + ttlMs })
  }
}

// Singleton por processo Node.js (persiste entre requests no mesmo worker)
const cache: BookSearchCacheProvider = new MemoryLruCache()

// ── Chave de cache ────────────────────────────────────────────────────────────

function cacheKey(query: string, lang: string): string {
  return `books:search:${lang}:${query.trim().toLowerCase()}`
}

// ── Parsers externos → BookMetadata ──────────────────────────────────────────

function parseGoogleBook(item: Record<string, unknown>): BookMetadata {
  const info = (item.volumeInfo ?? {}) as Record<string, unknown>
  const ids = (info.industryIdentifiers as Array<{ type: string; identifier: string }> | undefined) ?? []
  const isbn13 = ids.find((id) => id.type === 'ISBN_13')?.identifier ?? null
  const isbn10 = ids.find((id) => id.type === 'ISBN_10')?.identifier ?? null
  const images = (info.imageLinks ?? {}) as Record<string, string>
  return {
    googleBooksId: (item.id as string) ?? null,
    title: (info.title as string) ?? 'Sem título',
    author: (info.authors as string[] | undefined)?.[0] ?? null,
    coverUrl: images.thumbnail?.replace('http:', 'https:') ?? null,
    isbn: isbn13 ?? isbn10,
    publisher: (info.publisher as string | undefined) ?? null,
    publishedYear: info.publishedDate
      ? parseInt(String(info.publishedDate).slice(0, 4)) || null
      : null,
    pageCount: (info.pageCount as number | undefined) ?? null,
    description: (info.description as string | undefined)?.slice(0, 300) ?? null,
  }
}

function parseOpenLibraryBook(doc: Record<string, unknown>): BookMetadata {
  const coverId = doc.cover_i as number | undefined
  return {
    googleBooksId: null,
    title: (doc.title as string) ?? 'Sem título',
    author: (doc.author_name as string[] | undefined)?.[0] ?? null,
    coverUrl: coverId ? `https://covers.openlibrary.org/b/id/${coverId}-M.jpg` : null,
    isbn: (doc.isbn as string[] | undefined)?.[0] ?? null,
    publisher: (doc.publisher as string[] | undefined)?.[0] ?? null,
    publishedYear: (doc.first_publish_year as number | undefined) ?? null,
    pageCount: (doc.number_of_pages_median as number | undefined) ?? null,
    description: null,
  }
}

// ── Busca com cache ───────────────────────────────────────────────────────────

export interface BookSearchResult {
  books: BookMetadata[]
  source: 'cache' | 'google_books' | 'open_library'
  error?: string
}

/**
 * Pesquisa livros com cache automático.
 * Ordem: cache → Google Books → Open Library (fallback)
 *
 * Nunca lança exceção — erros retornam em `result.error`.
 */
export async function searchBooks(
  query: string,
  options: {
    maxResults?: number
    lang?: string
    apiKey?: string
    ttlMs?: number
  } = {}
): Promise<BookSearchResult> {
  const { maxResults = 12, lang = 'pt', apiKey = '', ttlMs = DEFAULT_TTL_MS } = options
  const q = query.trim()
  if (q.length < 2) return { books: [], source: 'cache' }

  const key = cacheKey(q, lang)

  // ── 1. Hit de cache ──────────────────────────────────────────────────────
  const cached = cache.get(key)
  if (cached) return { books: cached, source: 'cache' }

  // ── 2. Google Books API ──────────────────────────────────────────────────
  if (apiKey) {
    try {
      const url = new URL('https://www.googleapis.com/books/v1/volumes')
      url.searchParams.set('q', q)
      url.searchParams.set('maxResults', String(maxResults))
      url.searchParams.set('langRestrict', lang)
      url.searchParams.set('key', apiKey)
      url.searchParams.set('printType', 'books')
      url.searchParams.set('orderBy', 'relevance')

      const res = await fetch(url.toString(), { cache: 'no-store' })
      if (!res.ok) throw new Error(`Google Books: ${res.status}`)

      const data = await res.json()
      const books: BookMetadata[] = (data.items ?? []).map(parseGoogleBook)
      cache.set(key, books, ttlMs)
      return { books, source: 'google_books' }
    } catch {
      // cai para o fallback
    }
  }

  // ── 3. Open Library (fallback) ────────────────────────────────────────────
  try {
    const olRes = await fetch(
      `https://openlibrary.org/search.json?q=${encodeURIComponent(q)}&limit=${maxResults}&language=por`,
      { cache: 'no-store' }
    )
    if (!olRes.ok) throw new Error(`Open Library: ${olRes.status}`)

    const olData = await olRes.json()
    const books: BookMetadata[] = (olData.docs ?? []).slice(0, maxResults).map(parseOpenLibraryBook)
    cache.set(key, books, ttlMs)
    return { books, source: 'open_library' }
  } catch {
    return {
      books: [],
      source: 'open_library',
      error: 'Busca temporariamente indisponível. Tente novamente.',
    }
  }
}
