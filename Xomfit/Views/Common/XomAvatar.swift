import SwiftUI

struct XomAvatar: View {
    let name: String
    let size: CGFloat
    let imageURL: URL?
    /// When non-nil, draws a ring in this color. Pass `Theme.accent` for a standard accent ring.
    let ringColor: Color?
    let isOnline: Bool

    init(
        name: String,
        size: CGFloat = 44,
        imageURL: URL? = nil,
        ringColor: Color? = nil,
        isOnline: Bool = false,
        // Legacy param — maps to ringColor for backwards compat
        showBorder: Bool = false
    ) {
        self.name = name
        self.size = size
        self.imageURL = imageURL
        self.ringColor = showBorder ? Theme.accent : ringColor
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
                    .fill(Theme.accent)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle().stroke(Theme.background, lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
        }
        .overlay {
            if let ringColor {
                Circle()
                    .strokeBorder(ringColor, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(Theme.surfaceElevated)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
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

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        XomAvatar(name: "Dom Giordano", size: 44)
        XomAvatar(name: "Dom Giordano", size: 96, ringColor: Theme.accent)
        XomAvatar(name: "Dom Giordano", size: 48, isOnline: true)
    }
    .padding()
    .background(Theme.background)
}
