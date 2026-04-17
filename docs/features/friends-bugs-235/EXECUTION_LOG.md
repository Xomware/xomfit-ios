# Execution Log — Friends Bugs (#235)

**Plan**: `docs/features/friends-bugs-235/PLAN.md`
**Branch**: `fix/235-friends-bugs`
**Started**: 2026-04-17

## Phase Status

- [x] **Phase 1** — Service + Model Layer (`FriendshipRelation` enum, new service methods, hardened `sendFriendRequest`)
- [x] **Phase 2** — ProfileViewModel (replace `ProfileFriendshipStatus` with `FriendshipRelation`)
- [x] **Phase 3** — ProfileHeaderView + PrivateProfileView + ProfileView (direction-aware + confirmation dialogs)
- [x] **Phase 4** — FriendsView + new FriendsViewModel
- [x] **Phase 5** — OnboardingFriendsScreen unified state
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

### 2026-04-17 — Phase 3 complete
- `ProfileHeaderView.swift`: swapped `friendshipStatus: ProfileFriendshipStatus` prop for `relation: FriendshipRelation`. Replaced single `onActionTapped` with 6 discrete callbacks (`onEditProfile`, `onAddFriend`, `onCancelRequest`, `onAcceptRequest`, `onDeclineRequest`, `onRemoveFriend`). Added `@State showCancelDialog` / `showRemoveDialog` for destructive confirmation flows. Rewrote `actionButton` to branch on `relation`: `.none` → primary "Add Friend"; `.outgoingPending` → ghost "Sent" → cancel confirmation dialog; `.incomingPending` → primary Accept + ghost Decline stacked; `.friends` → secondary checkmark → remove confirmation dialog; `.blocked` → disabled ghost "Unavailable".
- `PrivateProfileView.swift`: same prop swap (no edit/remove callbacks since unreachable). `.none` / `.outgoingPending` / `.incomingPending` branches mirror the header; `.friends` defensively disabled; `.blocked` disabled ghost.
- `ProfileView.swift`: replaced `viewModel.friendshipStatus != .friends` with `!viewModel.isFriendsRelation`. Updated `PrivateProfileView` and `ProfileHeaderView` call sites to pass `relation: viewModel.relation` plus the discrete callbacks, each wrapping the matching VM method in `Task { await }`.
- `ProfileViewModel.swift`: deleted the Phase 2 back-compat shims — both the in-class `var friendshipStatus: ProfileFriendshipStatus` computed property and the file-scope `enum ProfileFriendshipStatus` block at the bottom of the file.
- Grep audit: `grep -rn 'ProfileFriendshipStatus\|friendshipStatus' Xomfit/` returns zero matches.
- `XomButton` variants (`.primary`, `.secondary`, `.ghost`, `.destructive`) exist in `Xomfit/Views/Common/XomButton.swift` and were used as-is — no adaptation needed.
- Build: `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17' build` → **BUILD SUCCEEDED**.

