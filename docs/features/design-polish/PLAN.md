# Plan: Design Polish — Visual Overhaul (Whoop/Oura premium dark + Strava/Hevy data density)

**Status**: Done
**Created**: 2026-04-16
**Last updated**: 2026-04-16

## Summary
A full-app visual overhaul of XomFit that trades the current indigo-tinted dark theme, drop-shadowed cards, and punchy neon-green chrome for a premium cinematic dark palette (Whoop/Oura lane) with data-dense legibility (Strava/Hevy lane) on the workout and stats surfaces. Shipped in six buildable, independently-mergeable PRs starting at the token layer and rolling up through chrome, social, profile, workout, and remaining surfaces. Success = every screen reads "premium fitness app" at a glance, and the data-heavy surfaces stay scannable under heavy load.

## Approach
Honor `docs/features/design-polish/RESEARCH.md` wholesale — the audit is correct, the palette table in §3 is the source of truth, and the priority ranking in §4 drives phase ordering. Lane B (premium dark) is the baseline language; Lane A (data density) is layered in on Active Workout, Profile Stats, PRs, Leaderboard, and Progress where numbers are the content. No business logic, no data model, no service, no Supabase call is modified — only views, view modifiers, and tokens. Phase 1 lands the token + primitive foundation so every downstream phase is a drop-in swap instead of a rewrite.

## Do-Not-Change List
- `Xomfit/Models/**` — no data model changes
- `Xomfit/Services/**` — no service / API / Supabase changes
- `Xomfit/ViewModels/**` — no VM changes, no new `@Observable` state for business logic
- MVVM boundary — views stay dumb, no service calls from views
- Auth flow behavior (Login, SignUp, ProfileCompletion logic) — visual polish only
- Routing / `NavigationStack` structure — swap styling, not screen graph
- `Haptics` and `Animation` token contents (existing curves stay; we add, not replace)

## Phase DAG

```
P1 (Foundation: tokens + primitives)
 ├─► P2 (Chrome: tab bar, nav, global states)
 ├─► P3 (Social: FeedItemCard + Feed + Detail)
 ├─► P4 (Profile: Header, tabs, sub-views)
 ├─► P5 (Active Workout + Exercise Library)
 └─► P6 (Remaining surfaces + motion layer)

P1 blocks all.
P2, P3, P4, P5 can run in parallel after P1.
P6 requires P2–P5 merged (it polishes tail surfaces and layers motion on top of refreshed components).
```

Rationale: P1 is the single atomic swap that lifts the whole app for free (surface hex changes alone remove the indigo cast). After P1 merges, any of P2–P5 can be picked up without blocking the others because primitives are shared.

---

## Phase 1 — Foundation (tokens + primitives) ✓ DONE

**Goal**: Replace palette, typography, spacing/radius, and elevation tokens. Refine shared primitives (`XomCard`, `XomStat`, `XomAvatar`, `XomButton`, `XomEmptyState`, `XomSkeletonRow`) to consume the new tokens and introduce hairline-based elevation. After this phase, the app looks different everywhere without any call-site changes.

**Effort**: M

**Files touched (existing)**:
- `Xomfit/Utils/Theme.swift` — full rewrite of color + typography sections, add radius scale, add hairline + elevation helpers, remove colored shadows from button styles
- `Xomfit/Views/Common/XomCard.swift` — swap to hairline border, remove `glassFill` double-layer, add `variant: .base | .elevated | .hero` enum
- `Xomfit/Views/Common/XomStat.swift` — rework hierarchy: hero number (`.rounded.heavy.monospacedDigit`) + uppercase kerned label, optional trend indicator
- `Xomfit/Views/Common/XomAvatar.swift` — accept larger default sizes, tighten initials sizing, switch `showBorder` from hard-coded accent to optional `ringColor: Color?`
- `Xomfit/Views/Common/XomButton.swift` — remove accent-colored shadow, press scale 0.94 → 0.98, subtle top-to-bottom gradient overlay for depth
- `Xomfit/Views/Common/XomEmptyState.swift` — accept `symbolStack: [String]` for layered SF Symbol illustration, add `floatingLoop: Bool`
- `Xomfit/Views/Common/XomSkeletonRow.swift` — align fills with new surface token; no structural change

