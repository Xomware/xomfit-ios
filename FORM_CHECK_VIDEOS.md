# Form Check Videos — Feature Guide

Record short video clips during your sets to review your form and get feedback from friends.

## Overview

**Form Check Videos** lets you attach a 5–15 second video clip to any logged workout set.  
After recording, you can trim the clip to the best rep, upload to Supabase Storage, and optionally share it with your friends for form feedback.

---

## Architecture

### New Files

| Path | Purpose |
|------|---------|
| `XomFit/Models/FormCheckVideo.swift` | `FormCheckVideo` model + `WorkoutSet` extension |
| `XomFit/Services/FormCheckVideoRecorder.swift` | AVCaptureSession wrapper — record/stop/flip camera |
| `XomFit/Services/VideoUploadService.swift` | Upload clips to Supabase Storage + save DB records |
| `XomFit/Utils/VideoTrimmer.swift` | Trim clip to best rep, thumbnail scrubber |
| `XomFit/Views/FormCheck/FormCheckVideoView.swift` | Full-screen camera UI + record controls |
| `XomFit/Views/FormCheck/VideoPlayerView.swift` | AVPlayer with seek bar + loop support |
| `XomFit/Views/FormCheck/FormCheckFeedView.swift` | Feed: browse friends' form checks, like & comment |
| `supabase/migrations/20260228_form_check_videos.sql` | DB schema + RLS policies |

### Modified Files

| Path | Change |
|------|--------|
| `XomFit/Models/WorkoutSet.swift` | Added `videoLocalURL`, `videoRemoteURL` optional properties |
| `XomFit/Views/Workout/WorkoutLoggerView.swift` | Camera icon on set rows → opens recorder sheet |
| `XomFit/ViewModels/WorkoutLoggerViewModel.swift` | `attachFormCheckVideo(to:setId:localURL:remoteURL:)` |

---

## User Flow

```
Workout Logger
  └─ Set row  →  tap 🎥 icon
       └─ FormCheckVideoView  (full-screen camera)
            ├─ Record 5–15 s clip
            ├─ Auto-stop at 15 s
            ├─ Flip front/back camera
            └─ Stop  →  VideoTrimSheet
                 ├─ Thumbnail scrubber to select start/end
                 └─ "Use Clip"  →  upload confirm alert
                      ├─ Upload & Save  →  VideoUploadService
                      │    ├─ Transcode .mov → .mp4
                      │    ├─ POST to Supabase Storage
                      │    └─ Save DB record
                      ├─ Save Locally Only
                      └─ Discard
```

---

## Privacy Model

Videos are **private by default**.  
Users can change visibility per-clip:

| Level | Who can see |
|-------|-------------|
| 🔒 Private | Only you |
| 👥 Friends | Accepted friends only |
| 🌐 Public | Everyone |

RLS policies in Supabase enforce these rules server-side.

---

## Supabase Setup

1. Run migration: `supabase/migrations/20260228_form_check_videos.sql`
2. Create Storage bucket `form-check-videos` (private, max 50 MB per file)
3. Configure RLS policies (included in migration)

---

## Permissions Required (Info.plist)

Add to your `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>XomFit needs camera access to record form check videos during your sets.</string>
<key>NSMicrophoneUsageDescription</key>
<string>XomFit needs microphone access to include audio with your form check videos.</string>
```

---

## Comments on Form Checks

- Tap the comment bubble on any video in the Form Check Feed
- Comment sheet shows a mini video player + threaded comments
- Friends can leave technique tips ("Great depth! Keep chest up 💪")

---

## Known Limitations / Future Work

- [ ] Video playback in feed currently requires a remote URL; local-only playback uses the local file URL
- [ ] Thumbnail generation in `VideoTrimmer` is synchronous per frame — consider a batch API
- [ ] Upload progress UI could be improved with a detailed progress bar
- [ ] No server-side video compression yet — consider Supabase Edge Functions + FFmpeg
