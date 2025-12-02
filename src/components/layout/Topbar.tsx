import { useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { useNavigate } from 'react-router-dom'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'
import { changeAdminPassword } from '@/lib/api/admins'

interface TopbarProps {
  onMenuClick?: () => void
}

export function Topbar({ onMenuClick }: TopbarProps) {
  const { user, signOut } = useAuth()
  const navigate = useNavigate()
  const [showDropdown, setShowDropdown] = useState(false)
  const [showPasswordModal, setShowPasswordModal] = useState(false)
  const [passwordForm, setPasswordForm] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  })
  const [passwordError, setPasswordError] = useState('')
  const [passwordLoading, setPasswordLoading] = useState(false)

  const handleLogout = async () => {
    setShowDropdown(false)
    await signOut()
    navigate('/login')
  }

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault()
    setPasswordError('')

    if (passwordForm.newPassword !== passwordForm.confirmPassword) {
      setPasswordError('New passwords do not match')
      return
    }

    if (passwordForm.newPassword.length < 6) {
      setPasswordError('Password must be at least 6 characters')
      return
    }

    setPasswordLoading(true)
    try {
      await changeAdminPassword(
        parseInt(user!.id),
        passwordForm.currentPassword,
        passwordForm.newPassword
      )
      setShowPasswordModal(false)
      setPasswordForm({ currentPassword: '', newPassword: '', confirmPassword: '' })
      alert('Password changed successfully!')
    } catch (error: any) {
      setPasswordError(error.message || 'Failed to change password')
    } finally {
      setPasswordLoading(false)
    }
  }

  const openPasswordModal = () => {
    setShowDropdown(false)
    setPasswordForm({ currentPassword: '', newPassword: '', confirmPassword: '' })
    setPasswordError('')
    setShowPasswordModal(true)
  }

  return (
    <header className="topbar">
      <div className="topbar-left">
        {onMenuClick && (
          <button
            onClick={onMenuClick}
            className="topbar-menu-btn"
            title="Toggle menu"
          >
            <svg className="topbar-menu-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
        )}
        <div className="topbar-greeting">
          <h2 className="topbar-greeting-title">
            {user?.department_id ? 'Department Admin' : 'Super Admin'}
          </h2>
          <p className="topbar-greeting-subtitle">Welcome back!</p>
        </div>
      </div>

      <div className="topbar-right">
        <div className="topbar-user-menu">
          <button
            onClick={() => setShowDropdown(!showDropdown)}
            className={`topbar-user-btn ${showDropdown ? 'open' : ''}`}
          >
            <div className="topbar-user-avatar">
              <img src="/EVSU_logo.png" alt="EVSU" className="topbar-avatar-img" />
            </div>
            <div className="topbar-user-info">
              <p className="topbar-user-name">
                {user?.admin?.name || user?.email || `Admin #${user?.id}`}
              </p>
              <p className="topbar-user-role">
                {user?.role?.replace('_', ' ')}
              </p>
            </div>
            <svg
              className="topbar-user-chevron"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          {showDropdown && (
            <>
              <div
                className="topbar-dropdown-backdrop"
                onClick={() => setShowDropdown(false)}
              ></div>
              <div className="topbar-dropdown">
                <div className="topbar-dropdown-header">
                  <p className="topbar-dropdown-user-name">
                    {user?.admin?.name || user?.email || `Admin #${user?.id}`}
                  </p>
                  <p className="topbar-dropdown-user-role">
                    {user?.role?.replace('_', ' ')}
                  </p>
                </div>
                <div className="topbar-dropdown-divider"></div>
                <button
                  onClick={openPasswordModal}
                  className="topbar-dropdown-item"
                >
                  <svg className="topbar-dropdown-item-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
                  </svg>
                  Change Password
                </button>
                <button
                  onClick={handleLogout}
                  className="topbar-dropdown-logout"
                >
                  <svg className="topbar-dropdown-logout-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                  </svg>
                  Logout
                </button>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Change Password Modal */}
      <Modal
        isOpen={showPasswordModal}
        onClose={() => setShowPasswordModal(false)}
        title="Change Password"
        footer={
          <>
            <Button variant="secondary" onClick={() => setShowPasswordModal(false)}>
              Cancel
            </Button>
            <Button onClick={handleChangePassword} disabled={passwordLoading}>
              {passwordLoading ? 'Saving...' : 'Change Password'}
            </Button>
          </>
        }
      >
        <form onSubmit={handleChangePassword} className="modal-form">
          {passwordError && (
            <div className="form-error-message">{passwordError}</div>
          )}
          <Input
            label="Current Password"
            type="password"
            value={passwordForm.currentPassword}
            onChange={(e) => setPasswordForm({ ...passwordForm, currentPassword: e.target.value })}
            required
          />
          <Input
            label="New Password"
            type="password"
            value={passwordForm.newPassword}
            onChange={(e) => setPasswordForm({ ...passwordForm, newPassword: e.target.value })}
            required
          />
          <Input
            label="Confirm New Password"
            type="password"
            value={passwordForm.confirmPassword}
            onChange={(e) => setPasswordForm({ ...passwordForm, confirmPassword: e.target.value })}
            required
          />
        </form>
      </Modal>
    </header>
  )
}