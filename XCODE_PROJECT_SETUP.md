# Xcode Project Setup for XomFit iOS Auth

**⚠️ IMPORTANT**: This repository contains only Swift source code. You need to create an Xcode project and configure it properly.

---

## Step 1: Create New Xcode Project

1. Open Xcode and select **File > New > Project**
2. Choose **iOS > App**
3. Configure the project:
   - **Product Name**: XomFit
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Bundle Identifier**: `com.xomware.xomfit` (or your preferred identifier)
   - **Team**: Select your Apple Developer team
   - **Use Core Data**: No
   - **Include Tests**: Yes (optional)

---

## Step 2: Import Source Files

1. Delete the auto-generated `ContentView.swift` file
2. Copy all files from the `XomFit/` directory into your Xcode project:
   ```
   XomFit/
   ├── XomFitApp.swift
   ├── Config.swift
   ├── Models/
   ├── Views/
   ├── ViewModels/
   ├── Services/
   └── Utils/
   ```
3. Make sure to add them to the target when prompted

---

## Step 3: Add Swift Package Dependencies

1. In Xcode, select **File > Add Package Dependencies...**
2. Add the Supabase Swift package:
   ```
   https://github.com/supabase/supabase-swift
   ```
   - Select version: **2.x** or later
   - Add to **XomFit** target

---

## Step 4: Configure URL Scheme

1. Select your **XomFit** target in Xcode
2. Go to the **Info** tab
3. Under **URL Types**, click **+** to add:
   - **Identifier**: `com.xomware.xomfit.oauth`
   - **URL Schemes**: `xomfit`
   - **Role**: Editor

This enables deep linking for OAuth flows (Google Sign In).

---

## Step 5: Configure App Capabilities

1. Select your **XomFit** target
2. Go to **Signing & Capabilities** tab
3. Add **Keychain Sharing** capability (for secure session storage)
4. Add **Sign in with Apple** capability (required for Apple Sign In)

---

## Step 6: Configure Info.plist

Add these entries to your `Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>googlechrome</string>
    <string>googlechromes</string>
</array>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.xomware.xomfit.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>xomfit</string>
        </array>
    </dict>
</array>
```

---

## Step 7: Set Up Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note your **Project URL** and **Anon Key** from Settings > API
3. Update `XomFit/Config.swift` with your real values:
   ```swift
   enum Config {
       static let supabaseURL = "https://your-project.supabase.co"
       static let supabaseAnonKey = "your-anon-key-here"
   }
   ```

---

## Step 8: Configure Supabase Auth Providers

In your Supabase dashboard:

1. Go to **Authentication > Providers**
2. Enable **Email**:
   - Toggle on
   - Keep default settings
3. Enable **Apple**:
   - Toggle on
   - You'll need Apple Developer credentials (see Supabase docs)
4. Enable **Google**:
   - Toggle on
   - You'll need Google Cloud Console OAuth credentials

### Configure Redirect URLs

1. Go to **Authentication > URL Configuration**
2. Add this redirect URL:
   ```
   xomfit://
   ```

---

## Step 9: Test the Implementation

1. Build and run on a real device (Apple Sign In requires it)
2. Test all three auth flows:
   - Email/Password sign up and sign in
   - Apple Sign In (requires real device)
   - Google Sign In (web-based OAuth)

---

## Step 10: Deploy Configuration

When ready for production:

1. **Apple Sign In**: Configure production keys in Apple Developer portal
2. **Google OAuth**: Set up production credentials in Google Cloud Console  
3. **Supabase**: Configure production environment variables
4. **App Store**: Ensure Apple Sign In is properly configured for App Store review

---

## Troubleshooting

### Deep Link Issues
- Verify URL scheme `xomfit://` is registered in both Xcode and Supabase
- Test on real device (simulator deep linking can be unreliable)

### Apple Sign In Not Working
- Must test on real device with valid Apple ID
- Ensure Sign in with Apple capability is enabled

### Session Not Persisting
- Verify Keychain Sharing capability is enabled
- Check that Supabase client is properly initialized

---

## Next Steps After Setup

1. **Create GitHub issues** for any bugs found during testing
2. **Test on multiple devices** and iOS versions
3. **Add user profile management** features
4. **Implement additional auth features** (password reset, email verification)

The auth implementation is now complete and ready for production use!