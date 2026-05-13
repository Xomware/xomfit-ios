import Foundation

/// Built-in stretch routines for the pre-workout warmup flow.
/// Stretches are mapped to muscle groups so we can suggest the right ones
/// for whatever workout the user is starting.
struct StretchDatabase {
    static let all: [Stretch] = [
        // MARK: - Full body / dynamic
        Stretch(
            id: "st-worlds-greatest", name: "World's Greatest Stretch",
            description: "Step into a deep lunge, drop the opposite hand to the floor, then rotate the top arm up toward the ceiling. Alternate sides.",
            durationSeconds: 45,
            targetMuscleGroups: [.hamstrings, .glutes, .back, .shoulders, .quads]
        ),
        Stretch(
            id: "st-cat-cow", name: "Cat-Cow",
            description: "On hands and knees, alternate between rounding the spine (cat) and arching while lifting the chest (cow). Move with your breath.",
            durationSeconds: 40,
            targetMuscleGroups: [.back, .abs]
        ),
        Stretch(
            id: "st-leg-swings", name: "Leg Swings",
            description: "Hold a wall or rack and swing one leg front-to-back, then side-to-side. Keep the swing controlled, not forced.",
            durationSeconds: 40,
            targetMuscleGroups: [.hamstrings, .glutes, .quads]
        ),
        Stretch(
            id: "st-arm-circles", name: "Arm Circles",
            description: "Extend arms out to the sides and make slow forward circles for half the time, then reverse. Increase the size gradually.",
            durationSeconds: 30,
            targetMuscleGroups: [.shoulders]
        ),

        // MARK: - Upper body
        Stretch(
            id: "st-shoulder-dislocates", name: "Shoulder Dislocates",
            description: "Hold a band, broomstick, or PVC pipe wide overhead and slowly pass it from in front of your hips to behind your back, then return.",
            durationSeconds: 45,
            targetMuscleGroups: [.shoulders, .chest]
        ),
        Stretch(
            id: "st-doorway-chest", name: "Doorway Chest Stretch",
            description: "Place forearms on a doorway frame at shoulder height and step one foot through to feel a stretch across the chest and front delts.",
            durationSeconds: 30,
            targetMuscleGroups: [.chest, .shoulders]
        ),
        Stretch(
            id: "st-cross-body-shoulder", name: "Cross-Body Shoulder Stretch",
            description: "Pull one arm across your chest with the other arm, holding just above the elbow. Feel the stretch in the rear delt.",
            durationSeconds: 30,
            targetMuscleGroups: [.shoulders, .back]
        ),
        Stretch(
            id: "st-overhead-tricep", name: "Overhead Tricep Stretch",
            description: "Reach one arm overhead and bend the elbow so the hand drops behind your head. Use the other hand to gently pull the elbow back.",
            durationSeconds: 30,
            targetMuscleGroups: [.triceps, .shoulders]
        ),
        Stretch(
            id: "st-thoracic-rotation", name: "Thoracic Rotation",
            description: "On hands and knees, place one hand behind your head and rotate that elbow up toward the ceiling, then back under the opposite arm.",
            durationSeconds: 40,
            targetMuscleGroups: [.back, .abs, .shoulders]
        ),
        Stretch(
            id: "st-wrist-circles", name: "Wrist Circles & Stretch",
            description: "Extend arms forward and slowly circle the wrists in both directions, then gently pull each hand back to stretch the forearms.",
            durationSeconds: 30,
            targetMuscleGroups: [.forearms]
        ),
        Stretch(
            id: "st-neck-rolls", name: "Neck Rolls",
            description: "Slowly drop your chin to your chest and roll your head from one shoulder to the other. Keep the motion gentle.",
            durationSeconds: 25,
            targetMuscleGroups: [.traps, .shoulders]
        ),

        // MARK: - Lower body
        Stretch(
            id: "st-90-90-hip", name: "90/90 Hip Stretch",
            description: "Sit with both legs at 90-degree angles — front leg out, back leg behind. Sit tall and lean forward over the front shin, then switch.",
            durationSeconds: 45,
            targetMuscleGroups: [.glutes, .hamstrings]
        ),
        Stretch(
            id: "st-pigeon", name: "Pigeon Pose",
            description: "Bring one shin in front of you with the foot under the opposite hip. Extend the back leg straight behind. Lean over the front shin.",
            durationSeconds: 45,
            targetMuscleGroups: [.glutes, .hamstrings]
        ),
        Stretch(
            id: "st-deep-squat-hold", name: "Deep Squat Hold",
            description: "Drop into a deep bodyweight squat, drive elbows against the inside of your knees, and stay tall. Pry the knees out.",
            durationSeconds: 45,
            targetMuscleGroups: [.glutes, .hamstrings, .quads, .calves]
        ),
        Stretch(
            id: "st-hamstring-stretch", name: "Standing Hamstring Stretch",
            description: "Place one heel on a low surface and hinge at the hips with a flat back until you feel the hamstring stretch.",
            durationSeconds: 40,
            targetMuscleGroups: [.hamstrings, .glutes]
        ),
        Stretch(
            id: "st-quad-pull", name: "Standing Quad Stretch",
            description: "Pull one heel toward your glute and hold. Keep knees together and stand tall — don't arch the lower back.",
            durationSeconds: 30,
            targetMuscleGroups: [.quads]
        ),
        Stretch(
            id: "st-couch-stretch", name: "Couch Stretch",
            description: "Place the top of one foot on a bench or wall behind you with the knee on the floor. Drive hips forward and stay tall.",
            durationSeconds: 45,
            targetMuscleGroups: [.quads, .glutes]
        ),
        Stretch(
            id: "st-figure-four", name: "Figure-Four Glute Stretch",
            description: "Lying on your back, cross one ankle over the opposite knee and pull the bottom thigh in toward your chest.",
            durationSeconds: 40,
            targetMuscleGroups: [.glutes]
        ),
        Stretch(
            id: "st-calf-wall", name: "Calf Wall Stretch",
            description: "Place hands on a wall, step one foot back with the heel pressed down and the leg straight. Lean in to stretch the calf.",
            durationSeconds: 30,
            targetMuscleGroups: [.calves]
        ),
        Stretch(
            id: "st-hip-flexor-lunge", name: "Half-Kneeling Hip Flexor Stretch",
            description: "Drop into a half-kneeling lunge. Squeeze the back glute and gently push the hips forward to stretch the front hip.",
            durationSeconds: 40,
            targetMuscleGroups: [.quads, .glutes, .abs]
        ),

        // MARK: - Core / back
        Stretch(
            id: "st-childs-pose", name: "Child's Pose",
            description: "Kneel and sit back on your heels, then fold forward and reach arms overhead on the floor. Breathe and let the back relax.",
            durationSeconds: 45,
            targetMuscleGroups: [.back, .lats, .shoulders]
        ),
        Stretch(
            id: "st-cobra", name: "Cobra Stretch",
            description: "Lie face down with hands under your shoulders and gently press up, lifting your chest. Keep hips on the floor.",
            durationSeconds: 30,
            targetMuscleGroups: [.abs, .back]
        ),
    ]

