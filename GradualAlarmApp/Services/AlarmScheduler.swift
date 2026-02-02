import Foundation
import UserNotifications

struct AlarmScheduler {
    static let alarmCategory = "ALARM_CATEGORY"
    static let alarmNotificationId = "alarm_T"
    static let alarmEscalationNotificationId = "alarm_T_plus_60"

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func computeNextFireDate(now: Date = Date(), hour: Int, minute: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let today = calendar.date(from: components) ?? now
        if today <= now {
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        return today
    }

    func computeFadeStart(fireDate: Date, fadeMinutes: Int) -> Date {
        calendar.date(byAdding: .minute, value: -max(1, fadeMinutes), to: fireDate) ?? fireDate
    }

    func registerCategories() {
        let snooze = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze",
            options: []
        )
        let dismiss = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.alarmCategory,
            actions: [snooze, dismiss],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func scheduleNotifications(fireDate: Date) async {
        await cancelNotifications()
        registerCategories()

        let content = UNMutableNotificationContent()
        content.title = "Gradual Alarm"
        content.body = "Alarm time."
        content.sound = .default
        content.categoryIdentifier = Self.alarmCategory

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.alarmNotificationId,
            content: content,
            trigger: trigger
        )

        let escalationContent = UNMutableNotificationContent()
        escalationContent.title = "Gradual Alarm"
        escalationContent.body = "Alarm is still ringing."
        escalationContent.sound = .default
        escalationContent.categoryIdentifier = Self.alarmCategory

        let escalationDate = calendar.date(byAdding: .second, value: 60, to: fireDate) ?? fireDate
        let escalationTrigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: escalationDate),
            repeats: false
        )
        let escalationRequest = UNNotificationRequest(
            identifier: Self.alarmEscalationNotificationId,
            content: escalationContent,
            trigger: escalationTrigger
        )

        do {
            try await center.add(request)
            try await center.add(escalationRequest)
        } catch {
            // Best effort; notifications may fail if permissions are disabled.
        }
    }

    func cancelNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.alarmNotificationId, Self.alarmEscalationNotificationId])
    }
}
