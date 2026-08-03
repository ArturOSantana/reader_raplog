import { NextResponse, type NextRequest } from 'next/server'

/**
 * Middleware do Marketing Website (lumen.app).
 *
 * A maioria das rotas são públicas (SEO, blog, páginas de livros).
 * Não há área autenticada nesta app — o middleware apenas passa adiante.
 *
 * Não instancia @supabase/ssr para evitar incompatibilidade com o Edge Runtime
 * (dependência transitiva `ws` usa APIs Node.js ausentes no Edge).
 */
export function middleware(request: NextRequest) {
  return NextResponse.next({ request })
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)'],
}
