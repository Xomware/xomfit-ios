# Plan: Friends Bugs (#235)

**Status**: Ready
**Created**: 2026-04-16
**Last updated**: 2026-04-17
**Issue**: Xomware/xomfit-ios#235

> **Clean sweep** — all known friend-system issues are addressed in this plan. No follow-ups are deferred.

## Summary
The friend system is broken end-to-end: search is incomplete, tapping Add creates duplicate pending rows, there's no way to cancel an outgoing request, profile headers ignore who initiated a pending relationship, and `declined`/`blocked` statuses are silently ignored. This plan unifies friendship state behind a single `FriendshipRelation` enum, adds the missing service methods (cancel, outgoing fetch, batch relation hydration), hardens `sendFriendRequest` against duplicates, rebuilds the UI (FriendsView, ProfileHeader, PrivateProfile, OnboardingFriends) around direction-aware state with confirmation dialogs for destructive actions, surfaces all swallowed errors, and deletes the legacy mock models that misrepresent the data shape.

## Problem Statement

### User report
> Search doesn't show everyone. Can hit Add/Request but it "doesn't hold up" — reverts, can re-request infinitely. No way to unrequest / cancel an outgoing pending request. Confusing UX.

### Root causes (pre-analyzed, not re-researched)
1. **`FriendsService.fetchFriends` is accepted-only** — it filters `.eq("status", value: "accepted")`. `ProfileViewModel.loadFriendshipStatus` calls `fetchFriends(userId: currentUserId)` which returns zero rows when the relation is pending (outgoing or incoming). Result: `friendshipStatus` resolves to `.none` on every profile visit, the Add Friend button re-appears, user taps again, DB rejects via the UNIQUE constraint, error alert pops. This is the primary driver of the "keep re-requesting" UX bug.
2. `FriendsService.sendFriendRequest` is a raw `.insert()` with no pre-check — tapping Add relies on DB rejection and surfaces cryptic errors instead of reflecting existing state.
3. `FriendsView.SearchResultRow` flips `@State requested = true` **before** the insert Task runs, so the row shows "Sent" even when the DB rejects with a UNIQUE violation. Error alert fires but local state is stale.
4. `ProfileViewModel.friendshipStatus` is `.none / .pending / .friends` — no direction, can't tell "I sent it" from "they sent it".
5. No `cancelFriendRequest` service method, no `fetchOutgoingRequests`, no outgoing-pending UI.
6. `ProfileHeaderView` action button — `.pending` and `.friends` taps call `onActionTapped` but `ProfileView` only wires `.none` → send. Pending/Friends taps are no-ops.
7. `OnboardingFriendsScreen` uses its own `sentRequests: Set<String>` — not unified with the rest of the app — and its `sendRequest` catches errors silently, removing from `sentRequests` without ever surfacing the failure to the user.
8. `FriendsView.performSearch` swallows search errors silently (no `errorMessage` path).
9. `PrivateProfileView` has its own send-request button needing the same cancel affordance.
10. Schema allows `status IN ('pending', 'accepted', 'declined', 'blocked')` — the app handles only `pending` and `accepted`. `declined` and `blocked` rows are silently invisible.
11. `Xomfit/Models/Friendship.swift` and `Xomfit/Models/FriendRequest.swift` are unused legacy mock-only models with the wrong shape vs `FriendRow`. They mislead future engineers.

### DB constraints (confirmed — no migration needed)
The `friendships` table already enforces `UNIQUE(requester_id, addressee_id)` and `CHECK status IN ('pending','accepted','declined','blocked')` at `supabase/migrations/20260312_core_tables.sql:137` (also mirrored in `20260312_all_tables.sql:59`). The "keep requesting" bug is **purely client-side**. No DB migration is part of this plan.

## User Decisions (LOCKED)

| # | Decision |
|---|---|
| 1 | Cancel outgoing: tap "Sent" button → `.confirmationDialog` to cancel (matches existing destructive-dialog pattern). |
| 2 | Incoming pending on someone's profile: header shows inline Accept (primary) + Decline (destructive) — live status. |
| 3 | FriendsView organization: top "Requests" section with Incoming + Sent subsections, then Friends section below. |
| 4 | Search results pre-hydrate relationship status — each row shows Add / Sent / Respond / Friends based on current DB state. |
| 5 | Remove friend: ProfileHeader "Friends" button → `.confirmationDialog` → delete friendship row. |
| 6 | Search-row Respond UX: compact **Accept** primary pill with a small **Decline** button below it — mirrors `ProfileHeaderView` behavior for visual consistency. |

