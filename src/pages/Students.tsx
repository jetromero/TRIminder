import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '@/hooks/useAuth'
import { getStudentsWithStats } from '@/lib/api/students'
import { getDepartments } from '@/lib/api/departments'
import { Table } from '@/components/ui/Table'
import { FilterDropdown } from '@/components/ui/FilterDropdown'
import type { StudentWithStats, Department } from '@/types/database'
import '@/styles/students.css'
import { formatMinutes } from '@/lib/utils/formatTime'

export function Students() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [students, setStudents] = useState<StudentWithStats[]>([])
  const [departments, setDepartments] = useState<Department[]>([])
  const [selectedDepartment, setSelectedDepartment] = useState<number | undefined>(
    user?.department_id || undefined
  )
  const [loading, setLoading] = useState(true)
  const [sortKey, setSortKey] = useState<string>('created_at')
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc')
  const [page, setPage] = useState(1)
  const pageSize = 10

  // Search and filter states
  const [searchQuery, setSearchQuery] = useState('')
  const [filterYearLevel, setFilterYearLevel] = useState<string>('')
  const [filterGender, setFilterGender] = useState<string>('')
  const [filterDepartment, setFilterDepartment] = useState<string>('')
  const [filtersExpanded, setFiltersExpanded] = useState(false)

  useEffect(() => {
    fetchStudents()
    fetchDepartments()
  }, [selectedDepartment, user])

  const fetchStudents = async () => {
    try {
      setLoading(true)
      const data = await getStudentsWithStats(selectedDepartment)
      setStudents(data)
    } catch (error) {
      console.error('Failed to fetch students:', error)
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

  const handleSort = (key: string, direction: 'asc' | 'desc') => {
    setSortKey(key)
    setSortDirection(direction)
    setPage(1) // Reset to first page when sorting
  }

  // Filter students based on search and filters
  const filteredStudents = students.filter((student) => {
    // Search filter - search across name, email, student_id
    if (searchQuery) {
      const query = searchQuery.toLowerCase()
      const fullName = `${student.first_name} ${student.last_name}`.toLowerCase()
      const email = student.email?.toLowerCase() || ''
      const studentId = student.student_id?.toLowerCase() || ''

      if (!fullName.includes(query) && !email.includes(query) && !studentId.includes(query)) {
        return false
      }
    }

    // Year level filter
    if (filterYearLevel && student.year_level !== filterYearLevel) {
      return false
    }

    // Gender filter
    if (filterGender && student.gender !== filterGender) {
      return false
    }

    // Department filter
    if (filterDepartment && student.department_id !== parseInt(filterDepartment)) {
      return false
    }

    return true
  })

  // Reset page when filters change
  useEffect(() => {
    setPage(1)
  }, [searchQuery, filterYearLevel, filterGender, filterDepartment])

  // Print PDF function
  const handlePrintPDF = () => {
    const printWindow = window.open('', '_blank', 'width=900,height=700')
    if (!printWindow) return

    // Set document title to remove about:blank
    printWindow.document.title = 'TriMinder - Students Report'

    const tableRows = sortedStudents.map((student) => {
      const dept = departments.find(d => d.id === student.department_id)
      return `
        <tr>
          <td>${student.student_id || 'N/A'}</td>
          <td>${student.first_name} ${student.last_name}</td>
          <td>${student.email || 'N/A'}</td>
          <td>${student.year_level || 'N/A'}</td>
          <td>${student.gender || 'N/A'}</td>
          <td>${dept?.name || 'N/A'}</td>
          <td>${formatMinutes(student.avg_daily_screen_time)}</td>
          <td>${student.badge_count || 0}</td>
          <td>${student.last_active ? new Date(student.last_active).toLocaleDateString() : 'Inactive'}</td>
        </tr>
      `
    }).join('')

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>TriMinder - Students Report</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { font-family: Arial, sans-serif; padding: 10px; color: #333; }
          .header { text-align: center; margin-bottom: 20px; padding-bottom: 15px; border-bottom: 2px solid #991b1b; }
          .header-row { display: flex; justify-content: center; align-items: center; gap: 30px; margin-bottom: 8px; }
          .header-row img { height: 70px; width: auto; }
          .header-row h1 { color: #991b1b; font-size: 32px; margin: 0; }
          .header p { color: #666; font-size: 12px; }
          .meta { display: flex; justify-content: space-between; margin-bottom: 15px; font-size: 12px; color: #666; }
          table { width: 100%; border-collapse: collapse; font-size: 11px; }
          th { background: #991b1b; color: white; padding: 10px 8px; text-align: left; font-weight: 600; }
          td { padding: 8px; border-bottom: 1px solid #e5e5e5; }
          tr:nth-child(even) { background: #fafafa; }
          .footer { margin-top: 20px; text-align: center; font-size: 10px; color: #999; }
          @media print {
            body { padding: 0; margin: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
            .no-print { display: none; }
            @page { 
              margin: 0.25in; 
              size: A4 landscape;
            }
          }
        </style>
      </head>
      <body>
        <div class="header">
          <div class="header-row">
            <img src="${window.location.origin}/EVSU_logo.png" alt="EVSU Logo" />
            <h1>TriMinder</h1>
            <img src="${window.location.origin}/logo.svg" alt="TriMinder Logo" />
          </div>
          <p>Students Report</p>
        </div>
        <div class="meta">
          <span>Generated: ${new Date().toLocaleString()}</span>
          <span>Total: ${sortedStudents.length} students</span>
        </div>
        <table>
          <thead>
            <tr>
              <th>Student ID</th>
              <th>Name</th>
              <th>Email</th>
              <th>Year Level</th>
              <th>Gender</th>
              <th>Department</th>
              <th>AVG Daily Screentime</th>
              <th>Badges</th>
              <th>Last Active</th>
            </tr>
          </thead>
          <tbody>
            ${tableRows}
          </tbody>
        </table>
        <div class="footer">
          <p>TriMinder - EVSU Screen Time Management System</p>
        </div>
        <script>window.onload = function() { window.print(); }</script>
      </body>
      </html>
    `

    printWindow.document.write(html)
    printWindow.document.close()
  }

  const sortedStudents = [...filteredStudents].sort((a, b) => {
    const aValue = a[sortKey as keyof StudentWithStats]
    const bValue = b[sortKey as keyof StudentWithStats]

    if (aValue === null || aValue === undefined) return 1
    if (bValue === null || bValue === undefined) return -1

    if (typeof aValue === 'number' && typeof bValue === 'number') {
      return sortDirection === 'asc' ? aValue - bValue : bValue - aValue
    }

    const aStr = String(aValue).toLowerCase()
    const bStr = String(bValue).toLowerCase()

    if (sortDirection === 'asc') {
      return aStr < bStr ? -1 : aStr > bStr ? 1 : 0
    } else {
      return aStr > bStr ? -1 : aStr < bStr ? 1 : 0
    }
  })

  const columns = [
    {
      key: 'student_id',
      header: 'Student ID',
      sortable: true,
    },
    {
      key: 'name',
      header: 'Name',
      sortable: true,
      render: (student: StudentWithStats) => (
        <div className="student-name-cell">
          {student.avatar_url ? (
            <img
              src={student.avatar_url}
              alt={`${student.first_name} ${student.last_name}`}
              className="student-table-avatar"
            />
          ) : (
            <div className="student-table-avatar student-table-avatar-initials">
              {student.first_name?.[0]}{student.last_name?.[0]}
            </div>
          )}
          <span>{student.first_name} {student.last_name}</span>
        </div>
      ),
    },
    {
      key: 'email',
      header: 'Email',
      sortable: true,
    },
    {
      key: 'year_level',
      header: 'Year Level',
      sortable: true,
      render: (student: StudentWithStats) => student.year_level || 'N/A',
    },
    {
      key: 'gender',
      header: 'Gender',
      sortable: true,
      render: (student: StudentWithStats) => student.gender || 'N/A',
    },
    {
      key: 'department_id',
      header: 'Department',
      sortable: true,
      render: (student: StudentWithStats) => {
        const dept = departments.find(d => d.id === student.department_id)
        return dept?.name || 'N/A'
      },
    },
    {
      key: 'avg_daily_screen_time',
      header: 'AVG Daily Screentime',
      sortable: true,
      render: (student: StudentWithStats) => formatMinutes(student.avg_daily_screen_time),
    },
    {
      key: 'badge_count',
      header: 'Badges',
      sortable: true,
    },
    {
      key: 'last_active',
      header: 'Last Active',
      sortable: true,
      render: (student: StudentWithStats) =>
        student.last_active ? new Date(student.last_active).toLocaleDateString() : 'Inactive',
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (student: StudentWithStats) => (
        <button
          onClick={() => navigate(`/students/${student.id}`)}
          className="btn btn-ghost btn-sm"
        >
          View Details
        </button>
      ),
    },
  ]

  if (loading) {
    return (
      <div className="page-wrapper">
        <div className="loading-wrapper">
          <div className="loading-content">
            <div className="loading-spinner"></div>
            <p className="loading-message">Loading students...</p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="page-wrapper">
      <div className="page-header-section">
        <div className="page-info">
          <h1 className="page-heading">Students</h1>
          <p className="page-subheading">View and manage students</p>
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

      <div className="filters-section">
        <div className="filters-layout">
          <div className="search-field-wrapper">
            <svg className="search-icon-svg" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              placeholder="Search by name, email, or student ID..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="search-field"
            />
            {searchQuery && (
              <button onClick={() => setSearchQuery('')} className="clear-search-btn">
                <svg className="clear-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            )}
          </div>

          <button
            onClick={() => setFiltersExpanded(!filtersExpanded)}
            className={`filters-toggle-btn ${filtersExpanded ? 'active' : ''} ${(filterYearLevel || filterDepartment || filterGender) ? 'has-filters' : ''}`}
          >
            <svg className="filters-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" width="16" height="16">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
            <span>Filters</span>
            {(filterYearLevel || filterDepartment || filterGender) && (
              <span className="filter-count-badge">
                {[filterYearLevel, filterDepartment, filterGender].filter(Boolean).length}
              </span>
            )}
          </button>

          <button onClick={handlePrintPDF} className="print-pdf-btn">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="16" height="16">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
            </svg>
            <span>Print PDF</span>
          </button>
        </div>

        {filtersExpanded && (
          <div className="collapsible-filters">
            <div className="collapsible-filters-grid">
              <FilterDropdown
                label="Year Level"
                value={filterYearLevel}
                onChange={setFilterYearLevel}
                placeholder="All Year Levels"
                options={[
                  { value: '', label: 'All Year Levels' },
                  { value: '1st Year', label: '1st Year' },
                  { value: '2nd Year', label: '2nd Year' },
                  { value: '3rd Year', label: '3rd Year' },
                  { value: '4th Year', label: '4th Year' },
                ]}
              />

              <FilterDropdown
                label="Department"
                value={filterDepartment}
                onChange={setFilterDepartment}
                placeholder="All Departments"
                options={[
                  { value: '', label: 'All Departments' },
                  ...departments.map((dept) => ({
                    value: dept.id.toString(),
                    label: dept.name,
                  })),
                ]}
              />

              <FilterDropdown
                label="Gender"
                value={filterGender}
                onChange={setFilterGender}
                placeholder="All Genders"
                options={[
                  { value: '', label: 'All Genders' },
                  { value: 'Male', label: 'Male' },
                  { value: 'Female', label: 'Female' },
                ]}
              />
            </div>
          </div>
        )}

        {(searchQuery || filterYearLevel || filterGender || filterDepartment) && (
          <div className="active-filters-bar">
            <div className="active-filters-wrapper">
              <span className="filters-heading">Active filters:</span>
              {searchQuery && (
                <span className="filter-chip">
                  Search: "{searchQuery}"
                  <button onClick={() => setSearchQuery('')} className="remove-filter-btn">
                    <svg className="remove-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </span>
              )}
              {filterYearLevel && (
                <span className="filter-chip">
                  Year: {filterYearLevel}
                  <button onClick={() => setFilterYearLevel('')} className="remove-filter-btn">
                    <svg className="remove-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </span>
              )}
              {filterDepartment && (
                <span className="filter-chip">
                  Dept: {departments.find(d => d.id === parseInt(filterDepartment))?.name}
                  <button onClick={() => setFilterDepartment('')} className="remove-filter-btn">
                    <svg className="remove-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </span>
              )}
              {filterGender && (
                <span className="filter-chip">
                  Gender: {filterGender}
                  <button onClick={() => setFilterGender('')} className="remove-filter-btn">
                    <svg className="remove-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </span>
              )}
              <button
                onClick={() => {
                  setSearchQuery('')
                  setFilterYearLevel('')
                  setFilterDepartment('')
                  setFilterGender('')
                }}
                className="clear-all-filters-btn"
              >
                Clear all
              </button>
            </div>
          </div>
        )}

        <div className="results-info">
          <p className="results-text">
            Showing <span className="results-number">{Math.min((page - 1) * pageSize + 1, filteredStudents.length)} to {Math.min(page * pageSize, filteredStudents.length)}</span> of{' '}
            <span className="results-number">{filteredStudents.length}</span> students
            {(searchQuery || filterYearLevel || filterGender || filterDepartment) && ' (filtered)'}
          </p>
        </div>
      </div>

      {filteredStudents.length === 0 ? (
        <div className="no-results-state">
          <svg className="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 className="empty-heading">No students found</h3>
          <p className="empty-message">
            {searchQuery || filterYearLevel || filterGender || filterDepartment
              ? 'Try adjusting your search or filters'
              : 'No students available'}
          </p>
          {(searchQuery || filterYearLevel || filterGender || filterDepartment) && (
            <button
              onClick={() => {
                setSearchQuery('')
                setFilterYearLevel('')
                setFilterDepartment('')
                setFilterGender('')
              }}
              className="empty-action-btn"
            >
              Clear all filters
            </button>
          )}
        </div>
      ) : (
        <Table
          columns={columns}
          data={sortedStudents}
          onSort={handleSort}
          sortKey={sortKey}
          sortDirection={sortDirection}
          pagination={{
            page,
            pageSize,
            total: sortedStudents.length,
            onPageChange: setPage,
          }}
        />
      )}
    </div>
  )
}

