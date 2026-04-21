import SwiftUI

struct RampPickerSheet: View {
    @EnvironmentObject var store: AlarmStore
    @Binding var isPresented: Bool

    @State private var selection: Int

    init(isPresented: Binding<Bool>, minutes: Int) {
        _isPresented = isPresented
        _selection = State(initialValue: minutes)
    }

    var body: some View {
        NavigationStack {
            Picker("Ramp duration", selection: $selection) {
                ForEach(Alarm.rampRange, id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .navigationTitle("Ramp Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.updateRamp(selection)
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
