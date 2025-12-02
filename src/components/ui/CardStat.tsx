import type { ReactNode } from 'react'

interface CardStatProps {
  title: string
  value: string | number
  icon?: ReactNode
  trend?: {
    value: number
    isPositive: boolean
  }
  className?: string
}

export function CardStat({ title, value, icon, trend, className = '' }: CardStatProps) {
  return (
    <div className={`card-stat ${className}`}>
      <div className="card-stat-content">
        {icon && (
          <div className="card-stat-icon">
            {icon}
          </div>
        )}
        <div className="card-stat-info">
          <p className="card-stat-title">{title}</p>
          <p className="card-stat-value">{value}</p>
          {trend && (
            <div className={`card-stat-trend ${trend.isPositive ? 'positive' : 'negative'}`}>
              <span>{trend.isPositive ? '↑' : '↓'}</span>
              <span>{Math.abs(trend.value)}%</span>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}