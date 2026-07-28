import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate, timeAgo } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Usuários · Admin Lumen' }

export default async function AdminUsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; page?: string }>
}) {
  const { q, page: pageParam } = await searchParams
  const page = Math.max(1, parseInt(pageParam ?? '1'))
  const pageSize = 20
  const offset = (page - 1) * pageSize

  const supabase = await createServerSupabase()

  let query = supabase
    .from('profiles')
    .select('id, username, full_name, email, role, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(offset, offset + pageSize - 1)

  if (q) {
    query = query.or(`username.ilike.%${q}%,email.ilike.%${q}%,full_name.ilike.%${q}%`)
  }

  const { data: users, count } = await query
  const totalPages = Math.ceil((count ?? 0) / pageSize)

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="flex items-center justify-between mb-8">
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Usuários</h1>
        <span className="text-sm font-[IBM_Plex_Mono] text-[#6B6863]">{count ?? 0} total</span>
      </div>

      <form className="flex gap-2 mb-6 max-w-md">
        <input
          name="q"
          defaultValue={q}
          placeholder="Buscar por username, email ou nome…"
          className="flex-1 border border-[#ECEAE9] rounded px-4 py-2 text-sm focus:outline-none focus:border-[#3D6B5A]"
        />
        <button type="submit" className="bg-[#1A1918] text-white px-5 py-2 rounded text-sm font-medium">
          Buscar
        </button>
      </form>

      <div className="bg-white border border-[#ECEAE9] rounded-lg overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-[#F2F1EF] border-b border-[#ECEAE9]">
            <tr>
              <th className="text-left px-4 py-3 font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest">Usuário</th>
              <th className="text-left px-4 py-3 font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest">Role</th>
              <th className="text-left px-4 py-3 font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest">Criado</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#ECEAE9]">
            {(users ?? []).map((u) => (
              <tr key={u.id} className="hover:bg-[#F2F1EF]">
                <td className="px-4 py-3">
                  <a href={`/users/${u.id}`} className="font-medium text-[#1A1918] hover:text-[#3D6B5A] transition-colors">
                    @{u.username}
                  </a>
                  <p className="text-xs text-[#6B6863]">{u.full_name}</p>
                </td>
                <td className="px-4 py-3">
                  <span className="font-[IBM_Plex_Mono] text-xs text-[#3D6B5A]">{u.role ?? 'user'}</span>
                </td>
                <td className="px-4 py-3 text-xs text-[#6B6863] font-[IBM_Plex_Mono]">
                  {u.created_at ? formatDate(u.created_at) : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="flex gap-2 mt-4 items-center text-sm text-[#6B6863]">
          <span>Página {page} de {totalPages}</span>
          {page > 1 && (
            <a href={`?${q ? `q=${q}&` : ''}page=${page - 1}`} className="text-[#3D6B5A] hover:underline">← Anterior</a>
          )}
          {page < totalPages && (
            <a href={`?${q ? `q=${q}&` : ''}page=${page + 1}`} className="text-[#3D6B5A] hover:underline">Próxima →</a>
          )}
        </div>
      )}
    </div>
  )
}
