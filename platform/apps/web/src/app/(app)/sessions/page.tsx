import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { timeAgo, formatMinutes } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Sessões de Leitura · Lumen' }

interface PageProps {
  searchParams: Promise<{
    page?: string
    book?: string
    from?: string
    to?: string
  }>
}

const PAGE_SIZE = 20

export default async function SessionsPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { page = '1', book = '', from = '', to = '' } = await searchParams
  const currentPage = Math.max(1, parseInt(page, 10))
  const offset = (currentPage - 1) * PAGE_SIZE

  // ── Busca com filtros ─────────────────────────────────────────────────────
  let query = supabase
    .from('reading_sessions')
    .select(`
      id,
      started_at,
      ended_at,
      duration_minutes,
      pages_read,
      start_page,
      end_page,
      notes,
      books:book_id (
        id,
        title,
        author,
        cover_url
      )
    `, { count: 'exact' })
    .eq('user_id', user.id)
    .order('started_at', { ascending: false })
    .range(offset, offset + PAGE_SIZE - 1)

  if (from) query = query.gte('started_at', from)
  if (to) query = query.lte('started_at', to + 'T23:59:59')
  if (book) query = query.eq('book_id', book)

  const { data: sessions, count } = await query
  const totalPages = Math.ceil((count ?? 0) / PAGE_SIZE)

  // ── Sumário geral ─────────────────────────────────────────────────────────
  const { data: summary } = await supabase
    .from('reading_sessions')
    .select('duration_minutes, pages_read')
    .eq('user_id', user.id)

  const totalMinutes = summary?.reduce((s, r) => s + (r.duration_minutes ?? 0), 0) ?? 0
  const totalPages30d = summary?.reduce((s, r) => s + (r.pages_read ?? 0), 0) ?? 0
  const totalSessions = count ?? 0

  // ── Livros do usuário para o filtro ───────────────────────────────────────
  const { data: userBooks } = await supabase
    .from('books')
    .select('id, title')
    .eq('user_id', user.id)
    .order('title')
    .limit(100)

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">
          Biblioteca
        </p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">
          Histórico de Sessões
        </h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Todas as suas sessões de leitura registradas.
        </p>
      </div>

      {/* Sumário */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
          <p className="font-[Fraunces] text-3xl font-bold text-[#3D6B5A]">{totalSessions}</p>
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">sessões totais</p>
        </div>
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
          <p className="font-[Fraunces] text-3xl font-bold text-[#3D6B5A]">{formatMinutes(totalMinutes)}</p>
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">tempo total</p>
        </div>
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
          <p className="font-[Fraunces] text-3xl font-bold text-[#3D6B5A]">{totalPages30d}</p>
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">páginas lidas</p>
        </div>
      </div>

      {/* Filtros */}
      <form method="GET" className="bg-white border border-[#ECEAE9] rounded-2xl p-5 mb-6">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-4">Filtros</p>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div>
            <label className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] block mb-1">Livro</label>
            <select
              name="book"
              defaultValue={book}
              className="w-full border border-[#ECEAE9] rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:border-[#3D6B5A]"
            >
              <option value="">Todos</option>
              {userBooks?.map((b) => (
                <option key={b.id} value={b.id}>{b.title}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] block mb-1">De</label>
            <input
              type="date"
              name="from"
              defaultValue={from}
              className="w-full border border-[#ECEAE9] rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:border-[#3D6B5A]"
            />
          </div>
          <div>
            <label className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] block mb-1">Até</label>
            <input
              type="date"
              name="to"
              defaultValue={to}
              className="w-full border border-[#ECEAE9] rounded-xl px-3 py-2 text-sm bg-white focus:outline-none focus:border-[#3D6B5A]"
            />
          </div>
        </div>
        <div className="flex gap-2 mt-4">
          <button
            type="submit"
            className="bg-[#1A1918] text-white text-sm px-4 py-2 rounded-xl hover:bg-[#3D6B5A] transition-colors font-[IBM_Plex_Mono]"
          >
            Filtrar
          </button>
          {(book || from || to) && (
            <Link
              href="/sessions"
              className="text-sm px-4 py-2 rounded-xl border border-[#ECEAE9] text-[#6B6863] hover:bg-[#F2F1EF] font-[IBM_Plex_Mono]"
            >
              Limpar
            </Link>
          )}
        </div>
      </form>

      {/* Lista de sessões */}
      {!sessions?.length ? (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl py-16 text-center">
          <p className="text-4xl mb-4">📖</p>
          <p className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">
            Nenhuma sessão encontrada
          </p>
          <p className="text-sm text-[#6B6863] mt-2">
            {book || from || to
              ? 'Tente ajustar os filtros.'
              : 'Suas sessões de leitura aparecerão aqui.'}
          </p>
        </div>
      ) : (
        <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
          <div className="divide-y divide-[#ECEAE9]">
            {sessions.map((session) => {
              const bookData = Array.isArray(session.books) ? session.books[0] : session.books
              return (
                <div key={session.id} className="px-5 py-4 flex items-start gap-4 hover:bg-[#F8F9FA]">
                  {/* Capa miniatura */}
                  {bookData?.cover_url ? (
                    <img
                      src={bookData.cover_url}
                      alt={bookData.title ?? ''}
                      className="w-10 h-14 object-cover rounded flex-shrink-0"
                    />
                  ) : (
                    <div className="w-10 h-14 bg-[#E8F0EE] rounded flex items-center justify-center flex-shrink-0">
                      <span className="text-lg">📖</span>
                    </div>
                  )}

                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <p className="font-medium text-[#1A1918] text-sm truncate">
                          {bookData?.title ?? 'Livro removido'}
                        </p>
                        {bookData?.author && (
                          <p className="text-xs text-[#6B6863]">{bookData.author}</p>
                        )}
                      </div>
                      <span className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] flex-shrink-0">
                        {session.started_at ? timeAgo(session.started_at) : '—'}
                      </span>
                    </div>

                    <div className="flex items-center gap-4 mt-2 flex-wrap">
                      {session.duration_minutes != null && (
                        <span className="text-xs font-[IBM_Plex_Mono] text-[#3D6B5A] bg-[#3D6B5A]/5 px-2 py-0.5 rounded">
                          ⏱ {formatMinutes(session.duration_minutes)}
                        </span>
                      )}
                      {session.pages_read != null && session.pages_read > 0 && (
                        <span className="text-xs font-[IBM_Plex_Mono] text-[#6B6863]">
                          {session.pages_read} pág.
                          {session.start_page && session.end_page
                            ? ` (${session.start_page}–${session.end_page})`
                            : ''}
                        </span>
                      )}
                      {session.started_at && (
                        <span className="text-xs font-[IBM_Plex_Mono] text-[#B0AEA9]">
                          {new Date(session.started_at).toLocaleDateString('pt-BR', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </span>
                      )}
                    </div>

                    {session.notes && (
                      <p className="text-xs text-[#6B6863] mt-2 line-clamp-2 italic">
                        &ldquo;{session.notes}&rdquo;
                      </p>
                    )}
                  </div>
                </div>
              )
            })}
          </div>

          {/* Paginação */}
          {totalPages > 1 && (
            <div className="px-5 py-4 border-t border-[#ECEAE9] flex items-center justify-between">
              <p className="text-xs font-[IBM_Plex_Mono] text-[#B0AEA9]">
                Pág. {currentPage} de {totalPages} · {count} sessões
              </p>
              <div className="flex gap-2">
                {currentPage > 1 && (
                  <Link
                    href={`/sessions?page=${currentPage - 1}${book ? `&book=${book}` : ''}${from ? `&from=${from}` : ''}${to ? `&to=${to}` : ''}`}
                    className="text-xs font-[IBM_Plex_Mono] px-3 py-1.5 border border-[#ECEAE9] rounded-lg hover:bg-[#F2F1EF] text-[#1A1918]"
                  >
                    ← Anterior
                  </Link>
                )}
                {currentPage < totalPages && (
                  <Link
                    href={`/sessions?page=${currentPage + 1}${book ? `&book=${book}` : ''}${from ? `&from=${from}` : ''}${to ? `&to=${to}` : ''}`}
                    className="text-xs font-[IBM_Plex_Mono] px-3 py-1.5 border border-[#ECEAE9] rounded-lg hover:bg-[#F2F1EF] text-[#1A1918]"
                  >
                    Próxima →
                  </Link>
                )}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
