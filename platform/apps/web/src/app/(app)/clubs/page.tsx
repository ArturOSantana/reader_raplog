import { redirect } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { createServerSupabase } from '@lumen/supabase/server'
import { clubCategoryLabel } from '@lumen/ui'
import type { BookClub } from '@lumen/types'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Clubes · Lumen Web' }

export default async function WebClubsPage() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: memberships } = await supabase
    .from('book_club_members')
    .select('role, club:book_clubs(id, slug, name, description, cover_url, category, status, current_book_title, current_book_author, current_book_cover_url)')
    .eq('user_id', user.id)

  type Row = { role: string; club: BookClub }
  const rows = (memberships as unknown as Row[]) ?? []

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="flex items-center justify-between mb-8">
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Clubes</h1>
        <a href="https://lumen.app/clubs" className="text-sm text-[#3D6B5A] hover:underline">
          Explorar clubes públicos →
        </a>
      </div>

      {rows.length === 0 && (
        <div className="text-center py-24 text-[#6B6863]">
          <p className="font-[Fraunces] text-xl mb-2">Nenhum clube ainda</p>
          <p className="text-sm">Entre em clubes pelo app Lumen no celular.</p>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {rows.map(({ role, club }) => (
          <Link
            key={club.id}
            href={`/clubs/${club.slug ?? club.id}`}
            className="bg-[#FAF9F7] border border-[#ECEAE9] rounded-lg p-5 hover:border-[#B0AEA9]"
          >
            <div className="flex gap-4 items-start mb-3">
              {club.cover_url ? (
                <Image
                  src={club.cover_url}
                  alt={club.name}
                  width={48}
                  height={48}
                  className="rounded object-cover flex-shrink-0"
                />
              ) : (
                <div className="w-12 h-12 bg-[#E8F0EE] rounded flex items-center justify-center flex-shrink-0">
                  <span className="font-[Fraunces] font-bold text-[#3D6B5A] text-lg">{club.name[0]}</span>
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <h2 className="font-[Fraunces] font-semibold text-[#1A1918] truncate">{club.name}</h2>
                  {(role === 'owner' || role === 'admin') && (
                    <span className="text-[10px] font-[IBM_Plex_Mono] text-[#8B5E2E] flex-shrink-0">
                      {role === 'owner' ? 'Dono' : 'Admin'}
                    </span>
                  )}
                </div>
                <p className="text-xs text-[#6B6863]">{clubCategoryLabel(club.category)}</p>
              </div>
            </div>
            {club.current_book_title && (
              <div className="flex gap-3 items-center bg-[#F2F1EF] rounded-xl p-3">
                {club.current_book_cover_url && (
                  <Image
                    src={club.current_book_cover_url}
                    alt={club.current_book_title}
                    width={32}
                    height={44}
                    className="rounded-md object-cover"
                  />
                )}
                <div className="min-w-0">
                  <p className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A] uppercase tracking-wider">
                    Lendo agora
                  </p>
                  <p className="text-xs font-medium text-[#1A1918] truncate">{club.current_book_title}</p>
                </div>
              </div>
            )}
          </Link>
        ))}
      </div>
    </div>
  )
}
