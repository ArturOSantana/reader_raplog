'use server'

import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'
import { isAdminRole } from '@lumen/types'

/** Verifica que o caller tem role admin — nunca confia no cliente. */
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

/** Registra ação no audit_log — logs nunca são deletados (spec §10). */
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

export async function suspendUser(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const userId = formData.get('user_id') as string
  const reason = (formData.get('reason') as string) || 'Suspensão administrativa'

  await supabase
    .from('profiles')
    .update({ suspended: true, suspended_at: new Date().toISOString(), suspended_reason: reason })
    .eq('id', userId)

  await writeAuditLog(supabase, actorId, userId, 'admin.user_suspended', { reason })
  redirect(`/users/${userId}?action=suspended`)
}

export async function unsuspendUser(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const userId = formData.get('user_id') as string

  await supabase
    .from('profiles')
    .update({ suspended: false, suspended_at: null, suspended_reason: null })
    .eq('id', userId)

  await writeAuditLog(supabase, actorId, userId, 'admin.user_unsuspended', {})
  redirect(`/users/${userId}?action=unsuspended`)
}

export async function banUser(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const userId = formData.get('user_id') as string
  const reason = (formData.get('reason') as string) || 'Banimento administrativo'

  await supabase
    .from('profiles')
    .update({ banned: true, banned_at: new Date().toISOString(), banned_reason: reason })
    .eq('id', userId)

  await writeAuditLog(supabase, actorId, userId, 'admin.user_banned', { reason })
  redirect(`/users/${userId}?action=banned`)
}

export async function changeUserPlan(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const userId = formData.get('user_id') as string
  const newPlan = formData.get('plan') as string
  const reason = (formData.get('reason') as string) || ''

  await supabase
    .from('subscriptions')
    .upsert({
      user_id: userId,
      plan: newPlan,
      status: 'active',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id' })

  await writeAuditLog(supabase, actorId, userId, 'admin.plan_changed', { plan: newPlan, reason })
  redirect(`/users/${userId}?action=plan_changed`)
}
