import Foundation

public enum MinimumAverageRating: String, Codable, CaseIterable, Hashable, Sendable {
    case none
    case three
    case four

    public var threshold: Double? {
        switch self {
        case .none:
            nil
        case .three:
            3.0
        case .four:
            4.0
        }
    }

    public var title: String {
        switch self {
        case .none:
            "Any Rating"
        case .three:
            "3.0+"
        case .four:
            "4.0+"
        }
    }
}

public struct MovieFilterSettings: Codable, Equatable, Sendable {
    public var excludeWatched: Bool
    public var minimumAverageRating: MinimumAverageRating
    public var excludedBuzzKillTags: Set<BuzzKillTag>

    public init(
        excludeWatched: Bool = true,
        minimumAverageRating: MinimumAverageRating = .none,
        excludedBuzzKillTags: Set<BuzzKillTag> = []
    ) {
        self.excludeWatched = excludeWatched
        self.minimumAverageRating = minimumAverageRating
        self.excludedBuzzKillTags = excludedBuzzKillTags
    }

    public static let `default` = MovieFilterSettings()
}

public enum MovieFilterEngine {
    public static func eligibleMovies(
        from movies: [Movie],
        watchedSlugs: Set<String>,
        settings: MovieFilterSettings
    ) -> [Movie] {
        movies.filter { movie in
            if settings.excludeWatched && watchedSlugs.contains(movie.slug) {
                return false
            }

            if let threshold = settings.minimumAverageRating.threshold {
                guard let aggregateRating = movie.aggregateRating, aggregateRating >= threshold else {
                    return false
                }
            }

            if !settings.excludedBuzzKillTags.isDisjoint(with: movie.buzzKillTags) {
                return false
            }

            return true
        }
    }
}
