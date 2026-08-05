/**
 * dominant-color.ts
 *
 * Extrai a cor dominante de uma imagem remota (server-side only).
 * Retorna uma string CSS `r g b` compatível com `rgb()` e `rgba()`.
 *
 * Usado para o "color wash" de 2-3 % de opacidade na página de clube,
 * derivado da capa do livro atual — sem JS cliente, sem runtime extra.
 */

import sharp from 'sharp'

/**
 * Faz fetch da imagem, reduz para um pixel via sharp e retorna
 * a cor dominante como tupla [r, g, b].
 * Em caso de erro (URL inválida, timeout, etc.) retorna null silenciosamente.
 */
export async function getDominantColor(
  imageUrl: string,
): Promise<[number, number, number] | null> {
  try {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 3000)

    const response = await fetch(imageUrl, {
      signal: controller.signal,
      // Não cacheia no browser — é server-side, mas deixa o cache do Next
      next: { revalidate: 3600 },
    })
    clearTimeout(timeout)

    if (!response.ok) return null

    const buffer = Buffer.from(await response.arrayBuffer())

    // Reduz para 1×1 px com modo "average" para obter a cor média/dominante
    const { data } = await sharp(buffer)
      .resize(1, 1, { fit: 'cover', kernel: 'lanczos3' })
      .raw()
      .toBuffer({ resolveWithObject: true })

    const r = data[0]
    const g = data[1]
    const b = data[2]

    // Descarta cores quase brancas/pretas — não acrescentam personalidade
    const brightness = (r + g + b) / 3
    if (brightness > 230 || brightness < 20) return null

    return [r, g, b]
  } catch {
    return null
  }
}

/**
 * Converte a tupla RGB em string CSS para uso em `rgba(r, g, b, opacity)`.
 */
export function rgbToCss(color: [number, number, number]): string {
  return `${color[0]}, ${color[1]}, ${color[2]}`
}
