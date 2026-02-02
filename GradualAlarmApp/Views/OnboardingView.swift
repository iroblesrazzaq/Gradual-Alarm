import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var controller: AlarmController
    @State private var finished = false

    var body: some View {
        if finished {
            MainAlarmView()
        } else {
            VStack(spacing: 24) {
                Text("Gradual Ramp Alarm")
                    .font(.largeTitle)
                Text("We will ask for notification permission to schedule alarm alerts.")
                    .multilineTextAlignment(.center)
                Button("Enable Notifications") {
                    controller.requestPermissionsIfNeeded()
                    finished = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
