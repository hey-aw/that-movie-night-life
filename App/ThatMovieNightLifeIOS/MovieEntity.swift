import AppIntents
import CoreSpotlight
import CoreTransferable
import Foundation

extension MovieNightStore {
    /// The single store the iOS app and its App Intents share, so Siri and the UI see the same state.
    static let iOSShared = MovieNightStore(platform: .iOS)
}

/// A film from the Random Movie Roulette list, exposed to Siri, Shortcuts, and Spotlight.
struct MovieEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Movie",
        numericFormat: "\(placeholder: .int) movies"
    )
    static let defaultQuery = MovieEntityQuery()

    /// The film's Letterboxd slug, such as `the-thing`.
    let id: String

    @Property(title: "Title", description: "The film's title, without its release year.")
    var title: String

    @Property(title: "Year", description: "The year the film was first released.")
    var year: Int?

    @Property(title: "Director", description: "The film's director.")
    var director: String?

    @Property(title: "Genres", description: "The film's genres, such as Horror, Comedy, or Science Fiction.")
    var genres: [String]

    @Property(title: "Cast", description: "Leading cast members, in billing order.")
    var cast: [String]

    @Property(
        title: "Letterboxd Rating",
        description: "The film's average rating from Letterboxd members, on a scale of 0.5 to 5.0 stars."
    )
    var letterboxdRating: Double?

    @Property(title: "Tagline", description: "The film's marketing tagline.")
    var tagline: String?

    @Property(title: "Overview", description: "A short, spoiler-light synopsis of the film's premise.")
    var overview: String?

    @Property(
        title: "Why People Like It",
        description: "A spoiler-safe, curated summary of why audiences enjoy this film. Use it to explain or pitch the film."
    )
    var whyPeopleLikeIt: String?

    @Property(
        title: "Appeal Tags",
        description: "Short tags describing what makes the film appealing, such as 'tense' or 'crowd-pleaser'."
    )
    var appealTags: [String]

    @Property(title: "Good Pick If", description: "The situation or mood where this film is a good choice.")
    var goodPickIf: String?

    @Property(title: "Maybe Skip If", description: "The situation or mood where this film may be a poor choice.")
    var maybeSkipIf: String?

    @Property(
        title: "Buzz Kills",
        description: "Content flags some viewers avoid: 'violent', 'serious' (heavy or bleak), or 'stupid' (dumb fun)."
    )
    var buzzKills: [String]

    @Property(title: "List Number", description: "The film's position on the Random Movie Roulette list.")
    var listNumber: Int

    @Property(title: "Letterboxd Page", description: "The film's page on Letterboxd, for reading reviews or logging it.")
    var letterboxdURL: URL?

    @Property(title: "Poster", description: "A link to the film's poster image.", visibility: .internal)
    var posterURL: URL?

    init(movie: Movie) {
        id = movie.slug
        title = movie.title
        year = movie.year
        director = movie.director
        genres = movie.genres
        cast = Array(movie.cast.prefix(6))
        letterboxdRating = movie.aggregateRating
        tagline = movie.tagline
        overview = movie.overview
        whyPeopleLikeIt = movie.whyPeopleLikeIt?.summary
        appealTags = movie.whyPeopleLikeIt?.appealTags ?? []
        goodPickIf = movie.whyPeopleLikeIt?.goodPickIf
        maybeSkipIf = movie.whyPeopleLikeIt?.maybeSkipIf
        buzzKills = movie.buzzKillTags.sorted().map(\.rawValue)
        listNumber = movie.number
        letterboxdURL = movie.letterboxdURLValue
        posterURL = movie.posterURLValue
    }

    var displayName: String {
        if let year { return "\(title) (\(year))" }
        return title
    }

    var subtitle: String {
        var parts: [String] = []
        if let director { parts.append(director) }
        if let genre = genres.first { parts.append(genre) }
        if let letterboxdRating { parts.append(String(format: "%.1f★", letterboxdRating)) }
        return parts.joined(separator: " · ")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: "\(subtitle)",
            image: posterURL.map { DisplayRepresentation.Image(url: $0) }
        )
    }

    /// Plain-text pitch used when the film is shared to another app.
    var shareText: String {
        var lines = [displayName]
        if let whyPeopleLikeIt { lines.append(whyPeopleLikeIt) }
        if let letterboxdURL { lines.append(letterboxdURL.absoluteString) }
        return lines.joined(separator: "\n")
    }

    var shareURL: URL {
        letterboxdURL ?? URL(string: "https://letterboxd.com/film/\(id)/")!
    }
}

// MARK: - Query

struct MovieEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [MovieEntity.ID]) async throws -> [MovieEntity] {
        let store = MovieNightStore.iOSShared
        return identifiers.compactMap(store.movie(slug:)).map(MovieEntity.init(movie:))
    }

    @MainActor
    func entities(matching string: String) async throws -> [MovieEntity] {
        MovieNightStore.iOSShared.searchMovies(string).map(MovieEntity.init(movie:))
    }

    @MainActor
    func suggestedEntities() async throws -> [MovieEntity] {
        let store = MovieNightStore.iOSShared
        var movies = store.recentPicks(limit: 10)
        if let current = store.currentMovie, !movies.contains(current) {
            movies.insert(current, at: 0)
        }
        return movies.map(MovieEntity.init(movie:))
    }
}

// MARK: - Sharing across apps

extension MovieEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
        ProxyRepresentation(exporting: \.shareURL)
    }
}

// MARK: - Spotlight

@available(iOS 18.0, *)
extension MovieEntity: IndexedEntity {}

@available(iOS 18.0, *)
enum MovieSpotlightIndexer {
    private static let indexVersionKey = "tmnl.spotlight.movieIndexVersion"
    /// Bump when `MovieEntity` gains properties that should be re-indexed.
    private static let schemaVersion = 1

    /// Indexes the bundled catalog so Siri can find films by name. Runs once per catalog/schema change.
    static func indexIfNeeded(_ catalog: [Movie], defaults: UserDefaults = .standard) async {
        guard !catalog.isEmpty else { return }
        let appealCount = catalog.lazy.filter { $0.whyPeopleLikeIt != nil }.count
        let version = "\(schemaVersion)-\(catalog.count)-\(appealCount)"
        guard defaults.string(forKey: indexVersionKey) != version else { return }

        let entities = catalog.map(MovieEntity.init(movie:))
        let index = CSSearchableIndex.default()
        do {
            for start in stride(from: 0, to: entities.count, by: 500) {
                let batch = Array(entities[start..<min(start + 500, entities.count)])
                try await index.indexAppEntities(batch)
            }
            defaults.set(version, forKey: indexVersionKey)
        } catch {
            // Indexing is best effort; the entity query still lets Siri find films.
        }
    }
}
