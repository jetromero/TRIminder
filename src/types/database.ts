export interface Profile {
  id: string
  email: string
  role: 'student' | 'sub_admin' | 'super_admin'
  department_id: number | null
  xp: number
  created_at: string
  user_tag: string
  updated_at: string
  avatar_url: string | null
  cover_photo_url: string | null
  bio: string | null
  first_name: string
  last_name: string
  student_id: string | null
  gender: string | null
  year_level: string | null
  date_of_birth: string | null
}

export interface Admin {
  id: number
  name: string
  username: string
  password: string
  department_id: number | null
  is_active: boolean
  last_login_at: string | null
  remember_token: string | null
  created_at: string
  updated_at: string
}

export interface Department {
  id: number
  name: string
}

export interface Badge {
  id: number
  name: string
  description: string | null
  icon_url: string | null
  xp_reward: number
}

export interface UserBadge {
  user_id: string
  badge_id: number
  awarded_at: string
}

export interface ScreenTimeLog {
  id: number
  user_id: string | null
  start_time: string
  end_time: string | null
  duration_minutes: number | null
  break_taken: boolean
  created_at: string
}

export interface UserUsageDaily {
  user_id: string
  usage_date: string
  total_minutes: number
  created_at: string
  updated_at: string
}

export interface XpAwardHistory {
  id: number
  user_id: string
  award_date: string
  xp_awarded: number
  screen_time_minutes: number
  created_at: string
}

export interface StudentWithStats extends Profile {
  total_screen_time: number
  avg_daily_screen_time: number
  badge_count: number
  last_active: string | null
}

export interface AnalyticsData {
  total_students: number
  average_daily_screen_time: number
  total_xp: number
  total_badges: number
  weekly_usage: Array<{ date: string; minutes: number }>
  top_students: Array<{ id: string; name: string; minutes: number; avatar_url: string | null }>
  xp_distribution: Array<{ range: string; count: number }>
  year_level_distribution: Array<{ year_level: string; count: number }>
  gender_distribution: Array<{ gender: string; count: number }>
  year_level_screen_time: Array<{ year_level: string; avg_minutes: number }>
  gender_screen_time: Array<{ gender: string; avg_minutes: number }>
}

