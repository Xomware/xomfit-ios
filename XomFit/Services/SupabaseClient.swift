import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey
)
