import SwiftUI

struct RepeatDaysPickerSheet: View {
    @EnvironmentObject var store: AlarmStore
    @Binding var isPresented: Bool

    @State private var selection: Set<Int>

    init(isPresented: Binding<Bool>, selectedWeekdays: Set<Int>) {
        _isPresented = isPresented
        _selection = State(initialValue: selectedWeekdays.isEmpty ? Alarm.allWeekdays : selectedWeekdays)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orderedWeekdays, id: \.weekday) { item in
                        Button {
                            toggle(item.weekday)
                        } label: {
                            HStack {
                                Text(item.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selection.contains(item.weekday) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } footer: {
                    Text("At least one repeat day is required.")
                }
            }
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.updateRepeatWeekdays(selection)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private var orderedWeekdays: [(weekday: Int, name: String)] {
        let calendar = Calendar.current
        let symbols = calendar.weekdaySymbols
        let firstWeekday = calendar.firstWeekday

        return (0..<7).map { offset in
            let weekday = ((firstWeekday - 1 + offset) % 7) + 1
            return (weekday, symbols[weekday - 1])
        }
    }

    private func toggle(_ weekday: Int) {
        if selection.contains(weekday) {
            guard selection.count > 1 else { return }
            selection.remove(weekday)
        } else {
            selection.insert(weekday)
        }
    }
}
