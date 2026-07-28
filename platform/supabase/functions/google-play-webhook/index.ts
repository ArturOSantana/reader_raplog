// Lumen Platform — Edge Function: google-play-webhook
// Spec §17: Sincronização de billing Google Play Billing
// Real-time Developer Notifications via Pub/Sub

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Google Pub/Sub envia: { message: { data: base64, messageId, ... }, subscription: '...' }
  let body: GooglePubSubMessage
  try {
    body = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  const messageData = body.message?.data
  if (!messageData) return new Response('Missing data', { status: 400 })

  let notification: GoogleRTDN
  try {
    const decoded = atob(messageData)
    notification = JSON.parse(decoded)
  } catch {
    return new Response('Failed to decode message', { status: 400 })
  }

  console.log(`Google Play notification: ${JSON.stringify(notification).slice(0, 200)}`)

  // Apenas processa notificações de assinatura
  const subscriptionNotification = notification.subscriptionNotification
  if (!subscriptionNotification) {
    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { purchaseToken, notificationType, subscriptionId } = subscriptionNotification

  try {
    const plan = resolveGooglePlan(subscriptionId)

    switch (notificationType) {
      // 1 = SUBSCRIPTION_RECOVERED
      // 2 = SUBSCRIPTION_RENEWED
      // 4 = SUBSCRIPTION_PURCHASED
      case 1:
      case 2:
      case 4: {
        await supabase.from('subscriptions').upsert({
          plan,
          status: 'active',
          channel: 'google',
          google_purchase_token: purchaseToken,
          current_period_start: new Date().toISOString(),
          // Google não fornece expiry na RTDN — buscar via API em produção
          current_period_end: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        }, { onConflict: 'google_purchase_token' })

        await supabase.from('audit_logs').insert({
          action: 'payment.approved',
          metadata: { plan, channel: 'google', notification_type: notificationType, subscription_id: subscriptionId },
        })
        break
      }

      // 3 = SUBSCRIPTION_CANCELED
      case 3: {
        await supabase.from('subscriptions')
          .update({ status: 'canceled', canceled_at: new Date().toISOString(), plan: 'free' })
          .eq('google_purchase_token', purchaseToken)
        break
      }

      // 5 = SUBSCRIPTION_ON_HOLD
      // 13 = SUBSCRIPTION_EXPIRED
      case 5:
      case 13: {
        const gracePeriodEnd = new Date()
        gracePeriodEnd.setDate(gracePeriodEnd.getDate() + 3)

        await supabase.from('subscriptions')
          .update({ status: 'past_due', grace_period_end_at: gracePeriodEnd.toISOString() })
          .eq('google_purchase_token', purchaseToken)

        await supabase.from('audit_logs').insert({
          action: 'payment.failed',
          metadata: { channel: 'google', notification_type: notificationType },
        })
        break
      }

      // 12 = SUBSCRIPTION_REVOKED (reembolso)
      case 12: {
        await supabase.from('subscriptions')
          .update({ status: 'canceled', canceled_at: new Date().toISOString(), plan: 'free' })
          .eq('google_purchase_token', purchaseToken)

        await supabase.from('audit_logs').insert({
          action: 'payment.failed',
          metadata: { channel: 'google', reason: 'revoked', notification_type: notificationType },
        })
        break
      }

      default:
        console.log(`Unhandled Google notification type: ${notificationType}`)
    }
  } catch (err) {
    console.error('Error processing Google Play:', err)
    await supabase.from('audit_logs').insert({
      action: 'payment.webhook_error',
      metadata: { channel: 'google', error: String(err), notification_type: notificationType },
    })
    return new Response('Internal error', { status: 500 })
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})

function resolveGooglePlan(subscriptionId: string): 'premium_monthly' | 'premium_annual' {
  if (subscriptionId.includes('annual')) return 'premium_annual'
  return 'premium_monthly'
}

interface GooglePubSubMessage {
  message: {
    data: string
    messageId: string
    publishTime: string
  }
  subscription: string
}

interface GoogleRTDN {
  version: string
  packageName: string
  eventTimeMillis: string
  subscriptionNotification?: {
    version: string
    notificationType: number
    purchaseToken: string
    subscriptionId: string
  }
  oneTimeProductNotification?: unknown
  testNotification?: unknown
}
