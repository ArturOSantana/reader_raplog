import { NextResponse } from 'next/server'
import { createServerSupabase } from '@lumen/supabase/server'

/**
 * GET /api/export/library
 *
 * Exporta a biblioteca do usuário autenticado em JSON ou CSV.
 * Parâmetro: ?format=json | ?format=csv  (padrão: json)
 *
 * Spec §11 — LGPD: exportação em formato aberto (não proprietário).
 * Spec §5 — Conteúdo do usuário pertence ao usuário.
 */
export async function GET(request: Request) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 })
  }

  const { searchParams } = new URL(request.url)
  const format = searchParams.get('format') ?? 'json'

  const { data: books, error } = await supabase
    .from('books')
    .select(`
      id,
      title,
      author,
      isbn,
      publisher,
      published_year,
      page_count,
      status,
      rating,
      review,
      started_at,
      finished_at,
      created_at,
      updated_at
    `)
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })

  if (error) {
    return NextResponse.json({ error: 'Erro ao exportar biblioteca' }, { status: 500 })
  }

  const rows = books ?? []

  // ── JSON ──────────────────────────────────────────────────────────────────
  if (format === 'json') {
    const payload = {
      exported_at: new Date().toISOString(),
      user_id: user.id,
      total: rows.length,
      books: rows,
    }
    return new NextResponse(JSON.stringify(payload, null, 2), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="lumen-biblioteca-${new Date().toISOString().slice(0, 10)}.json"`,
        'Cache-Control': 'no-store',
      },
    })
  }

  // ── CSV ───────────────────────────────────────────────────────────────────
  if (format === 'csv') {
    const cols = [
      'id', 'title', 'author', 'isbn', 'publisher',
      'published_year', 'page_count', 'status', 'rating',
      'review', 'started_at', 'finished_at', 'created_at', 'updated_at',
    ] as const

    const escape = (val: unknown): string => {
      if (val == null) return ''
      const str = String(val).replace(/"/g, '""')
      return str.includes(',') || str.includes('\n') || str.includes('"')
        ? `"${str}"`
        : str
    }

    const header = cols.join(',')
    const csvRows = rows.map((book) =>
      cols.map((col) => escape(book[col])).join(',')
    )
    const csv = [header, ...csvRows].join('\r\n')

    return new NextResponse(csv, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="lumen-biblioteca-${new Date().toISOString().slice(0, 10)}.csv"`,
        'Cache-Control': 'no-store',
      },
    })
  }

  return NextResponse.json({ error: 'Formato inválido. Use ?format=json ou ?format=csv' }, { status: 400 })
}
