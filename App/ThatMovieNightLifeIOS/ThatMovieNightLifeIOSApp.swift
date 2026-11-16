import SwiftUI

@main
struct ThatMovieNightLifeIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MovieNightStore.iOSShared

    init() {
        MovieNightStore.iOSShared.selectionObserver = { movie, source in
            MovieNightIntentDonations.donate(movie, source: source)
        }
        MovieNightShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
                .onChange(of: scenePhase) { _, newValue in
                    if newValue == .active {
                        store.sceneDidBecomeActive()
                    }
                }
                .task {
                    if #available(iOS 18.0, *) {
                        await MovieSpotlightIndexer.indexIfNeeded(store.catalog)
                    }
                }
        }
    }
}
