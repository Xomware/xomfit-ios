import Foundation

/// Deterministic, seedable random number generator (SplitMix64).
///
/// Used so `WorkoutGenerator` is fully reproducible from a seed: same seed →
/// identical output. Injected via Swift's `RandomNumberGenerator`-taking APIs
/// (`randomElement(using:)`, `shuffled(using:)`). Not cryptographic — this is
/// workout generation, not security. Kept `internal` so unit tests can build it.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid an all-zero state degenerating the stream.
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Pure, offline, constrained-random workout generator.
///
/// Turns a set of target `MuscleGroup`s + a time budget + a per-exercise set
/// count into a runnable `WorkoutTemplate`, biased toward exercises the user has
/// logged before (familiarity) while still surfacing novelty. Fully deterministic
/// given a `seed`.
///
/// This type performs **no** service calls, no I/O, and is not `@MainActor`. It is
/// the instant/offline twin of the AI Coach `build_workout` flow — it shares only
/// the `WorkoutTemplate` output type. All service access (history fetch, start,
/// save) lives in `WorkoutGeneratorViewModel`.
struct WorkoutGenerator {

    // MARK: - Tunables (single source of truth)

    /// Time → exercise-count heuristic: ~2 minutes per working set. Matches
    /// `WorkoutBuilderViewModel.estimatedDuration` (`sets * 2`).
    static let minutesPerSet = 2
    /// Bias multiplier applied (log-scaled) to exercises the user has logged.
    static let familiarityWeight = 3.0
    /// Base weight so unlogged lifts still appear (novelty floor).
    static let noveltyFloor = 1.0

    // MARK: - Generate

    /// Build a `WorkoutTemplate` from the given configuration.
    ///
    /// - Parameters:
    ///   - targets: muscle groups the user selected (split chips expand into these).
    ///   - timeBudgetMinutes: total session budget; drives exercise count.
    ///   - targetSets: working sets per exercise.
    ///   - familiarity: `exerciseId → logged-set count` (from the history walk).
    ///   - seed: fixed seed for reproducible output / reroll continuity.
    func generate(
        targets: [MuscleGroup],
        timeBudgetMinutes: Int,
        targetSets: Int,
        familiarity: [String: Int],
        seed: UInt64
    ) -> WorkoutTemplate {
        let targetSet = Set(targets)
        let pool = Self.pool(for: targetSet)

        // No exercises match the selection → empty (but valid) template.
        guard !pool.isEmpty else {
            return Self.assemble(
                picks: [],
                targets: targets,
                targetSets: targetSets
            )
        }

        var rng = SeededGenerator(seed: seed)

        // Rule 2 — exercise count from time budget, clamped to [2, poolCount].
        let denominator = max(1, targetSets * Self.minutesPerSet)
        let rawCount = timeBudgetMinutes / denominator
        let exerciseCount = max(2, min(pool.count, max(2, rawCount)))

        // Rule 3 — distribute slots across selected groups, weighted by each
        // group's filtered pool size, with round-robin remainder distribution.
        let slotGroups = Self.allocateSlots(
            count: exerciseCount,
            targets: targets,
            pool: pool
        )

        // Rule 4 — per-slot familiarity-weighted pick, no duplicates.
        var chosen: [Exercise] = []
        var chosenIds = Set<String>()
        for group in slotGroups {
            let subPool = pool.filter { $0.muscleGroups.contains(group) && !chosenIds.contains($0.id) }
            // Fall back to the whole remaining pool if this group is exhausted.
            let candidates = subPool.isEmpty
                ? pool.filter { !chosenIds.contains($0.id) }
                : subPool
            guard let pick = Self.weightedPick(from: candidates, familiarity: familiarity, using: &rng) else {
                continue
            }
            chosen.append(pick)
            chosenIds.insert(pick.id)
        }

        // Rule 5 — stable compound-before-isolation ordering (preserve selection
        // order within a category).
        let ordered = Self.compoundFirst(chosen)

        // Rules 6 & 7 — rep schemes + template assembly.
        let picks = ordered.map { ($0, Self.repScheme(for: $0.category, using: &rng)) }
        return Self.assemble(picks: picks, targets: targets, targetSets: targetSets)
    }

    // MARK: - Reroll

