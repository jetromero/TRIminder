import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getStudentById, getStudentUsageHistory, getStudentBadges } from '@/lib/api/students'
import { ChartLine } from '@/components/ui/ChartLine'
import { Button } from '@/components/ui/Button'
import type { Profile } from '@/types/database'
import { formatMinutes } from '@/lib/utils/formatTime'
import '@/styles/student-detail.css'

export function StudentDetail() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [student, setStudent] = useState<Profile | null>(null)
  const [usageHistory, setUsageHistory] = useState<any[]>([])
  const [badges, setBadges] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (id) {
      fetchStudentData()
    }
  }, [id])

  const fetchStudentData = async () => {
    if (!id) return

    try {
      const [studentData, usageData, badgesData] = await Promise.all([
        getStudentById(id),
        getStudentUsageHistory(id, 30),
        getStudentBadges(id),
      ])

      setStudent(studentData)
      setUsageHistory(usageData.map((u: any) => ({ date: u.usage_date, minutes: u.total_minutes })))
      setBadges(badgesData)
    } catch (error) {
      console.error('Failed to fetch student data:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="page-wrapper">
        <div className="loading-wrapper">
          <div className="loading-content">
            <div className="loading-spinner"></div>
            <p className="loading-message">Loading student details...</p>
          </div>
        </div>
      </div>
    )
  }

  if (!student) {
    return (
      <div className="page-wrapper">
        <div className="empty-state-wrapper">
          <svg className="empty-state-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
          <h3 className="empty-state-heading">Student not found</h3>
          <p className="empty-state-subtext">The student you're looking for doesn't exist</p>
        </div>
      </div>
    )
  }

  const totalScreenTime = usageHistory.reduce((sum, u) => sum + u.minutes, 0)
  const avgScreenTime = usageHistory.length > 0 ? Math.round(totalScreenTime / usageHistory.length) : 0
  const level = Math.floor(student.xp / 100) + 1 // Calculate level from XP
  const initials = `${student.first_name?.[0] || ''}${student.last_name?.[0] || ''}`.toUpperCase()

  return (
    <div className="page-wrapper">
      <div className="student-detail-container">
        {/* Back Button */}
        <div style={{ marginBottom: 'var(--spacing-lg)' }}>
          <Button variant="ghost" size="sm" onClick={() => navigate('/students')}>
            ← Back to Students
          </Button>
        </div>

        {/* Header Section */}
        <div className="student-header">
          <div className="student-header-content">
            {student.avatar_url ? (
              <img
                src={student.avatar_url}
                alt={`${student.first_name} ${student.last_name}`}
                className="student-avatar student-avatar-img"
              />
            ) : (
              <div className="student-avatar">{initials}</div>
            )}
            <div className="student-info">
              <h1 className="student-name">
                {student.first_name} {student.last_name}
              </h1>
              <p className="student-email">{student.email}</p>
              <span className="student-tag">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="16" height="16">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span>{student.user_tag}</span>
              </span>
            </div>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="stats-grid">
          <div className="stat-card">
            <span className="stat-icon">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="24" height="24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </span>
            <p className="stat-label">Level</p>
            <p className="stat-value">{level}</p>
          </div>
          <div className="stat-card">
            <span className="stat-icon">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="24" height="24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </span>
            <p className="stat-label">AVG Screentime</p>
            <p className="stat-value">{formatMinutes(avgScreenTime)}</p>
          </div>
          <div className="stat-card">
            <span className="stat-icon">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="24" height="24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
              </svg>
            </span>
            <p className="stat-label">Badges Earned</p>
            <p className="stat-value">{badges.length}</p>
          </div>
          <div className="stat-card">
            <span className="stat-icon">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="24" height="24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V8a2 2 0 00-2-2h-5m-4 0V5a2 2 0 114 0v1m-4 0a2 2 0 104 0m-5 8a2 2 0 100-4 2 2 0 000 4zm0 0c1.306 0 2.417.835 2.83 2M9 14a3.001 3.001 0 00-2.83 2M15 11h3m-3 4h2" />
              </svg>
            </span>
            <p className="stat-label">Student ID</p>
            <p className="stat-value">{student.student_id || 'N/A'}</p>
          </div>
        </div>

        {/* Charts Section */}
        <div className="chart-card chart-full-width">
          <div className="chart-header">
            <h2 className="chart-title">Usage History</h2>
            <span className="chart-badge">Last 30 Days</span>
          </div>
          {usageHistory.length > 0 ? (
            <ChartLine data={usageHistory} dataKey="minutes" strokeColor="#7f1d1d" />
          ) : (
            <div className="empty-state">
              <svg className="empty-state-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" width="48" height="48">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
              <p className="empty-state-text">No usage data available</p>
            </div>
          )}
        </div>

        {/* Badges Section */}
        <div className="badges-section">
          <div className="section-header">
            <h2 className="section-title">Achievements & Badges</h2>
            <span className="badge-count">{badges.length} Earned</span>
          </div>
          {badges.length > 0 ? (
            <div className="badges-grid">
              {badges.map((badge: any) => (
                <div key={`${badge.user_id}-${badge.badge_id}`} className="badge-card">
                  <div className="badge-content">
                    {badge.badges?.icon_url && (
                      <div className="badge-icon-wrapper">
                        <img src={badge.badges.icon_url} alt={badge.badges.name} className="badge-icon" />
                      </div>
                    )}
                    <div className="badge-details">
                      <h3 className="badge-name">{badge.badges?.name || 'Unknown Badge'}</h3>
                      <p className="badge-description">{badge.badges?.description || ''}</p>
                      <p className="badge-date">
                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="14" height="14">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                        <span>{new Date(badge.awarded_at).toLocaleDateString()}</span>
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <svg className="empty-state-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" width="48" height="48">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
              </svg>
              <p className="empty-state-text">No badges earned yet</p>
            </div>
          )}
        </div>

        {/* Student Information Section */}
        <div className="info-section">
          <div className="section-header">
            <h2 className="section-title">Student Information</h2>
          </div>
          <div className="info-grid">
            <div className="info-item">
              <p className="info-label">User Tag</p>
              <p className="info-value">{student.user_tag}</p>
            </div>
            <div className="info-item">
              <p className="info-label">Year Level</p>
              <p className="info-value">{student.year_level || 'N/A'}</p>
            </div>
            <div className="info-item">
              <p className="info-label">Gender</p>
              <p className="info-value">{student.gender || 'N/A'}</p>
            </div>
            <div className="info-item">
              <p className="info-label">Date of Birth</p>
              <p className="info-value">
                {student.date_of_birth ? new Date(student.date_of_birth).toLocaleDateString() : 'N/A'}
              </p>
            </div>
            <div className="info-item">
              <p className="info-label">Member Since</p>
              <p className="info-value">{new Date(student.created_at).toLocaleDateString()}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}