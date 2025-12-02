import { supabase } from '../supabaseClient'
import type { AnalyticsData } from '@/types/database'
import { format, subDays, subMonths, startOfWeek, startOfMonth, eachDayOfInterval, eachWeekOfInterval, eachMonthOfInterval } from 'date-fns'

export async function getAnalytics(departmentId?: number): Promise<AnalyticsData> {
  // Get students query
  let studentsQuery = supabase
    .from('profiles')
    .select('id, xp, department_id')
    .eq('role', 'student')

  if (departmentId) {
    studentsQuery = studentsQuery.eq('department_id', departmentId)
  }

  const { data: students, error: studentsError } = await studentsQuery

  if (studentsError) throw studentsError

  const studentIds = students?.map((s) => s.id) || []

  // Get total students
  const total_students = students?.length || 0

  // Get average daily screen time (last 7 days)
  const weekAgo = format(subDays(new Date(), 7), 'yyyy-MM-dd')
  const { data: usageData } = await supabase
    .from('user_usage_daily')
    .select('total_minutes, user_id')
    .in('user_id', studentIds)
    .gte('usage_date', weekAgo)

  const totalMinutes = usageData?.reduce((sum, u) => sum + u.total_minutes, 0) || 0
  const uniqueUsers = new Set(usageData?.map((u) => u.user_id)).size
  const average_daily_screen_time = uniqueUsers > 0 ? Math.round(totalMinutes / uniqueUsers / 7) : 0

  // Get total XP
  const total_xp = students?.reduce((sum, s) => sum + s.xp, 0) || 0

  // Get total badges
  const { count: total_badges } = await supabase
    .from('user_badges')
    .select('*', { count: 'exact', head: true })
    .in('user_id', studentIds)

  // Get weekly usage chart data
  const weekStart = startOfWeek(new Date(), { weekStartsOn: 1 })
  const weekDays = eachDayOfInterval({
    start: weekStart,
    end: new Date(),
  })

  const weekly_usage = await Promise.all(
    weekDays.map(async (day) => {
      const dateStr = format(day, 'yyyy-MM-dd')
      const { data } = await supabase
        .from('user_usage_daily')
        .select('total_minutes')
        .in('user_id', studentIds)
        .eq('usage_date', dateStr)

      const minutes = data?.reduce((sum, u) => sum + u.total_minutes, 0) || 0
      return {
        date: format(day, 'MMM dd'),
        minutes: Math.round(minutes / (studentIds.length || 1)),
      }
    })
  )

  // Get top 10 students by screen time
  const { data: topUsage } = await supabase
    .from('user_usage_daily')
    .select('user_id, total_minutes')
    .in('user_id', studentIds)
    .gte('usage_date', weekAgo)

  const studentMinutesMap = new Map<string, number>()
  topUsage?.forEach((entry) => {
    const current = studentMinutesMap.get(entry.user_id) || 0
    studentMinutesMap.set(entry.user_id, current + entry.total_minutes)
  })

  // Get full student profiles for names and avatars
  const { data: studentProfiles } = await supabase
    .from('profiles')
    .select('id, first_name, last_name, avatar_url')
    .in('id', Array.from(studentMinutesMap.keys()))

  const top_students = Array.from(studentMinutesMap.entries())
    .map(([id, minutes]) => {
      const profile = studentProfiles?.find((s) => s.id === id)
      return {
        id,
        name: profile
          ? `${profile.first_name} ${profile.last_name}`
          : 'Unknown',
        minutes,
        avatar_url: profile?.avatar_url || null,
      }
    })
    .sort((a, b) => b.minutes - a.minutes)
    .slice(0, 10)

  // Get XP distribution
  const xpRanges = [
    { min: 0, max: 100, label: '0-100' },
    { min: 101, max: 500, label: '101-500' },
    { min: 501, max: 1000, label: '501-1000' },
    { min: 1001, max: 5000, label: '1001-5000' },
    { min: 5001, max: Infinity, label: '5000+' },
  ]

  const xp_distribution = xpRanges.map((range) => ({
    range: range.label,
    count: students?.filter((s) => {
      if (range.max === Infinity) {
        return s.xp >= range.min
      }
      return s.xp >= range.min && s.xp <= range.max
    }).length || 0,
  }))

  // Get year level and gender distribution
  let year_level_distribution: Array<{ year_level: string; count: number }> = []
  let gender_distribution: Array<{ gender: string; count: number }> = []

  if (studentIds.length > 0) {
    const { data: studentProfilesFull } = await supabase
      .from('profiles')
      .select('year_level, gender')
      .eq('role', 'student')
      .in('id', studentIds)

    const yearLevelMap = new Map<string, number>()
    const genderMap = new Map<string, number>()

    studentProfilesFull?.forEach((profile) => {
      const yearLevel = profile.year_level || 'Not Specified'
      const gender = profile.gender || 'Not Specified'
      yearLevelMap.set(yearLevel, (yearLevelMap.get(yearLevel) || 0) + 1)
      genderMap.set(gender, (genderMap.get(gender) || 0) + 1)
    })

    year_level_distribution = Array.from(yearLevelMap.entries())
      .map(([year_level, count]) => ({ year_level, count }))
      .sort((a, b) => {
        // Sort by year level if numeric, otherwise alphabetically
        const aNum = parseInt(a.year_level)
        const bNum = parseInt(b.year_level)
        if (!isNaN(aNum) && !isNaN(bNum)) {
          return aNum - bNum
        }
        return a.year_level.localeCompare(b.year_level)
      })

    gender_distribution = Array.from(genderMap.entries())
      .map(([gender, count]) => ({ gender, count }))
      .sort((a, b) => b.count - a.count)
  }

  // Calculate average screen time per year level and gender
  let year_level_screen_time: Array<{ year_level: string; avg_minutes: number }> = []
  let gender_screen_time: Array<{ gender: string; avg_minutes: number }> = []

  if (studentIds.length > 0) {
    const { data: studentsWithDetails } = await supabase
      .from('profiles')
      .select('id, year_level, gender')
      .eq('role', 'student')
      .in('id', studentIds)

    const weekAgoDate = format(subDays(new Date(), 7), 'yyyy-MM-dd')
    const { data: usageData } = await supabase
      .from('user_usage_daily')
      .select('user_id, total_minutes')
      .in('user_id', studentIds)
      .gte('usage_date', weekAgoDate)

    // Group students by year level and calculate average
    const yearLevelMinutes = new Map<string, { total: number; count: number }>()
    const genderMinutes = new Map<string, { total: number; count: number }>()

    studentsWithDetails?.forEach((student) => {
      const yearLevel = student.year_level || 'Not Specified'
      const gender = student.gender || 'Not Specified'
      const studentUsage = usageData?.filter(u => u.user_id === student.id) || []
      const totalMinutes = studentUsage.reduce((sum, u) => sum + u.total_minutes, 0)

      // Year level aggregation
      const currentYL = yearLevelMinutes.get(yearLevel) || { total: 0, count: 0 }
      yearLevelMinutes.set(yearLevel, {
        total: currentYL.total + totalMinutes,
        count: currentYL.count + 1,
      })

      // Gender aggregation
      const currentG = genderMinutes.get(gender) || { total: 0, count: 0 }
      genderMinutes.set(gender, {
        total: currentG.total + totalMinutes,
        count: currentG.count + 1,
      })
    })

    year_level_screen_time = Array.from(yearLevelMinutes.entries())
      .map(([year_level, data]) => ({
        year_level,
        avg_minutes: Math.round(data.total / data.count),
      }))
      .sort((a, b) => b.avg_minutes - a.avg_minutes)

    gender_screen_time = Array.from(genderMinutes.entries())
      .map(([gender, data]) => ({
        gender,
        avg_minutes: Math.round(data.total / data.count),
      }))
      .sort((a, b) => b.avg_minutes - a.avg_minutes)
  }

  return {
    total_students,
    average_daily_screen_time,
    total_xp,
    total_badges: total_badges || 0,
    weekly_usage,
    top_students,
    xp_distribution,
    year_level_distribution,
    gender_distribution,
    year_level_screen_time,
    gender_screen_time,
  }
}

