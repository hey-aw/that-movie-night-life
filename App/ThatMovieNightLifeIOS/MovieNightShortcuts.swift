import AppIntents

struct MovieNightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DrawTonightsMovieIntent(),
            phrases: [
                "Draw a movie in \(.applicationName)",
                "Spin the reel in \(.applicationName)",
                "Pick tonight's movie with \(.applicationName)",
            ],
            shortTitle: "Draw Tonight's Movie",
            systemImageName: "film.stack"
        )
        AppShortcut(
            intent: GetTonightsMovieIntent(),
            phrases: [
                "What's tonight's movie in \(.applicationName)",
                "What are we watching in \(.applicationName)",
            ],
            shortTitle: "Tonight's Movie",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: ShortlistMoviesIntent(),
            phrases: [
                "Shortlist movies in \(.applicationName)",
                "Give me movie options in \(.applicationName)",
            ],
            shortTitle: "Shortlist Movies",
            systemImageName: "list.star"
        )
        AppShortcut(
            intent: ExplainWhyPeopleLikeItIntent(),
            phrases: [
                "Why do people like tonight's movie in \(.applicationName)",
                "Pitch tonight's movie in \(.applicationName)",
            ],
            shortTitle: "Why People Like It",
            systemImageName: "heart.text.square"
        )
    }
}