    // MARK: - Lookup

    static func byMuscleGroup(_ group: MuscleGroup) -> [Stretch] {
        all.filter { $0.targetMuscleGroups.contains(group) }
    }

    static func byId(_ id: String) -> Stretch? {
        all.first(where: { $0.id == id })
    }

    // MARK: - Suggestions

    /// Hard cap on the size of any suggested routine — keeps the preview list
    /// scannable and the timer reasonable (#349).
    static let maxStretches: Int = 6

    /// Stretch IDs treated as general dynamic openers — flow-friendly stretches
    /// that pair well with any session and lead the routine.
    private static let generalOpenerIds: [String] = ["st-cat-cow", "st-worlds-greatest"]

    /// Pick a routine of stretches that covers the muscle groups hit by a workout,
    /// summing roughly to `target` seconds (default ~6 minutes).
    ///
    /// Selection order (#349):
    /// 1. Union of `Exercise.recommendedStretchIds` declared by the workout's exercises.
    /// 2. Pad with 1-2 general dynamic openers (cat-cow, world's greatest) for flow.
    /// 3. If still under 3 picks, fall back to frequency-weighted muscle-group selection.
    /// 4. Cap the routine at `maxStretches` (6).
    ///
    /// - Parameters:
    ///   - workout: the workout being warmed up for.
    ///   - target: the total time budget for the routine, in seconds. The cap on
    ///     stretch count is enforced regardless of time budget.
    static func suggestedStretches(for workout: Workout, target: TimeInterval = 360) -> [Stretch] {
        suggestedStretches(
            forExercises: workout.exercises.map(\.exercise),
            target: target
        )
    }

