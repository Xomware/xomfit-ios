# Stick Figure Animations — Exercise Form Guides

Implementation of animated stick figure demonstrations for exercise form guidance with tips and common mistakes.

## Overview

This feature provides visual demonstrations of proper exercise form using animated stick figures, combined with detailed form guidance including:

- **Animated Demonstrations**: Smooth Lottie animations of each exercise
- **Form Cues**: Step-by-step guidance for performing exercises correctly
- **Common Mistakes**: Visual and textual warnings about mistakes to avoid
- **Exercise Library**: Top 10 compound exercises with animations

## Architecture

### Components

#### 1. **ExerciseAnimationLibrary** (`Models/Animations/ExerciseAnimationLibrary.swift`)

Central library for managing exercise animation metadata.

**Key Features:**
- Maps 10+ exercises to animation files and metadata
- Stores form cues and common mistakes for each exercise
- Categorizes by difficulty (Beginner, Intermediate, Advanced)
- Identifies compound vs isolation exercises

**Key Methods:**
```swift
ExerciseAnimationLibrary.animationMetadata(for: "ex-1")           // Get metadata for exercise
ExerciseAnimationLibrary.allAnimations                            // Get all available animations
ExerciseAnimationLibrary.compoundAnimations                       // Get compound exercises only
ExerciseAnimationLibrary.animations(by: .intermediate)            // Filter by difficulty
ExerciseAnimationLibrary.hasAnimation(for: "ex-1")                // Check if animation exists
```

#### 2. **AnimationAssetManager** (`Models/Animations/AnimationAssetManager.swift`)

Singleton manager for loading and caching animation assets.

**Key Features:**
- Thread-safe asset loading with concurrent queue
- In-memory caching of loaded animations
- Tracks loading and failed animations
- Preloading support for batch operations

**Key Methods:**
```swift
AnimationAssetManager.shared.loadAnimation(named:, completion:)    // Load async
AnimationAssetManager.shared.loadAnimationSync(named:)             // Load sync (previews)
AnimationAssetManager.shared.preloadAnimations(_:)                 // Preload batch
AnimationAssetManager.shared.clearCache(for:)                      // Clear specific
AnimationAssetManager.shared.clearAllCache()                       // Clear all
```

#### 3. **StickFigureView** (`Views/Animations/StickFigureView.swift`)

SwiftUI view for displaying the animated stick figure demonstration.

**Features:**
- Displays exercise animation with Lottie
- Play/pause controls
- Loop counter
- Error states and loading indicators
- Exercise metadata display (difficulty, compound status)

**Usage:**
```swift
StickFigureView(
    exerciseName: "Bench Press",
    animation: benchPressMetadata
)
```

#### 4. **FormTipsView** (`Views/Animations/FormTipsView.swift`)

SwiftUI view for displaying form guidance with tabbed interface.

**Tabs:**
- **Form Cues**: Numbered step-by-step instructions
- **Common Mistakes**: Warning list of errors to avoid

**Features:**
- Segmented tab picker for switching between cues and mistakes
- Color-coded icons and backgrounds
- Responsive scrollable content
- Informational callouts

**Usage:**
```swift
FormTipsView(animation: benchPressMetadata)
```

#### 5. **ExerciseAnimationDetailView** (`Views/Animations/ExerciseAnimationDetailView.swift`)

Complete modal view combining animation, form tips, and exercise info.

**Features:**
- Full-screen navigation with back button
- Scrollable layout of all components
- Exercise metadata display
- Loading states and error handling

**Usage:**
```swift
NavigationLink(value: "ex-1") {
    Label("Form Guide", systemImage: "figure.strengthtraining")
}
.navigationDestination(for: String.self) { exerciseId in
    ExerciseAnimationDetailView(
        exerciseId: exerciseId,
        exerciseName: "Bench Press"
    )
}
```

## Animation Files

Lottie JSON animation files are stored in `XomFit/Assets/Animations/`.

### Included Animations (Top 10 Compound Exercises)

