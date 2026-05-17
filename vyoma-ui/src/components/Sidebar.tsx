import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { useUserProfile } from '../contexts/UserProfileContext'
import '../styles/vyoma-app.css'
import '../styles/vyoma-sidebar.css'

/** @deprecated `user` prop ignored — profile comes from context */
export default function Sidebar(_props?: { user?: unknown }) {
  const navigate = useNavigate()
  const location = useLocation()
  const { user, logout } = useAuth()
  const { profile } = useUserProfile()

  if (!user) return null

  const handleSignOut = async () => {
    await logout()
    navigate('/login')
  }

  const isActive = (path: string) => location.pathname === path

  const displayName = profile?.displayName || user.displayName || user.email?.split('@')[0] || 'Operator'
  const handle = profile?.username ? `@${profile.username}` : user.email ?? ''
  const avatarUrl =
    user.photoURL ||
    `https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=1a1508&color=c9a84c&size=128`

  const navItems = [
    { path: '/dashboard', label: 'War Room', icon: '⌂' },
    { path: '/chat', label: 'Ask Vyoma', icon: '◈' },
    { path: '/feature-stack', label: 'Systems', icon: '▤' },
  ]

  return (
    <aside className="vyoma-sidebar">
      <div className="vyoma-sidebar__brand">
        <Link to="/dashboard" className="vyoma-sidebar__logo-link">
          <img src="/vyomaicon.png" alt="" className="vyoma-sidebar__mark" />
          <span className="vyoma-sidebar__wordmark font-cormorant">VYOMA</span>
        </Link>
      </div>

      <nav className="vyoma-sidebar__nav">
        {navItems.map((item) => (
          <Link
            key={item.path}
            to={item.path}
            className={`vyoma-sidebar__link${isActive(item.path) ? ' vyoma-sidebar__link--active' : ''}`}
          >
            <span className="vyoma-sidebar__icon" aria-hidden="true">
              {item.icon}
            </span>
            {item.label}
          </Link>
        ))}
        <Link to="/" className="vyoma-sidebar__link">
          <span className="vyoma-sidebar__icon" aria-hidden="true">
            ↗
          </span>
          Landing
        </Link>
      </nav>

      <div className="vyoma-sidebar__footer">
        <div className="vyoma-sidebar__user">
          <img src={avatarUrl} alt="" className="vyoma-sidebar__avatar" />
          <div>
            <p className="vyoma-sidebar__name">{displayName}</p>
            <p className="vyoma-sidebar__handle">{handle}</p>
          </div>
        </div>
        <button type="button" className="vyoma-sidebar__logout" onClick={handleSignOut}>
          Sign out
        </button>
      </div>
    </aside>
  )
}
