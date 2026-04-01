#!/bin/sh
# Xcode Cloud post-clone script

cd "$CI_PRIMARY_REPOSITORY_PATH"
PBXPROJ="Xomfit.xcodeproj/project.pbxproj"

# 1. Set build number using Xcode Cloud's auto-incrementing CI_BUILD_NUMBER
# Uses sed instead of agvtool (agvtool requires VERSIONING_SYSTEM=apple-generic)
if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "Setting build number to $CI_BUILD_NUMBER for all targets"
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/g" "$PBXPROJ"
fi

# 2. Sync marketing version across all targets (app + widget must match)
if [ -n "$APP_VERSION" ]; then
    echo "Setting marketing version to $APP_VERSION for all targets"
    sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $APP_VERSION/g" "$PBXPROJ"
fi

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
