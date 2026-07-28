import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Blog · Lumen',
  description: 'Artigos sobre leitura, hábitos, clubes do livro e literatura.',
}

export default function BlogPage() {
  return (
    <main className="min-h-screen bg-[#FAF9F7]">
      <nav className="border-b border-[#ECEAE9] bg-[#FAF9F7] sticky top-0 z-50">
        <div className="max-w-6xl mx-auto px-6 h-14 flex items-center justify-between">
          <a href="/" className="font-[Fraunces] font-bold text-xl text-[#1A1918]">lumen</a>
          <a href="https://app.lumen.app" className="text-sm text-[#6B6863] hover:text-[#1A1918]">Entrar</a>
        </div>
      </nav>

      <div className="max-w-3xl mx-auto px-6 py-16">
        <h1 className="font-[Fraunces] text-5xl font-bold text-[#1A1918] mb-4">Blog</h1>
        <p className="text-[#6B6863] text-lg mb-12">
          Artigos sobre leitura, hábitos e literatura.
        </p>

        <div className="space-y-8">
          {posts.map(({ slug, title, date, excerpt, category }) => (
            <a
              key={slug}
              href={`/blog/${slug}`}
              className="block group border-b border-[#ECEAE9] pb-8 last:border-0"
            >
              <p className="font-[IBM_Plex_Mono] text-xs text-[#3D6B5A] uppercase tracking-widest mb-2">
                {category}
              </p>
              <h2 className="font-[Fraunces] text-2xl font-bold text-[#1A1918] group-hover:text-[#3D6B5A] transition-colors mb-2">
                {title}
              </h2>
              <p className="text-[#6B6863] text-sm leading-relaxed mb-3">{excerpt}</p>
              <p className="font-[IBM_Plex_Mono] text-xs text-[#B0AEA9]">{date}</p>
            </a>
          ))}
        </div>
      </div>

      <footer className="border-t border-[#ECEAE9] py-8 mt-8">
        <div className="max-w-6xl mx-auto px-6 text-center text-xs text-[#B0AEA9] font-[IBM_Plex_Mono]">
          © {new Date().getFullYear()} Lumen
        </div>
      </footer>
    </main>
  )
}

const posts = [
  {
    slug: '10-livros-para-comecar-a-ler',
    title: '10 livros para começar a ler',
    date: 'Janeiro 2025',
    category: 'Recomendações',
    excerpt: 'Uma seleção cuidadosa para quem quer (re)descobrir o prazer da leitura sem saber por onde começar.',
  },
  {
    slug: 'como-criar-o-habito-da-leitura',
    title: 'Como criar o hábito da leitura',
    date: 'Dezembro 2024',
    category: 'Hábitos',
    excerpt: 'O segredo não é força de vontade — é design de ambiente. Veja como tornar a leitura a opção mais fácil do seu dia.',
  },
  {
    slug: 'melhores-livros-de-fantasia',
    title: 'Melhores livros de fantasia',
    date: 'Novembro 2024',
    category: 'Fantasia',
    excerpt: 'De Tolkien a Brandon Sanderson — um guia pelos mundos que mais valem a pena explorar.',
  },
  {
    slug: 'como-funciona-um-clube-do-livro',
    title: 'Como funciona um clube do livro',
    date: 'Outubro 2024',
    category: 'Clubes',
    excerpt: 'Tudo que você precisa saber para criar ou participar de um clube que realmente funcione.',
  },
]