**New files**:
- `Xomfit/Views/Common/XomBadge.swift` — reusable pill/chip (color stripe + icon + label), used by activity badges and filter pills
- `Xomfit/Views/Common/XomDivider.swift` — the ONE hairline rule (0.5pt, `white.opacity(0.08)`)
- `Xomfit/Views/Common/XomMetricLabel.swift` — view modifier or thin wrapper that applies uppercase + 0.5 kerning + `.caption.weight(.semibold)` to metric labels
- `Xomfit/Utils/Theme+Elevation.swift` — `View.hairline(_ radius: CGFloat)` modifier + `.heroGradient(accent:)` modifier, keeps `Theme.swift` lean

**Concrete design tokens** (paste-ready — engineer plugs these into `Theme.swift`):

```swift
// MARK: - Colors (neutral near-black ramp, single accent, role-split semantics)

/// 60% — App background. Warm-neutral near-black, removes blue cast.
static let background        = Color(hex: "0B0B0E")
/// 30% — Cards. Pure luminance lift from background, same hue family.
static let surface           = Color(hex: "17171C")
/// Sheets / modals / elevated containers.
static let surfaceElevated   = Color(hex: "1F1F26")
/// DEPRECATED alias — keep for one release, migrate callers, then remove.
static let surfaceSecondary  = Color(hex: "1F1F26")

/// 10% — Primary accent (CTAs, selected states only). Desaturated from 33FF66.
static let accent            = Color(hex: "2FE562")
/// Tinted fill for accent-utility use (selected tab bg, accent chip bg).
static let accentMuted       = Color(hex: "2FE562").opacity(0.18)

/// Text — off-white, neutral greys (not blue-greys).
static let textPrimary       = Color(hex: "F5F5F7")
static let textSecondary     = Color(hex: "9A9AA3")     // ~60% luminance
static let textTertiary      = Color(hex: "6B6B72")     // ~40% — timestamps, metadata

/// Semantic colors — all desaturated a notch vs current.
static let prGold            = Color(hex: "F5C84B")     // was FFD700
static let milestone         = Color(hex: "9B7BFF")     // was AA66FF
static let streak            = Color(hex: "FF7A45")     // was FF6633
static let alert             = Color(hex: "FF8A4C")     // was FF6B35
static let destructive       = Color(hex: "FF5E5E")     // was FF4444
/// Kept for API compat; points to accent. Callers should migrate to `accent`.
static let energy            = accent

// MARK: - Hairlines (ONE rule, used everywhere borders/dividers appear)

static let hairline          = Color.white.opacity(0.08)
static let hairlineStrong    = Color.white.opacity(0.12) // selected chips, focused inputs

// MARK: - Activity badge tokens — map to semantic role colors

static let badgeWorkout      = accent
static let badgePR           = prGold
static let badgeMilestone    = milestone
static let badgeStreak       = streak

// MARK: - Spacing (8pt grid + new section rhythm)

enum Spacing {
    static let hairline: CGFloat = 0.5   // NEW
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let section: CGFloat = 40     // NEW — between major vertical sections
}

// MARK: - Corner Radius (full scale — replaces 2-value system)

enum Radius {
    static let xs: CGFloat = 6    // inline chips, pills, small badges
    static let sm: CGFloat = 10   // buttons, small cards
    static let md: CGFloat = 16   // cards (default)
    static let lg: CGFloat = 22   // sheets, modals
    static let xl: CGFloat = 28   // full-bleed hero cards
}
// Keep old tokens as deprecated aliases for one release:
static let cornerRadius      = Radius.md
static let cornerRadiusSmall = Radius.sm

// MARK: - Typography (add SF Pro Rounded for numerics; add metric label)

/// Hero display number — PRs, volume totals, hero metrics.
static let fontDisplay: Font = .system(size: 44, weight: .heavy, design: .rounded).monospacedDigit()
/// Secondary hero number — stat columns, card titles with numbers.
static let fontNumberLarge: Font = .system(size: 28, weight: .bold, design: .rounded).monospacedDigit()
/// Inline numbers — set rows, feed stat pills.
static let fontNumberMedium: Font = .system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()

static let fontLargeTitle: Font = .largeTitle.weight(.bold)
static let fontTitle:      Font = .title.weight(.bold)       // 28pt
static let fontTitle2:     Font = .title2.weight(.semibold)  // 22pt
static let fontHeadline:   Font = .title3.weight(.semibold)  // 20pt
static let fontBody:       Font = .body                      // 17pt
static let fontSubheadline: Font = .subheadline              // 15pt
static let fontCaption:    Font = .caption                   // 12pt
static let fontSmall:      Font = .caption2.weight(.medium)  // 11pt

/// Uppercase + 0.5 kerning metric label. Apply via XomMetricLabel or .metricLabel() modifier.
static let fontMetricLabel: Font = .caption.weight(.semibold)

// Weight rhythm: 300 (light not used), 400 (.regular body), 600 (.semibold emphasis), 700+ (.bold/.heavy numerics)
// Size rhythm: 44 display / 28 number-large / 22 title / 17 body / 12 label
// Spacing rhythm: 8 / 16 / 24 / 40 between stacks
```

