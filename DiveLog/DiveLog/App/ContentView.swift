import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var diveStore: DiveStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GlobeContainerView()
                .tabItem { Label("Globe", systemImage: "globe") }
                .tag(0)

            DiveListView()
                .tabItem { Label("Dives", systemImage: "water.waves") }
                .tag(1)

            BuddyListView()
                .tabItem { Label("Buddies", systemImage: "person.2") }
                .tag(2)
        }
        .tint(.cyan)
        .task {
            if !healthKitService.isAuthorized {
                try? await healthKitService.requestAuthorization()
            }
        }
    }
}
