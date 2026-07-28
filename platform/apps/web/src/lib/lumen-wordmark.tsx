interface LumenWordmarkProps {
  className?: string
  variant?: 'light' | 'dark'
}

const INK = '#1A1918'
const INK_LIGHT = '#EFEFED'
const PROGRESS = '#4D7056'

export function LumenWordmark({ className, variant = 'light' }: LumenWordmarkProps) {
  const stroke = variant === 'dark' ? INK_LIGHT : INK
  const text = variant === 'dark' ? INK_LIGHT : INK

  return (
    <svg
      width="108"
      height="28"
      viewBox="0 0 140 36"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-label="Lumen"
      className={className}
    >
      <path
        d="M8 5 L8 27 L26 27"
        stroke={stroke}
        strokeWidth="2.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <line
        x1="8"
        y1="32"
        x2="128"
        y2="32"
        stroke={PROGRESS}
        strokeWidth="1.4"
        strokeLinecap="round"
      />
      <circle cx="134" cy="32" r="2.6" fill={PROGRESS} />
      <text
        x="30"
        y="27"
        fontFamily="Fraunces, Georgia, serif"
        fontSize="22"
        fontWeight="400"
        fill={text}
        letterSpacing="0.2"
      >
        umen
      </text>
    </svg>
  )
}
