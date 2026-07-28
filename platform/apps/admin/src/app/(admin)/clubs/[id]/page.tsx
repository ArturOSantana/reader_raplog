import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate, timeAgo, clubCategoryLabel } from '@lumen/ui'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import type { Metadata } from 'next'
import { closeClub, archiveClub, deleteClub, transferOwnership } from './actions'

export const metadata: Metadata = { title: 'Detalhe do Clube · Admin Lumen' }

export default async function ClubDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ action?: string }>
}) {
  const { id } = await params
  const { action } = await searchParams
  const supabase = await createServerSupabase()

  const [
    { data: club },
    { data: members },
    { data: checkins },
  ] = await Promise.all([
    supabase
      .from('book_clubs')
      .select('id, name, description, category, status, visibility, invite_code, cover_url, current_book_title, current_book_author, member_count, created_at')
      .eq('id', id)
      .single(),
    supabase
      .from('book_club_members')
      .select('user_id, role, joined_at, profile:profiles(username, full_name)')
      .eq('club_id', id)
      .order('joined_at', { ascending: false })
      .limit(50),
    supabase
      .from('book_club_checkins')
      .select('id, user_id, created_at, profile:profiles(username)')
      .eq('club_id', id)
      .order('created_at', { ascending: false })
      .limit(10),
  ])

  if (!club) notFound()

  const statusBadge: Record<string, string> = {
    active: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
    on_vacation: 'bg-[#8B5E2E]/10 text-[#8B5E2E]',
    closed: 'bg-[#F2F1EF] text-[#B0AEA9]',
    archived: 'bg-[#F2F1EF] text-[#B0AEA9]',
  }
  const statusLabel: Record<string, string> = {
    active: 'Ativo', on_vacation: 'Férias', closed: 'Encerrado', archived: 'Arquivado',
  }
  const memberRoleBadge: Record<string, string> = {
    owner: 'bg-[#1A1918]/10 text-[#1A1918]',
    admin: 'bg-[#3D6B5A]/10 text-[#3D6B5A]',
    member: 'bg-[#F2F1EF] text-[#6B6863]',
  }
  const memberRoleLabel: Record<string, string> = {
    owner: 'Dono', admin: 'Admin', member: 'Membro',
  }
  const visibilityLabel: Record<string, string> = {
    public: 'Público', private: 'Privado', invite_only: 'Por convite',
  }

  type Member = {
    user_id: string
    role: string
    joined_at: string
    profile: { username: string; full_name: string | null } | null
  }
  type Checkin = {
    id: string
    user_id: string
    created_at: string
    profile: { username: string } | null
  }

  const typedMembers = (members ?? []) as unknown as Member[]
  const typedCheckins = (checkins ?? []) as unknown as Checkin[]
  const owner = typedMembers.find((m) => m.role === 'owner')

  const actionMsgs: Record<string, string> = {
    closed: '✓ Clube encerrado',
    archived: '✓ Clube arquivado',
    deleted: '✓ Clube excluído',
    transferred: '✓ Ownership transferido',
  }

  const isActive = club.status === 'active' || club.status === 'on_vacation'

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-6">
        <Link href="/clubs" className="hover:text-[#3D6B5A]">Clubes</Link>
        <span>/</span>
        <span className="text-[#1A1918]">{club.name}</span>
      </div>

      {/* Toast de feedback */}
      {action && actionMsgs[action] && (
        <div className="bg-[#3D6B5A]/10 border border-[#3D6B5A]/30 text-[#3D6B5A] rounded-xl px-4 py-3 text-sm font-medium mb-6">
          {actionMsgs[action]}
        </div>
      )}

      {/* Header do clube */}
      <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="flex items-center gap-3 flex-wrap mb-2">
              <h1 className="font-[Fraunces] text-2xl font-bold text-[#1A1918]">{club.name}</h1>
              <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${statusBadge[club.status] ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                {statusLabel[club.status] ?? club.status}
              </span>
              <span className="text-[10px] font-[IBM_Plex_Mono] text-[#6B6863] bg-[#F2F1EF] px-2 py-0.5 rounded-full">
                {visibilityLabel[club.visibility] ?? club.visibility}
              </span>
            </div>
            {club.description && <p className="text-sm text-[#6B6863] max-w-xl">{club.description}</p>}
            <div className="flex items-center gap-4 mt-3 text-xs text-[#6B6863] font-[IBM_Plex_Mono]">
              <span>{clubCategoryLabel(club.category)}</span>
              <span>{club.member_count ?? typedMembers.length} membros</span>
              <span>Criado {formatDate(club.created_at)}</span>
            </div>
            {club.current_book_title && (
              <div className="mt-3 bg-[#F2F1EF] rounded-lg px-4 py-2 inline-flex items-center gap-2">
                <span className="text-sm">📖</span>
                <div>
                  <p className="text-xs font-medium text-[#1A1918]">{club.current_book_title}</p>
                  {club.current_book_author && <p className="text-[10px] text-[#6B6863]">{club.current_book_author}</p>}
                </div>
              </div>
            )}
          </div>
          {club.invite_code && (
            <div className="flex-shrink-0 text-right">
              <p className="text-[10px] font-[IBM_Plex_Mono] text-[#6B6863] mb-1">Código de convite</p>
              <code className="text-xs font-[IBM_Plex_Mono] bg-[#F2F1EF] px-3 py-1 rounded-lg text-[#1A1918]">
                {club.invite_code}
              </code>
            </div>
          )}
        </div>
      </div>

      {/* ─── Ações administrativas ─────────────────── */}
      <section className="bg-white border border-[#ECEAE9] rounded-2xl p-6 mb-6">
        <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-5">Ações</h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {/* Encerrar */}
          {isActive && (
            <div className="border border-[#ECEAE9] rounded-xl p-4">
              <p className="text-sm font-medium text-[#1A1918] mb-1">Encerrar clube</p>
              <p className="text-xs text-[#6B6863] mb-3">O clube fica inativo mas os dados são preservados.</p>
              <form action={closeClub}>
                <input type="hidden" name="club_id" value={id} />
                <button type="submit"
                  className="text-xs font-[IBM_Plex_Mono] border border-[#8B5E2E] text-[#8B5E2E] px-4 py-2 rounded-lg hover:bg-[#8B5E2E]/10 transition-colors">
                  Encerrar
                </button>
              </form>
            </div>
          )}

          {/* Arquivar */}
          {club.status !== 'archived' && (
            <div className="border border-[#ECEAE9] rounded-xl p-4">
              <p className="text-sm font-medium text-[#1A1918] mb-1">Arquivar clube</p>
              <p className="text-xs text-[#6B6863] mb-3">Arquiva o clube permanentemente. Não aparece em buscas.</p>
              <form action={archiveClub}>
                <input type="hidden" name="club_id" value={id} />
                <button type="submit"
                  className="text-xs font-[IBM_Plex_Mono] border border-[#B0AEA9] text-[#6B6863] px-4 py-2 rounded-lg hover:border-[#8B5E2E] hover:text-[#8B5E2E] transition-colors">
                  Arquivar
                </button>
              </form>
            </div>
          )}

          {/* Deletar */}
          <div className="border border-[#ECEAE9] rounded-xl p-4">
            <p className="text-sm font-medium text-[#8B2E2E] mb-1">Excluir clube</p>
            <p className="text-xs text-[#6B6863] mb-3">Remove permanentemente o clube e todos os membros.</p>
            <form action={deleteClub}>
              <input type="hidden" name="club_id" value={id} />
              <button type="submit"
                className="text-xs font-[IBM_Plex_Mono] border border-[#8B2E2E] text-[#8B2E2E] px-4 py-2 rounded-lg hover:bg-[#8B2E2E]/10 transition-colors">
                Excluir
              </button>
            </form>
          </div>

          {/* Transferir ownership */}
          {owner && typedMembers.filter((m) => m.role !== 'owner').length > 0 && (
            <div className="border border-[#ECEAE9] rounded-xl p-4 sm:col-span-2 lg:col-span-3">
              <p className="text-sm font-medium text-[#1A1918] mb-1">Transferir ownership</p>
              <p className="text-xs text-[#6B6863] mb-3">
                Dono atual: <span className="font-medium">@{owner.profile?.username}</span>
              </p>
              <form action={transferOwnership} className="flex gap-2 flex-wrap">
                <input type="hidden" name="club_id" value={id} />
                <input type="hidden" name="current_owner_id" value={owner.user_id} />
                <select
                  name="new_owner_id"
                  className="border border-[#ECEAE9] rounded-lg px-3 py-1.5 text-xs focus:outline-none focus:border-[#3D6B5A]"
                >
                  {typedMembers
                    .filter((m) => m.role !== 'owner')
                    .map((m) => (
                      <option key={m.user_id} value={m.user_id}>
                        @{m.profile?.username ?? m.user_id.slice(0, 8)} ({memberRoleLabel[m.role] ?? m.role})
                      </option>
                    ))}
                </select>
                <button type="submit"
                  className="text-xs font-[IBM_Plex_Mono] bg-[#1A1918] text-white px-4 py-2 rounded-lg hover:bg-[#2C2B29] transition-colors">
                  Transferir
                </button>
              </form>
            </div>
          )}
        </div>
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Membros */}
        <section>
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
            Membros ({typedMembers.length})
          </h2>
          {typedMembers.length > 0 ? (
            <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
              <div className="divide-y divide-[#ECEAE9]">
                {typedMembers.map((m) => (
                  <div key={m.user_id} className="px-4 py-3 flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-[#1A1918]">@{m.profile?.username ?? '?'}</p>
                      {m.profile?.full_name && <p className="text-xs text-[#6B6863]">{m.profile.full_name}</p>}
                    </div>
                    <div className="flex items-center gap-2 flex-shrink-0">
                      <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${memberRoleBadge[m.role] ?? 'bg-[#F2F1EF] text-[#B0AEA9]'}`}>
                        {memberRoleLabel[m.role] ?? m.role}
                      </span>
                      <span className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">
                        {timeAgo(m.joined_at)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="bg-[#F2F1EF] rounded-2xl p-6 text-center text-[#6B6863] text-sm">Sem membros.</div>
          )}
        </section>

        {/* Check-ins recentes */}
        <section>
          <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918] mb-4">
            Check-ins recentes
          </h2>
          {typedCheckins.length > 0 ? (
            <div className="bg-white border border-[#ECEAE9] rounded-2xl overflow-hidden">
              <div className="divide-y divide-[#ECEAE9]">
                {typedCheckins.map((c) => (
                  <div key={c.id} className="px-4 py-3 flex items-center justify-between">
                    <p className="text-sm text-[#1A1918]">@{c.profile?.username ?? '?'}</p>
                    <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">{timeAgo(c.created_at)}</p>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="bg-[#F2F1EF] rounded-2xl p-6 text-center text-[#6B6863] text-sm">Sem check-ins.</div>
          )}
        </section>
      </div>
    </div>
  )
}
