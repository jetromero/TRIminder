interface LogoProps {
    size?: number
    className?: string
}

export function Logo({ size = 40, className = '' }: LogoProps) {
    return (
        <img
            src="/logo.svg"
            alt="TriMinder Logo"
            width={size}
            height={size}
            className={className}
            style={{ objectFit: 'contain' }}
        />
    )
}
