import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { createUserProfile } from '../services/userProfile'
import '../components/landing/landing.css'
import './Login.css'

export default function ProfileSetup() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [username, setUsername] = useState('')
  const [tagline, setTagline] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await createUserProfile({
        username,
        tagline,
        displayName: user?.displayName ?? undefined,
      })
      navigate('/dashboard', { replace: true })
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Could not create profile')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="login-container vyoma-login">
      <div className="login-background" aria-hidden="true">
        <div className="particle" />
        <div className="particle" />
        <div className="particle" />
      </div>

      <div className="login-card">
        <div className="login-header">
          <img src="/vyoma-logo.png" alt="" className="login-logo-mark" />
          <h1 className="login-title font-cormorant login-wordmark-vyoma">VYOMA</h1>
          <p className="login-subtitle">Set up your operator profile — synced with the mobile app.</p>
        </div>

        <form onSubmit={handleSubmit} className="login-form">
          <div className="form-group">
            <label htmlFor="username">Username</label>
            <input
              id="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="hemal"
              required
              minLength={3}
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label htmlFor="tagline">Tagline</label>
            <input
              id="tagline"
              value={tagline}
              onChange={(e) => setTagline(e.target.value)}
              placeholder="Grad student · building in public"
              required
              disabled={loading}
            />
          </div>

          {error && (
            <div className="error-message" role="alert">
              {error}
            </div>
          )}

          <button type="submit" className="submit-button" disabled={loading}>
            {loading ? <span className="loading-spinner" /> : 'Enter War Room'}
          </button>
        </form>
      </div>
    </div>
  )
}