export async function getUsageTrend(
  range: 'daily' | 'weekly' | 'monthly',
  departmentId?: number
): Promise<Array<{ date: string; minutes: number }>> {
  // Get students
  let studentsQuery = supabase
    .from('profiles')
    .select('id')
    .eq('role', 'student')

  if (departmentId) {
    studentsQuery = studentsQuery.eq('department_id', departmentId)
  }

  const { data: students } = await studentsQuery
  const studentIds = students?.map((s) => s.id) || []

  if (studentIds.length === 0) return []

  const today = new Date()

  if (range === 'daily') {
    // Last 7 days, one data point per day
    const days = eachDayOfInterval({
      start: subDays(today, 6),
      end: today,
    })

    return Promise.all(
      days.map(async (day) => {
        const dateStr = format(day, 'yyyy-MM-dd')
        const { data } = await supabase
          .from('user_usage_daily')
          .select('total_minutes')
          .in('user_id', studentIds)
          .eq('usage_date', dateStr)

        const minutes = data?.reduce((sum, u) => sum + u.total_minutes, 0) || 0
        return {
          date: format(day, 'MMM dd'),
          minutes: Math.round(minutes / studentIds.length),
        }
      })
    )
  }

  if (range === 'weekly') {
    // Last 4 weeks, one data point per week
    const weeks = eachWeekOfInterval(
      {
        start: subDays(today, 28),
        end: today,
      },
      { weekStartsOn: 1 }
    )

    return Promise.all(
      weeks.map(async (weekStart) => {
        const weekEnd = subDays(new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000), 1)
        const startStr = format(weekStart, 'yyyy-MM-dd')
        const endStr = format(weekEnd > today ? today : weekEnd, 'yyyy-MM-dd')

        const { data } = await supabase
          .from('user_usage_daily')
          .select('total_minutes')
          .in('user_id', studentIds)
          .gte('usage_date', startStr)
          .lte('usage_date', endStr)

        const minutes = data?.reduce((sum, u) => sum + u.total_minutes, 0) || 0
        return {
          date: format(weekStart, 'MMM dd'),
          minutes: Math.round(minutes / studentIds.length),
        }
      })
    )
  }

  // Monthly - Last 6 months
  const months = eachMonthOfInterval({
    start: subMonths(today, 5),
    end: today,
  })

  return Promise.all(
    months.map(async (monthStart) => {
      const monthEnd = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0)
      const startStr = format(monthStart, 'yyyy-MM-dd')
      const endStr = format(monthEnd > today ? today : monthEnd, 'yyyy-MM-dd')

      const { data } = await supabase
        .from('user_usage_daily')
        .select('total_minutes')
        .in('user_id', studentIds)
        .gte('usage_date', startStr)
        .lte('usage_date', endStr)

      const minutes = data?.reduce((sum, u) => sum + u.total_minutes, 0) || 0
      return {
        date: format(monthStart, 'MMM yyyy'),
        minutes: Math.round(minutes / studentIds.length),
      }
    })
  )
}

