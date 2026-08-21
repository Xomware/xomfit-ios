import SwiftUI

// MARK: - Availability-gated chrome
//
// The project file says `IPHONEOS_DEPLOYMENT_TARGET = 26.2`, but the TestFlight
// workflow archives with `IPHONEOS_DEPLOYMENT_TARGET=18.0` (see the Archive step
// in `.github/workflows/testflight-deploy.yml`). The **shipping** floor is
// therefore iOS 18; the project setting only describes local development.
//
// This is a real trap: a Debug simulator build compiles iOS 26 APIs happily and
// the release archive then fails in CI. Anything newer than iOS 18 needs an
// `if #available` gate with a working fallback, not just a version bump.

extension View {
    /// Liquid Glass on iOS 26+, with the closest pre-26 equivalent below it.
    ///
    /// The fallback is `.ultraThinMaterial` plus a hairline stroke — the same
    /// treatment the workout resume bar used before Liquid Glass existed, so
    /// floating chrome still reads as its own layer on iOS 18.
    @ViewBuilder
    func xomGlass<S: InsettableShape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(shape.fill(.ultraThinMaterial))
                .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 0.5))
        }
    }

    /// Minimizes the tab bar as the user scrolls down. No-op before iOS 26,
    /// where the behaviour simply doesn't exist.
    @ViewBuilder
    func xomTabBarMinimizeOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
