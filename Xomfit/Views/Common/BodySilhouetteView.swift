import SwiftUI

/// Front or back of the anatomical silhouette.
///
/// Used by `FullBodyHeatmapView` (#346) and the mini silhouette inside
/// `ExerciseDetailSheet`. Front/back is a toggle, not two views shown at once,
/// so the same vertical real estate renders both sides.
enum BodySide: String, CaseIterable, Identifiable {
    case front
    case back

    var id: String { rawValue }

    var label: String {
        switch self {
        case .front: return "Front"
        case .back:  return "Back"
        }
    }
}

// MARK: - BodySilhouetteView

/// Stylised front/back human silhouette with per-muscle shading and tap-to-drill.
///
/// Each muscle group is an independent `Shape` so we can fill it with an
/// intensity-scaled accent color. The body itself is composed of simple
/// rounded primitives — no realistic anatomy, just enough mass to make the
/// shading legible. Black background + green accent gives the Hevy / Strong
/// aesthetic.
///
/// Coordinate system: shapes are authored in a canonical 200×400 layout, then
/// scaled by `GeometryReader` so the silhouette fills whatever size SwiftUI
/// hands it. This keeps every path tweak in one normalised space.
struct BodySilhouetteView: View {
    /// Which side to render. Use a SwiftUI `@State` in the caller and pass a binding-free value.
    let side: BodySide

    /// Fill color per muscle group. Missing keys render as `defaultMuscleFill`.
    /// Pass `Theme.accent.opacity(intensity)` here for the heatmap effect.
    let fillByMuscle: [MuscleGroup: Color]

    /// Optional tap handler. When nil, the silhouette is non-interactive (mini variant).
    var onMuscleTap: ((MuscleGroup) -> Void)? = nil

    /// Default fill for any muscle without an explicit entry in `fillByMuscle`.
    /// Slightly lifted vs `Theme.background` so the silhouette reads against the card.
    var defaultMuscleFill: Color = Theme.surface

    /// Outline color for the silhouette body + muscle borders.
    var outlineColor: Color = Theme.hairlineStrong

    /// Canonical authoring space. All paths are written against this size, then scaled.
    private static let canvasSize = CGSize(width: 200, height: 400)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / Self.canvasSize.width,
                proxy.size.height / Self.canvasSize.height
            )
            let scaledWidth = Self.canvasSize.width * scale
            let scaledHeight = Self.canvasSize.height * scale
            let originX = (proxy.size.width - scaledWidth) / 2
            let originY = (proxy.size.height - scaledHeight) / 2

            ZStack(alignment: .topLeading) {
                // Body outline silhouette — drawn first so muscles paint over it.
                BodyOutlineShape(side: side)
                    .fill(Theme.surface.opacity(0.6))
                    .overlay(
                        BodyOutlineShape(side: side)
                            .stroke(outlineColor, lineWidth: 1.0)
                    )
                    .frame(width: scaledWidth, height: scaledHeight)
                    .offset(x: originX, y: originY)

                // Muscle group shapes — one per group, on the visible side.
                ForEach(MuscleLayout.groups(for: side), id: \.self) { muscle in
                    let shape = MuscleShape(muscle: muscle, side: side)
                    shape
                        .fill(fillByMuscle[muscle] ?? defaultMuscleFill)
                        .overlay(
                            shape.stroke(outlineColor.opacity(0.7), lineWidth: 0.6)
                        )
                        .frame(width: scaledWidth, height: scaledHeight)
                        .offset(x: originX, y: originY)
                        .contentShape(shape)
                        .onTapGesture {
                            guard let handler = onMuscleTap else { return }
                            Haptics.selection()
                            handler(muscle)
                        }
                        .accessibilityElement()
                        .accessibilityLabel(Text(muscle.displayName))
                        .accessibilityAddTraits(onMuscleTap != nil ? .isButton : [])
                }
            }
        }
        .aspectRatio(Self.canvasSize.width / Self.canvasSize.height, contentMode: .fit)
    }
}

// MARK: - MuscleLayout

/// Static mapping of which muscle groups are visible on each side.
/// Keep in lockstep with `MuscleShape.path(for:side:in:)`.
private enum MuscleLayout {
    static func groups(for side: BodySide) -> [MuscleGroup] {
        switch side {
        case .front:
            return [.chest, .shoulders, .biceps, .forearms, .abs, .quads]
        case .back:
            return [.traps, .back, .lats, .triceps, .glutes, .hamstrings, .calves]
        }
    }
}

// MARK: - Body Outline Shape

