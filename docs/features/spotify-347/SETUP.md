# Spotify Now-Playing — Setup

XomFit captures the soundtrack of every workout. Apple Music works out of the box via
system permission. Spotify needs an explicit OAuth sign-in because iOS does not expose
other apps' Now Playing metadata to third-party apps — we have to ask Spotify directly.

This guide walks you through creating a Spotify Developer App, copying the public client
id into XomFit, and signing in.

## 1. Create a Spotify Developer App

1. Go to <https://developer.spotify.com/dashboard> and log in with your Spotify account.
2. Click **Create app**.
3. Fill in:
   - **App name:** `XomFit` (or anything you like — only you will see this)
   - **App description:** `Personal workout soundtrack capture`
   - **Website:** can be left blank
   - **Redirect URIs:** `xomfit://spotify-callback` (paste exactly — case + scheme matter)
   - **APIs used:** check **Web API**
4. Agree to the developer terms and click **Save**.

## 2. Copy your Client ID

1. On the new app's dashboard, click **Settings** (top-right).
2. Copy the value labelled **Client ID**.
   - It looks like `9a1b2c3d4e5f6789...` — 32 hex chars.
   - You do NOT need the Client Secret. XomFit uses PKCE so the secret stays unused.

## 3. Paste it into XomFit

1. Open XomFit -> **Profile tab** -> **Settings** -> **Music Sources**.
2. Tap into the **Spotify Client ID** field and paste your client id.
3. Tap **Sign In with Spotify**.
4. A web sheet opens at `accounts.spotify.com`. Log in (if you aren't already) and
   approve the requested scopes:
   - `user-read-currently-playing` — what XomFit polls during a workout
   - `user-read-playback-state` — reserved for future "what device is playing" UI
5. You'll be bounced back to XomFit. The Music Sources row now shows
   **Connected as `<your Spotify display name>`**.

## 4. (Optional) Add yourself as a tester

Spotify apps start in *Development Mode*, which limits sign-in to users you explicitly
allow.

1. Dashboard -> your app -> **Settings** -> **User Management**.
2. Click **Add New User**, enter your Spotify display name and the email tied to the
   account.

If you skip this you'll still see the Spotify login screen — but the consent step will
fail with a `User not registered in the Developer Dashboard` message.

## How it works during a workout

- When you tap **Start Workout**, XomFit kicks off a 30s polling task against
  `https://api.spotify.com/v1/me/player/currently-playing`.
- Each new track is deduped by URI and appended to the workout's captured tracks.
- On **Finish Workout**, Apple Music + Spotify captures are merged and sorted by capture
  time — you get one chronological soundtrack regardless of which app you used.
- If nothing is playing on Spotify (or you're paused), the endpoint returns 204 and the
  polling tick is a no-op. No empty entries, no crashes.

## Troubleshooting

- **"Paste your Spotify Client ID in Settings before signing in"** — you tapped Sign In
  before pasting the id. Drop it in the field above and retry.
- **Spotify says "INVALID_CLIENT: Invalid redirect URI"** — the redirect URI on the
  Dashboard does not exactly match `xomfit://spotify-callback`. Re-check casing.
- **Sign-in succeeds but the workout has no Spotify tracks** — make sure Spotify is
  actively playing (not paused) on at least one device during the workout. The Web API
  only reports active playback.
- **"User not registered in the Developer Dashboard"** — add yourself as a tester
  (step 4 above) or move the app to Extended Quota Mode via Spotify's review process.

## Security notes

- The client id is a **public** identifier — Spotify treats it that way, and so do we.
- XomFit uses **PKCE** (RFC 7636), so the client secret is never needed nor stored.
- Tokens are persisted via `@AppStorage` (UserDefaults) for v1. Anyone with device
  access could read them. Migrating to Keychain is tracked separately.
- Tap **Disconnect Spotify** in the same section to forget the tokens. You can also
  revoke XomFit's access from your Spotify account page at any time.
