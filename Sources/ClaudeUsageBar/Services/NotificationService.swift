import Foundation
import UserNotifications

/// Sends native macOS notifications when usage crosses specific thresholds.
/// Tracks which thresholds have been notified per reset window to avoid spam.
final class NotificationService {
    static let shared = NotificationService()

    /// Thresholds at which to notify (percentage values).
    private let thresholds: [Double] = [50, 80, 90]

    /// UserDefaults keys for persisting state.
    private enum Keys {
        static let fiveHourNotified = "notification_fiveHour_notifiedThresholds"
        static let sevenDayNotified = "notification_sevenDay_notifiedThresholds"
        static let fiveHourWindow = "notification_fiveHour_windowTimestamp"
        static let sevenDayWindow = "notification_sevenDay_windowTimestamp"
        static let fiveHourPreviousAbove50 = "notification_fiveHour_wasAbove50"
        static let sevenDayPreviousAbove50 = "notification_sevenDay_wasAbove50"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Permission

    /// Request notification permission on first launch.
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Threshold Checking

    /// Check both windows for threshold crossings after a data refresh.
    func checkThresholds(fiveHour: RateLimitBucket?, sevenDay: RateLimitBucket?) {
        if let fh = fiveHour {
            checkWindow(
                label: "Session",
                usage: fh.used_percentage,
                resetsAt: fh.resets_at,
                notifiedKey: Keys.fiveHourNotified,
                windowKey: Keys.fiveHourWindow,
                wasAbove50Key: Keys.fiveHourPreviousAbove50
            )
        }
        if let sd = sevenDay {
            checkWindow(
                label: "Weekly",
                usage: sd.used_percentage,
                resetsAt: sd.resets_at,
                notifiedKey: Keys.sevenDayNotified,
                windowKey: Keys.sevenDayWindow,
                wasAbove50Key: Keys.sevenDayPreviousAbove50
            )
        }
    }

    // MARK: - Private

    private func checkWindow(
        label: String,
        usage: Double,
        resetsAt: Double?,
        notifiedKey: String,
        windowKey: String,
        wasAbove50Key: String
    ) {
        let currentWindow = resetsAt ?? 0
        let previousWindow = defaults.double(forKey: windowKey)

        // If the reset window changed, clear notified thresholds
        if currentWindow != previousWindow {
            defaults.set(currentWindow, forKey: windowKey)
            defaults.removeObject(forKey: notifiedKey)
        }

        var notified = Set(defaults.array(forKey: notifiedKey) as? [Double] ?? [])
        let wasAbove50 = defaults.bool(forKey: wasAbove50Key)

        // Check for reset: usage was >= 50% and now <= 1%
        if wasAbove50 && usage <= 1 {
            sendNotification(
                title: "\(label) usage reset!",
                body: "Limits have reset! You're back to full capacity."
            )
            // Clear all notified thresholds since we've reset
            notified.removeAll()
            defaults.set(false, forKey: wasAbove50Key)
        }

        // Track whether usage has been above 50%
        if usage >= 50 {
            defaults.set(true, forKey: wasAbove50Key)
        }

        // Check ascending thresholds
        for threshold in thresholds {
            if usage >= threshold && !notified.contains(threshold) {
                notified.insert(threshold)
                let severity: String
                switch threshold {
                case 50: severity = "moderate usage"
                case 80: severity = "approaching limit"
                case 90: severity = "near limit"
                default: severity = ""
                }
                sendNotification(
                    title: "\(label) usage at \(Int(threshold))%",
                    body: "Usage at \(Int(threshold))% \u{2014} \(severity)"
                )
            }
        }

        defaults.set(Array(notified), forKey: notifiedKey)
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
