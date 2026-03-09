# XomFit iOS — Complete Setup Guide

> **Last Updated:** March 6, 2026
> **Repo:** `Xomware/xomfit-ios`
> **Purpose:** Everything needed to get XomFit running locally, connected to Supabase, with Apple & Google Sign In working end-to-end.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Clone & Open the Project](#2-clone--open-the-project)
3. [Create a Supabase Project](#3-create-a-supabase-project)
4. [Run Database Migrations](#4-run-database-migrations)
5. [Configure the App (Config.swift)](#5-configure-the-app-configswift)
6. [Set Up Apple Sign In](#6-set-up-apple-sign-in)
7. [Set Up Google Sign In](#7-set-up-google-sign-in)
8. [Configure Supabase Auth Providers](#8-configure-supabase-auth-providers)
9. [Configure URL Scheme & Deep Links](#9-configure-url-scheme--deep-links)
10. [Build & Run](#10-build--run)
11. [CI/CD (GitHub Actions)](#11-cicd-github-actions)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Prerequisites

Before you start, make sure you have:

| Tool | Version | How to Check | How to Install |
|------|---------|-------------|----------------|
| **macOS** | 14.0+ (Sonoma or later) | Apple menu → About This Mac | Update via System Settings |
| **Xcode** | 16.2+ | `xcodebuild -version` | Mac App Store or [developer.apple.com](https://developer.apple.com/xcode/) |
| **Xcode Command Line Tools** | Latest | `xcode-select -p` | `xcode-select --install` |
| **Apple Developer Account** | Paid ($99/yr) | [developer.apple.com/account](https://developer.apple.com/account) | Required for Sign In with Apple + TestFlight |
| **Supabase Account** | Free tier works | [supabase.com](https://supabase.com) | Sign up with GitHub |
| **Supabase CLI** (optional) | 1.x+ | `supabase --version` | `brew install supabase/tap/supabase` |
| **Git** | 2.x+ | `git --version` | `brew install git` |
| **gh CLI** (optional) | 2.x+ | `gh --version` | `brew install gh` |

---

## 2. Clone & Open the Project

```bash
# Clone the repo
git clone https://github.com/Xomware/xomfit-ios.git
cd xomfit-ios

# Open in Xcode
open XomFit.xcodeproj
```

### Project Structure (Key Files)

```
xomfit-ios/
├── XomFit/
│   ├── XomFitApp.swift          # App entry point
│   ├── Config.swift             # ⚠️ YOU EDIT THIS — Supabase URL + keys
│   ├── Services/
│   │   └── AuthService.swift    # Apple, Google, Email auth
│   ├── ViewModels/              # 20+ ViewModels
│   ├── Views/
│   │   └── Auth/                # Login, signup, OAuth UI
│   └── Models/                  # Data models
├── supabase/
│   └── migrations/              # 7 SQL migration files
├── .github/
│   └── workflows/
│       └── ci.yml               # GitHub Actions CI
└── docs/
    └── SETUP_GUIDE.md           # ← You are here
```

---

## 3. Create a Supabase Project

### Step 3.1 — Create the project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard)
2. Click **"New Project"**
3. Fill in:
   - **Name:** `xomfit` (or whatever you want)
   - **Database Password:** Generate a strong one. **Save this somewhere safe** (1Password, etc.). You'll need it for direct DB access later.
   - **Region:** Choose closest to your users (e.g., `US East (N. Virginia)` for East Coast)
4. Click **"Create new project"**
5. Wait 1-2 minutes for provisioning

### Step 3.2 — Get your credentials

Once the project is ready:

1. Go to **Settings** → **API** (left sidebar)
2. You need TWO values:
   - **Project URL** — looks like `https://abcdefghijkl.supabase.co`
   - **anon (public) key** — a long JWT string starting with `eyJ...`

⚠️ **Copy both of these now.** You'll paste them into `Config.swift` in Step 5.

### Step 3.3 — Note your Project Ref

Your **Project Ref** is the subdomain of your URL. If your URL is `https://abcdefghijkl.supabase.co`, then your ref is `abcdefghijkl`. You'll need this for OAuth redirect URLs.

---

## 4. Run Database Migrations

The app needs several database tables. All migrations are in `supabase/migrations/`.

### Option A — Via Supabase Dashboard (Easiest)

For each file in `supabase/migrations/` (run them **in order by filename**):

1. Go to **SQL Editor** in your Supabase dashboard
2. Click **"New Query"**
3. Copy-paste the contents of each migration file
4. Click **"Run"**

Run them in this order:
```
1. 20260228_body_composition.sql
2. 20260228_form_check_videos.sql
3. 20260228_gym_checkins.sql
4. 20260228_push_notifications.sql
5. 20260228_workout_marketplace.sql
6. 20260301_add_nutrition.sql
7. 20260306_social_feed.sql
```

### Option B — Via Supabase CLI

```bash
# Link to your remote project
supabase link --project-ref YOUR_PROJECT_REF

# Push all migrations
supabase db push
```

### Verify

After running migrations, go to **Table Editor** in the Supabase dashboard. You should see tables like:
- `body_compositions`
- `form_check_videos`
- `gym_checkins`
- `daily_nutrition`
- `social_feed_items`
- `social_feed_comments`
- `social_feed_likes`
- etc.

---

## 5. Configure the App (Config.swift)

Open `XomFit/Config.swift` and replace the placeholder values:

```swift
enum Config {
    // MARK: - Supabase Configuration
    // ⚠️ REPLACE THESE with your values from Step 3.2

    static let supabaseURL = "https://YOUR_PROJECT_REF.supabase.co"
    //                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    //                        Your Project URL from Settings → API

    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIs..."
    //                            ^^^^^^^^^^^^^^^^^^^^^^^^^^
    //                            Your anon key from Settings → API

    // These should stay as-is:
    static let oauthScheme = "xomfit"
    static let oauthCallbackURL = "xomfit://login-callback"
}
```

⚠️ **DO NOT commit your real keys to the repo.** `Config.swift` is in `.gitignore` (or should be). If it's not, add it:

```bash
echo "XomFit/Config.swift" >> .gitignore
```

---

## 6. Set Up Apple Sign In

Apple Sign In requires configuration in **three places**: Apple Developer Portal, Xcode, and Supabase.

### Step 6.1 — Apple Developer Portal: Create App ID

1. Go to [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click **"+"** to register a new identifier
3. Select **"App IDs"** → Continue
4. Select **"App"** → Continue
5. Fill in:
   - **Description:** `XomFit`
   - **Bundle ID:** Select **"Explicit"** and enter: `com.xomware.xomfit`
6. Scroll down to **Capabilities** and check ✅ **"Sign In with Apple"**
7. Click **Continue** → **Register**

### Step 6.2 — Apple Developer Portal: Create Service ID (for web/Supabase)

1. Go back to [Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click **"+"** again
3. Select **"Services IDs"** → Continue
4. Fill in:
   - **Description:** `XomFit Auth`
   - **Identifier:** `com.xomware.xomfit.auth` (this becomes your `client_id` in Supabase)
5. Click **Continue** → **Register**
6. Click on the Service ID you just created
7. Check ✅ **"Sign In with Apple"**
8. Click **Configure** next to it
9. In the configuration:
   - **Primary App ID:** Select `com.xomware.xomfit` (the App ID from Step 6.1)
   - **Domains:** Add `YOUR_PROJECT_REF.supabase.co`
   - **Return URLs:** Add `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
10. Click **Save** → **Continue** → **Save**

### Step 6.3 — Apple Developer Portal: Create Sign In with Apple Key

1. Go to [Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Click **"+"** to create a new key
3. Fill in:
   - **Key Name:** `XomFit Supabase Auth`
4. Check ✅ **"Sign In with Apple"**
5. Click **Configure** → select your **Primary App ID** (`com.xomware.xomfit`)
6. Click **Save** → **Continue** → **Register**
7. **⚠️ DOWNLOAD THE KEY FILE (.p8) IMMEDIATELY.** You can only download it once.
8. Note down:
   - **Key ID** — shown on the key details page (10-character string like `ABC123DEF4`)
   - **Team ID** — shown at top-right of the developer portal (10-character string)
9. Store the `.p8` file securely (1Password, etc.)

### Step 6.4 — Xcode: Enable Sign In with Apple Capability

1. Open `XomFit.xcodeproj` in Xcode
2. Select the **XomFit** target (blue app icon in the left sidebar)
3. Go to **Signing & Capabilities** tab
4. Click **"+ Capability"** (top left)
5. Search for and add **"Sign in with Apple"**
6. Make sure your **Team** is set to your Apple Developer team
7. Make sure **Bundle Identifier** is `com.xomware.xomfit`

Your entitlements file should now include:
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

---

## 7. Set Up Google Sign In

Google Sign In uses Supabase's built-in OAuth flow (no Google SDK needed in the app).

### Step 7.1 — Google Cloud Console: Create OAuth Client

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a new project (or select existing):
   - **Project name:** `XomFit`
3. Go to **APIs & Services** → **OAuth consent screen**
4. Select **"External"** → Create
5. Fill in:
   - **App name:** `XomFit`
   - **User support email:** your email
   - **Developer contact email:** your email
6. Click **Save and Continue** through Scopes (defaults are fine)
7. Add test users if in testing mode (your email)
8. Click **Save and Continue** → **Back to Dashboard**

### Step 7.2 — Create OAuth 2.0 Client ID

1. Go to **APIs & Services** → **Credentials**
2. Click **"+ Create Credentials"** → **"OAuth client ID"**
3. **Application type:** Select **"Web application"**
4. **Name:** `XomFit Supabase`
5. **Authorized redirect URIs:** Click **"+ Add URI"** and enter:
   ```
   https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
   ```
   Replace `YOUR_PROJECT_REF` with your actual Supabase project ref.
6. Click **Create**
7. **⚠️ Copy and save:**
   - **Client ID** — looks like `123456789-abcdef.apps.googleusercontent.com`
   - **Client Secret** — a shorter alphanumeric string

---

## 8. Configure Supabase Auth Providers

Now connect everything in your Supabase dashboard.

### Step 8.1 — Enable Apple Provider

1. Go to **Authentication** → **Providers** in your Supabase dashboard
2. Find **Apple** and toggle it **ON**
3. Fill in:
   - **Client ID (Services ID):** `com.xomware.xomfit.auth` (from Step 6.2)
   - **Secret Key:** Open the `.p8` file you downloaded in Step 6.3 in a text editor. Copy the ENTIRE contents including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`. Paste it here.
   - **Key ID:** The 10-character Key ID from Step 6.3
   - **Team ID:** Your 10-character Apple Team ID
4. Click **Save**

### Step 8.2 — Enable Google Provider

1. Still in **Authentication** → **Providers**
2. Find **Google** and toggle it **ON**
3. Fill in:
   - **Client ID:** The Google Client ID from Step 7.2
   - **Client Secret:** The Google Client Secret from Step 7.2
4. Click **Save**

### Step 8.3 — Enable Email Provider (should be on by default)

1. Still in **Authentication** → **Providers**
2. Find **Email** and make sure it's **ON**
3. Recommended settings:
   - ✅ **Enable Email Signup** — ON
   - ✅ **Confirm Email** — ON (sends verification email)
   - **Minimum password length:** 8
4. Click **Save**

### Step 8.4 — Configure Redirect URLs

1. Go to **Authentication** → **URL Configuration**
2. **Site URL:** Set to `xomfit://login-callback`
3. **Redirect URLs:** Add these:
   ```
   xomfit://login-callback
   xomfit://**
   ```
   This allows the OAuth flow to redirect back to your iOS app.
4. Click **Save**

---

## 9. Configure URL Scheme & Deep Links

The app uses a custom URL scheme (`xomfit://`) to handle OAuth redirects.

### Step 9.1 — Verify URL Scheme in Xcode

1. Open `XomFit.xcodeproj`
2. Select the **XomFit** target
3. Go to **Info** tab
4. Scroll down to **URL Types**
5. There should be an entry with:
   - **Identifier:** `com.xomware.xomfit`
   - **URL Schemes:** `xomfit`
   - **Role:** Editor
6. If it's not there, click **"+"** and add it with the values above

### Step 9.2 — Verify in Info.plist (alternative check)

Your `Info.plist` should contain:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>xomfit</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.xomware.xomfit</string>
    </dict>
</array>
```

### How it works

1. User taps "Sign in with Google/Apple"
2. App opens a web view to Supabase's OAuth endpoint
3. User authenticates with the provider
4. Provider redirects to `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
5. Supabase processes the token and redirects to `xomfit://login-callback`
6. iOS intercepts this URL and sends it to `XomFitApp.onOpenURL`
7. `AuthService.handleOAuthRedirect()` exchanges it for a session

---

## 10. Build & Run

### Step 10.1 — Select a Simulator

1. In Xcode, click the device selector (top center toolbar)
2. Choose **iPhone 15 Pro** (or any iOS 17+ simulator)

### Step 10.2 — Build

Press `Cmd + B` to build. First build will:
- Resolve Swift Package Manager dependencies
- Compile all source files
- This may take 2-5 minutes on first run

### Step 10.3 — Run

Press `Cmd + R` to run. The app should:
1. Show the **splash screen** briefly
2. Show the **login screen** with options for:
   - Sign in with Apple
   - Sign in with Google
   - Email/Password sign in
   - Create account

### Step 10.4 — Test Each Auth Method

**Email/Password:**
1. Tap "Create Account"
2. Enter email, username, password (min 8 chars, must include a number)
3. Check your email for verification link (if Confirm Email is enabled)
4. Sign in with credentials

**Apple Sign In:**
1. Tap "Sign in with Apple"
2. System Apple ID sheet appears
3. Choose to share or hide email
4. Authenticate with Face ID / passcode
5. Should redirect back to app and land on main screen

**Google Sign In:**
1. Tap "Sign in with Google"
2. Web view opens to Google's OAuth page
3. Sign in with Google account
4. Should redirect back to app via `xomfit://login-callback`

---

## 11. CI/CD (GitHub Actions)

CI runs automatically on every push to `main` and every PR targeting `main`.

### What CI Does

The workflow (`.github/workflows/ci.yml`) runs:
1. **Checkout** code
2. **Select Xcode** 16.2
3. **Resolve** Swift package dependencies
4. **Build** the project (iOS Simulator, no code signing)
5. **Test** all unit tests

### No Manual Triggers Needed

CI triggers automatically:
- ✅ `push` to `main` — runs on every merge
- ✅ `pull_request` to `main` — runs on every PR
- ✅ `workflow_dispatch` — available as manual fallback but shouldn't be needed

### Required Gates Before Merge

All four must pass (enforced by team policy):
1. ✅ **Compile** — code builds without errors
2. ✅ **Tests** — all unit tests pass
3. ✅ **Lint** — SwiftLint rules pass (per `.swiftlint.yml`)
4. ✅ **No secrets** — no hardcoded keys in code

---

## 12. Troubleshooting

### "Config is not configured" / App shows placeholder screen

**Problem:** `Config.swift` still has `YOUR_SUPABASE_URL` placeholder values.
**Fix:** Replace with real values from Step 5.

### Apple Sign In fails with "invalid_client"

**Problem:** Service ID or redirect URL mismatch.
**Fix checklist:**
- [ ] Service ID in Supabase matches the one in Apple Developer Portal (`com.xomware.xomfit.auth`)
- [ ] Return URL in Apple includes `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
- [ ] `.p8` key was pasted in full (including BEGIN/END lines)
- [ ] Key ID and Team ID are correct
- [ ] The key is associated with the correct Primary App ID

### Google Sign In redirects but doesn't complete

**Problem:** Redirect URL mismatch or URL scheme not configured.
**Fix checklist:**
- [ ] Google OAuth redirect URI matches exactly: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
- [ ] Supabase URL Configuration has `xomfit://login-callback` as redirect
- [ ] Xcode URL Types has `xomfit` scheme registered
- [ ] Google OAuth consent screen is published (not in "Testing" with user limit)

### Build fails — "No such module 'Supabase'"

**Problem:** Swift Package Manager dependencies not resolved.
**Fix:**
```bash
# In terminal:
cd xomfit-ios
xcodebuild -resolvePackageDependencies

# Or in Xcode:
# File → Packages → Resolve Package Versions
```

### OAuth redirect opens Safari instead of app

**Problem:** URL scheme not registered or app not installed.
**Fix:**
- Make sure the app is installed on the simulator/device
- Verify URL Types in Xcode Info tab (Step 9.1)
- Try: `xcrun simctl openurl booted "xomfit://login-callback"` to test the scheme

### Tests fail locally

```bash
# Run tests from command line:
xcodebuild test \
  -scheme XomFit \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | xcpretty
```

### Migrations fail

- Run them **in filename order** (dates are sequential)
- If a migration fails, check for existing tables that might conflict
- You can check existing tables: **Table Editor** in Supabase dashboard

---

## Quick Reference — What Goes Where

| Value | Where You Get It | Where It Goes |
|-------|-----------------|---------------|
| Supabase Project URL | Supabase → Settings → API | `Config.swift` → `supabaseURL` |
| Supabase Anon Key | Supabase → Settings → API | `Config.swift` → `supabaseAnonKey` |
| Apple Service ID | Apple Developer → Identifiers → Services IDs | Supabase → Auth → Apple → Client ID |
| Apple .p8 Key | Apple Developer → Keys (download once!) | Supabase → Auth → Apple → Secret Key |
| Apple Key ID | Apple Developer → Keys → Key Details | Supabase → Auth → Apple → Key ID |
| Apple Team ID | Apple Developer → top-right of portal | Supabase → Auth → Apple → Team ID |
| Google Client ID | Google Cloud → Credentials → OAuth 2.0 | Supabase → Auth → Google → Client ID |
| Google Client Secret | Google Cloud → Credentials → OAuth 2.0 | Supabase → Auth → Google → Client Secret |

---

## What's Next After Setup

Once auth is working, the app has these features ready to go:
- 🏋️ Workout Logger & Builder
- 📊 PR Tracking & Analytics
- 👥 Friends System & Social Feed
- 🤖 AI Coach
- 🏆 Challenges
- 📸 Body Composition & Progress Photos
- 🍎 Nutrition Tracking
- ⌚ Apple Watch Companion
- 📅 Workout Calendar
- 🏪 Workout Marketplace

All features are built and merged. Auth is the unlock. 🔑
