import Foundation
import UserNotifications

extension InstagramWebView.Coordinator {
    private enum NativeTimerKeys {
        static let endTimestampMs = "ss_timer_end_timestamp_ms"
        static let label = "ss_timer_label"
    }

    func scheduleTimerNotification(minutes: Int, label: String, endTimestampMs: Double? = nil) {
        let endMs = endTimestampMs ?? (Date().timeIntervalSince1970 * 1000) + Double(minutes * 60 * 1000)
        persistNativeTimer(endTimestampMs: endMs, label: label)

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "StopScroll"
            content.body = "Timer done — \(label). Time to put the phone down."
            content.sound = .default

            let remainingSeconds = max((endMs / 1000) - Date().timeIntervalSince1970, 1)
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: remainingSeconds,
                repeats: false
            )

            center.removePendingNotificationRequests(withIdentifiers: ["stopscroll-timer"])

            let request = UNNotificationRequest(
                identifier: "stopscroll-timer",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        DispatchQueue.main.async {
            self.syncNativeTimerStateToWebView(markExpiredIfNeeded: false)
        }
    }

    func cancelNativeTimer() {
        clearNativeTimerState()
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["stopscroll-timer"])

        DispatchQueue.main.async {
            self.syncNativeTimerStateToWebView(markExpiredIfNeeded: false)
        }
    }

    func syncNativeTimerStateToWebView(markExpiredIfNeeded: Bool) {
        guard let webView else { return }

        let nowMs = Date().timeIntervalSince1970 * 1000
        let endTimestampMs = UserDefaults.standard.double(forKey: NativeTimerKeys.endTimestampMs)
        let label = UserDefaults.standard.string(forKey: NativeTimerKeys.label) ?? ""
        let escapedLabel = label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        let js: String
        if endTimestampMs > nowMs {
            js = "window.__STOPSCROLL_TIMER = {end:\(Int(endTimestampMs)),label:'\(escapedLabel)'};"
        } else if endTimestampMs > 0, markExpiredIfNeeded {
            clearNativeTimerState()
            js = "window.__STOPSCROLL_TIMER = null; if (!window.__STOPSCROLL_TIMER_EXPIRED) { window.__STOPSCROLL_TIMER_EXPIRED = { remaining: 10 }; }"
        } else {
            js = "window.__STOPSCROLL_TIMER = null;"
        }

        webView.evaluateJavaScript(js)
    }

    private func persistNativeTimer(endTimestampMs: Double, label: String) {
        UserDefaults.standard.set(endTimestampMs, forKey: NativeTimerKeys.endTimestampMs)
        UserDefaults.standard.set(label, forKey: NativeTimerKeys.label)
    }

    private func clearNativeTimerState() {
        UserDefaults.standard.removeObject(forKey: NativeTimerKeys.endTimestampMs)
        UserDefaults.standard.removeObject(forKey: NativeTimerKeys.label)
    }
}
