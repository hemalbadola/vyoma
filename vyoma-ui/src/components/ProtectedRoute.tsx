import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { useUserProfile } from '../contexts/UserProfileContext'

interface ProtectedRouteProps {
  children: React.ReactNode
  requireProfile?: boolean
}

export default function ProtectedRoute({ children, requireProfile = true }: ProtectedRouteProps) {
  const { user, loading: authLoading } = useAuth()
  const { hasProfile, loading: profileLoading } = useUserProfile()
  const location = useLocation()

  const loading = authLoading || (requireProfile && user && profileLoading)

  if (loading) {
    return (
      <div className="vyoma-route-loading">
        <div className="vyoma-route-loading__spinner" />
        <p>Syncing your Vyoma field…</p>
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }

  if (requireProfile && !hasProfile && location.pathname !== '/profile-setup') {
    return <Navigate to="/profile-setup" replace />
  }

  if (!requireProfile && hasProfile && location.pathname === '/profile-setup') {
    return <Navigate to="/dashboard" replace />
  }

  return <>{children}</>
}
