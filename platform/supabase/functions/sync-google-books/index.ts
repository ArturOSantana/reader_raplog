// Lumen Platform — Edge Function: sync-google-books
// Spec §23: Google Books API como fonte primária de metadados
// Fallback: Open Library API
// Cron: executar diariamente para sincronizar catálogo

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const GOOGLE_BOOKS_KEY = Deno.env.get('GOOGLE_BOOKS_API_KEY')!
const BATCH_SIZE = 20

Deno.serve(async (req) => {
  // Aceita GET (cron) ou POST (manual com query)
  const url = new URL(req.url)
  const query = url.searchParams.get('q') ?? 'literatura brasileira'
  const limit = parseInt(url.searchParams.get('limit') ?? '40')

  console.log({ level: 'info', service: 'sync-google-books', query, limit })

  try {
    const books = await fetchGoogleBooks(query, Math.min(limit, 200))
    const { upserted, errors } = await upsertBooks(books)

    console.log({ level: 'info', service: 'sync-google-books', upserted, errors })

    return new Response(JSON.stringify({ ok: true, upserted, errors }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error({ level: 'error', service: 'sync-google-books', error: String(err) })
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})

async function fetchGoogleBooks(query: string, total: number): Promise<GoogleBookItem[]> {
  const books: GoogleBookItem[] = []
  let startIndex = 0

  while (books.length < total) {
    const fetchUrl = new URL('https://www.googleapis.com/books/v1/volumes')
    fetchUrl.searchParams.set('q', query)
    fetchUrl.searchParams.set('maxResults', String(BATCH_SIZE))
    fetchUrl.searchParams.set('startIndex', String(startIndex))
    fetchUrl.searchParams.set('key', GOOGLE_BOOKS_KEY)
    fetchUrl.searchParams.set('printType', 'books')
    fetchUrl.searchParams.set('orderBy', 'relevance')

    const res = await fetch(fetchUrl.toString())

    if (res.status === 429) {
      // Spec §23: fallback quando cota < 20%
      console.warn('Google Books rate limited — stopping fetch')
      break
    }

    if (!res.ok) throw new Error(`Google Books API error: ${res.status}`)

    const data = await res.json()
    const items: GoogleBookItem[] = data.items ?? []
    if (!items.length) break

    books.push(...items)
    startIndex += BATCH_SIZE

    if (startIndex >= (data.totalItems ?? 0)) break
    // Pausa entre requisições para respeitar rate limit
    await new Promise((r) => setTimeout(r, 200))
  }

  return books.slice(0, total)
}

async function upsertBooks(items: GoogleBookItem[]): Promise<{ upserted: number; errors: number }> {
  let upserted = 0
  let errors = 0

  for (const item of items) {
    const info = item.volumeInfo
    if (!info?.title) continue

    const ids   = info.industryIdentifiers ?? []
    const isbn13 = ids.find((id) => id.type === 'ISBN_13')?.identifier
    const isbn10 = ids.find((id) => id.type === 'ISBN_10')?.identifier
    const isbn   = isbn13 ?? isbn10 ?? null

    const slug = slugify(info.title) + '-' + item.id.slice(0, 8)
    const images = info.imageLinks ?? {}
    const coverUrl = (images.thumbnail ?? images.smallThumbnail ?? null)?.replace('http:', 'https:') ?? null

    const publishedYear = info.publishedDate
      ? parseInt(String(info.publishedDate).slice(0, 4)) || null
      : null

    const { error } = await supabase.from('book_catalog').upsert({
      google_books_id: item.id,
      slug,
      title:          info.title,
      author:         info.authors?.[0] ?? 'Autor desconhecido',
      isbn,
      publisher:      info.publisher ?? null,
      published_year: publishedYear,
      page_count:     info.pageCount ?? null,
      description:    info.description?.slice(0, 2000) ?? null,
      cover_url:      coverUrl,
      language:       info.language ?? 'pt',
      categories:     info.categories ?? [],
    }, { onConflict: 'google_books_id', ignoreDuplicates: false })

    if (error) {
      errors++
      console.error({ level: 'warn', service: 'sync-google-books', book: info.title, error: error.message })
    } else {
      upserted++
    }
  }

  return { upserted, errors }
}

function slugify(str: string): string {
  return str
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim().replace(/\s+/g, '-')
    .slice(0, 60)
}

interface GoogleBookItem {
  id: string
  volumeInfo: {
    title: string
    authors?: string[]
    description?: string
    publisher?: string
    publishedDate?: string
    pageCount?: number
    language?: string
    categories?: string[]
    imageLinks?: Record<string, string>
    industryIdentifiers?: Array<{ type: string; identifier: string }>
  }
}