## Approach

Introduce a direction-aware `FriendshipRelation` enum as the single source of truth for any 2-user relationship, covering all four DB status values. Push logic from views into view models. Hydrate lists in batches so UI reflects real DB state instead of optimistic local flags. Wire all destructive actions (cancel request, remove friend) through `.confirmationDialog` for consistency. Surface every caught error to the user.

Work is structured in 6 phases — each phase must compile and stay shippable. Phases map to commits inside a single PR so reviewers can read them in order.

## Affected Files / Components

| File / Component | Change | Why |
|---|---|---|
| `Xomfit/Services/FriendsService.swift` | Add `FriendshipRelation` enum, `relation(...)`, `batchRelations(...)`, `fetchOutgoingRequests(...)`, `cancelFriendRequest(...)`. Harden `sendFriendRequest` with dedupe + return new id. Map `declined`/`blocked` statuses. | Direction-aware state + missing service methods + full status coverage. |
| `Xomfit/ViewModels/ProfileViewModel.swift` | Replace `friendshipStatus: ProfileFriendshipStatus` with `relation: FriendshipRelation`. Add `cancelRequest`, `acceptIncoming`, `declineIncoming`, `removeFriend` methods. Delete `ProfileFriendshipStatus` type. | ViewModel drives all mutations, views stay dumb. |
| `Xomfit/Views/Profile/ProfileHeaderView.swift` | Switch `friendshipStatus` prop to `relation`. Render direction-aware action button with confirmation dialogs; handle blocked as hidden/neutral. | Respect direction, surface Respond/Cancel/Remove. |
| `Xomfit/Views/Profile/PrivateProfileView.swift` | Same prop swap, same dialog-driven affordances. | Parity with public profile header. |
| `Xomfit/Views/Profile/ProfileView.swift` | Pass 5 discrete callbacks down; each calls the matching VM method. | Replace dead-code branches where `.pending`/`.friends` taps were no-ops. |
| `Xomfit/Views/Friends/FriendsView.swift` | Extract logic to new `FriendsViewModel`. Rebuild sections: Search → Requests (Incoming + Sent) → Friends. `SearchResultRow` becomes stateless and takes a `FriendshipRelation`. Surface search errors. | Fix spam bug, reflect real state, match decisions 3/4/6. |
| `Xomfit/ViewModels/FriendsViewModel.swift` (new) | `@Observable` view model owning lists, search, mutations. | MVVM compliance; current view is all inline `@State`. |
| `Xomfit/Views/Onboarding/OnboardingFriendsScreen.swift` | Swap local `sentRequests: Set<String>` for `[String: FriendshipRelation]` loaded via `batchRelations`. Row button reflects relation. Surface errors via alert/toast. | Unified state across the app; no silent failures. |
| `Xomfit/Models/Friendship.swift` (delete) | Unused mock-only model with wrong shape. | Dead code; misleading. |
| `Xomfit/Models/FriendRequest.swift` (delete) | Unused mock-only model with wrong shape. | Dead code; misleading. |

## Phase 1 — Service + Model Layer

**Files touched**
- `Xomfit/Services/FriendsService.swift`

**Concrete changes**
- Add (file-level, public) enum covering all four DB status values plus direction:
  ```
  enum FriendshipRelation: Equatable {
      case none
      case outgoingPending(friendshipId: String)
      case incomingPending(friendshipId: String)
      case friends(friendshipId: String)
      case blocked(friendshipId: String, blockedByCurrentUser: Bool)
  }
  ```
- Add error case:
  ```
  enum FriendError: Error {
      case alreadyExists(relation: FriendshipRelation)
  }
  ```
