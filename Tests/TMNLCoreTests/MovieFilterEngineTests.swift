import XCTest
@testable import TMNLCore

final class MovieFilterEngineTests: XCTestCase {
    func testExcludeWatchedRemovesWatchedMovies() {
        let movies = [
            fixtureMovie(number: 1, slug: "the-fan-1982", title: "The Fan", year: 1982),
            fixtureMovie(number: 2, slug: "mad-max-fury-road", title: "Mad Max: Fury Road", year: 2015),
        ]
        let settings = MovieFilterSettings(excludeWatched: true)

        let filtered = MovieFilterEngine.eligibleMovies(
            from: movies,
            watchedSlugs: ["mad-max-fury-road"],
            settings: settings
        )

        XCTAssertEqual(filtered.map(\.slug), ["the-fan-1982"])
    }

    func testThreeStarThresholdExcludesLowerAndUnknownRatings() {
        let movies = [
            fixtureMovie(number: 1, slug: "a", title: "A", year: 2000, rating: 2.9),
            fixtureMovie(number: 2, slug: "b", title: "B", year: 2000, rating: 3.0),
            fixtureMovie(number: 3, slug: "c", title: "C", year: 2000, rating: nil),
        ]
        let settings = MovieFilterSettings(minimumAverageRating: .three)

        let filtered = MovieFilterEngine.eligibleMovies(from: movies, watchedSlugs: [], settings: settings)

        XCTAssertEqual(filtered.map(\.slug), ["b"])
    }

    func testFourStarThresholdKeepsOnlyFourAndUp() {
        let movies = [
            fixtureMovie(number: 1, slug: "a", title: "A", year: 2000, rating: 3.8),
            fixtureMovie(number: 2, slug: "b", title: "B", year: 2000, rating: 4.0),
            fixtureMovie(number: 3, slug: "c", title: "C", year: 2000, rating: 4.4),
        ]
        let settings = MovieFilterSettings(minimumAverageRating: .four)

        let filtered = MovieFilterEngine.eligibleMovies(from: movies, watchedSlugs: [], settings: settings)

        XCTAssertEqual(filtered.map(\.slug), ["b", "c"])
    }

    func testBuzzKillTagsAreExcluded() {
        let movies = [
            fixtureMovie(number: 1, slug: "safe", title: "Safe", year: 2001),
            fixtureMovie(number: 2, slug: "violent", title: "Violent", year: 2002, tags: [.violent]),
        ]
        let settings = MovieFilterSettings(excludedBuzzKillTags: [.violent])

        let filtered = MovieFilterEngine.eligibleMovies(from: movies, watchedSlugs: [], settings: settings)

        XCTAssertEqual(filtered.map(\.slug), ["safe"])
    }

    func testCombinedFiltersCanReducePoolToZero() {
        let movies = [
            fixtureMovie(number: 1, slug: "a", title: "A", year: 2000, rating: 4.1, tags: [.violent]),
            fixtureMovie(number: 2, slug: "b", title: "B", year: 2000, rating: 2.5),
        ]
        let settings = MovieFilterSettings(
            excludeWatched: true,
            minimumAverageRating: .four,
            excludedBuzzKillTags: [.violent]
        )

        let filtered = MovieFilterEngine.eligibleMovies(from: movies, watchedSlugs: ["b"], settings: settings)

        XCTAssertTrue(filtered.isEmpty)
    }

    func testSingleResultPoolIsPreserved() {
        let movies = [
            fixtureMovie(number: 1, slug: "a", title: "A", year: 2000, rating: 4.1),
            fixtureMovie(number: 2, slug: "b", title: "B", year: 2000, rating: 2.1),
        ]
        let settings = MovieFilterSettings(minimumAverageRating: .four)

        let filtered = MovieFilterEngine.eligibleMovies(from: movies, watchedSlugs: [], settings: settings)

        XCTAssertEqual(filtered.map(\.slug), ["a"])
    }
}
