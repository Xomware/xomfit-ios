import SwiftUI
import ConnectIQ

/// Pair a Garmin watch, see whether it's actually reachable, and test it.
///
/// This screen is why the Garmin integration never worked. The transport layer
/// — `GarminSyncService`, the workout mirroring, the Done Set handling — all
/// shipped, but `beginDeviceSelection()` had no caller anywhere in the app. With
/// no paired device, `isWatchReady` stayed false and every send and open request
/// returned at its first `guard`. Silently, with no error and nothing on screen
/// to suggest a step was missing.
///
/// So the screen leads with state rather than a button. Four things have to be
/// true before a workout reaches the wrist — Garmin Connect installed, a watch
/// paired, that watch connected, and the XomFit app installed on it — and any
/// one of them failing looks identical from the lifter's side: nothing happens.
/// Each gets its own row and its own fix.
struct GarminDeviceView: View {
    @State private var garmin = GarminSyncService.shared
    @State private var testResult: String?

    var body: some View {
        List {
            statusSection
            outcomeSection
            actionsSection
            if garmin.primaryDevice != nil {
                testSection
                forgetSection
            }
            helpSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Garmin Watch")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { garmin.refreshStatuses() }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            if let device = garmin.primaryDevice {
                statusRow(
                    icon: "applewatch",
                    title: device.friendlyName ?? device.modelName ?? "Garmin watch",
                    detail: statusText,
                    tint: statusTint
                )
                statusRow(
                    icon: appInstalledIcon,
                    title: "XomFit on watch",
                    detail: appInstalledText,
                    tint: appInstalledTint
                )
            } else {
                statusRow(
                    icon: "exclamationmark.circle.fill",
                    title: "No watch paired",
                    detail: "Workouts aren't being sent anywhere yet.",
                    tint: Theme.textTertiary
                )
            }
        } header: {
            XomMetricLabel("Status")
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private func statusRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .frame(width: Theme.Spacing.lg)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Garmin's status enum collapses several very different problems into
    /// "can't talk to it", so each one gets wording that names the actual fix.
    private var statusText: String {
        switch garmin.primaryStatus {
        case .connected:
            return garmin.isWatchReady
                ? "Connected and ready."
                // Connected but characteristics still being discovered. Real,
                // brief, and worth showing rather than claiming readiness.
                : "Connecting…"
        case .notConnected:
            return "Not connected. Open Garmin Connect and check the watch is in range."
        case .notFound:
            return "Not found. The watch may have been removed from Garmin Connect."
        case .bluetoothNotReady:
            return "Bluetooth is off or resetting."
        case .invalidDevice:
            return "Not registered with the Connect IQ SDK."
        case .none:
            return "Status unknown."
        @unknown default:
            return "Status unknown."
        }
    }

    private var statusTint: Color {
        garmin.isWatchReady ? Theme.accent : Theme.textTertiary
    }

    private var appInstalledIcon: String {
        switch garmin.isAppInstalled {
        case true: return "checkmark.circle.fill"
        case false: return "arrow.down.circle.fill"
        case nil: return "questionmark.circle"
        default: return "questionmark.circle"
        }
    }

    private var appInstalledText: String {
        switch garmin.isAppInstalled {
        case true: return "Installed."
        case false: return "Not installed — the watch can't receive workouts without it."
        case nil: return "Unknown until the watch connects."
        default: return "Unknown."
        }
    }

    private var appInstalledTint: Color {
        garmin.isAppInstalled == true ? Theme.accent : Theme.textTertiary
    }

    // MARK: - Actions

    /// What the last pairing attempt actually did.
    ///
    /// Every failure in this chain has looked the same from the outside —
    /// Garmin Connect opens and nothing comes back — whether the cause was a
    /// missing caller, a misspelled selector, a swallowed callback URL, or GCM
    /// not being installed. This turns "nothing happened" into something a
    /// lifter can act on.
    @ViewBuilder
    private var outcomeSection: some View {
        switch garmin.pairingOutcome {
        case .idle:
            EmptyView()

        case .awaitingGarminConnect:
            outcomeRow(
                icon: "hourglass",
                tint: Theme.alert,
                title: "Waiting on Garmin Connect",
                detail: "Garmin Connect was opened but hasn't sent a watch back yet. If you already picked one and returned here, tap Pair again — and if Garmin Connect opened to its home screen rather than a device list, it may not be signed in."
            )

        case .garminConnectMissing:
            outcomeRow(
                icon: "exclamationmark.triangle.fill",
                tint: Theme.destructive,
                title: "Garmin Connect isn't installed",
                detail: "XomFit talks to your watch directly, but Garmin Connect is what finds it in the first place."
            )

        case .returnedEmpty:
            outcomeRow(
                icon: "questionmark.circle",
                tint: Theme.alert,
                title: "No watch was shared",
                detail: "Garmin Connect came back without a device — usually that means the selection was cancelled, or no Connect IQ watch is paired to it."
            )

        case .paired(let count):
            outcomeRow(
                icon: "checkmark.circle.fill",
                tint: Theme.accent,
                title: count == 1 ? "Watch paired" : "\(count) watches paired",
                detail: "XomFit can talk to your watch. Start a workout and it should mirror."
            )
        }
    }

    private func outcomeRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(title)
                    .font(Theme.fontFootnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .listRowBackground(Theme.surface)
    }

    private var actionsSection: some View {
        Section {
            Button {
                // Leaves XomFit for Garmin Connect and returns through the
                // `xomfit-garmin` URL scheme.
                garmin.beginDeviceSelection()
            } label: {
                actionLabel(
                    icon: "antenna.radiowaves.left.and.right",
                    title: garmin.primaryDevice == nil ? "Pair a Watch" : "Change Watch"
                )
            }

            if garmin.isAppInstalled == false {
                Button {
                    garmin.showStoreListing()
                } label: {
                    actionLabel(icon: "arrow.down.app", title: "Install XomFit on Watch")
                }
            }

            Button {
                garmin.refreshStatuses()
            } label: {
                actionLabel(icon: "arrow.clockwise", title: "Refresh Status")
            }
        } header: {
            XomMetricLabel("Setup")
        } footer: {
            Text("Pairing opens Garmin Connect so you can choose which watch XomFit is allowed to talk to. Garmin Connect has to stay installed — it's how the phone finds the watch.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private func actionLabel(icon: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .frame(width: Theme.Spacing.lg)
                .foregroundStyle(Theme.accent)
            Text(title)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Test

    private var testSection: some View {
        Section {
            Button {
                testOnWatch()
            } label: {
                actionLabel(icon: "bolt.horizontal", title: "Open XomFit on Watch")
            }
            .disabled(!garmin.isWatchReady)

            if let testResult {
                Text(testResult)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        } header: {
            XomMetricLabel("Test")
        } footer: {
            Text("Garmin shows a prompt on the watch rather than launching apps silently — that's the platform's rule, not a XomFit limitation. Accept it on the watch and the workout screen appears.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private func testOnWatch() {
        testResult = "Sent — look at your watch."
        garmin.requestOpenOnWatch()
    }

    // MARK: - Forget

    private var forgetSection: some View {
        Section {
            Button(role: .destructive) {
                garmin.forgetDevices()
                testResult = nil
            } label: {
                Text("Forget Watch")
            }
        }
        .listRowBackground(Theme.surface)
    }

    // MARK: - Help

    private var helpSection: some View {
        Section {
            Text("Your watch needs the XomFit Connect IQ app installed from the Connect IQ store. Once paired, starting a workout on your phone asks the watch to open XomFit, and your current lift, set and rest timer mirror to the wrist.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
        } header: {
            XomMetricLabel("How it works")
        }
        .listRowBackground(Theme.surface)
    }
}
