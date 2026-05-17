import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useAuth } from './AuthContext'
import { subscribeUserProfile } from '../services/userProfile'
import type { VyomaUserProfile } from '../types/userProfile'

type UserProfileContextValue = {
  profile: VyomaUserProfile | null
  loading: boolean
  hasProfile: boolean
}

const UserProfileContext = createContext<UserProfileContextValue | null>(null)

export function useUserProfile() {
  const ctx = useContext(UserProfileContext)
  if (!ctx) {
    throw new Error('useUserProfile must be used within UserProfileProvider')
  }
  return ctx
}

export function UserProfileProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const [profile, setProfile] = useState<VyomaUserProfile | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!user) {
      setProfile(null)
      setLoading(false)
      return
    }

    setLoading(true)
    const unsub = subscribeUserProfile(
      user.uid,
      (next) => {
        setProfile(next)
        setLoading(false)
      },
      () => setLoading(false)
    )

    return unsub
  }, [user?.uid])

  const value = useMemo(
    () => ({
      profile,
      loading: Boolean(user) && loading,
      hasProfile: Boolean(profile),
    }),
    [profile, loading, user]
  )

  return <UserProfileContext.Provider value={value}>{children}</UserProfileContext.Provider>
}