1. **bench_press.json** - Barbell bench press
2. **squat.json** - Barbell back squat
3. **deadlift.json** - Conventional deadlift
4. **overhead_press.json** - Standing overhead press
5. **barbell_row.json** - Bent-over barbell row
6. **pullups.json** - Pull-ups
7. **dumbbell_bench_press.json** - Dumbbell bench press
8. **leg_press.json** - Leg press machine
9. **lat_pulldown.json** - Lat pulldown
10. **incline_dumbbell_press.json** - Incline dumbbell press

**Note:** Template files included. Replace with detailed stick figure animations as needed.

## Data Model

### AnimationMetadata

```swift
struct AnimationMetadata {
    let exerciseId: String
    let exerciseName: String
    let animationId: String
    let animationFileName: String
    let duration: TimeInterval
    let isCompound: Bool
    let commonMistakes: [String]
    let formCues: [String]
    let difficulty: Difficulty
}

enum Difficulty: String, Codable {
    case beginner
    case intermediate
    case advanced
}
```

## Testing

Comprehensive test suite in `XomFitTests/AnimationTests.swift` covers:

### Unit Tests
- Animation library completeness
- Metadata validation
- Asset manager caching
- Difficulty filtering
- Exercise lookups

### Performance Tests
- Library load time
- Animation lookup performance
- Difficulty filter performance

**Run tests:**
```bash
xcodebuild test -scheme XomFit
```

## Integration with Exercise Database

The animation library integrates with the existing Exercise model:

```swift
// Get animation for an exercise
if let animation = ExerciseAnimationLibrary.animationMetadata(for: exercise.id) {
    ExerciseAnimationDetailView(
        exerciseId: exercise.id,
        exerciseName: exercise.name
    )
}
```

## Usage Examples

### Display Form Guide in Exercise Detail

```swift
struct ExerciseDetailView: View {
    let exercise: Exercise
    
    var body: some View {
        VStack {
            if ExerciseAnimationLibrary.hasAnimation(for: exercise.id) {
                StickFigureView(
                    exerciseName: exercise.name,
                    animation: ExerciseAnimationLibrary.animationMetadata(
                        for: exercise.id
                    )!
                )
            }
        }
    }
}
```

### Browse All Animations

```swift
struct AnimationBrowserView: View {
    let animations = ExerciseAnimationLibrary.compoundAnimations
    
    var body: some View {
        List(animations, id: \.exerciseId) { animation in
            NavigationLink(destination: ExerciseAnimationDetailView(
                exerciseId: animation.exerciseId,
                exerciseName: animation.exerciseName
            )) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(animation.exerciseName)
                            .font(.headline)
                        Text(animation.difficulty.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                }
            }
        }
    }
}
```

## Future Enhancements

1. **Lottie Integration**: Replace JSON templates with detailed stick figure animations
2. **Form Analysis**: AI-powered form analysis with real-time feedback
3. **Video Overlays**: Add video demonstrations alongside animations
4. **Custom Speed Control**: Slow-motion playback for better form analysis
5. **Variant Animations**: Different variations of exercises (wide grip, narrow grip, etc.)
6. **Audio Cues**: Voice guidance synchronized with animations
7. **ARKit Integration**: AR visualization of proper form
8. **User Recording**: Allow users to record their own form and compare

## Dependencies

- SwiftUI (iOS 15+)
- Combine
- Foundation

**Recommended (for full Lottie support):**
- [lottie-ios](https://github.com/airbnb/lottie-ios) - For advanced animation rendering

## File Structure

```
XomFit/
├── Models/Animations/
│   ├── ExerciseAnimationLibrary.swift
│   └── AnimationAssetManager.swift
├── Views/Animations/
│   ├── StickFigureView.swift
│   ├── FormTipsView.swift
│   └── ExerciseAnimationDetailView.swift
└── Assets/Animations/
    ├── bench_press.json
    ├── squat.json
    ├── deadlift.json
    ├── ... (10 total)
    └── incline_dumbbell_press.json

XomFitTests/
└── AnimationTests.swift
```

## Notes

- Animation files are bundled with the app
- Thread-safe asset loading with NSLock
- Memory-efficient caching system
- All views support light/dark mode
- Full Preview support for SwiftUI development
