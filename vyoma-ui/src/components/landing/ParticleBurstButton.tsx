import { useCallback, useRef, type ReactNode } from 'react'

type ParticleBurstButtonProps = {
  children: ReactNode
  className?: string
  onActivate: () => void
}

type Particle = { x: number; y: number; vx: number; vy: number; life: number }

export default function ParticleBurstButton({ children, className = '', onActivate }: ParticleBurstButtonProps) {
  const btnRef = useRef<HTMLButtonElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)

  const burst = useCallback(() => {
    const btn = btnRef.current
    const canvas = canvasRef.current
    if (!btn || !canvas) return

    const rect = btn.getBoundingClientRect()
    canvas.width = rect.width
    canvas.height = rect.height
    canvas.style.width = `${rect.width}px`
    canvas.style.height = `${rect.height}px`

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const cx = rect.width / 2
    const cy = rect.height / 2
    const particles: Particle[] = Array.from({ length: 24 }, () => {
      const angle = Math.random() * Math.PI * 2
      const speed = 1.5 + Math.random() * 3.5
      return {
        x: cx,
        y: cy,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 1,
      }
    })

    let frame = 0
    const draw = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      let alive = false
      for (const p of particles) {
        p.x += p.vx
        p.y += p.vy
        p.life -= 0.04
        if (p.life <= 0) continue
        alive = true
        ctx.beginPath()
        ctx.arc(p.x, p.y, 2, 0, Math.PI * 2)
        ctx.fillStyle = `rgba(201, 168, 76, ${p.life})`
        ctx.fill()
      }
      frame += 1
      if (alive && frame < 40) requestAnimationFrame(draw)
      else ctx.clearRect(0, 0, canvas.width, canvas.height)
    }
    requestAnimationFrame(draw)
  }, [])

  const handleClick = () => {
    burst()
    window.setTimeout(onActivate, 180)
  }

  return (
    <button ref={btnRef} type="button" className={`particle-burst-btn ${className}`.trim()} onClick={handleClick}>
      <canvas ref={canvasRef} className="particle-burst-canvas" aria-hidden="true" />
      {children}
    </button>
  )
}
