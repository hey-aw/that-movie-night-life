import SwiftUI

@main
struct ThatMovieNightLifeMacApp: App {
    @State private var catalog: [Movie] = []
    @State private var catalogError: String?

    var body: some Scene {
        WindowGroup {
            RoomsTabView(catalog: catalog)
                .frame(minWidth: 600, minHeight: 600)
                .preferredColorScheme(.dark)
                .task {
                    do { catalog = try BundledMovieCatalog.load() }
                    catch { catalogError = error.localizedDescription }
                }
                .overlay(alignment: .bottom) {
                    if let catalogError { Text("Catalog unavailable: \(catalogError)").foregroundStyle(.red).padding() }
                }
        }
    }
}
