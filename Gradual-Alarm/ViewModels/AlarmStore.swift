import Foundation
import Combine
import SwiftUI

@MainActor
final class AlarmStore: ObservableObject {
    @Published var alarm: Alarm
    @Published var isAlarmFiring = false
    @Published var volumeWarningVisible = false
    @Published var diagnostics = AlarmDiagnosticsStore.load()

    init() {
        self.alarm = Alarm.load()
        wireAudioCallbacks()
        syncFromAudioState()
    }

    func activate() {
        if AudioRampPlayer.shared.isArmed {
            NotificationManager.shared.scheduleAlarmNotificationIfAuthorized(
                for: alarm,
                fireDate: AudioRampPlayer.shared.currentFireDate
            )
            syncFromAudioState()
            return
        }

        reschedule()
        NotificationManager.shared.prepareFallbackNotification(for: alarm)
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
        let currentFireDate = AudioRampPlayer.shared.currentFireDate ?? alarm.nextFireDate
        stopAudio(userInitiated: true)
        reschedule(after: currentFireDate)
    }

    func scheduleAudio() {
        scheduleAudio(for: alarm.nextFireDate)
    }

    func stopAudio(userInitiated: Bool = false) {
        AudioRampPlayer.shared.stop(recordStopAt: userInitiated)
        syncFromAudioState()
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active, .inactive, .background:
            syncFromAudioState()
        @unknown default:
            syncFromAudioState()
        }
    }

    func syncFromAudioState() {
        isAlarmFiring = AudioRampPlayer.shared.currentPhase == .ramping
        diagnostics = AudioRampPlayer.shared.diagnostics
        if AudioRampPlayer.shared.isArmed {
            NotificationManager.shared.scheduleAlarmNotificationIfAuthorized(
                for: alarm,
                fireDate: AudioRampPlayer.shared.currentFireDate
            )
        }
    }

    // MARK: - Private

    private func reschedule(after referenceDate: Date = Date()) {
        let nextFireDate = alarm.fireDate(after: referenceDate)
        NotificationManager.shared.cancelAlarmNotification()
        stopAudio()
        scheduleAudio(for: nextFireDate)
        NotificationManager.shared.scheduleAlarmNotificationIfAuthorized(for: alarm, fireDate: nextFireDate)
    }

    private func scheduleAudio(for fireDate: Date) {
        AudioRampPlayer.shared.arm(for: alarm, fireDate: fireDate)
        syncFromAudioState()
    }

    private func wireAudioCallbacks() {
        AudioRampPlayer.shared.onStateChanged = { [weak self] in
            self?.syncFromAudioState()
        }
    }
}
