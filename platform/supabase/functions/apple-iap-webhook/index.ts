// Lumen Platform — Edge Function: apple-iap-webhook
// Spec §17: Sincronização de billing Apple In-App Purchase
// Validação de notificação via App Store Server Notifications v2

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  let payload: AppleNotificationPayload
  try {
    payload = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  // Apple envia um signedPayload JWT — em produção validar com a chave pública da Apple
  // https://developer.apple.com/documentation/appstoreservernotifications
  const signedPayload = payload.signedPayload
  if (!signedPayload) {
    return new Response('Missing signedPayload', { status: 400 })
  }

  // Decodifica o payload JWT (sem verificar assinatura aqui — em produção usar biblioteca JWT)
  const parts = signedPayload.split('.')
  if (parts.length !== 3) return new Response('Invalid JWT format', { status: 400 })

  let notificationData: AppleDecodedPayload
  try {
    const decoded = atob(parts[1]!.replace(/-/g, '+').replace(/_/g, '/'))
    notificationData = JSON.parse(decoded)
  } catch {
    return new Response('Failed to decode payload', { status: 400 })
  }

  const { notificationType, subtype, data } = notificationData
  console.log(`Apple IAP notification: ${notificationType}/${subtype ?? '-'}`)

  try {
    const transactionInfo = decodeJWT<AppleTransactionInfo>(data.signedTransactionInfo)
    const userId = transactionInfo.appAccountToken // UUID do usuário Lumen

    if (!userId) {
      console.error('No appAccountToken in Apple transaction')
      return new Response('OK', { status: 200 })
    }

    switch (notificationType) {
      case 'SUBSCRIBED':
      case 'DID_RENEW': {
        const plan = resolveApplePlan(transactionInfo.productId)
        await supabase.from('subscriptions').upsert({
          user_id: userId,
          plan,
          status: 'active',
          channel: 'apple',
          apple_original_transaction_id: transactionInfo.originalTransactionId,
          current_period_start: new Date(transactionInfo.purchaseDate).toISOString(),
          current_period_end: new Date(transactionInfo.expiresDate ?? transactionInfo.purchaseDate).toISOString(),
        }, { onConflict: 'apple_original_transaction_id' })

        await supabase.from('audit_logs').insert({
          actor_id: userId,
          action: 'payment.approved',
          metadata: { plan, channel: 'apple', type: notificationType },
        })
        break
      }

      case 'DID_FAIL_TO_RENEW': {
        const gracePeriodEnd = new Date()
        gracePeriodEnd.setDate(gracePeriodEnd.getDate() + 3)

        await supabase.from('subscriptions')
          .update({ status: 'past_due', grace_period_end_at: gracePeriodEnd.toISOString() })
          .eq('apple_original_transaction_id', transactionInfo.originalTransactionId)

        await supabase.from('audit_logs').insert({
          actor_id: userId,
          action: 'payment.failed',
          metadata: { channel: 'apple', type: notificationType },
        })
        break
      }

      case 'EXPIRED':
      case 'REVOKE': {
        await supabase.from('subscriptions')
          .update({ status: 'canceled', canceled_at: new Date().toISOString(), plan: 'free' })
          .eq('apple_original_transaction_id', transactionInfo.originalTransactionId)
        break
      }

      case 'REFUND': {
        await supabase.from('subscriptions')
          .update({ status: 'canceled', canceled_at: new Date().toISOString(), plan: 'free' })
          .eq('apple_original_transaction_id', transactionInfo.originalTransactionId)

        await supabase.from('audit_logs').insert({
          actor_id: userId,
          action: 'payment.failed',
          metadata: { channel: 'apple', reason: 'refund' },
        })
        break
      }
    }
  } catch (err) {
    console.error('Error processing Apple IAP:', err)
    await supabase.from('audit_logs').insert({
      action: 'payment.webhook_error',
      metadata: { channel: 'apple', error: String(err), type: notificationType },
    })
    return new Response('Internal error', { status: 500 })
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})

function decodeJWT<T>(jwt: string): T {
  const parts = jwt.split('.')
  const decoded = atob(parts[1]!.replace(/-/g, '+').replace(/_/g, '/'))
  return JSON.parse(decoded)
}

function resolveApplePlan(productId: string): 'premium_monthly' | 'premium_annual' {
  if (productId.includes('annual')) return 'premium_annual'
  return 'premium_monthly'
}

interface AppleNotificationPayload {
  signedPayload: string
}

interface AppleDecodedPayload {
  notificationType: string
  subtype?: string
  data: {
    signedTransactionInfo: string
    signedRenewalInfo?: string
  }
}

interface AppleTransactionInfo {
  originalTransactionId: string
  productId: string
  purchaseDate: number
  expiresDate?: number
  appAccountToken?: string  // UUID do usuário (enviado no momento da compra)
}
