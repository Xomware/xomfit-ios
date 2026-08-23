import Foundation
import ConnectIQ

/// Mirrors the active workout to a Garmin watch, and receives Done Set back.
///
/// The Garmin counterpart to `WatchSyncService`. Deliberately the same shape and
/// the same wire format — `WorkoutState.fromMessage` on the watch reads the keys
/// built here, so the app describes a workout once rather than once per wearable.
///
/// Unlike `WCSession`, this is not free. Garmin's iOS SDK talks to the watch
/// directly over Bluetooth at runtime, but Garmin Connect Mobile has to be
/// installed to *discover* devices in the first place, and the handoff back into
/// XomFit happens through a custom URL scheme.
@MainActor
@Observable
final class GarminSyncService: NSObject {
    static let shared = GarminSyncService()

    /// Devices Garmin Connect has handed us. Persisted across launches: the
    /// discovery round trip leaves the app, and making the lifter repeat it
    /// every launch would be worse than a stale entry.
    private(set) var knownDevices: [IQDevice] = []
    /// Whether any known device currently has XomFit installed and reachable.
    private(set) var isWatchReady = false

    /// Must match the `id` in the Garmin app's `manifest.xml`. If these drift,
    /// messages are sent into a mailbox nothing is listening to — silently, with
    /// no error, which is the worst possible failure mode.
    ///
    /// Stored in the manifest's own form: 32 hex characters, no dashes.
    static let watchAppId = "de3fa4b5876e472082d0c3a3cf918b79"

    /// The same id as a `UUID`, which is what `IQApp` actually takes.
    ///
    /// This conversion is load-bearing and easy to miss. A Connect IQ manifest
    /// id is undashed hex; `UUID(uuidString:)` rejects that outright and returns
    /// nil. Passing the raw string through would build an `IQApp` with no uuid
    /// and every message would vanish silently — no error, no delivery. It is a
    /// known trap on the Garmin forums, and a unit test caught it here.
    static var watchAppUUID: UUID? {
        let hex = watchAppId
        guard hex.count == 32,
              hex.range(of: "^[0-9a-fA-F]{32}$", options: .regularExpression) != nil
        else { return nil }

        let dashed = [
            hex.prefix(8),
            hex.dropFirst(8).prefix(4),
            hex.dropFirst(12).prefix(4),
            hex.dropFirst(16).prefix(4),
            hex.dropFirst(20)
        ].joined(separator: "-")
        return UUID(uuidString: dashed)
    }

    /// Registered in Info.plist as a URL type. Garmin Connect launches back into
    /// XomFit through this after device discovery.
    static let urlScheme = "xomfit-garmin"

    private var app: IQApp?
    private static let storedDevicesKey = "garmin.knownDevices"

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Initialises the SDK. Call once at launch.
    func start() {
        ConnectIQ.sharedInstance().initialize(
            withUrlScheme: Self.urlScheme,
            uiOverrideDelegate: nil
        )
        restoreDevices()
    }

    /// Sends the lifter to Garmin Connect to pick their watch.
    ///
    /// This leaves XomFit. Garmin Connect returns through the URL scheme, which
    /// is why `handleOpenURL` has to exist and be wired from the app delegate.
    func beginDeviceSelection() {
        ConnectIQ.sharedInstance().showDeviceSelection()
    }

    /// Consumes the return trip from Garmin Connect.
    ///
    /// Returns false when the URL was not ours, so the caller can pass it on
    /// rather than swallowing another feature's deep link.
    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme == Self.urlScheme else { return false }
        guard let devices = ConnectIQ.sharedInstance().parseDeviceSelectionResponse(from: url) as? [IQDevice] else {
            return false
        }
        knownDevices = devices
        persistDevices()
        registerForDeviceEvents()
        return true
    }

    // MARK: - Sending

    /// Mirrors the workout to every known device.
    ///
    /// Sent transient. A rest countdown updates every second, and Garmin's
    /// device-side mailbox is small — queueing every tick would flood it, and a
    /// countdown delivered late is worse than one dropped.
    func send(state: WatchWorkoutState) {
        guard let app, isWatchReady else { return }

        let message: [String: Any] = [
            "exercise": state.currentExercise,
            "set": state.setNumber,
            "totalSets": state.totalSets,
            "elapsed": state.elapsedSeconds,
            // The watch counts down in whole seconds and treats negatives as
            // overtime, matching how the phone already models rest.
            "rest": restSeconds(from: state) as Any,
            "paused": state.isPaused
        ].compactMapValues { $0 }

        ConnectIQ.sharedInstance().sendMessage(
            message,
            to: app,
            progress: nil,
            completion: { _ in }
        )
    }

    /// Converts the absolute rest end date the phone tracks into the countdown
    /// the watch shows. Nil when not resting.
    private func restSeconds(from state: WatchWorkoutState) -> Int? {
        guard state.isResting, let end = state.restEndDate else { return nil }
        return Int(end.timeIntervalSinceNow.rounded())
    }

    // MARK: - Devices

    private func registerForDeviceEvents() {
        for device in knownDevices {
            ConnectIQ.sharedInstance().register(forDeviceEvents: device, delegate: self)
        }
        if let device = knownDevices.first {
            app = IQApp(uuid: Self.watchAppUUID, store: nil, device: device)
            if let app {
                ConnectIQ.sharedInstance().register(forAppMessages: app, delegate: self)
            }
        }
    }

    /// Devices persist as archived data rather than ids: `IQDevice` carries the
    /// friendly name and model the UI needs, and re-deriving those would mean
    /// another trip through Garmin Connect.
    private func persistDevices() {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: knownDevices, requiringSecureCoding: false
        ) else { return }
        UserDefaults.standard.set(data, forKey: Self.storedDevicesKey)
    }

    private func restoreDevices() {
        guard let data = UserDefaults.standard.data(forKey: Self.storedDevicesKey),
              let devices = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [IQDevice]
        else { return }
        knownDevices = devices
        registerForDeviceEvents()
    }
}

// MARK: - Device status

extension GarminSyncService: IQDeviceEventDelegate {
    nonisolated func devicesChanged() {}

    nonisolated func device(_ device: IQDevice, statusChanged status: IQDeviceStatus) {
        Task { @MainActor in
            // Only `connected` means messages will actually arrive. Anything
            // else — not paired, Garmin Connect not running, Bluetooth off —
            // should stop us sending into the void.
            self.isWatchReady = (status == .connected)
        }
    }
}

// MARK: - Receiving

extension GarminSyncService: IQAppMessageDelegate {
    nonisolated func receivedMessage(_ message: Any, from app: IQApp) {
        guard let dict = message as? [String: Any],
              dict["type"] as? String == "doneSet"
        else { return }

        Task { @MainActor in
            // The same entry point the Apple Watch uses. It is idempotent per
            // set, which matters here too: Bluetooth can deliver twice.
            NotificationCenter.default.post(name: .garminDoneSetReceived, object: nil)
        }
    }
}

extension Notification.Name {
    /// Posted when the Garmin watch reports a completed set. Observed by the app
    /// shell, which owns the workout view model — the service deliberately does
    /// not reach into it.
    static let garminDoneSetReceived = Notification.Name("garminDoneSetReceived")
}
