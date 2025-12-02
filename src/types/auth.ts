import { Profile, Admin } from './database'

export interface AuthUser {
  id: string
  email: string
  role: 'student' | 'sub_admin' | 'super_admin'
  department_id: number | null
  profile: Profile | null
  admin?: Admin | null
}

export type UserRole = 'student' | 'sub_admin' | 'super_admin'