    /// Pick a routine of stretches for a template (template hasn't started yet).
    /// Same selection logic as `suggestedStretches(for: workout)`.
    static func suggestedStretches(for template: WorkoutTemplate, target: TimeInterval = 360) -> [Stretch] {
        suggestedStretches(
            forExercises: template.exercises.map(\.exercise),
            target: target
        )
    }

    /// Selective routine builder used by the workout/template overloads.
    /// Centralizes the explicit-recommendation → opener → frequency-fallback flow
    /// so both call sites stay in sync.
    static func suggestedStretches(forExercises exercises: [Exercise], target: TimeInterval = 360) -> [Stretch] {
        guard !exercises.isEmpty else {
            return defaultRoutine(target: target)
        }

        // 1) Union of explicit recommended stretches, preserving the source order
        //    so the first compound's prescription leads the routine.
        var picked: [Stretch] = []
        var pickedIds = Set<String>()
        for exercise in exercises {
            guard let ids = exercise.recommendedStretchIds else { continue }
            for id in ids where !pickedIds.contains(id) {
                if let stretch = byId(id) {
                    picked.append(stretch)
                    pickedIds.insert(id)
                }
                if picked.count >= maxStretches { break }
            }
            if picked.count >= maxStretches { break }
        }

        // 2) Mix in 1-2 general dynamic openers for flow. Insert at the start so
        //    the user moves before they static-stretch a specific muscle.
        var openersInserted = 0
        for id in generalOpenerIds {
            guard openersInserted < 2, !pickedIds.contains(id) else { continue }
            if let stretch = byId(id) {
                picked.insert(stretch, at: openersInserted)
                pickedIds.insert(id)
                openersInserted += 1
            }
            if picked.count >= maxStretches { break }
        }

        // 3) Fall back to the frequency logic only when we don't have enough yet.
        //    Anything we already picked (openers + explicit) wins over the fallback.
        if picked.count < 3 {
            let groups = exercises.flatMap { $0.muscleGroups }
            let fallback = suggestedStretches(forMuscleGroups: groups, target: target)
            for stretch in fallback where !pickedIds.contains(stretch.id) {
                picked.append(stretch)
                pickedIds.insert(stretch.id)
                if picked.count >= maxStretches { break }
            }
        }

        // 4) Final cap. The list can still be small (e.g. exotic exercise with no
        //    muscle-group hits), in which case we let WarmupView render what we have.
        if picked.count > maxStretches {
            picked = Array(picked.prefix(maxStretches))
        }

        return picked.isEmpty ? defaultRoutine(target: target) : picked
    }

    /// Underlying selection logic: rank stretches by how many of the workout's
    /// muscle groups they cover (weighted by how often each group appears),
    /// then pack them up to the time budget.
    static func suggestedStretches(forMuscleGroups groups: [MuscleGroup], target: TimeInterval = 360) -> [Stretch] {
        // Start with a sensible default if the workout has no muscle group data.
        guard !groups.isEmpty else {
            return defaultRoutine(target: target)
        }

        // How many times does each muscle group appear in the workout?
        var frequency: [MuscleGroup: Int] = [:]
        for group in groups {
            frequency[group, default: 0] += 1
        }

        // Score each stretch by the total frequency it covers.
        let scored: [(stretch: Stretch, score: Int)] = all.map { stretch in
            let score = stretch.targetMuscleGroups.reduce(0) { acc, g in acc + (frequency[g] ?? 0) }
            return (stretch, score)
        }

        // Stretches that cover at least one muscle group, sorted by score (desc), then duration (asc)
        // so we don't blow the time budget early on long stretches.
        let candidates = scored
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.stretch.durationSeconds < rhs.stretch.durationSeconds
            }
            .map(\.stretch)

        var picked: [Stretch] = []
        var pickedIds = Set<String>()
        var remaining = target

        // Always lead with a dynamic full-body stretch if we have one and there's room.
        if let opener = all.first(where: { $0.id == "st-worlds-greatest" }),
           remaining >= TimeInterval(opener.durationSeconds) {
            picked.append(opener)
            pickedIds.insert(opener.id)
            remaining -= TimeInterval(opener.durationSeconds)
        }

        for stretch in candidates {
            if pickedIds.contains(stretch.id) { continue }
            let cost = TimeInterval(stretch.durationSeconds)
            if cost > remaining { continue }
            picked.append(stretch)
            pickedIds.insert(stretch.id)
            remaining -= cost
            // Cap the routine length so we don't end up with a 12-stretch list.
            if picked.count >= 7 { break }
        }

