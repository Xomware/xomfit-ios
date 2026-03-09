# XomFit iOS — Setup Guide

> **Last Updated:** March 9, 2026
> **Repo:** `Xomware/xomfit-ios`

---

## Quick-Start Checklist

Use this to track your progress. Every step links to details below.

- [ ] [Prerequisites installed](#1-prerequisites) (Xcode 16.2+, Apple Dev account, Supabase account)
- [ ] [Repo cloned, Xcode project open](#2-clone--open-the-project)
- [ ] [Swift packages added](#3-add-swift-package-dependencies)
- [ ] [Xcode capabilities configured](#4-configure-xcode-project)
- [ ] [Supabase project created, credentials saved](#5-create-a-supabase-project)
- [ ] [Database migrations run](#6-run-database-migrations)
- [ ] [Config.swift filled in](#7-configure-the-app)
- [ ] [Apple Sign In set up](#8-set-up-apple-sign-in) (Apple Developer Portal + Supabase)
- [ ] [Google Sign In set up](#9-set-up-google-sign-in) (Google Cloud Console + Supabase)
- [ ] [Auth providers enabled in Supabase](#10-configure-supabase-auth-providers)
- [ ] [Build & run, test auth flows](#11-build--run)

---

## 1. Prerequisites

| Tool | Version | How to Check | How to Install |
|------|---------|-------------|----------------|
| **macOS** | 14.0+ (Sonoma) | Apple menu > About This Mac | System Settings |
| **Xcode** | 16.2+ | `xcodebuild -version` | Mac App Store |
| **Apple Developer Account** | Paid ($99/yr) | [developer.apple.com/account](https://developer.apple.com/account) | Required for Sign In with Apple |
| **Supabase Account** | Free tier works | [supabase.com](https://supabase.com) | Sign up with GitHub |
| **Supabase CLI** (optional) | 1.x+ | `supabase --version` | `brew install supabase/tap/supabase` |

---

## 2. Clone & Open the Project

```bash
git clone https://github.com/Xomware/xomfit-ios.git
cd xomfit-ios
open XomFit.xcodeproj
```

### Project Structure

```
xomfit-ios/
├── XomFit/
│   ├── XomFitApp.swift          # App entry point
│   ├── Config.swift             # YOUR CREDENTIALS GO HERE
│   ├── Models/                  # Data models (Codable structs)
│   ├── Views/                   # SwiftUI views (Auth, Feed, Workout, etc.)
│   ├── ViewModels/              # 20+ ViewModels (MVVM)
│   ├── Services/                # Supabase, Auth, API services
│   └── Utils/                   # Theme, extensions
├── XomFitWatch/                 # Apple Watch companion app
├── supabase/migrations/         # 7 SQL migration files
├── .github/workflows/ci.yml     # GitHub Actions CI
└── docs/
    ├── SETUP.md                 # This file
    └── FEATURES.md              # Feature reference
```

---

## 3. Add Swift Package Dependencies

The app has **one** third-party dependency: the Supabase Swift SDK.

In Xcode: **File > Add Package Dependencies...**

| Package | URL | Version | What It Provides |
|---------|-----|---------|-----------------|
| **supabase-swift** | `https://github.com/supabase/supabase-swift` | **2.x** or later | Auth, Database, Storage, Realtime |

When prompted, add to the **XomFit** target.

After adding, Xcode resolves these modules (all from the single package above):
- `Supabase` — main import used throughout the app
- `Auth` — authentication (Apple, Google, Email)
- `PostgREST` — database queries
- `Realtime` — WebSocket subscriptions
- `Storage` — file uploads (progress photos, form check videos)

**No other SPM packages are needed.** Everything else uses Apple frameworks:
- `SwiftUI`, `Foundation`, `Combine` — UI and data
- `AuthenticationServices` — native Apple Sign In
- `AVFoundation`, `Vision` — video recording and analysis
- `CoreLocation` — gym check-in
- `HealthKit` — Apple Health integration
- `WatchConnectivity`, `WidgetKit` — Apple Watch
- `UserNotifications` — push notifications
- `PhotosUI` — photo picker

---

## 4. Configure Xcode Project

### 4.1 — Signing & Capabilities

Select the **XomFit** target > **Signing & Capabilities** tab > **+ Capability**:

| Capability | Why |
|-----------|-----|
| **Sign in with Apple** | Required for Apple Sign In |
| **Keychain Sharing** | Persists auth sessions across app launches |
| **HealthKit** | Apple Health sync (optional — skip if not using) |

### 4.2 — URL Scheme (for OAuth redirects)

Select the **XomFit** target > **Info** tab > **URL Types** > click **+**:

| Field | Value |
|-------|-------|
| **Identifier** | `com.xomware.xomfit` |
| **URL Schemes** | `xomfit` |
| **Role** | Editor |

This registers `xomfit://` so OAuth can redirect back to the app.

### 4.3 — Bundle Identifier

Make sure **Bundle Identifier** is `com.xomware.xomfit` (or your own — just keep it consistent across Apple Developer Portal and Supabase config).

### 4.4 — Deployment Target

Minimum iOS **17.0**.

---

## 5. Create a Supabase Project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) > **New Project**
2. **Name:** `xomfit`, **Region:** closest to you, **Password:** save it securely
3. Wait for provisioning (~1-2 min)
4. Go to **Settings > API** and copy:
   - **Project URL** — `https://YOURREF.supabase.co`
   - **anon (public) key** — starts with `eyJ...`
5. Your **Project Ref** is the subdomain (e.g., `YOURREF` from the URL above)

---

## 6. Run Database Migrations

All migrations are in `supabase/migrations/`. Run them **in filename order**.

### Option A — Dashboard (easiest)

Go to **SQL Editor** > **New Query** > paste each file > **Run**:

```
1. 20260228_body_composition.sql
2. 20260228_form_check_videos.sql
3. 20260228_gym_checkins.sql
4. 20260228_push_notifications.sql
5. 20260228_workout_marketplace.sql
6. 20260301_add_nutrition.sql
7. 20260306_social_feed.sql
```

### Option B — Supabase CLI

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

### Verify

**Table Editor** should show: `body_compositions`, `form_check_videos`, `gym_checkins`, `daily_nutrition`, `social_feed_items`, `social_feed_comments`, `social_feed_likes`, etc.

---

## 7. Configure the App

Open `XomFit/Config.swift` and replace placeholders:

```swift
enum Config {
    static let supabaseURL = "https://YOUR_PROJECT_REF.supabase.co"  // from Step 5
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIs..."          // from Step 5

    // Leave these as-is:
    static let oauthScheme = "xomfit"
    static let oauthCallbackURL = "xomfit://login-callback"
}
```

**Do not commit real keys.** Make sure `XomFit/Config.swift` is in `.gitignore`:

```bash
echo "XomFit/Config.swift" >> .gitignore
```

---

## 8. Set Up Apple Sign In

Three places: Apple Developer Portal, Xcode (done in Step 4), and Supabase (Step 10).

### 8.1 — Create App ID

1. [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list) > **+**
2. **App IDs** > **App** > Continue
3. **Description:** `XomFit`, **Bundle ID:** `com.xomware.xomfit` (Explicit)
4. Enable **Sign In with Apple** capability
5. **Continue** > **Register**

### 8.2 — Create Service ID (for Supabase)

1. Back to Identifiers > **+** > **Services IDs** > Continue
2. **Description:** `XomFit Auth`, **Identifier:** `com.xomware.xomfit.auth`
3. **Continue** > **Register**
4. Click the Service ID > enable **Sign In with Apple** > **Configure**:
   - **Primary App ID:** `com.xomware.xomfit`
   - **Domains:** `YOUR_PROJECT_REF.supabase.co`
   - **Return URLs:** `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
5. **Save**

### 8.3 — Create Auth Key

1. [developer.apple.com/account/resources/authkeys](https://developer.apple.com/account/resources/authkeys/list) > **+**
2. **Key Name:** `XomFit Supabase Auth`
3. Enable **Sign In with Apple** > **Configure** > select `com.xomware.xomfit`
4. **Save** > **Continue** > **Register**
5. **Download the .p8 key file immediately** (one-time download)
6. Note your **Key ID** (10 chars) and **Team ID** (top-right of portal)

---

## 9. Set Up Google Sign In

Google Sign In uses Supabase's OAuth flow — no Google SDK needed in the app.

### 9.1 — Google Cloud Console

1. [console.cloud.google.com](https://console.cloud.google.com) > create project `XomFit`
2. **APIs & Services** > **OAuth consent screen** > **External** > fill in app name + emails > save
3. **Credentials** > **+ Create Credentials** > **OAuth client ID**
4. **Type:** Web application, **Name:** `XomFit Supabase`
5. **Authorized redirect URIs:** `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
6. **Create** > copy **Client ID** and **Client Secret**

---

## 10. Configure Supabase Auth Providers

In your Supabase dashboard > **Authentication** > **Providers**:

### Apple

| Field | Value |
|-------|-------|
| **Client ID (Services ID)** | `com.xomware.xomfit.auth` (from Step 8.2) |
| **Secret Key** | Full contents of .p8 file (including BEGIN/END lines) |
| **Key ID** | 10-char Key ID from Step 8.3 |
| **Team ID** | 10-char Apple Team ID |

### Google

| Field | Value |
|-------|-------|
| **Client ID** | From Step 9.1 |
| **Client Secret** | From Step 9.1 |

### Email

Should be ON by default. Recommended: **Confirm Email** ON, **Min password:** 8.

### Redirect URLs

**Authentication** > **URL Configuration**:
- **Site URL:** `xomfit://login-callback`
- **Redirect URLs:** add `xomfit://login-callback` and `xomfit://**`

---

## 11. Build & Run

1. **Device selector:** iPhone 15 Pro (or any iOS 17+ simulator)
2. **Cmd + B** to build (first build resolves SPM packages, ~2-5 min)
3. **Cmd + R** to run

### Test Auth

| Method | How to Test |
|--------|------------|
| **Email/Password** | Create Account > enter email/username/password > verify email > sign in |
| **Apple Sign In** | Tap button > system sheet > Face ID/passcode > lands on main screen |
| **Google Sign In** | Tap button > web view > sign in with Google > redirects back to app |

---

## Quick Reference — Where Everything Goes

| Value | Where You Get It | Where It Goes |
|-------|-----------------|---------------|
| Supabase Project URL | Supabase > Settings > API | `Config.swift` > `supabaseURL` |
| Supabase Anon Key | Supabase > Settings > API | `Config.swift` > `supabaseAnonKey` |
| Apple Service ID | Apple Developer > Identifiers > Services IDs | Supabase > Auth > Apple > Client ID |
| Apple .p8 Key | Apple Developer > Keys (download once!) | Supabase > Auth > Apple > Secret Key |
| Apple Key ID | Apple Developer > Keys > Key Details | Supabase > Auth > Apple > Key ID |
| Apple Team ID | Apple Developer portal (top-right) | Supabase > Auth > Apple > Team ID |
| Google Client ID | Google Cloud > Credentials > OAuth 2.0 | Supabase > Auth > Google > Client ID |
| Google Client Secret | Google Cloud > Credentials > OAuth 2.0 | Supabase > Auth > Google > Client Secret |

---

## Troubleshooting

### "No such module 'Supabase'"
SPM dependencies not resolved. **File > Packages > Resolve Package Versions** or:
```bash
xcodebuild -resolvePackageDependencies
```

### "Config is not configured"
`Config.swift` still has placeholder values. Replace with real Supabase URL + key.

### Apple Sign In: "invalid_client"
- Service ID in Supabase matches Apple Developer Portal (`com.xomware.xomfit.auth`)
- Return URL includes `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
- `.p8` key pasted in full (including `-----BEGIN/END PRIVATE KEY-----` lines)
- Key ID and Team ID correct

### Google Sign In doesn't complete
- Google OAuth redirect URI matches exactly: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
- Supabase redirect URLs include `xomfit://login-callback`
- URL scheme `xomfit` registered in Xcode
- Google OAuth consent screen published (not stuck in "Testing" mode)

### OAuth opens Safari instead of app
- Verify URL Types in Xcode Info tab
- Test with: `xcrun simctl openurl booted "xomfit://login-callback"`

### Tests fail locally
```bash
xcodebuild test \
  -scheme XomFit \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | xcpretty
```

---

## CI/CD

CI runs automatically on push to `main` and PRs targeting `main` (`.github/workflows/ci.yml`).

Steps: checkout > Xcode 16.2 > resolve packages > build > test.

Gates: compile, tests pass, SwiftLint, no hardcoded secrets.
