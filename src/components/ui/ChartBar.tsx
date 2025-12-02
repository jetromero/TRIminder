import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from 'recharts'
import { formatMinutes } from '@/lib/utils/formatTime'

interface ChartBarProps {
  data: Array<{ [key: string]: string | number }>
  dataKey: string
  fillColor?: string
  height?: number
  xAxisKey?: string
  showGradient?: boolean
  barSize?: number
}

const GRADIENT_COLORS = [
  '#991b1b', // maroon-dark
  '#b91c1c', // maroon
  '#dc2626', // red  
  '#7f1d1d', // maroon-darker
  '#a16207', // amber-dark (accent)
  '#ca8a04', // yellow-dark (accent)
]

export function ChartBar({
  data,
  dataKey,
  fillColor = '#0ea5e9',
  height = 300,
  xAxisKey = 'range',
  showGradient = false,
  barSize
}: ChartBarProps) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart
        data={data}
        margin={{ top: 10, right: 10, left: -10, bottom: 5 }}
        barSize={barSize}
      >
        <defs>
          <linearGradient id="barGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={fillColor} stopOpacity={1} />
            <stop offset="100%" stopColor={fillColor} stopOpacity={0.6} />
          </linearGradient>
        </defs>
        <CartesianGrid
          strokeDasharray="3 3"
          stroke="#e5e7eb"
          vertical={false}
        />
        <XAxis
          dataKey={xAxisKey}
          stroke="#9ca3af"
          fontSize={11}
          tickLine={false}
          axisLine={{ stroke: '#e5e7eb' }}
        />
        <YAxis
          stroke="#9ca3af"
          fontSize={11}
          tickLine={false}
          axisLine={false}
        />
        <Tooltip
          contentStyle={{
            backgroundColor: 'rgba(255, 255, 255, 0.95)',
            border: 'none',
            borderRadius: '8px',
            padding: '10px 14px',
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
          }}
          labelStyle={{ fontWeight: 600, marginBottom: 4 }}
          cursor={{ fill: 'rgba(0, 0, 0, 0.04)' }}
          formatter={(value: number) => {
            if (dataKey === 'minutes') {
              return [formatMinutes(value), 'Avg Time']
            }
            return [value.toLocaleString(), dataKey]
          }}
        />
        <Bar
          dataKey={dataKey}
          fill={showGradient ? undefined : "url(#barGradient)"}
          radius={[6, 6, 0, 0]}
          maxBarSize={60}
        >
          {showGradient && data.map((_, index) => (
            <Cell
              key={`cell-${index}`}
              fill={GRADIENT_COLORS[index % GRADIENT_COLORS.length]}
            />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  )
}

