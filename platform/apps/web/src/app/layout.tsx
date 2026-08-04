import type { Metadata } from 'next'
import './globals.css'

function resolveMetadataBase(): URL {
  try {
    const raw = process.env.NEXT_PUBLIC_APP_URL
    if (raw) return new URL(raw)
  } catch {
    // variável inválida — usa fallback
  }
  return new URL('https://app.lumen.app')
}

export const metadata: Metadata = {
  metadataBase: resolveMetadataBase(),
  title: {
    default: 'Lumen Web',
    template: '%s · Lumen',
  },
  description: 'Portal web do Lumen. Gerencie sua biblioteca, sessões, clubes e estatísticas.',
  robots: { index: false, follow: false },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        {/* eslint-disable-next-line @next/next/no-page-custom-font */}
        <link
          href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,600;0,9..144,700&family=IBM+Plex+Mono:wght@400;500;600&family=Inter:wght@400;500;600&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  )
}
