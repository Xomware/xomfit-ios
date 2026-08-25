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

    /// Connection status per device uuid, as last reported by the SDK.
    ///
    /// Per device rather than one global flag. The old single `isWatchReady`
    /// Bool was written by whichever device reported last, so a second paired
    /// watch going `.notConnected` would mark the connected one unreachable and
    /// silently stop every send.
    private(set) var deviceStatuses: [UUID: IQDeviceStatus] = [:]

    /// Device uuids whose characteristics the SDK has finished discovering.
    ///
    /// `.connected` alone is not enough to talk to a watch — Garmin's own header
    /// says so explicitly, and `deviceCharacteristicsDiscovered:` exists to mark
    /// the real ready point. Sending in the gap between the two fails silently.
    private(set) var readyDevices: Set<UUID> = []

    /// Whether XomFit is installed on the primary watch. Nil until asked.
    private(set) var isAppInstalled: Bool?

    /// The watch messages are sent to — the first paired device.
    var primaryDevice: IQDevice? { knownDevices.first }

    /// Whether the primary watch is connected and ready to receive.
    var isWatchReady: Bool {
        guard let id = primaryDevice?.uuid else { return false }
        return deviceStatuses[id] == .connected && readyDevices.contains(id)
    }

    /// Status of the primary watch, for display.
    var primaryStatus: IQDeviceStatus? {
        guard let id = primaryDevice?.uuid else { return nil }
        return deviceStatuses[id]
    }

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
    /// What the last pairing attempt did, in the lifter's terms.
    ///
    /// Exists because every failure in this chain so far has looked identical
    /// from the outside — Garmin Connect opens and nothing comes back — whether
    /// the cause was a missing caller, a misspelled selector, a swallowed URL,
    /// or GCM simply not being installed. "Nothing happened" is not a diagnosis,
    /// and four rounds of guessing is enough.
    enum PairingOutcome: Equatable {
        case idle
        /// `showConnectIQDeviceSelection` was called and we are waiting on the
        /// return URL. If this is where it stops, GCM never handed anything back.
        case awaitingGarminConnect(since: Date)
        /// The SDK says Garmin Connect is not installed.
        case garminConnectMissing
        /// A URL came back but carried no devices — usually the lifter cancelled.
        case returnedEmpty
        case paired(count: Int)
    }

    private(set) var pairingOutcome: PairingOutcome = .idle

    func start() {
        // A delegate rather than nil. With nil the SDK silently substitutes its
        // own UI, so the one event it reports — Garmin Connect missing — never
        // reached us.
        ConnectIQ.sharedInstance().initialize(
            withUrlScheme: Self.urlScheme,
            uiOverrideDelegate: self
        )
        isInitialized = true
        restoreDevices()
    }

    /// Sends the lifter to Garmin Connect to pick their watch.
    ///
    /// This leaves XomFit. Garmin Connect returns through the URL scheme, which
    /// is why `handleOpenURL` has to exist and be wired from the app delegate.
    /// True once `initialize` has run. Every other SDK call depends on it, and
    /// it happens in a `.task` behind an `await` on the notification permission
    /// prompt — so a lifter reaching Settings quickly can genuinely get here
    /// first.
    private(set) var isInitialized = false

    func beginDeviceSelection() {
        // Self-heal rather than fail silently. Ordering between app launch and
        // the lifter opening this screen is not something to rely on.
        if !isInitialized {
            start()
        }
        pairingOutcome = .awaitingGarminConnect(since: Date())
        ConnectIQ.sharedInstance().showDeviceSelection()
    }

    /// Consumes the return trip from Garmin Connect.
    ///
    /// Returns false when the URL was not ours, so the caller can pass it on
    /// rather than swallowing another feature's deep link.
    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme == Self.urlScheme else { return false }

        let devices = ConnectIQ.sharedInstance().parseDeviceSelectionResponse(from: url) as? [IQDevice] ?? []

        // Claim the URL either way. It is ours by scheme, and returning false
        // would drop it into the router's catch-all — which is the exact bug
        // that made pairing look like nothing happened at all.
        guard !devices.isEmpty else {
            pairingOutcome = .returnedEmpty
            return true
        }

        knownDevices = devices
        pairingOutcome = .paired(count: devices.count)
        persistDevices()
        registerForDeviceEvents()
        return true
    }

    // MARK: - Opening

    /// Asks the Garmin to open XomFit.
    ///
    /// Garmin shows a prompt on the watch rather than launching silently — that
    /// is the platform's design, not a limitation we can route around, and it is
    /// still far better than expecting the lifter to scroll their activity list
    /// with a barbell waiting.
    ///
    /// Called when a workout starts. Safe to call when the app is already
    /// running: the SDK reports that as its own result rather than an error, and
    /// nothing is shown to the user.
    private var lastSetActionAt: Date?

    /// True when enough time has passed to treat this as a new action rather
    /// than a duplicate delivery.
    private func acceptSetAction() -> Bool {
        let now = Date()
        if let last = lastSetActionAt, now.timeIntervalSince(last) < Self.setActionDebounce {
            #if DEBUG
            print("[Garmin] set action ignored (debounced)")
            #endif
            return false
        }
        lastSetActionAt = now
        return true
    }

    func requestOpenOnWatch() {
        guard let app, isWatchReady else { return }
        ConnectIQ.sharedInstance().openAppRequest(app) { result in
            #if DEBUG
            switch result {
            case .success:
                print("[Garmin] open prompt shown")
            case .failure_AppAlreadyRunning:
                print("[Garmin] app already running")
            default:
                print("[Garmin] open request failed: \(result.rawValue)")
            }
            #endif
        }
    }

    // MARK: - Sending

    /// Mirrors the workout to every known device.
    ///
    /// Sent transient. A rest countdown updates every second, and Garmin's
    /// device-side mailbox is small — queueing every tick would flood it, and a
    /// countdown delivered late is worse than one dropped.
    func send(state: WatchWorkoutState, detail: WatchWorkoutDetail = .empty) {
        guard let app, isWatchReady else { return }

        var message: [String: Any] = [
            "exercise": state.currentExercise,
            "set": state.setNumber,
            "totalSets": state.totalSets,
            "elapsed": state.elapsedSeconds,
            "paused": state.isPaused
        ]
        // The watch counts down in whole seconds and treats negatives as
        // overtime, matching how the phone already models rest.
        if let rest = restSeconds(from: state) {
            message["rest"] = rest
        }
        if let reps = detail.reps { message["reps"] = reps }
        if let weight = detail.weight { message["weight"] = weight }
        if !detail.tips.isEmpty { message["tips"] = detail.tips }
        if let index = detail.currentIndex { message["currentIndex"] = index }
        if !detail.plan.isEmpty {
            // Capped for the same reason as upNext: the device mailbox is small
            // and the watch shows four rows at a time.
            message["plan"] = detail.plan.prefix(Self.planLimit).map {
                ["name": $0.name, "done": $0.done, "total": $0.total] as [String: Any]
            }
        }
        if !detail.upNext.isEmpty {
            // Capped before it leaves the phone. The device mailbox is small and
            // the watch only draws a handful — sending twenty names would cost
            // bandwidth to display four.
            message["upNext"] = Array(detail.upNext.prefix(Self.upNextLimit))
        }

        ConnectIQ.sharedInstance().sendMessage(
            message,
            to: app,
            progress: nil,
            completion: { _ in }
        )
    }

    /// How many upcoming exercise names travel to the watch.
    private static let upNextLimit = 6
    /// How many plan rows travel. Longer sessions than this exist; the watch
    /// scrolls, but the payload has to stop somewhere.
    private static let planLimit = 12

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
            // Seed from the SDK rather than waiting for an event. A watch that
            // was already connected when the app launched may not generate a
            // status change at all, which would leave the pairing screen
            // claiming "not connected" over a working link.
            if let id = device.uuid {
                deviceStatuses[id] = ConnectIQ.sharedInstance().getDeviceStatus(device)
            }
        }
        if let device = primaryDevice {
            app = IQApp(uuid: Self.watchAppUUID, store: nil, device: device)
            if let app {
                ConnectIQ.sharedInstance().register(forAppMessages: app, delegate: self)
            }
        }
        refreshAppStatus()
    }

    /// Re-reads connection status for every paired device.
    func refreshStatuses() {
        for device in knownDevices {
            guard let id = device.uuid else { continue }
            deviceStatuses[id] = ConnectIQ.sharedInstance().getDeviceStatus(device)
        }
        refreshAppStatus()
    }

    /// Asks whether the XomFit watch app is installed on the paired device.
    ///
    /// Worth distinguishing from "not connected": a lifter who paired their
    /// watch but never installed the Connect IQ app sees messages go nowhere,
    /// and "connected" alone would tell them everything is fine.
    func refreshAppStatus() {
        guard let app else {
            isAppInstalled = nil
            return
        }
        ConnectIQ.sharedInstance().getAppStatus(app) { status in
            // Read the value out here: `IQAppStatus` is not Sendable and must
            // not cross the actor boundary.
            let installed = status?.isInstalled
            Task { @MainActor in
                GarminSyncService.shared.isAppInstalled = installed
            }
        }
    }

    /// Opens the Connect IQ store page for the watch app, so a lifter whose
    /// watch is paired but missing the app has somewhere to go.
    func showStoreListing() {
        guard let app else { return }
        ConnectIQ.sharedInstance().showStore(for: app)
    }

    /// Drops every paired device and stops listening.
    func forgetDevices() {
        ConnectIQ.sharedInstance().unregister(forAllDeviceEvents: self)
        if let app {
            ConnectIQ.sharedInstance().unregister(forAppMessages: app, delegate: self)
        }
        app = nil
        knownDevices = []
        deviceStatuses = [:]
        readyDevices = []
        isAppInstalled = nil
        UserDefaults.standard.removeObject(forKey: Self.storedDevicesKey)
    }

    /// Devices persist as archived data rather than ids: `IQDevice` carries the
    /// friendly name and model the UI needs, and re-deriving those would mean
    /// another trip through Garmin Connect.
    private func persistDevices() {
        // Secure coding, which `IQDevice` declares support for. The previous
        // non-secure archive could only be read back through
        // `unarchiveTopLevelObjectWithData`.
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: knownDevices, requiringSecureCoding: true
        ) else { return }
        UserDefaults.standard.set(data, forKey: Self.storedDevicesKey)
    }

    /// Reads back the paired devices.
    ///
    /// This crashed the app on every launch once a device had been paired.
    /// `unarchiveTopLevelObjectWithData` raises an **Objective-C exception** on
    /// anything it cannot decode, and Swift's `try?` does not catch those — so a
    /// payload it disliked took the process down before the UI appeared, over
    /// and over, with no way for the lifter to get far enough in to clear it.
    ///
    /// `unarchivedArrayOfObjects(ofClass:from:)` throws a Swift error instead,
    /// which `try?` genuinely handles. Bad data is discarded rather than
    /// retried forever: the cost is pairing once more, against an app that
    /// cannot open at all.
    private func restoreDevices() {
        guard let data = UserDefaults.standard.data(forKey: Self.storedDevicesKey) else { return }

        guard let devices = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(
            ofClass: IQDevice.self, from: data
        ) else {
            UserDefaults.standard.removeObject(forKey: Self.storedDevicesKey)
            #if DEBUG
            print("[Garmin] stored devices could not be decoded — cleared")
            #endif
            return
        }

        knownDevices = devices
        registerForDeviceEvents()
    }
}

