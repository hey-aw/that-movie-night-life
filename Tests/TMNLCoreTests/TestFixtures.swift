import Foundation
@testable import TMNLCore

func fixtureMovie(
    number: Int,
    slug: String,
    title: String,
    year: Int,
    rating: Double? = nil,
    genres: [String] = [],
    tags: Set<BuzzKillTag> = []
) -> Movie {
    Movie(
        number: number,
        slug: slug,
        title: title,
        year: year,
        displayName: "\(title) (\(year))",
        letterboxdURL: "https://letterboxd.com/film/\(slug)/",
        watchURL: "https://letterboxd.com/film/\(slug)/watch/",
        posterURL: "https://example.com/\(slug).jpg",
        aggregateRating: rating,
        ratingCount: rating == nil ? nil : 100,
        genres: genres,
        tmdbMovieID: number,
        runtimeMinutes: 100,
        certification: nil,
        backdropURL: nil,
        buzzKillTags: tags
    )
}

func fixtureDate(_ isoDateTime: String) -> Date {
    ISO8601DateFormatter().date(from: isoDateTime)!
}
