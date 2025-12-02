import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '@/hooks/useAuth'

export function LoginNew() {
    const [username, setUsername] = useState('')
    const [password, setPassword] = useState('')
    const [error, setError] = useState('')
    const [loading, setLoading] = useState(false)
    const [success, setSuccess] = useState(false)
    const [focusedInput, setFocusedInput] = useState<string | null>(null)
    const { signIn } = useAuth()
    const navigate = useNavigate()

    // Auto-dismiss error after 4 seconds
    useEffect(() => {
        if (error) {
            const timer = setTimeout(() => setError(''), 4000)
            return () => clearTimeout(timer)
        }
    }, [error])

    // Set page background
    useEffect(() => {
        document.documentElement.style.background = '#f3f4f6'
        document.body.style.background = '#f3f4f6'
        document.body.style.margin = '0'
        const root = document.getElementById('root')
        if (root) root.style.background = '#f3f4f6'

        return () => {
            document.documentElement.style.background = ''
            document.body.style.background = ''
            if (root) root.style.background = ''
        }
    }, [])

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setError('')
        setLoading(true)

        try {
            await signIn(username, password)
            setSuccess(true)
            setTimeout(() => navigate('/dashboard'), 1200)
        } catch (err: any) {
            setError(err.message || 'Invalid username or password')
            setLoading(false)
        }
    }

    // Success loader
    if (success) {
        return (
            <div style={styles.loaderOverlay}>
                <div style={styles.loaderBox}>
                    <div style={styles.spinner}></div>
                    <p style={styles.loaderText}>Signing you in...</p>
                </div>
                <style>{spinnerKeyframes}</style>
            </div>
        )
    }

    return (
        <div style={styles.page}>
            {/* Back Button - Fixed Top Left */}
            <button onClick={() => navigate('/')} style={styles.backButton}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M19 12H5M12 19l-7-7 7-7" />
                </svg>
                Back
            </button>

            <div style={styles.container}>
                {/* Logo */}
                <div style={styles.logoSection}>
                    <img src="/logo.svg" alt="TriMinder" style={styles.logo} />
                    <h1 style={styles.title}>TriMinder</h1>
                    <p style={styles.subtitle}>Admin Dashboard</p>
                </div>

                {/* Login Card */}
                <div style={styles.card}>
                    <h2 style={styles.cardTitle}>Welcome Back</h2>
                    <p style={styles.cardSubtitle}>Sign in to your account</p>

                    <form onSubmit={handleSubmit} style={styles.form}>
                        {/* Username */}
                        <div style={styles.inputGroup}>
                            <label style={styles.label}>Username</label>
                            <input
                                type="text"
                                value={username}
                                onChange={(e) => setUsername(e.target.value)}
                                onFocus={() => setFocusedInput('username')}
                                onBlur={() => setFocusedInput(null)}
                                placeholder="Enter your username"
                                style={{
                                    ...styles.input,
                                    ...(focusedInput === 'username' ? styles.inputFocused : {}),
                                }}
                                required
                            />
                        </div>

                        {/* Password */}
                        <div style={styles.inputGroup}>
                            <label style={styles.label}>Password</label>
                            <input
                                type="password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                onFocus={() => setFocusedInput('password')}
                                onBlur={() => setFocusedInput(null)}
                                placeholder="Enter your password"
                                style={{
                                    ...styles.input,
                                    ...(focusedInput === 'password' ? styles.inputFocused : {}),
                                }}
                                required
                            />
                        </div>

                        {/* Error */}
                        {error && (
                            <div style={styles.error}>
                                <span style={styles.errorIcon}>!</span>
                                {error}
                            </div>
                        )}

                        {/* Submit Button */}
                        <button
                            type="submit"
                            disabled={loading}
                            style={{
                                ...styles.button,
                                opacity: loading ? 0.7 : 1,
                                cursor: loading ? 'not-allowed' : 'pointer',
                            }}
                        >
                            {loading ? 'Signing in...' : 'Sign In'}
                        </button>
                    </form>
                </div>

                <p style={styles.footer}>Secure admin access portal</p>
            </div>
            <style>{spinnerKeyframes}</style>
        </div>
    )
}