// MARK: - Device status

extension GarminSyncService: IQDeviceEventDelegate {
    /// The Connect IQ selector is `deviceStatusChanged:status:`.
    ///
    /// This used to be spelled `device(_:statusChanged:)`, which Swift maps to
    /// the selector `device:statusChanged:` — a different selector entirely.
    /// Every method on `IQDeviceEventDelegate` is `@optional`, so nothing failed
    /// to compile and nothing warned; the callback simply never fired, which
    /// left `isWatchReady` false forever and made every send and open request a
    /// silent no-op. Verified against the selector table in the framework
    /// binary rather than the spelling in the header.
    nonisolated func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        guard let uuid = device.uuid else { return }
        Task { @MainActor in
            self.deviceStatuses[uuid] = status
            // Characteristics do not survive a disconnect, so drop readiness
            // whenever the device leaves `.connected`.
            if status != .connected {
                self.readyDevices.remove(uuid)
            }
        }
    }

    /// The point a device is genuinely able to receive messages.
    nonisolated func deviceCharacteristicsDiscovered(_ device: IQDevice) {
        guard let uuid = device.uuid else { return }
        Task { @MainActor in
            self.readyDevices.insert(uuid)
            // Now that the link is real, find out whether the watch app is
            // actually installed — the other silent failure mode.
            self.refreshAppStatus()
        }
    }
}

