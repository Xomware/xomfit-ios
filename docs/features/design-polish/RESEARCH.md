# XomFit Design Polish — Research

> Research-only doc. Direction for polishing XomFit from "child made it" to "feels premium." Opinionated, actionable.

Note on research method: Dribbble/Mobbin/HIG fetches were blocked in this session, so reference-app callouts draw on existing product knowledge of Strava, Hevy, Whoop, Strong, Fitbod, Oura, Peloton, and Apple's iOS 17/18 HIG. Patterns are described concretely enough that you can verify them visually in 10 minutes of app browsing before committing to a direction.

---

## 1. Current state assessment

The token system in `Xomfit/Utils/Theme.swift` is actually well-structured — spacing grid, animation curves, haptics, variant styles all exist. The problem is at the **composition** layer, not the tokens. The parts look fine; the wholes feel amateur.

Specific issues, cited:

- **Too many surface colors, used inconsistently.** `Theme.background` (`#0A0A0F`), `Theme.surface` (`#1A1A2E`), `Theme.surfaceSecondary` (`#16213E`) — `1A1A2E` is an indigo-tinted midnight and `16213E` is a straight-up navy. They clash. Premium dark apps (Whoop, Oura) use a single neutral near-black plus one elevated tone, typically differing only in luminance, not hue. File: `Xomfit/Utils/Theme.swift:12-16`.
- **Feed card shadows are too soft and too dark for a dark theme.** `shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)` on a near-black background does almost nothing visually, adds no elevation, and muddies edges. File: `Xomfit/Views/Feed/FeedItemCard.swift:37`. Premium dark apps use a hairline border + subtle top highlight instead of drop shadow.
- **Activity badges placed in the header fight the avatar+name for attention.** Header row crams avatar, name, timestamp, colored badge, AND ellipsis menu into one line. File: `Xomfit/Views/Feed/FeedItemCard.swift:74-124`. Reads as cluttered. Instagram/Strava keep the header clean and move type/context into a subtle label under the name.
- **Typography lacks a personality tier.** Everything uses SF Pro with weight variations. No display font, no numeric emphasis on hero metrics. `fontDisplay` is defined (`largeTitle.weight(.black).width(.condensed)`) but I don't see it used in the cards we looked at — PR values use `title3.weight(.black)` (`Xomfit/Views/Feed/FeedItemCard.swift:429`) which is too small to feel celebratory.
- **Stat columns are undersized and underweight.** Profile header stats use `.headline.weight(.bold)` for the number (file `Xomfit/Views/Profile/ProfileHeaderView.swift:41, 119`). These should be `.title` or `.title2` with a condensed/rounded treatment. Hevy and Strong go big on numbers; XomFit whispers them.
- **Buttons are overdesigned.** Primary button carries a colored accent-shadow (`Theme.accent.opacity(0.3)` at radius 8). Against a dark background with a neon green button, the glow reads juvenile — like a gaming app, not a premium fitness tracker. File: `Xomfit/Utils/Theme.swift:316-321`, `Xomfit/Views/Common/XomButton.swift:56`.
- **Accent color `#33FF66` is punchy but aggressively saturated.** Fine for a CTA at 10% coverage, but when used for icons, progress fills, selected-tab labels, and friend-count emphasis, it becomes visual noise. Needs desaturation or a role split (hero accent vs utility accent).
- **Activity content blocks have too many colored backgrounds.** PR uses gold-tinted bg, milestone uses purple-tinted bg, streak uses orange-tinted bg (`FeedItemCard.swift:446-447, 481-482, 515-516`). Stacking a gold card inside a dark feed card inside a dark screen creates visual mud. Premium apps use color sparingly — a single accent stripe or icon, not a nested tinted panel.
- **Iconography is inconsistent.** Mix of `.fill` and line-weight SF Symbols (`trophy.fill` next to `heart` [non-fill]), no `symbolVariant` modifier applied at scope. Inconsistent weight reads as amateur.
- **Empty states are generic.** `XomEmptyState` (`Xomfit/Views/Common/XomEmptyState.swift`) is a tray icon + two text blocks. No illustration, no personality, no motion. This is where apps either feel delightful or feel like prototypes.
- **Skeleton loading is functional but lifeless.** `ShimmerModifier` shimmer is a simple gradient sweep (`Theme.swift:252-270`). No staggered reveal, no optimistic content. Whoop/Oura use silhouettes that match the shape of real content and fade-in at different rates.
- **Floating tab bar has a double container.** `Rectangle` + `UnevenRoundedRectangle` stroke (`MainTabView.swift:100-113`) — the tab bar background extends to the screen edges but shows a top stroke only in a rounded shape. Reads as a leftover hack from iterating on designs.
- **No consistent 1pt hairline system.** Dividers use `Theme.textSecondary.opacity(0.3)` (`FeedItemCard.swift:28-29`); glass borders use `Color.white.opacity(0.1)`. Two separate rules for the same visual concept.

