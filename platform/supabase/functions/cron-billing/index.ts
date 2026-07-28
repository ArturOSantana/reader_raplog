// Lumen Platform — Edge Function: cron-billing
// Spec §17: Downgrade automático após carência expirada (3 dias)
// Executar a cada hora via Supabase Cron

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async () => {
  console.log({ level: 'info', service: 'cron-billing', event: 'start' })

  const now = new Date().toISOString()
  let downgraded = 0
  let trialExpired = 0

  // ── 1. Downgrade: carência expirada ───────────────────────────────────────
  // past_due com grace_period_end_at < now → downgrade para Free
  const { data: expired } = await supabase
    .from('subscriptions')
    .select('id, user_id, plan, grace_period_end_at')
    .eq('status', 'past_due')
    .lt('grace_period_end_at', now)

  for (const sub of expired ?? []) {
    const { error } = await supabase
      .from('subscriptions')
      .update({
        status: 'expired',
        plan: 'free',
      })
      .eq('id', sub.id)

    if (!error) {
      downgraded++
      await supabase.from('audit_logs').insert({
        actor_id: sub.user_id,
        action: 'payment.failed',
        metadata: {
          reason: 'grace_period_expired',
          subscription_id: sub.id,
          previous_plan: sub.plan,
        },
      })

      // Notifica o usuário via email
      const { data: profile } = await supabase
        .from('profiles')
        .select('email, full_name')
        .eq('id', sub.user_id)
        .single()

      if (profile?.email) {
        await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-email`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            to: profile.email,
            subject: 'Sua assinatura Lumen expirou',
            template: 'payment_failed',
            data: {
              grace_days: 0,
              billing_url: 'https://app.lumen.app/billing',
            },
          }),
        }).catch(() => {/* não bloqueia se email falhar */})
      }
    }
  }

  // ── 2. Trial expirado → status active (período pago começa) ───────────────
  // Se o trial_end_at expirou mas status ainda é 'trialing' sem cancelamento,
  // o Stripe/Apple/Google deveria ter atualizado. Mas garantimos aqui como
  // fallback para canais manuais (gift codes).
  const { data: trialEnded } = await supabase
    .from('subscriptions')
    .select('id, user_id')
    .eq('status', 'trialing')
    .lt('trial_end_at', now)
    .in('channel', ['manual'])   // apenas canais manuais — os automáticos são tratados por webhook

  for (const sub of trialEnded ?? []) {
    const { error } = await supabase
      .from('subscriptions')
      .update({ status: 'active' })
      .eq('id', sub.id)

    if (!error) trialExpired++
  }

  // ── 3. Assinaturas expiradas há mais de 30 dias → marcar como free ────────
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  const { data: stale } = await supabase
    .from('subscriptions')
    .select('id, user_id')
    .in('status', ['canceled', 'expired'])
    .lt('current_period_end', thirtyDaysAgo.toISOString())
    .neq('plan', 'free')

  for (const sub of stale ?? []) {
    await supabase
      .from('subscriptions')
      .update({ plan: 'free' })
      .eq('id', sub.id)
  }

  const summary = { ok: true, downgraded, trialExpired, stale: stale?.length ?? 0 }
  console.log({ level: 'info', service: 'cron-billing', ...summary })

  return new Response(JSON.stringify(summary), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
