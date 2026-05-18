import Foundation

/// A curated stretching sequence — a pre-built playlist of `Stretch` IDs that
/// runs end-to-end as a guided session (#388).
///
/// Templates intentionally reference stretches by ID (not by value) so that
/// updates to a stretch's description / duration in `StretchDatabase` flow
/// through automatically without re-defining every template.
///
/// Loose parallel to `WorkoutTemplate`: name, description, an ordered list of
/// referenced items, plus a computed total duration.
struct StretchTemplate: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    /// Body-area tag — drives the badge color/icon on the template card and
    /// keeps the carousel visually organized.
    var category: StretchCategory
    /// Ordered list of `Stretch.id`s. Unknown IDs are skipped at runtime so a
    /// template stays usable if a referenced stretch is renamed/removed.
    var stretchIds: [String]
    /// Optional SF Symbol override. Falls back to the category icon when nil.
    var iconSystemName: String?

    /// Resolved stretches in template order. IDs that don't resolve are dropped.
    var stretches: [Stretch] {
        stretchIds.compactMap { StretchDatabase.byId($0) }
    }

    /// Sum of per-stretch hold times in seconds. Driven by the resolved
    /// stretches so missing IDs don't inflate the duration.
    var totalDurationSeconds: Int {
        stretches.reduce(0) { $0 + $1.durationSeconds }
    }

    /// Rounded "X min" string used on template cards.
    var totalDurationLabel: String {
        let secs = totalDurationSeconds
        if secs < 60 { return "\(secs) sec" }
        let mins = (secs + 30) / 60   // round to nearest minute
        return "\(mins) min"
    }

    var iconName: String {
        iconSystemName ?? category.icon
    }
}

// MARK: - Curated Templates

extension StretchTemplate {
    /// Built-in stretching sequences surfaced at the top of the Stretches view.
    /// Each is short (4-7 stretches) so it stays approachable and finishes in
    /// under 6 minutes. Pick stretches that already live in `StretchDatabase`.
    static let curated: [StretchTemplate] = [
        StretchTemplate(
            id: "stpl-pre-lift",
            name: "Pre-Lift Warmup",
            description: "Wake up the hips, thoracic spine, and shoulders before a heavy session. Dynamic, not static — keep moving.",
            category: .fullBody,
            stretchIds: [
                "st-cat-cow",
                "st-worlds-greatest",
                "st-shoulder-dislocates",
                "st-deep-squat-hold",
                "st-hip-flexor-lunge",
                "st-thoracic-rotation",
            ],
            iconSystemName: "flame.fill"
        ),
        StretchTemplate(
            id: "stpl-post-run-lower",
            name: "Post-Run Lower Body",
            description: "Cool the legs down after a run. Hits the hamstrings, calves, hips, and glutes — hold each one and breathe.",
            category: .lowerBody,
            stretchIds: [
                "st-standing-forward-fold",
                "st-calf-wall",
                "st-soleus-bent-knee-calf",
                "st-pigeon",
                "st-figure-four",
                "st-couch-stretch",
            ],
            iconSystemName: "figure.run"
        ),
        StretchTemplate(
            id: "stpl-desk-mobility",
            name: "Desk Worker Mobility",
            description: "Reset hips, lats, and neck after a long sit. Short, simple stretches that don't need any floor space.",
            category: .upperBody,
            stretchIds: [
                "st-chin-tuck",
                "st-cross-body-shoulder",
                "st-overhead-tricep",
                "st-doorway-chest",
                "st-lat-overhead",
                "st-hip-flexor-lunge",
            ],
            iconSystemName: "laptopcomputer"
        ),
        StretchTemplate(
            id: "stpl-full-body-cooldown",
            name: "Full-Body Cooldown",
            description: "Slow it all down after a tough workout. Static holds top-to-bottom to bring your heart rate back and ease the spine.",
            category: .fullBody,
            stretchIds: [
                "st-childs-pose",
                "st-down-dog",
                "st-pigeon",
                "st-supine-twist",
                "st-figure-four",
                "st-seated-forward-fold",
            ],
            iconSystemName: "moon.stars.fill"
        ),
        StretchTemplate(
            id: "stpl-hip-opener",
            name: "Hip Opener Flow",
            description: "Targeted opener for tight hips. Mix of supine, kneeling, and seated holds — finish with a deep squat.",
            category: .hips,
            stretchIds: [
                "st-supine-figure-four",
                "st-butterfly",
                "st-frog",
                "st-90-90-hip",
                "st-pigeon",
                "st-deep-squat-hold",
            ],
            iconSystemName: "figure.cooldown"
        ),
        StretchTemplate(
            id: "stpl-upper-body-reset",
            name: "Upper Body Reset",
            description: "Five minutes to undo desk slump and pre-bench tightness. Chest, lats, neck, and forearms.",
            category: .upperBody,
            stretchIds: [
                "st-doorway-chest",
                "st-shoulder-dislocates",
                "st-thread-the-needle",
                "st-lat-overhead",
                "st-forearm-prayer",
                "st-chin-tuck",
            ],
            iconSystemName: "figure.arms.open"
        ),
    ]
}
