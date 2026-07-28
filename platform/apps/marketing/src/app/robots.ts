import { MetadataRoute } from 'next'

/**
 * robots.txt — spec §12
 * Bloqueia rotas internas e autenticadas.
 */
export default function robots(): MetadataRoute.Robots {
  const base = process.env.NEXT_PUBLIC_APP_URL ?? 'https://lumen.app'

  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/app/',
          '/auth/',
          '/api/',
          '/_next/',
        ],
      },
    ],
    sitemap: `${base}/sitemap.xml`,
  }
}
