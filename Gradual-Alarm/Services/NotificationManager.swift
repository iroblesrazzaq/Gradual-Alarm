import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let alarmIdentifier = "gradualwake.alarm"

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    func scheduleAlarmNotification(for alarm: Alarm) {
        let interval = alarm.nextFireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Wake up"
        content.body = "Your alarm is ringing"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: alarmIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelAlarmNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarmIdentifier])
    }

    // Play banner + sound even when the app is frontmost
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