---

## 2. Reference apps

Pick 2–3 of these to study for 20 minutes each before committing to a direction.

- **Strava** — the gold standard for social fitness feed. What to steal: clean card header (avatar + name + context line, no badges jammed in); generous whitespace between sections; map/graphic hero then stats row then action bar; kudos (like) uses a subtle fill + count, not a red heart.
- **Hevy** — closest competitor by feature set (lifting tracker with social). What to steal: workout completion card with big volume number, exercise list as compact tinted pills, PR indicator is a single gold star, not a panel. Green accent used sparingly only for completion/active states.
- **Whoop** — premium dark-theme fitness. What to steal: single near-black background, one elevated card tone (luminance only), hero metrics use a heavy rounded numeric, color used only for score rings. No drop shadows anywhere.
- **Oura** — premium dark-theme with data density. What to steal: ring visualizations instead of bars; soft gradient fills on scores; typographic hierarchy where the number is 3x larger than the label and the label is uppercase small-caps.
- **Fitbod** — strong information density without clutter. What to steal: muscle heatmap treatment; set/rep rows with high contrast; rest-timer animation that feels like a breath, not a countdown.
- **Peloton** — emotional, celebratory states. What to steal: PR and milestone screens use a full-bleed color wash + big condensed type + confetti/particle motion, not a small gold panel.

---

## 3. Design language recommendations

### Color palette

Keep dark. Reduce hue variation between surfaces. Split the accent into role-specific tones so one color doesn't do four jobs.

Existing token -> proposed (derived, not invented):

| Role | Current | Proposed | Rationale |
|---|---|---|---|
| Background | `#0A0A0F` | `#0B0B0E` | Slight warm neutralization, removes the blue cast. |
| Surface (card) | `#1A1A2E` | `#17171C` | Pure luminance lift from background — same hue family. Kills the indigo tint. |
| Surface elevated (modal/sheet) | `#16213E` | `#1F1F26` | Higher luminance lift, still neutral. Deprecate `surfaceSecondary` as "nested container." |
| Hairline (dividers/borders) | `rgba(255,255,255,0.1)` + `textSecondary*0.3` | unified `rgba(255,255,255,0.08)` | One rule for all hairlines. |
| Text primary | `#FFFFFF` | `#F5F5F7` | Pure white on dark creates shimmer/fatigue. Apple's off-white is calmer. |
| Text secondary | `#9CA3AF` | `#9A9AA3` | Neutral grey, not blue-grey. Matches the surface hue shift. |
| Text tertiary (new) | — | `#6B6B72` | For timestamps, metadata that should recede. |
| Accent (hero/CTA) | `#33FF66` | `#2FE562` | Slightly desaturated so it doesn't scream. Reserve for primary actions only. |
| Accent muted (utility) | (none) | `#2FE562` @ 18% fill / 60% text | Use this for icon tints, selected tab labels, non-CTA accents. |
| Energy (success) | `#00C46A` | merge with accent | You don't need two greens. |
| PR gold | `#FFD700` | `#F5C84B` | Current gold is full-saturation and reads as cheap. The muted warm gold reads premium (Whoop/Oura trophy tone). |
| Milestone purple | `#AA66FF` | `#9B7BFF` | Slightly cooler/softer. |
| Streak orange | `#FF6633` | `#FF7A45` | Warmer, less aggressive. |
| Alert | `#FF6B35` | `#FF8A4C` | Less clown-orange. |
| Destructive | `#FF4444` | `#FF5E5E` | Less urgent-red, more considered-red. |

