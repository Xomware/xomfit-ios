import Navigation from '@/components/Navigation'
import ExerciseChart from '@/components/ExerciseChart'
import StatCard from '@/components/StatCard'

// Mock data
const benchPressData = [
  { date: 'Oct', weight: 185 },
  { date: 'Nov', weight: 205 },
  { date: 'Dec', weight: 215 },
  { date: 'Jan', weight: 225 },
  { date: 'Feb', weight: 245 },
  { date: 'Now', weight: 255 },
]

const squatData = [
  { date: 'Oct', weight: 225 },
  { date: 'Nov', weight: 245 },
  { date: 'Dec', weight: 265 },
  { date: 'Jan', weight: 285 },
  { date: 'Feb', weight: 315 },
  { date: 'Now', weight: 315 },
]

const deadliftData = [
  { date: 'Oct', weight: 315 },
  { date: 'Nov', weight: 335 },
  { date: 'Dec', weight: 355 },
  { date: 'Jan', weight: 385 },
  { date: 'Feb', weight: 405 },
  { date: 'Now', weight: 405 },
]

const ohpData = [
  { date: 'Oct', weight: 115 },
  { date: 'Nov', weight: 125 },
  { date: 'Dec', weight: 135 },
  { date: 'Jan', weight: 145 },
  { date: 'Feb', weight: 155 },
  { date: 'Now', weight: 155 },
]

const monthlyVolume = [
  { date: 'Sep', weight: 58000 },
  { date: 'Oct', weight: 68000 },
  { date: 'Nov', weight: 72000 },
  { date: 'Dec', weight: 65000 },
  { date: 'Jan', weight: 78000 },
  { date: 'Feb', weight: 84200 },
]

export default function AnalyticsPage() {
  return (
    <div className="min-h-screen bg-black">
      <Navigation />

      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-16">
        {/* Header */}
        <div className="mb-10">
          <h1 className="text-4xl font-black text-white">Analytics</h1>
          <p className="text-gray-400 mt-1">Your strength progress over the last 6 months</p>
        </div>

        {/* Top stats */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-10">
          <StatCard
            label="Total Workouts"
            value={312}
            icon="🏋️"
            accent="green"
            trend={{ direction: 'up', value: '+12 this month' }}
          />
          <StatCard
            label="Total Volume"
            value="2.4M"
            unit="lbs"
            icon="📊"
            accent="blue"
            trend={{ direction: 'up', value: '+8% this month' }}
          />
          <StatCard
            label="Best Bench"
            value={255}
            unit="lbs"
            icon="🏆"
            accent="yellow"
          />
          <StatCard
            label="Best Squat"
            value={315}
            unit="lbs"
            icon="🏆"
            accent="yellow"
          />
        </div>

        {/* Monthly volume */}
        <div className="mb-8">
          <h2 className="text-xl font-bold text-white mb-5">Monthly Volume</h2>
          <ExerciseChart
            exerciseName="Total Monthly Volume (lbs)"
            data={monthlyVolume}
            color="#3b82f6"
          />
        </div>

        {/* Big 4 lifts */}
        <div>
          <h2 className="text-xl font-bold text-white mb-5">Big Four — Weight Progression</h2>
          <div className="grid md:grid-cols-2 gap-6">
            <ExerciseChart exerciseName="Bench Press" data={benchPressData} color="#22c55e" />
            <ExerciseChart exerciseName="Squat" data={squatData} color="#a855f7" />
            <ExerciseChart exerciseName="Deadlift" data={deadliftData} color="#ef4444" />
            <ExerciseChart exerciseName="Overhead Press" data={ohpData} color="#f59e0b" />
          </div>
        </div>

        {/* Workout frequency heatmap placeholder */}
        <div className="mt-8 bg-gray-900 border border-gray-800 rounded-xl p-6">
          <h2 className="text-xl font-bold text-white mb-2">Workout Frequency</h2>
          <p className="text-gray-500 text-sm mb-6">Last 12 weeks</p>
          <div className="grid grid-cols-12 gap-1.5">
            {Array.from({ length: 84 }).map((_, i) => {
              // Mock frequency data
              const intensity = Math.random()
              const hasWorkout = intensity > 0.55
              const isHighIntensity = intensity > 0.8
              return (
                <div
                  key={i}
                  className={`aspect-square rounded-sm ${
                    !hasWorkout
                      ? 'bg-gray-800'
                      : isHighIntensity
                      ? 'bg-green-500'
                      : 'bg-green-500/40'
                  }`}
                  title={hasWorkout ? (isHighIntensity ? 'High intensity' : 'Workout') : 'Rest day'}
                />
              )
            })}
          </div>
          <div className="flex items-center gap-3 mt-4 text-xs text-gray-500">
            <span>Less</span>
            <div className="flex gap-1">
              <div className="w-3 h-3 rounded-sm bg-gray-800" />
              <div className="w-3 h-3 rounded-sm bg-green-500/25" />
              <div className="w-3 h-3 rounded-sm bg-green-500/50" />
              <div className="w-3 h-3 rounded-sm bg-green-500" />
            </div>
            <span>More</span>
          </div>
        </div>
      </main>
    </div>
  )
}
