import { onAuthStateChanged, signOut } from 'firebase/auth'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { auth } from '../firebase'
import type { AuthUser } from '../types/auth'

interface AuthContextType {
  user: AuthUser | null
  loading: boolean
  logout: () => Promise<void>
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
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (fbUser) => {
      if (fbUser) {
        setUser({
          uid: fbUser.uid,
          displayName: fbUser.displayName,
          email: fbUser.email,
          photoURL: fbUser.photoURL,
        })
      } else {
        setUser(null)
      }
      setLoading(false)
    })
    return unsubscribe
  }, [])

  const logout = useCallback(async () => {
    await signOut(auth)
    setUser(null)
  }, [])

  const getApiToken = useCallback(async () => {
    const fbUser = auth.currentUser
    if (fbUser) {
      try {
        return await fbUser.getIdToken()
      } catch {
        return undefined
      }
    }
    const t = import.meta.env.VITE_DEV_API_TOKEN
    return typeof t === 'string' && t.trim() !== '' ? t.trim() : undefined
  }, [])

  const value = useMemo(
    () => ({
      user,
      loading,
      logout,
      getApiToken,
    }),
    [user, loading, logout, getApiToken]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
