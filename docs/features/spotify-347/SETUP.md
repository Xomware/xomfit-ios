# Spotify Now-Playing — Setup

XomFit captures the soundtrack of every workout. Apple Music works out of the box via the
system Now-Playing permission. Spotify needs an explicit OAuth sign-in because iOS does not
expose other apps' Now-Playing metadata to third-party apps — we have to ask Spotify directly.

As of #390, XomFit ships with a shared Spotify Developer App baked in. **Most users just need
to sign in.**

## Connect Spotify

1. Open XomFit -> **Profile tab** -> **Settings** -> **Music Sources**.
2. Tap **Sign In with Spotify**.
3. A web sheet opens at `accounts.spotify.com`. Log in (if you aren't already) and approve the
   requested scopes:
   - `user-read-currently-playing` — what XomFit polls during a workout
   - `user-read-playback-state` — reserved for future "what device is playing" UI
4. You'll be bounced back to XomFit. The Music Sources row now shows
   **Connected as `<your Spotify display name>`**.

That's it. Start a workout — XomFit will pick up whatever you're playing on Spotify and merge
it with any Apple Music captures into one chronological soundtrack on Finish.

## How it works during a workout

- When you tap **Start Workout**, XomFit kicks off a 30s polling task against
  `https://api.spotify.com/v1/me/player/currently-playing`.
- Each new track is deduped by URI and appended to the workout's captured tracks.
- On **Finish Workout**, Apple Music + Spotify captures are merged and sorted by capture time
  — one chronological soundtrack regardless of which app you used.
- If nothing is playing on Spotify (or you're paused), the endpoint returns 204 and the
  polling tick is a no-op. No empty entries, no crashes.

## Troubleshooting

- **"Spotify isn't configured yet."** — the shared Client ID hasn't been replaced in this
  build. Wait for an updated build, or use the Advanced override below with your own Spotify
  Developer App.
- **Spotify says "INVALID_CLIENT: Invalid redirect URI"** — the redirect URI on the shared
  Spotify Developer App must be exactly `xomfit://spotify-callback`. If you're overriding the
  Client ID with your own Developer App, you have to register that URI yourself.
- **Sign-in succeeds but the workout has no Spotify tracks** — make sure Spotify is actively
  playing (not paused) on at least one device during the workout. The Web API only reports
  active playback.
- **"User not registered in the Developer Dashboard"** — the shared Developer App is in
  Development Mode and you aren't on the allow-list. Either wait for the app to move to
  Extended Quota Mode, or use the Advanced override with your own Developer App.

## Security notes

- The Spotify Client ID is a **public** identifier — Spotify treats it that way, and so do we.
- XomFit uses **PKCE** (RFC 7636), so the client secret is never needed nor stored.
- Tokens are persisted via `@AppStorage` (UserDefaults) for v1. Anyone with device access
  could read them. Migrating to Keychain is tracked separately.
- Tap **Disconnect Spotify** in the same section to forget the tokens. You can also revoke
  XomFit's access from your Spotify account page at any time.

---

## Power users: use your own Client ID

If you'd rather point sign-in at your own Spotify Developer App (e.g. you've already hit the
shared app's user quota, or you want to test against your own account), XomFit honors a
per-user override.

### 1. Create a Spotify Developer App

1. Go to <https://developer.spotify.com/dashboard> and log in with your Spotify account.
2. Click **Create app**.
3. Fill in:
   - **App name:** `XomFit` (or anything you like — only you will see this)
   - **App description:** `Personal workout soundtrack capture`
   - **Website:** can be left blank
   - **Redirect URIs:** `xomfit://spotify-callback` (paste exactly — case + scheme matter)
   - **APIs used:** check **Web API**
4. Agree to the developer terms and click **Save**.

### 2. Copy your Client ID

1. On the new app's dashboard, click **Settings** (top-right).
2. Copy the value labelled **Client ID** (a 32-char hex string).
   - You do NOT need the Client Secret. XomFit uses PKCE so the secret stays unused.

### 3. Paste it into XomFit

1. Open XomFit -> **Profile tab** -> **Settings** -> **Music Sources**.
2. Expand the **Advanced (override Client ID)** disclosure at the bottom of the Spotify block.
3. Paste your Client ID into the **Override Spotify Client ID** field.
4. Tap **Sign In with Spotify**. Sign-in will now use *your* Developer App instead of the
   shared one. Clearing the override field reverts to the shared id.

### 4. (Optional) Add yourself as a tester

Spotify apps start in *Development Mode*, which limits sign-in to users you explicitly allow.

1. Dashboard -> your app -> **Settings** -> **User Management**.
2. Click **Add New User**, enter your Spotify display name and the email tied to the account.

If you skip this you'll still see the Spotify login screen — but the consent step will fail
with a `User not registered in the Developer Dashboard` message.
