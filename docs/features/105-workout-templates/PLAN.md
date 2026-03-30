# Plan: Workout Templates

**Status**: Ready
**Created**: 2026-03-30
**Last updated**: 2026-03-30
**Issue**: #105
**Branch**: `feature/105-workout-templates`

## Summary
Let users start workouts from saved templates instead of building from scratch every time. The `WorkoutTemplate` model already exists with 4 built-in templates. This plan adds a template browsing UI to WorkoutView, a TemplateService for persistence, and wires template selection into the existing ActiveWorkoutView flow. Success = user can tap a template card and land in ActiveWorkoutView with all exercises and sets pre-loaded.

## Approach
Minimal v1: browse built-in templates, start workout from template, persist custom templates in UserDefaults. No template editor UI -- custom templates come from a future "Save as Template" feature. The existing `addExercise()` pattern in WorkoutLoggerViewModel already pre-fills weight/reps from history, so `startFromTemplate()` will reuse that logic per exercise.

## Affected Files / Components

| File / Component | Change | Why |
|-----------------|--------|-----|
| `Xomfit/Services/TemplateService.swift` | **New** -- singleton service for template CRUD | Owns template persistence (UserDefaults) and merges built-in + custom |
| `Xomfit/Views/Workout/TemplateCardView.swift` | **New** -- reusable template card component | Used in both the horizontal scroll on WorkoutView and TemplateListView |
| `Xomfit/Views/Workout/TemplateListView.swift` | **New** -- full list of all templates | Sheet showing all templates grouped by category, swipe-to-delete on custom |
| `Xomfit/Views/Workout/WorkoutView.swift` | **Edit** -- add template section below Start button | Horizontal scroll of template cards + "See All" that opens TemplateListView |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | **Edit** -- add `startFromTemplate(_:userId:)` | Creates WorkoutExercise array from template, pre-fills sets using existing `lastSetForExercise` |
| `Xomfit/Views/Workout/ActiveWorkoutView.swift` | **Edit** -- accept optional template, call new start method | Routes template starts through `startFromTemplate()` instead of `startWorkout()` |

## Implementation Steps

- [ ] **Step 1 -- Create TemplateService** (`Xomfit/Services/TemplateService.swift`)
  - `@MainActor final class TemplateService` with `static let shared`
  - `private let key = "xomfit_custom_templates"`
  - `func allTemplates() -> [WorkoutTemplate]` -- returns `WorkoutTemplate.builtIn + loadCustom()`, sorted by category then name
  - `func saveCustomTemplate(_ template: WorkoutTemplate)` -- encodes to UserDefaults
  - `func deleteCustomTemplate(id: String)` -- removes by id, no-op for built-in
  - Private `loadCustom() -> [WorkoutTemplate]` that decodes from UserDefaults
  - All custom templates get `isCustom = true` enforced on save

- [ ] **Step 2 -- Add `startFromTemplate` to WorkoutLoggerViewModel** (`Xomfit/ViewModels/WorkoutLoggerViewModel.swift`)
  - New method: `func startFromTemplate(_ template: WorkoutTemplate, userId: String)`
  - Calls `startWorkout(name: template.name, userId: userId)` first to reset state
  - Iterates `template.exercises`, for each:
    - Looks up last set via existing `lastSetForExercise(exerciseId)`
    - Creates `WorkoutExercise` with `targetSets` number of `WorkoutSet` entries
    - Pre-fills weight/reps from history (fallback: 0/0 like current behavior)
    - Copies `TemplateExercise.notes` to `WorkoutExercise.notes`
  - Assigns built exercises array to `self.exercises`

- [ ] **Step 3 -- Create TemplateCardView** (`Xomfit/Views/Workout/TemplateCardView.swift`)
  - Compact card showing: category icon, template name, exercise count, estimated duration
  - Dark theme: `Theme.cardBackground` background, `Theme.accent` icon tint
  - Fixed width (~160pt) for horizontal scroll, full-width variant for list
  - Tap callback via `onSelect: () -> Void`

