'use client'

import { useState } from 'react'
import Navigation from '@/components/Navigation'
import WorkoutCard from '@/components/WorkoutCard'

const allWorkouts = [
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
  {
    id: '4',
    name: 'Upper Body Push',
    date: '2026-02-20',
    duration_minutes: 58,
    exercise_count: 5,
    total_sets: 17,
    total_volume_lbs: 8100,
    has_pr: false,
  },
  {
    id: '5',
    name: 'Lower Body',
    date: '2026-02-18',
    duration_minutes: 80,
    exercise_count: 7,
    total_sets: 24,
    total_volume_lbs: 15800,
    has_pr: true,
  },
  {
    id: '6',
    name: 'Pull Day',
    date: '2026-02-16',
    duration_minutes: 50,
    exercise_count: 4,
    total_sets: 14,
    total_volume_lbs: 6200,
    has_pr: false,
  },
]

export default function WorkoutsPage() {
  const [search, setSearch] = useState('')

  const filtered = allWorkouts.filter(w =>
    w.name.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="min-h-screen bg-black">
      <Navigation />

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-16">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-4xl font-black text-white">Workouts</h1>
            <p className="text-gray-400 mt-1">{allWorkouts.length} sessions logged</p>
          </div>
          <a
            href="https://apps.apple.com/app/xomfit"
            className="flex items-center gap-2 bg-green-500 hover:bg-green-400 text-black font-bold px-4 py-2.5 rounded-xl transition-colors text-sm"
          >
            <span>📱</span>
            Log on iOS
          </a>
        </div>

        {/* Search */}
        <div className="relative mb-6">
          <svg
            className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="text"
            placeholder="Search workouts..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full bg-gray-900 border border-gray-700 rounded-xl pl-10 pr-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-green-500/50 text-sm"
          />
          {search && (
            <button
              onClick={() => setSearch('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300"
            >
              ✕
            </button>
          )}
        </div>

        {/* Results */}
        {filtered.length === 0 ? (
          <div className="text-center py-20 text-gray-500">
            <p className="text-4xl mb-4">🔍</p>
            <p className="text-lg font-semibold">No workouts found</p>
            <p className="text-sm mt-1">Try a different search term</p>
          </div>
        ) : (
          <div className="space-y-4">
            {filtered.map(workout => (
              <WorkoutCard
                key={workout.id}
                {...workout}
                href={`/workouts/${workout.id}`}
              />
            ))}
          </div>
        )}
      </main>
    </div>
  )
}
