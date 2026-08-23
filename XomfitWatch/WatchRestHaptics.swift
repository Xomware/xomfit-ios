import Foundation
import WatchKit

/// Buzzes the wrist through the last seconds of rest, then alarms at zero.
///
/// The Apple Watch app has never had haptics — the rest cue shipped phone-only,
/// which is the wrong place for it. Nobody keeps a phone on them mid-set.
///
/// Deliberately mirrors the phone and the Garmin app: five countdown ticks, then
/// roughly three seconds of pulsing. Three devices, one pattern, so they read as
/// one product rather than three apps that share a name.
///
/// **Counts down locally.** The phone sends an absolute `restEndDate`, not a
/// per-second tick, so this drives itself from a timer. Waiting on a message
/// every second would make the buzz only as steady as the Bluetooth link, and
/// the one moment it must be exact is the moment it fires.
@MainActor
final class WatchRestHaptics {
    /// Seconds of countdown ticks before the alarm.
    static let leadInSeconds = 5

    /// Pulses in the end-of-rest alarm, and their shape.
    ///
    /// `WKInterfaceDevice.play` takes a single named haptic — there is no
    /// duration or profile to hand it, unlike Core Haptics on the phone or
    /// `VibeProfile` on Garmin. So the three seconds are built by repeating a
    /// `.notification` on a timer rather than described in one call.
    private static let alarmPulses = 6
    private static let alarmInterval: TimeInterval = 0.5

    /// Whole second a tick last fired for, or nil when nothing has fired for the
    /// current rest period. Zero means the alarm has already played.
    ///
    /// Keyed on the second rather than a fired flag, for the same reason as the
    /// phone: the countdown is not the only thing that moves the clock. A new
    /// snapshot can jump it, and extending rest pushes it back up.
    private var lastTickSecond: Int?
    private var alarmTimer: Timer?

    /// Call on every tick of the view's own timer.
    ///
    /// `enabled` comes from the phone rather than a local setting: the toggle
    /// lives in one place, and a watch cannot read iPhone defaults.
    func update(restEndDate: Date?, isPaused: Bool, enabled: Bool) {
        guard enabled, !isPaused, let restEndDate else {
            reset()
            return
        }

        let remaining = Int(restEndDate.timeIntervalSinceNow.rounded(.up))

        if remaining <= 0 {
            guard lastTickSecond != 0 else { return }
            lastTickSecond = 0
            playAlarm()
            return
        }

        guard remaining <= Self.leadInSeconds, lastTickSecond != remaining else { return }
        lastTickSecond = remaining
        WKInterfaceDevice.current().play(.click)
    }

    /// Re-arms for the next rest period.
    func reset() {
        lastTickSecond = nil
        alarmTimer?.invalidate()
        alarmTimer = nil
    }

    private func playAlarm() {
        alarmTimer?.invalidate()
        var fired = 0

        // First pulse immediately — a timer's first fire is one interval late,
        // and the alarm has to land on zero, not half a second after it.
        WKInterfaceDevice.current().play(.notification)
        fired += 1

        alarmTimer = Timer.scheduledTimer(withTimeInterval: Self.alarmInterval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }
                guard fired < Self.alarmPulses else {
                    timer.invalidate()
                    self.alarmTimer = nil
                    return
                }
                WKInterfaceDevice.current().play(.notification)
                fired += 1
            }
        }
    }
}
