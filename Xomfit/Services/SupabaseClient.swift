import Foundation
import Supabase

// Validate configuration before initializing client
private func validateSupabaseConfig() {
    guard Config.isConfigured else {
        fatalError("""
        ❌ Supabase configuration is missing!
        
        Please update Config.swift with your actual Supabase project values:
        1. Go to https://supabase.com/dashboard
        2. Select your project  
        3. Go to Settings > API
        4. Copy Project URL and Anon Key to Config.swift
        
        Current values:
        - supabaseURL: \(Config.supabaseURL)
        - supabaseAnonKey: \(Config.supabaseAnonKey)
        """)
    }
    
    guard URL(string: Config.supabaseURL) != nil else {
        fatalError("❌ Invalid Supabase URL: \(Config.supabaseURL)")
    }
}

// Initialize Supabase client with validation
let supabase: SupabaseClient = {
    validateSupabaseConfig()
    
    return SupabaseClient(
        supabaseURL: URL(string: Config.supabaseURL)!,
        supabaseKey: Config.supabaseAnonKey
    )
}()
