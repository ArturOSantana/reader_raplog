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

/**
 * Envia um push notification manual para um usuário ou todos.
 * Spec §15: Push Notifications — enviar push manual, ver fila.
 */
export async function sendManualPush(formData: FormData): Promise<void> {
  const { supabase, user } = await requireAdmin()

  const title      = (formData.get('title') as string)?.trim()
  const body       = (formData.get('body') as string)?.trim()
  const targetType = (formData.get('target_type') as string) // 'user' | 'all'
  const userId     = (formData.get('user_id') as string)?.trim() || null

  if (!title || !body) return
  if (targetType === 'user' && !userId) return

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const serviceKey  = process.env.SUPABASE_SERVICE_ROLE_KEY

  const payload: Record<string, unknown> = { title, body }
  if (targetType === 'user') {
    payload.user_id = userId
  }

  try {
    const res = await fetch(`${supabaseUrl}/functions/v1/push-notification`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    })

    if (!res.ok) return

    const result = await res.json()

    await supabase.from('audit_logs').insert({
      actor_id: user.id,
      action: 'admin.feature_flag_toggled',
      metadata: {
        type: 'manual_push',
        target_type: targetType,
        target_user_id: userId,
        title,
        sent: result.sent ?? 0,
        failed: result.failed ?? 0,
      },
    })
  } catch {
    // erro de rede — falha silenciosa, revalidação não ocorre
    return
  }

  revalidatePath('/push')
}
