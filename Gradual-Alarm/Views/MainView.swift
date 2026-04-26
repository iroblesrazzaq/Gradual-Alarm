import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: AlarmStore
    @State private var showTimePicker = false
    @State private var showRampPicker = false
    @State private var showRepeatPicker = false
    @State private var showDiagnostics = false

    private var timeString: String {
        let h = store.alarm.timeHour
        let m = store.alarm.timeMinute
        let suffix = h < 12 ? "AM" : "PM"
        let displayHour = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", displayHour, m, suffix)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.volumeWarningVisible {
                    HStack {
                        Image(systemName: "speaker.slash.fill")
                        Text("Volume is low — the alarm may be quiet")
                            .font(.footnote)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.85))
                    .foregroundStyle(.black)
                }

                if let audioRouteWarningText = store.audioRouteWarningText {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text(audioRouteWarningText)
                            .font(.footnote)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.85))
                    .foregroundStyle(.black)
                }

                if store.systemAlarmWarningVisible {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Gradual audio was interrupted. The system alarm is still scheduled for the target time.")
                            .font(.footnote)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.9))
                    .foregroundStyle(.black)
                }

                List {
                    Section {
                        Button {
                            showTimePicker = true
                        } label: {
                            HStack {
                                Text("Alarm time")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(timeString)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            showRampPicker = true
                        } label: {
                            HStack {
                                Text("Ramp duration")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(store.alarm.rampMinutes) min")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            showRepeatPicker = true
                        } label: {
                            HStack {
                                Text("Repeat")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(store.alarm.repeatSummary)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Picker("Sound", selection: soundBinding) {
                            ForEach(AlarmSound.allCases) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }

                        Picker("Ramp curve", selection: rampCurveBinding) {
                            ForEach(AlarmRampCurve.allCases) { curve in
                                Text(curve.displayName).tag(curve)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Peak volume")
                                Spacer()
                                Text("\(Int(store.alarm.peakVolume * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: peakVolumeBinding, in: 0.1...1, step: 0.05)
                        }
                    } footer: {
                        Text("Volume ramp begins at \(rampStartString). A system alarm also fires at the target time if gradual audio gets interrupted. Make sure media volume is turned up before bed, and avoid starting other audio apps after arming.")
                    }

                    Section {
                        HStack {
                            Text("Next alarm")
                            Spacer()
                            Text(nextFireString)
                                .foregroundStyle(.secondary)
                        }

                        if let skippedFireDate = store.alarm.skippedFireDate {
                            HStack {
                                Text("Skipped")
                                Spacer()
                                Text(format(skippedFireDate, dateStyle: .short, timeStyle: .short))
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                store.clearSkippedOccurrence()
                            } label: {
                                Text("Restore skipped alarm")
                            }
                        } else {
                            Button {
                                store.skipNextOccurrence()
                            } label: {
                                Text("Skip next alarm")
                            }
                        }
                    }

                    Section {
                        Toggle("Nudge alarm", isOn: nudgeEnabledBinding)

                        if store.alarm.nudgeEnabled {
                            Stepper(
                                "Nudge after \(store.alarm.nudgeMinutes) min",
                                value: nudgeMinutesBinding,
                                in: Alarm.nudgeRange
                            )
                        }
                    } footer: {
                        Text("Nudge schedules a second system alarm if the first alarm is ignored.")
                    }

                    Section("Diagnostics") {
                        DisclosureGroup("Recent alarm events", isExpanded: $showDiagnostics) {
                            ForEach(diagnosticRows, id: \.label) { row in
                                HStack {
                                    Text(row.label)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(row.value)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gradual Alarm")
        }
        .onAppear { store.activate() }
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(
                isPresented: $showTimePicker,
                hour: store.alarm.timeHour,
                minute: store.alarm.timeMinute
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showRampPicker) {
            RampPickerSheet(
                isPresented: $showRampPicker,
                minutes: store.alarm.rampMinutes
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showRepeatPicker) {
            RepeatDaysPickerSheet(
                isPresented: $showRepeatPicker,
                selectedWeekdays: store.alarm.repeatWeekdays
            )
            .environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.isAlarmFiring) {
            FiringView()
                .environmentObject(store)
                .interactiveDismissDisabled()
        }
    }

    private var rampStartString: String {
        let date = store.alarm.rampStartDate
        return format(date, dateStyle: .none, timeStyle: .short)
    }

    private var nextFireString: String {
        format(store.alarm.nextFireDate, dateStyle: .medium, timeStyle: .short)
    }

    private var soundBinding: Binding<AlarmSound> {
        Binding(
            get: { store.alarm.sound },
            set: { store.updateSound($0) }
        )
    }

    private var rampCurveBinding: Binding<AlarmRampCurve> {
        Binding(
            get: { store.alarm.rampCurve },
            set: { store.updateRampCurve($0) }
        )
    }

    private var peakVolumeBinding: Binding<Double> {
        Binding(
            get: { Double(store.alarm.peakVolume) },
            set: { store.updatePeakVolume(Float($0)) }
        )
    }

    private var nudgeEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.alarm.nudgeEnabled },
            set: { store.updateNudgeEnabled($0) }
        )
    }

    private var nudgeMinutesBinding: Binding<Int> {
        Binding(
            get: { store.alarm.nudgeMinutes },
            set: { store.updateNudgeMinutes($0) }
        )
    }

    private var diagnosticRows: [(label: String, value: String)] {
        let diagnostics = store.diagnostics
        return [
            ("Last armed", format(diagnostics.lastArmedAt)),
            ("Last fire date", format(diagnostics.lastFireDate)),
            ("Ramp started", format(diagnostics.lastRampStartedAt)),
            ("Last stop", format(diagnostics.lastStopAt)),
            ("Last snooze", format(diagnostics.lastSnoozeAt)),
            ("Snoozed fire date", format(diagnostics.lastSnoozeFireDate)),
            ("System alarm scheduled", format(diagnostics.lastBackupScheduledAt)),
            ("System alarm fire date", format(diagnostics.lastBackupFireDate)),
            ("System alarm cancelled", format(diagnostics.lastBackupCancelledAt)),
            ("System alarm outcome", diagnostics.lastBackupScheduleOutcome ?? "Never"),
            ("Audio lost", format(diagnostics.lastAudioLossAt)),
            ("Interruption began", format(diagnostics.lastInterruptionBeganAt)),
            ("Interruption ended", format(diagnostics.lastInterruptionEndedAt)),
            ("Route change", format(diagnostics.lastRouteChangeAt)),
            ("Media reset", format(diagnostics.lastMediaServicesResetAt)),
            ("Recovery attempt", format(diagnostics.lastRecoveryAttemptAt)),
            ("Recovery outcome", diagnostics.lastRecoveryOutcome ?? "Never")
        ]
    }

    private func format(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return format(date, dateStyle: .short, timeStyle: .medium)
    }

    private func format(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
}
