import SwiftUI

/// Reusable circular avatar.
/// Shows a remote image via AsyncImage when `avatarURL` is set,
/// otherwise falls back to an initial letter badge.
struct AvatarView: View {
    let avatarURL: String?
    let displayName: String
    var size: CGFloat = 80

    var body: some View {
        if let urlString = avatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure, .empty:
                    initialsBadge
                @unknown default:
                    initialsBadge
                }
            }
        } else {
            initialsBadge
        }
    }

    private var initialsBadge: some View {
        Circle()
            .fill(Theme.accent.opacity(0.18))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(Theme.accent)
            )
    }

    private var initial: String {
        String((displayName.first ?? "?").uppercased())
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(avatarURL: nil, displayName: "Dom G", size: 96)
        AvatarView(avatarURL: nil, displayName: "Mike J", size: 60)
        AvatarView(avatarURL: nil, displayName: "", size: 40)
    }
    .padding()
    .background(Theme.background)
}