    /// Recompute a single slot, leaving every other slot byte-identical.
    ///
    /// Picks a replacement from the slot's muscle sub-pool, excluding every
    /// exercise currently in the template (so reroll never duplicates and never
    /// returns the current exercise unless the pool has size 1), re-applies a rep
    /// scheme, and re-sorts compound-before-isolation. Deterministic per seed.
    func reroll(
        slot: Int,
        in template: WorkoutTemplate,
        targets: [MuscleGroup],
        familiarity: [String: Int],
        seed: UInt64
    ) -> WorkoutTemplate {
        guard template.exercises.indices.contains(slot) else { return template }

        let targetSet = Set(targets)
        let pool = Self.pool(for: targetSet)
        let current = template.exercises[slot]

        // Anchor the rerolled slot to one of the current exercise's target groups
        // that's also in the selection, so the swap stays on-theme.
        let slotGroup = current.exercise.muscleGroups.first { targetSet.contains($0) }

        let existingIds = Set(template.exercises.map { $0.exercise.id })
        var candidates = pool.filter { ex in
            !existingIds.contains(ex.id) &&
            (slotGroup == nil || ex.muscleGroups.contains(slotGroup!))
        }
        // If the on-theme sub-pool is empty, widen to anything in the pool not
        // already in the template.
        if candidates.isEmpty {
            candidates = pool.filter { !existingIds.contains($0.id) }
        }
        // Pool size 1 (or fully exhausted) → nothing to swap to; keep current.
        guard !candidates.isEmpty else { return template }

        // Seed the slot so reroll is reproducible yet differs per slot.
        var rng = SeededGenerator(seed: seed &+ UInt64(slot) &+ 1)
        guard let replacement = Self.weightedPick(from: candidates, familiarity: familiarity, using: &rng) else {
            return template
        }

        let newExercise = WorkoutTemplate.TemplateExercise(
            id: UUID().uuidString,
            exercise: replacement,
            targetSets: current.targetSets,
            targetReps: Self.repScheme(for: replacement.category, using: &rng),
            notes: nil
        )

        var exercises = template.exercises
        exercises[slot] = newExercise

        // Re-sort compound-before-isolation (stable, preserving order within group).
        let resorted = Self.compoundFirst(exercises.map { $0.exercise }).map { sortedEx -> WorkoutTemplate.TemplateExercise in
            exercises.first { $0.exercise.id == sortedEx.id }!
        }

        var result = template
        result.exercises = resorted
        return result
    }

    // MARK: - Algorithm helpers (pure, static)

    /// Rule 1 — pool = full catalog filtered to exercises that target one of the
    /// selected muscles and are `.compound` or `.isolation` (cardio/stretch excluded).
    static func pool(for targets: Set<MuscleGroup>) -> [Exercise] {
        guard !targets.isEmpty else { return [] }
        return ExerciseDatabase.all.filter { ex in
            (ex.category == .compound || ex.category == .isolation) &&
            !ex.muscleGroups.filter(targets.contains).isEmpty
        }
    }

    /// Rule 3 — ordered list of `(group)` slot intents, weighted by each group's
    /// filtered pool size. Larger groups (back/legs) get more slots than small
    /// ones (calves/abs); the integer remainder is distributed round-robin in
    /// descending-pool order for determinism.
    static func allocateSlots(count: Int, targets: [MuscleGroup], pool: [Exercise]) -> [MuscleGroup] {
        // De-dupe targets, preserving order.
        var seen = Set<MuscleGroup>()
        let groups = targets.filter { seen.insert($0).inserted }
        guard !groups.isEmpty, count > 0 else { return [] }

        // Pool size per group (how many exercises hit that muscle).
        let sizes: [(group: MuscleGroup, size: Int)] = groups.map { g in
            (g, pool.filter { $0.muscleGroups.contains(g) }.count)
        }
        let totalSize = sizes.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else {
            // No pool weighting possible — even round-robin.
            return (0..<count).map { groups[$0 % groups.count] }
        }

        // Proportional allocation (floor), then distribute the remainder.
        var allocation: [(group: MuscleGroup, slots: Int, frac: Double)] = sizes.map { entry in
            let exact = Double(count) * Double(entry.size) / Double(totalSize)
            return (entry.group, Int(exact.rounded(.down)), exact - exact.rounded(.down))
        }
        var assigned = allocation.reduce(0) { $0 + $1.slots }
        // Hand out leftover slots to the largest fractional remainders first
        // (ties broken by larger pool, then enum order) — deterministic.
        let order = allocation.indices.sorted {
            if allocation[$0].frac != allocation[$1].frac { return allocation[$0].frac > allocation[$1].frac }
            return sizes[$0].size > sizes[$1].size
        }
        var oi = 0
        while assigned < count, !order.isEmpty {
            allocation[order[oi % order.count]].slots += 1
            assigned += 1
            oi += 1
        }

        // Expand into an ordered slot list, interleaving groups by descending
        // allocation so the workout opens with the dominant muscle.
        var remaining = allocation.map { (group: $0.group, slots: $0.slots) }
            .sorted { $0.slots > $1.slots }
        var slots: [MuscleGroup] = []
        while slots.count < count {
            var progressed = false
            for i in remaining.indices where remaining[i].slots > 0 {
                slots.append(remaining[i].group)
                remaining[i].slots -= 1
                progressed = true
                if slots.count == count { break }
            }
            if !progressed { break }
        }
        return slots
    }

