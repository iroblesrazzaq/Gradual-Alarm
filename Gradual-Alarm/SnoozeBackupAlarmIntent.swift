import AppIntents

struct SnoozeBackupAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze Backup Alarm"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        await BackupAlarmManager.shared.handleSnoozeIntent(for: alarmID)
        return .result()
    }
}
