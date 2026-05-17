import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import type { AuthUser } from '../types/auth'

interface SidebarProps {
  user: AuthUser
}

export default function Sidebar({ user }: SidebarProps) {
  const navigate = useNavigate()
  const location = useLocation()
  const { logout } = useAuth()

  const handleSignOut = async () => {
    await logout()
    navigate('/login')
  }

  const isActive = (path: string) => location.pathname === path

  const displayName = user.displayName || user.email?.split('@')[0] || 'Researcher'
  const avatarUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=b8860b&color=111&size=128`

  return (
    <aside className="sidebar">
      <div className="sidebar-content">
        <div className="logo-section">
          <h1 className="logo">
            <span className="logo-paper">Vyo</span>
            <span className="logo-verse">ma</span>
          </h1>
          <div className="logo-underline"></div>
        </div>

        <nav className="nav">
          <a href="/dashboard" className={`nav-link ${isActive('/dashboard') ? 'active' : ''}`}>
            <div className="nav-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path
                  d="M3 9L12 2L21 9V20C21 20.5304 20.7893 21.0391 20.4142 21.4142C20.0391 21.7893 19.5304 22 19 22H5C4.46957 22 3.96086 21.7893 3.58579 21.4142C3.21071 21.0391 3 20.5304 3 20V9Z"
                  stroke="currentColor"
                  strokeWidth="2"
                />
              </svg>
            </div>
            <span>Home</span>
            {isActive('/dashboard') && <div className="nav-indicator"></div>}
          </a>

          <a href="/scholar-search" className={`nav-link ${isActive('/scholar-search') ? 'active' : ''}`}>
            <div className="nav-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <circle cx="11" cy="11" r="8" stroke="currentColor" strokeWidth="2" />
                <path d="M21 21L16.65 16.65" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
            </div>
            <span>Search</span>
            {isActive('/scholar-search') && <div className="nav-indicator"></div>}
          </a>

          <a href="/library" className={`nav-link ${isActive('/library') ? 'active' : ''}`}>
            <div className="nav-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path
                  d="M19 21L12 16L5 21V5C5 4.46957 5.21071 3.96086 5.58579 3.58579C5.96086 3.21071 6.46957 3 7 3H17C17.5304 3 18.0391 3.21071 18.4142 3.58579C18.7893 3.96086 19 4.46957 19 5V21Z"
                  stroke="currentColor"
                  strokeWidth="2"
                />
              </svg>
            </div>
            <span>Library</span>
            {isActive('/library') && <div className="nav-indicator"></div>}
          </a>

          <a href="/network" className={`nav-link ${isActive('/network') ? 'active' : ''}`}>
            <div className="nav-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <circle cx="18" cy="5" r="3" stroke="currentColor" strokeWidth="2" />
                <circle cx="6" cy="12" r="3" stroke="currentColor" strokeWidth="2" />
                <circle cx="18" cy="19" r="3" stroke="currentColor" strokeWidth="2" />
                <path d="M8.59 13.51L15.42 17.49M15.41 6.51L8.59 10.49" stroke="currentColor" strokeWidth="2" />
              </svg>
            </div>
            <span>Network</span>
            {isActive('/network') && <div className="nav-indicator"></div>}
          </a>

          <a href="/chat" className={`nav-link ${isActive('/chat') ? 'active' : ''}`}>
            <div className="nav-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path
                  d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </div>
            <span>Chat</span>
            {isActive('/chat') && <div className="nav-indicator"></div>}
          </a>

          <a href="/mentor" className={`nav-link ${isActive('/mentor') ? 'active' : ''}`}>
            <div className="nav-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path
                  d="M17 21V19C17 17.9391 16.5786 16.9217 15.8284 16.1716C15.0783 15.4214 14.0609 15 13 15H5C3.93913 15 2.92172 15.4214 2.17157 16.1716C1.42143 16.9217 1 17.9391 1 19V21"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <circle cx="9" cy="7" r="4" stroke="currentColor" strokeWidth="2" />
                <path
                  d="M23 21V19C22.9993 18.1137 22.7044 17.2528 22.1614 16.5523C21.6184 15.8519 20.8581 15.3516 20 15.13"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path
                  d="M16 3.13C16.8604 3.35031 17.623 3.85071 18.1676 4.55232C18.7122 5.25392 19.0078 6.11683 19.0078 7.005C19.0078 7.89318 18.7122 8.75608 18.1676 9.45769C17.623 10.1593 16.8604 10.6597 16 10.88"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </div>
            <span>Mentor</span>
            {isActive('/mentor') && <div className="nav-indicator"></div>}
          </a>

          <a href="/feature-stack" className={`nav-link ${isActive('/feature-stack') ? 'active' : ''}`}>
            <div className="nav-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M4 5h16a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zm0 6h16a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-2a1 1 0 0 1 1-1zm0 6h16a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-2a1 1 0 0 1 1-1z" fill="currentColor" />
              </svg>
            </div>
            <span>Feature Stack</span>
            {isActive('/feature-stack') && <div className="nav-indicator"></div>}
          </a>
        </nav>

        <div className="sidebar-bottom">
          <div className="user-card">
            <img src={avatarUrl} alt="" className="user-avatar" />
            <div className="user-details">
              <p className="user-name">{displayName}</p>
              <p className="user-email">{user.email ?? ''}</p>
            </div>
          </div>

          <button type="button" onClick={handleSignOut} className="logout-btn">
            <svg viewBox="0 0 24 24" fill="none">
              <path
                d="M9 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H9M16 17L21 12M21 12L16 7M21 12H9"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <span>Logout</span>
          </button>
        </div>
      </div>
    </aside>
  )
}
