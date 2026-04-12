import XCTest
@testable import TMNLCore

final class MovieNightSessionTests: XCTestCase {
    func testNormalizeResetsCurrentSelectionForNewDay() {
        var session = MovieNightSession(
            filterSettings: .default,
            watchedSlugs: [],
            dailySelection: DailySelectionState(
                dayKey: "2026-03-28",
                currentMovieNumber: 1,
                replayMovieNumber: 1
            ),
            historyByDay: [:]
        )

        session.normalize(on: fixtureDate("2026-03-29T08:00:00Z"), calendar: .utcFixture)

        XCTAssertEqual(session.dailySelection.dayKey, "2026-03-29")
        XCTAssertNil(session.dailySelection.currentMovieNumber)
        XCTAssertNil(session.dailySelection.replayMovieNumber)
    }

    func testRecordSelectionAppendsCurrentDayHistoryAndSetsReplayMovie() {
        var session = MovieNightSession.empty
        let movie = fixtureMovie(number: 1, slug: "the-fan-1982", title: "The Fan", year: 1982)
        let date = fixtureDate("2026-03-29T08:00:00Z")

        session.recordSelection(movie, at: date, calendar: .utcFixture)

        XCTAssertEqual(session.dailySelection.currentMovieNumber, 1)
        XCTAssertEqual(session.dailySelection.replayMovieNumber, 1)
        XCTAssertEqual(session.historyByDay["2026-03-29"]?.count, 1)
        XCTAssertEqual(session.historyByDay["2026-03-29"]?.first?.movieSlug, "the-fan-1982")
    }

    func testReplayMovieDoesNotMutateState() {
        var session = MovieNightSession.empty
        let movie = fixtureMovie(number: 1, slug: "the-fan-1982", title: "The Fan", year: 1982)
        let date = fixtureDate("2026-03-29T08:00:00Z")
        session.recordSelection(movie, at: date, calendar: .utcFixture)

        let before = session
        let replayMovie = session.replayMovie(in: [movie])

        XCTAssertEqual(replayMovie?.slug, "the-fan-1982")
        XCTAssertEqual(session, before)
    }

    func testNormalizeRouletteClaimsLaneBatchFromPublishedAppealTitles() {
        var session = MovieNightSession.empty
        let catalog = [
            fixtureMovie(number: 1, slug: "alpha", title: "Alpha", year: 2001, enrichmentStatus: .ready, whyPeopleLikeIt: fixtureAppealSummary("Alpha appeal.")),
            fixtureMovie(number: 2, slug: "beta", title: "Beta", year: 2002, enrichmentStatus: .ready, whyPeopleLikeIt: fixtureAppealSummary("Beta appeal.")),
            fixtureMovie(number: 3, slug: "gamma", title: "Gamma", year: 2003)
        ]

        session.normalizeRoulette(in: catalog, laneCount: 1, batchSize: 2)

        XCTAssertEqual(session.rouletteState?.laneID, "lane-001")
        XCTAssertEqual(session.rouletteState?.batchIndex, 0)
        XCTAssertEqual(
            session.spinPool(in: catalog, laneCount: 1, batchSize: 2).map(\.slug),
            ["alpha", "beta"]
        )
    }

    func testAdvanceRouletteMovesToNextBatchAfterCurrentBatchIsConsumed() {
        var session = MovieNightSession.empty
        let catalog = [
            fixtureMovie(number: 1, slug: "alpha", title: "Alpha", year: 2001, enrichmentStatus: .ready, whyPeopleLikeIt: fixtureAppealSummary("Alpha appeal.")),
            fixtureMovie(number: 2, slug: "beta", title: "Beta", year: 2002, enrichmentStatus: .ready, whyPeopleLikeIt: fixtureAppealSummary("Beta appeal.")),
            fixtureMovie(number: 3, slug: "gamma", title: "Gamma", year: 2003, enrichmentStatus: .ready, whyPeopleLikeIt: fixtureAppealSummary("Gamma appeal."))
        ]

        session.normalizeRoulette(in: catalog, laneCount: 1, batchSize: 2)
        session.advanceRoulette(afterSelecting: catalog[0], in: catalog, laneCount: 1, batchSize: 2)

        XCTAssertEqual(
            session.spinPool(in: catalog, laneCount: 1, batchSize: 2).map(\.slug),
            ["beta"]
        )

        session.advanceRoulette(afterSelecting: catalog[1], in: catalog, laneCount: 1, batchSize: 2)

        XCTAssertEqual(session.rouletteState?.batchIndex, 1)
        XCTAssertEqual(
            session.spinPool(in: catalog, laneCount: 1, batchSize: 2).map(\.slug),
            ["gamma"]
        )
    }
}

private extension Calendar {
    static var utcFixture: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
