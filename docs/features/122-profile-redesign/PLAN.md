# Plan: Profile Redesign (IG-Style)

**Status**: Ready
**Created**: 2026-03-30
**Last updated**: 2026-03-30

## Summary
Redesign the XomFit ProfileView from a settings-like page into an Instagram-style profile with a header, stats row, custom tab picker, and tabbed content (Feed, Calendar, Stats, Friends). The same view must work for the current user and for viewing other users' profiles. Sign out and settings move to the gear icon toolbar item, which already links to the existing SettingsView.

## Approach
Full rewrite of ProfileView with extracted subviews. The existing ProfileViewModel expands to manage tab state, feed items, calendar data, and friends. FeedService gets one new method (`fetchUserFeed`). No new services needed -- all data sources already exist.

## Affected Files / Components
| File / Component | Change | Why |
|-----------------|--------|-----|
| `Xomfit/Views/Profile/ProfileView.swift` | Rewrite: header + tab picker + tab content container. Accept optional `userId` param. Remove sign out, nav links, stats grid, recent PRs. Extract EditProfileSheet to own file. | Core of the redesign |
| `Xomfit/Views/Profile/ProfileHeaderView.swift` | **New** -- avatar, display name, username, bio, IG-style stats row, action button (Edit Profile / Add Friend) | Extracted header component |
| `Xomfit/Views/Profile/ProfileTabPicker.swift` | **New** -- custom horizontal tab bar with underline indicator (Feed / Calendar / Stats / Friends) | IG-style tab UI |
| `Xomfit/Views/Profile/ProfileFeedView.swift` | **New** -- LazyVStack of FeedItemCard for the user's feed items | Feed tab content |
| `Xomfit/Views/Profile/ProfileCalendarView.swift` | **New** -- heatmap calendar grid (last ~12 weeks, LazyVGrid 7 cols, green intensity) | Calendar tab content |
| `Xomfit/Views/Profile/ProfileStatsView.swift` | **New** -- PRs list + volume summary. Reuses PRBadgeRow. | Stats tab content |
| `Xomfit/Views/Profile/ProfileFriendsView.swift` | **New** -- friend list with avatars within profile | Friends tab content |
| `Xomfit/Views/Profile/EditProfileSheet.swift` | **Extract** -- move existing EditProfileSheet from ProfileView to its own file (no logic changes) | Clean separation |
| `Xomfit/ViewModels/ProfileViewModel.swift` | Expand: add selectedTab enum, feedItems array, calendarData, friends list, `isOwnProfile` flag, `loadAll(userId:currentUserId:)`, fetchUserFeed, group workouts by day for calendar | Drives all new tab content |
| `Xomfit/Services/FeedService.swift` | Add `fetchUserFeed(userId:limit:offset:)` -- filter by `user_id` | Per-user feed data |
| `Xomfit/Views/Profile/PrivateProfileView.swift` | **New** -- lock icon + "This account is private" message | Shown for private non-friend profiles |

## Implementation Steps

### Phase 1: Service + ViewModel Foundation
- [ ] Step 1 -- Add `fetchUserFeed(userId:limit:offset:)` to `FeedService`. Copy `fetchFeed` but add `.eq("user_id", value: userId)` filter.
- [ ] Step 2 -- Define `ProfileTab` enum (feed, calendar, stats, friends) in ProfileViewModel.
- [ ] Step 3 -- Expand ProfileViewModel: add `selectedTab`, `feedItems: [SocialFeedItem]`, `friends: [FriendRow]`, `workoutsByDay: [Date: Int]` (for calendar), `isOwnProfile: Bool`, `isFriend: Bool`, `friendCount: Int`, `feedItemCount: Int`.
- [ ] Step 4 -- Add `loadAll(userId:currentUserId:)` to ProfileViewModel. Loads profile, stats, feed items, friends, and calendar data in parallel with `async let`. Sets `isOwnProfile` based on whether `userId == currentUserId`.
- [ ] Step 5 -- Add `loadCalendarData(workouts:)` helper to ProfileViewModel. Groups workouts by calendar day (stripping time) into `workoutsByDay` dictionary.

