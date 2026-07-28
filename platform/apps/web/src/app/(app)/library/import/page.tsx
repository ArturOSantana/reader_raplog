import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { importGoodreadsCSV, importGenericCSV } from '../import-actions'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Importar Livros · Lumen' }

interface PageProps {
  searchParams: Promise<{ action?: string; imported?: string; skipped?: string; error?: string }>
}

export default async function ImportPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { action, imported, skipped, error } = await searchParams

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="mb-8">
        <Link href="/library" className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] hover:text-[#1A1918] mb-4 inline-block">
          ← Biblioteca
        </Link>
        <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Biblioteca</p>
        <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918]">Importar livros</h1>
        <p className="text-sm text-[#6B6863] mt-1">
          Importe sua biblioteca do Goodreads ou via CSV genérico.
        </p>
      </div>

      {/* Feedback de resultado */}
      {action === 'done' && imported != null && (
        <div className="mb-6 bg-[#3D6B5A]/10 border border-[#3D6B5A]/20 text-[#3D6B5A] px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          ✓ {imported} livro{Number(imported) !== 1 ? 's' : ''} importado{Number(imported) !== 1 ? 's' : ''}
          {Number(skipped) > 0 && ` · ${skipped} ignorado${Number(skipped) !== 1 ? 's' : ''}`}
        </div>
      )}
      {error && (
        <div className="mb-6 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          {error}
        </div>
      )}

      <div className="space-y-6">
        {/* Card Goodreads */}
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
          <div className="flex items-start gap-4 mb-5">
            <div className="w-10 h-10 bg-[#E8F0EE] rounded-xl flex items-center justify-center text-xl flex-shrink-0">
              📚
            </div>
            <div>
              <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">Goodreads</h2>
              <p className="text-xs text-[#6B6863] mt-0.5">
                Exporte em{' '}
                <a
                  href="https://www.goodreads.com/review/import"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-[#3D6B5A] hover:underline"
                >
                  goodreads.com/review/import
                </a>
                {' '}e faça upload do arquivo <code className="bg-[#F2F1EF] px-1 rounded text-xs">.csv</code> aqui.
              </p>
            </div>
          </div>

          <form action={async (fd) => {
            'use server'
            const result = await importGoodreadsCSV(fd)
            const params = new URLSearchParams({
              action: 'done',
              imported: String(result.imported ?? 0),
              skipped: String(result.skipped ?? 0),
              ...(result.error ? { error: result.error } : {}),
            })
            redirect(`/library/import?${params}`)
          }}>
            <div className="border-2 border-dashed border-[#ECEAE9] rounded-xl p-6 text-center mb-4">
              <input
                type="file"
                name="file"
                accept=".csv"
                required
                className="w-full text-sm text-[#6B6863] file:mr-4 file:py-2 file:px-4 file:rounded-xl file:border-0 file:bg-[#1A1918] file:text-white file:text-sm file:cursor-pointer hover:file:bg-[#3D6B5A] file:transition-colors"
              />
              <p className="text-xs text-[#B0AEA9] mt-2 font-[IBM_Plex_Mono]">
                Máximo 5MB · apenas .csv
              </p>
            </div>
            <button
              type="submit"
              className="w-full bg-[#1A1918] text-white py-3 rounded-xl text-sm font-medium hover:bg-[#3D6B5A] transition-colors"
            >
              Importar do Goodreads
            </button>
          </form>

          {/* Como exportar */}
          <details className="mt-4 group">
            <summary className="text-xs font-[IBM_Plex_Mono] text-[#3D6B5A] cursor-pointer hover:text-[#1A1918]">
              Como exportar do Goodreads
            </summary>
            <ol className="mt-3 space-y-1.5 text-xs text-[#6B6863] list-decimal list-inside">
              <li>Acesse goodreads.com e faça login</li>
              <li>Vá em <strong>My Books → Import and Export</strong></li>
              <li>Clique em <strong>Export Library</strong></li>
              <li>Aguarde o arquivo ser gerado e faça download</li>
              <li>Faça upload do arquivo aqui</li>
            </ol>
          </details>
        </div>

        {/* Card CSV Genérico */}
        <div className="bg-white border border-[#ECEAE9] rounded-2xl p-6">
          <div className="flex items-start gap-4 mb-5">
            <div className="w-10 h-10 bg-[#E8F0EE] rounded-xl flex items-center justify-center text-xl flex-shrink-0">
              📄
            </div>
            <div>
              <h2 className="font-[Fraunces] text-lg font-semibold text-[#1A1918]">CSV Genérico</h2>
              <p className="text-xs text-[#6B6863] mt-0.5">
                Qualquer planilha com as colunas: <code className="bg-[#F2F1EF] px-1 rounded text-xs">title</code>,{' '}
                <code className="bg-[#F2F1EF] px-1 rounded text-xs">author</code>,{' '}
                <code className="bg-[#F2F1EF] px-1 rounded text-xs">status</code>,{' '}
                <code className="bg-[#F2F1EF] px-1 rounded text-xs">rating</code>,{' '}
                <code className="bg-[#F2F1EF] px-1 rounded text-xs">pages</code>
              </p>
            </div>
          </div>

          <form action={async (fd) => {
            'use server'
            const result = await importGenericCSV(fd)
            const params = new URLSearchParams({
              action: 'done',
              imported: String(result.imported ?? 0),
              skipped: String(result.skipped ?? 0),
              ...(result.error ? { error: result.error } : {}),
            })
            redirect(`/library/import?${params}`)
          }}>
            <div className="border-2 border-dashed border-[#ECEAE9] rounded-xl p-6 text-center mb-4">
              <input
                type="file"
                name="file"
                accept=".csv"
                required
                className="w-full text-sm text-[#6B6863] file:mr-4 file:py-2 file:px-4 file:rounded-xl file:border-0 file:bg-[#1A1918] file:text-white file:text-sm file:cursor-pointer hover:file:bg-[#3D6B5A] file:transition-colors"
              />
              <p className="text-xs text-[#B0AEA9] mt-2 font-[IBM_Plex_Mono]">
                Máximo 5MB · apenas .csv
              </p>
            </div>
            <button
              type="submit"
              className="w-full bg-[#1A1918] text-white py-3 rounded-xl text-sm font-medium hover:bg-[#3D6B5A] transition-colors"
            >
              Importar CSV
            </button>
          </form>

          {/* Template */}
          <div className="mt-4 bg-[#F8F9FA] rounded-xl p-4">
            <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] mb-2 uppercase tracking-widest">
              Exemplo de CSV
            </p>
            <pre className="text-[10px] font-[IBM_Plex_Mono] text-[#1A1918] overflow-x-auto">
{`title,author,status,rating,pages,year
Dom Casmurro,Machado de Assis,finished,5,256,1899
1984,George Orwell,want_to_read,,,1949`}
            </pre>
          </div>
        </div>
      </div>
    </div>
  )
}
