import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate, clubCategoryLabel } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Clubes · Admin Lumen' }

export default async function AdminClubsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string; page?: string }>
}) {
  const supabase = await createServerSupabase()
  const { q, status, page: pageParam } = await searchParams
  const page = Math.max(1, parseInt(pageParam ?? '1'))
  const pageSize = 25
  const offset = (page - 1) * pageSize

  let query = supabase
    .from('book_clubs')
    .select('id, name, description, category, status, visibility, created_at, current_book_title, member_count', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(offset, offset + pageSize - 1)

  if (q) query = query.ilike('name', `%${q}%`)
  if (status) query = query.eq('status', status)

  const { data: clubs, count } = await query
  const totalPages = Math.ceil((count ?? 0) / pageSize)

  const statusBadge: Record<string, string> = {
    active: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
    on_vacation: 'bg-[#8B5E2E]/10 text-[#8B5E2E]',
    closed: 'bg-[#F2F1EF] text-[#B0AEA9]',
    archived: 'bg-[#F2F1EF] text-[#B0AEA9]',
  }
  const statusLabel: Record<string, string> = {
    active: 'Ativo',
    on_vacation: 'Férias',
    closed: 'Encerrado',
    archived: 'Arquivado',
  }
  const visibilityLabel: Record<string, string> = {
    public: 'Público',
    private: 'Privado',
    invite_only: 'Convite',
  }

  const buildHref = (params: Record<string, string | undefined>) => {
    const p = new URLSearchParams()
    if (params.q) p.set('q', params.q)
    if (params.status) p.set('status', params.status)
    if (params.page) p.set('page', params.page)
    const str = p.toString()
    return str ? `?${str}` : '?'
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Clubes</h1>
        <p className="text-sm text-[#6B6863] mt-1">{count ?? 0} total</p>
      </div>

      {/* Filtros */}
      <form className="flex flex-wrap gap-2 mb-6">
        <input
          name="q"
          defaultValue={q}
          placeholder="Buscar clube…"
          className="flex-1 min-w-[200px] border border-[#ECEAE9] bg-white rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-[#3D6B5A]"
        />
        <select
          name="status"
          defaultValue={status}
          className="border border-[#ECEAE9] bg-white rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-[#3D6B5A]"
        >
          <option value="">Todos os status</option>
          <option value="active">Ativo</option>
          <option value="on_vacation">Férias</option>
          <option value="closed">Encerrado</option>
          <option value="archived">Arquivado</option>
        </select>
        <button type="submit" className="bg-[#1A1918] text-white px-5 py-2 rounded-xl text-sm font-medium hover:bg-[#2C2B29] transition-colors">
          Filtrar
        </button>
      </form>

      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[#ECEAE9]">
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Nome</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden md:table-cell">Categoria</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Visibilidade</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Membros</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Status</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden lg:table-cell">Criado</th>
            </tr>
          </thead>
          <tbody>
            {clubs?.map((club) => (
              <tr key={club.id} className="border-b border-[#ECEAE9]/50 hover:bg-[#FAF9F7] transition-colors">
                <td className="p-4">
                  <a href={`/clubs/${club.id}`} className="font-medium text-[#1A1918] hover:text-[#3D6B5A] transition-colors">
                    {club.name}
                  </a>
                  {club.current_book_title && (
                    <p className="text-[10px] text-[#6B6863] mt-0.5">📖 {club.current_book_title}</p>
                  )}
                </td>
                <td className="p-4 text-[#6B6863] hidden md:table-cell text-xs">{clubCategoryLabel(club.category)}</td>
                <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden sm:table-cell">{visibilityLabel[club.visibility] ?? club.visibility}</td>
                <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden sm:table-cell">{club.member_count ?? '—'}</td>
                <td className="p-4">
                  <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${statusBadge[club.status] ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                    {statusLabel[club.status] ?? club.status}
                  </span>
                </td>
                <td className="p-4 text-xs text-[#6B6863] font-[IBM_Plex_Mono] hidden lg:table-cell">
                  {formatDate(club.created_at)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!clubs || clubs.length === 0) && (
          <div className="p-12 text-center text-[#6B6863] text-sm">Nenhum clube encontrado.</div>
        )}
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm font-[IBM_Plex_Mono] text-[#6B6863]">
          <span>Página {page} de {totalPages}</span>
          <div className="flex gap-2">
            {page > 1 && (
              <a href={buildHref({ q, status, page: String(page - 1) })}
                className="px-3 py-1.5 border border-[#ECEAE9] rounded-lg hover:border-[#B0AEA9] transition-colors">
                ← Anterior
              </a>
            )}
            {page < totalPages && (
              <a href={buildHref({ q, status, page: String(page + 1) })}
                className="px-3 py-1.5 border border-[#ECEAE9] rounded-lg hover:border-[#B0AEA9] transition-colors">
                Próxima →
              </a>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
