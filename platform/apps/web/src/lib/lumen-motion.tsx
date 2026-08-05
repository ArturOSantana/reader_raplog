/**
 * lumen-motion.tsx
 *
 * Primitivos de animação do Lumen Web — casados com o grain de papel.
 *
 * Animações:
 *   - PageReveal: wrapper que aplica `page-enter` (fade + micro-slide)
 *   - Skel / SkelBlock: skeleton atoms sem gradiente branco — só pulse de opacidade
 *   - SkelCard / SkelText / SkelListTile: composições prontas
 *
 * O CSS das animações (page-enter, skel-pulse) vive em globals.css e
 * é compartilhado por qualquer classe `.page-enter` ou `.skel` no projeto.
 */

import React from 'react'

// ─────────────────────────────────────────────────────────────────────────────
// PAGE REVEAL
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Aplica o reveal editorial de entrada de página:
 * fade 0→1 + micro-slide 6 px para cima em 220 ms (easeOutCubic).
 *
 * Uso:
 * ```tsx
 * export default function MyPage() {
 *   return <PageReveal><div>conteúdo</div></PageReveal>
 * }
 * ```
 */
export function PageReveal({ children, className = '' }: {
  children: React.ReactNode
  className?: string
}) {
  return (
    <div className={`page-enter${className ? ` ${className}` : ''}`}>
      {children}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON ATOMS
// ─────────────────────────────────────────────────────────────────────────────

interface SkelBlockProps {
  /** largura CSS, default "100%" */
  width?: string
  /** altura CSS, default "1rem" */
  height?: string
  /** border-radius CSS, default "4px" */
  radius?: string
  className?: string
}

/**
 * Átomo de skeleton — pulse de opacidade, sem gradiente branco.
 * Idêntico nos dois temas: a cor de base troca via CSS (.dark).
 *
 * ```tsx
 * <SkelBlock height="14px" width="60%" />
 * ```
 */
export function SkelBlock({
  width = '100%',
  height = '1rem',
  radius = '4px',
  className = '',
}: SkelBlockProps) {
  return (
    <div
      className={`skel${className ? ` ${className}` : ''}`}
      style={{ width, height, borderRadius: radius }}
      aria-hidden
    />
  )
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON COMPOSIÇÕES
// ─────────────────────────────────────────────────────────────────────────────

/** Linha de texto skeleton — largura variável para parecer orgânico */
export function SkelText({ lines = 3 }: { lines?: number }) {
  const widths = ['100%', '85%', '70%', '92%', '60%', '80%']
  return (
    <div className="space-y-2">
      {Array.from({ length: lines }, (_, i) => (
        <SkelBlock
          key={i}
          height="13px"
          width={widths[i % widths.length]}
          // Atrasa levemente cada linha para o pulse parecer orgânico
          style={{ animationDelay: `${i * 80}ms` } as React.CSSProperties}
        />
      ))}
    </div>
  )
}

/** Card skeleton de altura fixa */
export function SkelCard({ height = '100px' }: { height?: string }) {
  return (
    <SkelBlock height={height} radius="6px" />
  )
}

/** Linha de lista com avatar + título + subtítulo */
export function SkelListTile() {
  return (
    <div className="flex items-center gap-3 px-4 py-3">
      {/* avatar */}
      <SkelBlock width="40px" height="40px" radius="20px" />
      {/* texto */}
      <div className="flex-1 space-y-2">
        <SkelBlock height="13px" width="70%" />
        <SkelBlock height="11px" width="45%" />
      </div>
    </div>
  )
}

/** Bloco de stat — número grande + label */
export function SkelStat() {
  return (
    <div className="space-y-2 p-5">
      <SkelBlock height="32px" width="48px" radius="4px" />
      <SkelBlock height="11px" width="80px" radius="4px" />
    </div>
  )
}

/** Grid 1×N de SkelListTile */
export function SkelScreenList({ count = 6 }: { count?: number }) {
  return (
    <div>
      {Array.from({ length: count }, (_, i) => (
        <SkelListTile key={i} />
      ))}
    </div>
  )
}