**Acceptance criteria**:
- App builds on `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'` with zero warnings introduced by the changes
- Launching the app shows the new near-black neutral surface (no indigo tint on cards anywhere)
- Every existing call-site compiles — old `Theme.cornerRadius` / `Theme.surfaceSecondary` / `Theme.fontDisplay` continue to resolve (deprecated aliases)
- `XomCard` base variant renders with a hairline border and no drop shadow; no visible "stacked fill" ring
- `XomStat` hero number is visibly 2–2.5x the height of its label; numbers align on digits across a row
- `XomButton` primary has no colored glow; press state is a subtle 0.98 scale with no shadow shift
- `XomEmptyState` old call-sites still work (single-icon API preserved); new `symbolStack:` param available but unused
- `XomBadge`, `XomDivider`, `XomMetricLabel` compile and have SwiftUI previews

**Rollback**: `git revert` the single phase 1 PR. Whole app falls back to current palette / primitives. No data touched.

---

## Phase 2 — Chrome (tab bar, nav, global states) ✓ DONE

**Goal**: Replace the double-container floating tab bar with a single `.ultraThinMaterial` surface + hairline. Polish nav bar title treatment across tabs. Standardize global loading / empty / error / shimmer to the new token language.

**Effort**: S

**Files touched**:
- `Xomfit/Views/MainTabView.swift` — rewrite `FloatingTabBar` body: `.background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeading: Radius.lg, topTrailing: Radius.lg, ...))` + single top hairline overlay; drop the `Rectangle` + `UnevenRoundedRectangle` stacking
- `Xomfit/Views/Feed/FeedView.swift` — `toolbarColorScheme` stays; swap toolbar icon tints from `Theme.accent` to `Theme.textPrimary` (consistent with Whoop/Oura — accent is reserved for active states)
- `Xomfit/Views/Profile/ProfileView.swift` — same toolbar tint cleanup
- `Xomfit/Views/Progress/XomProgressView.swift` — same
- `Xomfit/Views/Workout/WorkoutView.swift` — same
- `Xomfit/Utils/Theme.swift` — update `ShimmerModifier` to soft radial diagonal sweep (not linear), reduce overlay opacity to `white.opacity(0.06)`
- `Xomfit/Views/Common/XomFitLoader.swift` — verify against new palette; tint logo strokes to `accent` at new hex

**New files**:
- `Xomfit/Views/Common/XomErrorState.swift` — reusable error container built on `XomEmptyState`: warning glyph, concise copy, retry CTA. Replaces ad-hoc `errorView(message:)` helpers sprinkled in tab roots
- `Xomfit/Views/Common/XomToolbarTitle.swift` — optional helper for a consistent inline-title + subtitle treatment (used by detail views that want a two-line nav title)

