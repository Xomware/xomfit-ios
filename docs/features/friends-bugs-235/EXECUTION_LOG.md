# Execution Log — Friends Bugs (#235)

**Plan**: `docs/features/friends-bugs-235/PLAN.md`
**Branch**: `fix/235-friends-bugs`
**Started**: 2026-04-17

## Phase Status

- [x] **Phase 1** — Service + Model Layer (`FriendshipRelation` enum, new service methods, hardened `sendFriendRequest`)
- [x] **Phase 2** — ProfileViewModel (replace `ProfileFriendshipStatus` with `FriendshipRelation`)
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

### 2026-04-17 — Phase 2 complete
- `ProfileViewModel.swift`: removed `ProfileFriendshipStatus` enum from its original top-of-file location; replaced stored `friendshipStatus: ProfileFriendshipStatus` with `relation: FriendshipRelation = .none`.
- Added derived `isFriendsRelation: Bool` computed property.
- Renamed private `loadFriendshipStatus(currentUserId:targetUserId:)` → `loadRelation(...)`; new body delegates to `FriendsService.shared.relation(...)` and falls back to `.none` on error.
- Updated `loadAll(...)` privacy gate to use `loadRelation` + `!isFriendsRelation`.
- Rewrote `sendFriendRequest(fromUserId:toUserId:)` to capture the returned friendship id and assign `relation = .outgoingPending(friendshipId: newId)`; catches `FriendError.alreadyExists` and reflects the actual state.
- Added new `@MainActor` mutation methods: `cancelRequest()`, `acceptIncoming()`, `declineIncoming()`, `removeFriend()` — each guards on the matching `relation` case, calls the corresponding service, and sets `errorMessage` on failure.
- Added temporary back-compat shims so Phase 3 views still compile: file-scope `enum ProfileFriendshipStatus { case none, pending, friends }` (restored at bottom of file, outside the class — matches original placement) + in-class computed `var friendshipStatus: ProfileFriendshipStatus` that maps `relation` to the legacy tri-state. Both will be removed in Phase 3.
- Build: `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17' build` → **BUILD SUCCEEDED**.
