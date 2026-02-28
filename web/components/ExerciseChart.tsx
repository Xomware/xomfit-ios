'use client'

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts'

interface DataPoint {
  date: string
  weight: number
  reps?: number
}

interface ExerciseChartProps {
  exerciseName: string
  data: DataPoint[]
  color?: string
}

const CustomTooltip = ({ active, payload, label }: { active?: boolean; payload?: Array<{ value: number; payload: DataPoint }>; label?: string }) => {
  if (active && payload && payload.length) {
    const d = payload[0].payload
    return (
      <div className="bg-gray-900 border border-gray-700 rounded-lg p-3 shadow-xl">
        <p className="text-gray-400 text-xs mb-1">{label}</p>
        <p className="text-white font-bold text-sm">{d.weight} lbs</p>
        {d.reps && <p className="text-gray-400 text-xs">{d.reps} reps</p>}
      </div>
    )
  }
  return null
}

export default function ExerciseChart({
  exerciseName,
  data,
  color = '#22c55e',
}: ExerciseChartProps) {
  if (!data || data.length === 0) {
    return (
      <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
        <h3 className="font-bold text-white mb-4">{exerciseName}</h3>
        <div className="h-32 flex items-center justify-center text-gray-500 text-sm">
          No data yet
        </div>
      </div>
    )
  }

  const maxWeight = Math.max(...data.map(d => d.weight))
  const minWeight = Math.min(...data.map(d => d.weight))

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-bold text-white">{exerciseName}</h3>
        <div className="text-right">
          <p className="text-green-400 font-bold text-sm">{maxWeight} lbs</p>
          <p className="text-gray-500 text-xs">max</p>
        </div>
      </div>

      <ResponsiveContainer width="100%" height={160}>
        <LineChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#1f2937" />
          <XAxis
            dataKey="date"
            tick={{ fill: '#6b7280', fontSize: 10 }}
            axisLine={false}
            tickLine={false}
          />
          <YAxis
            domain={[Math.max(0, minWeight - 20), maxWeight + 20]}
            tick={{ fill: '#6b7280', fontSize: 10 }}
            axisLine={false}
            tickLine={false}
          />
          <Tooltip content={<CustomTooltip />} />
          <Line
            type="monotone"
            dataKey="weight"
            stroke={color}
            strokeWidth={2.5}
            dot={{ fill: color, strokeWidth: 0, r: 4 }}
            activeDot={{ fill: color, strokeWidth: 2, stroke: '#000', r: 6 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
