/**
 * GET /api/books/search?q=...&lang=...&maxResults=...
 *
 * Route Handler público (autenticado via Supabase session) para busca de livros.
 * Usa book-search-cache.ts — nunca chama Google Books duas vezes para a mesma query.
 *
 * Spec §2 (Google Books Cache Layer): cache → Google Books → Open Library
 */

import { NextRequest, NextResponse } from 'next/server'
import { createServerSupabase } from '@lumen/supabase/server'
import { searchBooks } from '@/lib/book-search-cache'

export const runtime = 'nodejs' // precisa de Map in-memory global

export async function GET(req: NextRequest) {
  // ── Autenticação ─────────────────────────────────────────────────────────
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 })
  }

  // ── Parâmetros ────────────────────────────────────────────────────────────
  const { searchParams } = req.nextUrl
  const q = (searchParams.get('q') ?? '').trim()
  const lang = searchParams.get('lang') ?? 'pt'
  const maxResults = Math.min(20, parseInt(searchParams.get('maxResults') ?? '12', 10) || 12)

  if (q.length < 2) {
    return NextResponse.json({ books: [], source: 'cache' })
  }

  // ── Busca com cache ───────────────────────────────────────────────────────
  const result = await searchBooks(q, {
    maxResults,
    lang,
    apiKey: process.env.GOOGLE_BOOKS_API_KEY ?? '',
  })

  // Headers de cache HTTP para CDN/browser (complementa o cache server)
  const headers: Record<string, string> = {
    'Cache-Control': 'private, max-age=3600',
    'X-Cache-Source': result.source,
  }

  if (result.error) {
    return NextResponse.json(result, { status: 503, headers })
  }

  return NextResponse.json(result, { headers })
}
