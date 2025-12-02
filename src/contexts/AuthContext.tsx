import { createContext, useContext, useEffect, useState, ReactNode } from 'react'
import { supabase } from '@/lib/supabaseClient'
import bcrypt from 'bcryptjs'
import type { AuthUser } from '@/types/auth'
import type { Admin } from '@/types/database'

interface AuthContextType {
  user: AuthUser | null
  loading: boolean
  loggingOut: boolean
  signIn: (username: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

const STORAGE_KEY = 'triminder_admin_session'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [loading, setLoading] = useState(true)
  const [loggingOut, setLoggingOut] = useState(false)

  // Load session from localStorage on mount
  useEffect(() => {
    const storedSession = localStorage.getItem(STORAGE_KEY)
    if (storedSession) {
      try {
        const sessionData = JSON.parse(storedSession)
        setUser(sessionData)
      } catch (error) {
        localStorage.removeItem(STORAGE_KEY)
      }
    }
    setLoading(false)
  }, [])

  const signIn = async (username: string, password: string) => {
    // Find admin by username
    const { data: admin, error: fetchError } = await supabase
      .from('admins')
      .select('*')
      .eq('username', username)
      .eq('is_active', true)
      .single()

    if (fetchError || !admin) {
      throw new Error('Invalid username or password')
    }

    // Verify password using bcrypt
    const passwordMatch = await bcrypt.compare(password, admin.password)
    if (!passwordMatch) {
      throw new Error('Invalid username or password')
    }

    // Update last login
    await supabase
      .from('admins')
      .update({ last_login_at: new Date().toISOString() })
      .eq('id', admin.id)

    // Determine role based on department_id
    // NULL department_id = super_admin, otherwise sub_admin
    const role: 'super_admin' | 'sub_admin' = admin.department_id === null ? 'super_admin' : 'sub_admin'

    const authUser: AuthUser = {
      id: admin.id.toString(),
      email: admin.username, // Using username as email for compatibility
      role,
      department_id: admin.department_id,
      profile: null,
      admin: {
        id: admin.id,
        name: admin.name,
        username: admin.username,
        password: '', // Don't store password
        department_id: admin.department_id,
        is_active: admin.is_active,
        last_login_at: admin.last_login_at,
        remember_token: null,
        created_at: admin.created_at,
        updated_at: admin.updated_at,
      },
    }

    // Store session
    localStorage.setItem(STORAGE_KEY, JSON.stringify(authUser))
    setUser(authUser)
  }

  const signOut = async () => {
    setLoggingOut(true)
    // Delay to show the logout loader
    await new Promise(resolve => setTimeout(resolve, 1500))
    localStorage.removeItem(STORAGE_KEY)
    setUser(null)
    setLoggingOut(false)
  }

  return (
    <AuthContext.Provider value={{ user, loading, loggingOut, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}

