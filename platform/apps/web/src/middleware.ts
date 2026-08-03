import { NextResponse, type NextRequest } from 'next/server'

/**
 * Middleware do Web Platform (app.lumen.app).
 *
 * Não instancia @supabase/ssr para evitar incompatibilidade com o Edge Runtime
 * (dependência transitiva `ws` usa APIs Node.js ausentes no Edge).
 *
 * Estratégia: lê o JWT de sessão do cookie do Supabase e decodifica o payload
 * Base64url sem verificar assinatura — a validação real ocorre nas chamadas à
 * API do Supabase nos Server Components / Route Handlers.
 */

const SESSION_COOKIE = 'sb-ueyamtswrlbtzzwpwddj-auth-token'

/** Decodifica o payload de um JWT sem verificar a assinatura (Edge-safe). */
function getJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    return JSON.parse(atob(payload))
  } catch {
    return null
  }
}

/** Lê a sessão Supabase dos cookies (suporta chunked cookies). */
function getSessionFromCookies(request: NextRequest): Record<string, unknown> | null {
  // Cookie pode estar em chunks: sb-...-auth-token.0, .1, etc.
  let raw = request.cookies.get(SESSION_COOKIE)?.value ?? null

  if (!raw) {
    // Tentar reconstituir chunks
    const chunks: string[] = []
    for (let i = 0; i < 5; i++) {
      const chunk = request.cookies.get(`${SESSION_COOKIE}.${i}`)?.value
      if (!chunk) break
      chunks.push(chunk)
    }
    if (chunks.length > 0) raw = chunks.join('')
  }

  if (!raw) return null

  try {
    // O Supabase SSR armazena em base64url com prefixo "base64-"
    let json = raw
    if (raw.startsWith('base64-')) {
      json = atob(raw.slice(7).replace(/-/g, '+').replace(/_/g, '/'))
    }
    const session = JSON.parse(json)
    const accessToken: string = session?.access_token ?? session?.[0]?.access_token ?? ''
    if (!accessToken) return null
    const payload = getJwtPayload(accessToken)
    if (!payload) return null
    // Verificar expiração
    const exp = payload.exp as number | undefined
    if (exp && exp * 1000 < Date.now()) return null
    return payload
  } catch {
    return null
  }
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  const publicPaths = ['/login', '/auth/callback', '/auth/google']
  const isPublic = publicPaths.some((p) => pathname.startsWith(p))

  const session = getSessionFromCookies(request)

  if (!session && !isPublic) {
    const loginUrl = request.nextUrl.clone()
    loginUrl.pathname = '/login'
    loginUrl.searchParams.set('next', pathname)
    return NextResponse.redirect(loginUrl)
  }

  if (session && pathname === '/login') {
    const homeUrl = request.nextUrl.clone()
    homeUrl.pathname = '/'
    return NextResponse.redirect(homeUrl)
  }

  return NextResponse.next({ request })
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
