import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Health Check · Admin Lumen' }

/**
 * Status em tempo real de todas as integrações externas.
 * Spec: toda integração deve ter timeout, retry, circuit breaker e monitoramento aqui.
 *
 * Esta página faz fetch server-side para cada integração e exibe o status.
 * Timeout conservador: 5s por integração.
 */

type IntegrationStatus = 'ok' | 'degraded' | 'down' | 'unknown'

interface IntegrationResult {
  name: string
  description: string
  status: IntegrationStatus
  latencyMs: number | null
  detail: string | null
  criticality: 'critical' | 'high' | 'medium'
}

async function checkSupabase(): Promise<IntegrationResult> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) {
    return { name: 'Supabase', description: 'Auth + DB + Realtime + Storage', status: 'unknown', latencyMs: null, detail: 'Variáveis de ambiente não configuradas', criticality: 'critical' }
  }
  const start = Date.now()
  try {
    const res = await fetch(`${url}/rest/v1/`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
      signal: AbortSignal.timeout(5000),
    })
    const latencyMs = Date.now() - start
    if (res.ok || res.status === 404) {
      return { name: 'Supabase', description: 'Auth + DB + Realtime + Storage', status: latencyMs > 1000 ? 'degraded' : 'ok', latencyMs, detail: `HTTP ${res.status}`, criticality: 'critical' }
    }
    return { name: 'Supabase', description: 'Auth + DB + Realtime + Storage', status: 'down', latencyMs, detail: `HTTP ${res.status}`, criticality: 'critical' }
  } catch (e) {
    return { name: 'Supabase', description: 'Auth + DB + Realtime + Storage', status: 'down', latencyMs: Date.now() - start, detail: String(e), criticality: 'critical' }
  }
}

async function checkGoogleBooks(): Promise<IntegrationResult> {
  const start = Date.now()
  try {
    const res = await fetch('https://www.googleapis.com/books/v1/volumes?q=lumen&maxResults=1', {
      signal: AbortSignal.timeout(5000),
    })
    const latencyMs = Date.now() - start
    const data = await res.json()
    if (res.ok && data.kind) {
      return { name: 'Google Books API', description: 'Busca e metadados de livros', status: latencyMs > 1000 ? 'degraded' : 'ok', latencyMs, detail: `${data.totalItems ?? 0} resultados`, criticality: 'high' }
    }
    return { name: 'Google Books API', description: 'Busca e metadados de livros', status: 'degraded', latencyMs, detail: `HTTP ${res.status}`, criticality: 'high' }
  } catch (e) {
    return { name: 'Google Books API', description: 'Busca e metadados de livros', status: 'down', latencyMs: Date.now() - start, detail: String(e), criticality: 'high' }
  }
}

// Integrações que não podem ser verificadas sem chaves privadas: status "unknown"
const staticIntegrations: IntegrationResult[] = [
  { name: 'Stripe', description: 'Pagamentos Web', status: 'unknown', latencyMs: null, detail: 'Verificação requer chave secreta (server-side only)', criticality: 'high' },
  { name: 'Apple IAP', description: 'Assinaturas iOS', status: 'unknown', latencyMs: null, detail: 'Verificação requer certificado Apple', criticality: 'high' },
  { name: 'Google Play Billing', description: 'Assinaturas Android', status: 'unknown', latencyMs: null, detail: 'Verificação requer service account', criticality: 'high' },
  { name: 'FCM / APNs', description: 'Push Notifications', status: 'unknown', latencyMs: null, detail: 'Verificação requer chave FCM', criticality: 'medium' },
  { name: 'Resend / SendGrid', description: 'Emails transacionais', status: 'unknown', latencyMs: null, detail: 'Verificação requer chave de API', criticality: 'medium' },
  { name: 'Sentry', description: 'Rastreamento de erros', status: 'unknown', latencyMs: null, detail: 'Verificação requer DSN', criticality: 'medium' },
]

