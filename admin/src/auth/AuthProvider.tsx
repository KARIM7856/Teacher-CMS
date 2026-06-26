import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import type { Profile } from '../types/database'

interface AuthContextValue {
  session: Session | null
  profile: Profile | null
  isAdmin: boolean
  loading: boolean
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

async function fetchProfile(userId: string): Promise<Profile | null> {
  const { data } = await supabase
    .from('profiles')
    .select('id, role, display_name, avatar_url')
    .eq('id', userId)
    .single()
  return (data as Profile) ?? null
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [profile, setProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let active = true

    supabase.auth.getSession().then(async ({ data }) => {
      if (!active) return
      setSession(data.session)
      if (data.session) setProfile(await fetchProfile(data.session.user.id))
      setLoading(false)
    })

    const { data: sub } = supabase.auth.onAuthStateChange(async (_event, next) => {
      setSession(next)
      setProfile(next ? await fetchProfile(next.user.id) : null)
    })

    return () => {
      active = false
      sub.subscription.unsubscribe()
    }
  }, [])

  async function signIn(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error

    const prof = await fetchProfile(data.user.id)
    if (!prof || prof.role !== 'admin') {
      await supabase.auth.signOut()
      throw new Error('هذا الحساب غير مخوّل للوصول إلى لوحة التحكم.')
    }
    setProfile(prof)
  }

  async function signOut() {
    await supabase.auth.signOut()
    setProfile(null)
  }

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      profile,
      isAdmin: profile?.role === 'admin',
      loading,
      signIn,
      signOut,
    }),
    [session, profile, loading],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within <AuthProvider>')
  return ctx
}
