interface PRBadgeProps {
  exercise_name: string
  weight_lbs: number
  reps: number
  date: string
  size?: 'sm' | 'md' | 'lg'
}

export default function PRBadge({
  exercise_name,
  weight_lbs,
  reps,
  date,
  size = 'md',
}: PRBadgeProps) {
  const exerciseName = exercise_name
  const formattedDate = new Date(date).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })

  if (size === 'sm') {
    return (
      <div className="flex items-center gap-2 bg-yellow-500/10 border border-yellow-500/25 rounded-lg px-3 py-2">
        <span className="text-yellow-400 text-sm">🏆</span>
        <div>
          <p className="text-white text-xs font-semibold">{exerciseName}</p>
          <p className="text-yellow-400 text-xs font-bold">{weight_lbs} lbs × {reps}</p>
        </div>
      </div>
    )
  }

  if (size === 'lg') {
    return (
      <div className="bg-gradient-to-br from-yellow-500/15 to-orange-500/10 border border-yellow-500/30 rounded-xl p-5">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 rounded-xl bg-yellow-500/20 flex items-center justify-center text-2xl flex-shrink-0">
            🏆
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-yellow-400 text-xs font-semibold uppercase tracking-wider mb-1">
              Personal Record
            </p>
            <h3 className="text-white font-bold text-lg leading-tight">{exerciseName}</h3>
            <div className="flex items-baseline gap-2 mt-2">
              <span className="text-3xl font-black text-white">{weight_lbs}</span>
              <span className="text-gray-400 text-sm">lbs</span>
              <span className="text-gray-500 mx-1">×</span>
              <span className="text-xl font-bold text-white">{reps}</span>
              <span className="text-gray-400 text-sm">reps</span>
            </div>
            <p className="text-gray-500 text-xs mt-1">{formattedDate}</p>
          </div>
        </div>
      </div>
    )
  }

  // Default 'md'
  return (
    <div className="bg-yellow-500/10 border border-yellow-500/25 rounded-xl p-4">
      <div className="flex items-center gap-3">
        <span className="text-xl">🏆</span>
        <div className="flex-1 min-w-0">
          <p className="text-yellow-400 text-xs font-semibold uppercase tracking-wider">PR</p>
          <p className="text-white font-bold text-sm truncate">{exerciseName}</p>
        </div>
        <div className="text-right">
          <p className="text-white font-black">{weight_lbs} lbs</p>
          <p className="text-gray-400 text-xs">× {reps} reps</p>
        </div>
      </div>
      <p className="text-gray-500 text-xs mt-2">{formattedDate}</p>
    </div>
  )
}