- [ ] **Step 4 -- Create TemplateListView** (`Xomfit/Views/Workout/TemplateListView.swift`)
  - Presented as a sheet from WorkoutView
  - Shows all templates from `TemplateService.shared.allTemplates()`
  - Grouped by `TemplateCategory` using `Section` headers
  - Each row: TemplateCardView (full-width variant) or inline row with name, description, exercise count, duration
  - Tap selects template and dismisses sheet
  - Swipe-to-delete on custom templates only (check `isCustom`)
  - Returns selected template via binding or callback

- [ ] **Step 5 -- Update WorkoutView** (`Xomfit/Views/Workout/WorkoutView.swift`)
  - Add `@State private var selectedTemplate: WorkoutTemplate?`
  - Add `@State private var showTemplateList = false`
  - Below the "Start Workout" button, add a section:
    - Section header: "Quick Start" label + "See All" button (opens TemplateListView)
    - Horizontal `ScrollView(.horizontal)` with `TemplateCardView` for each template (limit to ~6 for quick picks)
    - Tap on card sets `selectedTemplate` and triggers `showActiveWorkout = true`
  - Update `.fullScreenCover` to pass `selectedTemplate` to ActiveWorkoutView
  - On template list dismiss, if a template was selected, trigger workout start

- [ ] **Step 6 -- Update ActiveWorkoutView** (`Xomfit/Views/Workout/ActiveWorkoutView.swift`)
  - Add `var template: WorkoutTemplate? = nil` parameter (default nil for backward compat)
  - In `.onAppear`, branch:
    - If `template != nil`: call `viewModel.startFromTemplate(template!, userId: userId)`
    - Else: call `viewModel.startWorkout(name: workoutName, userId: userId)` (existing behavior)
  - Update the `workoutName` parameter to be optional or derive from template name

- [ ] **Step 7 -- Smoke test the full flow**
  - Verify: WorkoutView shows template cards on load
  - Verify: Tapping a template opens ActiveWorkoutView with exercises pre-loaded
  - Verify: Each exercise has the correct number of sets from `targetSets`
  - Verify: Weight/reps are pre-filled from workout history when available
  - Verify: "Start Workout" blank flow still works unchanged
  - Verify: "See All" opens TemplateListView with all 4 built-in templates
  - Verify: Template notes appear on exercises

## Out of Scope
- Template editor UI (create/edit custom templates)
- "Save as Template" from completed workout
- Supabase persistence for templates (UserDefaults only for v1)
- Template sharing between users
- Reordering exercises within a template
- Template search/filter

## Risks / Tradeoffs
- **UserDefaults size limit**: Not a concern for v1 -- custom templates are small JSON. If users accumulate hundreds, migrate to a local SQLite/SwiftData store later.
- **`lastSetForExercise` is synchronous cache lookup**: Works fine since `WorkoutService` already caches. If cache is empty (first launch, no history), sets default to 0/0 which is acceptable.
- **No template versioning**: If built-in templates change between app updates, in-progress workouts started from old templates are unaffected (template data is copied at start time, not referenced).
- **Compact card width**: Fixed 160pt may not look ideal on smaller devices. Use `adaptiveFrame` or test on iPhone SE.

## Open Questions
- [ ] Should template cards show on WorkoutView even when there's workout history (list could feel crowded)? Recommendation: yes, templates section stays visible above the history list.
- [ ] Should tapping a template skip the name entry alert (auto-use template name)? Recommendation: yes, skip the alert -- template name becomes workout name.

## Skills / Agents to Use
- **ios-standards**: Reference for Swift/SwiftUI conventions, `@Observable` patterns, accessibility requirements
- **Coder agent**: Execute steps 1-6 sequentially, one file per step
- **Tester agent**: Step 7 verification -- build and run through the simulator flow
