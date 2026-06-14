import Foundation
import Supabase

// Validate configuration before initializing client
private func validateSupabaseConfig() {
    // The unit-test host launches without injected Supabase config. Skip the
    // hard stop under XCTest so the test bundle can load; tests never hit the
    // network. Production/Debug app launches still fatal-error on misconfig.
    if NSClassFromString("XCTestCase") != nil { return }

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

    // Under XCTest the real config is absent, so use a syntactically valid
    // placeholder URL/key — the SDK initializer rejects a bogus URL. Tests
    // never make network calls against this client.
    if NSClassFromString("XCTestCase") != nil {
        return SupabaseClient(
            supabaseURL: URL(string: "https://placeholder.supabase.co")!,
            supabaseKey: "test-anon-key"
        )
    }

    return SupabaseClient(
        supabaseURL: URL(string: Config.supabaseURL)!,
        supabaseKey: Config.supabaseAnonKey
    )
}()
