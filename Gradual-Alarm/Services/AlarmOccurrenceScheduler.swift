import Foundation

@MainActor
enum AlarmOccurrenceScheduler {
    static func activateOccurrence(for alarm: Alarm, fireDate: Date) {
        AudioRampPlayer.shared.arm(for: alarm, fireDate: fireDate)
        BackupAlarmManager.shared.prepareBackupAlarm(after: fireDate)
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

    static func cancelCurrentOccurrence() {
        NotificationManager.shared.cancelAlarmNotification()
        BackupAlarmManager.shared.cancelBackup()
        AudioRampPlayer.shared.stop()
    }
}
