import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Download · Lumen',
  description: 'Baixe o Lumen para iOS ou Android. Gratuito.',
}

export default function DownloadPage() {
  return (
    <main className="min-h-screen bg-[#FAF9F7] flex items-center justify-center px-6">
      <div className="text-center max-w-md">
        <a href="/" className="font-[Fraunces] font-bold text-3xl text-[#1A1918] block mb-8">
          lumen
        </a>
        <h1 className="font-[Fraunces] text-4xl font-bold text-[#1A1918] mb-4">
          Baixar o Lumen
        </h1>
        <p className="text-[#6B6863] mb-10">
          Disponível para iOS e Android. Grátis para começar.
        </p>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <a
            href="https://apps.apple.com"
            className="bg-[#1A1918] text-[#FAF9F7] px-8 py-3.5 rounded font-medium hover:bg-[#2C2B29] text-sm"
          >
            App Store (iOS)
          </a>
          <a
            href="https://play.google.com"
            className="border border-[#ECEAE9] text-[#1A1918] px-8 py-3.5 rounded font-medium hover:border-[#B0AEA9] text-sm"
          >
            Google Play (Android)
          </a>
        </div>
      </div>
    </main>
  )
}
