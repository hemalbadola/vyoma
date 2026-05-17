import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import './Login.css'

export default function Login() {
  const navigate = useNavigate()
  const { signInGuest } = useAuth()

  const handleContinue = () => {
    signInGuest()
    navigate('/dashboard', { replace: true })
  }

  return (
    <div className="login-container">
      <div className="login-background">
        <div className="particle"></div>
        <div className="particle"></div>
        <div className="particle"></div>
        <div className="particle"></div>
        <div className="particle"></div>
      </div>

      <div className="login-card">
        <div className="login-header">
          <h1 className="login-title">
            <span className="title-paper">Paper</span>
            <span className="title-verse">Verse</span>
          </h1>
          <p className="login-subtitle">Sign-in is offline for now — continue with a local guest session.</p>
        </div>

        <div className="login-form" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <button type="button" onClick={handleContinue} className="submit-button">
            Continue to dashboard
          </button>
          <p className="login-subtitle" style={{ fontSize: '0.85rem', opacity: 0.85, margin: 0 }}>
            API search/save uses <code style={{ fontSize: '0.8em' }}>VITE_DEV_API_TOKEN</code> when set; otherwise
            requests are sent without a bearer token.
          </p>
        </div>

        <div className="login-footer">
          <p>
            <a href="/" className="toggle-mode" style={{ textDecoration: 'none' }}>
              ← Back to home
            </a>
          </p>
        </div>
      </div>
    </div>
  )
}
