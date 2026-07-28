import type { Metadata } from 'next'
import Link from 'next/link'
import { BookOpen, BarChart2, Users, Zap, Star, Shield } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Lumen — Seu Companheiro de Leitura',
  description:
    'Registre sessões, acompanhe progresso, participe de clubes do livro e descubra novas obras. Disponível para iOS e Android.',
}

export default function MarketingHome() {
  return (
    <div className="bg-[#FAF9F7] text-[#1A1918]">
      <MarketingNav />

      {/* ── Hero ──────────────────────────────────────────────── */}
      <section className="max-w-5xl mx-auto px-6 pt-28 pb-24 text-center">
        <h1 className="font-[Fraunces] text-6xl md:text-7xl font-bold leading-[1.1] mb-6 tracking-tight">
          Leia mais.<br />Lembre mais.
        </h1>
        <p className="text-[#6B6863] text-xl max-w-2xl mx-auto mb-10 leading-relaxed">
          Registre cada sessão, acompanhe seu progresso, participe de clubes e
          descubra resenhas honestas — tudo em um só lugar.
        </p>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Link
            href="/download"
            className="bg-[#1A1918] text-[#FAF9F7] px-8 py-3.5 rounded font-medium hover:bg-[#2C2B29]"
          >
            Baixar grátis
          </Link>
          <a
            href="https://app.lumen.app"
            className="border border-[#ECEAE9] text-[#1A1918] px-8 py-3.5 rounded font-medium hover:border-[#B0AEA9]"
          >
            Abrir Web App
          </a>
        </div>
      </section>

      {/* ── Features ────────────────────────────────────────────── */}
      <section id="features" className="max-w-6xl mx-auto px-6 py-24">
        <div className="text-center mb-14">
          <h2 className="font-[Fraunces] text-4xl font-bold mb-3">
            Tudo que um leitor precisa
          </h2>
          <p className="text-[#6B6863] max-w-xl mx-auto">
            Do primeiro até o último destaque, o Lumen acompanha toda a sua jornada.
          </p>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {features.map(({ icon: Icon, title, desc }) => (
            <div
              key={title}
              className="bg-white border border-[#ECEAE9] rounded-lg p-6 hover:border-[#B0AEA9]"
            >
              <Icon size={18} className="text-[#3D6B5A] mb-4" />
              <h3 className="font-[Fraunces] font-semibold text-lg mb-2">{title}</h3>
              <p className="text-[#6B6863] text-sm leading-relaxed">{desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── Pricing ─────────────────────────────────────────────── */}
      <section id="pricing" className="max-w-5xl mx-auto px-6 py-24">
        <div className="text-center mb-14">
          <h2 className="font-[Fraunces] text-4xl font-bold mb-3">Planos</h2>
          <p className="text-[#6B6863]">Comece grátis. Evolua quando quiser.</p>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-3xl mx-auto">
          <div className="bg-white border border-[#ECEAE9] rounded-lg p-8">
            <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-2">
              Gratuito
            </p>
            <p className="font-[Fraunces] text-4xl font-bold mb-6">R$&nbsp;0</p>
            <ul className="space-y-3 text-sm text-[#6B6863] mb-8">
              {['Biblioteca ilimitada', 'Sessões de leitura', 'Notas e destaques', 'Clubes públicos', '1 clube privado'].map((f) => (
                <li key={f} className="flex items-center gap-2">
                  <span className="text-[#3D6B5A]">✓</span> {f}
                </li>
              ))}
            </ul>
            <Link href="/download" className="block text-center border border-[#ECEAE9] rounded py-2.5 text-sm font-medium hover:border-[#B0AEA9]">
              Começar grátis
            </Link>
          </div>
          <div className="bg-[#1A1918] text-[#FAF9F7] rounded-lg p-8">
            <p className="font-[IBM_Plex_Mono] text-xs text-[#6B6863] uppercase tracking-widest mb-2">
              Pro
            </p>
            <p className="font-[Fraunces] text-4xl font-bold mb-1">R$&nbsp;14</p>
            <p className="text-xs text-[#6B6863] mb-6">/mês · cobrado anualmente</p>
            <ul className="space-y-3 text-sm text-[#B0AEA9] mb-8">
              {['Tudo do Gratuito', 'Clubes privados ilimitados', 'Analytics avançado', 'Metas avançadas', 'Widget de leitura', 'Suporte prioritário'].map((f) => (
                <li key={f} className="flex items-center gap-2">
                  <span className="text-[#3D6B5A]">✓</span> {f}
                </li>
              ))}
            </ul>
            <Link href="/download" className="block text-center bg-[#3D6B5A] text-[#FAF9F7] rounded py-2.5 text-sm font-medium hover:bg-[#5A9480]">
              Assinar Pro
            </Link>
          </div>
        </div>
      </section>

      {/* ── FAQ ─────────────────────────────────────────────────── */}
      <section id="faq" className="border-t border-[#ECEAE9] bg-[#F2F1EF] py-20">
        <div className="max-w-2xl mx-auto px-6">
          <h2 className="font-[Fraunces] text-4xl font-bold text-center mb-10">
            Perguntas frequentes
          </h2>
          <div className="space-y-4">
            {faqs.map(({ q, a }) => (
              <div key={q} className="bg-white border border-[#ECEAE9] rounded-lg p-5">
                <p className="font-[Fraunces] font-semibold mb-2">{q}</p>
                <p className="text-sm text-[#6B6863] leading-relaxed">{a}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <MarketingFooter />
    </div>
  )
}

// ── Componentes ────────────────────────────────────────────────

function MarketingNav() {
  return (
    <nav className="border-b border-[#ECEAE9] bg-[#FAF9F7] sticky top-0 z-50">
      <div className="max-w-6xl mx-auto px-6 h-14 flex items-center justify-between">
        <Link href="/" className="font-[Fraunces] font-bold text-xl">
          lumen
        </Link>
        <div className="hidden md:flex items-center gap-6 text-sm text-[#6B6863]">
          <Link href="/books" className="hover:text-[#1A1918]">Livros</Link>
          <Link href="/clubs" className="hover:text-[#1A1918]">Clubes</Link>
          <Link href="/blog" className="hover:text-[#1A1918]">Blog</Link>
          <Link href="/#pricing" className="hover:text-[#1A1918]">Preço</Link>
        </div>
        <div className="flex items-center gap-3">
          <a href="https://app.lumen.app" className="text-sm text-[#6B6863] hover:text-[#1A1918]">
            Entrar
          </a>
          <Link
            href="/download"
            className="bg-[#1A1918] text-[#FAF9F7] px-4 py-2 rounded text-sm font-medium hover:bg-[#2C2B29]"
          >
            Baixar app
          </Link>
        </div>
      </div>
    </nav>
  )
}

function MarketingFooter() {
  return (
    <footer className="border-t border-[#ECEAE9] py-12">
      <div className="max-w-6xl mx-auto px-6">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-10">
          <div>
            <p className="font-[Fraunces] font-bold text-lg mb-3">lumen</p>
            <p className="text-sm text-[#6B6863] leading-relaxed">
              Seu companheiro de leitura. Registre, acompanhe e evolua.
            </p>
          </div>
          {[
            { title: 'Produto', links: [{ l: 'Features', h: '/#features' }, { l: 'Preço', h: '/#pricing' }, { l: 'Download', h: '/download' }] },
            { title: 'Comunidade', links: [{ l: 'Clubes', h: '/clubs' }, { l: 'Livros', h: '/books' }, { l: 'Blog', h: '/blog' }] },
            { title: 'Empresa', links: [{ l: 'FAQ', h: '/#faq' }, { l: 'Contato', h: '/contact' }, { l: 'Privacidade', h: '/privacy' }] },
          ].map(({ title, links }) => (
            <div key={title}>
              <p className="font-[IBM_Plex_Mono] text-xs uppercase tracking-widest text-[#6B6863] mb-3">
                {title}
              </p>
              <ul className="space-y-2">
                {links.map(({ l, h }) => (
                  <li key={l}>
                    <Link href={h} className="text-sm text-[#6B6863] hover:text-[#1A1918] transition-colors">
                      {l}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="border-t border-[#ECEAE9] pt-6 flex items-center justify-between text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">
          <span>© {new Date().getFullYear()} Lumen</span>
          <span>Feito para leitores</span>
        </div>
      </div>
    </footer>
  )
}

// ── Dados ───────────────────────────────────────────────────────

const features = [
  { icon: BookOpen, title: 'Biblioteca', desc: 'Organize por status, acompanhe progresso página a página e veja o histórico completo de cada livro.' },
  { icon: BarChart2, title: 'Estatísticas', desc: 'Streak de leitura, heatmap de atividade, metas diárias e mensais, gráficos de evolução.' },
  { icon: Users, title: 'Clubes do Livro', desc: 'Crie ou entre em clubes públicos e privados. Desafios, enquetes, feed e ranking de leitores.' },
  { icon: Zap, title: 'Sessões de Leitura', desc: 'Timer de sessão, registro de páginas, mood e notas rápidas. Tudo sincronizado em tempo real.' },
  { icon: Star, title: 'Notas e Resenhas', desc: 'Anote observações, reflexões e destaques. Escreva resenhas e compartilhe com a comunidade.' },
  { icon: Shield, title: 'Privacidade', desc: 'Controle total sobre o que é público. Perfil, biblioteca e resenhas podem ser privados.' },
]

const faqs = [
  { q: 'O app é gratuito?', a: 'Sim. O plano gratuito inclui biblioteca ilimitada, sessões, notas e clubes públicos. O plano Pro adiciona funcionalidades avançadas.' },
  { q: 'Funciona no navegador?', a: 'Sim. O Web App em app.lumen.app tem biblioteca, estatísticas, clubes e notas. Sessões de leitura em tempo real são exclusivas do app móvel.' },
  { q: 'Posso importar livros de outros apps?', a: 'Estamos trabalhando em importação via CSV e integração com Goodreads. Por enquanto, a adição é manual ou via busca no Google Books.' },
  { q: 'Meus dados ficam seguros?', a: 'Sim. Usamos Supabase com criptografia em trânsito (TLS 1.3) e em repouso. Você pode exportar ou excluir seus dados a qualquer momento.' },
]
