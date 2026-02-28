import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Types for XomFit data
export interface Workout {
  id: string
  user_id: string
  name: string
  date: string
  duration_minutes: number
  notes?: string
  sets: WorkoutSet[]
  created_at: string
}

export interface WorkoutSet {
  id: string
  workout_id: string
  exercise_name: string
  sets: SetDetail[]
}

export interface SetDetail {
  set_number: number
  reps: number
  weight_lbs: number
  is_pr?: boolean
}

export interface UserProfile {
  id: string
  username: string
  display_name: string
  avatar_url?: string
  bio?: string
  joined_at: string
  total_workouts: number
  total_volume_lbs: number
  prs: PersonalRecord[]
}

export interface PersonalRecord {
  exercise_name: string
  weight_lbs: number
  reps: number
  date: string
}

export interface FeedItem {
  id: string
  user: UserProfile
  workout: Workout
  is_pr: boolean
  pr_exercise?: string
  pr_weight?: number
  created_at: string
}

// Auth helpers
export async function signInWithGoogle() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${typeof window !== 'undefined' ? window.location.origin : ''}/dashboard`,
    },
  })
  return { error }
}

export async function signInWithEmail(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  return { data, error }
}

export async function signUpWithEmail(email: string, password: string) {
  const { data, error } = await supabase.auth.signUp({ email, password })
  return { data, error }
}

export async function signOut() {
  const { error } = await supabase.auth.signOut()
  return { error }
}

export async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser()
  return user
}