// MARK: - Receiving

extension GarminSyncService: IQAppMessageDelegate {
    /// Minimum gap between two accepted set-affecting messages.
    ///
    /// Bluetooth delivers duplicates, and the consequence here is worse than on
    /// the Apple Watch path: `completeFocusedSetFromWatch` is idempotent for the
    /// *same* set, but by the time a duplicate arrives the cursor has advanced,
    /// so the repeat silently logs the next set too. A test caught it.
    ///
    /// 0.75s matches the interval `WatchSyncService` already uses for the same
    /// class of problem.
    private static let setActionDebounce: TimeInterval = 0.75

    nonisolated func receivedMessage(_ message: Any, from app: IQApp) {
        guard let dict = message as? [String: Any],
              let type = dict["type"] as? String
        else { return }

        // Reps and weight are read here, off the main actor, because the
        // dictionary must not cross the isolation boundary.
        let reps = dict["reps"] as? Int
        let weight = dict["weight"] as? Int

        Task { @MainActor in
            switch type {
            case "doneSet":
                guard self.acceptSetAction() else { return }
                // The same entry point the Apple Watch uses. It is idempotent
                // per set, which matters here too: Bluetooth can deliver twice.
                NotificationCenter.default.post(name: .garminActionReceived, object: nil,
                                               userInfo: ["action": "doneSet"])
            case "skipRest":
                NotificationCenter.default.post(name: .garminActionReceived, object: nil,
                                               userInfo: ["action": "skipRest"])
            case "logSet":
                guard self.acceptSetAction() else { return }
                var info: [String: Any] = ["action": "logSet"]
                if let reps { info["reps"] = reps }
                if let weight { info["weight"] = weight }
                NotificationCenter.default.post(name: .garminActionReceived, object: nil,
                                               userInfo: info)
            case "extendRest":
                NotificationCenter.default.post(name: .garminActionReceived, object: nil,
                                               userInfo: ["action": "extendRest"])
            case "nextExercise":
                NotificationCenter.default.post(name: .garminActionReceived, object: nil,
                                               userInfo: ["action": "nextExercise"])
            case "adjustSet":
                var info: [String: Any] = ["action": "adjustSet"]
                if let reps { info["reps"] = reps }
                if let weight { info["weight"] = weight }
                NotificationCenter.default.post(name: .garminActionReceived, object: nil,
                                               userInfo: info)
            default:
                break
            }
        }
    }
}

