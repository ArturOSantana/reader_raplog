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
 * Dispara o processamento de uma solicitação LGPD (exportação ou exclusão).
 * Spec §11: prazo de 15 dias para exportação, 30 dias para exclusão.
 */
export async function processLgpdRequest(formData: FormData): Promise<void> {
  const { supabase, user } = await requireAdmin()

  const requestId = formData.get('request_id') as string
  const action    = formData.get('action') as 'export' | 'delete'

  if (!requestId || !['export', 'delete'].includes(action)) return

  await supabase
    .from('lgpd_requests')
    .update({ status: 'processing', processed_by: user.id })
    .eq('id', requestId)

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const serviceKey  = process.env.SUPABASE_SERVICE_ROLE_KEY

  try {
    const res = await fetch(`${supabaseUrl}/functions/v1/process-lgpd`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ request_id: requestId, action }),
    })

    if (!res.ok) {
      const txt = await res.text()
      await supabase
        .from('lgpd_requests')
        .update({ status: 'failed', notes: txt.slice(0, 500) })
        .eq('id', requestId)
      return
    }
  } catch (err) {
    await supabase
      .from('lgpd_requests')
      .update({ status: 'failed', notes: String(err).slice(0, 500) })
      .eq('id', requestId)
    return
  }

  await supabase.from('audit_logs').insert({
    actor_id: user.id,
    action: action === 'export' ? 'user.data_exported' : 'user.account_deleted',
    target_id: requestId,
    metadata: { triggered_by: 'admin', action },
  })

  revalidatePath('/lgpd')
}

/** Rejeita uma solicitação LGPD com justificativa */
export async function rejectLgpdRequest(formData: FormData): Promise<void> {
  const { supabase, user } = await requireAdmin()

  const requestId = formData.get('request_id') as string
  const notes     = (formData.get('notes') as string)?.trim() || 'Rejeitado pelo administrador.'

  await supabase
    .from('lgpd_requests')
    .update({
      status: 'failed',
      processed_by: user.id,
      processed_at: new Date().toISOString(),
      notes,
    })
    .eq('id', requestId)

  revalidatePath('/lgpd')
}
