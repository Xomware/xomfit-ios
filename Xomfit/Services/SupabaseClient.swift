import Foundation
import Supabase

/// True when the process is running without real Supabase credentials on
/// purpose: the unit-test host, or a Debug launch under `XOMFIT_AUTH_BYPASS=1`
/// (the agent screenshot harness).
///
/// The bypass case matters because `validateSupabaseConfig` *fatal-errors*
/// rather than throwing, so a service that reached the network took the whole
/// app down on launch — `do/catch` around the call site cannot rescue an
/// assertion. Services already fall back to their local cache when a fetch
/// fails, so handing them a placeholder client degrades gracefully instead.
private var isUnconfiguredByDesign: Bool {
    if NSClassFromString("XCTestCase") != nil { return true }
    #if DEBUG
    if ProcessInfo.processInfo.environment["XOMFIT_AUTH_BYPASS"] == "1" { return true }
    #endif
    return false
}

// Validate configuration before initializing client
private func validateSupabaseConfig() {
    // Skip the hard stop when config is absent by design, so the test bundle
    // and the bypass harness can both load. Real Debug/Release launches still
    // fatal-error on misconfig.
    if isUnconfiguredByDesign { return }

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

    // Without real config, use a syntactically valid placeholder URL/key —
    // the SDK initializer rejects a bogus URL. Tests never make network calls
    // against this client, and the bypass harness's requests simply fail and
    // fall through to each service's cache path.
    if isUnconfiguredByDesign {
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
