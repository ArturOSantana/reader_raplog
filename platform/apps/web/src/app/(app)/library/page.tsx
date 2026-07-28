import { redirect } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { bookStatusLabel } from '@lumen/ui'
import { batchUpdateStatus, batchDelete } from './library-actions'
import type { Book } from '@lumen/types'
import type { Metadata } from 'next'
import { AddIcon, ChevronRightIcon, LibraryIcon, SearchIcon } from '@/lib/lumen-icons'

export const metadata: Metadata = { title: 'Biblioteca · Lumen Web' }

interface PageProps {
  searchParams: Promise<{
    view?: string      // 'grid' | 'table'
    status?: string    // filtro de status
    sort?: string      // 'updated' | 'title' | 'author' | 'rating' | 'pages'
    order?: string     // 'asc' | 'desc'
    action?: string    // feedback de ação
  }>
}

const STATUS_OPTIONS = [
  { value: '', label: 'Todos' },
  { value: 'reading', label: 'Lendo' },
  { value: 'want_to_read', label: 'Quero ler' },
  { value: 'finished', label: 'Lidos' },
  { value: 'abandoned', label: 'Abandonados' },
]

const SORT_OPTIONS = [
  { value: 'updated', label: 'Recentes' },
  { value: 'title', label: 'Título' },
  { value: 'author', label: 'Autor' },
  { value: 'rating', label: 'Nota' },
  { value: 'pages', label: 'Páginas' },
]