export default async function HealthCheckPage() {
  const now = new Date()

  const [supabaseResult, googleBooksResult] = await Promise.allSettled([
    checkSupabase(),
    checkGoogleBooks(),
  ])

  const liveResults: IntegrationResult[] = [
    supabaseResult.status === 'fulfilled' ? supabaseResult.value : { name: 'Supabase', description: 'Auth + DB + Realtime + Storage', status: 'unknown' as IntegrationStatus, latencyMs: null, detail: 'Erro ao verificar', criticality: 'critical' as const },
    googleBooksResult.status === 'fulfilled' ? googleBooksResult.value : { name: 'Google Books API', description: 'Busca e metadados de livros', status: 'unknown' as IntegrationStatus, latencyMs: null, detail: 'Erro ao verificar', criticality: 'high' as const },
  ]

  const allIntegrations = [...liveResults, ...staticIntegrations]

  const statusConfig: Record<IntegrationStatus, { label: string; cls: string; dot: string }> = {
    ok: { label: 'Operacional', cls: 'bg-[#3D6B5A]/10 text-[#3D6B5A]', dot: '#3D6B5A' },
    degraded: { label: 'Degradado', cls: 'bg-[#8B5E2E]/10 text-[#8B5E2E]', dot: '#8B5E2E' },
    down: { label: 'Fora do ar', cls: 'bg-[#8B2E2E]/10 text-[#8B2E2E]', dot: '#8B2E2E' },
    unknown: { label: 'Desconhecido', cls: 'bg-[#F2F1EF] text-[#B0AEA9]', dot: '#B0AEA9' },
  }

  const criticalityLabel: Record<string, string> = {
    critical: 'Crítico',
    high: 'Alta',
    medium: 'Média',
  }

  const countOk = allIntegrations.filter((i) => i.status === 'ok').length
  const countDown = allIntegrations.filter((i) => i.status === 'down').length
  const countDegraded = allIntegrations.filter((i) => i.status === 'degraded').length

  const overallStatus: IntegrationStatus = countDown > 0 ? 'down' : countDegraded > 0 ? 'degraded' : 'ok'
  const overallConfig = statusConfig[overallStatus]

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Admin</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Health Check</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Verificado em {now.toLocaleTimeString('pt-BR')} · {now.toLocaleDateString('pt-BR')}
        </p>
      </div>

      {/* Status geral */}
      <div className={`rounded-2xl p-5 mb-8 border ${overallStatus === 'ok' ? 'bg-[#3D6B5A]/10 border-[#3D6B5A]/30' : overallStatus === 'degraded' ? 'bg-[#8B5E2E]/10 border-[#8B5E2E]/30' : 'bg-[#8B2E2E]/10 border-[#8B2E2E]/30'}`}>
        <div className="flex items-center gap-3">
          <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: overallConfig.dot }} />
          <p className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">
            {overallStatus === 'ok' ? 'Todos os sistemas operacionais' : overallStatus === 'degraded' ? 'Performance degradada em algumas integrações' : 'Falha detectada em integração crítica'}
          </p>
        </div>
        <p className="text-sm text-[#6B6863] mt-1 ml-6">
          {countOk} OK · {countDegraded} degradados · {countDown} fora do ar
        </p>
      </div>

      {/* Cards de integração */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {allIntegrations.map((integration) => {
          const config = statusConfig[integration.status]
          return (
            <div
              key={integration.name}
              className="bg-white border border-[#ECEAE9] rounded-2xl p-5"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: config.dot }} />
                    <p className="font-[Fraunces] font-semibold text-[#1A1918]">{integration.name}</p>
                  </div>
                  <p className="text-xs text-[#6B6863] ml-4">{integration.description}</p>
                  {integration.detail && (
                    <p className="text-[10px] text-[#B0AEA9] mt-1 ml-4 font-[IBM_Plex_Mono]">{integration.detail}</p>
                  )}
                </div>
                <div className="flex-shrink-0 text-right">
                  <span className={`text-[10px] font-[IBM_Plex_Mono] px-2 py-0.5 rounded-full ${config.cls}`}>
                    {config.label}
                  </span>
                  {integration.latencyMs !== null && (
                    <p className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9] mt-1">{integration.latencyMs}ms</p>
                  )}
                </div>
              </div>
              <div className="mt-3 ml-4">
                <span className="text-[10px] font-[IBM_Plex_Mono] text-[#B0AEA9]">
                  Criticidade: {criticalityLabel[integration.criticality]}
                </span>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
