import { useEffect, useRef, useCallback, useState } from 'react'

// ─── Configuration ──────────────────────────────────────────────────────────
const COLORS = {
  primary: '#E8D3A8',
  glow: '#D8B57A',
  ring: '#F3E0B8',
}

const SPRING = {
  stiffness: 0.12,
  damping: 0.78,
  mass: 1.0,
}

const SIZES = {
  dotMin: 5,
  dotMax: 6,
  ringIdle: 0,
  ringHover: 22,
  ringClick: 16,
  trailDotSize: 2,
}

const MAGNETIC = {
  radius: 80,
  strength: 0.35,
}

const TRAIL_MAX = 5
const TRAIL_MIN_DISTANCE = 12
const TRAIL_FADE_RATE = 0.025

// ─── Types ──────────────────────────────────────────────────────────────────
interface TrailPoint {
  x: number
  y: number
  opacity: number
  born: number
}

// ─── Component ──────────────────────────────────────────────────────────────
export default function VyomaCursor() {
  const [finePointer] = useState(() =>
    typeof window !== 'undefined' && window.matchMedia('(hover: hover) and (pointer: fine)').matches
  )
  const dotRef = useRef<HTMLDivElement>(null)
  const ringRef = useRef<HTMLDivElement>(null)
  const trailCanvasRef = useRef<HTMLCanvasElement>(null)
  const rafRef = useRef<number>(0)

  // State refs (avoid re-renders — cursor runs in rAF loop)
  const mouse = useRef({ x: -100, y: -100 })
  const pos = useRef({ x: -100, y: -100 })
  const vel = useRef({ x: 0, y: 0 })
  const isHovering = useRef(false)
  const isClicking = useRef(false)
  const isDragging = useRef(false)
  const isText = useRef(false)
  const isHidden = useRef(false)
  const trails = useRef<TrailPoint[]>([])
  const lastTrailPos = useRef({ x: 0, y: 0 })
  const magnetTarget = useRef<{ x: number; y: number; active: boolean }>({ x: 0, y: 0, active: false })

  // ─── Magnetic field detection ─────────────────────────────────────────────
  const checkMagnetic = useCallback((mx: number, my: number) => {
    const magneticEls = document.querySelectorAll(
      'a, button, .cta-button, .vyoma-cta, .secondary-button, .glass-panel.process-card, .vyoma-pill-btn'
    )
    let closest: { el: Element; dist: number; cx: number; cy: number } | null = null

    for (const el of Array.from(magneticEls)) {
      const rect = el.getBoundingClientRect()
      const cx = rect.left + rect.width / 2
      const cy = rect.top + rect.height / 2
      const dist = Math.hypot(mx - cx, my - cy)
      if (dist < MAGNETIC.radius && (!closest || dist < closest.dist)) {
        closest = { el, dist, cx, cy }
      }
    }

    if (closest) {
      const t = 1 - closest.dist / MAGNETIC.radius
      const eased = t * t * MAGNETIC.strength
      magnetTarget.current = {
        x: closest.cx,
        y: closest.cy,
        active: true,
      }
      // Apply gravitational pull
      mouse.current.x += (closest.cx - mx) * eased
      mouse.current.y += (closest.cy - my) * eased
    } else {
      magnetTarget.current.active = false
    }
  }, [])

  // ─── Event handlers ───────────────────────────────────────────────────────
  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      mouse.current.x = e.clientX
      mouse.current.y = e.clientY
      checkMagnetic(e.clientX, e.clientY)

      // Detect text cursor areas
      const target = e.target as HTMLElement
      const computed = window.getComputedStyle(target)
      isText.current = computed.cursor === 'text' ||
        target.tagName === 'INPUT' ||
        target.tagName === 'TEXTAREA' ||
        target.isContentEditable
    }

    const onDown = (e: MouseEvent) => {
      isClicking.current = true
      // Detect drag start
      const target = e.target as HTMLElement
      if (target.draggable || target.closest('[draggable]')) {
        isDragging.current = true
      }
    }

    const onUp = () => {
      isClicking.current = false
      isDragging.current = false
    }

    const onEnterInteractive = (e: Event) => {
      const target = e.target as HTMLElement
      if (
        target.matches('a, button, [role="button"], .cta-button, .vyoma-cta, .secondary-button, .vyoma-pill-btn') ||
        target.closest('a, button, [role="button"], .cta-button, .vyoma-cta, .secondary-button, .vyoma-pill-btn')
      ) {
        isHovering.current = true
      }
    }

    const onLeaveInteractive = () => {
      isHovering.current = false
    }

    const onLeave = () => {
      isHidden.current = true
    }

    const onEnter = () => {
      isHidden.current = false
    }

    window.addEventListener('mousemove', onMove, { passive: true })
    window.addEventListener('mousedown', onDown)
    window.addEventListener('mouseup', onUp)
    document.addEventListener('mouseover', onEnterInteractive)
    document.addEventListener('mouseout', onLeaveInteractive)
    document.documentElement.addEventListener('mouseleave', onLeave)
    document.documentElement.addEventListener('mouseenter', onEnter)

    return () => {
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mousedown', onDown)
      window.removeEventListener('mouseup', onUp)
      document.removeEventListener('mouseover', onEnterInteractive)
      document.removeEventListener('mouseout', onLeaveInteractive)
      document.documentElement.removeEventListener('mouseleave', onLeave)
      document.documentElement.removeEventListener('mouseenter', onEnter)
    }
  }, [checkMagnetic])

  // ─── Animation loop ───────────────────────────────────────────────────────
  useEffect(() => {
    const dot = dotRef.current
    const ring = ringRef.current
    const canvas = trailCanvasRef.current
    if (!dot || !ring || !canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    // Size canvas
    const resizeCanvas = () => {
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
    }
    resizeCanvas()
    window.addEventListener('resize', resizeCanvas)

    let prevTime = performance.now()

    const animate = (now: number) => {
      const dt = Math.min((now - prevTime) / 16.67, 3) // Normalize to ~60fps, cap at 3x
      prevTime = now

      // Spring physics — feels calm and expensive
      const dx = mouse.current.x - pos.current.x
      const dy = mouse.current.y - pos.current.y
      const ax = dx * SPRING.stiffness - vel.current.x * SPRING.damping
      const ay = dy * SPRING.stiffness - vel.current.y * SPRING.damping
      vel.current.x += ax * dt
      vel.current.y += ay * dt
      pos.current.x += vel.current.x * dt
      pos.current.y += vel.current.y * dt

      // Velocity magnitude for inertial effects
      const speed = Math.hypot(vel.current.x, vel.current.y)

      // ── Core dot ──────────────────────────────────────────────────────
      const hidden = isHidden.current
      const clicking = isClicking.current
      const hovering = isHovering.current
      const textMode = isText.current
      const dragging = isDragging.current

      // Dot size: compression on click, slight stretch on speed
      let dotSize = SIZES.dotMin
      if (clicking) {
        dotSize = SIZES.dotMin * 0.6 // Gravity pulse — compression
      } else if (hovering) {
        dotSize = SIZES.dotMax
      }

      // Inertial stretch — dot elongates microscopically along motion axis
      const stretchFactor = Math.min(speed * 0.04, 0.4)
      const angle = Math.atan2(vel.current.y, vel.current.x)
      const scaleX = 1 + stretchFactor
      const scaleY = 1 - stretchFactor * 0.3
      const rotDeg = (angle * 180) / Math.PI

      // Text mode: celestial vertical line
      if (textMode) {
        dot.style.transform = `translate(${pos.current.x}px, ${pos.current.y}px) translate(-50%, -50%) scaleX(0.3) scaleY(2.4)`
        dot.style.borderRadius = '1px'
      } else {
        dot.style.transform = `translate(${pos.current.x}px, ${pos.current.y}px) translate(-50%, -50%) rotate(${rotDeg}deg) scaleX(${scaleX}) scaleY(${scaleY})`
        dot.style.borderRadius = '50%'
      }

      dot.style.width = `${dotSize}px`
      dot.style.height = `${dotSize}px`
      dot.style.opacity = hidden ? '0' : clicking ? '0.9' : '1'

      // Dot glow intensity — adaptive
      const glowSize = clicking ? 4 : hovering ? 8 : 5
      const glowOpacity = clicking ? 0.12 : hovering ? 0.1 : 0.06
      dot.style.boxShadow = `0 0 ${glowSize}px rgba(232, 211, 168, ${glowOpacity})`

      // ── Outer ring ────────────────────────────────────────────────────
      let ringSize = SIZES.ringIdle
      let ringOpacity = 0
      let ringBorder = 1

      if (clicking) {
        ringSize = SIZES.ringClick
        ringOpacity = 0.25
        ringBorder = 1.5
      } else if (hovering) {
        ringSize = SIZES.ringHover
        ringOpacity = 0.18
        ringBorder = 1
      } else if (dragging) {
        // Elongate along motion axis
        ringSize = 28
        ringOpacity = 0.12
      }

      // Drag elongation
      const ringStretch = dragging ? Math.min(speed * 0.06, 0.5) : 0
      const ringScaleX = 1 + ringStretch
      const ringScaleY = 1 - ringStretch * 0.25

      ring.style.transform = `translate(${pos.current.x}px, ${pos.current.y}px) translate(-50%, -50%) rotate(${rotDeg}deg) scaleX(${ringScaleX}) scaleY(${ringScaleY})`
      ring.style.width = `${ringSize}px`
      ring.style.height = `${ringSize}px`
      ring.style.opacity = hidden ? '0' : String(ringOpacity)
      ring.style.borderWidth = `${ringBorder}px`

      // ── Constellation trails ──────────────────────────────────────────
      // Only spawn during fast movement
      if (speed > 3.5) {
        const distFromLast = Math.hypot(
          pos.current.x - lastTrailPos.current.x,
          pos.current.y - lastTrailPos.current.y
        )
        if (distFromLast > TRAIL_MIN_DISTANCE) {
          trails.current.push({
            x: pos.current.x,
            y: pos.current.y,
            opacity: Math.min(speed * 0.012, 0.18),
            born: now,
          })
          lastTrailPos.current = { x: pos.current.x, y: pos.current.y }
          if (trails.current.length > TRAIL_MAX) {
            trails.current.shift()
          }
        }
      }

      // Draw trails on canvas
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      trails.current = trails.current.filter((t) => {
        t.opacity -= TRAIL_FADE_RATE * dt
        if (t.opacity <= 0) return false

        ctx.beginPath()
        ctx.arc(t.x, t.y, SIZES.trailDotSize, 0, Math.PI * 2)
        ctx.fillStyle = `rgba(232, 211, 168, ${t.opacity})`
        ctx.fill()

        // Tiny glow per trail point
        ctx.beginPath()
        ctx.arc(t.x, t.y, SIZES.trailDotSize + 2, 0, Math.PI * 2)
        ctx.fillStyle = `rgba(216, 181, 122, ${t.opacity * 0.3})`
        ctx.fill()

        return true
      })

      rafRef.current = requestAnimationFrame(animate)
    }

    rafRef.current = requestAnimationFrame(animate)

    return () => {
      cancelAnimationFrame(rafRef.current)
      window.removeEventListener('resize', resizeCanvas)
    }
  }, [])

  if (!finePointer) return null

  // ─── Render ───────────────────────────────────────────────────────────────
  return (
    <>
      {/* Trail canvas — full viewport, behind cursor elements */}
      <canvas
        ref={trailCanvasRef}
        aria-hidden="true"
        style={{
          position: 'fixed',
          inset: 0,
          zIndex: 99997,
          pointerEvents: 'none',
          width: '100vw',
          height: '100vh',
        }}
      />

      {/* Core dot — the consciousness point */}
      <div
        ref={dotRef}
        aria-hidden="true"
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          zIndex: 99999,
          pointerEvents: 'none',
          width: `${SIZES.dotMin}px`,
          height: `${SIZES.dotMin}px`,
          borderRadius: '50%',
          backgroundColor: COLORS.primary,
          willChange: 'transform, width, height, opacity',
          transition: 'width 0.2s cubic-bezier(0.23, 1, 0.32, 1), height 0.2s cubic-bezier(0.23, 1, 0.32, 1), border-radius 0.15s ease',
        }}
      />

      {/* Outer ring — focus field */}
      <div
        ref={ringRef}
        aria-hidden="true"
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          zIndex: 99998,
          pointerEvents: 'none',
          width: '0px',
          height: '0px',
          borderRadius: '50%',
          border: `1px solid ${COLORS.ring}`,
          backgroundColor: 'transparent',
          opacity: 0,
          willChange: 'transform, width, height, opacity',
          transition: 'width 0.35s cubic-bezier(0.23, 1, 0.32, 1), height 0.35s cubic-bezier(0.23, 1, 0.32, 1), opacity 0.3s ease, border-width 0.15s ease',
        }}
      />
    </>
  )
}
