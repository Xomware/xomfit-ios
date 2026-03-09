import Foundation

/// Complete exercise database for XomFit
/// Organized by muscle group with form tips
struct ExerciseDatabase {
    static let all: [Exercise] = chest + back + shoulders + legs + arms + core
    
    // MARK: - Chest
    static let chest: [Exercise] = [
        Exercise(id: "ex-bench-flat", name: "Bench Press", muscleGroups: [.chest, .triceps, .shoulders], equipment: .barbell, category: .compound,
                 description: "Flat barbell bench press — the king of chest exercises.",
                 tips: ["Retract shoulder blades", "Feet flat on floor", "Touch bar to mid-chest", "Drive through your feet"]),
        Exercise(id: "ex-bench-incline", name: "Incline Bench Press", muscleGroups: [.chest, .shoulders, .triceps], equipment: .barbell, category: .compound,
                 description: "Incline barbell press targeting upper chest.",
                 tips: ["Set bench to 30-45 degrees", "Lower bar to upper chest", "Don't flare elbows too wide"]),
        Exercise(id: "ex-bench-db", name: "Dumbbell Bench Press", muscleGroups: [.chest, .triceps, .shoulders], equipment: .dumbbell, category: .compound,
                 description: "Dumbbell variation for better range of motion.",
                 tips: ["Full range of motion at the bottom", "Press dumbbells together at top", "Control the negative"]),
        Exercise(id: "ex-incline-db", name: "Incline Dumbbell Press", muscleGroups: [.chest, .shoulders, .triceps], equipment: .dumbbell, category: .compound,
                 description: "Incline dumbbell press for upper chest development.",
                 tips: ["30-45 degree incline", "Don't bounce at the bottom", "Squeeze at the top"]),
        Exercise(id: "ex-chest-fly", name: "Cable Chest Fly", muscleGroups: [.chest], equipment: .cable, category: .isolation,
                 description: "Cable flyes for chest isolation and stretch.",
                 tips: ["Slight bend in elbows throughout", "Squeeze chest at the center", "Control the stretch"]),
        Exercise(id: "ex-dips", name: "Dips", muscleGroups: [.chest, .triceps, .shoulders], equipment: .bodyweight, category: .compound,
                 description: "Parallel bar dips — lean forward to target chest.",
                 tips: ["Lean forward for chest emphasis", "Go to at least 90 degrees", "Don't swing"]),
        Exercise(id: "ex-pushup", name: "Push-ups", muscleGroups: [.chest, .triceps, .shoulders], equipment: .bodyweight, category: .compound,
                 description: "Classic bodyweight push-up.",
                 tips: ["Keep core tight", "Full range of motion", "Hands slightly wider than shoulders"]),
        Exercise(id: "ex-machine-press", name: "Machine Chest Press", muscleGroups: [.chest, .triceps], equipment: .machine, category: .compound,
                 description: "Machine press for controlled chest work.",
                 tips: ["Adjust seat height so handles align with mid-chest", "Don't lock out elbows", "Squeeze at full extension"]),
    ]
    
    // MARK: - Back
    static let back: [Exercise] = [
        Exercise(id: "ex-deadlift", name: "Deadlift", muscleGroups: [.back, .hamstrings, .glutes, .traps], equipment: .barbell, category: .compound,
                 description: "Conventional deadlift — the ultimate posterior chain builder.",
                 tips: ["Bar over mid-foot", "Neutral spine", "Push the floor away", "Lock out at the top"]),
        Exercise(id: "ex-row-barbell", name: "Barbell Row", muscleGroups: [.back, .lats, .biceps], equipment: .barbell, category: .compound,
                 description: "Bent-over barbell row for back thickness.",
                 tips: ["Hinge at hips to ~45 degrees", "Pull to lower chest/upper abs", "Squeeze shoulder blades together"]),
        Exercise(id: "ex-row-db", name: "Dumbbell Row", muscleGroups: [.back, .lats, .biceps], equipment: .dumbbell, category: .compound,
                 description: "Single-arm dumbbell row.",
                 tips: ["Keep back flat", "Pull elbow past torso", "Don't rotate your body"]),
        Exercise(id: "ex-pullup", name: "Pull-ups", muscleGroups: [.lats, .back, .biceps], equipment: .bodyweight, category: .compound,
                 description: "Overhand grip pull-up — king of lat exercises.",
                 tips: ["Full dead hang at bottom", "Pull chest to bar", "Control the negative"]),
        Exercise(id: "ex-chinup", name: "Chin-ups", muscleGroups: [.lats, .biceps, .back], equipment: .bodyweight, category: .compound,
                 description: "Underhand grip for more bicep involvement.",
                 tips: ["Supinated grip shoulder width", "Drive elbows down", "Full range of motion"]),
        Exercise(id: "ex-lat-pulldown", name: "Lat Pulldown", muscleGroups: [.lats, .back, .biceps], equipment: .cable, category: .compound,
                 description: "Cable pulldown for lat width.",
                 tips: ["Lean back slightly", "Pull to upper chest", "Don't use momentum"]),
        Exercise(id: "ex-cable-row", name: "Seated Cable Row", muscleGroups: [.back, .lats, .biceps], equipment: .cable, category: .compound,
                 description: "Seated cable row for mid-back thickness.",
                 tips: ["Keep chest up", "Pull to stomach", "Squeeze at full contraction"]),
        Exercise(id: "ex-face-pull", name: "Face Pulls", muscleGroups: [.shoulders, .traps, .back], equipment: .cable, category: .isolation,
                 description: "Cable face pulls for rear delts and posture.",
                 tips: ["Pull rope to face level", "Externally rotate at the end", "Light weight, high reps"]),
    ]
    
