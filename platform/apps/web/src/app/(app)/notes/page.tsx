import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'
import { formatDate } from '@lumen/ui'
import type { Note } from '@lumen/types'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Notas · Lumen Web' }

export default async function NotesPage() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: notes } = await supabase
    .from('notes')
    .select('id, type, content, page_number, created_at, book:books(title, author)')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(50)

  type NoteRow = Note & { book: { title: string; author: string | null } | null }
  const rows = (notes as unknown as NoteRow[]) ?? []

  const typeLabel: Record<string, string> = {
    observation: 'Observação',
    reflection: 'Reflexão',
    highlight: 'Destaque',
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="flex items-center justify-between mb-8">
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Notas</h1>
        <span className="text-sm text-[#6B6863] font-[IBM_Plex_Mono]">
          {rows.length} nota{rows.length !== 1 ? 's' : ''}
        </span>
      </div>

      {rows.length === 0 && (
        <div className="text-center py-24 text-[#6B6863]">
          <p className="font-[Fraunces] text-xl mb-2">Nenhuma nota ainda</p>
          <p className="text-sm">Adicione notas durante as sessões no app.</p>
        </div>
      )}

      <div className="space-y-4">
        {rows.map((note) => (
          <div key={note.id} className="bg-white border border-[#ECEAE9] rounded-lg p-5">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-[10px] font-[IBM_Plex_Mono] text-[#3D6B5A] uppercase tracking-widest">
                {typeLabel[note.type] ?? note.type}
              </span>
              {note.page_number && (
                <span className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">
                  p.{note.page_number}
                </span>
              )}
            </div>
            <p className="text-sm text-[#1A1918] leading-relaxed mb-3">{note.content}</p>
            <div className="flex items-center justify-between">
              <p className="text-xs text-[#6B6863] truncate">
                {note.book?.title ?? 'Livro removido'}
              </p>
              <p className="text-xs text-[#B0AEA9] font-[IBM_Plex_Mono] flex-shrink-0 ml-2">
                {formatDate(note.created_at)}
              </p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
