import Foundation
import Observation

/// In-process channel for the training nudge → generator hop.
///
/// `MainTabView` owns navigation `destination`; `WorkoutView` owns the generator
/// sheet (`showGenerator` + the generator view model). Rather than round-trip a
/// `xomfit://` URL for an in-app tap, the nudge sets `pending` and flips the
/// destination to `.workout`; `WorkoutView` observes `pending`, opens the
/// generator pre-seeded with that muscle, then clears it.
///
/// Injected into the environment from `XomFitApp` so both views share one holder.
@MainActor
@Observable
final class GeneratorPreseed {
    /// The muscle the nudge wants the generator to open pre-seeded with.
    /// Set by the nudge toast tap; consumed and cleared by `WorkoutView`.
    var pending: MuscleGroup?

    init(pending: MuscleGroup? = nil) {
        self.pending = pending
    }
}
