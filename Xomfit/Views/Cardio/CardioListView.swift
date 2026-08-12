import SwiftUI

/// Cardio history — logged sessions plus anything imported from Apple Health.
struct CardioListView: View {
    let userId: String

    @State private var service = CardioService.shared
    @State private var showLogSheet = false
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !hasLoaded {
                XomFitLoaderPulse()
            } else if service.sessions.isEmpty {
                emptyState
            } else {
                sessionList
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
