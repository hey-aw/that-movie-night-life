import SwiftUI
import UIKit

@main
struct ThatMovieNightLifeIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MovieNightStore(platform: .iOS)

    init() {
        configureNavigationTypography()
    }

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

    private func configureNavigationTypography() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.shadowColor = .clear
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: Self.serifFont(size: 34, weight: .bold)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: Self.serifFont(size: 17, weight: .semibold)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.Colors.accent)
    }

    private static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        return UIFont(descriptor: descriptor.withDesign(.serif) ?? descriptor, size: size)
    }
}