**Acceptance criteria**:
- Tab bar renders as a single `.ultraThinMaterial` layer with a single 0.5pt top hairline; no visible double background against any tab content
- Tab bar respects safe-area insets on notched + home-indicator devices
- Selected tab label / icon uses `Theme.accent`; unselected uses `Theme.textSecondary`
- Toolbar icons on all four tab roots use `Theme.textPrimary` (not `accent`) — accent now means "selected / active" only
- Shimmer sweep is visibly softer and reads as ambient light, not a loading bar
- `XomErrorState` used by at least FeedView and LeaderboardView; copy mapped to friendly messages (no raw error dumps)
- App still buildable; all screens still reachable

**Rollback**: `git revert` the phase 2 PR. Tab bar and toolbar revert; nothing else regresses because tokens are phase 1.

---

## Phase 3 — Social surfaces (feed) ✓ DONE

**Goal**: Rebuild `FeedItemCard` from the inside out. Kill shadows, kill tinted inner panels, upsize hero numbers, clean the header row, unify icon weight across the action bar. Polish `FeedView` list spacing and filter bar. Polish `FeedDetailView` + `FeedCommentsView`.

**Effort**: L (card is the hero component, 4 sub-content types)

**Files touched**:
- `Xomfit/Views/Feed/FeedItemCard.swift` — full rebuild:
  - Kill `.shadow(...)` at line 37 → replace with `XomCard(variant: .base)` wrapper
  - Header row: remove the inline `activityBadge` from the top-right; move activity context to a subtle line under the display name ("Workout · 2h ago", "Personal Record · 4h ago")
  - Upsize avatar from 40 → 48pt
  - `WorkoutActivityContent`: stats row uses refined `XomStat` (hero number design), keep 3-column layout
  - `PRActivityContent`: replace tinted panel (`Theme.prGold.opacity(0.08)` bg) with a 3pt leading gold stripe + gold icon + display-sized weight number (`fontDisplay`, 44pt). Previous-best line uses `textTertiary`
  - `MilestoneActivityContent`: 3pt leading purple stripe, no tinted bg
  - `StreakActivityContent`: 3pt leading orange stripe, no tinted bg, flame icon at `.title` weight
  - Action bar: lock all icons to `.font(.system(size: 18, weight: .medium))` non-fill until active; like button swaps to `heart.fill` + accent (not destructive red — Strava-pattern) on press, fires particle burst
  - Exercise pills row: use `XomBadge` with `xs` radius
- `Xomfit/Views/Feed/FeedView.swift` — spacing polish:
  - Scroll list uses `LazyVStack(spacing: Spacing.md)` between cards (currently implicit)
  - Filter bar hairline-separated from list content
  - Toolbar icons → `textPrimary` tint (done in phase 2, verify)
- `Xomfit/Views/Feed/FeedFilterBar.swift` — filter chips:
  - Active state: `accent` fill (black text), not accent outline
  - Inactive: `surface` fill with hairline border
  - Use `XomBadge` primitive with `interactive: true` variant
- `Xomfit/Views/Feed/FeedDetailView.swift` — rebuild hero card as full-bleed variant, comments list uses hairline separators instead of dividers
- `Xomfit/Views/Feed/FeedCommentsView.swift` — comment row: 32pt avatar, hairline separator, `textTertiary` timestamp, reply button using ghost button variant

**New files**:
- `Xomfit/Views/Feed/ActivityStripeCard.swift` — shared primitive for the PR/Milestone/Streak content with leading color stripe. Takes `stripeColor`, `icon`, `title`, `@ViewBuilder content`

**Acceptance criteria**:
- `FeedItemCard` has zero `.shadow(...)` calls and zero nested tinted-color backgrounds
- PR weight number reads at 44pt rounded heavy on a PR card — clearly the visual focal point
- Activity context line reads "[Activity Type] · [time ago]" under display name, no colored badge on the right side of the header
- All action bar icons are the same line weight; only `heart.fill` on liked state differs (filled + accent)
- Exercise pills render with `XomBadge`, not ad-hoc `.background(Theme.background)` wrappers
- Filter chips: active chip is filled accent with black text, no outline; inactive is surface + hairline; tapping switches smoothly
- Feed scroll has `Spacing.md` (16pt) between cards consistently
- Comment row aligns avatar + text baselines, timestamp reads in `textTertiary`
- VoiceOver still announces activity type, author, and timestamp on each card

