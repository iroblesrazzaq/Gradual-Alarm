import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: AlarmStore
    @State private var showTimePicker = false
    @State private var showRampPicker = false

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
}
