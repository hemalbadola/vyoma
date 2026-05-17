import { lazy, Suspense, useCallback, useEffect, useRef, useState } from 'react'
import './App.css'
import './components/landing/landing.css'
import VyomaLoader from './components/VyomaLoader'
import VyomaCursor from './components/VyomaCursor'
import VyomaNavbar from './components/landing/VyomaNavbar'
import DownloadSection from './components/landing/DownloadSection'
import { Link } from 'react-router-dom'
import PaymentModal, { type PricingPlan } from './components/landing/PaymentModal'
import MorningPreviewModal from './components/landing/MorningPreviewModal'
import ParticleBurstButton from './components/landing/ParticleBurstButton'
import {
  SentinelAnimation,
  CalendarMindAnimation,
  AmbientLayerAnimation,
} from './components/landing/PillarAnimations'
import { PRICING_PLANS } from './config/pricing'

const SceneManager = lazy(() => import('./components/SceneManager'))

declare global {
  interface Window {
    VYOMA_BACKEND?: string
  }
}

/** Default ambient loop level (0–1). Override with VITE_AMBIENT_VOLUME in .env */
const AMBIENT_VOLUME = Math.min(1, Math.max(0, Number(import.meta.env.VITE_AMBIENT_VOLUME) || 0.55))

function App() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const mainRef = useRef<HTMLElement | null>(null)

  const [sceneReady, setSceneReady] = useState(false)
  const [loaderVisible, setLoaderVisible] = useState(true)
  const [loaderExiting, setLoaderExiting] = useState(false)
  const [scrollProgress, setScrollProgress] = useState(0)
  const [showBackToTop, setShowBackToTop] = useState(false)
  const [isMuted, setIsMuted] = useState(false)
  const [paymentPlan, setPaymentPlan] = useState<PricingPlan | null>(null)
  const [morningPreviewOpen, setMorningPreviewOpen] = useState(false)
  const audioRef = useRef<HTMLAudioElement | null>(null)

  const loaderExitTimeout = useRef<number | undefined>(undefined)
  const loaderTriggeredRef = useRef(false)

  useEffect(() => {
    return () => {
      if (loaderExitTimeout.current !== undefined) {
        window.clearTimeout(loaderExitTimeout.current)
      }
    }
  }, [])

  useEffect(() => {
    const handleScroll = () => {
      const windowHeight = window.innerHeight
      const documentHeight = document.documentElement.scrollHeight
      const scrollTop = window.scrollY
      const scrollableHeight = documentHeight - windowHeight
      const progress = scrollableHeight > 0 ? (scrollTop / scrollableHeight) * 100 : 0

      setScrollProgress(progress)
      setShowBackToTop(scrollTop > windowHeight)
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const scrollToSection = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  const handleSceneReady = useCallback(() => {
    if (loaderTriggeredRef.current) return
    loaderTriggeredRef.current = true
    setSceneReady(true)
    setLoaderExiting(true)
    loaderExitTimeout.current = window.setTimeout(() => setLoaderVisible(false), 650)
  }, [])

  const toggleMute = useCallback(() => {
    const audio = audioRef.current
    if (!audio) return
    if (isMuted) {
      audio.volume = AMBIENT_VOLUME
      audio.play().catch(() => {})
      setIsMuted(false)
    } else {
      audio.pause()
      setIsMuted(true)
    }
  }, [isMuted])

  useEffect(() => {
    const audio = audioRef.current
    if (!audio) return

    audio.volume = AMBIENT_VOLUME

    const playAmbient = () =>
      audio.play().then(() => setIsMuted(false)).catch(() => setIsMuted(true))

    void playAmbient()

    // Browsers often block autoplay until a gesture — retry once on interaction
    const resumeOnGesture = () => {
      if (!audio.paused) return
      audio.volume = AMBIENT_VOLUME
      void playAmbient()
    }
    document.addEventListener('click', resumeOnGesture, { once: true })
    document.addEventListener('keydown', resumeOnGesture, { once: true })
    return () => {
      document.removeEventListener('click', resumeOnGesture)
      document.removeEventListener('keydown', resumeOnGesture)
    }
  }, [])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setPaymentPlan(null)
        setMorningPreviewOpen(false)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  return (
    <>
      <VyomaCursor />
      {loaderVisible && (
        <VyomaLoader
          fullscreen
          isExiting={loaderExiting}
          message={sceneReady ? 'Vyoma is ready.' : 'Gathering the Vyoma lattice…'}
        />
      )}

      <VyomaNavbar onGetStarted={() => scrollToSection('section-5')} />

      <div className="vyoma-scroll-bar" aria-hidden="true">
        <div className="vyoma-scroll-bar__fill" style={{ width: `${scrollProgress}%` }} />
      </div>

      {showBackToTop && (
        <button
          onClick={scrollToTop}
          className="fixed bottom-8 right-8 z-50 vyoma-pill-btn p-4 rounded-full shadow-lg transition-all duration-300 hover:scale-110 border border-amber-500/25"
          aria-label="Back to top"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M5 10l7-7m0 0l7 7m-7-7v18" />
          </svg>
        </button>
      )}

      <PaymentModal plan={paymentPlan} onClose={() => setPaymentPlan(null)} />
      <MorningPreviewModal open={morningPreviewOpen} onClose={() => setMorningPreviewOpen(false)} />

      <div id="smooth-wrapper">
        <div id="smooth-content">
          <Suspense fallback={<VyomaLoader fullscreen message="Rendering the Vyoma field…" />}>
            <SceneManager canvasRef={canvasRef} mainRef={mainRef} onReady={handleSceneReady} />
            <div className="vyoma-vignette" aria-hidden="true" />
          </Suspense>
          <main ref={mainRef} className="relative z-10">
            <section id="section-1" className="content-section section-1 hero-minimal">
              <p className="text-lg md:text-xl text-slate-300 max-w-3xl mx-auto mb-8 leading-relaxed hero-tagline">
                The intelligence between your plans and your time.
              </p>
              <div className="flex flex-col sm:flex-row gap-6 justify-center">
                <ParticleBurstButton
                  className="cta-button vyoma-cta text-center"
                  onActivate={() => scrollToSection('section-2')}
                >
                  [ Enter ]
                </ParticleBurstButton>
                <button
                  type="button"
                  className="secondary-button text-center"
                  onClick={() => setMorningPreviewOpen(true)}
                >
                  See the morning
                </button>
              </div>
            </section>

            <section id="section-2" className="content-section section-2">
              <div className="glass-panel max-w-lg">
                <p className="act-label">Act 2 — Confession</p>
                <h2 className="text-3xl md:text-5xl font-bold text-white mb-8 leading-tight">
                  You have the meetings.
                  <br />
                  The tasks.
                  <br />
                  The deadlines.
                </h2>
                <ul className="space-y-5 text-slate-300 text-lg leading-relaxed">
                  <li className="pain-point opacity-0">But when the moment arrives —</li>
                  <li className="pain-point opacity-0">you still have to figure out</li>
                  <li className="pain-point opacity-0">what to do with it.</li>
                </ul>
              </div>
            </section>

            <section id="section-3" className="content-section">
              <div id="card-observe" className="glass-panel process-card pillar-card">
                <div className="pillar-card__canvas">
                  <SentinelAnimation />
                </div>
                <div className="pillar-card__copy">
                  <p className="act-label">Act 3 — The Sentinel</p>
                  <h2 className="text-3xl font-bold text-white mb-2">The Sentinel</h2>
                  <p className="text-slate-300">
                    Watches every deadline. Knows when a window is closing before you feel the pressure. It nudges. Not
                    after. Before.
                  </p>
                </div>
              </div>
              <div id="card-orient" className="glass-panel process-card pillar-card ml-auto text-right">
                <div className="pillar-card__canvas">
                  <CalendarMindAnimation />
                </div>
                <div className="pillar-card__copy">
                  <p className="act-label">Act 3 — The Calendar Mind</p>
                  <h2 className="text-3xl font-bold text-white mb-2">The Calendar Mind</h2>
                  <p className="text-slate-300">
                    Reads the shape of your day. Finds the real gaps. Protects the time that matters. Not a scheduler. A
                    reader of time.
                  </p>
                </div>
              </div>
              <div id="card-decide" className="glass-panel process-card pillar-card">
                <div className="pillar-card__canvas">
                  <AmbientLayerAnimation />
                </div>
                <div className="pillar-card__copy">
                  <p className="act-label">Act 3 — The Ambient Layer</p>
                  <h2 className="text-3xl font-bold text-white mb-2">The Ambient Layer</h2>
                  <p className="text-slate-300">
                    On your lock screen. In your notifications. Everywhere you already look. Always present. Never in the
                    way.
                  </p>
                </div>
              </div>
              <div id="card-act" className="glass-panel process-card ml-auto text-right">
                <p className="act-label">Act 3 — Convergence</p>
                <h2 className="text-3xl font-bold text-white mb-2">One system</h2>
                <p className="text-slate-300">
                  Not three tools. One system that reads all three, connects the gaps between them, and tells you what to
                  do next.
                </p>
              </div>
            </section>

            <section id="section-4" className="content-section section-4 flex items-center justify-center">
              <div id="solution-panel" className="glass-panel w-full max-w-4xl text-left">
                <div className="p-2 md:p-4">
                  <p className="act-label">Act 3 — Convergence panel</p>
                  <h2 className="text-3xl md:text-5xl vyoma-wordmark-unified text-white mb-6">VYOMA</h2>
                  <p className="text-xl md:text-2xl text-slate-200 leading-relaxed max-w-3xl">
                    Not three tools. One system that reads all three, connects the gaps between them, and tells you what
                    to do next.
                  </p>
                </div>
              </div>
            </section>

            <section id="section-terminal" className="content-section section-4 flex items-center justify-center">
              <div className="glass-panel w-full max-w-4xl text-left terminal-panel">
                <p className="act-label">Act 4 — Terminal</p>
                <pre className="terminal-text text-slate-200 text-sm md:text-base leading-relaxed whitespace-pre-wrap font-mono">
                  {`07:58 AM  ↳ Syncing calendar...  3 meetings today
          ↳ Reading task board... 2 items due today
          ↳ Focus windows available: 11:00–12:30, 4:00–5:00

08:00 AM  ↳ Deadline: Project draft — due 3:00 PM
          ↳ Recommended window: 11:00 AM session
          ↳ Setting ambient reminder for 10:50 AM

08:01 AM  ↳ Your day is ready.

This happens every morning.
Without you asking.`}
                </pre>
              </div>
            </section>

            <section id="section-5" className="content-section section-5">
              <div className="w-full max-w-5xl mx-auto">
                <p className="act-label text-center">Act 5 — Pricing</p>
                <h2 className="text-3xl md:text-5xl font-bold text-white mb-12 text-center">Pick your rhythm.</h2>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                  {PRICING_PLANS.map((plan) => (
                    <div
                      key={plan.id}
                      className={`glass-panel text-center flex flex-col pricing-card ${
                        plan.id === 'monthly' ? 'pricing-featured border-amber-500/35' : ''
                      }`}
                    >
                      <span className="pricing-card__orbit" aria-hidden="true" />
                      <h3 className="text-xl font-bold text-white mb-2">
                        {plan.name}
                        {plan.id === 'monthly' && <span className="accent-gold"> ★</span>}
                      </h3>
                      <p className="text-3xl font-black accent-gold mb-2">{plan.price}</p>
                      <p className="text-slate-400 text-sm mb-4">
                        {plan.id === 'weekly'
                          ? 'Try before you commit'
                          : plan.id === 'monthly'
                            ? 'The full experience'
                            : 'Serious about your time'}
                      </p>
                      <button
                        type="button"
                        className="vyoma-btn-gold mx-auto"
                        onClick={() => setPaymentPlan(plan)}
                      >
                        {plan.cta}
                      </button>
                    </div>
                  ))}
                </div>
                <p className="text-center text-slate-500 text-sm mt-10">
                  No card required for the free trial · Cancel anytime · Powered by Razorpay
                </p>
              </div>
            </section>

            <DownloadSection />

            <section id="section-6" className="content-section section-6">
              <h2 id="orchestrate-heading" className="text-3xl md:text-5xl font-bold text-white mb-6">
                The intelligence between your plans and your time.
              </h2>
              <div className="flex flex-col sm:flex-row gap-6 justify-center mb-16">
                <Link to="/login" className="cta-button vyoma-cta text-center">
                  Sign In
                </Link>
                <a href="mailto:hello@vyoma.app" className="secondary-button text-center">
                  Contact
                </a>
              </div>
            </section>

            <footer className="content-section vyoma-footer border-t border-white/10">
              <p className="text-slate-400 text-center max-w-2xl mx-auto mb-6">
                The intelligence between your plans and your time.
              </p>
              <p className="text-slate-500 text-sm text-center">
                <a href="/privacy" className="hover:text-amber-200/90 transition-colors">
                  Privacy
                </a>
                <span className="mx-2">·</span>
                <a href="/terms" className="hover:text-amber-200/90 transition-colors">
                  Terms
                </a>
                <span className="mx-2">·</span>
                <a href="mailto:hello@vyoma.app" className="hover:text-amber-200/90 transition-colors">
                  Contact
                </a>
              </p>
            </footer>
          </main>

          <audio ref={audioRef} src="/vyoma-ambient.mp3" loop preload="auto" />
          <button
            onClick={toggleMute}
            className="vyoma-mute-btn"
            aria-label={isMuted ? 'Unmute ambient audio' : 'Mute ambient audio'}
            title={isMuted ? 'Unmute' : 'Mute'}
          >
            {isMuted ? '◇' : '◆'}
          </button>
        </div>
      </div>
    </>
  )
}

export default App
