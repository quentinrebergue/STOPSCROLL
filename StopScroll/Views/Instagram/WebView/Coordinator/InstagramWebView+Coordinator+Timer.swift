import Foundation
import UserNotifications

extension InstagramWebView.Coordinator {
    func scheduleTimerNotification(minutes: Int, label: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "StopScroll"
            content.body = "Timer done — \(label). Time to put the phone down."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(TimeInterval(minutes * 60), 1),
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
    }
}
