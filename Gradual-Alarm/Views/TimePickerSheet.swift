import SwiftUI

struct TimePickerSheet: View {
    @EnvironmentObject var store: AlarmStore
    @Binding var isPresented: Bool

    @State private var selection: Date

    init(isPresented: Binding<Bool>, hour: Int, minute: Int) {
        _isPresented = isPresented
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        _selection = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }

    var body: some View {
        NavigationStack {
            DatePicker("Alarm time", selection: $selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle("Set Alarm Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            let cal = Calendar.current
                            let hour = cal.component(.hour, from: selection)
                            let minute = cal.component(.minute, from: selection)
                            store.updateTime(hour: hour, minute: minute)
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                }
        }
    }
}
