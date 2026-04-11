import Foundation
import XCTest
@testable import TMNLCore

final class BundledMovieAppealTests: XCTestCase {
    func testBundledCatalogMergesMovieAppealSidecarBySlug() throws {
        let bundle = try temporaryBundle(
            moviesJSON: """
            [
              {
                "number": 1,
                "slug": "alpha",
                "title": "Alpha",
                "year": 2001,
                "displayName": "Alpha (2001)",
                "letterboxdURL": "https://letterboxd.com/film/alpha/",
                "watchURL": "https://letterboxd.com/film/alpha/watch/",
                "posterURL": "https://example.com/alpha.jpg",
                "aggregateRating": 4.1,
                "ratingCount": 100,
                "genres": ["Comedy"],
                "tmdbMovieID": 1,
                "runtimeMinutes": 98,
                "certification": "PG",
                "backdropURL": null,
                "overview": "Alpha overview.",
                "tagline": null,
                "director": null,
                "cast": []
              },
              {
                "number": 2,
                "slug": "beta",
                "title": "Beta",
                "year": 2002,
                "displayName": "Beta (2002)",
                "letterboxdURL": "https://letterboxd.com/film/beta/",
                "watchURL": "https://letterboxd.com/film/beta/watch/",
                "posterURL": "https://example.com/beta.jpg",
                "aggregateRating": 3.9,
                "ratingCount": 50,
                "genres": ["Drama"],
                "tmdbMovieID": 2,
                "runtimeMinutes": 110,
                "certification": "R",
                "backdropURL": null,
                "overview": "Beta overview.",
                "tagline": null,
                "director": null,
                "cast": []
              }
            ]
            """,
            tagsJSON: """
            {
              "beta": ["serious"]
            }
            """,
            appealJSON: """
            {
              "alpha": {
                "summary": "People like this because it moves with easy confidence and keeps the room relaxed without feeling disposable.",
                "appeal_tags": ["easy chemistry", "comfort-watch energy"],
                "good_pick_if": "you want something light and charming",
                "maybe_skip_if": "you want sharper stakes",
                "confidence": "high"
              }
            }
            """
        )

        let catalog = try BundledMovieCatalog.load(bundle: bundle)

        XCTAssertEqual(catalog.count, 2)
        XCTAssertEqual(catalog[0].whyPeopleLikeIt?.summary, "People like this because it moves with easy confidence and keeps the room relaxed without feeling disposable.")
        XCTAssertEqual(catalog[0].whyPeopleLikeIt?.appealTags, ["easy chemistry", "comfort-watch energy"])
        XCTAssertEqual(catalog[0].whyPeopleLikeIt?.goodPickIf, "you want something light and charming")
        XCTAssertEqual(catalog[0].whyPeopleLikeIt?.maybeSkipIf, "you want sharper stakes")
        XCTAssertEqual(catalog[0].whyPeopleLikeIt?.confidence, .high)
        XCTAssertNil(catalog[1].whyPeopleLikeIt)
        XCTAssertEqual(catalog[1].buzzKillTags, [.serious])
    }

    func testBundledCatalogAllowsMissingMovieAppealSidecar() throws {
        let bundle = try temporaryBundle(
            moviesJSON: """
            [
              {
                "number": 1,
                "slug": "alpha",
                "title": "Alpha",
                "year": 2001,
                "displayName": "Alpha (2001)",
                "letterboxdURL": "https://letterboxd.com/film/alpha/",
                "watchURL": "https://letterboxd.com/film/alpha/watch/",
                "posterURL": "https://example.com/alpha.jpg",
                "aggregateRating": 4.1,
                "ratingCount": 100,
                "genres": ["Comedy"],
                "tmdbMovieID": 1,
                "runtimeMinutes": 98,
                "certification": "PG",
                "backdropURL": null,
                "overview": "Alpha overview.",
                "tagline": null,
                "director": null,
                "cast": []
              }
            ]
            """,
            tagsJSON: "{}",
            appealJSON: nil
        )

        let catalog = try BundledMovieCatalog.load(bundle: bundle)

        XCTAssertEqual(catalog.count, 1)
        XCTAssertNil(catalog[0].whyPeopleLikeIt)
    }

    private func temporaryBundle(
        moviesJSON: String,
        tagsJSON: String,
        appealJSON: String?
    ) throws -> Bundle {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")

        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.aw.tmnl.tests.bundle</string>
            <key>CFBundleName</key>
            <string>TMNLTests</string>
        </dict>
        </plist>
        """.write(to: bundleURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        try moviesJSON.write(to: bundleURL.appendingPathComponent("movies.catalog.json"), atomically: true, encoding: .utf8)
        try tagsJSON.write(to: bundleURL.appendingPathComponent("movie-tags.json"), atomically: true, encoding: .utf8)
        if let appealJSON {
            try appealJSON.write(to: bundleURL.appendingPathComponent("movie-appeal.json"), atomically: true, encoding: .utf8)
        }

        guard let bundle = Bundle(url: bundleURL) else {
            throw XCTSkip("Could not create temporary bundle for resource loading test.")
        }
        return bundle
    }
}
