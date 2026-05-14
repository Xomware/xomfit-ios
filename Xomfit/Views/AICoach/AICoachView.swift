import SwiftUI

/// Chat interface for the AI Coach. Hits Anthropic's Messages API directly
/// via `AICoachService` and seeds the system prompt with the user's
/// `UserFitnessProfile` when available.
///
/// Scope:
/// - Streaming replies (token-by-token) via SSE.
/// - Conversation persisted to UserDefaults (last 50 messages).
/// - `build_workout` tool: when the model calls it, an inline Save / Start
///   card is rendered under the assistant message.
struct AICoachView: View {
    @State private var viewModel = AICoachViewModel()
    @State private var savedToast: Toast?
    @State private var showClearConfirm = false
    @FocusState private var inputFocused: Bool

    /// Workout session is optional — the chat is also reachable from Settings,
    /// where it's not in scope. When absent, the "Start Now" card button is hidden.
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession: WorkoutLoggerViewModel?
    @Environment(AuthService.self) private var authService: AuthService?

    /// Optional override key persisted by the user in Settings.
    /// Stored in `@AppStorage` for v1 — TODO Keychain.
    @AppStorage("aiCoach.anthropicAPIKey") private var apiKeyOverride: String = ""

    /// User-selected Anthropic model. Persisted in Settings → AI Coach (#371).
    @AppStorage("aiCoach.model") private var modelRawValue: String = AICoachModel.sonnet45.rawValue

    /// Whether to show the past-conversations stub sheet (#371).
    @State private var showHistoryStub = false

    /// Resolved model from the persisted raw value, with fallback to Sonnet.
    private var selectedModel: AICoachModel {
        AICoachModel.resolve(rawValue: modelRawValue)
    }

    /// Current user id for the prompt-priming workout context. Lowercased
    /// UUID string to match the caching key.
    private var userId: String? {
        guard let raw = authService?.currentUser?.id.uuidString.lowercased(),
              !raw.isEmpty
        else { return nil }
        return raw
    }

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

                if let cost = viewModel.costMeterText {
                    costFooter(cost)
                }

