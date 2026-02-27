# AI Coach Implementation for XomFit

## Overview

The AI Coach feature provides personalized workout recommendations based on user training history, goals, and performance analysis. It uses machine learning principles to analyze workout data and suggest optimal programming adjustments.

## Architecture

### Models (`Models/AIRecommendation.swift`)

#### `AIRecommendation`
The core recommendation object containing:
- **Type**: Exercise, rep range, rest period, weak point, plateau, volume progression, exercise swap, new program, or form correction
- **Exercise**: Specific exercise recommendation with rep range, sets, rest period
- **Program**: Full program recommendation with split type and duration
- **Analysis**: Performance insights backing the recommendation
- **Confidence**: 0-1 score indicating recommendation strength
- **Reasoning**: Human-readable explanation

#### `PerformanceAnalysis`
Detailed analysis of user performance including:
- **MuscleGroupAnalysis**: Per-muscle group frequency, volume, and training status
- **VolumeProgression**: Total volume trends over time
- **StrengthProgression**: PR count, RPE trends, high-intensity volume
- **Imbalances**: Detected muscle group volume imbalances
- **EstimatedMaxes**: Calculated 1RM estimates for exercises

#### `RecommendationLearning`
Tracks user feedback:
- Accepted/rejected recommendations
- Learned user preferences
- Exercise effectiveness scores

### Services (`Services/AICoachService.swift`)

`AICoachService` implements the core recommendation engine:

```swift
class AICoachService: AICoachServiceProtocol {
    func generateRecommendations(userId: String, workouts: [Workout]) -> [AIRecommendation]
    func analyzePerformance(userId: String, workouts: [Workout]) -> PerformanceAnalysis
    func getPersonalizedProgram(userId: String, preferences: UserTrainingPreferences) -> ProgramRecommendation
    func recordRecommendationFeedback(userId: String, recommendationId: String, accepted: Bool) -> Void
}
```

#### Recommendation Engine

The service generates recommendations through multiple analysis paths:

1. **Weak Point Detection**
   - Identifies muscle groups with low training frequency
   - Suggests exercises to address underdeveloped areas
   - Confidence: 0.80

2. **Imbalance Detection**
   - Compares volume ratios between muscle groups
   - Flags ratios > 1.5x as imbalances
   - Severities: minor (1.5-2x), moderate (2-3x), severe (3x+)
   - Confidence: 0.75

3. **Plateau Detection**
   - Tracks recent PRs and RPE trends
   - Suggests rep range changes when progress stalls
   - Confidence: 0.72

4. **Volume Progression**
   - Analyzes month-to-month volume trends
   - Recommends adjustments based on up/down/stable trends
   - Confidence: 0.78-0.80

5. **Deload Suggestions**
   - Triggers after high-intensity volume thresholds (>15 RPE 9+ sets/month)
   - Recommends 50-60% intensity recovery week
   - Confidence: 0.70

#### Performance Metrics

**Strength Estimation**
- Uses Brzycki formula to estimate 1RM: `weight × (36 / (37 - (reps + 10 - rpe)))`
- Maintains confidence scores based on sample size
- Matches estimates against actual maxes when available

**Volume Analysis**
- Tracks absolute volume (weight × reps × sets)
- Compares 30-day and 90-day windows
- Detects trends with ±20% thresholds

**Frequency Classification**
- Rare: < 1x/month
- Occasional: 1-2x/month
- Regular: 1-2x/week
- Frequent: 3+/week

### ViewModels (`ViewModels/AICoachViewModel.swift`)

`AICoachViewModel` manages UI state:

```swift
@MainActor
class AICoachViewModel: ObservableObject {
    @Published var recommendations: [AIRecommendation]
    @Published var performanceAnalysis: PerformanceAnalysis?
    @Published var userPreferences: UserTrainingPreferences
    
    func loadRecommendations(userId: String, workouts: [Workout])
    func analyzePerformance(userId: String, workouts: [Workout])
    func acceptRecommendation(_ rec: AIRecommendation)
    func dismissRecommendation(_ rec: AIRecommendation)
    func getPersonalizedProgram(userId: String, workouts: [Workout])
}
```

