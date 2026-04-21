import SwiftUI

@main
struct Gradual_AlarmApp: App {
    @StateObject private var store = AlarmStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
        }
    }
}
