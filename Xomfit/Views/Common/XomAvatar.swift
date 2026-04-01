import SwiftUI

struct XomAvatar: View {
    let name: String
    let size: CGFloat
    let imageURL: URL?
    let showBorder: Bool
    let isOnline: Bool

    init(
        name: String,
        size: CGFloat = 40,
        imageURL: URL? = nil,
        showBorder: Bool = false,
        isOnline: Bool = false
    ) {
        self.name = name
        self.size = size
        self.imageURL = imageURL
        self.showBorder = showBorder
        self.isOnline = isOnline
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        initialsView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }

            if isOnline {
                Circle()
                    .fill(Theme.energy)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle().stroke(Theme.background, lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
        }
        .overlay {
            if showBorder {
                Circle()
                    .strokeBorder(Theme.accent, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(Theme.surfaceSecondary)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            )
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
