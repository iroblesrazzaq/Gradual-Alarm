import SwiftUI

struct RingingView: View {
    @EnvironmentObject private var controller: AlarmController

    var body: some View {
        VStack(spacing: 32) {
            Text(Date().formatted(date: .omitted, time: .shortened))
                .font(.system(size: 64, weight: .bold))
            Text(controller.state == .escalating ? "Wake Up!" : "Alarm Ringing")
                .font(.title2)
            HStack(spacing: 20) {
                Button("Dismiss") {
                    controller.dismiss()
                }
                .buttonStyle(.borderedProminent)

                if controller.config.snoozeEnabled {
                    Button("Snooze") {
                        controller.snooze()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
        .foregroundColor(.white)
    }
}