    // MARK: - Shoulders
    static let shoulders: [Exercise] = [
        Exercise(id: "ex-ohp", name: "Overhead Press", muscleGroups: [.shoulders, .triceps], equipment: .barbell, category: .compound,
                 description: "Standing barbell overhead press.",
                 tips: ["Brace your core", "Press bar slightly back", "Full lockout overhead", "Don't lean back excessively"]),
        Exercise(id: "ex-db-shoulder-press", name: "Dumbbell Shoulder Press", muscleGroups: [.shoulders, .triceps], equipment: .dumbbell, category: .compound,
                 description: "Seated or standing dumbbell press.",
                 tips: ["Don't go too heavy", "Full range of motion", "Press up and slightly inward"]),
        Exercise(id: "ex-lateral-raise", name: "Lateral Raises", muscleGroups: [.shoulders], equipment: .dumbbell, category: .isolation,
                 description: "Dumbbell lateral raises for side delt width.",
                 tips: ["Slight bend in elbows", "Raise to shoulder height", "Lead with your elbows, not hands", "Control the negative"]),
        Exercise(id: "ex-front-raise", name: "Front Raises", muscleGroups: [.shoulders], equipment: .dumbbell, category: .isolation,
                 description: "Front delt isolation.",
                 tips: ["Alternating or together", "Don't swing", "Raise to eye level"]),
        Exercise(id: "ex-rear-delt-fly", name: "Rear Delt Fly", muscleGroups: [.shoulders, .back], equipment: .dumbbell, category: .isolation,
                 description: "Bent-over rear delt flyes.",
                 tips: ["Bend over to near parallel", "Lead with elbows", "Squeeze at the top"]),
        Exercise(id: "ex-shrugs", name: "Barbell Shrugs", muscleGroups: [.traps], equipment: .barbell, category: .isolation,
                 description: "Barbell shrugs for trap development.",
                 tips: ["Straight up and down", "Hold at the top", "Don't roll your shoulders"]),
    ]
    
    // MARK: - Legs
    static let legs: [Exercise] = [
        Exercise(id: "ex-squat", name: "Squat", muscleGroups: [.quads, .glutes, .hamstrings], equipment: .barbell, category: .compound,
                 description: "Back squat — the king of leg exercises.",
                 tips: ["Bar on upper traps", "Feet shoulder width", "Break at hips and knees together", "Thighs to parallel or below"]),
        Exercise(id: "ex-front-squat", name: "Front Squat", muscleGroups: [.quads, .glutes], equipment: .barbell, category: .compound,
                 description: "Front squat for quad-dominant leg work.",
                 tips: ["Elbows high", "Stay upright", "Go as deep as mobility allows"]),
        Exercise(id: "ex-leg-press", name: "Leg Press", muscleGroups: [.quads, .glutes, .hamstrings], equipment: .machine, category: .compound,
                 description: "Machine leg press for heavy leg work.",
                 tips: ["Don't lock out knees", "Full range of motion", "Feet shoulder width on platform"]),
        Exercise(id: "ex-rdl", name: "Romanian Deadlift", muscleGroups: [.hamstrings, .glutes, .back], equipment: .barbell, category: .compound,
                 description: "RDL for hamstring and glute development.",
                 tips: ["Slight knee bend", "Push hips back", "Bar stays close to legs", "Feel the hamstring stretch"]),
        Exercise(id: "ex-lunge", name: "Walking Lunges", muscleGroups: [.quads, .glutes, .hamstrings], equipment: .dumbbell, category: .compound,
                 description: "Walking lunges with dumbbells.",
                 tips: ["Long stride", "Back knee almost touches ground", "Keep torso upright"]),
        Exercise(id: "ex-leg-curl", name: "Leg Curl", muscleGroups: [.hamstrings], equipment: .machine, category: .isolation,
                 description: "Machine leg curl for hamstring isolation.",
                 tips: ["Control the negative", "Full range of motion", "Don't lift hips off pad"]),
        Exercise(id: "ex-leg-ext", name: "Leg Extension", muscleGroups: [.quads], equipment: .machine, category: .isolation,
                 description: "Machine leg extension for quad isolation.",
                 tips: ["Pause at full extension", "Control the descent", "Don't use momentum"]),
        Exercise(id: "ex-calf-raise", name: "Calf Raises", muscleGroups: [.calves], equipment: .machine, category: .isolation,
                 description: "Standing calf raises.",
                 tips: ["Full stretch at bottom", "Pause at top", "Slow and controlled"]),
        Exercise(id: "ex-hip-thrust", name: "Hip Thrust", muscleGroups: [.glutes, .hamstrings], equipment: .barbell, category: .compound,
                 description: "Barbell hip thrust for glute max activation.",
                 tips: ["Back on bench, bar on hips", "Drive through heels", "Squeeze glutes at top", "Chin tucked"]),
    ]
    