- New methods on `FriendsService`:
  - `func relation(currentUserId: String, otherUserId: String) async throws -> FriendshipRelation`
    - Single query: `friendships` where `(requester_id == a AND addressee_id == b) OR (requester_id == b AND addressee_id == a)`. Use Supabase `.or()` filter. Map the row → enum:
      - `status == 'pending'` + `requester_id == currentUserId` → `.outgoingPending(id)`
      - `status == 'pending'` + `addressee_id == currentUserId` → `.incomingPending(id)`
      - `status == 'accepted'` → `.friends(id)`
      - `status == 'declined'` → **`.none`** (treat as if no row — user may re-request; the declined row will be cleared by the next insert path).
      - `status == 'blocked'` → `.blocked(id, blockedByCurrentUser: requester_id == currentUserId)`.
  - `func batchRelations(currentUserId: String, otherUserIds: [String]) async throws -> [String: FriendshipRelation]`
    - Two queries: rows where `requester_id == currentUserId AND addressee_id IN (...)`, and rows where `addressee_id == currentUserId AND requester_id IN (...)`. Merge into `[otherUserId: FriendshipRelation]` using the same mapping rules. Any userId not in the dict is `.none` at call site. Declined rows are dropped (mapped to no entry).
  - `func fetchOutgoingRequests(userId: String) async throws -> [FriendRow]`
    - `WHERE requester_id = userId AND status = 'pending'`.
  - `func cancelFriendRequest(friendshipId: String) async throws`
    - Internally calls the same DELETE as `declineFriendRequest` — separate name for call-site clarity.
- Harden `sendFriendRequest(fromUserId:toUserId:) async throws -> String`:
  1. Call `relation(currentUserId: fromUserId, otherUserId: toUserId)`.
  2. If result is `.none`, insert and return the new friendship id.
  3. If result is `.blocked`, throw `FriendError.alreadyExists(relation: .blocked(...))` — caller suppresses UI.
  4. Otherwise throw `FriendError.alreadyExists(relation: result)`.
  5. If a stale `declined` row was returned from the DB (should not happen per mapping — declined rows are ignored in step 1), delete it before insert to keep the UNIQUE constraint happy. Document this edge case inline.

**Acceptance check**
- Build Xomfit scheme — no errors.
- Manual REPL: Call `sendFriendRequest` twice in a row — second call throws `.alreadyExists`; only one pending row in DB (DB-UNIQUE confirms).
- `relation` returns `.outgoingPending` when viewing a user you requested, `.incomingPending` when viewing a user who requested you, `.none` when the only row is `declined`, `.blocked` when status is blocked.

## Phase 2 — ProfileViewModel

**Files touched**
- `Xomfit/ViewModels/ProfileViewModel.swift`

**Concrete changes**
- Remove the `ProfileFriendshipStatus` enum declaration entirely (it lives at the top of this file).
- Replace stored property `var friendshipStatus: ProfileFriendshipStatus = .none` with `var relation: FriendshipRelation = .none`.
- Rewrite `loadFriendshipStatus(currentUserId:targetUserId:)` to call `FriendsService.shared.relation(...)` and assign to `relation`. Rename method to `loadRelation(...)` for clarity (update call sites).
- Update the privacy gate in `loadAll(...)`:
  ```
  if isPrivate && !isFriendsRelation { isLoading = false; return }
  ```
  where `isFriendsRelation` is a derived computed property: `if case .friends = relation { true } else { false }`.
- New methods:
  - `func sendFriendRequest(fromUserId:toUserId:)` — update existing to assign `relation = .outgoingPending(friendshipId: <id from service>)` on success.
  - `func cancelRequest()` — reads `.outgoingPending(let id)` off `relation`, calls `cancelFriendRequest(friendshipId: id)`, sets `relation = .none`.
  - `func acceptIncoming()` — reads `.incomingPending(let id)`, calls `acceptFriendRequest(...)`, sets `relation = .friends(friendshipId: id)`.
  - `func declineIncoming()` — reads `.incomingPending(let id)`, calls `declineFriendRequest(...)`, sets `relation = .none`.
  - `func removeFriend()` — reads `.friends(let id)`, calls `removeFriend(friendshipId: id)`, sets `relation = .none`.
- All new methods set `errorMessage` on failure — no silent swallows.

**Acceptance check**
- Build passes.
- Open another user's profile — `relation` is loaded correctly before UI renders; outgoing pending is correctly identified.
- Simulate each action — `relation` transitions as expected; errors surface via `errorMessage`.

## Phase 3 — ProfileHeaderView + PrivateProfileView + ProfileView

**Files touched**
- `Xomfit/Views/Profile/ProfileHeaderView.swift`
- `Xomfit/Views/Profile/PrivateProfileView.swift`
- `Xomfit/Views/Profile/ProfileView.swift`

**Concrete changes**

