import SwiftUI

enum RootTab: Hashable {
    case tonight
    case rooms
    case encore
    case library
}

struct RootTabView: View {
    @Bindable var store: MovieNightStore
    @State private var selectedTab: RootTab = .tonight

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
        TabView(selection: $selectedTab) {
            Tab("Tonight", systemImage: "sparkles", value: .tonight) {
                TonightTabView(store: store)
            }

            Tab("Rooms", systemImage: "person.2", value: .rooms) {
                RoomsTabView()
            }

            Tab("Encore", systemImage: "hands.clap", value: .encore) {
                EncoreTabView(store: store, selectedTab: $selectedTab)
            }

            Tab("Library", systemImage: "books.vertical", value: .library) {
                LibraryTabView(store: store)
            }
        }
        .tint(AppTheme.Colors.accent)
        .preferredColorScheme(.dark)
        .modifier(MinimizeOnScrollModifier())
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            TonightTabView(store: store)
                .tabItem { Label("Tonight", systemImage: "sparkles") }
                .tag(RootTab.tonight)

            RoomsTabView()
                .tabItem { Label("Rooms", systemImage: "person.2") }
                .tag(RootTab.rooms)

            EncoreTabView(store: store, selectedTab: $selectedTab)
                .tabItem { Label("Encore", systemImage: "hands.clap") }
                .tag(RootTab.encore)

            LibraryTabView(store: store)
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(RootTab.library)
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
