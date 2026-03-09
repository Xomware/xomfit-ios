import Foundation

/// Maps exercises to their stick figure animation assets
struct ExerciseAnimationLibrary {
    /// Animation metadata for an exercise
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
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }
    
    private static let animationDatabase: [String: AnimationMetadata] = [
        // Compound Lifts - Priority 1
        "ex-1": AnimationMetadata(
            exerciseId: "ex-1",
            exerciseName: "Bench Press",
            animationId: "bench-press-standard",
            animationFileName: "bench_press.json",
            duration: 2.5,
            isCompound: true,
            commonMistakes: [
                "Bouncing the bar off the chest",
                "Elbows flared too wide",
                "Incomplete lockout at top",
                "Feet not planted firmly"
            ],
            formCues: [
                "Keep feet flat on the floor",
                "Arch your back slightly",
                "Lower bar to mid-chest",
                "Press up and slightly back",
                "Full lockout at the top"
            ],
            difficulty: .intermediate
        ),
        
        "ex-2": AnimationMetadata(
            exerciseId: "ex-2",
            exerciseName: "Squat",
            animationId: "squat-barbell",
            animationFileName: "squat.json",
            duration: 2.8,
            isCompound: true,
            commonMistakes: [
                "Knees caving inward",
                "Heels lifting off ground",
                "Chest dropping forward",
                "Incomplete depth",
                "Asymmetrical weight distribution"
            ],
            formCues: [
                "Feet shoulder-width apart",
                "Chest up, shoulders back",
                "Break at hips and knees simultaneously",
                "Knees track over toes",
                "Drive through heels to stand"
            ],
            difficulty: .intermediate
        ),
        
        "ex-3": AnimationMetadata(
            exerciseId: "ex-3",
            exerciseName: "Deadlift",
            animationId: "deadlift-conventional",
            animationFileName: "deadlift.json",
            duration: 3.0,
            isCompound: true,
            commonMistakes: [
                "Bar drifting away from body",
                "Rounding lower back",
                "Hips too high at start",
                "Incomplete hip extension",
                "Pulling with arms instead of legs"
            ],
            formCues: [
                "Bar over mid-foot",
                "Shoulders over bar",
                "Neutral spine throughout",
                "Chest up from the start",
                "Drive through heels, lock out hips"
            ],
            difficulty: .advanced
        ),
        
        "ex-4": AnimationMetadata(
            exerciseId: "ex-4",
            exerciseName: "Overhead Press",
            animationId: "overhead-press-standing",
            animationFileName: "overhead_press.json",
            duration: 2.4,
            isCompound: true,
            commonMistakes: [
                "Excessive back arch",
                "Incomplete lockout",
                "Pressing too far forward",
                "Weak core bracing",
                "Bar path inconsistent"
            ],
            formCues: [
                "Brace your core tightly",
                "Press bar straight up",
                "Press slightly back at lockout",
                "Full elbow extension overhead",
                "Maintain neutral spine"
            ],
            difficulty: .intermediate
        ),
        
        "ex-5": AnimationMetadata(
            exerciseId: "ex-5",
            exerciseName: "Barbell Row",
            animationId: "barbell-row-bent-over",
            animationFileName: "barbell_row.json",
            duration: 2.2,
            isCompound: true,
            commonMistakes: [
                "Rounding the back",
                "Hips rising before shoulders",
                "Bar path away from body",
                "Incomplete range of motion",
                "Using arm strength instead of back"
            ],
            formCues: [
                "Hinge at hips, flat back",
                "Shoulders slightly in front of bar",
                "Pull bar to lower chest",
                "Squeeze shoulder blades together",
                "Control the descent"
            ],
            difficulty: .intermediate
        ),
        
        // Additional Compound Exercises (6-10)
        "ex-6": AnimationMetadata(
            exerciseId: "ex-6",
            exerciseName: "Pull-ups",
            animationId: "pullups-standard",
            animationFileName: "pullups.json",
            duration: 2.6,
            isCompound: true,
            commonMistakes: [
                "Partial range of motion",
                "Kipping or jerking motion",
                "Elbows flared too wide",
                "Head jutting forward"
            ],
            formCues: [
                "Dead hang at bottom",
                "Elbows bent to 90 degrees",
                "Chin above bar at top",
                "Controlled descent",
                "Engage lats, not just arms"
            ],
            difficulty: .advanced
        ),
        
        "ex-7": AnimationMetadata(
            exerciseId: "ex-7",
            exerciseName: "Dumbbell Bench Press",
            animationId: "dumbbell-bench-press",
            animationFileName: "dumbbell_bench_press.json",
            duration: 2.5,
            isCompound: true,
            commonMistakes: [
                "Uneven dumbbell height",
                "Dumbbells too low on descent",
                "Elbows angled too wide"
            ],
            formCues: [
                "Dumbbells at shoulder height",
                "Press up and together",
                "Full elbow extension",
                "Control the descent"
            ],
            difficulty: .intermediate
        ),
        
        "ex-8": AnimationMetadata(
            exerciseId: "ex-8",
            exerciseName: "Leg Press",
            animationId: "leg-press-machine",
            animationFileName: "leg_press.json",
            duration: 2.7,
            isCompound: true,
            commonMistakes: [
                "Knees tracking inward",
                "Feet too high on platform",
                "Incomplete range of motion",
                "Knee lockout at top"
            ],
            formCues: [
                "Feet shoulder-width apart",
                "Feet middle of platform",
                "Full range of motion",
                "Controlled descent",
                "Drive through feet to press"
            ],
            difficulty: .beginner
        ),
        
        "ex-9": AnimationMetadata(
            exerciseId: "ex-9",
            exerciseName: "Lat Pulldown",
            animationId: "lat-pulldown-machine",
            animationFileName: "lat_pulldown.json",
            duration: 2.3,
            isCompound: true,
            commonMistakes: [
                "Bar path away from body",
                "Incomplete range at bottom",
                "Using arm strength only",
                "Leaning too far back"
            ],
            formCues: [
                "Slight backward lean",
                "Pull bar to upper chest",
                "Elbows drive down",
                "Shoulder blades retract",
                "Controlled ascent"
            ],
            difficulty: .beginner
        ),
        
        "ex-10": AnimationMetadata(
            exerciseId: "ex-10",
            exerciseName: "Incline Dumbbell Press",
            animationId: "incline-dumbbell-press",
            animationFileName: "incline_dumbbell_press.json",
            duration: 2.5,
            isCompound: true,
            commonMistakes: [
                "Incline too steep",
                "Dumbbells too wide at bottom",
                "Incomplete range of motion"
            ],
            formCues: [
                "30-45 degree incline",
                "Dumbbells at shoulder height",
                "Press up and together",
                "Full elbow extension"
            ],
            difficulty: .intermediate
        ),
    ]
    
    /// Retrieve animation metadata for an exercise
    static func animationMetadata(for exerciseId: String) -> AnimationMetadata? {
        return animationDatabase[exerciseId]
    }
    
    /// Get all available animations
    static var allAnimations: [AnimationMetadata] {
        return Array(animationDatabase.values).sorted { $0.exerciseName < $1.exerciseName }
    }
    
    /// Get compound exercise animations only
    static var compoundAnimations: [AnimationMetadata] {
        return allAnimations.filter { $0.isCompound }
    }
    
    /// Get animations by difficulty
    static func animations(by difficulty: Difficulty) -> [AnimationMetadata] {
        return allAnimations.filter { $0.difficulty == difficulty }
    }
    
    /// Check if animation exists for exercise
    static func hasAnimation(for exerciseId: String) -> Bool {
        return animationDatabase[exerciseId] != nil
    }
    
    /// Get list of animations available for UI
    static var availableExerciseNames: [String] {
        return allAnimations.map { $0.exerciseName }
    }
}