export default async function LibraryPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { view = 'grid', status = '', sort = 'updated', order = 'desc', action } = await searchParams

  // ── Query com filtros + ordenação ─────────────────────────────────────────
  const sortCol: Record<string, string> = {
    updated: 'updated_at',
    title:   'title',
    author:  'author',
    rating:  'rating',
    pages:   'page_count',
  }

  let query = supabase
    .from('books')
    .select('*')
    .eq('user_id', user.id)
    .order(sortCol[sort] ?? 'updated_at', { ascending: order === 'asc', nullsFirst: false })

  if (status) query = query.eq('status', status)

  const { data: rawBooks } = await query
  const books = (rawBooks as Book[]) ?? []

  // Contagem total para o badge
  const { count: totalCount } = await supabase
    .from('books')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', user.id)

  const feedbackMsg: Record<string, string> = {
    batch_updated: 'Status atualizado.',
    batch_deleted: 'Livros removidos.',
    imported: 'Importação concluída.',
  }

  return (
    <div className="p-6 max-w-6xl mx-auto">
      {/* Feedback */}
      {action && feedbackMsg[action] && (
        <div className="mb-5 bg-[#3D6B5A]/10 border border-[#3D6B5A]/20 text-[#3D6B5A] px-4 py-2.5 rounded-xl text-sm font-[IBM_Plex_Mono]">
          {feedbackMsg[action]}
        </div>
      )}

      {/* Cabeçalho */}
      <div className="flex items-start justify-between mb-6 flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1 text-[#6B6863]">
            <LibraryIcon className="h-4 w-4" />
            <p className="text-xs font-[IBM_Plex_Mono] uppercase tracking-widest">
              {totalCount ?? 0} livros
            </p>
          </div>
          <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Biblioteca</h1>
        </div>
        <div className="flex items-center gap-2">
          <Link
            href="/library/import"
            className="text-sm px-4 py-2 border border-[#ECEAE9] rounded-xl text-[#6B6863] hover:bg-[#F2F1EF] font-[IBM_Plex_Mono] inline-flex items-center gap-2"
          >
            <AddIcon className="h-4 w-4" />
            <span>Importar</span>
          </Link>
          <a
            href="/api/export/library?format=csv"
            className="text-sm px-4 py-2 border border-[#ECEAE9] rounded-xl text-[#6B6863] hover:bg-[#F2F1EF] font-[IBM_Plex_Mono]"
          >
            ↓ CSV
          </a>
          <a
            href="/api/export/library?format=json"
            className="text-sm px-4 py-2 border border-[#ECEAE9] rounded-xl text-[#6B6863] hover:bg-[#F2F1EF] font-[IBM_Plex_Mono]"
          >
            ↓ JSON
          </a>
        </div>
      </div>

      {/* Toolbar: filtros + view toggle */}
      <div className="flex flex-col gap-4 mb-6">
        <div className="relative max-w-md">
          <SearchIcon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#B0AEA9]" />
          <input
            type="search"
            placeholder="Buscar livros em breve"
            disabled
            aria-label="Busca da biblioteca em breve"
            className="w-full rounded-xl border border-[#ECEAE9] bg-white py-2.5 pl-9 pr-3 text-sm text-[#B0AEA9] outline-none"
          />
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          {/* Status */}
          <div className="flex gap-1.5 flex-wrap">
            {STATUS_OPTIONS.map((opt) => (
              <Link
                key={opt.value}
                href={`/library?view=${view}&sort=${sort}&order=${order}${opt.value ? `&status=${opt.value}` : ''}`}
                className={`text-xs font-[IBM_Plex_Mono] px-3 py-1.5 rounded-lg transition-colors ${
                  status === opt.value
                    ? 'bg-[#1A1918] text-white'
                    : 'bg-[#F2F1EF] text-[#6B6863] hover:bg-[#ECEAE9]'
                }`}
              >
                {opt.label}
              </Link>
            ))}
          </div>

          <div className="ml-auto flex items-center gap-2">
            {/* Ordenação */}
            <form method="GET" className="flex gap-1">
              {status && <input type="hidden" name="status" value={status} />}
              <input type="hidden" name="view" value={view} />
              <select
                name="sort"
                defaultValue={sort}
                onChange={undefined}
                className="text-xs font-[IBM_Plex_Mono] border border-[#ECEAE9] rounded-lg px-2 py-1.5 bg-white text-[#6B6863] focus:outline-none"
              >
                {SORT_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o.label}</option>
                ))}
              </select>
              <select
                name="order"
                defaultValue={order}
                onChange={undefined}
                className="text-xs font-[IBM_Plex_Mono] border border-[#ECEAE9] rounded-lg px-2 py-1.5 bg-white text-[#6B6863] focus:outline-none"
              >
                <option value="desc">↓ Desc</option>
                <option value="asc">↑ Asc</option>
              </select>
              <button
                type="submit"
                className="text-xs font-[IBM_Plex_Mono] px-3 py-1.5 bg-[#1A1918] text-white rounded-lg hover:bg-[#3D6B5A] transition-colors"
              >
                OK
              </button>
            </form>

            {/* Grid / Table toggle */}
            <div className="flex border border-[#ECEAE9] rounded-lg overflow-hidden">
              <Link
                href={`/library?view=grid&status=${status}&sort=${sort}&order=${order}`}
                className={`px-2.5 py-1.5 text-xs font-[IBM_Plex_Mono] transition-colors ${
                  view !== 'table' ? 'bg-[#1A1918] text-white' : 'text-[#6B6863] hover:bg-[#F2F1EF]'
                }`}
              >
                ⊞
              </Link>
              <Link
                href={`/library?view=table&status=${status}&sort=${sort}&order=${order}`}
                className={`px-2.5 py-1.5 text-xs font-[IBM_Plex_Mono] transition-colors ${
                  view === 'table' ? 'bg-[#1A1918] text-white' : 'text-[#6B6863] hover:bg-[#F2F1EF]'
                }`}
              >
                ☰
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* Vazio */}
      {books.length === 0 && (
        <div className="text-center py-24 text-[#6B6863] flex flex-col items-center">
          <LibraryIcon className="h-10 w-10 text-[#B0AEA9] mb-4" />
          <p className="font-[Fraunces] text-xl mb-2">
            {status ? `Nenhum livro com status "${bookStatusLabel(status)}"` : 'Sua estante ainda está em silêncio.'}
          </p>
          <p className="text-sm mb-4">Importe uma lista existente ou adicione pelo app mobile.</p>
          <Link href="/library/import" className="inline-flex items-center gap-2 bg-[#1A1918] text-white px-5 py-2.5 rounded-xl text-sm hover:bg-[#3D6B5A]">
            <AddIcon className="h-4 w-4" />
            <span>Importar livros</span>
          </Link>
        </div>
      )}

      {/* ── Visualização em TABELA ─────────────────────────────────────────── */}
      {view === 'table' && books.length > 0 && (
        <form>
          {/* Batch actions */}
          <div className="flex items-center gap-2 mb-3">
            <span className="text-xs font-[IBM_Plex_Mono] text-[#6B6863]">Selecionados:</span>
            <button
              formAction={async (fd) => {
                'use server'
                await batchUpdateStatus(fd)
                redirect('/library?view=table&action=batch_updated')
              }}
              name="status"
              value="finished"
              className="text-xs px-3 py-1.5 border border-[#ECEAE9] rounded-lg hover:bg-[#F2F1EF] font-[IBM_Plex_Mono] text-[#3D6B5A]"
            >
              Marcar lido
            </button>
            <button
              formAction={async (fd) => {
                'use server'
                await batchUpdateStatus(fd)
                redirect('/library?view=table&action=batch_updated')
              }}
              name="status"
              value="want_to_read"
              className="text-xs px-3 py-1.5 border border-[#ECEAE9] rounded-lg hover:bg-[#F2F1EF] font-[IBM_Plex_Mono] text-[#6B6863]"
            >
              Quero ler
            </button>
            <button
              formAction={async (fd) => {
                'use server'
                await batchDelete(fd)
                redirect('/library?view=table&action=batch_deleted')
              }}
              className="text-xs px-3 py-1.5 border border-red-200 rounded-lg hover:bg-red-50 font-[IBM_Plex_Mono] text-[#8B2E2E]"
            >
              Remover
            </button>
          </div>

          <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[#ECEAE9] text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] uppercase tracking-widest">
                  <th className="w-8 px-3 py-3"><input type="checkbox" id="select-all" className="rounded" /></th>
                  <th className="text-left px-3 py-3">Título</th>
                  <th className="text-left px-3 py-3 hidden sm:table-cell">Autor</th>
                  <th className="text-left px-3 py-3">Status</th>
                  <th className="text-left px-3 py-3 hidden md:table-cell">Nota</th>
                  <th className="text-left px-3 py-3 hidden lg:table-cell">Páginas</th>
                  <th className="text-left px-3 py-3 hidden lg:table-cell">Ano</th>
                </tr>
              </thead>
              <tbody>
                {books.map((book) => (
                  <tr key={book.id} className="border-b border-[#ECEAE9] last:border-0 hover:bg-[#F8F9FA]">
                    <td className="px-3 py-3 text-center">
                      <input
                        type="checkbox"
                        name="ids"
                        value={book.id}
                        className="rounded"
                      />
                    </td>
                    <td className="px-3 py-3">
                      <div className="flex items-center gap-3 min-w-0">
                        {book.cover_url ? (
                          <Image
                            src={book.cover_url}
                            alt={book.title}
                            width={28}
                            height={40}
                            className="rounded object-cover flex-shrink-0"
                          />
                        ) : (
                          <div className="w-7 h-10 bg-[#E8F0EE] rounded flex-shrink-0" />
                        )}
                        <p className="font-medium text-[#1A1918] truncate max-w-[200px]">
                          {book.title}
                        </p>
                      </div>
                    </td>
                    <td className="px-3 py-3 text-[#6B6863] hidden sm:table-cell truncate max-w-[140px]">
                      {book.author ?? '—'}
                    </td>
                    <td className="px-3 py-3">
                      <span className={`text-[10px] font-[IBM_Plex_Mono] px-1.5 py-0.5 rounded uppercase tracking-wider ${
                        book.status === 'reading'   ? 'bg-blue-100 text-blue-700'    :
                        book.status === 'read'      ? 'bg-[#E8F0EE] text-[#3D6B5A]'  :
                        book.status === 'abandoned' ? 'bg-red-50 text-red-600'       :
                        'bg-[#F2F1EF] text-[#6B6863]'
                      }`}>
                        {bookStatusLabel(book.status)}
                      </span>
                    </td>
                    <td className="px-3 py-3 hidden md:table-cell">
                      {book.rating ? (
                        <span className="text-[#F5A623] text-xs">
                          {'★'.repeat(book.rating)}{'☆'.repeat(5 - book.rating)}
                        </span>
                      ) : <span className="text-[#B0AEA9] font-[IBM_Plex_Mono] text-xs">—</span>}
                    </td>
                    <td className="px-3 py-3 text-[#6B6863] font-[IBM_Plex_Mono] text-xs hidden lg:table-cell">
                      {book.total_pages ?? '—'}
                    </td>
                    <td className="px-3 py-3 text-[#B0AEA9] font-[IBM_Plex_Mono] text-xs hidden lg:table-cell">
                      {book.status === 'reading' && book.current_page && book.total_pages ? (
                        <div>
                          <div className="h-1 bg-[#E8F0EE] rounded-full w-16 overflow-hidden">
                            <div
                              className="h-full bg-[#3D6B5A] rounded-full"
                              style={{ width: `${Math.min(100, (book.current_page / book.total_pages) * 100)}%` }}
                            />
                          </div>
                          <span className="text-[9px] mt-0.5 block">{book.current_page}/{book.total_pages}</span>
                        </div>
                      ) : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </form>
      )}

      {/* ── Visualização em GRADE ──────────────────────────────────────────── */}
      {view !== 'table' && books.length > 0 && (
        <>
          {/* Agrupa por status apenas quando não há filtro */}
          {status ? (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {books.map((book) => <BookCard key={book.id} book={book} />)}
            </div>
          ) : (
            (['reading', 'want_to_read', 'read', 'abandoned'] as const).map((s) => {
              const list = books.filter((b) => b.status === s)
              if (!list.length) return null
              return (
                <section key={s} className="mb-10">
                  <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4 flex items-center gap-2">
                    {bookStatusLabel(s)}
                    <span className="text-sm font-[IBM_Plex_Mono] font-normal text-[#6B6863]">({list.length})</span>
                  </h2>
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {list.map((book) => <BookCard key={book.id} book={book} />)}
                  </div>
                </section>
              )
            })
          )}
        </>
      )}
    </div>
  )
}

function BookCard({ book }: { book: Book }) {
  return (
    <div className="group">
      <div className="aspect-[2/3] bg-[#E8F0EE] rounded-xl overflow-hidden mb-2">
        {book.cover_url ? (
          <Image
            src={book.cover_url}
            alt={book.title}
            width={120}
            height={180}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center p-3">
            <span className="font-[Fraunces] text-[#3D6B5A] text-center text-xs font-semibold leading-snug">
              {book.title}
            </span>
          </div>
        )}
      </div>
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="text-xs font-medium text-[#1A1918] truncate">{book.title}</p>
          <p className="text-xs text-[#6B6863] truncate">{book.author}</p>
        </div>
        <ChevronRightIcon className="h-3.5 w-3.5 text-[#B0AEA9] flex-shrink-0 mt-0.5" />
      </div>
      {book.status === 'reading' && book.current_page && book.total_pages && (
        <div className="mt-1.5">
          <div className="h-1 bg-[#E8F0EE] rounded-full overflow-hidden">
            <div
              className="h-full bg-[#3D6B5A] rounded-full"
              style={{ width: `${Math.min(100, (book.current_page / book.total_pages) * 100)}%` }}
            />
          </div>
          <p className="text-[10px] text-[#6B6863] mt-0.5">{book.current_page}/{book.total_pages} pág.</p>
        </div>
      )}
      {book.rating != null && book.rating > 0 && (
        <p className="text-xs text-[#F5A623] mt-0.5">{'★'.repeat(book.rating)}</p>
      )}
    </div>
  )
}