**Rollback**: `git revert` the phase 3 PR. Feed surfaces revert to post-phase-2 state. No upstream surfaces affected.

---

## Phase 4 — Profile ✓ DONE

**Goal**: Upsize everything that was whispered in `ProfileHeaderView`. Refine `ProfileTabPicker` and polish the three sub-views (`ProfileFeedView`, `ProfileCalendarView`, `ProfileStatsView`) with Lane A data density.

**Effort**: M

**Files touched**:
- `Xomfit/Views/Profile/ProfileHeaderView.swift`:
  - Avatar: 70pt → 96pt (Envato spec 80–120); `XomAvatar` with optional accent ring when PR-streak-active
  - Name: `.body.weight(.bold)` → `.title2.bold` (22pt)
  - Username: `fontCaption` → `textTertiary` + `subheadline`
  - Stat row: rework each column with refined `XomStat` — number at `fontNumberLarge` (28pt rounded bold), label uppercase kerned `fontMetricLabel`
  - Action button: swap to `XomButton(.primary)` for "Add Friend", `XomButton(.secondary)` for "Edit Profile", remove inline custom button styling
  - Bio: `fontBody` with `textSecondary`, max 4 lines with `truncationMode: .tail`
  - Private account badge: `XomBadge` with `secondary` variant
- `Xomfit/Views/Profile/ProfileTabPicker.swift`:
  - Replace manual `Divider()` with `XomDivider`
  - Underline thickness 2 → 2.5pt, match accent exactly
  - Inactive icon color → `textSecondary`, active → `textPrimary` (not accent — accent is the underline). Whoop pattern.
- `Xomfit/Views/Profile/ProfileFeedView.swift` — list spacing `Spacing.md`, empty state uses new `XomEmptyState` with symbol stack
- `Xomfit/Views/Profile/ProfileCalendarView.swift` — density polish: day cells use `surface` fill when logged, `accent` when PR day; hairline grid
- `Xomfit/Views/Profile/ProfileStatsView.swift` — stat grid uses refined `XomStat` in cards, charts adopt `accent` + `accentMuted` gradient fill
- `Xomfit/Views/Profile/EditProfileSheet.swift` — sheet corner radius `Radius.lg`, form field hairline borders
- `Xomfit/Views/Profile/FriendsListView.swift` — row avatar 40pt, hairline separator, `XomButton(.ghost)` for action
- `Xomfit/Views/Profile/PrivateProfileView.swift` — bigger lock icon, refined copy, single CTA with `XomButton`

**New files**: none (existing primitives sufficient)

**Acceptance criteria**:
- Profile header avatar is 96pt, visibly the anchor of the header
- Display name reads at 22pt bold; username underneath in `textTertiary`
- Stat row numbers are monospaced-digit and visibly 2x the height of their uppercase kerned labels
- Edit Profile button uses `XomButton(.secondary)` with no custom `.cornerRadiusSmall` background hack
- Tab picker: underline is 2.5pt accent, selected tab label is `textPrimary` not accent
- Calendar day grid has hairline separators (not `textSecondary * 0.3`)
- Stats charts render with accent-gradient fills, no other hue introduced
- All sub-views scroll smoothly on a profile with 100+ feed items

**Rollback**: `git revert` the phase 4 PR. Profile surfaces revert to post-phase-1 state. No other tabs affected.

---

## Phase 5 — Active Workout + Exercise Library ✓ DONE

**Goal**: This is the legibility-critical phase. Every element on `ActiveWorkoutView` gets inspected for data density and scannability. Rest timer becomes a premium moment. Set rows are chunky, high-contrast, monospaced. Exercise picker is faster to scan.

**Effort**: L

**Files touched**:
- `Xomfit/Views/Workout/ActiveWorkoutView.swift`:
  - Header bar: elapsed-time uses `fontNumberLarge` monospaced, label `fontMetricLabel` uppercase
  - Rest timer config row: pill-style `XomBadge` with leading-accent indicator when active
  - Floating "Add Exercise" FAB: swap inline styling for `XomButton(.primary)` wrapped in a `.ultraThinMaterial` container so it reads as floating over content
  - Empty state: new `XomEmptyState` with stacked symbols (`dumbbell.fill`, `figure.strengthtraining.traditional`)
  - Keyboard toolbar: hairline top border, `textSecondary` for inactive buttons
