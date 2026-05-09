import SwiftUI

/// Chat interface for the AI Coach. Hits Anthropic's Messages API directly
/// via `AICoachService` and seeds the system prompt with the user's
/// `UserFitnessProfile` when available.
///
/// v1 scope:
/// - Plain-text replies (no streaming yet — TODO)
/// - In-memory chat history per app launch (no persistence)
/// - 3 suggestion chips when empty
struct AICoachView: View {
    @State private var viewModel = AICoachViewModel()
    @FocusState private var inputFocused: Bool

    /// Optional override key persisted by the user in Settings.
    /// Stored in `@AppStorage` for v1 — TODO Keychain.
    @AppStorage("aiCoach.anthropicAPIKey") private var apiKeyOverride: String = ""

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.isEmpty {
                    emptyState
                } else {
                    transcript
                }

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                composer
            }
        }
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.isEmpty {
                    Button {
                        Haptics.light()
                        viewModel.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityLabel("Start new conversation")
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                XomEmptyState(
                    symbolStack: ["sparkles", "dumbbell.fill"],
                    title: "Your AI Lifting Coach",
                    subtitle: "Ask for a workout, a weekly plan, or how to push past a plateau.",
                    floatingLoop: true
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    XomMetricLabel("Try Asking")
                        .padding(.horizontal, Theme.Spacing.md)

                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.suggestionChips, id: \.self) { chip in
                            suggestionChip(chip)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            Haptics.light()
            Task { await viewModel.sendSuggestion(text, apiKeyOverride: apiKeyOverride) }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "sparkle")
                    .foregroundStyle(Theme.accent)
                Text(text)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .strokeBorder(Theme.hairline, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PressableCardStyle())
        .disabled(viewModel.isSending)
        .accessibilityLabel(text)
        .accessibilityHint("Sends this prompt to your AI Coach")
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.messages) { message in
                        AICoachMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.xomChill) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.alert)
            Text(message)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.alert.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(Theme.alert.opacity(0.4), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            TextField("Ask your coach…", text: Bindable(viewModel).draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .lineLimit(1...5)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                                .strokeBorder(Theme.hairline, lineWidth: 0.5)
                        )
                )
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { triggerSend() }
                .disabled(viewModel.isSending)
                .accessibilityLabel("Message")

            Button {
                triggerSend()
            } label: {
                Image(systemName: viewModel.isSending ? "stop.fill" : "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(viewModel.canSend ? Theme.accent : Theme.surfaceElevated)
                    )
            }
            .disabled(!viewModel.canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Theme.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 0.5)
                }
        )
    }

    private func triggerSend() {
        guard viewModel.canSend else { return }
        Haptics.light()
        Task { await viewModel.send(apiKeyOverride: apiKeyOverride) }
    }
}

// MARK: - Message bubble

private struct AICoachMessageBubble: View {
    let message: AICoachMessage

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if message.role == .user {
                Spacer(minLength: 40)
                bubble
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                assistantAvatar
                bubble
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 40)
            }
        }
    }

    private var assistantAvatar: some View {
        Image(systemName: "sparkles")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.accent)
            .frame(width: 32, height: 32)
            .background(Theme.accent.opacity(0.18))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bubble: some View {
        if message.isStreaming && message.text.isEmpty {
            TypingDots()
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.surface)
                )
        } else {
            Text(message.text)
                .font(Theme.fontBody)
                .foregroundStyle(message.role == .user ? .black : Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(message.role == .user ? Theme.accent : Theme.surface)
                )
                .textSelection(.enabled)
                .accessibilityLabel(
                    "\(message.role == .user ? "You" : "Coach") said: \(message.text)"
                )
        }
    }
}

// MARK: - Typing dots

private struct TypingDots: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.textSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == index ? 1 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { timer in
                Task { @MainActor in
                    phase = (phase + 1) % 3
                }
                _ = timer
            }
        }
        .accessibilityLabel("Coach is typing")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AICoachView()
    }
    .preferredColorScheme(.dark)
}
