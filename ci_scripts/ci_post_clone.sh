#!/bin/sh
# Xcode Cloud post-clone script

# Auto-increment build number
if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "Setting build number to $CI_BUILD_NUMBER"
    cd "$CI_PRIMARY_REPOSITORY_PATH"
    agvtool new-version -all "$CI_BUILD_NUMBER"
fi

# Generate Config.swift from environment variables
CONFIG_PATH="$CI_PRIMARY_REPOSITORY_PATH/Xomfit/Config.swift"
echo "Generating Config.swift..."

cat > "$CONFIG_PATH" << EOF
import Foundation

enum Config {
    static let supabaseURL = "${SUPABASE_URL}"
    static let supabaseAnonKey = "${SUPABASE_ANON_KEY}"

    static let oauthScheme = "xomfit"
    static let oauthCallbackURL = "xomfit://login-callback"

    static let appName = "XomFit"
    static let bundleIdentifier = "com.Xomware.Xomfit"

    enum Validation {
        static let emailPattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}$"
        static let passwordMinLength = 8
        static let passwordRequiresNumber = true
        static let passwordRequiresSpecialChar = false
    }

    static var isConfigured: Bool {
        return !supabaseURL.contains("YOUR_") && !supabaseAnonKey.contains("YOUR_")
    }
}
EOF

echo "Config.swift generated at $CONFIG_PATH"