### Phase 2: Extracted / New Subviews
- [ ] Step 6 -- Extract `EditProfileSheet` from ProfileView into `Xomfit/Views/Profile/EditProfileSheet.swift`. No logic changes.
- [ ] Step 7 -- Create `ProfileHeaderView`. Props: displayName, username, bio, avatarURL, initials, isPrivate, isOwnProfile, feedItemCount, friendCount, prCount, onStatTapped (closure that sets selectedTab), onActionTapped (edit or add friend). Use Theme colors. Avatar: 80pt circle with initials or AsyncImage.
- [ ] Step 8 -- Create `ProfileTabPicker`. Binding<ProfileTab>, custom HStack with underline indicator animated with `.matchedGeometryEffect`. Icons: list.bullet (feed), calendar (calendar), chart.bar (stats), person.2 (friends).
- [ ] Step 9 -- Create `ProfileFeedView`. Takes `[SocialFeedItem]`, renders in LazyVStack using existing FeedItemCard. Show empty state if no items.
- [ ] Step 10 -- Create `ProfileCalendarView`. Takes `workoutsByDay: [Date: Int]`. LazyVGrid with 7 columns, ~12 weeks of cells. Color: `Theme.cardBackground` for empty, `Theme.accent.opacity(0.4)` for 1 workout, `Theme.accent` for 2+. Day-of-week header row (S M T W T F S).
- [ ] Step 11 -- Create `ProfileStatsView`. Takes `[PersonalRecord]`, shows total PRs header + ForEach with PRBadgeRow. Add volume stat card at top.
- [ ] Step 12 -- Create `ProfileFriendsView`. Takes `[FriendRow]` (will need profile lookups for display names/avatars). List rows with avatar circle + display name. Tap navigates to that user's profile.
- [ ] Step 13 -- Create `PrivateProfileView`. Lock icon + message + "Send Friend Request" button.

### Phase 3: Rewrite ProfileView
- [ ] Step 14 -- Rewrite `ProfileView`. Accept optional `userId: String?` parameter (nil = current user). Compose: ProfileHeaderView + ProfileTabPicker + switch on selectedTab for content views. Toolbar: gear icon (NavigationLink to SettingsView) for own profile only, pencil icon triggers EditProfileSheet for own profile.
- [ ] Step 15 -- Handle other-user flow: if `userId != nil && userId != currentUserId`, set `isOwnProfile = false`. If profile is private and not friends, show PrivateProfileView instead of tabs.
- [ ] Step 16 -- Wire stats row taps: tapping Posts/Friends/PRs in the header switches `selectedTab` to .feed/.friends/.stats respectively.

### Phase 4: Integration + Polish
- [ ] Step 17 -- Update any navigation that pushes to ProfileView (feed user taps, friend list taps) to pass `userId` parameter.
- [ ] Step 18 -- Remove sign out button and nav links from ProfileView (already in SettingsView).
- [ ] Step 19 -- Test own-profile flow: load, edit, tab switching, calendar rendering.
- [ ] Step 20 -- Test other-user flow: view public profile, view private profile (locked), add friend action.
- [ ] Step 21 -- Verify accessibility: Dynamic Type on all text, VoiceOver labels on tab picker and stats row, 44pt touch targets on all interactive elements.

## Out of Scope
- Avatar image upload (just initials/placeholder for now -- avatarURL field exists but upload flow is separate)
- Pull-to-refresh on profile
- Infinite scroll / pagination on profile feed (load first 20, paginate later)
- Workout detail drill-down from calendar cells
- Friend request accept/reject from within profile (that lives in FriendsView)
- Real-time feed updates via Supabase subscriptions

## Risks / Tradeoffs
- **FeedItemCard reuse in profile context**: FeedItemCard (348 LOC) was built for the main feed. It may show user info redundantly when used in a profile. Mitigation: check if it has a compact mode or plan a fast follow to add one.
- **Calendar data volume**: Loading all workouts to build the calendar could be slow for heavy users. Mitigation: limit to last 90 days in the query.
- **Friends list in profile needs profile lookups**: FriendsService returns FriendRow (IDs only). Displaying names/avatars requires batch profile fetches. Mitigation: add a `fetchProfiles(userIds:)` batch method to ProfileService, or accept N+1 for now with small friend counts.
- **Tab picker sticky behavior**: SwiftUI ScrollView doesn't natively support sticky headers. Mitigation: use `LazyVStack(pinnedViews: [.sectionHeaders])` with the tab picker as a section header.

## Open Questions
- [x] ProfileFriendsView navigates to other user's profile (recursive push, IG pattern)
- [x] Calendar should look like a real calendar with month/day headers, not just a heatmap grid
- [x] Add Friend button handles all states: "Add Friend" (none), "Requested" (pending), "Friends" (accepted)

## Skills / Agents to Use
- **Coder agent**: Execute phases 1-3 sequentially. Each phase is independent enough for a focused coding pass.
- **ios-standards skill**: Reference before writing any new SwiftUI views to ensure conventions (foregroundStyle vs foregroundColor, clipShape, etc.).
- **Reviewer agent**: After phase 3 to check MVVM compliance, verify no view-to-service calls, and catch accessibility gaps.
