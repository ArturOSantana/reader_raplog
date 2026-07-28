// Lumen Platform — Edge Function: stripe-webhook
// Spec §17: Sincronização de billing via webhooks → Edge Function
// Spec §10: Toda operação de pagamento gera audit_log imutável
// Spec §21: Segurança — validação de assinatura obrigatória

import { createClient } from 'jsr:@supabase/supabase-js@2'
import Stripe from 'npm:stripe@17'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-12-18.acacia',
  httpClient: Stripe.createFetchHttpClient(),
})

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const signature = req.headers.get('stripe-signature')
  if (!signature) {
    return new Response('Missing signature', { status: 400 })
  }

  const body = await req.text()
  let event: Stripe.Event

  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      Deno.env.get('STRIPE_WEBHOOK_SECRET')!,
    )
  } catch (err) {
    console.error('Stripe webhook signature failed:', err)
    return new Response('Invalid signature', { status: 400 })
  }

  console.log(`Stripe event: ${event.type}`)

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session
        await handleCheckoutCompleted(session)
        break
      }
      case 'invoice.payment_succeeded': {
        const invoice = event.data.object as Stripe.Invoice
        await handlePaymentSucceeded(invoice)
        break
      }
      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice
        await handlePaymentFailed(invoice)
        break
      }
      case 'customer.subscription.updated': {
        const sub = event.data.object as Stripe.Subscription
        await handleSubscriptionUpdated(sub)
        break
      }
      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription
        await handleSubscriptionDeleted(sub)
        break
      }
      default:
        console.log(`Unhandled event: ${event.type}`)
    }
  } catch (err) {
    console.error(`Error processing ${event.type}:`, err)
    // Log auditoria de falha
    await supabase.from('audit_logs').insert({
      action: 'payment.webhook_error',
      metadata: { event_type: event.type, error: String(err) },
    })
    return new Response('Internal error', { status: 500 })
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const userId = session.metadata?.user_id
  if (!userId) return

  const stripeSubId = session.subscription as string
  if (!stripeSubId) return

  const stripeSub = await stripe.subscriptions.retrieve(stripeSubId)
  const plan = resolvePlan(stripeSub.items.data[0]?.price?.id)

  await supabase.from('subscriptions').upsert({
    user_id: userId,
    plan,
    status: 'active',
    channel: 'stripe',
    stripe_subscription_id: stripeSubId,
    stripe_customer_id: session.customer as string,
    current_period_start: new Date(stripeSub.current_period_start * 1000).toISOString(),
    current_period_end: new Date(stripeSub.current_period_end * 1000).toISOString(),
    trial_start_at: stripeSub.trial_start
      ? new Date(stripeSub.trial_start * 1000).toISOString()
      : null,
    trial_end_at: stripeSub.trial_end
      ? new Date(stripeSub.trial_end * 1000).toISOString()
      : null,
    price_amount: stripeSub.items.data[0]?.price?.unit_amount,
    currency: stripeSub.currency.toUpperCase(),
  }, { onConflict: 'stripe_subscription_id' })

  await supabase.from('audit_logs').insert({
    actor_id: userId,
    action: 'payment.approved',
    metadata: { plan, stripe_subscription_id: stripeSubId, channel: 'stripe' },
  })
}

async function handlePaymentSucceeded(invoice: Stripe.Invoice) {
  const stripeSubId = invoice.subscription as string
  if (!stripeSubId) return

  const stripeSub = await stripe.subscriptions.retrieve(stripeSubId)

  await supabase.from('subscriptions')
    .update({
      status: 'active',
      current_period_start: new Date(stripeSub.current_period_start * 1000).toISOString(),
      current_period_end: new Date(stripeSub.current_period_end * 1000).toISOString(),
      grace_period_end_at: null,
    })
    .eq('stripe_subscription_id', stripeSubId)

  await supabase.from('audit_logs').insert({
    action: 'payment.approved',
    metadata: { stripe_subscription_id: stripeSubId, invoice_id: invoice.id },
  })
}

async function handlePaymentFailed(invoice: Stripe.Invoice) {
  const stripeSubId = invoice.subscription as string
  if (!stripeSubId) return

  // Spec §17: 3 dias de carência
  const gracePeriodEnd = new Date()
  gracePeriodEnd.setDate(gracePeriodEnd.getDate() + 3)

  await supabase.from('subscriptions')
    .update({
      status: 'past_due',
      grace_period_end_at: gracePeriodEnd.toISOString(),
    })
    .eq('stripe_subscription_id', stripeSubId)

  await supabase.from('audit_logs').insert({
    action: 'payment.failed',
    metadata: {
      stripe_subscription_id: stripeSubId,
      invoice_id: invoice.id,
      grace_period_end: gracePeriodEnd.toISOString(),
    },
  })
}

async function handleSubscriptionUpdated(sub: Stripe.Subscription) {
  const plan = resolvePlan(sub.items.data[0]?.price?.id)
  const status = mapStripeStatus(sub.status)

  await supabase.from('subscriptions')
    .update({
      plan,
      status,
      current_period_start: new Date(sub.current_period_start * 1000).toISOString(),
      current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
      canceled_at: sub.canceled_at
        ? new Date(sub.canceled_at * 1000).toISOString()
        : null,
    })
    .eq('stripe_subscription_id', sub.id)
}

async function handleSubscriptionDeleted(sub: Stripe.Subscription) {
  await supabase.from('subscriptions')
    .update({
      status: 'canceled',
      canceled_at: new Date().toISOString(),
      plan: 'free',
    })
    .eq('stripe_subscription_id', sub.id)

  await supabase.from('audit_logs').insert({
    action: 'payment.failed',
    metadata: { stripe_subscription_id: sub.id, reason: 'subscription_deleted' },
  })
}

function resolvePlan(priceId: string | undefined): 'premium_monthly' | 'premium_annual' | 'free' {
  const MONTHLY_PRICE_ID = Deno.env.get('STRIPE_MONTHLY_PRICE_ID')
  const ANNUAL_PRICE_ID  = Deno.env.get('STRIPE_ANNUAL_PRICE_ID')
  if (priceId === MONTHLY_PRICE_ID) return 'premium_monthly'
  if (priceId === ANNUAL_PRICE_ID)  return 'premium_annual'
  return 'free'
}

function mapStripeStatus(status: Stripe.Subscription.Status): 'trialing' | 'active' | 'past_due' | 'canceled' | 'expired' {
  const map: Record<string, 'trialing' | 'active' | 'past_due' | 'canceled' | 'expired'> = {
    trialing: 'trialing',
    active: 'active',
    past_due: 'past_due',
    canceled: 'canceled',
    unpaid: 'past_due',
    incomplete: 'past_due',
    incomplete_expired: 'expired',
    paused: 'past_due',
  }
  return map[status] ?? 'active'
}
