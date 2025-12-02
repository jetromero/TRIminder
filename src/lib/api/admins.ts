import { supabase } from '../supabaseClient'
import bcrypt from 'bcryptjs'
import type { Admin } from '@/types/database'

const SALT_ROUNDS = 10

export async function getAdmins(departmentId?: number) {
  let query = supabase.from('admins').select('*').order('created_at', { ascending: false })

  if (departmentId) {
    query = query.eq('department_id', departmentId)
  }

  const { data, error } = await query

  if (error) throw error
  return data as Admin[]
}

export async function getAdminById(id: number) {
  const { data, error } = await supabase
    .from('admins')
    .select('*')
    .eq('id', id)
    .single()

  if (error) throw error
  return data as Admin
}

export async function createAdmin(admin: Omit<Admin, 'id' | 'created_at' | 'updated_at' | 'last_login_at' | 'remember_token'>) {
  // Hash the password before storing
  const hashedPassword = await bcrypt.hash(admin.password, SALT_ROUNDS)

  const { data, error } = await supabase
    .from('admins')
    .insert({ ...admin, password: hashedPassword })
    .select()
    .single()

  if (error) throw error
  return data as Admin
}

export async function updateAdmin(id: number, updates: Partial<Admin>) {
  // Hash password if it's being updated
  let updateData = { ...updates, updated_at: new Date().toISOString() }

  if (updates.password && updates.password.length > 0) {
    updateData.password = await bcrypt.hash(updates.password, SALT_ROUNDS)
  } else {
    // Remove password from updates if empty (don't update it)
    delete updateData.password
  }

  const { data, error } = await supabase
    .from('admins')
    .update(updateData)
    .eq('id', id)
    .select()
    .single()

  if (error) throw error
  return data as Admin
}

export async function deleteAdmin(id: number) {
  const { error } = await supabase
    .from('admins')
    .delete()
    .eq('id', id)

  if (error) throw error
}

export async function changeAdminPassword(id: number, currentPassword: string, newPassword: string) {
  // First verify current password
  const { data: admin, error: fetchError } = await supabase
    .from('admins')
    .select('password')
    .eq('id', id)
    .single()

  if (fetchError || !admin) {
    throw new Error('Admin not found')
  }

  // Verify current password matches using bcrypt
  const passwordMatch = await bcrypt.compare(currentPassword, admin.password)
  if (!passwordMatch) {
    throw new Error('Current password is incorrect')
  }

  // Hash the new password
  const hashedNewPassword = await bcrypt.hash(newPassword, SALT_ROUNDS)

  // Update to new password
  const { error: updateError } = await supabase
    .from('admins')
    .update({ password: hashedNewPassword, updated_at: new Date().toISOString() })
    .eq('id', id)

  if (updateError) throw updateError
}

// Check if current user is the default admin
export function isDefaultAdmin(username: string): boolean {
  return username === 'admin'
}

