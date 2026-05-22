import Foundation
import SwiftUI

/// View model backing the inline soundtrack editor on `WorkoutDetailView`
/// (#411 follow-up).
///
/// Holds the per-workout featured track + share-all toggle in a small
/// `@Observable` shell so the detail view can flip stars and toggle sharing
/// without having to push a full edit-mode save through
/// `WorkoutDetailViewModel`. Each mutation pushes through
/// `WorkoutService.setFeaturedTrack` / `setShareFullSoundtrack`, which patch
/// the local cache + Supabase + matching feed item.
///
/// Designed for the read-only viewing surface — when the user is the workout
/// author this lets them flip their pick without re-opening edit mode. When
/// the user is not the author the view skips wiring this up entirely.
@MainActor
@Observable
final class WorkoutSoundtrackEditViewModel {
    /// Owning workout id — passed to `WorkoutService` on every mutation.
    let workoutId: String

    /// Currently-selected featured track id (matches `WorkoutTrack.id.uuidString`).
    /// Mirror of the underlying workout's value so the UI updates instantly
    /// while the Supabase write is in flight.
    var featuredTrackId: String?

    /// Share-all toggle mirror — same instant-feedback contract as above.
    var shareFullSoundtrack: Bool

    /// True while a write is in flight. Currently used for haptic / visual
    /// timing; views can disable controls if they want optimistic-only edits.
    var isSaving: Bool = false

    init(workout: Workout) {
        self.workoutId = workout.id
        self.featuredTrackId = workout.featuredTrackId
        self.shareFullSoundtrack = workout.shareFullSoundtrack
    }

    /// Toggle featured pick on the given track. Tapping the same row clears
    /// the pick so the user can fully unstick it.
    func toggleFeatured(trackId: String) {
        let next: String? = (featuredTrackId == trackId) ? nil : trackId
        featuredTrackId = next
        Task {
            isSaving = true
            await WorkoutService.shared.setFeaturedTrack(workoutId: workoutId, trackId: next)
            isSaving = false
        }
    }

    /// Toggle the share-full-soundtrack flag.
    func setShareFullSoundtrack(_ enabled: Bool) {
        shareFullSoundtrack = enabled
        Task {
            isSaving = true
            await WorkoutService.shared.setShareFullSoundtrack(workoutId: workoutId, enabled: enabled)
            isSaving = false
        }
    }
}
