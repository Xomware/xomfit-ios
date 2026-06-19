import SwiftUI

/// Row wrapper that reveals a trailing-edge Delete action when the user swipes
/// left, mimicking the iOS-native `List` swipe-actions UX inside views that
/// are rendered as `ScrollView` + `LazyVStack` (e.g. the active workout list,
/// the exercise jumper sheet, the template builder).
///
/// Native `.swipeActions(edge:)` only works inside a `List`, so we provide a
/// drag-gesture-driven approximation. The row content slides leading while the
/// Delete pill rides into view from the trailing edge. Past a threshold or on
/// flick, the row commits the delete via the `onDelete` callback.
///
/// Accessibility: exposes a VoiceOver `accessibilityAction(named: "Delete")`
/// using the supplied `accessibilityLabel` so screen-reader users can delete
/// without performing the swipe gesture.
struct SwipeToDeleteRow<Content: View>: View {
    let accessibilityActionName: String
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    /// Live drag translation; negative when swiping left. Capped at the action width.
    @State private var dragOffset: CGFloat = 0
    /// Final resting offset after a release. Either 0 (closed) or -actionWidth (open).
    @State private var committedOffset: CGFloat = 0
    /// Set true once the user releases past the snap threshold so the delete pill
    /// renders its label without the trailing icon flicker during drag.
    @State private var isOpen = false
    /// Tracks whether we've determined this gesture is horizontal (swipe) vs vertical (scroll).
    /// Once locked, we commit to that direction for the rest of the gesture.
    @State private var gestureAxis: GestureAxis = .undetermined

    private enum GestureAxis {
        case undetermined, horizontal, vertical
    }

    /// Width of the trailing Delete pill. Wide enough to comfortably show the
    /// "Delete" label + trash glyph and meet the 44pt minimum touch target.
    private let actionWidth: CGFloat = 88
    /// How far the user must drag past the action width before a release auto-commits
    /// the delete. Prevents accidental deletes from a hair-trigger flick.
    private let autoDeleteThreshold: CGFloat = 140
    /// Below this absolute drag distance a release snaps closed; above it snaps open.
    private let snapOpenThreshold: CGFloat = 32
    /// Minimum distance before we lock in a gesture direction. Higher = easier scrolling.
    private let axisLockThreshold: CGFloat = 15

    var body: some View {
        ZStack(alignment: .trailing) {
            // Trailing destructive action — sits underneath, revealed by the slide.
            Button {
                Haptics.warning()
                commitDelete()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "trash.fill")
                        .font(.subheadline.weight(.bold))
                    Text("Delete")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(Theme.destructive)
            }
            .buttonStyle(.plain)
            .opacity(currentOffset < -1 ? 1 : 0)
            .accessibilityHidden(true)
            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))

            // Foreground row — slides left to expose the action.
            content()
                .background(Theme.background) // keep underlying delete hidden when closed
                .offset(x: currentOffset)
                // `.simultaneousGesture` (not `.gesture`) so the parent
                // ScrollView's pan recognizer runs in parallel. A plain
                // `.gesture` claims the touch exclusively and starves the
                // ScrollView, making the whole list unscrollable. The
                // axis-lock logic below still gates the swipe reveal: a
                // vertical drag never flips `gestureAxis` to `.horizontal`,
                // so `dragOffset` stays 0 and only the ScrollView reacts.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)

                            // Lock axis once we've moved past the threshold
                            if gestureAxis == .undetermined {
                                let total = dx + dy
                                if total > axisLockThreshold {
                                    // Require clearly horizontal (2:1 ratio) to claim as swipe
                                    gestureAxis = (dx > dy * 2) ? .horizontal : .vertical
                                }
                            }

                            // Only handle horizontal swipes; let vertical pass through to ScrollView
                            guard gestureAxis == .horizontal else { return }

                            let raw = committedOffset + value.translation.width
                            // Clamp: never positive (no rightward reveal), and don't
                            // stretch past 1.5x the action width.
                            dragOffset = min(0, max(raw, -actionWidth * 1.5))
                        }
                        .onEnded { value in
                            let wasHorizontal = gestureAxis == .horizontal
                            gestureAxis = .undetermined // Reset for next gesture

                            guard wasHorizontal else {
                                snapClosed()
                                return
                            }

                            let final = committedOffset + value.translation.width
                            if final < -autoDeleteThreshold {
                                // Past the auto-commit line — fire the destructive callback.
                                Haptics.warning()
                                commitDelete()
                            } else if final < -snapOpenThreshold {
                                snapOpen()
                            } else {
                                snapClosed()
                            }
                        }
                )
        }
        .accessibilityAction(named: Text("Delete")) {
            commitDelete()
        }
        .accessibilityHint("Swipe left to delete, or use the Delete rotor action")
    }

    private var currentOffset: CGFloat {
        // While actively dragging we use the running offset; otherwise the committed one.
        dragOffset < 0 ? dragOffset : committedOffset
    }

    private func snapOpen() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            committedOffset = -actionWidth
            dragOffset = 0
            isOpen = true
        }
    }

    private func snapClosed() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            committedOffset = 0
            dragOffset = 0
            isOpen = false
        }
    }

    private func commitDelete() {
        // Slide fully off-screen-trailing before firing the model mutation so the
        // row visually exits instead of just popping. The callback ultimately
        // removes this view from its parent's ForEach, which unmounts us.
        withAnimation(.easeIn(duration: 0.18)) {
            committedOffset = -actionWidth * 4
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDelete()
        }
    }
}

extension View {
    /// Apply swipe-to-delete behavior to a row inside a `LazyVStack` (or any
    /// non-`List` container). Mirrors the look + feel of `.swipeActions`.
    ///
    /// - Parameters:
    ///   - accessibilityActionName: User-facing name for the destructive action
    ///     exposed to VoiceOver (e.g. "Delete Bench Press from workout").
    ///   - onDelete: Callback fired when the user commits the swipe — either by
    ///     tapping the revealed Delete pill or flicking past the auto-delete threshold.
    func swipeToDelete(
        accessibilityActionName: String,
        perform onDelete: @escaping () -> Void
    ) -> some View {
        SwipeToDeleteRow(
            accessibilityActionName: accessibilityActionName,
            onDelete: onDelete
        ) { self }
    }
}