- `Xomfit/Views/Workout/RestTimerView.swift`:
  - Wrap countdown in conic-gradient progress ring (fills over duration)
  - Number: `fontDisplay` (44pt rounded heavy), breathing scale 0.98 ↔ 1.02 at 1s period
  - Skip/Extend buttons → `XomButton(.ghost)` + `XomButton(.secondary)`
  - Background: `.ultraThinMaterial` so timer reads as overlay
  - Haptic: fire `Haptics.selection()` at 3, 2, 1; `Haptics.workoutComplete()` at 0
- `Xomfit/Views/Workout/SetRowView.swift`:
  - Reps / weight input: `fontNumberMedium` monospaced rounded
  - PR indicator: leading 3pt gold stripe + trophy icon (not a tinted bg)
  - Completed set checkbox: `accent` fill, `checkmark` glyph, 28pt hit target
  - Row height ≥ 52pt for easy gym-floor tapping
- `Xomfit/Views/Workout/ExerciseConfigRow.swift` — same density rules as SetRowView
- `Xomfit/Views/Workout/WorkoutFocusView.swift` — large-text mode respects new type scale; hero numbers use `fontDisplay`
- `Xomfit/Views/Workout/ExercisePickerView.swift`:
  - Search field: hairline border, `surface` fill, `textTertiary` placeholder
  - Muscle group filter chips: use `XomBadge` active/inactive treatment
  - Exercise row: 48pt tap target, `textPrimary` name, muscle tags as small `XomBadge`s
- `Xomfit/Views/Workout/WorkoutDetailView.swift` — hero stats row, exercise list density, finish button uses `XomButton(.primary)` with no shadow
- `Xomfit/Views/Workout/WorkoutBuilderView.swift` — form field polish, hairline borders, consistent spacing
- `Xomfit/Views/Workout/TemplateListView.swift` + `TemplateCardView.swift` + `TemplateDetailView.swift` — card treatment via `XomCard`, no shadows, hero volume number
- `Xomfit/Views/Workout/RecentWorkoutCard.swift` — same density rules

**New files**:
- `Xomfit/Views/Workout/RestTimerRingView.swift` — extracted conic-gradient ring shape (reusable)

**Acceptance criteria**:
- Active Workout set rows are ≥ 52pt tall and all numeric inputs render monospaced rounded
- Rest timer has a conic progress ring, breathing number animation, and haptic at T-3/2/1/0
- PR on a set row is a leading gold stripe + trophy icon only — no tinted row background
- Exercise picker scrolls at 60fps on a 200+ exercise library (no layout regressions from density changes)
- Keyboard toolbar does not obscure the active set row (iOS keyboard inset respected)
- Workout detail hero stats (Volume, Duration, Sets, PRs) each render at `fontNumberLarge` or larger
- Completion button fires `Haptics.workoutComplete()` and the view still uses the existing `finishWorkout` VM call unchanged

**Rollback**: `git revert` the phase 5 PR. Workout surfaces revert. Other phases unaffected.

---

## Phase 6 — Remaining surfaces + motion layer ✓ DONE

**Goal**: Polish the long tail (Friends, Leaderboard, Progress, Settings, Onboarding) and add the five signature motions from research §5 as a layered pass across everything that shipped in phases 2–5.

**Effort**: M

**Files touched**:
- `Xomfit/Views/Friends/FriendsView.swift` — row polish (avatar 40pt, hairline separators, action buttons via `XomButton`)
- `Xomfit/Views/Progress/LeaderboardView.swift`:
  - Filter bar: `XomBadge` chips
  - Leaderboard row: rank number in `fontNumberLarge`, avatar 40pt, user row uses hairline separator, current-user row gets leading accent stripe
  - Podium (top 3): accent-gold-silver-bronze medallion treatment using `fontDisplay` for the rank number
