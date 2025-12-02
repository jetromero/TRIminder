import { supabase } from '../supabaseClient'
import type { Profile, StudentWithStats, UserUsageDaily, ScreenTimeLog } from '@/types/database'
import { format, subDays } from 'date-fns'

export async function getStudents(departmentId?: number) {
  let query = supabase
    .from('profiles')
    .select('*')
    .eq('role', 'student')
    .order('created_at', { ascending: false })

  if (departmentId) {
    query = query.eq('department_id', departmentId)
  }

  const { data, error } = await query

  if (error) throw error
  return data as Profile[]
}

export async function getStudentById(id: string) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', id)
    .eq('role', 'student')
    .single()

  if (error) throw error
  return data as Profile
}

export async function getStudentsWithStats(departmentId?: number): Promise<StudentWithStats[]> {
  const students = await getStudents(departmentId)

  const studentsWithStats = await Promise.all(
    students.map(async (student) => {
      // Get total screen time from user_usage_daily
      const { data: usageData } = await supabase
        .from('user_usage_daily')
        .select('total_minutes')
        .eq('user_id', student.id)

      const total_screen_time = usageData?.reduce((sum, u) => sum + u.total_minutes, 0) || 0
      const days_with_usage = usageData?.length || 0
      const avg_daily_screen_time = days_with_usage > 0 ? Math.round(total_screen_time / days_with_usage) : 0

      // Get badge count
      const { count: badgeCount } = await supabase
        .from('user_badges')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', student.id)

      // Get last active date
      const { data: lastUsage } = await supabase
        .from('user_usage_daily')
        .select('usage_date')
        .eq('user_id', student.id)
        .order('usage_date', { ascending: false })
        .limit(1)
        .single()

      return {
        ...student,
        total_screen_time,
        avg_daily_screen_time,
        badge_count: badgeCount || 0,
        last_active: lastUsage?.usage_date || null,
      }
    })
  )

  return studentsWithStats
}

export async function getStudentUsageHistory(userId: string, days: number = 7) {
  const startDate = format(subDays(new Date(), days), 'yyyy-MM-dd')

  const { data, error } = await supabase
    .from('user_usage_daily')
    .select('*')
    .eq('user_id', userId)
    .gte('usage_date', startDate)
    .order('usage_date', { ascending: true })

  if (error) throw error
  return data as UserUsageDaily[]
}

export async function getStudentScreenTimeLogs(userId: string, limit: number = 50) {
  const { data, error } = await supabase
    .from('screen_time_logs')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit)

  if (error) throw error
  return data as ScreenTimeLog[]
}

export async function getStudentBadges(userId: string) {
  const { data, error } = await supabase
    .from('user_badges')
    .select(`
      *,
      badges (*)
    `)
    .eq('user_id', userId)
    .order('awarded_at', { ascending: false })

  if (error) throw error
  return data
}

export async function getStudentXpHistory(userId: string, days: number = 30) {
  const startDate = format(subDays(new Date(), days), 'yyyy-MM-dd')

  const { data, error } = await supabase
    .from('xp_award_history')
    .select('*')
    .eq('user_id', userId)
    .gte('award_date', startDate)
    .order('award_date', { ascending: false })

  if (error) throw error
  return data
}

