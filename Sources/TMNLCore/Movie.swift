import Foundation

public struct BuzzKillTag: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral, Comparable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    public static let violent = BuzzKillTag(rawValue: "violent")
    public static let serious = BuzzKillTag(rawValue: "serious")
    public static let stupid = BuzzKillTag(rawValue: "stupid")

    public static func < (lhs: BuzzKillTag, rhs: BuzzKillTag) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct Movie: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let number: Int
    public let slug: String
    public let title: String
    public let year: Int?
    public let displayName: String
    public let letterboxdURL: String
    public let watchURL: String
    public let posterURL: String?
    public let aggregateRating: Double?
    public let ratingCount: Int?
    public let genres: [String]
    public let tmdbMovieID: Int?
    public let runtimeMinutes: Int?
    public let certification: String?
    public let backdropURL: String?
    public let overview: String?
    public let tagline: String?
    public let director: String?
    public let cast: [String]
    public let buzzKillTags: Set<BuzzKillTag>
    public let whyPeopleLikeIt: MovieAppealSummary?

    public var id: Int { number }

    public init(
        number: Int,
        slug: String,
        title: String,
        year: Int?,
        displayName: String,
        letterboxdURL: String,
        watchURL: String,
        posterURL: String?,
        aggregateRating: Double?,
        ratingCount: Int?,
        genres: [String],
        tmdbMovieID: Int?,
        runtimeMinutes: Int?,
        certification: String?,
        backdropURL: String?,
        overview: String? = nil,
        tagline: String? = nil,
        director: String? = nil,
        cast: [String] = [],
        buzzKillTags: Set<BuzzKillTag> = [],
        whyPeopleLikeIt: MovieAppealSummary? = nil
    ) {
        self.number = number
        self.slug = slug
        self.title = title
        self.year = year
        self.displayName = displayName
        self.letterboxdURL = letterboxdURL
        self.watchURL = watchURL
        self.posterURL = posterURL
        self.aggregateRating = aggregateRating
        self.ratingCount = ratingCount
        self.genres = genres
        self.tmdbMovieID = tmdbMovieID
        self.runtimeMinutes = runtimeMinutes
        self.certification = certification
        self.backdropURL = backdropURL
        self.overview = overview
        self.tagline = tagline
        self.director = director
        self.cast = cast
        self.buzzKillTags = buzzKillTags
        self.whyPeopleLikeIt = whyPeopleLikeIt
    }

    public var letterboxdURLValue: URL? {
        URL(string: letterboxdURL)
    }

    public var watchURLValue: URL? {
        URL(string: watchURL)
    }

    public var letterboxdReviewURLValue: URL? {
        validatedWebURL(from: watchURL) ?? validatedWebURL(from: letterboxdURL)
    }

    public var posterURLValue: URL? {
        guard let posterURL else { return nil }
        return URL(string: posterURL)
    }

    public var appleTVSearchURL: URL? {
        var components = URLComponents(string: "https://tv.apple.com/search")
        let query = [title, year.map(String.init)].compactMap { $0 }.joined(separator: " ")
        components?.queryItems = [
            URLQueryItem(name: "term", value: query)
        ]
        return components?.url
    }
}

private func validatedWebURL(from value: String) -> URL? {
    guard
        let components = URLComponents(string: value),
        let scheme = components.scheme?.lowercased(),
        scheme == "http" || scheme == "https",
        components.host?.isEmpty == false
    else {
        return nil
    }

    return components.url
}
