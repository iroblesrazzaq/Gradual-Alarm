import Foundation
import Combine

final class AlarmStore: ObservableObject {
    @Published var alarm: Alarm
    @Published var isAlarmFiring = false
    @Published var volumeWarningVisible = false

    init() {
        self.alarm = Alarm.load()
    }

    func activate() {
        NotificationManager.shared.requestPermission { [weak self] granted in
            guard let self, granted else { return }
            self.reschedule()
        }
    }

    func updateTime(hour: Int, minute: Int) {
        alarm.timeHour = hour
        alarm.timeMinute = minute
        alarm.save()
        reschedule()
    }

    func updateRamp(_ minutes: Int) {
        alarm.rampMinutes = minutes
        alarm.save()
        reschedule()
    }

    func stopAlarm() {
        isAlarmFiring = false
        stopAudio()
        reschedule()
    }

    // MARK: - Audio stubs (wired in M2)

    func scheduleAudio() {
        // M2: AudioRampPlayer.shared.scheduleRamp(for: alarm)
    }

    func stopAudio() {
        // M2: AudioRampPlayer.shared.stopAll()
    }

    // MARK: - Private

    private func reschedule() {
        NotificationManager.shared.cancelAlarmNotification()
        NotificationManager.shared.scheduleAlarmNotification(for: alarm)
        stopAudio()
        scheduleAudio()
    }
}