- `Xomfit/Views/Progress/XomProgressView.swift`:
  - Stat cards: `XomCard` + `XomStat` (hero numbers)
  - Charts: accent + `accentMuted` gradient fill, hairline grid lines, `textTertiary` axis labels
  - Muscle heatmap (`BodyHeatmapView.swift`): accent fill intensity ramp, no other hues
- `Xomfit/Views/Profile/BodyHeatmapView.swift` — update fill ramp to accent luminance only
- `Xomfit/Views/Profile/PRListView.swift` — row: trophy icon + exercise name + weight in `fontNumberMedium` + date in `textTertiary`, hairline separators, leading gold stripe on top-3 PRs
- `Xomfit/Views/Shared/PRBadgeRow.swift` — match new badge/stripe pattern
- `Xomfit/Views/Profile/SettingsView.swift` — section headers `fontMetricLabel`, row hairline separators, chevrons in `textTertiary`
- `Xomfit/Views/Notifications/NotificationInboxView.swift` + `NotificationPreferencesView.swift` — row / toggle polish
- `Xomfit/Views/Auth/LoginView.swift` + `SignUpView.swift` + `ProfileCompletionView.swift` — form field hairline borders, `XomButton(.primary)` CTAs, hero logo treatment
- `Xomfit/Views/Onboarding/OnboardingView.swift` + `OnboardingWelcomeScreen.swift` + `OnboardingGoalsScreen.swift` + `OnboardingFriendsScreen.swift` + `OnboardingBottomBar.swift` — consistent spacing rhythm, `XomButton` variants, `.section` gaps
- `Xomfit/Views/MainTabView.swift` — tab transition: upgrade opacity-only crossfade to opacity + 8pt vertical offset `.spring(response: 0.4, dampingFraction: 0.82)`
- `Xomfit/Views/Feed/FeedItemCard.swift` — like-button particle burst (5–8 small heart particles rising and fading over 0.6s)
- `Xomfit/Views/Workout/RestTimerView.swift` — completion flourish: full-view `accent.opacity(0.15)` overlay fade in 0.2s / out 0.4s, "GO" swap with spring
- `Xomfit/Views/Profile/ProfileStatsView.swift` + `XomProgressView.swift` — stat count-up animation on appear (0 → value over 0.8s ease-out)

**New files**:
- `Xomfit/Views/Common/ParticleBurstView.swift` — reusable particle emitter (used by like-burst, PR celebration later)
- `Xomfit/Views/Common/CountUpNumber.swift` — view that animates an Int from 0 to target with monospaced digits

**Acceptance criteria**:
- Leaderboard, Progress, PR list, Settings all render with zero nested tinted panels
- Onboarding flow feels consistent end-to-end — same spacing, button styles, typography
- Tab switch has visible 8pt vertical lift, not a crossfade
- Like button particle burst fires on first like-tap only (not on unlike), pairs with soft haptic
- Stat count-up runs once per appearance, never causes width jitter (monospaced digits)
- Rest timer completion flourish runs once at T=0 and does not loop
- All five signature motions from research §5 present: like burst, rest complete flourish, tab switch, stat count-up, PR card parallax (deferred to PR celebration screen if time-boxed)

**Rollback**: `git revert` the phase 6 PR. Motion layer and tail surfaces revert to post-phase-5 state. Cleanup still leaves a cohesive app because phases 1–5 are the core visual lift.

---

## Visual QA Checklist (run at the end of every phase)

For each phase, verify on iPhone 16 simulator + one physical device if available:

