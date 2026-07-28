// Lumen Platform — Edge Function: process-lgpd
// Spec §11: LGPD — direitos de acesso e esquecimento
// Spec §10: Todo processamento gera audit_log imutável

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Requer service_role ou autenticação admin
  const authHeader = req.headers.get('authorization')
  if (authHeader !== `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  let body: { request_id: string; action: 'export' | 'delete' }
  try {
    body = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  const { request_id, action } = body

  const { data: lgpdRequest } = await supabase
    .from('lgpd_requests')
    .select('id, user_id, type, status')
    .eq('id', request_id)
    .single()

  if (!lgpdRequest || lgpdRequest.status !== 'pending') {
    return new Response('Request not found or already processed', { status: 404 })
  }

  // Marca como em processamento
  await supabase.from('lgpd_requests')
    .update({ status: 'processing' })
    .eq('id', request_id)

  const userId = lgpdRequest.user_id

  try {
    if (action === 'export') {
      await processExport(request_id, userId)
    } else {
      await processDeletion(request_id, userId)
    }
  } catch (err) {
    console.error({ level: 'error', service: 'lgpd', action, request_id, error: String(err) })

    await supabase.from('lgpd_requests')
      .update({ status: 'failed', notes: String(err) })
      .eq('id', request_id)

    return new Response('Processing failed', { status: 500 })
  }

  return new Response(JSON.stringify({ processed: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})

async function processExport(requestId: string, userId: string) {
  // Coleta todos os dados do usuário (spec §11: direito de acesso)
  const [
    { data: profile },
    { data: books },
    { data: sessions },
    { data: notes },
    { data: highlights },
    { data: reviews },
    { data: goals },
  ] = await Promise.all([
    supabase.from('profiles').select('*').eq('id', userId).single(),
    supabase.from('books').select('*').eq('user_id', userId),
    supabase.from('reading_sessions').select('*').eq('user_id', userId),
    supabase.from('notes').select('*').eq('user_id', userId),
    supabase.from('highlights').select('*').eq('user_id', userId),
    supabase.from('reviews').select('*').eq('user_id', userId),
    supabase.from('goals').select('*').eq('user_id', userId),
  ])

  const exportData = {
    exported_at: new Date().toISOString(),
    schema_version: '1.0',
    user: profile,
    library: books ?? [],
    reading_sessions: sessions ?? [],
    notes: notes ?? [],
    highlights: highlights ?? [],
    reviews: reviews ?? [],
    goals: goals ?? [],
  }

  // Upload para Storage (bucket privado com URL assinada)
  const fileName = `lgpd-export-${userId}-${Date.now()}.json`
  const { error: uploadError } = await supabase.storage
    .from('lgpd-exports')
    .upload(fileName, JSON.stringify(exportData, null, 2), {
      contentType: 'application/json',
      upsert: true,
    })

  if (uploadError) throw uploadError

  // URL assinada com validade de 24h
  const { data: signedUrl } = await supabase.storage
    .from('lgpd-exports')
    .createSignedUrl(fileName, 86400)

  // Atualiza a solicitação com URL
  await supabase.from('lgpd_requests')
    .update({
      status: 'completed',
      processed_at: new Date().toISOString(),
      export_url: signedUrl?.signedUrl,
    })
    .eq('id', requestId)

  // Audit log
  await supabase.from('audit_logs').insert({
    actor_id: userId,
    action: 'user.data_exported',
    metadata: { request_id: requestId },
  })

  // Dispara email ao usuário (via send-email Edge Function)
  await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-email`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      to: (profile as { email?: string })?.email,
      subject: 'Seus dados do Lumen estão prontos',
      template: 'lgpd_export_ready',
      data: { export_url: signedUrl?.signedUrl },
    }),
  })
}

async function processDeletion(requestId: string, userId: string) {
  // Spec §11: Exclusão definitiva em até 30 dias
  // Anonimiza dados pessoais; mantém mínimo legal (ex: histórico de pagamentos)

  const anonymizedUsername = `deleted_${userId.slice(0, 8)}`

  // 1. Anonimiza o perfil
  await supabase.from('profiles').update({
    username:        anonymizedUsername,
    full_name:       null,
    bio:             null,
    avatar_url:      null,
    email:           null,
    status:          'banned',
    privacy_profile: 'private',
    privacy_library: 'private',
    privacy_reviews: 'private',
    privacy_stats:   'private',
  }).eq('id', userId)

  // 2. Remove dados pessoais irreversíveis
  await Promise.all([
    supabase.from('notes').delete().eq('user_id', userId),
    supabase.from('highlights').delete().eq('user_id', userId),
    supabase.from('push_tokens').delete().eq('user_id', userId),
    supabase.from('follows').delete().or(`follower_id.eq.${userId},following_id.eq.${userId}`),
  ])

  // 3. Anonimiza reviews (mantém conteúdo se público, remove vínculo)
  await supabase.from('reviews').update({ user_id: null }).eq('user_id', userId)

  // 4. Mantém subscriptions para compliance financeiro (5 anos — spec §11)
  // Apenas marca como cancelada
  await supabase.from('subscriptions')
    .update({ status: 'canceled' })
    .eq('user_id', userId)

  // 5. Audit log de exclusão
  await supabase.from('audit_logs').insert({
    actor_id: userId,
    action: 'user.account_deleted',
    metadata: { request_id: requestId, anonymized_username: anonymizedUsername },
  })

  // 6. Atualiza solicitação
  await supabase.from('lgpd_requests')
    .update({ status: 'completed', processed_at: new Date().toISOString() })
    .eq('id', requestId)

  // 7. Deleta a conta do auth.users via service_role
  await supabase.auth.admin.deleteUser(userId)

  console.log({ level: 'info', service: 'lgpd', action: 'deletion', user_id: userId })
}
