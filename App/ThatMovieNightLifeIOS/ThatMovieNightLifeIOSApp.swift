import SwiftUI

@main
struct ThatMovieNightLifeIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MovieNightStore(platform: .iOS)

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
                .onChange(of: scenePhase) { _, newValue in
                    if newValue == .active {
                        store.sceneDidBecomeActive()
                    }
                }
        }
    }
}
