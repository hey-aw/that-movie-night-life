import Foundation
import XCTest
import ZIPFoundation
@testable import TMNLCore

final class WatchedImportServiceTests: XCTestCase {
    func testResolveWatchedSlugsMatchesCanonicalLetterboxdURLFirst() {
        let movies = [
            fixtureMovie(number: 1, slug: "the-fan-1982", title: "The Fan", year: 1982),
            fixtureMovie(number: 2, slug: "mad-max-fury-road", title: "Mad Max: Fury Road", year: 2015),
        ]
        let csv = """
        Letterboxd URI,Name,Year
        https://letterboxd.com/film/mad-max-fury-road/,Mad Max: Fury Road,2015
        """

        let matched = WatchedImportService.resolveWatchedSlugs(csvText: csv, movies: movies)

        XCTAssertEqual(matched, ["mad-max-fury-road"])
    }

    func testResolveWatchedSlugsFallsBackToTitleAndYear() {
        let movies = [
            fixtureMovie(number: 1, slug: "the-fan-1982", title: "The Fan", year: 1982),
        ]
        let csv = """
        Name,Year
        The Fan,1982
        """

        let matched = WatchedImportService.resolveWatchedSlugs(csvText: csv, movies: movies)

        XCTAssertEqual(matched, ["the-fan-1982"])
    }

    func testImportWatchedSlugsSupportsWatchedCSVFile() throws {
        let movies = [
            fixtureMovie(number: 1, slug: "the-fan-1982", title: "The Fan", year: 1982),
        ]
        let url = try temporaryFileURL(name: "watched.csv")
        try """
        Letterboxd URI,Name,Year
        https://letterboxd.com/film/the-fan-1982/,The Fan,1982
        """.write(to: url, atomically: true, encoding: .utf8)

        let matched = try WatchedImportService.importWatchedSlugs(from: url, movies: movies)

        XCTAssertEqual(matched, ["the-fan-1982"])
    }

    func testImportWatchedSlugsSupportsZipArchive() throws {
        let movies = [
            fixtureMovie(number: 1, slug: "the-fan-1982", title: "The Fan", year: 1982),
        ]
        let zipURL = try temporaryFileURL(name: "letterboxd-export.zip")
        let archive = try Archive(url: zipURL, accessMode: .create)

        let data = Data("""
        Letterboxd URI,Name,Year
        https://letterboxd.com/film/the-fan-1982/,The Fan,1982
        """.utf8)
        try archive.addEntry(with: "watched.csv", type: .file, uncompressedSize: Int64(data.count)) { position, size in
            let start = Int(position)
            let end = start + size
            return data.subdata(in: start..<end)
        }

        let matched = try WatchedImportService.importWatchedSlugs(from: zipURL, movies: movies)

        XCTAssertEqual(matched, ["the-fan-1982"])
    }

    private func temporaryFileURL(name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
}
