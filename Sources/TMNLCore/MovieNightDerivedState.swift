import Foundation

public struct MovieNightHistorySection: Identifiable, Equatable, Sendable {
    public let dayKey: String
    public let entries: [SelectionHistoryEntry]

    public var id: String { dayKey }

    public init(dayKey: String, entries: [SelectionHistoryEntry]) {
        self.dayKey = dayKey
        self.entries = entries
    }
}

public struct MovieNightDerivedState: Equatable, Sendable {
    public let availableBuzzKillTags: [BuzzKillTag]
    public let eligibleMovies: [Movie]
    public let historySections: [MovieNightHistorySection]
    public let currentMovie: Movie?
    public let latestHistoryMovie: Movie?
    public let featuredMovie: Movie?

    public init(
        availableBuzzKillTags: [BuzzKillTag],
        eligibleMovies: [Movie],
        historySections: [MovieNightHistorySection],
        currentMovie: Movie?,
        latestHistoryMovie: Movie?,
        featuredMovie: Movie?
    ) {
        self.availableBuzzKillTags = availableBuzzKillTags
        self.eligibleMovies = eligibleMovies
        self.historySections = historySections
        self.currentMovie = currentMovie
        self.latestHistoryMovie = latestHistoryMovie
        self.featuredMovie = featuredMovie
    }

    public static func build(
        catalog: [Movie],
        session: MovieNightSession,
        moviesByNumber: [Int: Movie]? = nil,
        moviesBySlug: [String: Movie]? = nil
    ) -> MovieNightDerivedState {
        let resolvedMoviesByNumber = moviesByNumber ?? Dictionary(uniqueKeysWithValues: catalog.map { ($0.number, $0) })
        let resolvedMoviesBySlug = moviesBySlug ?? Dictionary(
            catalog.map { ($0.slug, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let eligibleMovies = session.eligibleMovies(from: catalog)
        let historySections = session.historyByDay.keys.sorted(by: >).map { dayKey in
            MovieNightHistorySection(dayKey: dayKey, entries: session.historyByDay[dayKey] ?? [])
        }
        let currentMovie = session.dailySelection.currentMovieNumber.flatMap { resolvedMoviesByNumber[$0] }
        let latestHistoryMovie = historySections.lazy
            .compactMap(\.entries.first)
            .compactMap { resolvedMoviesBySlug[$0.movieSlug] }
            .first
        let featuredMovie = currentMovie ?? latestHistoryMovie

        return MovieNightDerivedState(
            availableBuzzKillTags: Array(Set(catalog.flatMap(\.buzzKillTags))).sorted(),
            eligibleMovies: eligibleMovies,
            historySections: historySections,
            currentMovie: currentMovie,
            latestHistoryMovie: latestHistoryMovie,
            featuredMovie: featuredMovie
        )
    }
}

public enum MovieNightReelMetrics {
    public static func narrowedCandidateCount(
        eligibleMovies: [Movie],
        reelDigits: [String],
        lockedDigitCount: Int
    ) -> Int {
        guard lockedDigitCount > 0 else { return eligibleMovies.count }
        let prefix = reelDigits.prefix(lockedDigitCount).joined()
        return eligibleMovies.filter { String(format: "%05d", $0.number).hasPrefix(prefix) }.count
    }
}
