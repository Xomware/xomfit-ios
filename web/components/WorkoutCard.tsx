import Link from 'next/link'

interface WorkoutCardProps {
  id: string
  name: string
  date: string
  duration_minutes: number
  exercise_count: number
  total_sets: number
  total_volume_lbs?: number
  has_pr?: boolean
  href?: string
}

export default function WorkoutCard({
  id,
  name,
  date,
  duration_minutes,
  exercise_count,
  total_sets,
  total_volume_lbs,
  has_pr,
  href,
}: WorkoutCardProps) {
  const formattedDate = new Date(date).toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  })

  const content = (
    <div className="group bg-gray-900 border border-gray-800 rounded-xl p-5 hover:border-green-500/40 hover:bg-gray-900/80 transition-all duration-200 cursor-pointer">
      <div className="flex items-start justify-between mb-3">
        <div>
          <div className="flex items-center gap-2">
            <h3 className="font-bold text-white text-lg group-hover:text-green-400 transition-colors">
              {name}
            </h3>
            {has_pr && (
              <span className="text-xs bg-yellow-500/20 text-yellow-400 border border-yellow-500/30 px-2 py-0.5 rounded-full font-semibold">
                PR
              </span>
            )}
          </div>
          <p className="text-sm text-gray-500 mt-0.5">{formattedDate}</p>
        </div>
        <div className="text-right">
          <p className="text-sm font-semibold text-gray-300">{duration_minutes}m</p>
          <p className="text-xs text-gray-500">duration</p>
        </div>
      </div>

      <div className="flex items-center gap-4 pt-3 border-t border-gray-800">
        <div className="flex flex-col">
          <span className="text-base font-bold text-white">{exercise_count}</span>
          <span className="text-xs text-gray-500">exercises</span>
        </div>
        <div className="w-px h-8 bg-gray-800" />
        <div className="flex flex-col">
          <span className="text-base font-bold text-white">{total_sets}</span>
          <span className="text-xs text-gray-500">sets</span>
        </div>
        {total_volume_lbs != null && (
          <>
            <div className="w-px h-8 bg-gray-800" />
            <div className="flex flex-col">
              <span className="text-base font-bold text-white">
                {total_volume_lbs.toLocaleString()}
              </span>
              <span className="text-xs text-gray-500">lbs vol</span>
            </div>
          </>
        )}
      </div>
    </div>
  )

  return href ? <Link href={href}>{content}</Link> : <div>{content}</div>
}
