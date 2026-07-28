import { createServerSupabase } from '@lumen/supabase/server'
import type { Metadata } from 'next'

interface PageProps {
  searchParams: Promise<{ q?: string; page?: string }>
}

export const metadata: Metadata = {
  title: 'Clubes de Leitura · Lumen',
  description: 'Encontre clubes de leitura públicos na plataforma Lumen e leia em comunidade.',
}

export const revalidate = 3600

const PAGE_SIZE = 18

export default async function ClubsIndexPage({ searchParams }: PageProps) {
  const { q = '', page = '1' } = await searchParams
  const currentPage = Math.max(1, parseInt(page, 10))
  const offset = (currentPage - 1) * PAGE_SIZE

  const supabase = await createServerSupabase()

  let query = supabase
    .from('book_clubs')
    .select('id, slug, name, description, cover_url, category, current_book_title, current_book_cover_url', { count: 'exact' })
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .range(offset, offset + PAGE_SIZE - 1)

  if (q.trim()) {
    query = query.ilike('name', `%${q.trim()}%`)
  }

  const { data: clubs, count } = await query
  const totalPages = Math.ceil((count ?? 0) / PAGE_SIZE)

  const { clubCategoryLabel } = await import('@lumen/ui')

  return (
    <main className="min-h-screen bg-[#FAF9F7]">
      <nav className="border-b border-[#ECEAE9] bg-[#FAF9F7] sticky top-0 z-50">
        <div className="max-w-5xl mx-auto px-6 h-14 flex items-center justify-between">
          <a href="/" className="font-[Fraunces] font-bold text-xl text-[#1A1918]">lumen</a>
          <a href="https://app.lumen.app" className="text-sm text-[#6B6863] hover:text-[#1A1918]">
            Entrar
          </a>
        </div>
      </nav>

      <div className="max-w-5xl mx-auto px-6 py-12">
        <div className="mb-10">
          <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
            Lumen
          </p>
          <h1 className="font-[Fraunces] text-5xl font-bold text-[#1A1918] mb-4">
            Clubes de Leitura
          </h1>
          <p className="text-[#6B6863] text-lg max-w-xl">
            {count ? `${count.toLocaleString('pt-BR')} clube${count !== 1 ? 's' : ''} ativo${count !== 1 ? 's' : ''}` : 'Leia em comunidade.'}
          </p>
        </div>

        {/* Busca */}
        <form method="GET" className="mb-8">
          <div className="flex gap-2 max-w-xl">
            <input
              name="q"
              defaultValue={q}
              placeholder="Buscar clubes..."
              className="flex-1 border border-[#ECEAE9] rounded-xl px-4 py-3 text-sm bg-white focus:outline-none focus:border-[#3D6B5A]"
            />
            <button
              type="submit"
              className="bg-[#1A1918] text-white px-5 py-3 rounded-xl text-sm hover:bg-[#3D6B5A] transition-colors"
            >
              Buscar
            </button>
            {q && (
              <a
                href="/clubs"
                className="px-4 py-3 rounded-xl border border-[#ECEAE9] text-sm text-[#6B6863] hover:bg-[#F2F1EF]"
              >
                ×
              </a>
            )}
          </div>
        </form>

        {/* Grade */}
        {!clubs?.length ? (
          <div className="text-center py-20">
            <p className="font-[Fraunces] text-2xl text-[#1A1918] mb-2">Nenhum clube encontrado</p>
            <p className="text-sm text-[#6B6863]">Tente um termo diferente.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 mb-10">
            {clubs.map((club) => (
              <a
                key={club.id}
                href={`/clubs/${club.slug ?? club.id}`}
                className="group bg-white border border-[#ECEAE9] rounded-2xl p-5 hover:border-[#B0AEA9] transition-colors"
              >
                <div className="flex gap-4 items-start mb-4">
                  {club.cover_url ? (
                    <img
                      src={club.cover_url}
                      alt={club.name}
                      className="w-12 h-12 rounded-xl object-cover flex-shrink-0"
                    />
                  ) : (
                    <div className="w-12 h-12 bg-[#E8F0EE] rounded-xl flex items-center justify-center flex-shrink-0">
                      <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-lg">
                        {club.name[0]}
                      </span>
                    </div>
                  )}
                  <div className="min-w-0">
                    <h2 className="font-[Fraunces] font-semibold text-[#1A1918] group-hover:text-[#3D6B5A] transition-colors truncate">
                      {club.name}
                    </h2>
                    <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono]">
                      {clubCategoryLabel(club.category)}
                    </p>
                  </div>
                </div>

                {club.description && (
                  <p className="text-xs text-[#6B6863] mb-3 line-clamp-2 leading-relaxed">
                    {club.description}
                  </p>
                )}

                {club.current_book_title && (
                  <div className="flex gap-3 items-center bg-[#F2F1EF] rounded-xl p-3">
                    {club.current_book_cover_url && (
                      <img
                        src={club.current_book_cover_url}
                        alt={club.current_book_title}
                        className="w-8 h-11 object-cover rounded"
                      />
                    )}
                    <div className="min-w-0">
                      <p className="text-[9px] font-[IBM_Plex_Mono] text-[#3D6B5A] uppercase tracking-wider">
                        Lendo agora
                      </p>
                      <p className="text-xs font-medium text-[#1A1918] truncate">
                        {club.current_book_title}
                      </p>
                    </div>
                  </div>
                )}
              </a>
            ))}
          </div>
        )}

        {/* Paginação */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between">
            <p className="text-xs font-[IBM_Plex_Mono] text-[#B0AEA9]">
              Pág. {currentPage} de {totalPages}
            </p>
            <div className="flex gap-2">
              {currentPage > 1 && (
                <a
                  href={`/clubs?page=${currentPage - 1}${q ? `&q=${encodeURIComponent(q)}` : ''}`}
                  className="text-xs font-[IBM_Plex_Mono] px-4 py-2 border border-[#ECEAE9] rounded-lg hover:bg-[#F2F1EF] text-[#1A1918] bg-white"
                >
                  ← Anterior
                </a>
              )}
              {currentPage < totalPages && (
                <a
                  href={`/clubs?page=${currentPage + 1}${q ? `&q=${encodeURIComponent(q)}` : ''}`}
                  className="text-xs font-[IBM_Plex_Mono] px-4 py-2 border border-[#ECEAE9] rounded-lg hover:bg-[#F2F1EF] text-[#1A1918] bg-white"
                >
                  Próxima →
                </a>
              )}
            </div>
          </div>
        )}
      </div>
    </main>
  )
}
