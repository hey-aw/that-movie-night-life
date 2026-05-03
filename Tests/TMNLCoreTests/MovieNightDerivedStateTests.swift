import XCTest
@testable import TMNLCore

final class MovieNightDerivedStateTests: XCTestCase {
    func testBuildCachesEligibleMoviesAndFeaturedMovie() {
        let catalog = [
            fixtureMovie(number: 1, slug: "safe", title: "Safe", year: 2001, rating: 4.2),
            fixtureMovie(number: 2, slug: "violent", title: "Violent", year: 2002, rating: 4.5, tags: [.violent]),
            fixtureMovie(number: 3, slug: "watched", title: "Watched", year: 2003, rating: 4.1)
        ]
        let session = MovieNightSession(
            filterSettings: MovieFilterSettings(
                excludeWatched: true,
                minimumAverageRating: .four,
                excludedBuzzKillTags: [.violent]
            ),
            watchedSlugs: ["watched"],
            dailySelection: DailySelectionState(dayKey: "2026-03-29", currentMovieNumber: 1, replayMovieNumber: 1),
            historyByDay: [:]
        )

        let state = MovieNightDerivedState.build(catalog: catalog, session: session)

        XCTAssertEqual(state.availableBuzzKillTags, [.violent])
        XCTAssertEqual(state.eligibleMovies.map(\.slug), ["safe"])
        XCTAssertEqual(state.currentMovie?.slug, "safe")
        XCTAssertEqual(state.featuredMovie?.slug, "safe")
    }

    func testBuildUsesLatestHistoryMovieWhenNoCurrentSelectionExists() {
        let catalog = [
            fixtureMovie(number: 7, slug: "older", title: "Older", year: 2000),
            fixtureMovie(number: 9, slug: "newer", title: "Newer", year: 2001)
        ]
        let session = MovieNightSession(
            filterSettings: .default,
            watchedSlugs: [],
            dailySelection: DailySelectionState(dayKey: "2026-03-30"),
            historyByDay: [
                "2026-03-29": [
                    SelectionHistoryEntry(
                        movieSlug: "older",
                        number: 7,
                        title: "Older",
                        displayName: "Older (2000)",
                        timestamp: fixtureDate("2026-03-29T06:00:00Z"),
                        skipped: false
                    )
                ],
                "2026-03-30": [
                    SelectionHistoryEntry(
                        movieSlug: "newer",
                        number: 9,
                        title: "Newer",
                        displayName: "Newer (2001)",
                        timestamp: fixtureDate("2026-03-30T07:00:00Z"),
                        skipped: false
                    )
                ]
            ]
        )

        let state = MovieNightDerivedState.build(catalog: catalog, session: session)

        XCTAssertEqual(state.historySections.map(\.dayKey), ["2026-03-30", "2026-03-29"])
        XCTAssertEqual(state.latestHistoryMovie?.slug, "newer")
        XCTAssertEqual(state.featuredMovie?.slug, "newer")
    }

    func testBuildToleratesDuplicateSlugsInCatalog() {
        let catalog = [
            fixtureMovie(number: 1, slug: "duplicate", title: "First", year: 2001),
            fixtureMovie(number: 2, slug: "duplicate", title: "Second", year: 2002)
        ]
        let session = MovieNightSession(
            filterSettings: .default,
            watchedSlugs: [],
            dailySelection: DailySelectionState(dayKey: "2026-03-30"),
            historyByDay: [
                "2026-03-30": [
                    SelectionHistoryEntry(
                        movieSlug: "duplicate",
                        number: 1,
                        title: "First",
                        displayName: "First (2001)",
                        timestamp: fixtureDate("2026-03-30T07:00:00Z"),
                        skipped: false
                    )
                ]
            ]
        )

        let state = MovieNightDerivedState.build(catalog: catalog, session: session)

        XCTAssertEqual(state.latestHistoryMovie?.number, 1)
        XCTAssertEqual(state.featuredMovie?.number, 1)
    }

    func testNarrowedCandidateCountMatchesLockedPrefix() {
        let eligibleMovies = [
            fixtureMovie(number: 12, slug: "a", title: "A", year: 2000),
            fixtureMovie(number: 123, slug: "b", title: "B", year: 2000),
            fixtureMovie(number: 129, slug: "c", title: "C", year: 2000),
            fixtureMovie(number: 98765, slug: "d", title: "D", year: 2000)
        ]

        XCTAssertEqual(
            MovieNightReelMetrics.narrowedCandidateCount(
                eligibleMovies: eligibleMovies,
                reelDigits: ["0", "0", "1", "2", "9"],
                lockedDigitCount: 0
            ),
            4
        )
        XCTAssertEqual(
            MovieNightReelMetrics.narrowedCandidateCount(
                eligibleMovies: eligibleMovies,
                reelDigits: ["0", "0", "1", "2", "9"],
                lockedDigitCount: 4
            ),
            2
        )
        XCTAssertEqual(
            MovieNightReelMetrics.narrowedCandidateCount(
                eligibleMovies: eligibleMovies,
                reelDigits: ["0", "0", "1", "2", "9"],
                lockedDigitCount: 5
            ),
            1
        )
    }

    func testBuildExposesRouletteSpinPoolFromAppealReadyBatch() {
        var session = MovieNightSession.empty
        let catalog = [
            fixtureMovie(number: 1, slug: "plain", title: "Plain", year: 2000),
            fixtureMovie(number: 2, slug: "appeal-a", title: "Appeal A", year: 2001, enrichmentStatus: .ready, whyPeopleLikeIt: fixtureAppealSummary("Appeal A summary.")),
            fixtureMovie(number: 3, slug: "appeal-b", title: "Appeal B", year: 2002, enrichmentStatus: .ready, whyPeopleLikeIt: fixtureAppealSummary("Appeal B summary."))
        ]

        session.normalizeRoulette(in: catalog, laneCount: 1, batchSize: 2)
        let state = MovieNightDerivedState.build(
            catalog: catalog,
            session: session,
            rouletteLaneCount: 1,
            rouletteBatchSize: 2
        )

        XCTAssertEqual(state.eligibleMovies.map(\.slug), ["plain", "appeal-a", "appeal-b"])
        XCTAssertEqual(state.spinPool.map(\.slug), ["appeal-a", "appeal-b"])
        XCTAssertTrue(state.spinPool.allSatisfy { $0.whyPeopleLikeIt != nil })
    }
}