/// The overall body silhouette — head + torso + arms + legs. Same primitives
/// for front/back; the difference is which muscles paint over it.
private struct BodyOutlineShape: Shape {
    let side: BodySide

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 200.0
        let sy = rect.height / 400.0
        var p = Path()

        // Head
        p.addEllipse(in: CGRect(x: 80 * sx, y: 8 * sy, width: 40 * sx, height: 48 * sy))

        // Neck
        p.addRect(CGRect(x: 92 * sx, y: 50 * sy, width: 16 * sx, height: 14 * sy))

        // Torso (trapezoid-ish via rounded rect)
        p.addRoundedRect(
            in: CGRect(x: 60 * sx, y: 62 * sy, width: 80 * sx, height: 140 * sy),
            cornerSize: CGSize(width: 18 * sx, height: 18 * sy)
        )

        // Shoulders / deltoid caps so the silhouette reads as upper-body wide
        p.addEllipse(in: CGRect(x: 44 * sx, y: 64 * sy, width: 36 * sx, height: 38 * sy))
        p.addEllipse(in: CGRect(x: 120 * sx, y: 64 * sy, width: 36 * sx, height: 38 * sy))

        // Upper arms
        p.addRoundedRect(
            in: CGRect(x: 40 * sx, y: 80 * sy, width: 26 * sx, height: 90 * sy),
            cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
        )
        p.addRoundedRect(
            in: CGRect(x: 134 * sx, y: 80 * sy, width: 26 * sx, height: 90 * sy),
            cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
        )

        // Forearms (slightly narrower)
        p.addRoundedRect(
            in: CGRect(x: 42 * sx, y: 168 * sy, width: 22 * sx, height: 70 * sy),
            cornerSize: CGSize(width: 10 * sx, height: 10 * sy)
        )
        p.addRoundedRect(
            in: CGRect(x: 136 * sx, y: 168 * sy, width: 22 * sx, height: 70 * sy),
            cornerSize: CGSize(width: 10 * sx, height: 10 * sy)
        )

        // Pelvis / waist
        p.addRoundedRect(
            in: CGRect(x: 64 * sx, y: 198 * sy, width: 72 * sx, height: 36 * sy),
            cornerSize: CGSize(width: 14 * sx, height: 14 * sy)
        )

        // Upper legs
        p.addRoundedRect(
            in: CGRect(x: 66 * sx, y: 230 * sy, width: 32 * sx, height: 100 * sy),
            cornerSize: CGSize(width: 14 * sx, height: 14 * sy)
        )
        p.addRoundedRect(
            in: CGRect(x: 102 * sx, y: 230 * sy, width: 32 * sx, height: 100 * sy),
            cornerSize: CGSize(width: 14 * sx, height: 14 * sy)
        )

        // Lower legs (calves area)
        p.addRoundedRect(
            in: CGRect(x: 70 * sx, y: 326 * sy, width: 26 * sx, height: 66 * sy),
            cornerSize: CGSize(width: 10 * sx, height: 10 * sy)
        )
        p.addRoundedRect(
            in: CGRect(x: 104 * sx, y: 326 * sy, width: 26 * sx, height: 66 * sy),
            cornerSize: CGSize(width: 10 * sx, height: 10 * sy)
        )

        _ = side // body outline is identical for front/back today; reserved for future side-specific tweaks.
        return p
    }
}

// MARK: - Muscle Shape

/// Renders the path for a single muscle group on a given side. Authored against
/// the same 200×400 canonical space as `BodyOutlineShape`, so the muscle sits
/// on top of the underlying body silhouette without drift.
private struct MuscleShape: Shape {
    let muscle: MuscleGroup
    let side: BodySide

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 200.0
        let sy = rect.height / 400.0

