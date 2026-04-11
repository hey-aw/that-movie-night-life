import XCTest
@testable import TMNLCore

final class MovieAppealSummaryTests: XCTestCase {
    func testPresentationIsSummaryOnlyWhenOnlySummaryExists() {
        let appeal = MovieAppealSummary(
            summary: "People call this \"easy to sink into,\" which is most of the pitch."
        )

        XCTAssertEqual(appeal.presentation, .summaryOnly)
        XCTAssertFalse(appeal.isExpandable)
        XCTAssertEqual(appeal.collapsedAppealTags, [])
    }

    func testPresentationIsFullWhenTagsOrGuidanceExist() {
        let appeal = MovieAppealSummary(
            summary: "People call this \"easy to sink into,\" which is most of the pitch.",
            appealTags: ["easy chemistry", "comfort-watch energy"],
            goodPickIf: "you want something light and warm"
        )

        XCTAssertEqual(appeal.presentation, .full)
        XCTAssertTrue(appeal.isExpandable)
        XCTAssertEqual(appeal.collapsedAppealTags, ["easy chemistry", "comfort-watch energy"])
    }
}