- [ ] **Light content load**: feed with 2 items, profile with 0 friends, empty workout — does the phase's surface still feel intentional?
- [ ] **Heavy content load**: feed with 50+ items, profile with 100+ posts, active workout with 10+ exercises and 5+ sets each — no layout collapse, scroll stays smooth
- [ ] **Empty state**: every list/grid/tab the phase touches renders the refined `XomEmptyState` (not a bare ProgressView, not a stock message)
- [ ] **Error state**: force a network failure (airplane mode) — every async surface in the phase shows `XomErrorState` with a retry CTA, not a stack trace
- [ ] **Long strings**: 40-char display name, 80-char workout name, 200-char bio — nothing truncates mid-word awkwardly, no horizontal overflow
- [ ] **Large Dynamic Type**: test at `.accessibilityExtraLarge` — text does not overlap, hero numbers still legible, tap targets still ≥ 44pt
- [ ] **VoiceOver**: every tap target has a label, activity badges announce their type, stat columns announce "[value] [label]"
- [ ] **Dark mode only**: no phantom white flashes on sheet present/dismiss (known SwiftUI foot-gun); `toolbarColorScheme(.dark, for: .navigationBar)` intact on all nav roots
- [ ] **Build**: `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'` exits 0 with no new warnings

---

## Out of Scope

- Business logic changes (VMs, services, models) — explicit non-goal
- New features (no new screens, no new data fetches, no new Supabase queries)
- Onboarding copy rewrites — visual polish only; copy stays
- Illustration assets beyond SF Symbol composition — no custom SVG / vector import in this pass
- Light mode — app stays dark-only until a dedicated light-mode phase is scoped
- Localization pass — strings stay as-is
- Accessibility audit beyond Dynamic Type + VoiceOver label checks
- Haptics rework — existing `Haptics` patterns reused, no new CoreHaptics patterns

## Risks / Tradeoffs

- **Token-level change in P1 can cause visual regressions everywhere**: mitigated by keeping deprecated aliases (`surfaceSecondary`, `cornerRadius`) resolving to new values; P1 is the cheapest PR to revert if something breaks
- **SF Pro Rounded + monospacedDigit combo has subtle rendering differences pre-iOS 17.4**: iOS 17+ target covers all supported; verify once on iOS 17.0 simulator
- **`.ultraThinMaterial` tab bar over scrolling content can look slightly different across devices**: acceptable — matches native iOS pattern
- **Particle burst + motion layer in P6 risks perf regressions on older devices**: use `withAnimation` only, no CADisplayLink loops; test on iPhone 13 or equivalent
- **Phases 2–5 being parallelizable means merge conflicts on shared primitives**: mitigated by P1 locking primitives before any sibling phase starts; downstream phases only consume, never modify, primitives
- **Large scope across 40+ files**: mitigated by strict phase boundaries — each PR is reviewable independently, each phase keeps the app buildable

## Open Questions — Resolved 2026-04-16

- [x] **Brand mark**: Use existing assets `XomFitLogo` (`logo-dark.png` / `logo-light.png`) and `XomFitBanner` from `Xomfit/Assets.xcassets/`. No custom mascot design work in this plan — integrate these assets into chrome (P2) and onboarding (P6).
- [x] **PR celebration full-screen takeover**: Deferred. Not in P6 scope. Track as follow-up feature.
- [x] **Like color**: Keep current red heart (`Theme.destructive`). Do not migrate to accent-on-like.
- [x] **Photo gallery in feed**: Keep horizontal scroll gallery layout in P3. **Add tap-to-zoom**: tapping a photo opens a full-screen zoomable viewer (pinch-zoom + swipe-to-dismiss). New component in P3 scope: `PhotoZoomView`.
- [x] **Deprecation window for `surfaceSecondary`**: Keep as alias through P6, hard-remove in a follow-up cleanup PR after P6 ships. Every phase that touches call sites migrates them; P6 exit means zero remaining call sites.
- [x] **Light mode**: Out of scope. Not on any roadmap in this plan.
- [x] **Design review gate**: No Figma mock gate. Trust the plan + RESEARCH.md as the spec. Visual QA happens in the PR review per phase.

## Skills / Agents to Use

- **ios-standards skill**: every phase — enforce SwiftUI conventions (`@Observable` for state, modern APIs `foregroundStyle` / `clipShape(.rect())`, strict concurrency)
- **swiftui-reviewer agent** (if present): post-phase code review on primitive rewrites (P1) and FeedItemCard rebuild (P3)
- **ios-build-verifier agent** (if present): run `xcodebuild` at each phase exit to confirm zero-warning build before PR
- **git-pr-drafter agent** (if present): each phase ships as one PR; auto-draft PR body from the phase's Acceptance Criteria section
