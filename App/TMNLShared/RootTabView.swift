import SwiftUI

struct RootTabView: View {
    @Bindable var store: MovieNightStore

    var body: some View {
#if os(tvOS)
        MovieNightHomeView(store: store)
#else
        if #available(iOS 18.0, *) {
            modernTabView
        } else {
            legacyTabView
        }
#endif
    }

#if !os(tvOS)
    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView {
            Tab("Tonight", systemImage: "sparkles") {
                TonightTabView(store: store)
            }

            Tab("Rooms", systemImage: "person.2") {
                RoomsTabView()
            }

            Tab("Encore", systemImage: "hands.clap") {
                EncoreTabView(store: store)
            }

            Tab("Library", systemImage: "books.vertical") {
                LibraryTabView(store: store)
            }
        }
        .tint(AppTheme.Colors.accent)
        .preferredColorScheme(.dark)
        .modifier(MinimizeOnScrollModifier())
    }

    private var legacyTabView: some View {
        TabView {
            TonightTabView(store: store)
                .tabItem { Label("Tonight", systemImage: "sparkles") }

            RoomsTabView()
                .tabItem { Label("Rooms", systemImage: "person.2") }

            EncoreTabView(store: store)
                .tabItem { Label("Encore", systemImage: "hands.clap") }

            LibraryTabView(store: store)
                .tabItem { Label("Library", systemImage: "books.vertical") }
        }
        .tint(AppTheme.Colors.accent)
        .preferredColorScheme(.dark)
    }
#endif
}

private struct MinimizeOnScrollModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}