`ProfileHeaderView`:
- Replace `let friendshipStatus: ProfileFriendshipStatus` with `let relation: FriendshipRelation`.
- Replace `onActionTapped: () -> Void` with discrete callbacks:
  - `onAddFriend: () -> Void`
  - `onCancelRequest: () -> Void`
  - `onAcceptRequest: () -> Void`
  - `onDeclineRequest: () -> Void`
  - `onRemoveFriend: () -> Void`
  - Keep `onEditProfile: () -> Void` for the own-profile case.
- Rewrite `actionButton`:
  - `isOwnProfile` → "Edit Profile" → `onEditProfile`.
  - `.none` → primary "Add Friend" → `onAddFriend`.
  - `.outgoingPending` → ghost "Sent" → tap flips `@State showCancelDialog = true`. `.confirmationDialog("Cancel request?", isPresented: $showCancelDialog, titleVisibility: .visible) { Button("Cancel Request", role: .destructive) { onCancelRequest() }; Button("Keep", role: .cancel) {} }`.
  - `.incomingPending` → inline two-button row: primary "Accept" → `onAcceptRequest`; destructive "Decline" below/adjacent → `onDeclineRequest`. Use existing `XomButton` variants.
  - `.friends` → secondary "Friends" with checkmark → tap flips `@State showRemoveDialog = true` → confirmation dialog "Remove friend?" → destructive "Remove" calls `onRemoveFriend`.
  - `.blocked` → render a neutral disabled "Unavailable" chip (or hide the action row entirely if `blockedByCurrentUser == false`). No actionable buttons from this screen.

`PrivateProfileView`:
- Replace `friendshipStatus` prop with `relation`. Replace `onSendRequest` with the same 4 relation callbacks used by header (minus edit).
- Button states mirror header: `.none` → "Send Friend Request"; `.outgoingPending` → "Request Sent" → tap → cancel dialog; `.incomingPending` → Accept + Decline; `.friends` shouldn't be reachable here (private gate passes through if friends), but handle defensively with a "Friends" chip; `.blocked` → Unavailable chip.

`ProfileView`:
- Remove the single `onActionTapped` dispatcher; pass the 5 discrete callbacks down, each calling the matching VM method wrapped in `Task { await vm.xxx() }`.
- Ensure feed/stats re-render on `relation` change (automatic via `@Observable`).
- Verify both entry points to `ProfileView` (tab root for self, pushed for other users) route mutations through the VM.

**Acceptance check**
- Open a user you haven't interacted with → Add Friend works.
- After Add, header shows Sent — tap → confirmation dialog → Cancel Request → header reverts to Add Friend; DB row gone.
- From user B's account, send to user A — open B's profile from A → header shows Accept + Decline. Tap Accept → header shows Friends.
- Tap Friends → confirmation dialog → Remove → header reverts to Add Friend.
- Private account: same flow works on `PrivateProfileView`.
- Blocked user: header shows neutral state with no action buttons.

## Phase 4 — FriendsView + FriendsViewModel

**Files touched**
- `Xomfit/Views/Friends/FriendsView.swift`
- `Xomfit/ViewModels/FriendsViewModel.swift` (new)

**Concrete changes**

New `FriendsViewModel` (`@Observable @MainActor`):
- Stored:
  - `friends: [FriendRow]`
  - `incomingRequests: [FriendRow]`
  - `outgoingRequests: [FriendRow]`
  - `friendProfiles: [String: ProfileRow]`
  - `requesterProfiles: [String: ProfileRow]` (for incoming rows)
  - `addresseeProfiles: [String: ProfileRow]` (for outgoing rows)
  - `searchResults: [ProfileRow]`
  - `searchRelations: [String: FriendshipRelation]`
  - `searchQuery: String`
  - `isLoading: Bool`
  - `isSearching: Bool`
  - `errorMessage: String?`
- Methods:
  - `loadAll(userId:)` — parallel fetch of friends, incoming, outgoing, then batch-load profiles.
  - `performSearch(query:userId:)` — calls `searchUsers` then `batchRelations` for the result ids. **On error, sets `errorMessage`** (no silent swallow).
  - `sendRequest(fromUserId:toUserId:)` — calls service, then updates `searchRelations[toUserId] = .outgoingPending(id:)` and appends to `outgoingRequests`. On error sets `errorMessage`.
  - `cancelRequest(friendshipId:)`, `acceptRequest(friendshipId:)`, `declineRequest(friendshipId:)`, `removeFriend(friendshipId:)` — each reconciles the right list after the mutation, updates `searchRelations` entry if applicable. Errors surface via `errorMessage`.

