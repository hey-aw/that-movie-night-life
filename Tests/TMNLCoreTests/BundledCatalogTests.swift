import XCTest
@testable import TMNLCore

final class BundledCatalogTests: XCTestCase {
    func testBundledCatalogLoadsAndPreservesNumbering() throws {
        let catalog = try BundledMovieCatalog.load()

        XCTAssertEqual(catalog.count, 10_734)
        XCTAssertEqual(catalog.first?.number, 1)
        XCTAssertEqual(catalog.last?.number, 10_734)
        XCTAssertEqual(catalog.map(\.number), Array(1...10_734))
    }
}
