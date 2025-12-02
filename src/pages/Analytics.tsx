import { useEffect, useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { getAnalytics, getDepartmentComparison } from '@/lib/api/analytics'
import { getDepartments } from '@/lib/api/departments'
import { CardStat } from '@/components/ui/CardStat'
import { ChartLine } from '@/components/ui/ChartLine'
import { ChartBar } from '@/components/ui/ChartBar'
import { FilterDropdown } from '@/components/ui/FilterDropdown'
import type { AnalyticsData, Department } from '@/types/database'

export function Analytics() {
  const { user } = useAuth()
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null)
  const [departments, setDepartments] = useState<Department[]>([])
  const [departmentComparison, setDepartmentComparison] = useState<any[]>([])
  const [selectedDepartment, setSelectedDepartment] = useState<number | undefined>(
    user?.department_id || undefined
  )
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchAnalytics()
    if (user?.role === 'super_admin') {
      fetchDepartments()
      fetchDepartmentComparison()
    }
  }, [selectedDepartment, user])

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
            <p className="loading-message">Loading analytics...</p>
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
      <div className="page-header-section">
        <div className="page-info">
          <h1 className="page-heading">Analytics</h1>
          <p className="page-subheading">Detailed insights and metrics</p>
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
          value={`${analytics.average_daily_screen_time} min`}
          icon={
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="40" height="40">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          }
        />
        <CardStat
          title="Total XP"
          value={analytics.total_xp.toLocaleString()}
          icon={
            <svg fill="currentColor" viewBox="0 0 24 24" width="40" height="40">
              <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
            </svg>
          }
        />
        <CardStat
          title="Total Badges"
          value={analytics.total_badges}
          icon={
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="40" height="40">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
            </svg>
          }
        />
      </div>

      <div className="charts-section">
        <div className="dashboard-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">Weekly Usage Trend</h2>
            <span className="time-badge">Last 7 days</span>
          </div>
          <ChartLine data={analytics.weekly_usage} dataKey="minutes" />
        </div>

        <div className="dashboard-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">XP Distribution</h2>
            <span className="time-badge">Overview</span>
          </div>
          <ChartBar data={analytics.xp_distribution} dataKey="count" />
        </div>

        <div className="dashboard-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">Year Level Distribution</h2>
            <span className="time-badge">Current</span>
          </div>
          <ChartBar
            data={analytics.year_level_distribution.map((item) => ({
              range: item.year_level || 'Not Specified',
              count: item.count,
            }))}
            dataKey="count"
            fillColor="#8b5cf6"
          />
        </div>

        <div className="dashboard-card">
          <div className="card-header-with-badge">
            <h2 className="card-main-title">Gender Distribution</h2>
            <span className="time-badge">Current</span>
          </div>
          <ChartBar
            data={analytics.gender_distribution.map((item) => ({
              range: item.gender || 'Not Specified',
              count: item.count,
            }))}
            dataKey="count"
            fillColor="#ec4899"
          />
        </div>
      </div>

      <div className="dashboard-card">
        <div className="card-header-with-badge">
          <h2 className="card-main-title">Top 10 Students by Screen Time</h2>
          <span className="time-badge">Leaderboard</span>
        </div>
        <div className="top-performers-list">
          {analytics.top_students.slice(0, 10).map((student, index) => (
            <div key={student.id} className="performer-item">
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
                <span className="performer-name">{student.name}</span>
              </div>
              <span className="performer-value">{student.minutes} min</span>
            </div>
          ))}
        </div>
      </div>

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
                    <td>{dept.average_screen_time} min</td>
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