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

export async function resolveReport(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const reportId = formData.get('report_id') as string
  const targetId = formData.get('target_id') as string

  await supabase
    .from('reports')
    .update({ status: 'resolved', resolved_at: new Date().toISOString(), resolved_by: actorId })
    .eq('id', reportId)

  await writeAuditLog(supabase, actorId, targetId, 'report.resolved', { report_id: reportId })
  redirect('/moderation?action=resolved')
}

export async function dismissReport(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const reportId = formData.get('report_id') as string
  const targetId = formData.get('target_id') as string

  await supabase
    .from('reports')
    .update({ status: 'dismissed', resolved_at: new Date().toISOString(), resolved_by: actorId })
    .eq('id', reportId)

  await writeAuditLog(supabase, actorId, targetId, 'report.dismissed', { report_id: reportId })
  redirect('/moderation?action=dismissed')
}

export async function markReviewing(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const reportId = formData.get('report_id') as string
  const targetId = formData.get('target_id') as string

  await supabase
    .from('reports')
    .update({ status: 'reviewing' })
    .eq('id', reportId)

  await writeAuditLog(supabase, actorId, targetId, 'report.reviewing', { report_id: reportId })
  redirect('/moderation?action=reviewing')
}

export async function shadowBanUser(formData: FormData) {
  const { supabase, actorId } = await requireAdmin()
  const userId = formData.get('user_id') as string
  const reportId = formData.get('report_id') as string

  // Shadow ban: usuário vê seus posts, ninguém mais vê (spec §16)
  await supabase
    .from('profiles')
    .update({ shadow_banned: true })
    .eq('id', userId)

  await supabase
    .from('reports')
    .update({ status: 'resolved', resolved_at: new Date().toISOString(), resolved_by: actorId })
    .eq('id', reportId)

  await writeAuditLog(supabase, actorId, userId, 'admin.user_shadow_banned', { report_id: reportId })
  redirect('/moderation?action=shadow_banned')
}
