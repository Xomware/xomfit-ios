import Navigation from '@/components/Navigation'
import PRBadge from '@/components/PRBadge'
import Link from 'next/link'

// Mock data
const mockWorkoutDetail = {
  id: '1',
  name: 'Upper Body Push',
  date: '2026-02-27',
  duration_minutes: 62,
  notes: 'Great session. Hit a new bench PR! Shoulders felt a little tight on OHP.',
  exercises: [
    {
      name: 'Bench Press',
      sets: [
        { set_number: 1, reps: 5, weight_lbs: 205, is_pr: false },
        { set_number: 2, reps: 5, weight_lbs: 225, is_pr: false },
        { set_number: 3, reps: 5, weight_lbs: 245, is_pr: false },
        { set_number: 4, reps: 1, weight_lbs: 255, is_pr: true },
      ],
    },
    {
      name: 'Incline Dumbbell Press',
      sets: [
        { set_number: 1, reps: 10, weight_lbs: 70, is_pr: false },
        { set_number: 2, reps: 9, weight_lbs: 70, is_pr: false },
        { set_number: 3, reps: 8, weight_lbs: 70, is_pr: false },
      ],
    },
    {
      name: 'Overhead Press',
      sets: [
        { set_number: 1, reps: 5, weight_lbs: 135, is_pr: false },
        { set_number: 2, reps: 5, weight_lbs: 145, is_pr: false },
        { set_number: 3, reps: 4, weight_lbs: 150, is_pr: false },
      ],
    },
    {
      name: 'Cable Lateral Raise',
      sets: [
        { set_number: 1, reps: 15, weight_lbs: 25, is_pr: false },
        { set_number: 2, reps: 15, weight_lbs: 25, is_pr: false },
        { set_number: 3, reps: 12, weight_lbs: 30, is_pr: false },
      ],
    },
    {
      name: 'Tricep Pushdown',
      sets: [
        { set_number: 1, reps: 12, weight_lbs: 60, is_pr: false },
        { set_number: 2, reps: 12, weight_lbs: 65, is_pr: false },
        { set_number: 3, reps: 10, weight_lbs: 70, is_pr: false },
      ],
    },
  ],
}

interface WorkoutDetailPageProps {
  params: Promise<{ id: string }>
}

export default async function WorkoutDetailPage({ params }: WorkoutDetailPageProps) {
  const { id } = await params
  const workout = { ...mockWorkoutDetail, id }

  const formattedDate = new Date(workout.date).toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  })

  // Compute total volume
  const totalVolume = workout.exercises.reduce((total, ex) => {
    return total + ex.sets.reduce((s, set) => s + set.reps * set.weight_lbs, 0)
  }, 0)

  const prSets = workout.exercises
    .flatMap(ex =>
      ex.sets
        .filter(s => s.is_pr)
        .map(s => ({ exercise_name: ex.name, ...s, date: workout.date }))
    )

  return (
    <div className="min-h-screen bg-black">
      <Navigation />

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-16">
        {/* Back */}
        <Link
          href="/workouts"
          className="inline-flex items-center gap-1 text-gray-500 hover:text-gray-300 text-sm mb-6 transition-colors"
        >
          ← Back to Workouts
        </Link>

        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-black text-white">{workout.name}</h1>
          <p className="text-gray-400 mt-1">{formattedDate}</p>

          <div className="flex items-center gap-6 mt-4">
            <div className="text-center">
              <p className="text-2xl font-black text-white">{workout.duration_minutes}m</p>
              <p className="text-gray-500 text-xs">duration</p>
            </div>
            <div className="w-px h-10 bg-gray-800" />
            <div className="text-center">
              <p className="text-2xl font-black text-white">{workout.exercises.length}</p>
              <p className="text-gray-500 text-xs">exercises</p>
            </div>
            <div className="w-px h-10 bg-gray-800" />
            <div className="text-center">
              <p className="text-2xl font-black text-white">
                {workout.exercises.reduce((t, ex) => t + ex.sets.length, 0)}
              </p>
              <p className="text-gray-500 text-xs">sets</p>
            </div>
            <div className="w-px h-10 bg-gray-800" />
            <div className="text-center">
              <p className="text-2xl font-black text-green-400">{totalVolume.toLocaleString()}</p>
              <p className="text-gray-500 text-xs">lbs total</p>
            </div>
          </div>
        </div>

        {/* PRs */}
        {prSets.length > 0 && (
          <div className="mb-8">
            <h2 className="text-lg font-bold text-white mb-3">🏆 PRs This Session</h2>
            <div className="grid sm:grid-cols-2 gap-3">
              {prSets.map(pr => (
                <PRBadge
                  key={`${pr.exercise_name}-${pr.set_number}`}
                  exercise_name={pr.exercise_name}
                  weight_lbs={pr.weight_lbs}
                  reps={pr.reps}
                  date={pr.date}
                  size="lg"
                />
              ))}
            </div>
          </div>
        )}

        {/* Notes */}
        {workout.notes && (
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4 mb-8">
            <p className="text-gray-500 text-xs font-semibold uppercase tracking-wider mb-2">Notes</p>
            <p className="text-gray-300 text-sm leading-relaxed">{workout.notes}</p>
          </div>
        )}

        {/* Exercises */}
        <div className="space-y-6">
          <h2 className="text-xl font-bold text-white">Exercises</h2>
          {workout.exercises.map((exercise, i) => (
            <div key={i} className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
              <div className="px-5 py-4 border-b border-gray-800 flex items-center justify-between">
                <h3 className="font-bold text-white">{exercise.name}</h3>
                <span className="text-gray-500 text-sm">{exercise.sets.length} sets</span>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="text-left">
                      <th className="px-5 py-3 text-gray-500 text-xs font-semibold uppercase tracking-wider">Set</th>
                      <th className="px-5 py-3 text-gray-500 text-xs font-semibold uppercase tracking-wider">Weight</th>
                      <th className="px-5 py-3 text-gray-500 text-xs font-semibold uppercase tracking-wider">Reps</th>
                      <th className="px-5 py-3 text-gray-500 text-xs font-semibold uppercase tracking-wider">Volume</th>
                      <th className="px-5 py-3 text-gray-500 text-xs font-semibold uppercase tracking-wider"></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-800">
                    {exercise.sets.map(set => (
                      <tr
                        key={set.set_number}
                        className={set.is_pr ? 'bg-yellow-500/5' : 'hover:bg-gray-800/50'}
                      >
                        <td className="px-5 py-3 text-gray-400 text-sm font-medium">
                          {set.set_number}
                        </td>
                        <td className="px-5 py-3 text-white font-bold">
                          {set.weight_lbs} lbs
                        </td>
                        <td className="px-5 py-3 text-white font-bold">{set.reps}</td>
                        <td className="px-5 py-3 text-gray-400 text-sm">
                          {(set.reps * set.weight_lbs).toLocaleString()} lbs
                        </td>
                        <td className="px-5 py-3">
                          {set.is_pr && (
                            <span className="text-xs bg-yellow-500/20 text-yellow-400 border border-yellow-500/30 px-2 py-0.5 rounded-full font-semibold">
                              PR
                            </span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot>
                    <tr className="border-t border-gray-700">
                      <td colSpan={3} className="px-5 py-3 text-gray-500 text-xs">Total</td>
                      <td className="px-5 py-3 text-green-400 text-sm font-bold">
                        {exercise.sets
                          .reduce((t, s) => t + s.reps * s.weight_lbs, 0)
                          .toLocaleString()}{' '}
                        lbs
                      </td>
                      <td />
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}
