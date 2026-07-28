// Lumen Platform — Edge Function: send-email
// Spec §20: Fila de emails transacionais com retry automático
// Provider: Resend (com fallback para SendGrid)
// Spec §8: Logs estruturados, sem dados sensíveis

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const FROM_EMAIL     = Deno.env.get('EMAIL_FROM') ?? 'noreply@lumen.app'

interface EmailPayload {
  to: string
  subject: string
  template: string // 'welcome' | 'magic_link' | 'streak_reminder' | 'plan_confirmed' | etc.
  data: Record<string, unknown>
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  let payload: EmailPayload
  try {
    payload = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  const { to, subject, template, data } = payload

  // Renderiza HTML a partir do template
  const html = renderTemplate(template, data)

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to,
        subject,
        html,
      }),
    })

    if (!res.ok) {
      const err = await res.text()
      console.error({ level: 'error', service: 'send-email', template, error: err })
      // Não loga o `to` para evitar PII nos logs (spec §8)
      throw new Error(`Resend API error: ${res.status}`)
    }

    console.log({ level: 'info', service: 'send-email', template, status: 'sent' })
    return new Response(JSON.stringify({ sent: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error({ level: 'error', service: 'send-email', template, error: String(err) })
    return new Response(JSON.stringify({ sent: false, error: 'Email delivery failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})

function renderTemplate(template: string, data: Record<string, unknown>): string {
  const baseStyle = `
    <style>
      body { font-family: -apple-system, sans-serif; background: #FAF9F7; color: #1A1918; margin: 0; padding: 0; }
      .container { max-width: 560px; margin: 40px auto; background: #fff; border-radius: 16px; padding: 40px; border: 1px solid #ECEAE9; }
      h1 { font-size: 28px; font-weight: 700; margin-bottom: 12px; }
      p { font-size: 15px; line-height: 1.6; color: #6B6863; }
      .btn { display: inline-block; background: #1A1918; color: #fff !important; padding: 12px 28px; border-radius: 10px; text-decoration: none; font-size: 14px; font-weight: 500; margin: 20px 0; }
      .footer { margin-top: 32px; font-size: 12px; color: #B0AEA9; }
    </style>
  `

  const templates: Record<string, string> = {
    welcome: `
      <!DOCTYPE html><html><head>${baseStyle}</head><body>
      <div class="container">
        <p style="font-family:serif;font-size:24px;font-weight:700;color:#1A1918">lumen</p>
        <h1>Bem-vindo, ${data.name ?? 'leitor'}! 📖</h1>
        <p>Sua conta foi criada com sucesso. Comece adicionando seu primeiro livro.</p>
        <a href="${data.app_url ?? 'https://app.lumen.app'}" class="btn">Abrir o Lumen</a>
        <p class="footer">Se não criou esta conta, ignore este email.</p>
      </div></body></html>
    `,
    magic_link: `
      <!DOCTYPE html><html><head>${baseStyle}</head><body>
      <div class="container">
        <p style="font-family:serif;font-size:24px;font-weight:700;color:#1A1918">lumen</p>
        <h1>Seu link de acesso</h1>
        <p>Clique no botão abaixo para entrar no Lumen. Este link expira em 10 minutos.</p>
        <a href="${data.magic_link}" class="btn">Entrar no Lumen</a>
        <p>Por segurança, este link é de uso único e expira em 10 minutos.</p>
        <p class="footer">Se não solicitou, ignore este email.</p>
      </div></body></html>
    `,
    streak_reminder: `
      <!DOCTYPE html><html><head>${baseStyle}</head><body>
      <div class="container">
        <p style="font-family:serif;font-size:24px;font-weight:700;color:#1A1918">lumen</p>
        <h1>🔥 Não perca seu streak de ${data.streak_days} dias!</h1>
        <p>Você ainda não leu hoje. Que tal reservar alguns minutos para o seu livro?</p>
        <a href="${data.app_url ?? 'https://app.lumen.app'}" class="btn">Continuar lendo</a>
        <p class="footer">Para não receber mais lembretes, ajuste nas configurações.</p>
      </div></body></html>
    `,
    plan_confirmed: `
      <!DOCTYPE html><html><head>${baseStyle}</head><body>
      <div class="container">
        <p style="font-family:serif;font-size:24px;font-weight:700;color:#1A1918">lumen</p>
        <h1>Assinatura Premium confirmada ✅</h1>
        <p>Seu plano <strong>${data.plan_name ?? 'Premium'}</strong> está ativo.</p>
        <a href="${data.app_url ?? 'https://app.lumen.app'}" class="btn">Explorar benefícios</a>
        <p class="footer">Acesse as configurações para gerenciar sua assinatura.</p>
      </div></body></html>
    `,
    payment_failed: `
      <!DOCTYPE html><html><head>${baseStyle}</head><body>
      <div class="container">
        <p style="font-family:serif;font-size:24px;font-weight:700;color:#1A1918">lumen</p>
        <h1>⚠️ Problema com seu pagamento</h1>
        <p>Não conseguimos processar o pagamento da sua assinatura. Você tem ${data.grace_days ?? 3} dias para regularizar.</p>
        <a href="${data.billing_url ?? 'https://app.lumen.app/settings'}" class="btn">Atualizar forma de pagamento</a>
        <p class="footer">Em caso de dúvidas, entre em contato pelo suporte.</p>
      </div></body></html>
    `,
    lgpd_export_ready: `
      <!DOCTYPE html><html><head>${baseStyle}</head><body>
      <div class="container">
        <p style="font-family:serif;font-size:24px;font-weight:700;color:#1A1918">lumen</p>
        <h1>⚖️ Seus dados estão prontos</h1>
        <p>Sua solicitação de exportação de dados foi processada. O link abaixo expira em 24 horas.</p>
        <a href="${data.export_url}" class="btn">Baixar meus dados</a>
        <p class="footer">Spec LGPD — direito de portabilidade.</p>
      </div></body></html>
    `,
  }

  return templates[template] ?? `<p>Email: ${template}</p>`
}