### 2026-04-17 — Phase 4 complete
- Created `Xomfit/ViewModels/FriendsViewModel.swift` (`@MainActor @Observable`) owning friends list, incoming/outgoing requests, profile caches (friend/requester/addressee), search state (`searchQuery`, `searchResults`, `searchRelations`, `isSearching`), and `errorMessage`.
- `loadAll(userId:)` parallel-fetches friends + incoming + outgoing via `async let`, then hydrates profile caches per list. `performSearch(query:userId:)` calls `FriendsService.searchUsers` then `batchRelations` to pre-color each row. `clearSearch()` helper resets search state when the query empties.
- Mutation methods (`sendRequest`, `cancelRequest`, `acceptRequest`, `declineRequest`, `removeFriend`) all update `searchRelations[otherUserId]` locally so the search row reflects state without a refetch. `sendRequest` also appends a synthetic `FriendRow` to `outgoingRequests` + caches the searched profile as the addressee so the Sent section renders immediately; catches `FriendError.alreadyExists` and reconciles the actual relation from the error payload.
- Rewrote `Xomfit/Views/Friends/FriendsView.swift`: view holds `@State private var vm = FriendsViewModel()` + `searchTask`; uses `.task` + `.refreshable` to call `loadAll`; alert is `nil`-binding-bridged to `vm.errorMessage`; search `TextField` bound to `$vm.searchQuery` via `@Bindable` and debounces 300ms before calling `performSearch`; empty query calls `vm.clearSearch()`.
- Section structure: **three separate top-level sections** — "Incoming" (conditional), "Sent" (conditional), "Friends (count)" (always, shows empty-state text if `friends.isEmpty`). Deviated from the plan's nested "Requests → Incoming/Sent" wrapper in favor of three sibling sections — cleaner for SwiftUI `List` and matches the plan's "pragmatic interpretation" note.
- `SearchResultRow` is now stateless (no `@State requested`) — takes `relation` + four callbacks + local `@State showCancelDialog` for the cancel confirmation. Renders: `.none` → primary "Add", `.outgoingPending` → ghost "Sent" → dialog → Cancel Request, `.incomingPending` → vertical Accept primary + small Decline destructive, `.friends` → disabled "Friends" pill, `.blocked` → `EmptyView` (rows also filtered upstream).
- New file-local `OutgoingRequestRow` mirrors `PendingRequestRow` layout with a single destructive "Cancel" button wrapped in the same `.confirmationDialog` pattern.
- Blocked users filtered out of `searchResults` in the `ForEach` via `filter { ... if case .blocked = ... }`.
- All buttons have `.accessibilityLabel` for VoiceOver; 300ms search debounce preserved.
- pbxproj: **no edit needed** — `grep -c "ProfileViewModel.swift" Xomfit.xcodeproj/project.pbxproj` → `0` and the project uses `PBXFileSystemSynchronizedRootGroup` (7 occurrences). New Swift files auto-discover.
- Build: `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17' build` → **BUILD SUCCEEDED** (no warnings from new files).

### 2026-04-17 — Phase 5 complete
- `OnboardingFriendsScreen.swift`: removed `@State sentRequests: Set<String>`. Added `@State relations: [String: FriendshipRelation]`, `errorMessage`, `cancelTargetId`, `showCancelDialog`.
- `debouncedSearch(_:)` now calls `FriendsService.shared.batchRelations` right after `searchUsers` to pre-hydrate row buttons, and surfaces any caught error via `errorMessage` (previously silently swallowed). Clearing the search query also resets `relations`.
- Rewrote `sendRequest(to:)` with optimistic `FriendshipRelation.outgoingPending(friendshipId: "pending")` placeholder → real id on success; catches `FriendError.alreadyExists` and reflects the actual relation; on other errors reverts to `.none` and surfaces `errorMessage`.
- Added `cancelRequest(targetId:friendshipId:)`, `acceptRequest(_:friendshipId:)`, `declineRequest(_:friendshipId:)` mirroring the error-handling pattern. Cancel short-circuits local state back to `.none` when `friendshipId == "pending"` (no server row to DELETE yet).
- New `actionView(for:relation:)` `@ViewBuilder` renders the per-relation button states using the same primary/ghost/disabled pill styling as `FriendsView.SearchResultRow` (Phase 4): `.none` → primary "Add"; `.outgoingPending` → ghost "Sent" → opens shared `.confirmationDialog`; `.incomingPending` → stacked Accept primary + Decline destructive text button; `.friends` → disabled "Friends" pill; `.blocked` → `EmptyView` (rows also filtered at the `ForEach` level).
- Top-level `VStack` now owns a `.confirmationDialog` (keyed on `showCancelDialog`/`cancelTargetId`) and a `.alert` bound to `errorMessage` via a nil-binding bridge.
- All action buttons carry `.accessibilityLabel` for VoiceOver parity with `FriendsView`.
- Build: `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17' build` → **BUILD SUCCEEDED**.