**Rule:** Only ONE colored panel on screen at a time. PR/Milestone/Streak content blocks should lose their tinted backgrounds and instead use a 3px leading color stripe + tinted icon. Reference: Linear's issue rows.

### Typography

SF Pro is fine for UI. Add SF Pro Rounded for hero metrics and numeric displays — pairs with the fitness/friendly tone without looking like a kids' app. Use monospaced digits everywhere numbers animate (rest timer, volume counter).

| Token | Current | Proposed |
|---|---|---|
| Display (hero number) | `largeTitle.weight(.black).width(.condensed)` | `.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit()` |
| Large title | `largeTitle.bold` | keep, but add `.rounded` on number-heavy headers |
| Title | `title.bold` | keep |
| Headline | `title3.semibold` | keep |
| Metric label (new) | — | `.caption.weight(.semibold)` + `.textCase(.uppercase)` + `.kerning(0.5)` |
| Body | `.body` | keep |
| Caption | `.caption` | keep |
| Small (badge) | `.caption2.medium` | `.caption2.semibold.monospacedDigit()` when numeric |

**Rule:** Every metric on screen follows the pattern `BIG NUMBER / small uppercase label` (Whoop/Oura style). The current stat columns have the number only one size larger than the label — not a hierarchy.

### Spacing + radius

Existing 8pt grid is correct (`Theme.Spacing`). Keep it. Add:

- `Spacing.hairline: CGFloat = 0.5` — for the unified 0.5px border.
- `Spacing.section: CGFloat = 40` — between major vertical sections on a scroll view (profile header -> tab picker, etc.). Current profile header pads md (16) top/bottom, feels cramped.

Radius tokens — add a scale instead of just two:

| Token | Value | Use |
|---|---|---|
| `radius.xs` | 6 | Inline chips, pills, small badges |
| `radius.sm` | 10 | Buttons, small cards (current `cornerRadiusSmall`) |
| `radius.md` | 16 | Cards (current `cornerRadius`) |
| `radius.lg` | 22 | Sheets, modals |
| `radius.xl` | 28 | Full-bleed hero cards (PR announcement, workout complete) |

### Elevation / card treatment

Kill drop shadows. They do not work on near-black backgrounds and the current 4px/15% opacity shadow is invisible anyway. Replace with:

- **Base card:** `fill(surface)` + `strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)` — the hairline is the elevation.
- **Elevated card (sheet/modal):** `fill(surfaceElevated)` + hairline, same as above.
- **Hero card (PR celebration, workout complete):** background uses `LinearGradient` from `accent.opacity(0.12)` to `accent.opacity(0)` top-to-bottom, + hairline. Color gradient = elevation.
- **Pressed state:** scale 0.98 (not 0.94 — too much) + background lifts to `white.opacity(0.04)` overlay.

Reference: Whoop cards have no shadow, just a 1px hairline at ~6% white. Instantly reads premium.

### Iconography

SF Symbols, lock to one variant per context.