/// The parts of a workout the watch shows that `WatchWorkoutState` does not
/// carry.
///
/// Kept separate rather than widened into `WatchWorkoutState`, because the Apple
/// Watch does not display any of it and every field added there costs bandwidth
/// on a link that already works.
struct WatchWorkoutDetail {
    var reps: Int?
    var weight: Int?
    var upNext: [String]
    /// Short form cues for the current lift. Phrases, not sentences: a round
    /// screen cannot show a sentence and a lifter mid-set will not read one.
    var tips: [String]
    /// Every exercise with its set progress, for the watch's plan overview.
    var plan: [PlanRow]
    /// Which entry in `plan` is being worked.
    var currentIndex: Int?

    /// One exercise as the watch needs it: a name and how far through it is.
    /// Deliberately not the sets themselves — per-set weights would multiply the
    /// payload for detail no watch screen can usefully show.
    struct PlanRow {
        let name: String
        let done: Int
        let total: Int
    }

    static let empty = WatchWorkoutDetail(
        reps: nil, weight: nil, upNext: [], tips: [], plan: [], currentIndex: nil
    )
}

extension Notification.Name {
    /// Posted when the Garmin watch asks for something. `userInfo["action"]`
    /// carries which. Observed by the app shell, which owns the workout view
    /// model — the service deliberately does not reach into it.
    static let garminActionReceived = Notification.Name("garminActionReceived")
}

// MARK: - SDK-reported problems

extension GarminSyncService: IQUIOverrideDelegate {
    /// The SDK's only callback for "this cannot work". Passing nil for the
    /// delegate meant the SDK showed its own UI and the app learned nothing —
    /// which is indistinguishable, from the lifter's side, from every other
    /// failure in this chain.
    nonisolated func needsToInstallConnectMobile() {
        Task { @MainActor in
            self.pairingOutcome = .garminConnectMissing
        }
    }
}
