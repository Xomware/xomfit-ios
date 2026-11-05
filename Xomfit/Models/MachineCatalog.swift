import Foundation

/// Static catalog of branded machines.
///
/// Arsenal Strength names and features come from the manufacturer's shop
/// (theshop.myarsenalstrength.com, collections `reloaded-series`, `m-1-series`,
/// `alpha-series`). Reloaded is plate-loaded and M-1 is selectorized. Alpha is
/// mostly benches and racks, so only its Smith machine is listed. The M-1
/// functional trainer and Basic Trainer cable stations are left out: they are
/// generic cable stations, covered by `Equipment.cable` on a gym profile.
///
/// Grip and position overrides only list what the product page describes
/// (e.g. the Standing Chest Press's horizontal and neutral handles).
enum MachineCatalog {
    static let all: [Machine] = arsenalReloaded + arsenalM1 + arsenalAlpha

    static let byId: [String: Machine] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Machines that can perform the given exercise, in catalog order.
    static func machines(for exerciseId: String) -> [Machine] {
        all.filter { $0.exerciseIds.contains(exerciseId) }
    }

    private static let arsenal = "Arsenal"
    private static let rowGrips: [GripType] = [.overhand, .neutral, .underhand]

    private static let arsenalReloaded: [Machine] = [
        Machine(id: "arsenal-reloaded-incline-fly", brand: arsenal, series: "Reloaded", name: "Incline Fly",
                loading: .plateLoaded, muscleGroups: [.chest, .shoulders],
                exerciseIds: ["ex-machine-incline-fly"]),
        Machine(id: "arsenal-reloaded-pendulum-squat", brand: arsenal, series: "Reloaded", name: "Pendulum Squat",
                loading: .plateLoaded, muscleGroups: [.quads, .glutes],
                exerciseIds: ["ex-pendulum-squat"]),
        Machine(id: "arsenal-reloaded-lever-row", brand: arsenal, series: "Reloaded", name: "Lever Row",
                loading: .plateLoaded, muscleGroups: [.back, .lats, .biceps],
                exerciseIds: ["ex-chest-supported-row", "ex-tbar-row"],
                grips: rowGrips + [.wide, .close]),
        Machine(id: "arsenal-reloaded-glute-bridge", brand: arsenal, series: "Reloaded", name: "Glute Bridge",
                loading: .plateLoaded, muscleGroups: [.glutes, .hamstrings],
                exerciseIds: ["ex-machine-glute-bridge"]),
        Machine(id: "arsenal-reloaded-iso-multi-row", brand: arsenal, series: "Reloaded", name: "ISO Multi Row",
                loading: .plateLoaded, muscleGroups: [.back, .lats],
                exerciseIds: ["ex-machine-row", "ex-single-arm-machine-row"]),
        Machine(id: "arsenal-reloaded-iso-shoulder-press", brand: arsenal, series: "Reloaded", name: "ISO Shoulder Press",
                loading: .plateLoaded, muscleGroups: [.shoulders, .triceps],
                exerciseIds: ["ex-machine-shoulder-press"]),
        Machine(id: "arsenal-reloaded-linear-leg-press", brand: arsenal, series: "Reloaded", name: "Linear Leg Press",
                loading: .plateLoaded, muscleGroups: [.quads, .glutes, .hamstrings],
                exerciseIds: ["ex-leg-press", "ex-single-leg-press", "ex-leg-press-calf-raise"]),
        Machine(id: "arsenal-reloaded-standing-chest-press", brand: arsenal, series: "Reloaded", name: "Standing Chest Press",
                loading: .plateLoaded, muscleGroups: [.chest, .triceps],
                exerciseIds: ["ex-machine-press"],
                grips: [.overhand, .neutral], positions: [.standing]),
        Machine(id: "arsenal-reloaded-linear-hack-squat", brand: arsenal, series: "Reloaded", name: "Linear Hack Squat",
                loading: .plateLoaded, muscleGroups: [.quads, .glutes],
                exerciseIds: ["ex-hack-squat"]),
        Machine(id: "arsenal-reloaded-iso-incline-press", brand: arsenal, series: "Reloaded", name: "ISO Incline Press",
                loading: .plateLoaded, muscleGroups: [.chest, .shoulders],
                exerciseIds: ["ex-incline-machine-press"]),
        Machine(id: "arsenal-reloaded-tricep-kickback-dip", brand: arsenal, series: "Reloaded", name: "Tricep Kickback/Dip",
                loading: .plateLoaded, muscleGroups: [.triceps],
                exerciseIds: ["ex-tricep-dip-machine"]),
        Machine(id: "arsenal-reloaded-multi-flex", brand: arsenal, series: "Reloaded", name: "Multi Flex",
                loading: .plateLoaded, muscleGroups: [.chest, .shoulders, .back],
                exerciseIds: ["ex-machine-press", "ex-machine-shoulder-press", "ex-machine-row"]),
        Machine(id: "arsenal-reloaded-leg-extension-seated-leg-curl", brand: arsenal, series: "Reloaded",
                name: "Leg Extension/Seated Leg Curl",
                loading: .plateLoaded, muscleGroups: [.quads, .hamstrings],
                exerciseIds: ["ex-leg-ext", "ex-single-leg-ext", "ex-seated-leg-curl"]),
        Machine(id: "arsenal-reloaded-viking-press", brand: arsenal, series: "Reloaded", name: "Viking Press",
                loading: .plateLoaded, muscleGroups: [.shoulders, .triceps],
                exerciseIds: ["ex-viking-press"]),
        Machine(id: "arsenal-reloaded-vertical-row", brand: arsenal, series: "Reloaded", name: "Vertical Row",
                loading: .plateLoaded, muscleGroups: [.back, .lats],
                exerciseIds: ["ex-machine-row", "ex-machine-high-row"],
                grips: rowGrips, positions: [.seated, .standing]),
        Machine(id: "arsenal-reloaded-seated-calf-raise", brand: arsenal, series: "Reloaded", name: "Seated Calf Raise",
                loading: .plateLoaded, muscleGroups: [.calves],
                exerciseIds: ["ex-seated-calf-raise"]),
        Machine(id: "arsenal-reloaded-iso-flat-press", brand: arsenal, series: "Reloaded", name: "ISO Flat Press",
                loading: .plateLoaded, muscleGroups: [.chest, .triceps],
                exerciseIds: ["ex-machine-press"],
                positions: [.lying]),
        Machine(id: "arsenal-reloaded-power-squat", brand: arsenal, series: "Reloaded", name: "Power Squat",
                loading: .plateLoaded, muscleGroups: [.quads, .glutes],
                exerciseIds: ["ex-power-squat"]),
        Machine(id: "arsenal-reloaded-bilateral-leg-press", brand: arsenal, series: "Reloaded", name: "Bilateral Leg Press",
                loading: .plateLoaded, muscleGroups: [.quads, .glutes],
                exerciseIds: ["ex-leg-press", "ex-single-leg-press"]),
        Machine(id: "arsenal-reloaded-t-bar-row", brand: arsenal, series: "Reloaded", name: "T Bar Row",
                loading: .plateLoaded, muscleGroups: [.back, .lats, .biceps],
                exerciseIds: ["ex-tbar-row"],
                grips: [.wide, .close]),
        Machine(id: "arsenal-reloaded-belt-squat", brand: arsenal, series: "Reloaded", name: "Belt Squat",
                loading: .plateLoaded, muscleGroups: [.quads, .glutes],
                exerciseIds: ["ex-belt-squat"]),
        Machine(id: "arsenal-reloaded-vertical-chest-press", brand: arsenal, series: "Reloaded", name: "Vertical Chest Press",
                loading: .plateLoaded, muscleGroups: [.chest, .triceps],
                exerciseIds: ["ex-machine-press"],
                grips: [.wide, .close]),
        Machine(id: "arsenal-reloaded-linear-smith-row", brand: arsenal, series: "Reloaded", name: "Linear Smith Row",
                loading: .plateLoaded, muscleGroups: [.back, .lats],
                exerciseIds: ["ex-chest-supported-row"],
                grips: rowGrips),
        Machine(id: "arsenal-reloaded-vertical-leg-press", brand: arsenal, series: "Reloaded", name: "Vertical Leg Press",
                loading: .plateLoaded, muscleGroups: [.quads, .glutes],
                exerciseIds: ["ex-vertical-leg-press"]),
        Machine(id: "arsenal-reloaded-iso-lat-pulldown", brand: arsenal, series: "Reloaded", name: "ISO Lat Pulldown",
                loading: .plateLoaded, muscleGroups: [.lats, .back, .biceps],
                exerciseIds: ["ex-lat-pulldown", "ex-single-arm-lat-pulldown"],
                grips: rowGrips),
    ]

