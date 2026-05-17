import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react'
import type { AuthUser } from '../types/auth'

const GUEST_USER: AuthUser = {
  uid: 'guest',
  displayName: 'Guest',
  email: 'guest@local.dev'
}

interface AuthContextType {
  user: AuthUser | null
  loading: boolean
  signInGuest: () => void
  logout: () => Promise<void>
  /** Bearer token for backend calls when Firebase is not wired; set `VITE_DEV_API_TOKEN` in `.env`. */
  getApiToken: () => Promise<string | undefined>
}

export const AuthContext = createContext<AuthContextType | null>(null)

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}

interface AuthProviderProps {
  children: ReactNode
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [loading] = useState(false)

  const signInGuest = useCallback(() => {
    setUser(GUEST_USER)
  }, [])

  const logout = useCallback(async () => {
    setUser(null)
  }, [])

  const getApiToken = useCallback(async () => {
    const t = import.meta.env.VITE_DEV_API_TOKEN
    return typeof t === 'string' && t.trim() !== '' ? t.trim() : undefined
  }, [])

  const value = useMemo(
    () => ({
      user,
      loading,
      signInGuest,
      logout,
      getApiToken
    }),
    [user, loading, signInGuest, logout, getApiToken]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
