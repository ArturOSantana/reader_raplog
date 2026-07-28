'use server'

import { redirect } from 'next/navigation'
import { revalidatePath } from 'next/cache'
import { createServerSupabase } from '@lumen/supabase/server'
import { isAdminRole } from '@lumen/types'

async function requireAdmin() {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  if (!isAdminRole(profile?.role)) redirect('/login?error=unauthorized')
  return { supabase, user }
}

/** Gera um novo código de convite */
export async function createInvite(formData: FormData): Promise<void> {
  const { supabase, user } = await requireAdmin()

  const type      = (formData.get('type') as string) || 'early_access'
  const email     = (formData.get('email') as string)?.trim() || null
  const maxUses   = parseInt(formData.get('max_uses') as string) || 1
  const notes     = (formData.get('notes') as string)?.trim() || null
  const expiresIn = parseInt(formData.get('expires_days') as string) || 30

  // Código único: 5 chars aleatórios legíveis
  const code = Array.from(crypto.getRandomValues(new Uint8Array(5)))
    .map((b) => 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'[b % 31])
    .join('')

  const expiresAt = new Date()
  expiresAt.setDate(expiresAt.getDate() + expiresIn)

  await supabase.from('invites').insert({
    code,
    type,
    email,
    max_uses: maxUses,
    notes,
    expires_at: expiresAt.toISOString(),
    created_by: user.id,
    status: 'pending',
  })

  revalidatePath('/invites')
}

/** Revoga um convite (impede uso) */
export async function revokeInvite(formData: FormData): Promise<void> {
  const { supabase, user } = await requireAdmin()

  const inviteId = formData.get('invite_id') as string

  await supabase
    .from('invites')
    .update({ status: 'revoked' })
    .eq('id', inviteId)

  await supabase.from('audit_logs').insert({
    actor_id: user.id,
    action: 'admin.feature_flag_toggled',
    target_id: inviteId,
    metadata: { type: 'invite_revoked' },
  })

  revalidatePath('/invites')
}

/** Estende a validade de um convite */
export async function extendInvite(formData: FormData): Promise<void> {
  const { supabase } = await requireAdmin()

  const inviteId  = formData.get('invite_id') as string
  const extraDays = parseInt(formData.get('days') as string) || 7

  const { data: invite } = await supabase
    .from('invites').select('expires_at').eq('id', inviteId).single()

  const base = invite?.expires_at ? new Date(invite.expires_at) : new Date()
  base.setDate(base.getDate() + extraDays)

  await supabase
    .from('invites')
    .update({ expires_at: base.toISOString(), status: 'pending' })
    .eq('id', inviteId)

  revalidatePath('/invites')
}
