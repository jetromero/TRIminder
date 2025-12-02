import type { SelectHTMLAttributes, ReactNode } from 'react'

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string
  error?: string
  compact?: boolean
  children: ReactNode
}

export function Select({ label, error, compact, className = '', children, ...props }: SelectProps) {
  return (
    <div className="input-group">
      {label && (
        <label className="input-label">
          {label}
        </label>
      )}
      <div className="select-wrapper">
        <select
          className={`select ${compact ? 'select-compact' : ''} ${error ? 'input-error' : ''} ${className}`}
          {...props}
        >
          {children}
        </select>
      </div>
      {error && (
        <p className="input-error-message">
          <span>⚠️</span>
          <span>{error}</span>
        </p>
      )}
    </div>
  )
}

