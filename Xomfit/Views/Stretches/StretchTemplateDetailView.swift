import SwiftUI

/// Detail view for a curated `StretchTemplate` (#388, edit mode added in #398).
///
/// Shows the template's stretches in order with a "Start Stretching" CTA that
/// presents the guided runner as a full-screen cover. The user can flip into
/// edit mode (pencil button) to reorder + delete stretches before starting;
/// edits affect only the current session and never mutate
/// `StretchTemplate.curated`. Tapping a row out of edit mode opens the
/// existing `StretchDetailSheet`.
struct StretchTemplateDetailView: View {
    let template: StretchTemplate

    @State private var stretchForDetail: Stretch?
    @State private var showRunner = false
    /// Per-session, editable copy of the template's stretches. Initialized
    /// from `template.stretches` and reset back to it via the "Reset" button.
    @State private var sessionStretches: [Stretch] = []
    /// Drives the swipe / drag affordances on the in-sequence list.
    @State private var editMode: EditMode = .inactive

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        headerCard
                        listSection
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, 140)
                }

                bottomBar
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                editToolbarContent
            }
        }
        .environment(\.editMode, $editMode)
        .onAppear {
            // Seed the editable copy lazily so we don't trample mid-session
            // edits when the view re-renders from a state change.
            if sessionStretches.isEmpty {
                sessionStretches = template.stretches
            }
            #if DEBUG
            // Agent screenshot helper: when XOMFIT_STRETCH_EDIT_MODE=1 is set,
            // auto-flip into edit mode shortly after first render so the
            // verification script can capture the drag/swipe affordances
            // without scripted taps.
            if ProcessInfo.processInfo.environment["XOMFIT_STRETCH_EDIT_MODE"] == "1" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editMode = .active
                    }
                }
            }
            #endif
        }
        .sheet(item: $stretchForDetail) { stretch in
            StretchDetailSheet(stretch: stretch)
        }
        .fullScreenCover(isPresented: $showRunner) {
            GuidedStretchRunnerView(
                stretches: sessionStretches,
                templateName: template.name
            )
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: template.iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accentMuted)
                    .clipShape(.rect(cornerRadius: Theme.Radius.md))

                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    Text(template.name)
                        .font(Theme.fontTitle2)
                        .foregroundStyle(Theme.textPrimary)
                    Text(template.category.displayName)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            Text(template.description)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.md) {
                metric(icon: "clock.fill", label: totalDurationLabel)
                metric(icon: "list.bullet", label: "\(sessionStretches.count) stretches")
            }
            .accessibilityElement(children: .combine)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func metric(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.surfaceElevated)
        .clipShape(.rect(cornerRadius: Theme.Radius.xs))
    }

    private var totalDurationLabel: String {
        let secs = sessionStretches.reduce(0) { $0 + $1.durationSeconds }
        if secs < 60 { return "\(secs) sec" }
        let mins = (secs + 30) / 60
        return "\(mins) min"
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var editToolbarContent: some View {
        if editMode == .active {
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    Haptics.light()
                    sessionStretches = template.stretches
                } label: {
                    Text("Reset")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.alert)
                }
                .disabled(sessionStretches.map(\.id) == template.stretchIds)
                .accessibilityLabel("Reset stretches to template order")

                Button {
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editMode = .inactive
                    }
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Finish editing stretches")
            }
        } else {
            Button {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    editMode = .active
                }
            } label: {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .disabled(sessionStretches.isEmpty)
            .accessibilityLabel("Edit stretches")
            .accessibilityHint("Reorder or remove stretches before starting")
        }
    }

    // MARK: - Stretch List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                XomMetricLabel("In This Sequence")
                Spacer()
                if editMode == .active {
                    Text("Drag to reorder · swipe to remove")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            if editMode == .active {
                editableList
            } else {
                staticList
            }
        }
    }

    /// Read-only list used out of edit mode. Each row stays tappable so the
    /// user can pop the detail sheet without entering edit mode.
    private var staticList: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(sessionStretches.enumerated()), id: \.element.id) { index, stretch in
                Button {
                    Haptics.selection()
                    stretchForDetail = stretch
                } label: {
                    row(index: index, stretch: stretch)
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("Stretch \(index + 1): \(stretch.name), \(stretch.durationSeconds) seconds")
                .accessibilityHint("Opens stretch details")
            }
        }
    }

    /// Edit-mode list. Uses SwiftUI `List` so we get drag handles + swipe to
    /// delete for free. The fixed-height frame caps the visual size to match
    /// the static list — it grows as needed because we set `.scrollDisabled`.
    private var editableList: some View {
        List {
            ForEach(Array(sessionStretches.enumerated()), id: \.element.id) { index, stretch in
                row(index: index, stretch: stretch)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .accessibilityLabel("Stretch \(index + 1): \(stretch.name), \(stretch.durationSeconds) seconds")
            }
            .onMove(perform: moveStretch)
            .onDelete(perform: deleteStretch)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .frame(minHeight: CGFloat(sessionStretches.count) * 84)
    }

    private func moveStretch(from source: IndexSet, to destination: Int) {
        Haptics.selection()
        sessionStretches.move(fromOffsets: source, toOffset: destination)
    }

    private func deleteStretch(at offsets: IndexSet) {
        Haptics.light()
        sessionStretches.remove(atOffsets: offsets)
    }

    private func row(index: Int, stretch: Stretch) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: Theme.Radius.xs))

            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(stretch.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(stretch.description)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Text("\(stretch.durationSeconds)s")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .contentShape(Rectangle())
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.medium()
                // Leave edit mode before starting so the runner doesn't render
                // behind a stale edit affordance.
                if editMode == .active { editMode = .inactive }
                showRunner = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Start Stretching")
                }
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(sessionStretches.isEmpty)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
            .accessibilityLabel("Start guided stretching sequence with \(sessionStretches.count) stretches")
        }
        .background(
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        StretchTemplateDetailView(template: StretchTemplate.curated[0])
    }
    .preferredColorScheme(.dark)
}
#endif
