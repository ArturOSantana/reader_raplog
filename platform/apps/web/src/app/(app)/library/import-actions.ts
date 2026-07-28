'use server'

import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'

/**
 * importGoodreadsCSV — processa o CSV exportado do Goodreads
 *
 * Colunas obrigatórias do Goodreads export:
 *   Title, Author, ISBN, My Rating, Number of Pages, Year Published,
 *   Date Read, Date Added, Exclusive Shelf, My Review
 */
export async function importGoodreadsCSV(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const file = formData.get('file') as File | null
  if (!file || file.size === 0) {
    return { error: 'Arquivo inválido.' }
  }

  if (!file.name.endsWith('.csv')) {
    return { error: 'Apenas arquivos .csv são aceitos.' }
  }

  // Spec §8: limite de 5MB para upload
  if (file.size > 5 * 1024 * 1024) {
    return { error: 'Arquivo muito grande. Máximo: 5MB.' }
  }

  const text = await file.text()
  const rows = parseCSV(text)

  if (rows.length < 2) {
    return { error: 'CSV vazio ou sem dados.' }
  }

  const headers = rows[0].map((h) => h.trim().toLowerCase())
  const dataRows = rows.slice(1)

  // Mapeamento de colunas Goodreads
  const col = (name: string) => headers.indexOf(name)
  const titleIdx     = col('title')
  const authorIdx    = col('author')
  const isbnIdx      = col('isbn')
  const ratingIdx    = col('my rating')
  const pagesIdx     = col('number of pages')
  const yearIdx      = col('year published')
  const dateReadIdx  = col('date read')
  const shelfIdx     = col('exclusive shelf')
  const reviewIdx    = col('my review')

  if (titleIdx === -1) {
    return { error: 'Formato inválido: coluna "Title" não encontrada. Exporte diretamente do Goodreads.' }
  }

  let imported = 0
  let skipped  = 0
  const errors: string[] = []

  for (const row of dataRows) {
    const get = (idx: number) => (idx >= 0 ? (row[idx] ?? '').trim() : '')

    const title = get(titleIdx)
    if (!title) { skipped++; continue }

    const shelf   = get(shelfIdx).toLowerCase()
    const status  = shelfToStatus(shelf)
    const rating  = parseInt(get(ratingIdx)) || null
    const pages   = parseInt(get(pagesIdx)) || null
    const year    = parseInt(get(yearIdx)) || null
    const dateRead = parseDateRead(get(dateReadIdx))

    // ISBN: Goodreads exporta com ="..." — limpa
    const isbnRaw = get(isbnIdx).replace(/[="]/g, '')
    const isbn    = isbnRaw || null

    try {
      const { error } = await supabase.from('books').insert({
        user_id:        user.id,
        title,
        author:         get(authorIdx) || null,
        isbn,
        page_count:     pages,
        published_year: year,
        status,
        rating:         rating && rating > 0 ? rating : null,
        review:         get(reviewIdx) || null,
        finished_at:    dateRead,
      })
      if (error) {
        errors.push(`"${title}": ${error.message}`)
        skipped++
      } else {
        imported++
      }
    } catch {
      errors.push(`"${title}": erro inesperado`)
      skipped++
    }
  }

  // Audit log
  await supabase.from('audit_logs').insert({
    actor_id: user.id,
    action: 'user.data_exported',
    metadata: { type: 'goodreads_import', imported, skipped },
  })

  return { imported, skipped, errors: errors.slice(0, 5) }
}

/**
 * importGenericCSV — CSV genérico com colunas flexíveis
 * Colunas reconhecidas: title, author, isbn, status, rating, pages, year, review
 */
export async function importGenericCSV(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const file = formData.get('file') as File | null
  if (!file || file.size === 0) return { error: 'Arquivo inválido.' }
  if (!file.name.endsWith('.csv')) return { error: 'Apenas arquivos .csv são aceitos.' }
  if (file.size > 5 * 1024 * 1024) return { error: 'Arquivo muito grande. Máximo: 5MB.' }

  const text = await file.text()
  const rows = parseCSV(text)
  if (rows.length < 2) return { error: 'CSV vazio ou sem dados.' }

  const headers = rows[0].map((h) => h.trim().toLowerCase())
  const dataRows = rows.slice(1)

  const col = (name: string) => headers.indexOf(name)
  const titleIdx  = col('title') !== -1 ? col('title') : col('titulo')
  const authorIdx = col('author') !== -1 ? col('author') : col('autor')
  const isbnIdx   = col('isbn')
  const statusIdx = col('status')
  const ratingIdx = col('rating') !== -1 ? col('rating') : col('nota')
  const pagesIdx  = col('pages') !== -1 ? col('pages') : col('paginas')
  const yearIdx   = col('year') !== -1 ? col('year') : col('ano')
  const reviewIdx = col('review') !== -1 ? col('review') : col('resenha')

  if (titleIdx === -1) {
    return { error: 'Coluna "title" ou "titulo" não encontrada.' }
  }

  let imported = 0; let skipped = 0
  const errors: string[] = []

  for (const row of dataRows) {
    const get = (idx: number) => (idx >= 0 ? (row[idx] ?? '').trim() : '')
    const title = get(titleIdx)
    if (!title) { skipped++; continue }

    const statusRaw = get(statusIdx).toLowerCase()
    const status    = genericStatusMap(statusRaw)
    const rating    = parseInt(get(ratingIdx)) || null

    try {
      const { error } = await supabase.from('books').insert({
        user_id:        user.id,
        title,
        author:         get(authorIdx) || null,
        isbn:           get(isbnIdx) || null,
        page_count:     parseInt(get(pagesIdx)) || null,
        published_year: parseInt(get(yearIdx)) || null,
        status,
        rating:         rating && rating > 0 && rating <= 5 ? rating : null,
        review:         get(reviewIdx) || null,
      })
      if (error) { errors.push(`"${title}": ${error.message}`); skipped++ }
      else imported++
    } catch {
      errors.push(`"${title}": erro inesperado`); skipped++
    }
  }

  return { imported, skipped, errors: errors.slice(0, 5) }
}

// ── Helpers ───────────────────────────────────────────────────

function parseCSV(text: string): string[][] {
  const rows: string[][] = []
  const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n')
  for (const line of lines) {
    if (!line.trim()) continue
    rows.push(parseLine(line))
  }
  return rows
}

function parseLine(line: string): string[] {
  const fields: string[] = []
  let field = ''
  let inQuotes = false
  for (let i = 0; i < line.length; i++) {
    const ch = line[i]
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') { field += '"'; i++ }
      else inQuotes = !inQuotes
    } else if (ch === ',' && !inQuotes) {
      fields.push(field); field = ''
    } else {
      field += ch
    }
  }
  fields.push(field)
  return fields
}

function shelfToStatus(shelf: string): 'reading' | 'want_to_read' | 'finished' | 'abandoned' {
  if (shelf === 'currently-reading' || shelf === 'reading') return 'reading'
  if (shelf === 'read') return 'finished'
  if (shelf === 'did-not-finish' || shelf === 'abandoned') return 'abandoned'
  return 'want_to_read'
}

function genericStatusMap(s: string): 'reading' | 'want_to_read' | 'finished' | 'abandoned' {
  if (['reading', 'lendo', 'current'].includes(s)) return 'reading'
  if (['read', 'lido', 'finished', 'concluido'].includes(s)) return 'finished'
  if (['abandoned', 'abandonado', 'dnf'].includes(s)) return 'abandoned'
  return 'want_to_read'
}

function parseDateRead(d: string): string | null {
  if (!d) return null
  // Goodreads: "YYYY/MM/DD" ou "MM/DD/YYYY"
  const iso = d.replace(/\//g, '-')
  const dt  = new Date(iso)
  return isNaN(dt.getTime()) ? null : dt.toISOString()
}
