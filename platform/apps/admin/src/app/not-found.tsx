export const dynamic = 'force-dynamic'

export default function NotFound() {
  return (
    <main style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', fontFamily: 'sans-serif', color: '#1A1A2E' }}>
      <p style={{ fontSize: 72, fontWeight: 700, margin: 0, lineHeight: 1 }}>404</p>
      <p style={{ fontSize: 16, color: '#6C757D', marginTop: 12 }}>Página não encontrada</p>
      <a href="/" style={{ marginTop: 24, fontSize: 14, color: '#3D6B5A', textDecoration: 'underline' }}>Voltar ao início</a>
    </main>
  )
}
