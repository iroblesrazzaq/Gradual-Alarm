import SwiftUI

struct MainAlarmView: View {
    @EnvironmentObject private var controller: AlarmController
    @State private var showingSoundPicker = false

    private var timeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let calendar = Calendar.current
                let now = Date()
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = controller.config.hour
                components.minute = controller.config.minute
                return calendar.date(from: components) ?? now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                controller.config.hour = components.hour ?? controller.config.hour
                controller.config.minute = components.minute ?? controller.config.minute
            }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Alarm")) {
                    Toggle("Enabled", isOn: $controller.config.enabled)
                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    Stepper("Fade minutes: \(controller.config.fadeMinutes)", value: $controller.config.fadeMinutes, in: 1...60)
                }

                Section(header: Text("Sound")) {
                    HStack {
                        Text("Gentle sound")
                        Spacer()
                        Text(controller.selectedSoundName.capitalized)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingSoundPicker = true
                    }
                }

                Section(header: Text("Snooze")) {
                    Toggle("Snooze enabled", isOn: $controller.config.snoozeEnabled)
                    Stepper("Snooze minutes: \(controller.config.snoozeMinutes)", value: $controller.config.snoozeMinutes, in: 1...20)
                }

                Section {
                    Button("Save Alarm") {
                        controller.saveAndReschedule()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let next = controller.nextFire, let fadeStart = controller.fadeStart {
                    Section(header: Text("Next Alarm")) {
                        Text("Fade starts: \(fadeStart.formatted(date: .abbreviated, time: .shortened))")
                        Text("Rings at: \(next.formatted(date: .abbreviated, time: .shortened))")
                    }
                }

                Section {
                    Button("Test Ramp (15s)") {
                        let now = Date()
                        controller.config.enabled = true
                        controller.nextFire = Calendar.current.date(byAdding: .second, value: 15, to: now)
                        controller.fadeStart = now
                        controller.state = .scheduled
                        controller.startRampIfNeeded()
                    }
                }
            }
            .navigationTitle("Gradual Alarm")
            .sheet(isPresented: $showingSoundPicker) {
                SoundPickerView(selectedSound: $controller.selectedSoundName)
            }
        }
    }
}