const spinnerKeyframes = `
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
`

const styles: { [key: string]: React.CSSProperties } = {
    page: {
        minHeight: '100vh',
        width: '100%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#f3f4f6',
        padding: '20px',
        boxSizing: 'border-box',
    },
    container: {
        width: '100%',
        maxWidth: '380px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
    },
    backButton: {
        position: 'fixed',
        top: '20px',
        left: '20px',
        display: 'flex',
        alignItems: 'center',
        gap: '6px',
        padding: '10px 16px',
        background: 'white',
        border: '1px solid #e5e7eb',
        borderRadius: '10px',
        fontSize: '14px',
        fontWeight: 500,
        color: '#374151',
        cursor: 'pointer',
        transition: 'all 0.2s',
        boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
        zIndex: 100,
    },
    logoSection: {
        textAlign: 'center',
        marginBottom: '24px',
        width: '100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
    },
    logo: {
        width: '72px',
        height: '72px',
        marginBottom: '12px',
        filter: 'drop-shadow(0 4px 12px rgba(0,0,0,0.15))',
        display: 'block',
    },
    title: {
        fontSize: '28px',
        fontWeight: 700,
        color: '#7f1d1d',
        margin: '0 0 4px 0',
    },
    subtitle: {
        fontSize: '14px',
        color: '#9ca3af',
        margin: 0,
    },
    card: {
        width: '100%',
        background: 'white',
        borderRadius: '16px',
        padding: '32px',
        boxShadow: '0 4px 24px rgba(0,0,0,0.08)',
        boxSizing: 'border-box',
    },
    cardTitle: {
        fontSize: '20px',
        fontWeight: 600,
        color: '#111827',
        margin: '0 0 4px 0',
        textAlign: 'center',
    },
    cardSubtitle: {
        fontSize: '14px',
        color: '#6b7280',
        margin: '0 0 24px 0',
        textAlign: 'center',
    },
    form: {
        display: 'flex',
        flexDirection: 'column',
        gap: '16px',
    },
    inputGroup: {
        display: 'flex',
        flexDirection: 'column',
        gap: '6px',
    },
    label: {
        fontSize: '14px',
        fontWeight: 500,
        color: '#374151',
    },
    input: {
        width: '100%',
        padding: '12px 14px',
        fontSize: '15px',
        border: '1px solid #e5e7eb',
        borderRadius: '10px',
        outline: 'none',
        transition: 'border-color 0.2s, box-shadow 0.2s',
        boxSizing: 'border-box',
    },
    inputFocused: {
        borderColor: '#991b1b',
        boxShadow: '0 0 0 3px rgba(153, 27, 27, 0.15)',
    },
    error: {
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        padding: '12px',
        background: '#fef2f2',
        border: '1px solid #fecaca',
        borderRadius: '10px',
        color: '#dc2626',
        fontSize: '14px',
    },
    errorIcon: {
        width: '20px',
        height: '20px',
        background: '#dc2626',
        color: 'white',
        borderRadius: '50%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: '12px',
        fontWeight: 700,
        flexShrink: 0,
    },
    button: {
        width: '100%',
        padding: '14px',
        fontSize: '15px',
        fontWeight: 600,
        color: 'white',
        background: '#991b1b',
        border: 'none',
        borderRadius: '10px',
        marginTop: '8px',
        transition: 'background 0.2s',
    },
    footer: {
        fontSize: '12px',
        color: '#9ca3af',
        marginTop: '24px',
    },
    loaderOverlay: {
        position: 'fixed',
        inset: 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#f3f4f6',
    },
    loaderBox: {
        textAlign: 'center',
    },
    spinner: {
        width: '48px',
        height: '48px',
        border: '4px solid #e5e7eb',
        borderTopColor: '#991b1b',
        borderRadius: '50%',
        animation: 'spin 1s linear infinite',
        margin: '0 auto 16px',
    },
    loaderText: {
        fontSize: '16px',
        fontWeight: 500,
        color: '#374151',
        margin: 0,
    },
}
