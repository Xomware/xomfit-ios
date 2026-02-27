# XomFit Challenges Implementation Guide

## Overview
This guide covers the complete implementation of the Workout Challenges feature (#13) for XomFit iOS, including real-time updates, leaderboards, streaks, and badges.

## Feature Scope
- **Challenge Types**: Most Volume, Heaviest Exercise, Most Workouts, Fastest Time, Strength Gain
- **Duration**: 7 days (volume/heavy) or 30 days (workouts/time/strength)
- **Leaderboards**: Ranked by primary metric with streaks and badges
- **Real-time Updates**: WebSocket-based live rank changes and notifications
- **Streaks**: Consecutive workout days tracked per challenge
- **Badges**: Achievement system for performance milestones

## Architecture

### Services
1. **BadgeService** - Evaluates and awards badges based on performance
2. **StreakService** - Tracks and updates workout streaks
3. **RealtimeService** - Manages WebSocket subscriptions for live updates
4. **FriendsService** - Fetches friend lists for challenge creation

### ViewModels
- **ChallengeViewModel** - Orchestrates all challenge data and real-time subscriptions

### Views
- **ChallengeView** - Main tab with active/personal/all challenges
- **CreateChallengeView** - New challenge creation form with friend selection
- **LeaderboardView** - Ranked display with podium and badges
- **ChallengeDetailView** - Challenge details with streaks and metrics

## Setup Instructions

### 1. Database Schema Setup

Run the SQL migrations in `CHALLENGES_SCHEMA.sql` in your Supabase project:

```sql
-- In Supabase Dashboard > SQL Editor
-- Paste contents of CHALLENGES_SCHEMA.sql
```

This creates:
- `challenges` table
- `challenge_participants` table
- `challenge_results` table
- `streaks` table
- `badges` table
- `friendships` table
- Indexes and RLS policies

### 2. Update SupabaseService

The existing `SupabaseService` mock needs to be replaced with real Supabase integration:

```swift
// Already in place in SupabaseClient.swift
let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey
)
```

Ensure your `Config.swift` has:
```swift
enum Config {
    static let supabaseURL = "YOUR_SUPABASE_URL"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
}
```

### 3. Implement Supabase Methods

Complete the mock methods in `SupabaseService`:

```swift
// Fetch generic objects
func fetch<T: Decodable>(_ type: T.Type, from table: String) async throws -> [T]

// Fetch with where clause
func fetch<T: Decodable>(
    _ type: T.Type,
    from table: String,
    where column: String,
    equals value: String
) async throws -> [T]

// Insert and update methods
func insert<T: Encodable>(_ object: T, into table: String) async throws
func update<T: Encodable>(_ object: T, in table: String, where column: String, equals value: String) async throws
```

### 4. Real-time Setup

#### Option A: Polling (Current Implementation)
The `RealtimeService` uses timer-based polling as a fallback. This works but is less efficient.

#### Option B: Supabase Realtime (Recommended)
Update `RealtimeService` to use Supabase Realtime when supabase-swift 3.0+ is available:

```swift
// Future implementation
let channel = supabase.realtime.channel("challenges")
channel.on(.update) { payload in
    // Handle real-time updates
}
try await channel.subscribe()
```

### 5. Friend Integration

Ensure your app has a `users` table with profile data:

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    profile_image_url TEXT,
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 6. Notification Integration

Update `NotificationService` to send actual push notifications:

```swift
// In NotificationService
func sendChallengeUpdate(title: String, body: String) async {
    // Send via UserNotifications framework
}

func sendChallengeInvitation(title: String, body: String) async {
    // Send invitation notification
}
```

## Feature Details

### Challenge Types

| Type | Duration | Metric | Unit |
|------|----------|--------|------|
| Most Volume | 7 days | Total weight lifted | lbs |
| Heaviest Exercise | 7 days | Single max lift | lbs |
| Most Workouts | 30 days | Workout count | count |
| Fastest Mile | 30 days | Best time | seconds |
| Strength Gain | 30 days | Weight increase | lbs |

### Badges System

**Automatic Badges:**
- **First Place** - Rank #1 at end of challenge
- **Podium** - Top 3 finish
- **Streak Master** - 7+ day consecutive workout streak
- **Most Improved** - Improved from starting rank
- **Consistency** - No missed days during challenge
- **PR Breaker** - Set new personal record

**Implementation**: See `BadgeService.evaluateBadges()`

### Streak Logic

Streaks are tracked per user per challenge:
- Increments on each workout day
- Resets if user misses a day
- Status: Active → At Risk (1 day missed) → Broken (2+ days missed)

**Implementation**: See `StreakService`

### Leaderboard Calculations

Rankings are calculated in real-time based on the challenge type:

```
// Most Volume / Heaviest
Results ranked by highest value

// Most Workouts
Results ranked by workout count

// Rankings update after each workout
// Ties broken by latest update time
```

## Integration Checklist

- [ ] Run `CHALLENGES_SCHEMA.sql` in Supabase
- [ ] Update `SupabaseService` with real implementations
- [ ] Configure `NotificationService` for push notifications
- [ ] Set up `users` table with profile data
- [ ] Test challenge creation flow
- [ ] Test leaderboard ranking updates
- [ ] Test streak tracking and resets
- [ ] Test badge earning and notifications
- [ ] Test real-time leaderboard updates
- [ ] Test friend list loading
- [ ] Deploy to TestFlight

## Testing

### Unit Tests Needed
- BadgeService badge evaluation logic
- StreakService streak calculations
- LeaderboardView ranking display
- Real-time update publishing

### Integration Tests
- End-to-end challenge creation
- Leaderboard updates on result changes
- Streak updates on workouts
- Badge earning notifications

## Known Limitations & Future Improvements

1. **Real-time**: Currently uses polling; upgrade to Supabase Realtime v2
2. **Custom Exercises**: "Heaviest Exercise" doesn't yet allow exercise selection
3. **Partial Days**: Streaks reset on first missed day (doesn't use grace period)
4. **Image Uploads**: User avatars use placeholder system
5. **Analytics**: No challenge history or statistics yet
6. **Mobile Notifications**: Requires APNS certificate setup

## Performance Optimizations

- Leaderboard caching with 5-minute TTL
- Batch streak updates on challenge completion
- Index all key queries in database
- Pagination for large leaderboards (100+ users)

## Security

All operations protected by Row-Level Security (RLS) policies:
- Users can only see challenges they're in
- Badges only visible to badge owner
- Streaks only visible to streak owner
- Friendships require bilateral visibility

## Support & Debugging

### Common Issues

**"Leaderboard not updating"**
- Check Supabase project is configured
- Verify user has completed workouts
- Check `challenge_results` table for entries

**"Streaks not tracking"**
- Verify `streaks` table has entries
- Check `StreakService.updateStreak()` is called
- Confirm `last_workout_date` is being updated

**"Badges not earning"**
- Run `BadgeService.evaluateBadges()` after workout
- Check badge existence check logic
- Verify badges table has permission to insert

## Contributing

When adding new challenge types:
1. Add type to `ChallengeType` enum
2. Update `durationDays` property
3. Update `displayName` and `description`
4. Add calculation logic to leaderboard fetch
5. Create badge rules for new metric

## References

- [Challenge Models](./XomFit/Models/Challenge.swift)
- [Challenge ViewModel](./XomFit/ViewModels/ChallengeViewModel.swift)
- [Challenge Views](./XomFit/Views/Challenges/)
- [Services](./XomFit/Services/)
