import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: AlarmStore
    @State private var showTimePicker = false
    @State private var showRampPicker = false
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
                    } footer: {
                        Text("Volume ramp begins at \(rampStartString). Make sure media volume is turned up before bed.")
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
        .fullScreenCover(isPresented: $store.isAlarmFiring) {
            FiringView()
                .environmentObject(store)
                .interactiveDismissDisabled()
        }
    }

    private var rampStartString: String {
        let date = store.alarm.rampStartDate
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var diagnosticRows: [(label: String, value: String)] {
        let diagnostics = store.diagnostics
        return [
            ("Last armed", format(diagnostics.lastArmedAt)),
            ("Last fire date", format(diagnostics.lastFireDate)),
            ("Ramp started", format(diagnostics.lastRampStartedAt)),
            ("Last stop", format(diagnostics.lastStopAt)),
            ("Backup scheduled", format(diagnostics.lastBackupScheduledAt)),
            ("Backup fire date", format(diagnostics.lastBackupFireDate)),
            ("Backup cancelled", format(diagnostics.lastBackupCancelledAt)),
            ("Backup outcome", diagnostics.lastBackupScheduleOutcome ?? "Never"),
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
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
