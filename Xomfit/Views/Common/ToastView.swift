import SwiftUI

// MARK: - Toast Model

struct Toast: Equatable {
    enum Style {
        case error
        case success
        case info
    }

    let style: Style
    let message: String
    var duration: Double = 3.0
}

// MARK: - Toast View

struct ToastView: View {
    let toast: Toast

    var icon: String {
        switch toast.style {
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch toast.style {
        case .error: return Theme.destructive
        case .success: return Theme.accent
        case .info: return .blue
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm + Theme.Spacing.tight) {
            Image(systemName: icon)
                .font(Theme.fontTitle3)
                .foregroundStyle(iconColor)

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md - Theme.Spacing.tighter)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.5))
                )
        )
        .padding(.horizontal, Theme.Spacing.md)
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    /// Optional action fired when the toast is tapped (e.g. the training nudge
    /// opening the generator). Defaults to a no-op so existing badge toasts keep
    /// their dismiss-only behavior. The toast still dismisses on tap regardless.
    var onTap: () -> Void = {}

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastView(toast: toast)
                        .padding(.top, Theme.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(toast.duration))
                                withAnimation(.xomConfident) {
                                    self.toast = nil
                                }
                            }
                        }
                        .onTapGesture {
                            onTap()
                            withAnimation(.xomConfident) {
                                self.toast = nil
                            }
                        }
                        .zIndex(100)
                }
            }
            .animation(.xomConfident, value: toast)
    }
}

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }

    /// Toast variant with a tap action. The action runs before the toast
    /// dismisses; used by the training nudge to open the pre-seeded generator.
    func toast(_ toast: Binding<Toast?>, onTap: @escaping () -> Void) -> some View {
        modifier(ToastModifier(toast: toast, onTap: onTap))
    }
}
