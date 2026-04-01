#!/bin/sh
# Xcode Cloud post-clone script

cd "$CI_PRIMARY_REPOSITORY_PATH"
PBXPROJ="Xomfit.xcodeproj/project.pbxproj"

# 1. Build number — Xcode Cloud auto-increments CI_BUILD_NUMBER
# Use sed to sync across all targets (app + widget must match)
if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "Setting build number to $CI_BUILD_NUMBER for all targets"
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/g" "$PBXPROJ"
fi

# 2. Marketing version — auto-increment patch version based on build number
# Format: MAJOR.MINOR.BUILD (e.g., 1.0.7, 1.0.8, 1.0.9...)
# Set MAJOR and MINOR via env vars, patch auto-increments
MAJOR="${APP_VERSION_MAJOR:-1}"
MINOR="${APP_VERSION_MINOR:-0}"
PATCH="${CI_BUILD_NUMBER:-0}"
MARKETING_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "Setting marketing version to $MARKETING_VERSION for all targets"
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $MARKETING_VERSION/g" "$PBXPROJ"

# 3. Generate Config.swift from environment variables
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

echo "Config.swift generated"
