import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '@/hooks/useAuth'
import { Logo } from '@/components/ui/Logo'
import '@/styles/login.css'

export function Login() {
  // Force background color on mount - cover entire screen
  useEffect(() => {
    const html = document.documentElement
    const body = document.body
    const root = document.getElementById('root')

    // Store originals
    const originals = {
      htmlBg: html.style.background,
      bodyBg: body.style.background,
      rootBg: root?.style.background || '',
      bodyMargin: body.style.margin,
      bodyPadding: body.style.padding,
      htmlHeight: html.style.minHeight,
      bodyHeight: body.style.minHeight,
    }

    // Apply grey background everywhere
    const bg = '#f8f9fa'
    html.style.background = bg
    html.style.minHeight = '100%'
    body.style.background = bg
    body.style.margin = '0'
    body.style.padding = '0'
    body.style.minHeight = '100vh'
    if (root) {
      root.style.background = bg
      root.style.minHeight = '100vh'
    }

    return () => {
      html.style.background = originals.htmlBg
      html.style.minHeight = originals.htmlHeight
      body.style.background = originals.bodyBg
      body.style.margin = originals.bodyMargin
      body.style.padding = originals.bodyPadding
      body.style.minHeight = originals.bodyHeight
      if (root) root.style.background = originals.rootBg
    }
  }, [])
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const { signIn } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      await signIn(username, password)
      setSuccess(true)
      setTimeout(() => {
        navigate('/dashboard')
      }, 1500)
    } catch (err: any) {
      setError(err.message || 'Failed to sign in')
      setLoading(false)
    }
  }

  // Full screen loader for successful login
  if (success) {
    return (
      <div className="login-loader-overlay">
        <div className="login-loader-content">
          <div className="login-loader-spinner"></div>
          <p className="login-loader-text">Signing you in...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="login-page" style={{ background: '#f8f9fa' }}>
      <div className="login-container">
        {/* Logo/Brand Section */}
        <div className="login-brand">
          <div className="login-logo">
            <Logo size={80} />
          </div>
          <h1 className="login-title">TriMinder</h1>
          <p className="login-subtitle">Admin Dashboard</p>
        </div>

        {/* Login Card */}
        <div className="login-card">
          <div className="login-card-header">
            <h2 className="login-card-title">Welcome Back</h2>
            <p className="login-card-subtitle">Sign in to continue to your dashboard</p>
          </div>

          <form onSubmit={handleSubmit} className="login-form">
            <div className="login-input-group">
              <label className="login-label">Username</label>
              <div className="login-input-wrapper">
                <svg className="login-input-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <input
                  type="text"
                  className="login-input"
                  placeholder="Enter your username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  required
                  autoComplete="username"
                />
              </div>
            </div>

            <div className="login-input-group">
              <label className="login-label">Password</label>
              <div className="login-input-wrapper">
                <svg className="login-input-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
                <input
                  type="password"
                  className="login-input"
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  autoComplete="current-password"
                />
              </div>
            </div>

            {error && (
              <div className="login-error">
                <svg className="login-error-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span>{error}</span>
              </div>
            )}

            <button
              type="submit"
              className="login-button"
              disabled={loading}
            >
              {loading ? (
                <>
                  <svg className="login-button-spinner" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Signing in...
                </>
              ) : (
                'Sign In'
              )}
            </button>
          </form>
        </div>

        {/* Footer */}
        <p className="login-footer">
          Secure admin access portal
        </p>
      </div>
    </div>
  )
}

