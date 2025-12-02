import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '@/hooks/useAuth'
import { getAnalytics, getDepartmentComparison, getUsageTrend, getTopStudents, getHourlyScreentime } from '@/lib/api/analytics'
import { getDepartments } from '@/lib/api/departments'
import { CardStat } from '@/components/ui/CardStat'
import { ChartLine } from '@/components/ui/ChartLine'
import { ChartBar } from '@/components/ui/ChartBar'
import { FilterDropdown } from '@/components/ui/FilterDropdown'
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts'
import type { AnalyticsData, Department } from '@/types/database'
import { formatMinutes } from '@/lib/utils/formatTime'

export function Dashboard() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null)
  const [departments, setDepartments] = useState<Department[]>([])
  const [departmentComparison, setDepartmentComparison] = useState<any[]>([])
  const [selectedDepartment, setSelectedDepartment] = useState<number | undefined>(
    user?.department_id || undefined
  )
  const [loading, setLoading] = useState(true)
  const [usageTrendRange, setUsageTrendRange] = useState<'daily' | 'weekly' | 'monthly'>('daily')
  const [usageTrendData, setUsageTrendData] = useState<Array<{ date: string; minutes: number }>>([])
  const [topStudentsRange, setTopStudentsRange] = useState<'daily' | 'weekly' | 'monthly'>('daily')
  const [topStudentsData, setTopStudentsData] = useState<Array<{ id: string; name: string; minutes: number; avatar_url: string | null }> | null>(null)
  const [topStudentsSortOrder, setTopStudentsSortOrder] = useState<'desc' | 'asc'>('desc')
  const [hourlyScreentime, setHourlyScreentime] = useState<Array<{ hour: string; minutes: number }>>([])

  useEffect(() => {
    fetchAnalytics()
    if (user?.role === 'super_admin') {
      fetchDepartments()
      fetchDepartmentComparison()
    }
  }, [selectedDepartment, user])

  useEffect(() => {
    fetchUsageTrend()
  }, [usageTrendRange, selectedDepartment])

  useEffect(() => {
    fetchTopStudents()
  }, [topStudentsRange, selectedDepartment])

  useEffect(() => {
    fetchHourlyScreentime()
  }, [selectedDepartment])

  const fetchHourlyScreentime = async () => {
    try {
      const data = await getHourlyScreentime(selectedDepartment)
      setHourlyScreentime(data)
    } catch (error) {
      console.error('Failed to fetch hourly screentime:', error)
    }
  }

  const fetchUsageTrend = async () => {
    try {
      const data = await getUsageTrend(usageTrendRange, selectedDepartment)
      setUsageTrendData(data)
    } catch (error) {
      console.error('Failed to fetch usage trend:', error)
    }
  }

  const fetchTopStudents = async () => {
    try {
      const data = await getTopStudents(topStudentsRange, selectedDepartment)
      setTopStudentsData(data)
    } catch (error) {
      console.error('Failed to fetch top students:', error)
    }
  }

  const fetchAnalytics = async () => {
    try {
      setLoading(true)
      const data = await getAnalytics(selectedDepartment)
      setAnalytics(data)
    } catch (error) {
      console.error('Failed to fetch analytics:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchDepartments = async () => {
    try {
      const data = await getDepartments()
      setDepartments(data)
    } catch (error) {
      console.error('Failed to fetch departments:', error)
    }
  }

  const fetchDepartmentComparison = async () => {
    try {
      const data = await getDepartmentComparison()
      setDepartmentComparison(data)
    } catch (error) {
      console.error('Failed to fetch department comparison:', error)
    }
  }

  if (loading) {
    return (
      <div className="page-wrapper">
        <div className="loading-wrapper">
          <div className="loading-content">
            <div className="loading-spinner"></div>
            <p className="loading-message">Loading dashboard...</p>
          </div>
        </div>
      </div>
    )
  }

  if (!analytics) {
    return (
      <div className="page-wrapper">
        <div className="empty-state-wrapper">
          <svg className="empty-state-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <h3 className="empty-state-heading">Failed to load analytics</h3>
          <p className="empty-state-subtext">Please try refreshing the page</p>
        </div>
      </div>
    )
  }

  return (
    <div className="page-wrapper">
      {/* Header */}
      <div className="page-header-section">
        <div className="page-info">
          <h1 className="page-heading">Dashboard</h1>
          <p className="page-subheading">Overview and analytics of your department's performance</p>
        </div>
        {user?.role === 'super_admin' && (
          <FilterDropdown
            value={selectedDepartment?.toString() || ''}
            onChange={(value) => setSelectedDepartment(value ? parseInt(value) : undefined)}
            placeholder="All Departments"
            className="department-selector"
            options={[
              { value: '', label: 'All Departments' },
              ...departments.map((dept) => ({
                value: dept.id.toString(),
                label: dept.name,
              })),
            ]}
          />
        )}
      </div>

      {/* Stats Grid */}
      <div className="dashboard-stats-grid">
        <CardStat
          title="Total Students"
          value={analytics.total_students}
          icon={
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="40" height="40">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
          }
        />
        <CardStat
          title="Avg Daily Screen Time"
          value={formatMinutes(analytics.average_daily_screen_time)}
          icon={
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="40" height="40">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          }
        />
        {user?.role === 'super_admin' && departmentComparison.length > 0 ? (
          <CardStat
            title="Top Dept (Screen Time)"
            value={
              departmentComparison.reduce((max, dept) =>
                dept.average_screen_time > max.average_screen_time ? dept : max
              ).department_name
            }
            icon={
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="40" height="40">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            }
          />
        ) : (
          <CardStat
            title="Top Gender (Screen Time)"
            value={
              analytics.gender_screen_time
                .filter(item => item.gender !== 'Not Specified')
              [0]?.gender || analytics.gender_screen_time[0]?.gender || 'N/A'
            }
            icon={
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="40" height="40">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
            }
          />
        )}
        <CardStat
          title="Top Year Level (Screen Time)"
          value={
            analytics.year_level_screen_time
              .filter(item => item.year_level !== 'Not Specified')
            [0]?.year_level || analytics.year_level_screen_time[0]?.year_level || 'N/A'
          }
          icon={
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="40" height="40">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </svg>
          }
        />
      </div>

      {/* Charts Section - Row 1: Usage Trend + Top 10 Students */}
      <div className="charts-section">
        <div className="dashboard-card usage-trend-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">Usage Trend</h2>
            <div className="time-range-selector">
              <button
                className={`time-range-btn ${usageTrendRange === 'daily' ? 'active' : ''}`}
                onClick={() => setUsageTrendRange('daily')}
              >
                Daily
              </button>
              <button
                className={`time-range-btn ${usageTrendRange === 'weekly' ? 'active' : ''}`}
                onClick={() => setUsageTrendRange('weekly')}
              >
                Weekly
              </button>
              <button
                className={`time-range-btn ${usageTrendRange === 'monthly' ? 'active' : ''}`}
                onClick={() => setUsageTrendRange('monthly')}
              >
                Monthly
              </button>
            </div>
          </div>
          <ChartLine data={usageTrendData.length > 0 ? usageTrendData : analytics.weekly_usage} dataKey="minutes" strokeColor="#7f1d1d" />
        </div>

        <div className="dashboard-card top-students-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">Top 10 Students</h2>
            <div className="top-students-controls">
              <button
                className="sort-toggle-btn"
                onClick={() => setTopStudentsSortOrder(topStudentsSortOrder === 'desc' ? 'asc' : 'desc')}
                title={topStudentsSortOrder === 'desc' ? 'Highest first' : 'Lowest first'}
              >
                {topStudentsSortOrder === 'desc' ? (
                  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="16" height="16">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12" />
                  </svg>
                ) : (
                  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="16" height="16">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 4h13M3 8h9m-9 4h9m5-4v12m0 0l-4-4m4 4l4-4" />
                  </svg>
                )}
              </button>
              <div className="time-range-selector">
                <button
                  className={`time-range-btn ${topStudentsRange === 'daily' ? 'active' : ''}`}
                  onClick={() => setTopStudentsRange('daily')}
                >
                  Daily
                </button>
                <button
                  className={`time-range-btn ${topStudentsRange === 'weekly' ? 'active' : ''}`}
                  onClick={() => setTopStudentsRange('weekly')}
                >
                  Weekly
                </button>
                <button
                  className={`time-range-btn ${topStudentsRange === 'monthly' ? 'active' : ''}`}
                  onClick={() => setTopStudentsRange('monthly')}
                >
                  Monthly
                </button>
              </div>
            </div>
          </div>
          <div className="top-performers-list scrollable">
            {[...(topStudentsData && topStudentsData.length > 0 ? topStudentsData : analytics.top_students)]
              .sort((a, b) => topStudentsSortOrder === 'desc' ? b.minutes - a.minutes : a.minutes - b.minutes)
              .slice(0, 10)
              .map((student, index) => (
                <div
                  key={student.id}
                  className="performer-item clickable"
                  onClick={() => navigate(`/students/${student.id}`)}
                >
                  <div className="performer-info">
                    <div
                      className={`rank-badge ${index === 0
                        ? 'rank-gold'
                        : index === 1
                          ? 'rank-silver'
                          : index === 2
                            ? 'rank-bronze'
                            : 'rank-default'
                        }`}
                    >
                      {index + 1}
                    </div>
                    {student.avatar_url ? (
                      <img
                        src={student.avatar_url}
                        alt={student.name}
                        className="performer-avatar"
                      />
                    ) : (
                      <div className="performer-avatar-placeholder">
                        {student.name.charAt(0).toUpperCase()}
                      </div>
                    )}
                    <span className="performer-name">{student.name}</span>
                  </div>
                  <span className="performer-value">{formatMinutes(student.minutes)}</span>
                </div>
              ))}
          </div>
        </div>

        {user?.role === 'super_admin' && departmentComparison.length > 0 ? (
          <div className="dashboard-card dept-screentime-card">
            <div className="card-header-with-badge">
              <h2 className="card-main-title">Avg Screen Time by Dept</h2>
              <span className="time-badge">Comparison</span>
            </div>
            <ChartBar
              data={departmentComparison.map((dept) => ({
                range: dept.department_name,
                minutes: dept.average_screen_time,
              }))}
              dataKey="minutes"
              xAxisKey="range"
              fillColor="#991b1b"
            />
          </div>
        ) : (
          <div className="dashboard-card dept-screentime-card">
            <div className="card-header-with-badge">
              <h2 className="card-main-title">Today's Hourly Screen Time</h2>
              <span className="time-badge">24 Hours</span>
            </div>
            <ChartBar
              data={hourlyScreentime.map(item => ({
                range: item.hour,
                minutes: item.minutes,
              }))}
              dataKey="minutes"
              xAxisKey="range"
              fillColor="#991b1b"
            />
          </div>
        )}

        <div className="dashboard-card year-level-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">Year Level Distribution</h2>
            <span className="time-badge">Current</span>
          </div>
          <div className="stacked-bar-list">
            {(() => {
              const allYearLevels = ['1st Year', '2nd Year', '3rd Year', '4th Year', 'Not Specified']
              const opacities = [0.08, 0.12, 0.18, 0.25, 0.35]

              return allYearLevels.map((yearLevel, index) => {
                const data = analytics.year_level_distribution.find(
                  item => (item.year_level || 'Not Specified') === yearLevel
                )
                const count = data?.count || 0

                return (
                  <div
                    key={yearLevel}
                    className="stacked-bar-item"
                    style={{
                      backgroundColor: `rgba(127, 29, 29, ${opacities[index]})`,
                    }}
                  >
                    <div className="stacked-bar-indicator" style={{ backgroundColor: '#7f1d1d' }} />
                    <span className="stacked-bar-label" style={{ color: '#7f1d1d' }}>
                      {yearLevel}
                    </span>
                    <span className="stacked-bar-value" style={{ color: '#7f1d1d' }}>
                      {count}
                    </span>
                  </div>
                )
              })
            })()}
          </div>
        </div>

        <div className="dashboard-card gender-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">Gender Distribution</h2>
            <span className="time-badge">Current</span>
          </div>
          {(() => {
            const genderData = analytics.gender_distribution.map((item) => ({
              name: item.gender || 'Not Specified',
              value: item.count,
            }))
            const COLORS = ['#7f1d1d', '#991b1b', '#b91c1c', '#dc2626']
            const total = genderData.reduce((sum, item) => sum + item.value, 0)

            // Get screen time for each gender
            const getGenderScreenTime = (gender: string) => {
              const found = analytics.gender_screen_time?.find(
                g => g.gender === gender || (gender === 'Not Specified' && g.gender === 'Not Specified')
              )
              return found?.avg_minutes || 0
            }

            return (
              <div className="semi-donut-container">
                <ResponsiveContainer width="100%" height={200}>
                  <PieChart>
                    <Pie
                      data={genderData}
                      cx="50%"
                      cy="95%"
                      startAngle={180}
                      endAngle={0}
                      innerRadius={80}
                      outerRadius={130}
                      paddingAngle={2}
                      dataKey="value"
                    >
                      {genderData.map((_, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        background: 'white',
                        border: 'none',
                        borderRadius: '8px',
                        boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
                      }}
                    />
                  </PieChart>
                </ResponsiveContainer>
                <div className="semi-donut-total">
                  <span className="total-value">{total}</span>
                  <span className="total-label">Total Students</span>
                </div>
                <div className="semi-donut-legend">
                  {genderData.map((item, index) => (
                    <div key={item.name} className="legend-item-inline">
                      <div className="legend-row">
                        <span className="legend-color" style={{ backgroundColor: COLORS[index % COLORS.length] }} />
                        <span className="legend-label">{item.name}</span>
                        <span className="legend-value">{item.value}</span>
                      </div>
                      <span className="legend-avg">Avg: {formatMinutes(getGenderScreenTime(item.name))}</span>
                    </div>
                  ))}
                </div>
              </div>
            )
          })()}
        </div>
      </div>

      {/* Department Comparison */}
      {user?.role === 'super_admin' && departmentComparison.length > 0 && (
        <div className="dashboard-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">Department Comparison</h2>
            <span className="time-badge">All Departments</span>
          </div>
          <div className="comparison-table-container">
            <table className="comparison-table">
              <thead>
                <tr>
                  <th>Department</th>
                  <th>Students</th>
                  <th>Avg Screen Time</th>
                  <th>Total XP</th>
                </tr>
              </thead>
              <tbody>
                {departmentComparison.map((dept) => (
                  <tr key={dept.department_id}>
                    <td>{dept.department_name}</td>
                    <td>{dept.total_students}</td>
                    <td>{formatMinutes(dept.average_screen_time)}</td>
                    <td>{dept.total_xp.toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}