import SwiftUI

@main
struct Gradual_AlarmApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = AlarmStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, newPhase in
                    store.handleScenePhase(newPhase)
                }
        }
    }
}
