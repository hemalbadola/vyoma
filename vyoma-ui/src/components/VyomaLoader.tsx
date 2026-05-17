import { useId } from 'react'

type VyomaLoaderProps = {
  fullscreen?: boolean
  message?: string
  isExiting?: boolean
}

const VyomaLoader = ({
  fullscreen = false,
  message = 'Preparing Vyoma…',
  isExiting = false
}: VyomaLoaderProps) => {
  const gradientId = useId()
  const ringGradientId = useId()

  return (
    <div
      className={[
        'vyoma-loader',
        fullscreen ? 'vyoma-loader--fullscreen' : '',
        isExiting ? 'vyoma-loader--exit' : ''
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <div className="vyoma-loader__logo" aria-hidden="true">
        <svg viewBox="0 0 120 120" role="presentation">
          <defs>
            <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#fff8e7" />
              <stop offset="40%" stopColor="#d4af37" />
              <stop offset="100%" stopColor="#6a5218" />
            </linearGradient>
            <linearGradient id={ringGradientId} x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor="#f0d78c" />
              <stop offset="100%" stopColor="#8a6e28" />
            </linearGradient>
          </defs>
          <circle cx="60" cy="60" r="38" fill="none" stroke={`url(#${ringGradientId})`} strokeWidth="5" opacity="0.85" />
          <line x1="60" y1="22" x2="60" y2="58" stroke={`url(#${gradientId})`} strokeWidth="3" strokeLinecap="round" />
          <circle cx="60" cy="68" r="6" fill={`url(#${gradientId})`} />
        </svg>
      </div>
      <div className="vyoma-loader__progress" aria-hidden="true">
        <div className="vyoma-loader__progress-track">
          <div className="vyoma-loader__progress-fill" />
        </div>
      </div>
      {message ? (
        <p className="vyoma-loader__message" aria-live="polite">
          {message}
        </p>
      ) : null}
    </div>
  )
}

export default VyomaLoader
