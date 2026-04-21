import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let alarmIdentifier = "gradualwake.alarm"

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    func prepareFallbackNotification(for alarm: Alarm) {
        checkPermissionStatus { [weak self] status in
            guard let self else { return }

            switch status {
            case .authorized, .provisional, .ephemeral:
                self.scheduleAlarmNotification(for: alarm)
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        self.scheduleAlarmNotification(for: alarm)
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func scheduleAlarmNotificationIfAuthorized(for alarm: Alarm, fireDate: Date? = nil) {
        checkPermissionStatus { [weak self] status in
            guard let self else { return }
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            self.scheduleAlarmNotification(for: alarm, fireDate: fireDate)
        }
    }

    func scheduleAlarmNotification(for alarm: Alarm, fireDate: Date? = nil) {
        let interval = (fireDate ?? alarm.nextFireDate).timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Wake up"
        content.body = "Your alarm is ringing"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: alarmIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("NotificationManager: failed to schedule fallback notification: \(error.localizedDescription)")
            }
        }
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