export async function getDepartmentComparison() {
  const { data: departments } = await supabase.from('departments').select('id, name')

  if (!departments) return []

  const comparisons = await Promise.all(
    departments.map(async (dept) => {
      const analytics = await getAnalytics(dept.id)
      return {
        department_id: dept.id,
        department_name: dept.name,
        total_students: analytics.total_students,
        average_screen_time: analytics.average_daily_screen_time,
        total_xp: analytics.total_xp,
      }
    })
  )

  return comparisons
}

export async function getHourlyScreentime(
  departmentId?: number
): Promise<Array<{ hour: string; minutes: number }>> {
  // Get students based on department
  let studentsQuery = supabase.from('profiles').select('id').eq('role', 'student')
  if (departmentId) {
    studentsQuery = studentsQuery.eq('department_id', departmentId)
  }
  const { data: students } = await studentsQuery

  if (!students || students.length === 0) {
    return Array.from({ length: 24 }, (_, i) => ({
      hour: `${i.toString().padStart(2, '0')}:00`,
      minutes: 0,
    }))
  }

  const studentIds = students.map((s) => s.id)

  // Get today's date range
  const today = new Date()
  const startOfDay = new Date(today)
  startOfDay.setHours(0, 0, 0, 0)
  const endOfDay = new Date(today)
  endOfDay.setHours(23, 59, 59, 999)

  // Get screen time logs for today
  const { data: logs } = await supabase
    .from('screen_time_logs')
    .select('start_time, end_time, duration_minutes')
    .in('user_id', studentIds)
    .gte('start_time', startOfDay.toISOString())
    .lte('start_time', endOfDay.toISOString())

  // Initialize hourly data
  const hourlyData = Array.from({ length: 24 }, (_, i) => ({
    hour: `${i.toString().padStart(2, '0')}:00`,
    minutes: 0,
  }))

  // Aggregate minutes by hour
  logs?.forEach((log) => {
    const startTime = new Date(log.start_time)
    const hour = startTime.getHours()
    const minutes = log.duration_minutes || 0
    hourlyData[hour].minutes += minutes
  })

  return hourlyData
}

