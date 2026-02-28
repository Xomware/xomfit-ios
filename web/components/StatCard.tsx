interface StatCardProps {
  label: string
  value: string | number
  unit?: string
  icon?: string
  trend?: {
    direction: 'up' | 'down' | 'neutral'
    value: string
  }
  accent?: 'green' | 'yellow' | 'blue' | 'red'
}

const accentClasses = {
  green: {
    icon: 'bg-green-500/15 text-green-400',
    value: 'text-green-400',
    trend: { up: 'text-green-400', down: 'text-red-400', neutral: 'text-gray-400' },
  },
  yellow: {
    icon: 'bg-yellow-500/15 text-yellow-400',
    value: 'text-yellow-400',
    trend: { up: 'text-green-400', down: 'text-red-400', neutral: 'text-gray-400' },
  },
  blue: {
    icon: 'bg-blue-500/15 text-blue-400',
    value: 'text-blue-400',
    trend: { up: 'text-green-400', down: 'text-red-400', neutral: 'text-gray-400' },
  },
  red: {
    icon: 'bg-red-500/15 text-red-400',
    value: 'text-red-400',
    trend: { up: 'text-green-400', down: 'text-red-400', neutral: 'text-gray-400' },
  },
}

export default function StatCard({
  label,
  value,
  unit,
  icon,
  trend,
  accent = 'green',
}: StatCardProps) {
  const classes = accentClasses[accent]

  const trendIcon =
    trend?.direction === 'up' ? '↑' : trend?.direction === 'down' ? '↓' : '→'

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
      <div className="flex items-start justify-between mb-3">
        <p className="text-gray-400 text-sm font-medium">{label}</p>
        {icon && (
          <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-sm ${classes.icon}`}>
            {icon}
          </div>
        )}
      </div>

      <div className="flex items-baseline gap-1.5">
        <span className={`text-3xl font-black ${classes.value}`}>
          {typeof value === 'number' ? value.toLocaleString() : value}
        </span>
        {unit && <span className="text-gray-500 text-sm font-medium">{unit}</span>}
      </div>

      {trend && (
        <div className={`flex items-center gap-1 mt-2 text-xs font-medium ${classes.trend[trend.direction]}`}>
          <span>{trendIcon}</span>
          <span>{trend.value}</span>
        </div>
      )}
    </div>
  )
}