        switch (side, muscle) {
        // MARK: Front

        case (.front, .chest):
            // Two pec slabs side-by-side near the upper torso.
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 66 * sx, y: 78 * sy, width: 32 * sx, height: 40 * sy),
                cornerSize: CGSize(width: 10 * sx, height: 10 * sy)
            )
            p.addRoundedRect(
                in: CGRect(x: 102 * sx, y: 78 * sy, width: 32 * sx, height: 40 * sy),
                cornerSize: CGSize(width: 10 * sx, height: 10 * sy)
            )
            return p

        case (.front, .shoulders):
            // Front deltoid caps — overlap shoulder ovals.
            var p = Path()
            p.addEllipse(in: CGRect(x: 46 * sx, y: 66 * sy, width: 30 * sx, height: 30 * sy))
            p.addEllipse(in: CGRect(x: 124 * sx, y: 66 * sy, width: 30 * sx, height: 30 * sy))
            return p

        case (.front, .biceps):
            // Upper arms, slightly narrower than the outline so the body edge shows.
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 44 * sx, y: 96 * sy, width: 20 * sx, height: 64 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            p.addRoundedRect(
                in: CGRect(x: 136 * sx, y: 96 * sy, width: 20 * sx, height: 64 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            return p

        case (.front, .forearms):
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 44 * sx, y: 170 * sy, width: 18 * sx, height: 60 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            p.addRoundedRect(
                in: CGRect(x: 138 * sx, y: 170 * sy, width: 18 * sx, height: 60 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            return p

        case (.front, .abs):
            // Stacked rectangle block over the lower torso.
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 84 * sx, y: 124 * sy, width: 32 * sx, height: 74 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            return p

        case (.front, .quads):
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 68 * sx, y: 236 * sy, width: 28 * sx, height: 88 * sy),
                cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
            )
            p.addRoundedRect(
                in: CGRect(x: 104 * sx, y: 236 * sy, width: 28 * sx, height: 88 * sy),
                cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
            )
            return p

        // MARK: Back

        case (.back, .traps):
            // Upper-back trapezoid between shoulders.
            var p = Path()
            p.move(to: CGPoint(x: 80 * sx, y: 64 * sy))
            p.addLine(to: CGPoint(x: 120 * sx, y: 64 * sy))
            p.addLine(to: CGPoint(x: 110 * sx, y: 96 * sy))
            p.addLine(to: CGPoint(x: 90 * sx, y: 96 * sy))
            p.closeSubpath()
            return p

        case (.back, .back):
            // Upper-mid back slab (general "back" group used by deadlift, rows).
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 72 * sx, y: 96 * sy, width: 56 * sx, height: 36 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            return p

        case (.back, .lats):
            // Two flared wings on either side of the mid back.
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 62 * sx, y: 130 * sy, width: 28 * sx, height: 66 * sy),
                cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
            )
            p.addRoundedRect(
                in: CGRect(x: 110 * sx, y: 130 * sy, width: 28 * sx, height: 66 * sy),
                cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
            )
            return p

        case (.back, .triceps):
            // Upper arm — same slot as biceps on front, painted on the back side.
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 44 * sx, y: 96 * sy, width: 20 * sx, height: 64 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            p.addRoundedRect(
                in: CGRect(x: 136 * sx, y: 96 * sy, width: 20 * sx, height: 64 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            return p

        case (.back, .glutes):
            // Two rounded glute lobes at the pelvis.
            var p = Path()
            p.addEllipse(in: CGRect(x: 68 * sx, y: 200 * sy, width: 30 * sx, height: 36 * sy))
            p.addEllipse(in: CGRect(x: 102 * sx, y: 200 * sy, width: 30 * sx, height: 36 * sy))
            return p

        case (.back, .hamstrings):
            // Posterior thigh — slightly higher than quads to leave the calves visible.
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 68 * sx, y: 240 * sy, width: 28 * sx, height: 84 * sy),
                cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
            )
            p.addRoundedRect(
                in: CGRect(x: 104 * sx, y: 240 * sy, width: 28 * sx, height: 84 * sy),
                cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
            )
            return p

        case (.back, .calves):
            var p = Path()
            p.addRoundedRect(
                in: CGRect(x: 72 * sx, y: 330 * sy, width: 22 * sx, height: 58 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            p.addRoundedRect(
                in: CGRect(x: 106 * sx, y: 330 * sy, width: 22 * sx, height: 58 * sy),
                cornerSize: CGSize(width: 8 * sx, height: 8 * sy)
            )
            return p

        // Muscles that aren't visible on the given side render an empty path
        // (so they're invisible / non-interactive).
        default:
            return Path()
        }
    }
}

// MARK: - Preview

#Preview("Front") {
    BodySilhouetteView(
        side: .front,
        fillByMuscle: [
            .chest: Theme.accent.opacity(0.8),
            .biceps: Theme.accent.opacity(0.5),
            .abs: Theme.accent.opacity(0.3),
            .quads: Theme.accent.opacity(0.65),
        ],
        onMuscleTap: { _ in }
    )
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}

#Preview("Back") {
    BodySilhouetteView(
        side: .back,
        fillByMuscle: [
            .lats: Theme.accent.opacity(0.7),
            .glutes: Theme.accent.opacity(0.45),
            .hamstrings: Theme.accent.opacity(0.55),
            .calves: Theme.accent.opacity(0.25),
        ],
        onMuscleTap: { _ in }
    )
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