    /// Rule 4 — familiarity-weighted random pick.
    /// `weight = noveltyFloor + familiarityWeight * log(1 + familiarity[id])`.
    static func weightedPick(
        from candidates: [Exercise],
        familiarity: [String: Int],
        using rng: inout SeededGenerator
    ) -> Exercise? {
        guard !candidates.isEmpty else { return nil }
        let weights = candidates.map { ex -> Double in
            let freq = Double(familiarity[ex.id] ?? 0)
            return noveltyFloor + familiarityWeight * log(1 + freq)
        }
        let total = weights.reduce(0, +)
        guard total > 0 else { return candidates.randomElement(using: &rng) }
        let roll = Double.random(in: 0..<total, using: &rng)
        var cumulative = 0.0
        for (i, w) in weights.enumerated() {
            cumulative += w
            if roll < cumulative { return candidates[i] }
        }
        return candidates.last
    }

    /// Rule 5 — stable sort placing `.compound` before `.isolation`, preserving
    /// the input order within each category.
    static func compoundFirst(_ exercises: [Exercise]) -> [Exercise] {
        let compounds = exercises.filter { $0.category == .compound }
        let isolations = exercises.filter { $0.category != .compound }
        return compounds + isolations
    }

    /// Rule 6 — category-appropriate rep scheme, chosen via the seeded RNG so it's
    /// deterministic but not always the same literal.
    static func repScheme(for category: ExerciseCategory, using rng: inout SeededGenerator) -> String {
        switch category {
        case .compound:
            return ["5", "6-8"].randomElement(using: &rng) ?? "5"
        case .isolation:
            return ["10-12", "12-15"].randomElement(using: &rng) ?? "10-12"
        case .cardio, .stretching:
            // Not generated in v1; defensive fallback.
            return "10-12"
        }
    }

    /// Rule 7 — assemble the output `WorkoutTemplate`.
    static func assemble(
        picks: [(Exercise, String)],
        targets: [MuscleGroup],
        targetSets: Int
    ) -> WorkoutTemplate {
        let templateExercises = picks.map { (exercise, reps) in
            WorkoutTemplate.TemplateExercise(
                id: UUID().uuidString,
                exercise: exercise,
                targetSets: targetSets,
                targetReps: reps,
                notes: nil
            )
        }
        let count = templateExercises.count
        let duration = count * targetSets * minutesPerSet
        let region = dominantRegion(targets: targets)

        return WorkoutTemplate(
            id: UUID().uuidString,
            name: name(for: region, targets: targets),
            description: "\(count) exercises, ~\(duration)min",
            exercises: templateExercises,
            estimatedDuration: duration,
            category: region?.templateCategory ?? .custom,
            isCustom: true
        )
    }

    /// The single region that most of the selected muscles roll up into, or nil
    /// when the selection spans regions evenly (mixed).
    static func dominantRegion(targets: [MuscleGroup]) -> TrainingRegion? {
        guard !targets.isEmpty else { return nil }
        var counts: [TrainingRegion: Int] = [:]
        for muscle in targets { counts[muscle.region, default: 0] += 1 }
        let sorted = counts.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key.rawValue < $1.key.rawValue
        }
        // Mixed when two or more regions tie for the lead.
        guard let top = sorted.first else { return nil }
        let leaders = sorted.filter { $0.value == top.value }
        return leaders.count == 1 ? top.key : nil
    }

    static func name(for region: TrainingRegion?, targets: [MuscleGroup]) -> String {
        guard !targets.isEmpty else { return "Generated Workout" }
        if let region { return "\(region.displayName) Generator" }
        return "Mixed Generator"
    }
}
