import AlarmKit
import ActivityKit
import AppIntents
import Foundation
import SwiftUI

private struct BackupAlarmMetadata: AlarmMetadata {}

private struct BackupAlarmState: Codable {
    var alarmID: UUID
    var primaryFireDate: Date
    var backupFireDate: Date
    var rampMinutesOverride: Int?
    var nudgeAlarmID: UUID?
    var nudgeFireDate: Date?
}

private enum BackupAlarmStateStore {
    private static let key = "alarm.backup.state.v1"

    static func load() -> BackupAlarmState? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(BackupAlarmState.self, from: data) else {
            return nil
        }
        return state
    }

    static func save(_ state: BackupAlarmState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class BackupAlarmManager {
    static let shared = BackupAlarmManager()
    static let systemAlarmOffset: TimeInterval = 0

    private let alarmManager = AlarmManager.shared
    private var scheduleTask: Task<Void, Never>?

    var trackedBackupID: UUID? { BackupAlarmStateStore.load()?.alarmID }
    var trackedBackupFireDate: Date? { BackupAlarmStateStore.load()?.backupFireDate }
    var trackedPrimaryFireDate: Date? { BackupAlarmStateStore.load()?.primaryFireDate }
    var trackedRampMinutesOverride: Int? { BackupAlarmStateStore.load()?.rampMinutesOverride }
    var authorizationState: AlarmManager.AuthorizationState { alarmManager.authorizationState }

    func prepareBackupAlarm(for alarm: Alarm, after primaryFireDate: Date, rampMinutesOverride: Int? = nil) {
        schedule(alarm: alarm, primaryFireDate: primaryFireDate, rampMinutesOverride: rampMinutesOverride, requestAuthorizationIfNeeded: true)
    }

    func scheduleBackupIfAuthorized(for alarm: Alarm, after primaryFireDate: Date, rampMinutesOverride: Int? = nil) {
        schedule(alarm: alarm, primaryFireDate: primaryFireDate, rampMinutesOverride: rampMinutesOverride, requestAuthorizationIfNeeded: false)
    }

    func cancelBackup() {
        scheduleTask?.cancel()
        scheduleTask = nil

        guard let state = BackupAlarmStateStore.load() else { return }

        let alarmIDs = [state.alarmID, state.nudgeAlarmID].compactMap { $0 }
        do {
            for alarmID in alarmIDs {
                try alarmManager.cancel(id: alarmID)
            }
        } catch {
            print("BackupAlarmManager: failed to cancel backup alarm: \(error.localizedDescription)")
        }

        BackupAlarmStateStore.clear()
        _ = AlarmDiagnosticsStore.update { diagnostics in
            diagnostics.lastBackupCancelledAt = Date()
        }
    }

    func currentPrimaryFireDate(for alarmIDString: String) -> Date? {
        guard let alarmID = UUID(uuidString: alarmIDString),
              let state = BackupAlarmStateStore.load(),
              state.alarmID == alarmID || state.nudgeAlarmID == alarmID else {
            return nil
        }

        return state.primaryFireDate
    }

    func handleStopIntent(for alarmIDString: String) async {
        let alarm = Alarm.load()
        let primaryFireDate = currentPrimaryFireDate(for: alarmIDString) ?? alarm.nextFireDate
        AlarmOccurrenceScheduler.skipCurrentOccurrence(using: alarm, currentFireDate: primaryFireDate, recordStop: true)
    }

    func handleSnoozeIntent(for alarmIDString: String) async {
        if let alarmID = UUID(uuidString: alarmIDString) {
            do {
                try alarmManager.stop(id: alarmID)
            } catch {
                print("BackupAlarmManager: failed to stop backup alarm before snooze: \(error.localizedDescription)")
            }
        }

        AlarmOccurrenceScheduler.snoozeCurrentOccurrence(using: Alarm.load())
    }

    private func schedule(alarm: Alarm, primaryFireDate: Date, rampMinutesOverride: Int?, requestAuthorizationIfNeeded: Bool) {
        let backupFireDate = primaryFireDate.addingTimeInterval(Self.systemAlarmOffset)
        let nudgeFireDate = alarm.nudgeFireDate(for: primaryFireDate)

        if let state = BackupAlarmStateStore.load(),
           state.backupFireDate == backupFireDate,
           state.nudgeFireDate == nudgeFireDate,
           state.rampMinutesOverride == rampMinutesOverride {
            recordScheduleOutcome("already_scheduled")
            return
        }

        scheduleTask?.cancel()
        scheduleTask = Task { [weak self] in
            await self?.performSchedule(
                alarm: alarm,
                primaryFireDate: primaryFireDate,
                backupFireDate: backupFireDate,
                nudgeFireDate: nudgeFireDate,
                rampMinutesOverride: rampMinutesOverride,
                requestAuthorizationIfNeeded: requestAuthorizationIfNeeded
            )
        }
    }

    private func performSchedule(
        alarm: Alarm,
        primaryFireDate: Date,
        backupFireDate: Date,
        nudgeFireDate: Date?,
        rampMinutesOverride: Int?,
        requestAuthorizationIfNeeded: Bool
    ) async {
        guard backupFireDate > Date() else {
            recordScheduleOutcome("backup_fire_date_in_past")
            return
        }

        let authorizationState: AlarmManager.AuthorizationState
        do {
            authorizationState = try await resolveAuthorization(requestIfNeeded: requestAuthorizationIfNeeded)
        } catch {
            print("BackupAlarmManager: failed to resolve authorization: \(error.localizedDescription)")
            recordScheduleOutcome("authorization_request_failed")
            return
        }

        guard !Task.isCancelled else { return }

        guard authorizationState == .authorized else {
            recordScheduleOutcome("authorization_denied")
            return
        }

        if let existingState = BackupAlarmStateStore.load() {
            do {
                try alarmManager.cancel(id: existingState.alarmID)
            } catch {
                print("BackupAlarmManager: failed to cancel previous backup alarm: \(error.localizedDescription)")
            }
            BackupAlarmStateStore.clear()
        }

        let alarmID = UUID()
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(backupFireDate),
            attributes: makeAttributes(title: "Wake up"),
            stopIntent: StopBackupAlarmIntent(alarmID: alarmID.uuidString),
            secondaryIntent: SnoozeBackupAlarmIntent(alarmID: alarmID.uuidString),
            sound: .default
        )

        do {
            _ = try await alarmManager.schedule(id: alarmID, configuration: configuration)
            guard !Task.isCancelled else { return }

            let nudgeAlarmID = await scheduleNudgeIfNeeded(
                for: alarm,
                nudgeFireDate: nudgeFireDate
            )
            guard !Task.isCancelled else { return }

            BackupAlarmStateStore.save(
                BackupAlarmState(
                    alarmID: alarmID,
                    primaryFireDate: primaryFireDate,
                    backupFireDate: backupFireDate,
                    rampMinutesOverride: rampMinutesOverride,
                    nudgeAlarmID: nudgeAlarmID,
                    nudgeFireDate: nudgeFireDate
                )
            )
            _ = AlarmDiagnosticsStore.update { diagnostics in
                diagnostics.lastBackupScheduledAt = Date()
                diagnostics.lastBackupFireDate = backupFireDate
                diagnostics.lastFireDate = primaryFireDate
                diagnostics.lastBackupScheduleOutcome = alarm.nudgeEnabled && nudgeAlarmID == nil ? "scheduled_without_nudge" : "scheduled"
            }
        } catch {
            print("BackupAlarmManager: failed to schedule backup alarm: \(error.localizedDescription)")
            recordScheduleOutcome("schedule_failed")
        }
    }

    private func scheduleNudgeIfNeeded(for alarm: Alarm, nudgeFireDate: Date?) async -> UUID? {
        guard alarm.nudgeEnabled, let nudgeFireDate, nudgeFireDate > Date() else {
            return nil
        }

        let nudgeAlarmID = UUID()
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(nudgeFireDate),
            attributes: makeAttributes(title: "Nudge alarm"),
            stopIntent: StopBackupAlarmIntent(alarmID: nudgeAlarmID.uuidString),
            secondaryIntent: SnoozeBackupAlarmIntent(alarmID: nudgeAlarmID.uuidString),
            sound: .default
        )

        do {
            _ = try await alarmManager.schedule(id: nudgeAlarmID, configuration: configuration)
            return nudgeAlarmID
        } catch {
            print("BackupAlarmManager: failed to schedule nudge alarm: \(error.localizedDescription)")
            recordScheduleOutcome("nudge_schedule_failed")
            return nil
        }
    }

    private func resolveAuthorization(requestIfNeeded: Bool) async throws -> AlarmManager.AuthorizationState {
        switch alarmManager.authorizationState {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            guard requestIfNeeded else { return .notDetermined }
            return try await alarmManager.requestAuthorization()
        @unknown default:
            return .denied
        }
    }

    private func makeAttributes(title: LocalizedStringResource) -> AlarmAttributes<BackupAlarmMetadata> {
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: title,
                secondaryButton: AlarmButton(
                    text: "Snooze",
                    textColor: .blue,
                    systemImageName: "zzz"
                ),
                secondaryButtonBehavior: .custom
            )
        )

        return AlarmAttributes(
            presentation: presentation,
            metadata: BackupAlarmMetadata(),
            tintColor: .blue
        )
    }

    private func recordScheduleOutcome(_ outcome: String) {
        _ = AlarmDiagnosticsStore.update { diagnostics in
            diagnostics.lastBackupScheduleOutcome = outcome
        }
    }
}
