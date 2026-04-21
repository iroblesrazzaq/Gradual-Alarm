import AppIntents

struct StopBackupAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Backup Alarm"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        await BackupAlarmManager.shared.handleStopIntent(for: alarmID)
        return .result()
    }
}
