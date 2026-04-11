import SwiftUI

@main
struct ThatMovieNightLifeTVApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MovieNightStore(platform: .tvOS)

    var body: some Scene {
        WindowGroup {
            MovieNightHomeView(store: store)
                .onChange(of: scenePhase) { _, newValue in
                    if newValue == .active {
                        store.sceneDidBecomeActive()
                    }
                }
        }
    }
}
