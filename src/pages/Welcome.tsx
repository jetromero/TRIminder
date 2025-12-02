import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'

export function Welcome() {
    const navigate = useNavigate()
    const [hoveredBtn, setHoveredBtn] = useState<string | null>(null)
    const [navigating, setNavigating] = useState<'student' | 'admin' | null>(null)

    const handleNavigate = (type: 'student' | 'admin') => {
        setNavigating(type)
        setTimeout(() => {
            navigate(type === 'student' ? '/student-download' : '/login')
        }, 1000)
    }

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

    // Show loader when navigating
    if (navigating) {
        return (
            <div style={styles.loaderOverlay}>
                <div style={styles.loaderContent}>
                    <div style={styles.loaderSpinner}></div>
                    <p style={styles.loaderText}>
                        {navigating === 'student' ? 'Opening download page...' : 'Opening admin login...'}
                    </p>
                </div>
                <style>{`
                    @keyframes spin {
                        0% { transform: rotate(0deg); }
                        100% { transform: rotate(360deg); }
                    }
                `}</style>
            </div>
        )
    }

    return (
        <div style={styles.page}>
            <div style={styles.container}>
                {/* Logo */}
                <div style={styles.logoSection}>
                    <img src="/logo.svg" alt="TriMinder" style={styles.logo} />
                    <h1 style={styles.title}>TriMinder</h1>
                    <p style={styles.subtitle}>Screen Time Management for Students</p>
                </div>

                {/* Selection Card */}
                <div style={styles.card}>
                    <h2 style={styles.cardTitle}>Welcome!</h2>
                    <p style={styles.cardSubtitle}>Please select your role to continue</p>

                    <div style={styles.buttonGroup}>
                        {/* Student Button */}
                        <button
                            onClick={() => handleNavigate('student')}
                            onMouseEnter={() => setHoveredBtn('student')}
                            onMouseLeave={() => setHoveredBtn(null)}
                            disabled={navigating !== null}
                            style={{
                                ...styles.roleButton,
                                background: hoveredBtn === 'student' ? '#f0fdf4' : 'white',
                                borderColor: hoveredBtn === 'student' ? '#22c55e' : '#e5e7eb',
                            }}
                        >
                            <div style={{ ...styles.buttonIcon, background: '#dcfce7', color: '#16a34a' }}>
                                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                    <path d="M22 10v6M2 10l10-5 10 5-10 5z" />
                                    <path d="M6 12v5c3 3 9 3 12 0v-5" />
                                </svg>
                            </div>
                            <div style={styles.buttonText}>
                                <span style={styles.buttonTitle}>I'm a Student</span>
                                <span style={styles.buttonDesc}>Download the TriMinder app</span>
                            </div>
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#9ca3af" strokeWidth="2">
                                <path d="M9 18l6-6-6-6" />
                            </svg>
                        </button>

                        {/* Admin Button */}
                        <button
                            onClick={() => handleNavigate('admin')}
                            onMouseEnter={() => setHoveredBtn('admin')}
                            onMouseLeave={() => setHoveredBtn(null)}
                            disabled={navigating !== null}
                            style={{
                                ...styles.roleButton,
                                background: hoveredBtn === 'admin' ? '#fef2f2' : 'white',
                                borderColor: hoveredBtn === 'admin' ? '#991b1b' : '#e5e7eb',
                            }}
                        >
                            <div style={{ ...styles.buttonIcon, background: '#fee2e2', color: '#991b1b' }}>
                                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                    <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
                                    <circle cx="9" cy="7" r="4" />
                                    <path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
                                </svg>
                            </div>
                            <div style={styles.buttonText}>
                                <span style={styles.buttonTitle}>I'm an Admin</span>
                                <span style={styles.buttonDesc}>Access the dashboard</span>
                            </div>
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#9ca3af" strokeWidth="2">
                                <path d="M9 18l6-6-6-6" />
                            </svg>
                        </button>
                    </div>
                </div>

                <p style={styles.footer}>EVSU Screen Time Management System</p>
            </div>
        </div>
    )
}

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
    buttonGroup: {
        display: 'flex',
        flexDirection: 'column',
        gap: '12px',
    },
    roleButton: {
        display: 'flex',
        alignItems: 'center',
        gap: '14px',
        width: '100%',
        padding: '14px 16px',
        background: 'white',
        border: '1px solid #e5e7eb',
        borderRadius: '12px',
        cursor: 'pointer',
        transition: 'all 0.2s',
        textAlign: 'left',
        boxSizing: 'border-box',
    },
    buttonIcon: {
        width: '44px',
        height: '44px',
        borderRadius: '10px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
    },
    buttonText: {
        display: 'flex',
        flexDirection: 'column',
        gap: '2px',
        flex: 1,
    },
    buttonTitle: {
        fontSize: '15px',
        fontWeight: 600,
        color: '#111827',
    },
    buttonDesc: {
        fontSize: '13px',
        color: '#6b7280',
    },
    footer: {
        fontSize: '12px',
        color: '#9ca3af',
        marginTop: '24px',
    },
    loaderOverlay: {
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        background: '#f3f4f6',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 9999,
    },
    loaderContent: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '16px',
    },
    loaderSpinner: {
        width: '48px',
        height: '48px',
        border: '4px solid #e5e7eb',
        borderTopColor: '#991b1b',
        borderRadius: '50%',
        animation: 'spin 1s linear infinite',
    },
    loaderText: {
        fontSize: '16px',
        color: '#6b7280',
        margin: 0,
    },
}