    private static let arsenalM1: [Machine] = [
        Machine(id: "arsenal-m1-standing-lateral-raise", brand: arsenal, series: "M-1", name: "Standing Lateral Raise",
                loading: .selectorized, muscleGroups: [.shoulders],
                exerciseIds: ["ex-machine-lateral-raise"],
                positions: [.standing]),
        Machine(id: "arsenal-m1-pec-fly-rear-delt", brand: arsenal, series: "M-1", name: "Pec Fly/Rear Delt",
                loading: .selectorized, muscleGroups: [.chest, .shoulders],
                exerciseIds: ["ex-pec-deck", "ex-reverse-pec-deck"],
                grips: [.overhand, .neutral]),
        Machine(id: "arsenal-m1-leg-extension", brand: arsenal, series: "M-1", name: "Leg Extension",
                loading: .selectorized, muscleGroups: [.quads],
                exerciseIds: ["ex-leg-ext", "ex-single-leg-ext"]),
        Machine(id: "arsenal-m1-lat-pullover", brand: arsenal, series: "M-1", name: "Lat Pullover",
                loading: .selectorized, muscleGroups: [.lats, .back],
                exerciseIds: ["ex-pullover-machine"]),
        Machine(id: "arsenal-m1-donkey-calf-raise", brand: arsenal, series: "M-1", name: "Donkey Calf Raise",
                loading: .selectorized, muscleGroups: [.calves],
                exerciseIds: ["ex-donkey-calf-raise"]),
        Machine(id: "arsenal-m1-standing-calf-raise", brand: arsenal, series: "M-1", name: "Standing Calf Raise",
                loading: .selectorized, muscleGroups: [.calves],
                exerciseIds: ["ex-standing-calf-machine"]),
        Machine(id: "arsenal-m1-standing-leg-curl", brand: arsenal, series: "M-1", name: "Standing Leg Curl",
                loading: .selectorized, muscleGroups: [.hamstrings],
                exerciseIds: ["ex-single-leg-curl"],
                positions: [.standing]),
        Machine(id: "arsenal-m1-lying-leg-curl", brand: arsenal, series: "M-1", name: "Lying Leg Curl",
                loading: .selectorized, muscleGroups: [.hamstrings],
                exerciseIds: ["ex-leg-curl"],
                positions: [.lying]),
    ]

    private static let arsenalAlpha: [Machine] = [
        Machine(id: "arsenal-alpha-smith-machine", brand: arsenal, series: "Alpha", name: "Smith Machine",
                loading: .plateLoaded, muscleGroups: [.quads, .chest, .shoulders, .back],
                exerciseIds: ["ex-smith-squat", "ex-smith-front-squat", "ex-smith-bench-press",
                              "ex-smith-incline-press", "ex-smith-shoulder-press", "ex-smith-row",
                              "ex-smith-calf-raise"]),
    ]
}
