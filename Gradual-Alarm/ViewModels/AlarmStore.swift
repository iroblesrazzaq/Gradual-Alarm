import Foundation
import Combine
import SwiftUI

@MainActor
final class AlarmStore: ObservableObject {
    @Published var alarm: Alarm
    @Published var isAlarmFiring = false
    @Published var volumeWarningVisible = false
    @Published var systemAlarmWarningVisible = false
    @Published var diagnostics = AlarmDiagnosticsStore.load()

    init() {
        self.alarm = Alarm.load()
        wireAudioCallbacks()
        syncFromAudioState()
    }

    func activate() {
        let fireDate = AudioRampPlayer.shared.currentFireDate ?? alarm.nextFireDate

        if AudioRampPlayer.shared.isArmed {
            NotificationManager.shared.scheduleAlarmNotificationIfAuthorized(
                for: alarm,
                fireDate: fireDate
            )
            BackupAlarmManager.shared.scheduleBackupIfAuthorized(
                after: fireDate,
                rampMinutesOverride: BackupAlarmManager.shared.trackedRampMinutesOverride
            )
            syncFromAudioState()
            return
        }

        if let recoveredFireDate = BackupAlarmManager.shared.trackedPrimaryFireDate,
           recoveredFireDate > Date() {
            AlarmOccurrenceScheduler.activateOccurrence(
                for: alarm,
                fireDate: recoveredFireDate,
                rampMinutesOverride: BackupAlarmManager.shared.trackedRampMinutesOverride
            )
        } else {
            AlarmOccurrenceScheduler.reschedule(using: alarm, after: Date())
        }
        syncFromAudioState()
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
        AlarmOccurrenceScheduler.skipCurrentOccurrence(using: alarm, currentFireDate: currentFireDate, recordStop: true)
        syncFromAudioState()
    }

    func snoozeAlarm() {
        isAlarmFiring = false
        AlarmOccurrenceScheduler.snoozeCurrentOccurrence(using: alarm)
        syncFromAudioState()
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
            AudioRampPlayer.shared.syncForCurrentTime()
            syncFromAudioState()
        @unknown default:
            AudioRampPlayer.shared.syncForCurrentTime()
            syncFromAudioState()
        }
    }

    func syncFromAudioState() {
        isAlarmFiring = AudioRampPlayer.shared.currentPhase == .ramping
        diagnostics = AudioRampPlayer.shared.diagnostics
        systemAlarmWarningVisible = shouldShowSystemAlarmWarning(from: diagnostics)
        if AudioRampPlayer.shared.isArmed {
            NotificationManager.shared.scheduleAlarmNotificationIfAuthorized(
                for: alarm,
                fireDate: AudioRampPlayer.shared.currentFireDate
            )
        }
    }

    // MARK: - Private

    private func reschedule(after referenceDate: Date = Date()) {
        AlarmOccurrenceScheduler.reschedule(using: alarm, after: referenceDate)
        syncFromAudioState()
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

    private func shouldShowSystemAlarmWarning(from diagnostics: AlarmDiagnostics) -> Bool {
        guard let outcome = diagnostics.lastRecoveryOutcome else { return false }

        let degradedOutcomes: Set<String> = [
            "resume_failed",
            "resume_failed_without_shouldResume",
            "scene_phase_catchup_failed",
            "route_change_recovery_failed",
            "arm_failed",
            "resume_failed_without_shouldResume_play_failed"
        ]

        return degradedOutcomes.contains(outcome)
    }
}