    // MARK: - Arms
    static let arms: [Exercise] = [
        Exercise(id: "ex-barbell-curl", name: "Barbell Curl", muscleGroups: [.biceps], equipment: .barbell, category: .isolation,
                 description: "Standing barbell curl.",
                 tips: ["Keep elbows pinned to sides", "Don't swing", "Full range of motion"]),
        Exercise(id: "ex-db-curl", name: "Dumbbell Curl", muscleGroups: [.biceps], equipment: .dumbbell, category: .isolation,
                 description: "Standing or seated dumbbell curls.",
                 tips: ["Supinate at the top", "Control the negative", "Alternate or together"]),
        Exercise(id: "ex-hammer-curl", name: "Hammer Curl", muscleGroups: [.biceps, .forearms], equipment: .dumbbell, category: .isolation,
                 description: "Neutral grip curls for brachialis and forearms.",
                 tips: ["Neutral grip throughout", "Don't swing", "Great for forearm development"]),
        Exercise(id: "ex-preacher-curl", name: "Preacher Curl", muscleGroups: [.biceps], equipment: .dumbbell, category: .isolation,
                 description: "Preacher bench curls for strict bicep isolation.",
                 tips: ["Full stretch at bottom", "Don't come all the way up", "Strict form"]),
        Exercise(id: "ex-tricep-pushdown", name: "Tricep Pushdown", muscleGroups: [.triceps], equipment: .cable, category: .isolation,
                 description: "Cable pushdowns with rope or bar.",
                 tips: ["Elbows pinned to sides", "Full extension", "Squeeze at the bottom"]),
        Exercise(id: "ex-skull-crusher", name: "Skull Crushers", muscleGroups: [.triceps], equipment: .barbell, category: .isolation,
                 description: "Lying tricep extension with EZ bar.",
                 tips: ["Lower to forehead or behind head", "Keep elbows in", "Control the weight"]),
        Exercise(id: "ex-overhead-ext", name: "Overhead Tricep Extension", muscleGroups: [.triceps], equipment: .dumbbell, category: .isolation,
                 description: "Overhead single or double dumbbell tricep extension.",
                 tips: ["Keep elbows close to head", "Full stretch at bottom", "Lock out at top"]),
        Exercise(id: "ex-close-grip-bench", name: "Close Grip Bench Press", muscleGroups: [.triceps, .chest], equipment: .barbell, category: .compound,
                 description: "Narrow grip bench press for tricep emphasis.",
                 tips: ["Hands shoulder-width or slightly narrower", "Elbows tucked", "Touch lower chest"]),
    ]
    
    // MARK: - Core
    static let core: [Exercise] = [
        Exercise(id: "ex-plank", name: "Plank", muscleGroups: [.abs], equipment: .bodyweight, category: .isolation,
                 description: "Isometric core hold.",
                 tips: ["Straight line from head to heels", "Don't let hips sag", "Breathe normally"]),
        Exercise(id: "ex-hanging-leg-raise", name: "Hanging Leg Raise", muscleGroups: [.abs], equipment: .bodyweight, category: .isolation,
                 description: "Hanging from a bar, raise legs to parallel or above.",
                 tips: ["Control the swing", "Curl pelvis up", "Slow negative"]),
        Exercise(id: "ex-cable-crunch", name: "Cable Crunch", muscleGroups: [.abs], equipment: .cable, category: .isolation,
                 description: "Kneeling cable crunch for weighted ab work.",
                 tips: ["Crunch down, don't pull with arms", "Round your spine", "Squeeze at the bottom"]),
        Exercise(id: "ex-ab-wheel", name: "Ab Wheel Rollout", muscleGroups: [.abs], equipment: .other, category: .isolation,
                 description: "Ab wheel rollout for deep core activation.",
                 tips: ["Start from knees", "Don't collapse at the bottom", "Brace core throughout"]),
    ]
    
    // MARK: - Search
    static func search(_ query: String) -> [Exercise] {
        if query.isEmpty { return all }
        let lowered = query.lowercased()
        return all.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.muscleGroups.contains(where: { $0.rawValue.contains(lowered) }) ||
            $0.equipment.rawValue.contains(lowered)
        }
    }
    
    static func byMuscleGroup(_ group: MuscleGroup) -> [Exercise] {
        all.filter { $0.muscleGroups.contains(group) }
    }
    
    static func byEquipment(_ equipment: Equipment) -> [Exercise] {
        all.filter { $0.equipment == equipment }
    }
}
