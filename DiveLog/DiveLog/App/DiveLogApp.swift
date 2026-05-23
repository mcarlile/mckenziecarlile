import SwiftUI

@main
struct DiveLogApp: App {
    @StateObject private var healthKitService = HealthKitService()
    @StateObject private var diveStore = DiveStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitService)
                .environmentObject(diveStore)
                .preferredColorScheme(.dark)
        }
    }
}
