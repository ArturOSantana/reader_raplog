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

/** Liga/desliga uma feature flag */
export async function toggleFlag(formData: FormData) {
  const { supabase, user } = await requireAdmin()

  const flagId  = formData.get('flag_id') as string
  const enabled = formData.get('enabled') === 'true'

  const { error } = await supabase
    .from('feature_flags')
    .update({ enabled: !enabled })
    .eq('id', flagId)

  if (error) return { error: error.message }

  await supabase.from('audit_logs').insert({
    actor_id: user.id,
    action: 'admin.feature_flag_toggled',
    target_id: flagId,
    metadata: { enabled: !enabled },
  })

  revalidatePath('/feature-flags')
  return { ok: true }
}

/** Ajusta o percentual de rollout (0–100) */
export async function updateRollout(formData: FormData) {
  const { supabase, user } = await requireAdmin()

  const flagId  = formData.get('flag_id') as string
  const percent = parseInt(formData.get('rollout_percent') as string)

  if (isNaN(percent) || percent < 0 || percent > 100) {
    return { error: 'Percentual inválido (0–100).' }
  }

  const { error } = await supabase
    .from('feature_flags')
    .update({ rollout_percent: percent })
    .eq('id', flagId)

  if (error) return { error: error.message }

  await supabase.from('audit_logs').insert({
    actor_id: user.id,
    action: 'admin.feature_flag_toggled',
    target_id: flagId,
    metadata: { rollout_percent: percent },
  })

  revalidatePath('/feature-flags')
  return { ok: true }
}

/** Cria uma nova feature flag */
export async function createFlag(formData: FormData) {
  const { supabase } = await requireAdmin()

  const key         = (formData.get('key') as string)?.trim().toLowerCase().replace(/\s+/g, '_')
  const description = (formData.get('description') as string)?.trim() ?? ''

  if (!key || !/^[a-z0-9_]+$/.test(key)) {
    return { error: 'Chave inválida. Use apenas letras, números e _.' }
  }

  const { error } = await supabase.from('feature_flags').insert({
    key,
    description,
    enabled: false,
    rollout_percent: 0,
  })

  if (error) return { error: error.code === '23505' ? 'Já existe uma flag com esta chave.' : error.message }

  revalidatePath('/feature-flags')
  return { ok: true }
}

/** Remove uma feature flag */
export async function deleteFlag(formData: FormData) {
  const { supabase, user } = await requireAdmin()

  const flagId = formData.get('flag_id') as string

  await supabase.from('audit_logs').insert({
    actor_id: user.id,
    action: 'admin.feature_flag_toggled',
    target_id: flagId,
    metadata: { deleted: true },
  })

  const { error } = await supabase
    .from('feature_flags')
    .delete()
    .eq('id', flagId)

  if (error) return { error: error.message }

  revalidatePath('/feature-flags')
  return { ok: true }
}