- **Tab bar, nav bar:** `symbolVariant(.fill)` when selected, line when unselected. Current tab bar does this well already (`MainTabView.swift:83-85`). Apply same rule to feed action bar.
- **Feed action bar:** lock to non-fill line icons (`heart`, `bubble.right`, `square.and.arrow.up`, `bookmark`) until pressed — consistent line weight. On like, swap to `heart.fill` + accent tint + haptic.
- **Activity badges:** use `.fill` consistently; current mixes `figure.strengthtraining.traditional` (not fill) with `trophy.fill`. Pick a lane.
- **Icon weight:** set a global `.font(.system(size: X, weight: .medium))` for all utility icons. Stop shipping default weight.
- **Add a brand mark.** One custom SVG/rasterized mascot or wordmark in nav bar. Pure SF Symbols everywhere = generic.

---

## 4. Component polish targets, prioritized

Ranked by visual-impact-per-hour. Do top 3 before anything else.

1. **FeedItemCard** — S/M. File: `Xomfit/Views/Feed/FeedItemCard.swift`. This is the hero component. Weak: cluttered header, tinted content panels, soft shadow. Do: remove drop shadow, add hairline border, move activity badge out of header into a subtle label under the name, strip tinted backgrounds from PR/Milestone/Streak inner cards and replace with leading color stripe + tinted icon only. Upsize PR value to display-class typography (`44pt heavy rounded`). Effort: M.
2. **Theme.swift color + typography tokens** — S. File: `Xomfit/Utils/Theme.swift`. Do: update hex values per §3 table, add `textTertiary`, add rounded-numeric display font, add metric-label helper that applies uppercase + kerning. No UI code change required beyond hex swaps — immediate wholesale lift. Effort: S.
3. **ProfileHeaderView** — M. File: `Xomfit/Views/Profile/ProfileHeaderView.swift`. Weak: stats use `.headline` (too small), avatar is a small gradient circle, action button is small and generic. Do: upsize stat numbers to `.title.rounded.monospacedDigit`, upsize avatar to 88pt with a thin 2pt accent ring only when PR-streak-active, make name a proper `.title2.bold`, move username under name with `textTertiary`. Effort: M.
4. **FloatingTabBar** — S. File: `Xomfit/Views/MainTabView.swift:63-115`. Weak: double-container, rectangle+UnevenRoundedRectangle hack. Do: single `.ultraThinMaterial` background with a top hairline, 28pt radius top only, proper safe-area handling. iOS 18 glass material is free polish. Effort: S.
5. **Stat/metric row (XomStat)** — S. File: `Xomfit/Views/Common/XomStat.swift`. Weak: equal weight between number and label. Do: make number 2.5x size of label, label uppercase + kerning, monospaced digits, optional trend indicator (up/down arrow). Effort: S.
6. **ActiveWorkoutView + RestTimerView** — M. Weak: timer is a countdown, not an experience. Do: circular progress ring (conic gradient), breathing animation on the time number, haptic at 5-4-3-2-1, `.ultraThinMaterial` background so the timer feels overlaid. Effort: M.
7. **Empty states (XomEmptyState)** — M. File: `Xomfit/Views/Common/XomEmptyState.swift`. Weak: lifeless SF Symbol + text. Do: commission or assemble SF-Symbol-composed illustrations (stack 2-3 symbols with offsets and tint variations), add subtle breathing loop, context-specific copy. Effort: M.
8. **Button styles (XomButton, AccentButtonStyle)** — S. Files: `Xomfit/Views/Common/XomButton.swift`, `Xomfit/Utils/Theme.swift:307-325`. Weak: colored shadow reads juvenile. Do: remove shadow entirely, reduce press scale to 0.98, add subtle highlight gradient top-to-bottom for depth, keep haptic. Effort: S.
9. **Skeleton loaders** — M. Files: `Xomfit/Utils/Theme.swift:252-284`. Weak: shimmer is generic. Do: make skeletons mirror the real layout (avatar circle, two lines, stat row) instead of rectangles, add slight stagger. Effort: M.
10. **Exercise picker + set row** — M. Weak: dense spreadsheet feel on ActiveWorkoutView. Do: chunky tap targets, left-edge PR star accent, weight/reps in monospaced rounded. Effort: M.
11. **PR celebration** — L. Promote to a full-screen takeover when a PR is hit mid-workout: full-bleed gradient, confetti (particle view), big number animates in with spring, rank-up haptic fires. Currently buried in a feed card after the fact. Effort: L but huge wow.
12. **Feed filter bar** — S. File: `Xomfit/Views/Feed/FeedFilterBar.swift`. Likely chips. Do: convert to scrollable segmented pills, accent-fill when active, not accent outline. Effort: S.

