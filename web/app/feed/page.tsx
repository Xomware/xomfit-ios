import Navigation from '@/components/Navigation'
import Link from 'next/link'

interface FeedWorkout {
  id: string
  user: {
    username: string
    display_name: string
    avatar_initial: string
    avatar_color: string
  }
  workout_name: string
  date: string
  duration_minutes: number
  exercise_count: number
  total_sets: number
  total_volume_lbs: number
  is_pr: boolean
  pr_exercise?: string
  pr_weight?: number
  ago: string
}

const feedItems: FeedWorkout[] = [
  {
    id: 'f1',
    user: { username: 'mikejohnson', display_name: 'Mike Johnson', avatar_initial: 'M', avatar_color: 'bg-blue-500/20 text-blue-400 border-blue-500/30' },
    workout_name: 'Heavy Leg Day',
    date: '2026-02-28',
    duration_minutes: 85,
    exercise_count: 6,
    total_sets: 24,
    total_volume_lbs: 16800,
    is_pr: true,
    pr_exercise: 'Squat',
    pr_weight: 340,
    ago: '2h ago',
  },
  {
    id: 'f2',
    user: { username: 'sarafit', display_name: 'Sara C.', avatar_initial: 'S', avatar_color: 'bg-pink-500/20 text-pink-400 border-pink-500/30' },
    workout_name: 'Upper Body Strength',
    date: '2026-02-28',
    duration_minutes: 60,
    exercise_count: 5,
    total_sets: 18,
    total_volume_lbs: 6200,
    is_pr: false,
    ago: '3h ago',
  },
  {
    id: 'f3',
    user: { username: 'alexpower', display_name: 'Alex P.', avatar_initial: 'A', avatar_color: 'bg-orange-500/20 text-orange-400 border-orange-500/30' },
    workout_name: 'Pull Day',
    date: '2026-02-27',
    duration_minutes: 55,
    exercise_count: 5,
    total_sets: 16,
    total_volume_lbs: 7800,
    is_pr: true,
    pr_exercise: 'Pull-up (weighted)',
    pr_weight: 45,
    ago: '1d ago',
  },
  {
    id: 'f4',
    user: { username: 'jameslifts', display_name: 'James T.', avatar_initial: 'J', avatar_color: 'bg-purple-500/20 text-purple-400 border-purple-500/30' },
    workout_name: 'Push Day',
    date: '2026-02-27',
    duration_minutes: 70,
    exercise_count: 6,
    total_sets: 20,
    total_volume_lbs: 9400,
    is_pr: false,
    ago: '1d ago',
  },
  {
    id: 'f5',
    user: { username: 'ellenjones', display_name: 'Ellen J.', avatar_initial: 'E', avatar_color: 'bg-teal-500/20 text-teal-400 border-teal-500/30' },
    workout_name: 'Deadlift Focused',
    date: '2026-02-26',
    duration_minutes: 75,
    exercise_count: 4,
    total_sets: 15,
    total_volume_lbs: 18500,
    is_pr: true,
    pr_exercise: 'Deadlift',
    pr_weight: 365,
    ago: '2d ago',
  },
]

function FeedCard({ item }: { item: FeedWorkout }) {
  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 hover:border-gray-700 transition-colors">
      {/* User header */}
      <div className="flex items-center gap-3 mb-4">
        <div className={`w-10 h-10 rounded-full border flex items-center justify-center font-bold text-sm flex-shrink-0 ${item.user.avatar_color}`}>
          {item.user.avatar_initial}
        </div>
        <div className="flex-1 min-w-0">
          <Link
            href={`/profile/${item.user.username}`}
            className="font-semibold text-white hover:text-green-400 transition-colors text-sm"
          >
            {item.user.display_name}
          </Link>
          <p className="text-gray-500 text-xs">@{item.user.username} · {item.ago}</p>
        </div>
        {item.is_pr && (
          <span className="text-xs bg-yellow-500/20 text-yellow-400 border border-yellow-500/30 px-2 py-1 rounded-full font-semibold flex-shrink-0">
            🏆 PR
          </span>
        )}
      </div>

      {/* Workout info */}
      <Link href={`/workouts/${item.id}`} className="block group">
        <h3 className="font-bold text-white group-hover:text-green-400 transition-colors mb-1">
          {item.workout_name}
        </h3>

        {item.is_pr && item.pr_exercise && (
          <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg px-3 py-2 mb-3 inline-flex items-center gap-2">
            <span className="text-yellow-400 text-sm">🏆</span>
            <span className="text-yellow-300 text-sm font-semibold">
              New PR: {item.pr_exercise} — {item.pr_weight} lbs
            </span>
          </div>
        )}

        <div className="flex items-center gap-4 text-sm">
          <span className="text-gray-400">
            <span className="font-semibold text-white">{item.duration_minutes}m</span>
          </span>
          <span className="text-gray-600">·</span>
          <span className="text-gray-400">
            <span className="font-semibold text-white">{item.exercise_count}</span> exercises
          </span>
          <span className="text-gray-600">·</span>
          <span className="text-gray-400">
            <span className="font-semibold text-white">{item.total_sets}</span> sets
          </span>
          <span className="text-gray-600">·</span>
          <span className="text-gray-400">
            <span className="font-semibold text-green-400">{item.total_volume_lbs.toLocaleString()}</span> lbs
          </span>
        </div>
      </Link>
    </div>
  )
}

export default function FeedPage() {
  return (
    <div className="min-h-screen bg-black">
      <Navigation />

      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-16">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-4xl font-black text-white">Feed</h1>
            <p className="text-gray-400 mt-1">What your crew is lifting</p>
          </div>
        </div>

        {/* Filter tabs */}
        <div className="flex gap-2 mb-6">
          <button className="px-4 py-2 rounded-lg bg-green-500/15 text-green-400 border border-green-500/30 text-sm font-medium">
            All
          </button>
          <button className="px-4 py-2 rounded-lg text-gray-400 hover:bg-gray-800 hover:text-white border border-transparent text-sm font-medium transition-colors">
            PRs Only
          </button>
          <button className="px-4 py-2 rounded-lg text-gray-400 hover:bg-gray-800 hover:text-white border border-transparent text-sm font-medium transition-colors">
            Following
          </button>
        </div>

        {/* Feed items */}
        <div className="space-y-4">
          {feedItems.map(item => (
            <FeedCard key={item.id} item={item} />
          ))}
        </div>

        {/* Load more */}
        <div className="mt-8 text-center">
          <button className="text-gray-500 hover:text-gray-300 text-sm transition-colors border border-gray-800 rounded-xl px-6 py-3 hover:border-gray-600">
            Load more
          </button>
        </div>
      </main>
    </div>
  )
}
