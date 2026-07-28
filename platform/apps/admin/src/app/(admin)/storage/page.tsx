import { createServerSupabase } from '@lumen/supabase/server'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Storage · Admin Lumen' }

export default async function StoragePage() {
  const supabase = await createServerSupabase()

  // Capas de livros com e sem URL
  const [
    { count: totalBooks },
    { count: booksWithCover },
    { count: booksWithoutCover },
    { data: orphanCovers },
    { data: recentUploads },
  ] = await Promise.all([
    supabase.from('books').select('*', { count: 'exact', head: true }),
    supabase.from('books').select('*', { count: 'exact', head: true }).not('cover_url', 'is', null),
    supabase.from('books').select('*', { count: 'exact', head: true }).is('cover_url', null),
    // Capas órfãs: cover_url não null mas livro sem user_id conhecido (possível resíduo)
    supabase
      .from('books')
      .select('title, author, cover_url, created_at')
      .not('cover_url', 'is', null)
      .order('created_at', { ascending: false })
      .limit(10),
    // Uploads recentes de avatares/capas
    supabase
      .from('profiles')
      .select('username, avatar_url, updated_at')
      .not('avatar_url', 'is', null)
      .order('updated_at', { ascending: false })
      .limit(10),
  ])

  const coverPct = totalBooks && totalBooks > 0
    ? Math.round(((booksWithCover ?? 0) / totalBooks) * 100)
    : 0

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Storage</h1>
        <p className="text-sm text-[#6B6863] mt-1">Capas, avatares e arquivos temporários</p>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { value: totalBooks ?? 0, label: 'Livros total', color: '#1A1918' },
          { value: booksWithCover ?? 0, label: 'Com capa', color: '#3D6B5A' },
          { value: booksWithoutCover ?? 0, label: 'Sem capa', color: (booksWithoutCover ?? 0) > 0 ? '#8B2E2E' : '#B0AEA9' },
          { value: `${coverPct}%`, label: 'Cobertura', color: coverPct >= 80 ? '#3D6B5A' : '#8B5E2E' },
        ].map(({ value, label, color }) => (
          <div key={label} className="bg-white border border-[#ECEAE9] rounded-2xl p-5">
            <p className="font-[Fraunces] text-2xl font-bold" style={{ color }}>{value}</p>
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Barra de cobertura */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-2">Cobertura de capas</h2>
        <p className="text-xs text-[#6B6863] font-[IBM_Plex_Mono] mb-4">
          {booksWithCover ?? 0} de {totalBooks ?? 0} livros possuem capa
        </p>
        <div className="h-3 bg-[#F2F1EF] rounded-full overflow-hidden">
          <div
            className="h-full bg-[#3D6B5A] rounded-full transition-all"
            style={{ width: `${coverPct}%` }}
          />
        </div>
        <div className="flex justify-between mt-2">
          <span className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A]">{coverPct}% com capa</span>
          <span className="text-[10px] font-[IBM_Plex_Mono] text-[#8B2E2E]">{100 - coverPct}% sem capa</span>
        </div>
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Capas recentes */}
        <section className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
          <div className="p-4 border-b border-[#ECEAE9]">
            <h2 className="font-[Fraunces] text-base font-semibold text-[#1A1918]">
              Capas recentes
            </h2>
          </div>
          <div className="divide-y divide-[#ECEAE9]">
            {(orphanCovers ?? []).map((b, i) => (
              <div key={i} className="px-4 py-3 flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-xs font-medium text-[#1A1918] truncate">{b.title}</p>
                  <p className="text-[10px] text-[#6B6863]">{b.author}</p>
                </div>
                <span className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A] bg-[#3D6B5A]/10 px-2 py-0.5 rounded-full flex-shrink-0">
                  ✓ capa
                </span>
              </div>
            ))}
          </div>
          {(!orphanCovers || orphanCovers.length === 0) && (
            <div className="p-6 text-center text-[#6B6863] text-sm">Nenhum registro.</div>
          )}
        </section>

        {/* Avatares recentes */}
        <section className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
          <div className="p-4 border-b border-[#ECEAE9]">
            <h2 className="font-[Fraunces] text-base font-semibold text-[#1A1918]">
              Avatares recentes
            </h2>
          </div>
          <div className="divide-y divide-[#ECEAE9]">
            {(recentUploads ?? []).map((p) => (
              <div key={p.username} className="px-4 py-3 flex items-center justify-between gap-3">
                <p className="text-xs font-medium text-[#1A1918]">@{p.username}</p>
                <span className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A] bg-[#3D6B5A]/10 px-2 py-0.5 rounded-full flex-shrink-0">
                  ✓ avatar
                </span>
              </div>
            ))}
          </div>
          {(!recentUploads || recentUploads.length === 0) && (
            <div className="p-6 text-center text-[#6B6863] text-sm">Nenhum avatar.</div>
          )}
        </section>
      </div>

      {/* Aviso de limpeza */}
      <div className="mt-6 bg-[#F2F1EF] border border-[#ECEAE9] rounded-2xl p-5">
        <h3 className="font-[Fraunces] text-sm font-semibold text-[#1A1918] mb-2">Limpeza de arquivos temporários</h3>
        <p className="text-xs text-[#6B6863]">
          Arquivos temporários de upload são limpos automaticamente via cron job diário.
          Capas órfãs (sem livro associado) são removidas semanalmente.
          Para limpeza manual, acesse o painel de <strong>Cron Jobs</strong> e force a execução do job <code className="font-[IBM_Plex_Mono]">storage.cleanup</code>.
        </p>
      </div>
    </div>
  )
}
