import SwiftUI

/// Cardio history — logged sessions plus anything imported from Apple Health.
struct CardioListView: View {
    let userId: String

    @State private var service = CardioService.shared
    @State private var showLogSheet = false
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var hasLoaded = false

    /// Opt-in for automatic Health imports. Surfaced here as well as in Settings
    /// because this is the screen someone lands on when their watch data is
    /// missing — a toggle buried three taps away in Settings does not answer
    /// "why isn't my Garmin run here".
    @AppStorage(CardioService.autoImportKey) private var autoImportCardio: Bool = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !hasLoaded {
                XomFitLoaderPulse()
            } else {
                VStack(spacing: 0) {
                    if showAutoImportPrompt {
                        autoImportPrompt
                    }
                    if service.sessions.isEmpty {
                        emptyState
                    } else {
                        sessionList
                    }
                }
            }
        }
        .navigationTitle("Cardio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showLogSheet = true
                    } label: {
                        Label("Log a session", systemImage: "plus.circle")
                    }
                    Button {
                        Task { await importFromHealth() }
                    } label: {
                        Label("Import from Health", systemImage: "heart.text.square")
                    }
                    .disabled(isImporting)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogCardioView(userId: userId) {
                Task { await load() }
            }
        }
        .task {
            guard !hasLoaded else { return }
            await load()
            await autoImportIfEnabled()
        }
        .refreshable { await load() }
        .overlay(alignment: .bottom) {
            if let importMessage {
                Text(importMessage)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.surfaceElevated, in: .capsule)
                    .padding(.bottom, Theme.Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.xomChill, value: importMessage)
    }

    // MARK: - List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(service.sessions) { session in
                    CardioSessionRow(session: session)
                }
            }
            .padding(Theme.Spacing.md)
        }
    }

    /// Shown until the lifter has made a choice. Health access is the single
    /// most common reason watch data is missing, and until now the only cure was
    /// a menu item most people never opened.
    private var showAutoImportPrompt: Bool {
        !autoImportCardio && HealthKitService.shared.isAvailable
    }

    private var autoImportPrompt: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "heart.text.square.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text("Bring in your watch data")
                    .font(Theme.fontFootnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Garmin, Apple Watch, Whoop and Polar all write to Apple Health.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button {
                Haptics.selection()
                Task { await enableAutoImport() }
            } label: {
                Text("Turn on")
                    .font(Theme.fontCaption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(isImporting)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.md))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var emptyState: some View {
        XomEmptyState(
            icon: "figure.run",
            title: "No cardio yet",
            subtitle: "Log a run, ride or row — or pull in what your watch already recorded.",
            ctaLabel: "Log a session",
            ctaAction: { showLogSheet = true }
        )
    }

    // MARK: - Actions

    private func load() async {
        await service.fetchSessions(userId: userId)
        hasLoaded = true
    }

    /// Anchored import — safe to run on every appearance because it only ever
    /// fetches what HealthKit has not handed us before.
    private func autoImportIfEnabled() async {
        guard autoImportCardio, HealthKitService.shared.isAvailable else { return }
        let count = await service.importNewFromHealth(userId: userId)
        guard count > 0 else { return }
        await service.fetchSessions(userId: userId)
        importMessage = "Imported \(count) session\(count == 1 ? "" : "s") from Health"
        try? await Task.sleep(for: .seconds(2.5))
        importMessage = nil
    }

    /// Turns auto-import on from the prompt, requesting Health access and
    /// running the first import straight away.
    private func enableAutoImport() async {
        autoImportCardio = true
        isImporting = true
        await HealthKitService.shared.requestAuthorization()
        let count = await service.importNewFromHealth(userId: userId)
        await service.fetchSessions(userId: userId)
        isImporting = false
        importMessage = count == 0
            ? "Nothing new in Health yet"
            : "Imported \(count) session\(count == 1 ? "" : "s") from Health"
        Haptics.light()
        try? await Task.sleep(for: .seconds(2.5))
        importMessage = nil
    }

    private func importFromHealth() async {
        isImporting = true
        // Authorization is requested on demand rather than at launch: asking for
        // Health access before the user has shown any interest in it is the
        // fastest way to get the sheet dismissed permanently.
        await HealthKitService.shared.requestAuthorization()
        let count = await service.importFromHealth(userId: userId)
        isImporting = false

        importMessage = count == 0
            ? "Nothing new to import"
            : "Imported \(count) session\(count == 1 ? "" : "s")"
        Haptics.light()

        try? await Task.sleep(for: .seconds(2.5))
        importMessage = nil
    }
}

// MARK: - Row

private struct CardioSessionRow: View {
    let session: CardioSession

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: session.modality.icon)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accentMuted, in: .rect(cornerRadius: Theme.Radius.sm))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(session.modality.displayName)
                        .font(Theme.fontBodyEmphasized)
                        .foregroundStyle(Theme.textPrimary)
                    // Imported sessions are labeled so the lifter can tell what
                    // came off their watch from what they typed in.
                    if session.isImported {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityLabel("Imported from Health")
                    }
                }

                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: Theme.Spacing.sm) {
                    metric(session.durationDisplay, icon: "clock")
                    if let distance = session.distanceMiles, distance > 0 {
                        metric(String(format: "%.2f mi", distance), icon: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    if let pace = session.paceDisplay {
                        metric(pace, icon: "speedometer")
                    }
                    if let hr = session.averageHeartRate, hr > 0 {
                        metric("\(Int(hr)) bpm", icon: "heart.fill")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.md))
        .accessibilityElement(children: .combine)
    }

    private func metric(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(Theme.fontSmall)
        }
        .foregroundStyle(Theme.textSecondary)
    }
}
