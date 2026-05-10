import SwiftUI

/// Full-screen zoomable photo viewer with pinch-zoom and swipe-to-dismiss.
struct PhotoZoomView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragVelocityY: CGFloat = 0

    private let dismissThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            Color.black
                .opacity(dismissOpacity)
                .ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value.magnification
                                        scale = max(1, min(newScale, 6))
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale < 1.05 {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                scale = 1
                                                lastScale = 1
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        if scale <= 1.05 {
                                            // Swipe-to-dismiss only when not zoomed in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width * 0.3,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            dragVelocityY = value.velocity.height
                                        } else {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { value in
                                        if scale <= 1.05 && (abs(offset.height) > dismissThreshold || dragVelocityY > 800) {
                                            dismiss()
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                if scale <= 1.05 {
                                                    offset = .zero
                                                    lastOffset = .zero
                                                } else {
                                                    lastOffset = offset
                                                }
                                            }
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if scale > 1.5 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 3
                                    lastScale = 3
                                }
                            }
                        }
                case .failure:
                    Image(systemName: "photo")
                        .font(Theme.fontLargeTitle)
                        .foregroundStyle(Theme.textSecondary)
                default:
                    ProgressView().tint(Theme.textSecondary)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Theme.fontTitle2)
                            .foregroundStyle(Theme.textSecondary)
                            .background(Color.black.opacity(0.4).clipShape(Circle()))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .padding()
                    .accessibilityLabel("Close")
                    .accessibilityHint("Closes the full-screen photo viewer")
                }
                Spacer()
            }
            .opacity(scale <= 1.05 ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: scale)
        }
        .statusBar(hidden: true)
        .presentationBackground(.clear)
    }

    private var dismissOpacity: Double {
        let progress = min(abs(offset.height) / dismissThreshold, 1.0)
        return 1.0 - progress * 0.5
    }
}
