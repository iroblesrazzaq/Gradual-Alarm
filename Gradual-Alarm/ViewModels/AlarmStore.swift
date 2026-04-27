import AVFoundation
import AlarmKit
import Foundation
import Combine
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

enum ReliabilityStatusKind {
    case ready
    case warning
    case actionNeeded
    case unknown
}

struct ReliabilityStatus {
    var title: String
    var detail: String
    var kind: ReliabilityStatusKind
    var canOpenSettings: Bool = false
}

@MainActor
final class AlarmStore: ObservableObject {
    @Published var alarm: Alarm
    @Published var isAlarmFiring = false
    @Published var volumeWarningVisible = false
    @Published var systemAlarmWarningVisible = false
    @Published var audioRouteWarningText: String?
    @Published var diagnostics = AlarmDiagnosticsStore.load()
    @Published var notificationStatus = ReliabilityStatus(
        title: "Fallback notification",
        detail: "Checking permission...",
        kind: .unknown
    )
    @Published var backupAlarmStatus = ReliabilityStatus(
        title: "System backup",
        detail: "Checking permission...",
        kind: .unknown
    )
    @Published var gradualAudioStatus = ReliabilityStatus(
        title: "Gradual audio",
        detail: "Checking audio...",
        kind: .unknown
    )

    private var environmentTimer: Timer?
    private let lowVolumeThreshold: Float = 0.25

    init() {
        let loadedAlarm = Alarm.load()
        let cleanedAlarm = loadedAlarm.clearingExpiredSkip()
        if loadedAlarm.skippedFireDate != cleanedAlarm.skippedFireDate {
            cleanedAlarm.save()
        }

        self.alarm = cleanedAlarm
        wireAudioCallbacks()
        syncFromAudioState()
    }

