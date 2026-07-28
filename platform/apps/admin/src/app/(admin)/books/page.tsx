import { createServerSupabase } from '@lumen/supabase/server'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Livros · Admin Lumen' }

export default async function AdminBooksPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>
}) {
  const supabase = await createServerSupabase()
  const { q } = await searchParams

  let query = supabase
    .from('books')
    .select('title, author, cover_url, genre, total_pages, created_at')
    .not('author', 'is', null)
    .order('created_at', { ascending: false })
    .limit(200)

  if (q) query = query.ilike('title', `%${q}%`)

  const { data: books } = await query

  // Deduplicação por título+autor
  const seen = new Set<string>()
  const unique = (books ?? []).filter((b) => {
    const key = `${b.title}__${b.author}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })

  const withCover = unique.filter((b) => b.cover_url).length
  const withoutCover = unique.length - withCover

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Livros</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          {unique.length} títulos únicos
          <span className="text-[#B0AEA9]"> · {withCover} com capa · {withoutCover} sem capa</span>
        </p>
      </div>

      {/* Busca */}
      <form className="flex gap-2 mb-6 max-w-sm">
        <input
          name="q"
          defaultValue={q}
          placeholder="Buscar por título…"
          className="flex-1 border border-[#ECEAE9] bg-white rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-[#3D6B5A]"
        />
        <button type="submit" className="bg-[#1A1918] text-white px-5 py-2 rounded-xl text-sm font-medium hover:bg-[#2C2B29] transition-colors">
          Buscar
        </button>
      </form>

      {/* Contadores rápidos */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        {[
          { value: unique.length, label: 'Títulos únicos', color: '#1A1918' },
          { value: withCover, label: 'Com capa', color: '#3D6B5A' },
          { value: withoutCover, label: 'Sem capa', color: withoutCover > 0 ? '#8B2E2E' : '#B0AEA9' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-4">
            <p className="font-[Fraunces] text-2xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Tabela */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[#ECEAE9]">
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Título</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden md:table-cell">Autor</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden sm:table-cell">Gênero</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs hidden lg:table-cell">Páginas</th>
              <th className="text-left p-4 font-[IBM_Plex_Mono] text-[#6B6863] text-xs">Capa</th>
            </tr>
          </thead>
          <tbody>
            {unique.map((book, i) => (
              <tr key={i} className="border-b border-[#ECEAE9]/50 hover:bg-[#FAF9F7] transition-colors">
                <td className="p-4 font-medium text-[#1A1918] max-w-[200px] truncate">{book.title}</td>
                <td className="p-4 text-[#6B6863] hidden md:table-cell">{book.author}</td>
                <td className="p-4 text-[#6B6863] hidden sm:table-cell text-xs">{book.genre ?? '—'}</td>
                <td className="p-4 text-[#6B6863] font-[IBM_Plex_Mono] text-xs hidden lg:table-cell">
                  {book.total_pages ?? '—'}
                </td>
                <td className="p-4">
                  {book.cover_url ? (
                    <span className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A] bg-[#3D6B5A]/10 px-2 py-0.5 rounded-full">✓</span>
                  ) : (
                    <span className="text-[10px] font-[IBM_Plex_Mono] text-[#8B2E2E] bg-[#8B2E2E]/10 px-2 py-0.5 rounded-full">sem capa</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {unique.length === 0 && (
          <div className="p-12 text-center text-[#6B6863] text-sm">Nenhum livro encontrado.</div>
        )}
      </div>
    </div>
  )
}
