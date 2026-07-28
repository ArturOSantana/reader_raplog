'use server'

import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'
import { isAdminRole } from '@lumen/types'

async function requireAdmin() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  if (!isAdminRole(profile?.role)) redirect('/login?error=unauthorized')
  return { supabase, actorId: user.id }
}

async function writeAuditLog(
  supabase: Awaited<ReturnType<typeof createServerSupabase>>,
  actorId: string,
  targetId: string,
  action: string,
  metadata: Record<string, unknown> = {},
) {
  await supabase.from('audit_logs').insert({
    actor_id: actorId,
    target_id: targetId,
    action,
    metadata,
    created_at: new Date().toISOString(),
  })
}

export async function closeClub(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const clubId = formData.get('club_id') as string

  await supabase
    .from('book_clubs')
    .update({ status: 'closed' })
    .eq('id', clubId)

  await writeAuditLog(supabase, actorId, clubId, 'club.closed', {})
  redirect(`/clubs/${clubId}?action=closed`)
}

export async function archiveClub(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const clubId = formData.get('club_id') as string

  await supabase
    .from('book_clubs')
    .update({ status: 'archived' })
    .eq('id', clubId)

  await writeAuditLog(supabase, actorId, clubId, 'club.archived', {})
  redirect(`/clubs/${clubId}?action=archived`)
}

export async function deleteClub(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const clubId = formData.get('club_id') as string

  // Remove membros antes de deletar (FK constraints)
  await supabase.from('book_club_members').delete().eq('club_id', clubId)
  await supabase.from('book_clubs').delete().eq('id', clubId)

  await writeAuditLog(supabase, actorId, clubId, 'club.deleted', {})
  redirect('/clubs?action=deleted')
}

export async function transferOwnership(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const clubId = formData.get('club_id') as string
  const newOwnerId = formData.get('new_owner_id') as string
  const currentOwnerId = formData.get('current_owner_id') as string

  // Rebaixa owner atual para admin
  await supabase
    .from('book_club_members')
    .update({ role: 'admin' })
    .eq('club_id', clubId)
    .eq('user_id', currentOwnerId)

  // Promove novo owner
  await supabase
    .from('book_club_members')
    .update({ role: 'owner' })
    .eq('club_id', clubId)
    .eq('user_id', newOwnerId)

  await writeAuditLog(supabase, actorId, clubId, 'club.owner_transferred', {
    from: currentOwnerId,
    to: newOwnerId,
  })
  redirect(`/clubs/${clubId}?action=transferred`)
}