    func activate() {
        startEnvironmentMonitoring()

        let fireDate = AudioRampPlayer.shared.currentFireDate ?? alarm.nextFireDate

        if AudioRampPlayer.shared.isArmed {
            NotificationManager.shared.scheduleAlarmNotificationIfAuthorized(
                for: alarm,
                fireDate: fireDate
            )
            BackupAlarmManager.shared.scheduleBackupIfAuthorized(
                for: alarm,
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
        refreshReliabilityState()
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

    func updateRepeatWeekdays(_ weekdays: Set<Int>) {
        let validWeekdays = Set(weekdays.filter { Alarm.allWeekdays.contains($0) })
        alarm.repeatWeekdays = validWeekdays.isEmpty ? Alarm.allWeekdays : validWeekdays
        alarm.skippedFireDate = nil
        alarm.save()
        reschedule()
    }

    func updateSound(_ sound: AlarmSound) {
        alarm.sound = sound
        alarm.save()
        reschedule()
    }

    func updatePeakVolume(_ peakVolume: Float) {
        alarm.peakVolume = min(max(peakVolume, 0.1), 1)
        alarm.save()
        reschedule()
    }

    func updateRampCurve(_ rampCurve: AlarmRampCurve) {
        alarm.rampCurve = rampCurve
        alarm.save()
        reschedule()
    }

    func updateNudgeEnabled(_ isEnabled: Bool) {
        alarm.nudgeEnabled = isEnabled
        alarm.save()
        reschedule()
    }

    func updateNudgeMinutes(_ minutes: Int) {
        alarm.nudgeMinutes = min(max(minutes, Alarm.nudgeRange.lowerBound), Alarm.nudgeRange.upperBound)
        alarm.save()
        reschedule()
    }

    func skipNextOccurrence() {
        alarm = AlarmOccurrenceScheduler.skipNextOccurrence(using: alarm)
        syncFromAudioState()
    }

    func clearSkippedOccurrence() {
        alarm = AlarmOccurrenceScheduler.clearSkippedOccurrence(using: alarm)
        syncFromAudioState()
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
            updateEnvironmentWarnings()
            syncFromAudioState()
            refreshReliabilityState()
        @unknown default:
            AudioRampPlayer.shared.syncForCurrentTime()
            updateEnvironmentWarnings()
            syncFromAudioState()
            refreshReliabilityState()
        }
    }

    func syncFromAudioState() {
        isAlarmFiring = AudioRampPlayer.shared.currentPhase == .alerting
        diagnostics = AudioRampPlayer.shared.diagnostics
        systemAlarmWarningVisible = shouldShowSystemAlarmWarning(from: diagnostics)
        updateEnvironmentWarnings()
        if AudioRampPlayer.shared.isArmed {
            NotificationManager.shared.scheduleAlarmNotificationIfAuthorized(
                for: alarm,
                fireDate: AudioRampPlayer.shared.currentFireDate
            )
        }
        refreshReliabilityState()
    }

    func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
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

    private func startEnvironmentMonitoring() {
        guard environmentTimer == nil else { return }
        updateEnvironmentWarnings()

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateEnvironmentWarnings()
                self.refreshReliabilityState()
            }
        }
        environmentTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshReliabilityState() {
        updateGradualAudioStatus()
        updateBackupAlarmStatus()
        updateNotificationStatus()
    }

    private func updateGradualAudioStatus() {
        guard AudioRampPlayer.shared.isArmed else {
            gradualAudioStatus = ReliabilityStatus(
                title: "Gradual audio",
                detail: "Not armed yet",
                kind: .warning
            )
            return
        }

        switch AudioRampPlayer.shared.currentPhase {
        case .silentHold:
            gradualAudioStatus = ReliabilityStatus(
                title: "Gradual audio",
                detail: "Armed; ramp starts at \(formatTime(alarm.rampStartDate(for: activeFireDate)))",
                kind: .ready
            )
        case .ramping:
            gradualAudioStatus = ReliabilityStatus(
                title: "Gradual audio",
                detail: "Ramping now",
                kind: .ready
            )
        case .alerting:
            gradualAudioStatus = ReliabilityStatus(
                title: "Gradual audio",
                detail: "Alarm is ringing",
                kind: .ready
            )
        case .idle:
            gradualAudioStatus = ReliabilityStatus(
                title: "Gradual audio",
                detail: "Not armed yet",
                kind: .warning
            )
        }
    }

    private func updateBackupAlarmStatus() {
        switch BackupAlarmManager.shared.authorizationState {
        case .authorized:
            if let backupFireDate = BackupAlarmManager.shared.trackedBackupFireDate,
               backupFireDate > Date(),
               Calendar.current.isDate(backupFireDate, equalTo: activeFireDate, toGranularity: .minute) {
                backupAlarmStatus = ReliabilityStatus(
                    title: "System backup",
                    detail: "Ready for \(formatTime(backupFireDate))",
                    kind: .ready
                )
            } else {
                backupAlarmStatus = ReliabilityStatus(
                    title: "System backup",
                    detail: "Authorized but not scheduled yet",
                    kind: .warning
                )
            }
        case .notDetermined:
            backupAlarmStatus = ReliabilityStatus(
                title: "System backup",
                detail: "Permission needed",
                kind: .actionNeeded
            )
        case .denied:
            backupAlarmStatus = ReliabilityStatus(
                title: "System backup",
                detail: "Permission denied",
                kind: .actionNeeded,
                canOpenSettings: true
            )
        @unknown default:
            backupAlarmStatus = ReliabilityStatus(
                title: "System backup",
                detail: "Unavailable on this device",
                kind: .actionNeeded
            )
        }
    }

    private func updateNotificationStatus() {
        NotificationManager.shared.checkPermissionStatus { [weak self] status in
            guard let self else { return }

            switch status {
            case .authorized, .provisional, .ephemeral:
                self.notificationStatus = ReliabilityStatus(
                    title: "Fallback notification",
                    detail: "Ready",
                    kind: .ready
                )
            case .notDetermined:
                self.notificationStatus = ReliabilityStatus(
                    title: "Fallback notification",
                    detail: "Permission needed",
                    kind: .actionNeeded
                )
            case .denied:
                self.notificationStatus = ReliabilityStatus(
                    title: "Fallback notification",
                    detail: "Permission denied",
                    kind: .actionNeeded,
                    canOpenSettings: true
                )
            @unknown default:
                self.notificationStatus = ReliabilityStatus(
                    title: "Fallback notification",
                    detail: "Permission unavailable",
                    kind: .actionNeeded
                )
            }
        }
    }

    private func updateEnvironmentWarnings() {
        let session = AVAudioSession.sharedInstance()
        volumeWarningVisible = session.outputVolume < lowVolumeThreshold || alarm.peakVolume < lowVolumeThreshold
        audioRouteWarningText = currentAudioRouteWarning(from: session.currentRoute)
    }

    private func currentAudioRouteWarning(from route: AVAudioSessionRouteDescription) -> String? {
        let outputs = route.outputs
        guard !outputs.isEmpty else {
            return "No audio output is active. The alarm may not be audible."
        }

        if let output = outputs.first(where: { $0.portType == .headphones }) {
            return "Audio is routed to \(output.portName). Unplug headphones before sleep."
        }

        if let output = outputs.first(where: { [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0.portType) }) {
            return "Audio is routed to \(output.portName). Bluetooth can disconnect overnight."
        }

        if let output = outputs.first(where: { $0.portType == .airPlay }) {
            return "Audio is routed to \(output.portName). Use the iPhone speaker for the most reliable alarm."
        }

        if outputs.contains(where: { $0.portType == .builtInReceiver }) {
            return "Audio is routed to the phone receiver. Switch to speaker output before sleep."
        }

        return nil
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

    private var activeFireDate: Date {
        AudioRampPlayer.shared.currentFireDate ?? alarm.nextFireDate
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