---

## 5. Motion + micro-interactions

Five animations worth the effort. All use existing animation tokens in `Theme.swift:83-94`.

1. **Like button bounce + heart burst.** Currently scales to 1.3 on tap (`FeedItemCard.swift:198-207`). Upgrade: on first-tap from unliked, fire a small particle burst (5-8 small hearts fading up + out over 0.6s), scale main heart 1.0 → 1.35 → 1.0 using `xomCelebration`, `sensoryFeedback(.impact(.soft))`. Reference: Instagram double-tap.
2. **Rest timer completion flourish.** When timer hits 0: ring fills fully, whole view briefly brightens with a `accent.opacity(0.15)` overlay that fades in 0.2s / out 0.4s, `Haptics.workoutComplete` fires, number animates to "GO" with `.spring(response: 0.35, dampingFraction: 0.55)`. Currently undersold.
3. **Tab switch transition.** Currently opacity crossfade (`MainTabView.swift:18`). Upgrade: combine opacity with 8pt vertical offset using `.spring(response: 0.4, dampingFraction: 0.82)`. More substance without adding latency.
4. **Stat number count-up on profile/stats screen.** When stat rows appear, animate numbers from 0 to real value using `withAnimation(.easeOut(duration: 0.8))` and a `@State` intermediate value. Uses monospaced digits so width doesn't jitter. Pairs with `Haptics.selection()` at the end.
5. **PR hero card parallax.** On feed PR cards: subtle tilt/parallax responding to device motion (CoreMotion, +/- 3 degrees), gold gradient shifts slightly. Understated — reference Apple Wallet card tilt. Feels expensive.

Spring parameters to standardize:

- **Interactive press:** `.spring(response: 0.2, dampingFraction: 0.85)` (current `xomSnappy` is close)
- **Stat/card appearance:** `.spring(response: 0.4, dampingFraction: 0.82)`
- **Celebration:** `.spring(response: 0.35, dampingFraction: 0.55)` (current `xomCelebration` uses 0.3/0.5 — slightly bouncier; keep)

---

## 6. Empty + loading + error states

**Current — empty states:** Generic SF Symbol + title + subtitle + optional CTA (`XomEmptyState.swift`). Used consistently (good) but feels like a placeholder.

**Polish recommendations:**

- **Feed empty (no friends/posts yet):** illustration of 3 overlapping SF Symbols (`dumbbell`, `figure.run`, `trophy`) with accent tint at low opacity, floating gently (2s ease-in-out loop, 3pt offset). Copy: "Your feed is quiet. Add friends to see their workouts." CTA: primary button "Find friends."
- **Workout empty (no exercises added):** ghost silhouette of an ExerciseCard with shimmer, label "Add your first exercise" + arrow pointing to the floating Add button. Onboarding in context.
- **Calendar empty (profile):** faded calendar grid, "Your workout days will appear here" copy, optional primary CTA "Start a workout."
- **PR list empty:** trophy silhouette at 30% opacity with a subtle gold glow, "No PRs yet" + "Hit a personal best in any lift to see it here."

**Current — loading:** `ShimmerModifier` + `SkeletonCard` rectangles. Functional but generic.

**Polish:**