        // Aim for at least 5 stretches when the budget allows; pad with fillers.
        if picked.count < 5 {
            let fillers = all
                .filter { !pickedIds.contains($0.id) }
                .sorted { $0.durationSeconds < $1.durationSeconds }
            for stretch in fillers {
                let cost = TimeInterval(stretch.durationSeconds)
                if cost > remaining { continue }
                picked.append(stretch)
                pickedIds.insert(stretch.id)
                remaining -= cost
                if picked.count >= 5 { break }
            }
        }

        // If we still got nothing useful (e.g. workout used a muscle group with no stretches),
        // fall back to the default routine.
        return picked.isEmpty ? defaultRoutine(target: target) : picked
    }

    // MARK: - Captions (#349)

    /// Short "why this stretch" line surfaced on the WarmupView preview rows.
    /// Cross-references the stretch's `targetMuscleGroups` with the workout's
    /// exercises so the caption names the lift the stretch is prepping for.
    ///
    /// Examples:
    /// - "Loosens chest + shoulders for Bench Press"
    /// - "Opens hips for Squat + Deadlift"
    /// - "Mobilizes shoulders" (no matching exercise)
    static func caption(for stretch: Stretch, in exercises: [Exercise]) -> String {
        // Match exercises whose recommended list contains this stretch first —
        // that's the strongest signal (the lift literally asked for this stretch).
        let explicit = exercises.filter {
            $0.recommendedStretchIds?.contains(stretch.id) == true
        }

        let matchedExercises: [Exercise]
        if !explicit.isEmpty {
            matchedExercises = explicit
        } else {
            // Fall back to muscle-group overlap so frequency-picked stretches
            // still get a meaningful caption.
            let targets = Set(stretch.targetMuscleGroups)
            matchedExercises = exercises.filter { !targets.isDisjoint(with: Set($0.muscleGroups)) }
        }

        let muscleText = stretch.targetMuscleGroups
            .prefix(2)
            .map { $0.displayName.lowercased() }
            .joined(separator: " + ")

        let verb = preferredVerb(for: stretch.targetMuscleGroups)

        guard !matchedExercises.isEmpty else {
            // No workout context — describe the stretch in isolation.
            if muscleText.isEmpty { return "Warmup mobility" }
            return "\(verb) \(muscleText)"
        }

        // De-dup exercise names while preserving order, then cap at 2 so the
        // caption stays readable on a row.
        var seen = Set<String>()
        var names: [String] = []
        for ex in matchedExercises {
            if !seen.contains(ex.name) {
                seen.insert(ex.name)
                names.append(ex.name)
            }
            if names.count >= 2 { break }
        }

        let liftSummary = names.joined(separator: " + ")
        if muscleText.isEmpty {
            return "Preps you for \(liftSummary)"
        }
        return "\(verb) \(muscleText) for \(liftSummary)"
    }

    /// Picks a verb appropriate for the muscle groups being stretched so captions
    /// don't always start with "loosens".
    private static func preferredVerb(for groups: [MuscleGroup]) -> String {
        // Hip / lower body openers read better with "opens".
        let hipGroups: Set<MuscleGroup> = [.glutes, .quads, .hamstrings]
        if groups.contains(where: { hipGroups.contains($0) }) {
            return "Opens"
        }
        // Mid-back / thoracic / shoulder mobility reads as "mobilizes".
        let mobilityGroups: Set<MuscleGroup> = [.shoulders, .back, .traps, .lats]
        if groups.allSatisfy({ mobilityGroups.contains($0) }) {
            return "Mobilizes"
        }
        return "Loosens"
    }

    /// A balanced full-body warmup used when we have no workout-specific info.
    static func defaultRoutine(target: TimeInterval = 360) -> [Stretch] {
        let preferredOrder = [
            "st-worlds-greatest",
            "st-cat-cow",
            "st-shoulder-dislocates",
            "st-deep-squat-hold",
            "st-90-90-hip",
            "st-childs-pose",
            "st-leg-swings",
        ]
        var picked: [Stretch] = []
        var remaining = target
        for id in preferredOrder {
            guard let stretch = byId(id) else { continue }
            let cost = TimeInterval(stretch.durationSeconds)
            if cost > remaining { continue }
            picked.append(stretch)
            remaining -= cost
        }
        return picked
    }
}
