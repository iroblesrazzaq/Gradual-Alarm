import Foundation

@MainActor
enum AlarmOccurrenceScheduler {
    static let snoozeDuration: TimeInterval = 10 * 60

    static func activateOccurrence(for alarm: Alarm, fireDate: Date, rampMinutesOverride: Int? = nil) {
        AudioRampPlayer.shared.arm(for: armedAlarm(from: alarm, rampMinutesOverride: rampMinutesOverride), fireDate: fireDate)
        BackupAlarmManager.shared.prepareBackupAlarm(after: fireDate, rampMinutesOverride: rampMinutesOverride)
        NotificationManager.shared.prepareFallbackNotification(for: alarm, fireDate: fireDate)
    }

    static func reschedule(using alarm: Alarm, after referenceDate: Date = Date()) {
        let nextFireDate = alarm.fireDate(after: referenceDate)
        cancelCurrentOccurrence()
        activateOccurrence(for: alarm, fireDate: nextFireDate)
    }

    static func skipCurrentOccurrence(using alarm: Alarm, currentFireDate: Date?, recordStop: Bool) {
        let referenceDate = currentFireDate ?? alarm.nextFireDate
        NotificationManager.shared.cancelAlarmNotification()
        BackupAlarmManager.shared.cancelBackup()
        AudioRampPlayer.shared.stop(recordStopAt: recordStop)

        let nextFireDate = alarm.fireDate(after: referenceDate)
        activateOccurrence(for: alarm, fireDate: nextFireDate)
    }

    static func snoozeCurrentOccurrence(using alarm: Alarm, snoozeDate: Date = Date().addingTimeInterval(snoozeDuration)) {
        cancelCurrentOccurrence()

        let rampMinutesOverride = min(alarm.rampMinutes, Int(snoozeDuration / 60))
        activateOccurrence(for: alarm, fireDate: snoozeDate, rampMinutesOverride: rampMinutesOverride)

        _ = AlarmDiagnosticsStore.update { diagnostics in
            diagnostics.lastSnoozeAt = Date()
            diagnostics.lastSnoozeFireDate = snoozeDate
        }
    }

    static func cancelCurrentOccurrence() {
        NotificationManager.shared.cancelAlarmNotification()
        BackupAlarmManager.shared.cancelBackup()
        AudioRampPlayer.shared.stop()
    }

    private static func armedAlarm(from alarm: Alarm, rampMinutesOverride: Int?) -> Alarm {
        guard let rampMinutesOverride else { return alarm }
        var alarm = alarm
        alarm.rampMinutes = max(1, rampMinutesOverride)
        return alarm
    }
}
