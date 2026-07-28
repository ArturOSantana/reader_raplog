// Lumen Platform — Edge Function: push-notification
// Spec §20: Fila de push notifications com FCM (Android) e APNs (iOS)
// Spec §8: Logs estruturados sem dados sensíveis

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!
const APNS_KEY_ID    = Deno.env.get('APNS_KEY_ID')
const APNS_TEAM_ID   = Deno.env.get('APNS_TEAM_ID')
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') ?? 'app.lumen.ios'

interface PushPayload {
  user_id?: string
  tokens?: string[]          // tokens diretos (alternativo ao user_id)
  title: string
  body: string
  data?: Record<string, string>
  badge?: number
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  let payload: PushPayload
  try {
    payload = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  const { user_id, tokens: directTokens, title, body, data, badge } = payload

  // Resolve tokens: por user_id ou direto
  let tokens: Array<{ token: string; platform: string }> = []

  if (user_id) {
    const { data: pushTokens } = await supabase
      .from('push_tokens')
      .select('token, platform')
      .eq('user_id', user_id)
      .eq('active', true)
    tokens = pushTokens ?? []
  } else if (directTokens?.length) {
    // tokens diretos — assume todos FCM
    tokens = directTokens.map((t) => ({ token: t, platform: 'android' }))
  }

  if (!tokens.length) {
    return new Response(JSON.stringify({ sent: 0, message: 'No tokens found' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let sent = 0
  let failed = 0

  await Promise.allSettled(tokens.map(async ({ token, platform }) => {
    try {
      if (platform === 'android') {
        await sendFCM(token, title, body, data)
      } else {
        await sendAPNs(token, title, body, data, badge)
      }
      sent++
    } catch (err) {
      failed++
      console.error({ level: 'error', service: 'push', platform, error: String(err) })

      // Desativa token inválido
      if (String(err).includes('invalid') || String(err).includes('unregistered')) {
        await supabase.from('push_tokens')
          .update({ active: false })
          .eq('token', token)
      }
    }
  }))

  console.log({ level: 'info', service: 'push', sent, failed, user_id: user_id ?? 'direct' })

  return new Response(JSON.stringify({ sent, failed }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})

async function sendFCM(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
) {
  const res = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      Authorization: `key=${FCM_SERVER_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      to: token,
      notification: { title, body },
      data: data ?? {},
      android: { priority: 'high' },
    }),
  })
  const result = await res.json()
  if (result.failure > 0) {
    const error = result.results?.[0]?.error ?? 'unknown'
    throw new Error(`FCM error: ${error}`)
  }
}

async function sendAPNs(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
  badge?: number,
) {
  // Em produção: usar JWT com chave privada p8 para autenticar com APNs
  // Aqui implementamos a estrutura do request — autenticação via biblioteca dedicada
  const apnsPayload = {
    aps: {
      alert: { title, body },
      badge: badge ?? 0,
      sound: 'default',
    },
    ...data,
  }

  const res = await fetch(`https://api.push.apple.com/3/device/${token}`, {
    method: 'POST',
    headers: {
      'apns-topic': APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'Content-Type': 'application/json',
      // Authorization: `bearer ${apnsJWT}` — gerado com chave p8 em produção
    },
    body: JSON.stringify(apnsPayload),
  })

  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(`APNs error: ${(err as { reason?: string }).reason ?? res.status}`)
  }
}
