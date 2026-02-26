import Foundation

enum Config {
    // MARK: - Supabase Configuration
    // Get these values from your Supabase project dashboard:
    // Settings > API > Project URL and Anon Key
    static let supabaseURL = "YOUR_SUPABASE_URL"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
    
    // MARK: - OAuth Configuration
    // Custom URL scheme for OAuth redirects
    static let oauthScheme = "xomfit"
    
    // MARK: - App Configuration
    static let appName = "XomFit"
    static let bundleIdentifier = "com.xomware.xomfit"
    
    // MARK: - Validation
    static var isConfigured: Bool {
        return !supabaseURL.contains("YOUR_") && !supabaseAnonKey.contains("YOUR_")
    }
}
