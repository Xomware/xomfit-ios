# Execution Log — Friends Bugs (#235)

**Plan**: `docs/features/friends-bugs-235/PLAN.md`
**Branch**: `fix/235-friends-bugs`
**Started**: 2026-04-17

## Phase Status

- [x] **Phase 1** — Service + Model Layer (`FriendshipRelation` enum, new service methods, hardened `sendFriendRequest`)
- [ ] **Phase 2** — ProfileViewModel (replace `ProfileFriendshipStatus` with `FriendshipRelation`)
- [ ] **Phase 3** — ProfileHeaderView + PrivateProfileView + ProfileView (direction-aware + confirmation dialogs)
- [ ] **Phase 4** — FriendsView + new FriendsViewModel
- [ ] **Phase 5** — OnboardingFriendsScreen unified state
- [ ] **Phase 6** — Cleanup (delete legacy models + grep audit)
- [ ] Manual test pass (T1-T13)
- [ ] Open PR against `develop` with `Closes #235`

## Log

### 2026-04-17 — Kickoff
- Plan flipped Draft → Ready.
- Starting Phase 1 via `ios-specialist` agent.

### 2026-04-17 — Phase 1 complete
- Added `FriendshipRelation` enum (none / outgoingPending / incomingPending / friends / blocked) and `FriendError.alreadyExists` in `FriendsService.swift`.
- Added private `mapRelation(row:currentUserId:)` helper that maps DB status + direction to the enum (declined → .none).
- Added `relation(currentUserId:otherUserId:)` using a single `.or()` query with two `and(...)` clauses and `.limit(1)`.
- Added `batchRelations(currentUserId:otherUserIds:)` using two `.in(...)` queries merged into `[otherUserId: FriendshipRelation]`; drops `.none` entries; early returns `[:]` for empty input.
- Added `fetchOutgoingRequests(userId:)` mirroring `fetchPendingRequests`.
- Added `cancelFriendRequest(friendshipId:)` as a thin wrapper over `declineFriendRequest` for call-site clarity.
- Hardened `sendFriendRequest(fromUserId:toUserId:)` → now returns `String` (new friendship id) with `@discardableResult`; pre-checks `relation(...)` and throws `FriendError.alreadyExists(relation:)` if anything but `.none` is found.
- `fetchFriends` left accepted-only (correct for its purpose per plan).
- Build: `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17' build` → **BUILD SUCCEEDED** (iPhone 16 sim not installed locally; used iPhone 17 — iOS 26.2).
