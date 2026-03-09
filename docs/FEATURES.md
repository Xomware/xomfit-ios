# XomFit iOS — Feature Reference

> Condensed reference for all implemented features. See source code for full details.

---

## Architecture

- **Pattern:** MVVM (Model-View-ViewModel)
- **UI:** SwiftUI, dark mode, green accent (#33FF66)
- **Backend:** Supabase (PostgreSQL + Auth + Storage + Realtime)
- **Min iOS:** 17.0
- **Only SPM dependency:** `supabase-swift` 2.x

---

## Core Features

### Workout Logger & Builder
Log sets with reps/weight, built-in timer, customizable rest periods. Create and save workout templates.
- `Views/Workout/`, `ViewModels/WorkoutViewModel.swift`, `Services/WorkoutService.swift`

### Exercise Library
Comprehensive exercise database with muscle group categorization.
- `Models/Exercise.swift`

### PR Tracking
Auto-detects personal records across all exercises. Gold badge highlight on feed.
- `ViewModels/PRViewModel.swift`

### Analytics & Stats
Progress charts, volume tracking, estimated 1RM trends, intensity distribution, muscle group analysis.
- `ViewModels/AnalyticsViewModel.swift`, `ViewModels/AdvancedStatsViewModel.swift`

---

## Social Features

### Social Feed
Activity feed with filter tabs (Friends / Following / Discover). Likes, emoji reactions, comments, sharing.
- `Views/Feed/`, `ViewModels/SocialFeedViewModel.swift`, `ViewModels/FeedViewModel.swift`
- DB tables: `social_feed_items`, `social_feed_comments`, `social_feed_likes`

### Friends System
Follow friends, view profiles, compare performance.
- `ViewModels/FriendViewModel.swift`

### Social Leaderboards
Compete on lift records, total volume, workout streaks.
- `ViewModels/LeaderboardViewModel.swift`

### Workout Challenges
Create timed challenges (volume, heaviest, most workouts, fastest, strength gain). Leaderboards, streaks, badges.
- `ViewModels/ChallengeViewModel.swift`, `Services/StreakService.swift`, `Services/BadgeService.swift`

### Live Workout Mode
Real-time workout broadcasting to friends with reactions/cheers and viewer notifications.
- `ViewModels/LiveWorkoutViewModel.swift`, `Services/RealtimeService.swift`

---

## Health & Body

### Body Composition
Weight tracking, body measurements, progress photos with charts.
- `ViewModels/BodyCompositionViewModel.swift`, `Services/BodyCompositionService.swift`
- DB: `body_compositions`

### Nutrition Tracking
Calorie/macro logging with barcode scanner.
- `ViewModels/NutritionViewModel.swift`, `Services/NutritionService.swift`
- DB: `daily_nutrition`

### Recovery Insights
Recovery tracking and recommendations based on workout data.
- `ViewModels/RecoveryViewModel.swift`, `Services/RecoveryService.swift`

### HealthKit Integration
Sync with Apple Health for holistic tracking.
- `Services/HealthKitService.swift`, `ViewModels/IntegrationViewModel.swift`

---

## Media & Form

### Form Check Videos
Record 5-15s video clips during sets, trim, upload to Supabase Storage, share for feedback.
- `Services/FormCheckVideoRecorder.swift`, `Services/VideoAnalysisService.swift`
- DB: `form_check_videos`

### Stick Figure Animations
Animated exercise form guides with step-by-step cues and common mistakes.
- Lottie-style animations per exercise

### Video Analysis
AI-driven form correction using Vision framework.
- `Services/VideoAnalysisService.swift`, `ViewModels/VideoAnalysisViewModel.swift`

---

## Other Features

### AI Coach
Personalized workout recommendations based on training history, goals, and performance analysis.
- `Services/AICoachService.swift`, `ViewModels/AICoachViewModel.swift`

### Workout Calendar
GitHub-style heat map of workout history.
- `ViewModels/WorkoutCalendarViewModel.swift`

### Gym Check-in
Location-based check-in, see who's at your gym.
- `Services/GymCheckInService.swift`, `ViewModels/GymCheckInViewModel.swift`
- DB: `gym_checkins`

### Workout Marketplace
Discover, share, and import community training programs.
- `ViewModels/MarketplaceViewModel.swift`, `Services/MarketplaceService.swift`
- DB: `workout_marketplace` tables

### User Profile
Username, display name, bio, avatar upload, stats, privacy controls.
- `ViewModels/ProfileViewModel.swift`, `Services/UserProfileService.swift`

### Push Notifications
APNs integration with workout reminders, friend activity alerts, deep linking.
- `Services/NotificationService.swift`, `Services/ActivityNotificationService.swift`
- DB: `push_notifications`

### Export & Share
Export workouts, achievements, progress reports.
- `Services/ExportService.swift`, `ViewModels/ExportViewModel.swift`

### Custom Programs
Build and save personalized training programs.
- `Services/ProgramService.swift`

### Apple Watch Companion
Quick set logging, rest timer, workout controls, complications.
- `XomFitWatch/` directory

---

## Database Tables (Supabase)

All migrations in `supabase/migrations/`. See `docs/SETUP.md` Step 6 for how to run them.

| Migration | Tables Created |
|-----------|---------------|
| `20260228_body_composition.sql` | `body_compositions` |
| `20260228_form_check_videos.sql` | `form_check_videos` |
| `20260228_gym_checkins.sql` | `gym_checkins` |
| `20260228_push_notifications.sql` | push notification tables |
| `20260228_workout_marketplace.sql` | marketplace tables |
| `20260301_add_nutrition.sql` | `daily_nutrition` |
| `20260306_social_feed.sql` | `social_feed_items`, `social_feed_comments`, `social_feed_likes` |
