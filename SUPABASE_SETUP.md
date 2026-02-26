# Supabase Setup Guide for XomFit iOS

This guide walks through the steps needed to configure Supabase authentication for the XomFit iOS app.

## Prerequisites

- Xcode 15.0 or later
- An Apple Developer account (for signing the app)
- A Supabase account (free tier works fine)

---

## Step 1: Set Up Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in or create an account
2. Create a new project:
   - Choose any region (e.g., us-east-1)
   - Set a strong database password
3. Once the project is created, go to **Settings > API** and note:
   - **Project URL** (e.g., `https://your-project.supabase.co`)
   - **Anon Key** (public key)

## Step 2: Enable Authentication Providers

In your Supabase dashboard:

1. Go to **Authentication > Providers**
2. Enable **Email Provider**:
   - Click "Email" and toggle it on
   - Keep default settings
3. Enable **Apple Provider**:
   - Click "Apple"
   - You'll need:
     - **Services ID** (from Apple Developer)
     - **Team ID** (from Apple Developer)
     - **Key ID** (from Apple Developer)
   - See [Supabase Apple Provider Docs](https://supabase.com/docs/guides/auth/social-login/auth-apple) for details

> **Optional**: Google provider is stubbed out in `LoginView.swift`. To enable it, follow the [Supabase Google OAuth Guide](https://supabase.com/docs/guides/auth/social-login/auth-google).

## Step 3: Configure Redirect URLs

1. In your Supabase dashboard, go to **Authentication > URL Configuration**
2. Add this redirect URL:
   ```
   xomfit://
   ```
   - This tells Supabase to redirect back to the iOS app after OAuth

## Step 4: Set Up URL Scheme in Xcode

1. Open `XomFit.xcodeproj` in Xcode
2. Select the **XomFit** target
3. Go to **Info** tab
4. Under **URL Types**, click **+** to add a new URL scheme:
   - **Identifier**: `com.xomware.xomfit` (or similar)
   - **URL Schemes**: `xomfit`
5. Save and close

---

## Step 5: Add supabase-swift Package

1. In Xcode, select **File > Add Packages...**
2. Enter the repository URL:
   ```
   https://github.com/supabase/supabase-swift
   ```
3. Select version: **2.x**
4. Choose the **XomFit** target to add the package to
5. Click **Add Package**

---

## Step 6: Fill in Config.swift

1. Open `XomFit/Config.swift`
2. Replace the placeholder values:
   ```swift
   enum Config {
       static let supabaseURL = "https://your-project.supabase.co"
       static let supabaseAnonKey = "your-anon-key-here"
   }
   ```
   - Use the **Project URL** and **Anon Key** from Step 1

---

## Step 7: Test the App

1. Build and run the app on a simulator or device
2. Try these flows:
   - **Email/Password Sign Up**: Create a new account with email and password
   - **Email/Password Sign In**: Log in with the account you just created
   - **Sign In with Apple**: Use your Apple ID to sign in (requires a real device or simulator with Face ID/Touch ID)
3. Check the Supabase dashboard:
   - Go to **Authentication > Users** to see created users

---

## Troubleshooting

### "Invalid Supabase URL or Key"
- Make sure you've filled in `Config.swift` with real values
- Double-check there are no trailing spaces

### "Redirect URL mismatch" during OAuth
- Verify the `xomfit://` URL scheme is registered in Xcode
- Verify `xomfit://` is in Supabase **URL Configuration**

### Apple Sign In not working on simulator
- Apple Sign In requires a real device or simulator with proper sign-in credentials configured
- Test with email/password sign in first

### Session not persisting after app close
- Supabase-swift automatically stores sessions in Keychain
- If sessions don't persist, check that Keychain sharing is enabled in your app's capabilities

---

## User Profiles Setup (Issue #3)

### Database Migration

Run `supabase/migrations/20240001_profiles.sql` in the Supabase SQL Editor.
It creates:
- **`public.profiles`** table with username, display_name, bio, avatar_url, is_private, and lifetime stats columns
- RLS policies (users read/write their own profile; public profiles readable by all)
- **`avatars`** Storage bucket (public) with per-user folder upload policies

### Storage Bucket

The migration creates the `avatars` bucket automatically. Verify in:
**Supabase Dashboard → Storage → Buckets** that `avatars` exists and is set to **Public**.

### How the Profile Flow Works

1. After sign-in, `ProfileView` calls `loadProfile(userId:)`.
2. If no row exists in `profiles`, the **ProfileSetupView** wizard appears (4 steps: welcome → name → avatar → bio).
3. On completion, a row is inserted and the avatar (if chosen) is uploaded to `storage/avatars/<userId>/avatar.jpg`.
4. The **Edit Profile** sheet (pencil icon, top-right) lets users change any field at any time.

---

## Next Steps

Once authentication is working:

1. ✅ **User Profiles**: Implemented in `feature/user-profile` branch
2. **Google Sign In**: Implement Google OAuth if needed
3. **Email Verification**: Optionally require email verification before sign-in

---

## References

- [Supabase Swift Docs](https://supabase.com/docs/reference/swift/introduction)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [ASAuthorizationController Apple Docs](https://developer.apple.com/documentation/authenticationservices/asauthorizationcontroller)
