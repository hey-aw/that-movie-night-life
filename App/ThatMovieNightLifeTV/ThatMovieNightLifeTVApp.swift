import SwiftUI

@main
struct ThatMovieNightLifeTVApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MovieNightStore(platform: .tvOS)

    var body: some Scene {
        WindowGroup {
            TabView {
                MovieNightHomeView(store: store)
                    .tabItem { Label("Tonight", systemImage: "sparkles") }
                RoomsTabView(catalog: store.catalog)
                    .tabItem { Label("Rooms", systemImage: "person.2") }
            }
            .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newValue in
                    if newValue == .active {
                        store.sceneDidBecomeActive()
                    }
                }
        }
    }
}
