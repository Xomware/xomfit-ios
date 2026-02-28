import Navigation from '@/components/Navigation'
import WorkoutCard from '@/components/WorkoutCard'
import StatCard from '@/components/StatCard'
import PRBadge from '@/components/PRBadge'
import Link from 'next/link'

// Mock data — in production, fetch from Supabase
const mockWorkouts = [
  {
    id: '1',
    name: 'Upper Body Push',
    date: '2026-02-27',
    duration_minutes: 62,
    exercise_count: 5,
    total_sets: 18,
    total_volume_lbs: 8450,
    has_pr: true,
  },
  {
    id: '2',
    name: 'Lower Body',
    date: '2026-02-25',
    duration_minutes: 75,
    exercise_count: 6,
    total_sets: 22,
    total_volume_lbs: 14200,
    has_pr: false,
  },
  {
    id: '3',
    name: 'Pull Day',
    date: '2026-02-23',
    duration_minutes: 55,
    exercise_count: 5,
    total_sets: 16,
    total_volume_lbs: 6800,
    has_pr: false,
  },
]

const mockPRs = [
  { exercise_name: 'Bench Press', weight_lbs: 255, reps: 1, date: '2026-02-27' },
  { exercise_name: 'Squat', weight_lbs: 315, reps: 2, date: '2026-02-18' },
]

export default function DashboardPage() {
  const userName = 'Dom' // In production: from Supabase auth session

  return (
    <div className="min-h-screen bg-black">
      <Navigation />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-16">
        {/* Header */}
        <div className="mb-10">
          <p className="text-gray-500 text-sm mb-1">Welcome back 👋</p>
          <h1 className="text-4xl font-black text-white">
            Hey, <span className="text-green-400">{userName}</span>
          </h1>
          <p className="text-gray-400 mt-2">
            You&apos;ve logged <strong className="text-white">12 workouts</strong> this month. Keep it up!
          </p>
        </div>

        {/* Stats grid */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-10">
          <StatCard
            label="Workouts This Month"
            value={12}
            icon="🏋️"
            accent="green"
            trend={{ direction: 'up', value: '+3 vs last month' }}
          />
          <StatCard
            label="Total Volume (lbs)"
            value="84,200"
            icon="📊"
            accent="blue"
            trend={{ direction: 'up', value: '+12% vs last month' }}
          />
          <StatCard
            label="Current Streak"
            value={5}
            unit="days"
            icon="🔥"
            accent="yellow"
          />
          <StatCard
            label="Avg Duration"
            value={64}
            unit="min"
            icon="⏱️"
            accent="green"
            trend={{ direction: 'neutral', value: 'No change' }}
          />
        </div>

        <div className="grid lg:grid-cols-3 gap-8">
          {/* Recent workouts */}
          <div className="lg:col-span-2">
            <div className="flex items-center justify-between mb-5">
              <h2 className="text-xl font-bold text-white">Recent Workouts</h2>
              <Link
                href="/workouts"
                className="text-sm text-green-400 hover:text-green-300 transition-colors font-medium"
              >
                View all →
              </Link>
            </div>
            <div className="space-y-4">
              {mockWorkouts.map(workout => (
                <WorkoutCard
                  key={workout.id}
                  {...workout}
                  href={`/workouts/${workout.id}`}
                />
              ))}
            </div>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* PRs */}
            <div>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-bold text-white">Recent PRs</h2>
                <Link
                  href="/analytics"
                  className="text-sm text-green-400 hover:text-green-300 transition-colors"
                >
                  Analytics →
                </Link>
              </div>
              <div className="space-y-3">
                {mockPRs.map(pr => (
                  <PRBadge key={pr.exercise_name} {...pr} size="md" />
                ))}
              </div>
            </div>

            {/* Quick actions */}
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
              <h3 className="font-bold text-white mb-4">Quick Actions</h3>
              <div className="space-y-2">
                <a
                  href="https://apps.apple.com/app/xomfit"
                  className="flex items-center gap-3 p-3 rounded-lg bg-green-500/10 hover:bg-green-500/20 border border-green-500/20 transition-colors"
                >
                  <span>📱</span>
                  <span className="text-sm text-green-400 font-medium">Log Workout on iOS</span>
                </a>
                <Link
                  href="/feed"
                  className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-800 transition-colors"
                >
                  <span>👥</span>
                  <span className="text-sm text-gray-300">View Social Feed</span>
                </Link>
                <Link
                  href="/analytics"
                  className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-800 transition-colors"
                >
                  <span>📈</span>
                  <span className="text-sm text-gray-300">Progress Analytics</span>
                </Link>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