### Views

#### `AICoachView` (Main)
- Displays top recommendation with action buttons (Accept/Skip)
- Shows overall performance score
- Lists additional recommendations
- Displays key insights (weak points, imbalances)
- Refreshable via pull-to-refresh

#### `PerformanceAnalysisView`
- Tabbed interface for detailed analysis
- Volume & strength progression
- Muscle group breakdown
- Imbalance details
- Estimated 1RM display

#### `AICoachSettingsView`
- User preference configuration
- Training split selection
- Frequency targets
- Rep range preferences
- Rest period settings
- Deload automation

## Usage

### Basic Integration

```swift
// In a view or view model
let viewModel = AICoachViewModel()

// Load recommendations when user logs workouts
viewModel.loadRecommendations(userId: user.id, workouts: workouts, userStats: user.stats)

// Analyze performance
viewModel.analyzePerformance(userId: user.id, workouts: workouts)

// User actions
viewModel.acceptRecommendation(recommendation)
viewModel.dismissRecommendation(recommendation)
```

### In SwiftUI

```swift
AICoachView(
    viewModel: AICoachViewModel(),
    user: currentUser,
    workouts: userWorkouts
)
```

## Data Flow

```
User Workouts
    ↓
AICoachService.analyzePerformance()
    ├─ Volume Analysis
    ├─ Strength Progression
    ├─ Muscle Group Analysis
    └─ Imbalance Detection
    ↓
Generates Recommendations
    ├─ Weak Point
    ├─ Imbalance
    ├─ Plateau
    ├─ Volume Progression
    └─ Deload
    ↓
AICoachViewModel
    ├─ Sorts by confidence
    └─ Limits to top 5
    ↓
AICoachView displays to user
    ├─ Accept → Records feedback
    └─ Skip → Records feedback
```

## Learning System

### Current Implementation
- Tracks accepted vs rejected recommendations
- Records per-exercise effectiveness scores
- Stores user training preferences

### Future Enhancements
1. **Collaborative Filtering**: Compare recommendations effectiveness across users
2. **Bayesian Learning**: Update confidence scores based on feedback
3. **Temporal Patterns**: Learn user's best training times/frequencies
4. **Exercise Substitution**: Learn exercise preferences within muscle groups
5. **Periodization**: Suggest program phases (hypertrophy, strength, power)

## Recommendation Confidence Scores

| Type | Base Confidence | Factors |
|------|-----------------|---------|
| Weak Point | 0.80 | Frequency <1x/month |
| Imbalance | 0.75 | Volume ratio severity |
| Plateau | 0.72 | RPE stability |
| Volume | 0.78-0.80 | Trend clarity |
| Deload | 0.70 | High-intensity volume |
| New Program | 0.85-0.95 | Data completeness |

## Performance Considerations

- **Computation**: Analysis runs async in background, no UI blocking
- **Caching**: Performance analysis cached until new workouts logged
- **Storage**: Learning state kept in memory (can persist to UserDefaults/database)
- **API Calls**: Can be extended to backend ML service for enhanced analysis

## Future Enhancements

### Phase 1 (Current)
✅ Recommendation generation
✅ Performance analysis
✅ User preferences
✅ Feedback recording

### Phase 2
- [ ] Backend ML integration (OpenAI, Claude, or custom models)
- [ ] Program template library
- [ ] Exercise form video matching
- [ ] Deload week automation
- [ ] PRR adjustment algorithms

### Phase 3
- [ ] Social comparison (vs friends)
- [ ] Goal-based programming
- [ ] Injury prevention suggestions
- [ ] Nutrition recommendations
- [ ] Recovery metrics integration

## Testing

Mock data available:
```swift
AIRecommendation.mockExerciseRecommendation
AIRecommendation.mockWeakPointRecommendation
AIRecommendation.mockProgramRecommendation
```

## Notes

- All analysis uses local data only (privacy-first)
- Recommendations are suggestions, not prescriptions
- User feedback improves future recommendations
- Integrates with existing WorkoutStore and Exercise database
