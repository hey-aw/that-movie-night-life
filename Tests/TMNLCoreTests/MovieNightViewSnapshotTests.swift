import XCTest
@testable import TMNLCore

final class MovieNightViewSnapshotTests: XCTestCase {
    func testBuildFilterSnapshotProducesStablePillsAndMetrics() {
        let historySections = [
            MovieNightHistorySection(
                dayKey: "2026-03-30",
                entries: [
                    SelectionHistoryEntry(
                        movieSlug: "alpha",
                        number: 12,
                        title: "Alpha",
                        displayName: "Alpha (2001)",
                        timestamp: fixtureDate("2026-03-30T07:00:00Z"),
                        skipped: false
                    ),
                    SelectionHistoryEntry(
                        movieSlug: "beta",
                        number: 13,
                        title: "Beta",
                        displayName: "Beta (2002)",
                        timestamp: fixtureDate("2026-03-30T08:00:00Z"),
                        skipped: true
                    )
                ]
            )
        ]

        let snapshot = MovieNightViewSnapshot.build(
            filterSettings: MovieFilterSettings(
                excludeWatched: true,
                minimumAverageRating: .four,
                excludedBuzzKillTags: [.violent, .serious]
            ),
            catalogCount: 10734,
            eligibleCount: 284,
            watchedCount: 901,
            historySections: historySections
        )

        XCTAssertEqual(
            snapshot.filterPills,
            [
                MovieNightFilterPill(title: "Exclude Watched", isActive: true),
                MovieNightFilterPill(title: "4.0+", isActive: true),
                MovieNightFilterPill(title: "No Serious", isActive: true),
                MovieNightFilterPill(title: "No Violent", isActive: true)
            ]
        )
        XCTAssertEqual(snapshot.historyEntryCount, 2)
        XCTAssertEqual(snapshot.catalogCount, 10734)
        XCTAssertEqual(snapshot.eligibleCount, 284)
        XCTAssertEqual(snapshot.watchedCount, 901)
    }
}
