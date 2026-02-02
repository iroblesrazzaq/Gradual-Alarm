import SwiftUI

@main
struct GradualAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AlarmController()

    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .environmentObject(controller)
                .fullScreenCover(isPresented: $controller.showingRinging) {
                    RingingView()
                        .environmentObject(controller)
                        .onAppear {
                            UIApplication.shared.isIdleTimerDisabled = true
                        }
                        .onDisappear {
                            UIApplication.shared.isIdleTimerDisabled = false
                        }
                }
        }
    }
}