                composer
            }
        }
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        Haptics.light()
                        showHistoryStub = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityLabel("Past conversations")

                    if !viewModel.isEmpty {
                        Button(role: .destructive) {
                            Haptics.light()
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .accessibilityLabel("Clear conversation")
                    }
                }
            }
        }
        .sheet(isPresented: $showHistoryStub) {
            pastConversationsStub
        }
        .confirmationDialog(
            "Clear conversation?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                Haptics.medium()
                viewModel.clearConversation()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the saved chat history on this device.")
        }
        .toast($savedToast)
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

                    // Horizontally scrollable chip rail (#371).
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(viewModel.suggestionChips, id: \.self) { chip in
                                suggestionChip(chip)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            Haptics.light()
            Task {
                await viewModel.sendSuggestion(
                    text,
                    apiKeyOverride: apiKeyOverride,
                    model: selectedModel,
                    userId: userId
                )
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "sparkle")
                    .foregroundStyle(Theme.accent)
                Text(text)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(Theme.surface)
                    .overlay(
                        Capsule()
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
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            AICoachMessageBubble(message: message)
                            if message.role == .assistant, let payload = message.workoutPayload {
                                WorkoutBuildCard(
                                    payload: payload,
                                    canStart: workoutSession != nil && authService?.currentUser != nil,
                                    onSave: { handleSave(payload: payload) },
                                    onStart: { handleStart(payload: payload) }
                                )
                                .padding(.leading, 40) // align with bubble (past avatar)
                            }
                            // Regenerate action only on the latest assistant
                            // bubble when the convo is at rest (#371).
                            if message.role == .assistant,
                               message.id == viewModel.lastAssistantMessageId,
                               viewModel.canRegenerateLast {
                                regenerateButton
                                    .padding(.leading, 40)
                            }
                        }
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

    private var regenerateButton: some View {
        Button {
            Haptics.light()
            Task {
                await viewModel.regenerateLast(
                    apiKeyOverride: apiKeyOverride,
                    model: selectedModel,
                    userId: userId
                )
            }
        } label: {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: "arrow.clockwise")
                Text("Regenerate")
            }
            .font(Theme.fontCaption.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .frame(minHeight: 32)
            .background(
                Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSending)
        .accessibilityLabel("Regenerate last reply")
        .accessibilityHint("Discards the last reply and asks again")
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.xomChill) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - Tool actions

    private func handleSave(payload: WorkoutBuildPayload) {
        Haptics.success()
        if let template = viewModel.saveTemplate(from: payload) {
            savedToast = Toast(style: .success, message: "Saved \"\(template.name)\" to templates")
        }
    }

    private func handleStart(payload: WorkoutBuildPayload) {
        guard
            let workoutSession,
            let userId = authService?.currentUser?.id.uuidString.lowercased(),
            !userId.isEmpty
        else { return }
        Haptics.success()
        viewModel.startWorkout(from: payload, on: workoutSession, userId: userId)
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
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
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
        Task {
            await viewModel.send(
                apiKeyOverride: apiKeyOverride,
                model: selectedModel,
                userId: userId
            )
        }
    }

    // MARK: - Cost meter footer (#371)

    private func costFooter(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    // MARK: - Past conversations stub (#371)

    private var pastConversationsStub: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.accent)
                    Text("Multi-thread chats coming soon")
                        .font(Theme.fontBody.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("For now your AI Coach is one rolling conversation. We'll add per-topic threads in a future update.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Past Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showHistoryStub = false }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
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
            .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
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

// MARK: - Workout build card

/// Inline card under an assistant message that called the `build_workout`
/// tool. Lists the exercises and offers Save / Start actions.
private struct WorkoutBuildCard: View {
    let payload: WorkoutBuildPayload
    let canStart: Bool
    let onSave: () -> Void
    let onStart: () -> Void

    /// Resolved exercises from the catalog, in payload order. Items whose
    /// `exerciseId` isn't in `ExerciseDatabase.all` are dropped — same skip
    /// behaviour as `AICoachViewModel.buildTemplate`.
    private var resolved: [(item: WorkoutBuildPayload.Exercise, exercise: Exercise)] {
        payload.exercises.compactMap { item in
            guard let ex = ExerciseDatabase.byId[item.exerciseId] else {
                return nil
            }
            return (item, ex)
        }
    }

    /// Number of exercises the model returned that we couldn't map. Surfaced
    /// in the footer so users know why the saved template might be shorter.
    private var skippedCount: Int { payload.exercises.count - resolved.count }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header

            Divider().background(Theme.hairline)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(resolved.enumerated()), id: \.offset) { _, row in
                    exerciseRow(item: row.item, exercise: row.exercise)
                }
                if resolved.isEmpty {
                    Text("No matching exercises in your catalog yet.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                if skippedCount > 0 && !resolved.isEmpty {
                    Text("\(skippedCount) exercise\(skippedCount == 1 ? "" : "s") skipped (unknown id)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    onSave()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.fill")
                        Text("Save as Template")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.surfaceElevated)
                .foregroundStyle(Theme.textPrimary)
                .disabled(resolved.isEmpty)

                Button {
                    onStart()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Start Now")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(.black)
                .disabled(resolved.isEmpty || !canStart)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(Theme.accent.opacity(0.4), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested workout: \(payload.name), \(resolved.count) exercises")
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(payload.name)
                    .font(Theme.fontBody.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let mins = payload.estimatedDurationMinutes, mins > 0 {
                    Text("~\(mins) min · \(resolved.count) exercise\(resolved.count == 1 ? "" : "s")")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("\(resolved.count) exercise\(resolved.count == 1 ? "" : "s")")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func exerciseRow(item: WorkoutBuildPayload.Exercise, exercise: Exercise) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text(exercise.name)
                .font(Theme.fontCaption.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(targetLine(item: item))
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
        }
    }

    private func targetLine(item: WorkoutBuildPayload.Exercise) -> String {
        var parts = ["\(item.sets)x\(item.targetReps)"]
        if let w = item.targetWeight, w > 0 {
            let weightStr: String = (w.rounded() == w) ? String(Int(w)) : String(format: "%.1f", w)
            parts.append("@ \(weightStr) lb")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Typing dots

private struct TypingDots: View {
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Spacing.tight) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.textSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion ? 0.7 : (phase == index ? 1 : 0.3))
            }
        }
        .onAppear {
            // Skip the cycling timer entirely under Reduce Motion — the static
            // dots + the "Coach is typing" label are enough signal.
            guard !reduceMotion else { return }
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