export async function getTopStudents(
  range: 'daily' | 'weekly' | 'monthly',
  departmentId?: number
): Promise<Array<{ id: string; name: string; minutes: number; avatar_url: string | null }>> {
  const now = new Date()
  let startDate: Date

  switch (range) {
    case 'daily':
      // Today only
      startDate = new Date(now)
      startDate.setHours(0, 0, 0, 0)
      break
    case 'weekly':
      // Last 7 days
      startDate = new Date(now)
      startDate.setDate(startDate.getDate() - 7)
      break
    case 'monthly':
      // Last 30 days
      startDate = new Date(now)
      startDate.setDate(startDate.getDate() - 30)
      break
  }

  // Get students based on department
  let studentsQuery = supabase.from('profiles').select('id')
  if (departmentId) {
    studentsQuery = studentsQuery.eq('department_id', departmentId)
  }
  const { data: students } = await studentsQuery

  if (!students || students.length === 0) {
    return []
  }

  const studentIds = students.map((s) => s.id)

  // Get usage data for the time range
  const { data: usageData } = await supabase
    .from('user_usage_daily')
    .select('user_id, total_minutes')
    .in('user_id', studentIds)
    .gte('usage_date', format(startDate, 'yyyy-MM-dd'))

  if (!usageData || usageData.length === 0) {
    return []
  }

  // Aggregate minutes per student
  const studentMinutesMap = new Map<string, number>()
  usageData.forEach((entry) => {
    const current = studentMinutesMap.get(entry.user_id) || 0
    studentMinutesMap.set(entry.user_id, current + entry.total_minutes)
  })

  // Get student profiles with names and avatars
  const { data: studentProfiles } = await supabase
    .from('profiles')
    .select('id, first_name, last_name, avatar_url')
    .in('id', Array.from(studentMinutesMap.keys()))

  // Build top students list
  const topStudents = Array.from(studentMinutesMap.entries())
    .map(([id, minutes]) => {
      const profile = studentProfiles?.find((s) => s.id === id)
      return {
        id,
        name: profile ? `${profile.first_name} ${profile.last_name}` : 'Unknown',
        minutes,
        avatar_url: profile?.avatar_url || null,
      }
    })
    .sort((a, b) => b.minutes - a.minutes)
    .slice(0, 10)

  return topStudents
}

