import XCTest
@testable import TMNLCore

final class MovieNightCriteriaTests: XCTestCase {
    private let movies = [
        fixtureMovie(number: 1, slug: "halloween", title: "Halloween", year: 1978, rating: 3.8, genres: ["Horror"], tags: [.violent]),
        fixtureMovie(number: 2, slug: "the-thing", title: "The Thing", year: 1982, rating: 4.2, genres: ["Horror", "Science Fiction"]),
        fixtureMovie(number: 3, slug: "gremlins", title: "Gremlins", year: 1984, rating: 3.5, genres: ["Comedy", "Horror"], tags: [.stupid]),
        fixtureMovie(number: 4, slug: "airplane", title: "Airplane!", year: 1980, rating: 3.9, genres: ["Comedy"]),
    ]

    private func session(
        watched: Set<String> = [],
        settings: MovieFilterSettings = .default
    ) -> MovieNightSession {
        MovieNightSession(
            filterSettings: settings,
            watchedSlugs: watched,
            dailySelection: DailySelectionState(dayKey: "2026-11-16"),
            historyByDay: [:]
        )
    }

    func testGenreAndDecadeNarrowTheField() {
        let criteria = MovieNightCriteria(genre: "horror", decade: 1980)

        let result = criteria.eligibleMovies(from: movies, session: session())

        XCTAssertEqual(result.map(\.slug), ["the-thing", "gremlins"])
    }

    func testDecadeAcceptsAnyYearInsideIt() {
        let criteria = MovieNightCriteria(decade: 1987)

        let result = criteria.eligibleMovies(from: movies, session: session())

        XCTAssertEqual(result.map(\.slug), ["the-thing", "gremlins", "airplane"])
    }

    func testAdditionalTagsStackOnSavedTags() {
        let saved = MovieFilterSettings(excludedBuzzKillTags: [.violent])
        let criteria = MovieNightCriteria(additionalExcludedTags: [.stupid])

        let result = criteria.eligibleMovies(from: movies, session: session(settings: saved))

        XCTAssertEqual(result.map(\.slug), ["the-thing", "airplane"])
    }

    func testMinimumRatingDropsLowerRatedFilms() {
        let criteria = MovieNightCriteria(minimumRating: 3.85)

        let result = criteria.eligibleMovies(from: movies, session: session())

        XCTAssertEqual(result.map(\.slug), ["the-thing", "airplane"])
    }

    func testIncludeWatchedOverridesSavedExclusion() {
        let watchedSession = session(watched: ["the-thing"])

        XCTAssertFalse(MovieNightCriteria.none.eligibleMovies(from: movies, session: watchedSession).map(\.slug).contains("the-thing"))
        XCTAssertTrue(MovieNightCriteria(includeWatched: true).eligibleMovies(from: movies, session: watchedSession).map(\.slug).contains("the-thing"))
    }

    func testSearchRanksExactThenPrefixThenContains() {
        let catalog = [
            fixtureMovie(number: 1, slug: "the-thing-from-another-world", title: "The Thing from Another World", year: 1951),
            fixtureMovie(number: 2, slug: "a-thing-or-two", title: "A Thing or Two", year: 2001),
            fixtureMovie(number: 3, slug: "the-thing", title: "The Thing", year: 1982),
        ]

        let result = MovieSearch.search("the thing", in: catalog)

        XCTAssertEqual(result.map(\.slug), ["the-thing", "the-thing-from-another-world"])
        XCTAssertEqual(MovieSearch.search("THING", in: catalog).count, 3)
        XCTAssertTrue(MovieSearch.search("   ", in: catalog).isEmpty)
    }
}
