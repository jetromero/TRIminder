import { supabase } from '../supabaseClient'
import type { Department } from '@/types/database'

export async function getDepartments() {
  const { data, error } = await supabase
    .from('departments')
    .select('*')
    .order('name', { ascending: true })

  if (error) throw error
  return data as Department[]
}

export async function getDepartmentById(id: number) {
  const { data, error } = await supabase
    .from('departments')
    .select('*')
    .eq('id', id)
    .single()

  if (error) throw error
  return data as Department
}

export async function createDepartment(department: Omit<Department, 'id'>) {
  const { data, error } = await supabase
    .from('departments')
    .insert(department)
    .select()
    .single()

  if (error) throw error
  return data as Department
}

export async function updateDepartment(id: number, updates: Partial<Department>) {
  const { data, error } = await supabase
    .from('departments')
    .update(updates)
    .eq('id', id)
    .select()
    .single()

  if (error) throw error
  return data as Department
}

export async function deleteDepartment(id: number) {
  const { error } = await supabase
    .from('departments')
    .delete()
    .eq('id', id)

  if (error) throw error
}

