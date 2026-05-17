import { Link } from 'react-router-dom'

type VyomaNavbarProps = {
  onGetStarted: () => void
}

export default function VyomaNavbar({ onGetStarted }: VyomaNavbarProps) {
  return (
    <header className="vyoma-nav">
      <a href="/" className="vyoma-nav-brand" aria-label="Vyoma home">
        <img src="/vyoma-logo.png" alt="" className="vyoma-nav-mark" />
        <span className="vyoma-nav-wordmark font-cormorant">VYOMA</span>
      </a>
      <div className="vyoma-nav-actions">
        <button type="button" className="vyoma-nav-cta-ghost" onClick={onGetStarted}>
          Get started
        </button>
        <Link to="/login" className="vyoma-nav-signin">
          Sign in
        </Link>
      </div>
    </header>
  )
}
