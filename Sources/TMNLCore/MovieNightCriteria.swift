import Foundation

/// One-off filters layered on top of a person's saved `MovieFilterSettings`.
///
/// Used by Siri and Shortcuts requests such as "draw an 80s horror movie, nothing too
/// violent" without changing the filters saved in the app.
public struct MovieNightCriteria: Equatable, Sendable {
    /// Genre name as it appears in the catalog, such as "Horror" or "Science Fiction".
    public var genre: String?
    /// First year of a decade, such as 1980 for the 1980s.
    public var decade: Int?
    /// Lowest acceptable average Letterboxd rating, from 0.5 to 5.0.
    public var minimumRating: Double?
    /// Buzz-kill tags to skip in addition to the saved ones.
    public var additionalExcludedTags: Set<BuzzKillTag>
    /// When true, already-watched films can be drawn even if the saved filters exclude them.
    public var includeWatched: Bool

    public init(
        genre: String? = nil,
        decade: Int? = nil,
        minimumRating: Double? = nil,
        additionalExcludedTags: Set<BuzzKillTag> = [],
        includeWatched: Bool = false
    ) {
        self.genre = genre
        self.decade = decade
        self.minimumRating = minimumRating
        self.additionalExcludedTags = additionalExcludedTags
        self.includeWatched = includeWatched
    }

    public static let none = MovieNightCriteria()

    public func eligibleMovies(from catalog: [Movie], session: MovieNightSession) -> [Movie] {
        var settings = session.filterSettings
        settings.excludedBuzzKillTags.formUnion(additionalExcludedTags)
        if includeWatched {
            settings.excludeWatched = false
        }

        let normalizedGenre = genre?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let decadeStart = decade.map { ($0 / 10) * 10 }

        return MovieFilterEngine.eligibleMovies(
            from: catalog,
            watchedSlugs: session.watchedSlugs,
            settings: settings
        ).filter { movie in
            if let normalizedGenre, !normalizedGenre.isEmpty,
               !movie.genres.contains(where: { $0.lowercased() == normalizedGenre }) {
                return false
            }
            if let decadeStart {
                guard let year = movie.year, (decadeStart..<(decadeStart + 10)).contains(year) else {
                    return false
                }
            }
            if let minimumRating {
                guard let rating = movie.aggregateRating, rating >= minimumRating else {
                    return false
                }
            }
            return true
        }
    }
}

/// Simple ranked title, director, and cast search over the bundled catalog.
public enum MovieSearch {
    public static func search(_ query: String, in movies: [Movie], limit: Int = 25) -> [Movie] {
        let needle = normalize(query)
        guard !needle.isEmpty, limit > 0 else { return [] }

        var scored: [(score: Int, movie: Movie)] = []
        for movie in movies {
            let title = normalize(movie.title)
            let displayName = normalize(movie.displayName)
            let score: Int
            if title == needle || displayName == needle {
                score = 0
            } else if title.hasPrefix(needle) {
                score = 1
            } else if title.contains(needle) {
                score = 2
            } else if let director = movie.director, normalize(director).contains(needle) {
                score = 3
            } else if movie.cast.contains(where: { normalize($0).contains(needle) }) {
                score = 4
            } else {
                continue
            }
            scored.append((score, movie))
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                let lhsCount = lhs.movie.ratingCount ?? 0
                let rhsCount = rhs.movie.ratingCount ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.movie.number < rhs.movie.number
            }
            .prefix(limit)
            .map(\.movie)
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
