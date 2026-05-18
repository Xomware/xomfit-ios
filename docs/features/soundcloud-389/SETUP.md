# SoundCloud Now-Playing — Setup

XomFit captures the soundtrack of every workout across multiple sources: Apple Music
(system permission, read-only), Spotify (#347, paste-your-own client id), and SoundCloud
(#389, shared client id baked into the app).

## TL;DR — current status

> **The SoundCloud Developer program has been intermittently closed to new app
> registrations for years.** As of shipping this integration, the `sharedClientId` in
> `Xomfit/Services/SoundCloudConfig.swift` is a `PLACEHOLDER_SHARED_SOUNDCLOUD_CLIENT_ID`.
>
> - The code is fully wired and ready.
> - Users who tap **Sign In with SoundCloud** before the placeholder is replaced will get
>   a clear inline error: *"SoundCloud rejected XomFit's shared client id. The SoundCloud
>   Developer program has been intermittently closed to new apps — see Settings for
>   status."*
> - **Apple Music and Spotify capture continue working untouched.** The user can finish
>   their workout normally; only the SoundCloud row is non-functional.
>
> **TODO:** Once SoundCloud reopens app registrations (or we get an existing app id
> reassigned), replace `SoundCloudConfig.sharedClientId` and ship a point release.
> See <https://developers.soundcloud.com> for the latest status.

## Why a shared client id (vs paste-your-own like Spotify)

Spotify lets anyone register a developer app in 30 seconds — `Settings -> Music Sources ->
Spotify Client ID` paste field is the right UX there. SoundCloud's program isn't reliably
open, so requiring every user to register their own app would mean ~nobody ever uses the
integration. Instead, XomFit ships a single shared client id and gates the OAuth dance
behind PKCE so the absence of a client secret is safe.

## OAuth flow

`SoundCloudAuthService` (mirrors `SpotifyAuthService` almost exactly):

1. Generate PKCE verifier + S256 challenge + anti-CSRF `state`.
2. Open `ASWebAuthenticationSession` to
   `https://api.soundcloud.com/connect?client_id=<shared>&response_type=code&code_challenge=...&redirect_uri=xomfit://soundcloud-callback&scope=non-expiring`.
3. SoundCloud redirects to `xomfit://soundcloud-callback?code=...&state=...`.
4. POST the code + verifier to `https://api.soundcloud.com/oauth2/token` for tokens.
5. Persist tokens via `@AppStorage` (UserDefaults). Keychain migration tracked separately.

## Polling (`SoundCloudNowPlayingService`)

SoundCloud's Web API does **not** expose a real-time "currently playing" endpoint. The
closest thing is `GET /me/play-history/tracks?limit=5` — a list of the most recently played
tracks.

- On `startCapture()` we snapshot whatever's currently at the head of play-history and
  store its dedupe key. This way, the song the user was listening to ~before~ tapping
  Start Workout doesn't get attributed to the workout.
- Every 30s we poll again. If the head is different from what we last saw, we capture it.
- The 30s cadence vs typical 3-4 minute song length means we generally catch each track
  with a small lag (anywhere from a few seconds to a minute or two — SoundCloud writes to
  history only after a play threshold).

This is best-effort but matches what's possible without a real-time endpoint.

## During a workout

- Tap **Start Workout** → all three services (`NowPlayingService`,
  `SpotifyNowPlayingService`, `SoundCloudNowPlayingService`) kick off polling.
- Tap **Finish Workout** → each service returns its captured `[WorkoutTrack]`. The view
  model merges them and sorts by `capturedAt`, so the saved soundtrack reflects actual
  play order across sources.
- Tap **Discard** → all three services drop their captured state and stop polling.

## When the placeholder client id is replaced

1. Get the real id from <https://developers.soundcloud.com> (or whichever channel
   eventually grants you a redeemable app).
2. Register the redirect URI **exactly** `xomfit://soundcloud-callback` on the SoundCloud
   Developer Dashboard (case + scheme matter).
3. Edit `Xomfit/Services/SoundCloudConfig.swift`:
   ```swift
   static let sharedClientId: String = "<the real id>"
   ```
4. No other code changes needed. Ship the point release.

## Troubleshooting

- **"SoundCloud rejected XomFit's shared client id..."** — Expected with the placeholder
  id. Wait for the next point release, or contact the maintainer.
- **Sign-in succeeds but no SoundCloud tracks captured** — Make sure SoundCloud was the
  app actively playing audio during the workout, and the songs were played long enough to
  hit SoundCloud's play-count threshold (it determines when a play counts toward history).
- **"INVALID_CLIENT" / "Invalid redirect URI"** — Redirect URI on the Dashboard does not
  exactly match `xomfit://soundcloud-callback`. Re-check casing.
- **`apiClosed` error after a previously working sign-in** — SoundCloud sometimes revokes
  client ids without warning. Hit Disconnect and re-sign-in once the client id is rotated.

## Security notes

- Shared client id is treated as public, same as Spotify's. PKCE (RFC 7636) means no
  client secret is needed or stored.
- Tokens are in `@AppStorage` (UserDefaults). Anyone with device access could read them.
  Keychain migration is tracked separately, same as Spotify.
- **Disconnect SoundCloud** in the Music Sources section forgets the tokens. SoundCloud
  does not document a user-facing token revoke endpoint, so the only stronger guarantee is
  to change your SoundCloud password.
