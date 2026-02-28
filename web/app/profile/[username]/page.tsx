import Navigation from '@/components/Navigation'
import WorkoutCard from '@/components/WorkoutCard'
import PRBadge from '@/components/PRBadge'
import StatCard from '@/components/StatCard'

// Mock data
const mockProfile = {
  username: 'domgiordano',
  display_name: 'Dom Giordano',
  avatar_url: null as string | null,
  bio: 'Lifting since 2019. PPL split. Goal: 315 bench by EOY 💪',
  joined_at: '2024-01-15',
  total_workouts: 312,
  total_volume_lbs: 2450000,
  prs: [
    { exercise_name: 'Bench Press', weight_lbs: 255, reps: 1, date: '2026-02-27' },
    { exercise_name: 'Squat', weight_lbs: 315, reps: 2, date: '2026-02-18' },
    { exercise_name: 'Deadlift', weight_lbs: 405, reps: 1, date: '2026-01-30' },
    { exercise_name: 'Overhead Press', weight_lbs: 155, reps: 3, date: '2026-02-10' },
  ],
}

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

interface ProfilePageProps {
  params: Promise<{ username: string }>
}

export default async function ProfilePage({ params }: ProfilePageProps) {
  const { username } = await params
  const profile = { ...mockProfile, username }

  const joinDate = new Date(profile.joined_at).toLocaleDateString('en-US', {
    month: 'long',
    year: 'numeric',
  })

  return (
    <div className="min-h-screen bg-black">
      <Navigation />

      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-16">
        {/* Profile header */}
        <div className="flex flex-col sm:flex-row items-start gap-6 mb-10">
          {/* Avatar */}
          <div className="flex-shrink-0">
            {profile.avatar_url ? (
              <img
                src={profile.avatar_url}
                alt={profile.display_name}
                className="w-24 h-24 rounded-2xl border-2 border-gray-700"
              />
            ) : (
              <div className="w-24 h-24 rounded-2xl bg-gradient-to-br from-green-500/30 to-emerald-500/10 border-2 border-green-500/30 flex items-center justify-center">
                <span className="text-green-400 font-black text-4xl">
                  {profile.display_name[0].toUpperCase()}
                </span>
              </div>
            )}
          </div>

          <div className="flex-1 min-w-0">
            <h1 className="text-3xl font-black text-white">{profile.display_name}</h1>
            <p className="text-gray-500 text-sm">@{profile.username}</p>
            {profile.bio && (
              <p className="text-gray-300 mt-2 text-sm leading-relaxed max-w-lg">{profile.bio}</p>
            )}
            <p className="text-gray-600 text-xs mt-2">Member since {joinDate}</p>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-10">
          <StatCard label="Total Workouts" value={profile.total_workouts} icon="🏋️" accent="green" />
          <StatCard
            label="Total Volume"
            value={(profile.total_volume_lbs / 1000).toFixed(0) + 'K'}
            unit="lbs"
            icon="📊"
            accent="blue"
          />
          <StatCard label="PRs Achieved" value={profile.prs.length} icon="🏆" accent="yellow" />
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {/* Workout history */}
          <div className="md:col-span-2">
            <h2 className="text-xl font-bold text-white mb-5">Recent Workouts</h2>
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

          {/* PRs */}
          <div>
            <h2 className="text-xl font-bold text-white mb-5">Personal Records</h2>
            <div className="space-y-3">
              {profile.prs.map(pr => (
                <PRBadge key={pr.exercise_name} {...pr} size="md" />
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