`FriendsView`:
- Replace all `@State` data lists with `@State private var vm = FriendsViewModel()`.
- Bind `.alert(item: errorMessage)` or similar to surface `vm.errorMessage`.
- Section order when `searchQuery` is empty:
  1. **Requests** section — header "Requests". If `incomingRequests` non-empty, subsection label "Incoming" + rows. If `outgoingRequests` non-empty, subsection label "Sent" + rows. Entire section hidden if both empty.
  2. **Friends** section — header "Friends (count)".
- Section when `searchQuery` is non-empty:
  - Search results. Each row stateless, receives `FriendshipRelation` from `vm.searchRelations[profile.id] ?? .none`. Row button:
    - `.none` → "Add" (primary pill).
    - `.outgoingPending` → "Sent" pill. Tap → inline `.confirmationDialog` on the row to cancel.
    - `.incomingPending` → compact **Accept** primary pill with a small **Decline** button below it (decision #6) — mirrors `ProfileHeaderView` behavior.
    - `.friends` → "Friends" disabled pill.
    - `.blocked` → row hidden entirely (don't show blocked users in search).
- `SearchResultRow` becomes stateless — removes `@State private var requested`. Takes `relation: FriendshipRelation` + callbacks (`onAdd`, `onCancel`, `onAccept`, `onDecline`).
- New `OutgoingRequestRow` component mirroring `PendingRequestRow` but with a single "Cancel" destructive button (wrapped in confirmation dialog).
- After any mutation: prefer local reconciliation over full reload, fall back to reload on error.

**Acceptance check**
- Launch FriendsView when you have no incoming/outgoing → "Requests" section hidden.
- With incoming-only → section shows only "Incoming" subsection.
- With both → both subsections visible under a single "Requests" header.
- Search a username → each result shows correct button (Add / Sent / Respond / Friends) based on DB.
- Tap Add → row updates to Sent without refetch; tap Sent → confirmation → Cancel → row reverts to Add.
- Send a request, then have the other user send back (or vice versa) — search result changes to Respond/Friends without relaunching.
- Search error (simulate by killing the network mid-query) → alert surfaces `vm.errorMessage`.

## Phase 5 — OnboardingFriendsScreen

**Files touched**
- `Xomfit/Views/Onboarding/OnboardingFriendsScreen.swift`

**Concrete changes**
- Remove `@State private var sentRequests: Set<String>`.
- Add `@State private var relations: [String: FriendshipRelation] = [:]` and `@State private var errorMessage: String?`.
- After `performSearch` returns results, call `FriendsService.shared.batchRelations(currentUserId: userId, otherUserIds: results.map { $0.id })` and merge into `relations`.
- `userRow(_:)` reads `relations[user.id] ?? .none` and renders:
  - `.none` → "Add" pill → `sendRequest(to:)`.
  - `.outgoingPending` → "Sent" pill → tap → confirmation dialog → cancel.
  - `.incomingPending` → compact Accept primary + small Decline (decision #6).
  - `.friends` → "Friends" disabled pill.
  - `.blocked` → row hidden.
- `sendRequest(to:)` — optimistically set `relations[targetId] = .outgoingPending(friendshipId: "pending")` (placeholder id), call service, on success replace with real id from the service return value. **On error set `errorMessage`** and revert the relation to `.none` — do not swallow silently.
- Bind an alert to `errorMessage`.
- Apply the same error-surfacing fix to the onboarding `performSearch` function.

**Acceptance check**
- Onboarding search + add behaves identically to FriendsView search.
- If a user already has outgoing/incoming with a result, the correct button shows on first render.
- Trigger a failing request (kill network) — alert appears, row reverts, no silent failure.

## Phase 6 — Cleanup

**Files touched / deleted**
- Delete `Xomfit/Models/Friendship.swift`
- Delete `Xomfit/Models/FriendRequest.swift`
- Delete `ProfileFriendshipStatus` type from `Xomfit/ViewModels/ProfileViewModel.swift` (done in Phase 2 — re-verify here).

**Pre-deletion grep checklist** (run before deleting each file — all must return zero non-mock references):
- [ ] `grep -rn "Friendship" Xomfit/ --include='*.swift' | grep -v "Friendship.swift" | grep -v "FriendshipRelation" | grep -v "friendshipId"` → expected: zero matches that reference the type `Friendship` from the deleted model.
- [ ] `grep -rn "FriendRequest" Xomfit/ --include='*.swift' | grep -v "FriendRequest.swift"` → expected: zero matches.
- [ ] `grep -rn "ProfileFriendshipStatus" Xomfit/ --include='*.swift'` → expected: zero matches.
- [ ] `grep -rn "friendshipStatus" Xomfit/ --include='*.swift'` → expected: zero matches (all renamed to `relation`).

**Post-deletion audit** (confirms the clean sweep):
- [ ] Audit all 4 call sites of `FriendsService.sendFriendRequest` (FriendsView/VM, ProfileView/VM, OnboardingFriendsScreen, PrivateProfileView) — each uses the new `-> String` return value and handles `FriendError.alreadyExists` explicitly.
- [ ] Verify `ProfileView` as tab-root (self profile) and pushed (other-user profile) both route the new mutation callbacks through `ProfileViewModel`.
- [ ] `xcodebuild -scheme Xomfit` passes with zero warnings from deleted files.

**Commit**: `#235 remove legacy Friendship/FriendRequest models after FriendshipRelation migration`.

## Do-Not-Change List

- `friendships` DB schema — already has `UNIQUE(requester_id, addressee_id)` and `CHECK status IN ('pending','accepted','declined','blocked')`. No migration needed.
- `SocialFeedItem` model — separate concern.
- Any notification code — separate concern; out of scope here.
- `ProfileService` — no changes.
- Other profile fields / tabs / feed logic.

## Implementation Steps

- [x] **Phase 1** — Add `FriendshipRelation`, new service methods, harden `sendFriendRequest`. Commit: `#235 add FriendshipRelation enum and direction-aware friend service methods`.
- [x] **Phase 2** — Replace `ProfileFriendshipStatus` with `FriendshipRelation` in `ProfileViewModel`; add cancel/accept/decline/remove methods. Commit: `#235 switch ProfileViewModel to FriendshipRelation`.
- [x] **Phase 3** — Update `ProfileHeaderView`, `PrivateProfileView`, `ProfileView` to use relation + discrete callbacks + confirmation dialogs. Commit: `#235 direction-aware profile header with cancel/remove confirmation dialogs`.
- [x] **Phase 4** — Extract `FriendsViewModel`; rebuild `FriendsView` with Requests (Incoming + Sent) + Friends sections; make `SearchResultRow` stateless and relation-driven; surface search errors. Commit: `#235 restructure FriendsView with FriendsViewModel and hydrated search`.
- [x] **Phase 5** — Unify `OnboardingFriendsScreen` with `batchRelations`; surface swallowed errors. Commit: `#235 hydrate onboarding friend search with real relations and surface errors`.
- [x] **Phase 6** — Delete legacy `Friendship.swift` + `FriendRequest.swift`; final grep audit. Commit: `#235 remove legacy Friendship/FriendRequest models after FriendshipRelation migration`.
- [ ] Manual test pass against the Test Plan below.
- [ ] Open PR against `develop` with `Closes #235`.
- [ ] Update XomBoard status to In Review on PR open.

## Test Plan (Manual)

No automated test coverage in this project — manual verification on iPhone 16 simulator + device.

Two test accounts required: **User A** and **User B**. A third account **User C** helps for blocked-state testing.

### T1 — Send + cancel (outgoing)
1. User A opens User B's profile → taps "Add Friend".
2. Button changes to "Sent".
3. Tap "Sent" → confirmation dialog appears ("Cancel request?").
4. Tap "Cancel Request" → button reverts to "Add Friend".
5. DB: zero `friendships` rows between A and B.

### T2 — Duplicate prevention
1. User A sends request to User B.
2. Close profile, reopen.
3. Button shows "Sent" (not "Add Friend") — relation is loaded from DB.
4. No way to send a second request (button is "Sent" not "Add").
5. DB: exactly one pending row (DB UNIQUE constraint confirms).

### T3 — Receive + respond
1. User A requests User B.
2. User B opens User A's profile → button shows "Accept" primary + "Decline" destructive.
3. Tap "Accept" → button becomes "Friends" checkmark. Header on User A side (if open) updates to "Friends" on next refresh.
4. DB: row status is `accepted`.

### T4 — Decline + re-request
1. User A requests User B.
2. User B declines → B's profile for A reverts to "Add Friend".
3. **User A can immediately send a new request** (declined row is deleted by service, not archived — `FriendsService.declineFriendRequest` DELETEs).
4. DB after re-request: one pending row.

### T5 — Remove friend + re-request
1. From the "Friends" state, tap "Friends" button → confirmation dialog.
2. Tap "Remove" → button becomes "Add Friend".
3. DB: zero rows.
4. Immediately send again → succeeds; one pending row.

### T6 — FriendsView sections
1. With no requests: only Friends section visible.
2. With incoming only: Requests section visible with Incoming subsection only.
3. With outgoing only: Requests section with Sent subsection only.
4. With both: Requests section with both subsections.

### T7 — Search hydration
1. User A search for User B (no relation) → shows "Add".
2. Send → row flips to "Sent" without re-search.
3. Clear search, reopen search with same query → row still "Sent".
4. User B has sent A a request → A searches B → row shows Accept + Decline (compact).

### T8 — PrivateProfileView
1. User B sets profile to private.
2. User A opens B's profile → `PrivateProfileView` with "Send Friend Request".
3. Send → "Request Sent", tap → cancel dialog, cancel works.
4. User B accepts (from their FriendsView) → User A's next open of B's profile loads the full profile (not private view).

### T9 — OnboardingFriendsScreen
1. Create a fresh account with an existing friend relationship pre-seeded (or send from another device first).
2. On onboarding friends screen, search — the known relation renders correctly (Friends / Sent / Respond), not a bare "Add".
3. Kill network, attempt to send from onboarding → alert surfaces the error; row does not stay in "Sent" state.

### T10 — Race condition (two devices)
1. User A on device 1, User A on device 2 — both open User B's profile simultaneously.
2. Both tap "Add Friend" at the same time.
3. One succeeds; the other surfaces a friendly error ("Request already sent") via `FriendError.alreadyExists`.
4. DB: exactly one pending row.

### T11 — Blocked user
1. Mark User C as blocked in DB (manual — no UI for this yet).
2. User A opens User C's profile → header shows neutral "Unavailable" chip, no Add button.
3. User A searches for User C → User C does not appear in search results.

### T12 — Swallowed error surfaces
1. Kill network.
2. `FriendsView` search → alert appears with `errorMessage`.
3. `OnboardingFriendsScreen` send → alert appears with `errorMessage`.
4. Re-enable network, retry → succeeds.

### T13 — Build integrity
- `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'` after each phase commit — zero errors, no new warnings.
- After Phase 6: no references to deleted `Friendship`, `FriendRequest`, or `ProfileFriendshipStatus` types.

## Risks / Tradeoffs

- **Race conditions on rapid tap**: addressed by `FriendError.alreadyExists` being thrown from the service pre-check AND the DB UNIQUE constraint as a backstop. T10 verifies.
- **Service signature change** for `sendFriendRequest` (returns id now) — safe because we control all call sites (FriendsView, ProfileView, OnboardingFriendsScreen, PrivateProfileView) and Phase 6 audit confirms.
- **Removing `ProfileFriendshipStatus` + legacy models**: grep checklist in Phase 6 guarantees zero dangling references before deletion.
- **Batch relation query perf**: `batchRelations` issues 2 queries with `.in()` filters. Fine at current scale (<100 search results). Revisit if search grows.
- **Confirmation dialog UX**: an extra tap for cancel matches existing app pattern (Discard Workout, FriendListRow swipe-remove) — consistency wins.
- **Blocked status UX**: chose to hide blocked users from search and show neutral chip on their profile. Alternative (show "Blocked" explicitly) rejected — reveals info the blocker may not want exposed. Document if product wants to revisit.

## Rollout Notes
- Single PR against `develop`, reviewed as 6 commits.
- No migrations, no env vars, no feature flag.
- Merge to `develop` → QA → promote to `master` via normal release flow.

## Open Questions

_None — all previously open questions are resolved:_
- Search-row "Respond" UX → decision #6: compact Accept primary + small Decline below it.
- DB unique constraint → already exists at `supabase/migrations/20260312_core_tables.sql:137`. No follow-up needed.

## Skills / Agents to Use
- **ios-standards skill**: consult for SwiftUI conventions (`@Observable`, `.confirmationDialog`, `NavigationStack`) before each phase.
- **ios-build skill** (if present) / direct `xcodebuild`: run after each phase commit to catch compile errors early.
- **pr-author agent**: when opening the PR — use `Closes #235` in the description and summarize the 6-commit breakdown.
- **xomboard-update agent / skill**: move issue #235 through Backlog → In Progress on first commit, In Review on PR open, Done on merge.