- Skeletons that match real card anatomy: avatar circle, title line, subtitle line, stat row (3 small rects), action bar. 0.05s stagger between cards. Same approach as LinkedIn/Twitter.
- Replace `ShimmerModifier`'s linear gradient sweep with a softer radial highlight that moves diagonally — less "loading bar" feel.
- Full-screen spinners: use `XomFitLoader` (already exists at `Xomfit/Views/Common/XomFitLoader.swift` — verify it's polished; if not, a pulsing dumbbell or circular ring works).

**Current — errors:** `errorView(message:)` in `FeedView.swift` (not inspected in detail). Assume generic.

**Polish:**

- Error state uses `XomEmptyState` style with a warning icon (`exclamationmark.triangle` in `.alert` tone at 40% opacity), concise error copy, retry CTA. Don't show stack traces or raw messages to the user — map known errors to friendly copy, fallback to "Something went wrong. Try again."
- Add a toast pattern (already exists: `Xomfit/Views/Common/ToastView.swift`) for transient failures: top-of-screen pill, auto-dismisses in 3s. Less disruptive than a full error screen.

---

## 7. Top 10 concrete, high-impact polish moves

Pick any of these and ship it in a single PR. Each is one file or tight cluster.

1. **Swap surface hex values** in `Xomfit/Utils/Theme.swift` to the neutral palette (background `#0B0B0E`, surface `#17171C`, surfaceSecondary `#1F1F26`, text `#F5F5F7`). Nothing else changes. Whole app will look less amateur immediately.
2. **Remove feed card drop shadow** at `Xomfit/Views/Feed/FeedItemCard.swift:37`, add a 0.5pt `strokeBorder(Color.white.opacity(0.06))`. Instant premium upgrade.
3. **Kill tinted backgrounds in PR/Milestone/Streak inner cards** (`FeedItemCard.swift:446-516`). Replace with a 3pt leading color stripe + tinted icon. One colored element per card.
4. **Upsize PR value typography** at `FeedItemCard.swift:429` to `.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit()`. Celebrate the number.
5. **Unify icon variant** in `FeedItemCard.swift` action bar — all line icons until active state. Apply `.font(.system(size: 18, weight: .medium))` at the bar level.
6. **Redesign ProfileHeaderView stat columns** at `Xomfit/Views/Profile/ProfileHeaderView.swift:116-131`. Numbers `.title.rounded.monospacedDigit()`, labels uppercase+kerned `.caption2.weight(.semibold)`.
7. **Replace FloatingTabBar background** at `Xomfit/Views/MainTabView.swift:100-113` with `.ultraThinMaterial` + single top-rounded mask + 0.5pt top hairline. Cleaner, more iOS 18.
8. **Remove accent-colored shadow from AccentButtonStyle** at `Xomfit/Utils/Theme.swift:316-321`, reduce press scale to 0.98.
9. **Polish RestTimerView** — wrap the countdown in a conic-gradient progress ring, add breathing scale on the number (0.98 ↔ 1.02 over 1s), fire haptic at last 3 seconds.
10. **Upgrade XomEmptyState** at `Xomfit/Views/Common/XomEmptyState.swift` to support a stacked-symbol illustration (2-3 SF Symbols offset + tinted) and a gentle floating loop. One shared component, used everywhere.

---

## Appendix — Files inspected

- `Xomfit/Utils/Theme.swift` (full)
- `Xomfit/Views/Feed/FeedItemCard.swift` (full)
- `Xomfit/Views/Profile/ProfileView.swift` (full)
- `Xomfit/Views/Profile/ProfileHeaderView.swift` (full)
- `Xomfit/Views/Workout/ActiveWorkoutView.swift` (first 100)
- `Xomfit/Views/MainTabView.swift` (full)
- `Xomfit/Views/Feed/FeedView.swift` (first 80)
- `Xomfit/Views/Common/XomAvatar.swift`, `XomStat.swift`, `XomCard.swift`, `XomButton.swift`, `XomEmptyState.swift` (full)
- `.claude/rules/ios.md`

Design rules file (`.claude/rules/*design*`): none exist — opportunity to add one after this direction lands.
