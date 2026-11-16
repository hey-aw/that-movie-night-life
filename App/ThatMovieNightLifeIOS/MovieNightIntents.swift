import AppIntents
import Foundation

// App Intents for That Movie Night Life.
//
// Every intent works in Shortcuts and App Shortcuts from iOS 17. The `@AppIntent(.tool)`
// macro (Siri AI Developer Preview) additionally lets Siri call each one as a tool on
// iOS 27.3+; the macro adopts `ToolIntent`'s availability, so no `#available` is needed here.

// MARK: - Enums

enum GenreOption: String, AppEnum {
    case action = "Action"
    case adventure = "Adventure"
    case animation = "Animation"
    case comedy = "Comedy"
    case crime = "Crime"
    case documentary = "Documentary"
    case drama = "Drama"
    case family = "Family"
    case fantasy = "Fantasy"
    case history = "History"
    case horror = "Horror"
    case music = "Music"
    case mystery = "Mystery"
    case romance = "Romance"
    case scienceFiction = "Science Fiction"
    case thriller = "Thriller"
    case tvMovie = "TV Movie"
    case war = "War"
    case western = "Western"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Genre"
    static let caseDisplayRepresentations: [GenreOption: DisplayRepresentation] = [
        .action: "Action",
        .adventure: "Adventure",
        .animation: "Animation",
        .comedy: "Comedy",
        .crime: "Crime",
        .documentary: "Documentary",
        .drama: "Drama",
        .family: "Family",
        .fantasy: "Fantasy",
        .history: "History",
        .horror: "Horror",
        .music: "Music",
        .mystery: "Mystery",
        .romance: "Romance",
        .scienceFiction: DisplayRepresentation(title: "Science Fiction", synonyms: ["Sci-Fi", "SF"]),
        .thriller: "Thriller",
        .tvMovie: "TV Movie",
        .war: "War",
        .western: "Western",
    ]
}

enum BuzzKillOption: String, AppEnum {
    case violent
    case serious
    case stupid

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Buzz Kill",
        numericFormat: "\(placeholder: .int) buzz kills"
    )
    static let caseDisplayRepresentations: [BuzzKillOption: DisplayRepresentation] = [
        .violent: DisplayRepresentation(
            title: "Violent",
            subtitle: "Gore, brutality, or intense violence",
            synonyms: ["Gory", "Bloody", "Brutal"]
        ),
        .serious: DisplayRepresentation(
            title: "Serious",
            subtitle: "Heavy, bleak, or emotionally draining",
            synonyms: ["Heavy", "Depressing", "Bleak", "Sad"]
        ),
        .stupid: DisplayRepresentation(
            title: "Stupid",
            subtitle: "Dumb fun, low-brow, or silly",
            synonyms: ["Dumb", "Silly", "Low-brow"]
        ),
    ]

    var tag: BuzzKillTag { BuzzKillTag(rawValue: rawValue) }
}

enum SavedRatingFloorOption: String, AppEnum {
    case any
    case three
    case four

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Rating Floor"
    static let caseDisplayRepresentations: [SavedRatingFloorOption: DisplayRepresentation] = [
        .any: "Any rating",
        .three: "3.0 stars and up",
        .four: "4.0 stars and up",
    ]

    var minimumAverageRating: MinimumAverageRating {
        switch self {
        case .any: .none
        case .three: .three
        case .four: .four
        }
    }
}

enum MovieNightIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noMatches
    case catalogUnavailable
    case noPickTonight
    case reelSpinning

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noMatches:
            "No films on the list match those filters. Try loosening them."
        case .catalogUnavailable:
            "The movie list isn't available right now."
        case .noPickTonight:
            "Nothing has been picked for tonight yet."
        case .reelSpinning:
            "The reel is already spinning. Try again in a moment."
        }
    }
}

// MARK: - Draw

@AppIntent(.tool)
struct DrawTonightsMovieIntent: AppIntent {
    static let title: LocalizedStringResource = "Draw Tonight's Movie"
    static let description = IntentDescription(
        """
        Draws one random film from the 10,000+ film Random Movie Roulette list and locks it in as \
        tonight's movie, replacing any earlier pick. Skips films the person has already watched and \
        honors their saved buzz-kill filters. Optional filters apply to this draw only.
        """
    )

    @Parameter(title: "Genre", description: "Only draw films in this genre. Leave empty for any genre.")
    var genre: GenreOption?

    @Parameter(
        title: "Decade",
        description: "Only draw films released in this decade, given as its first year, such as 1980 for the 1980s."
    )
    var decade: Int?

    @Parameter(
        title: "Minimum Rating",
        description: "Lowest acceptable average Letterboxd rating, from 0.5 to 5.0 stars. Leave empty for no minimum."
    )
    var minimumRating: Double?

    @Parameter(
        title: "Avoid",
        description: "Kinds of films to skip for this draw, on top of the saved filters.",
        default: []
    )
    var avoid: [BuzzKillOption]

    @Parameter(
        title: "Include Watched",
        description: "Whether films the person has already watched may be drawn.",
        default: false
    )
    var includeWatched: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Draw tonight's movie") {
            \.$genre
            \.$decade
            \.$minimumRating
            \.$avoid
            \.$includeWatched
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<MovieEntity> & ProvidesDialog {
        let store = MovieNightStore.iOSShared
        guard !store.catalog.isEmpty else { throw MovieNightIntentError.catalogUnavailable }
        guard !store.isSpinning else { throw MovieNightIntentError.reelSpinning }

        let criteria = MovieNightCriteria(
            genre: genre?.rawValue,
            decade: decade,
            minimumRating: minimumRating,
            additionalExcludedTags: Set(avoid.map(\.tag)),
            includeWatched: includeWatched
        )
        guard let movie = store.drawMovie(matching: criteria) else {
            throw MovieNightIntentError.noMatches
        }

        let entity = MovieEntity(movie: movie)
        let pitch = entity.whyPeopleLikeIt.map { " \($0)" } ?? ""
        return .result(value: entity, dialog: "Tonight's movie is \(entity.displayName).\(pitch)")
    }
}

// MARK: - Shortlist

@AppIntent(.tool)
struct ShortlistMoviesIntent: AppIntent {
    static let title: LocalizedStringResource = "Shortlist Movies"
    static let description = IntentDescription(
        """
        Suggests a few random films from the Random Movie Roulette list that fit the person's saved \
        filters and any optional filters, without changing tonight's pick. Use it when the person \
        wants options to choose from rather than a single winner.
        """
    )

    @Parameter(
        title: "Count",
        description: "How many films to suggest, from 1 to 10.",
        default: 3,
        inclusiveRange: (1, 10)
    )
    var count: Int

    @Parameter(title: "Genre", description: "Only suggest films in this genre. Leave empty for any genre.")
    var genre: GenreOption?

    @Parameter(
        title: "Decade",
        description: "Only suggest films released in this decade, given as its first year, such as 1990 for the 1990s."
    )
    var decade: Int?

    @Parameter(
        title: "Minimum Rating",
        description: "Lowest acceptable average Letterboxd rating, from 0.5 to 5.0 stars. Leave empty for no minimum."
    )
    var minimumRating: Double?

    @Parameter(
        title: "Avoid",
        description: "Kinds of films to skip, on top of the saved filters.",
        default: []
    )
    var avoid: [BuzzKillOption]

    static var parameterSummary: some ParameterSummary {
        Summary("Shortlist \(\.$count) movies") {
            \.$genre
            \.$decade
            \.$minimumRating
            \.$avoid
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[MovieEntity]> & ProvidesDialog {
        let store = MovieNightStore.iOSShared
        guard !store.catalog.isEmpty else { throw MovieNightIntentError.catalogUnavailable }

        let criteria = MovieNightCriteria(
            genre: genre?.rawValue,
            decade: decade,
            minimumRating: minimumRating,
            additionalExcludedTags: Set(avoid.map(\.tag))
        )
        let picks = Array(store.candidates(matching: criteria).shuffled().prefix(max(1, min(count, 10))))
        guard !picks.isEmpty else { throw MovieNightIntentError.noMatches }

        let entities = picks.map(MovieEntity.init(movie:))
        let names = ListFormatter.localizedString(byJoining: entities.map(\.displayName))
        return .result(value: entities, dialog: "Here are some options: \(names).")
    }
}

// MARK: - Tonight's pick

@AppIntent(.tool)
struct GetTonightsMovieIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Tonight's Movie"
    static let description = IntentDescription(
        "Returns the film locked in as tonight's movie, if one has been picked today. Picks reset at midnight."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<MovieEntity?> & ProvidesDialog {
        guard let movie = MovieNightStore.iOSShared.currentMovie else {
            return .result(value: nil, dialog: "Nothing's picked for tonight yet. Ask me to draw a movie.")
        }
        let entity = MovieEntity(movie: movie)
        return .result(value: entity, dialog: "Tonight's movie is \(entity.displayName).")
    }
}

@AppIntent(.tool)
struct SetTonightsMovieIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Tonight's Movie"
    static let description = IntentDescription(
        """
        Locks in a specific film from the Random Movie Roulette list as tonight's movie, replacing any \
        earlier pick. Use it when the person names the film they want instead of a random draw.
        """
    )

    @Parameter(title: "Movie", description: "The film to watch tonight.")
    var movie: MovieEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Make \(\.$movie) tonight's movie")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<MovieEntity> & ProvidesDialog {
        let store = MovieNightStore.iOSShared
        guard let resolved = store.movie(slug: movie.id) else {
            throw MovieNightIntentError.catalogUnavailable
        }
        store.lockIn(resolved)
        return .result(value: movie, dialog: "\(movie.displayName) is locked in for tonight.")
    }
}

// MARK: - Why People Like It

@AppIntent(.tool)
struct ExplainWhyPeopleLikeItIntent: AppIntent {
    static let title: LocalizedStringResource = "Explain Why People Like a Movie"
    static let description = IntentDescription(
        """
        Gives a spoiler-safe pitch for a film: why audiences enjoy it, when it's a good pick, and when \
        to maybe skip it. Uses the app's curated "Why People Like It" notes when available, otherwise \
        the tagline and premise. Defaults to tonight's movie.
        """
    )

    @Parameter(title: "Movie", description: "The film to explain. Leave empty to use tonight's movie.")
    var movie: MovieEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Explain why people like \(\.$movie)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let store = MovieNightStore.iOSShared
        let entity: MovieEntity
        if let movie {
            entity = movie
        } else if let current = store.currentMovie {
            entity = MovieEntity(movie: current)
        } else {
            throw MovieNightIntentError.noPickTonight
        }

        var sentences: [String] = []
        if let summary = entity.whyPeopleLikeIt {
            sentences.append(summary)
            if let goodPickIf = entity.goodPickIf { sentences.append("Good pick if \(lowercasedFirst(goodPickIf))") }
            if let maybeSkipIf = entity.maybeSkipIf { sentences.append("Maybe skip if \(lowercasedFirst(maybeSkipIf))") }
        } else if let tagline = entity.tagline ?? entity.overview {
            sentences.append(tagline)
        } else {
            sentences.append("\(entity.displayName) doesn't have curated notes yet.")
        }
        if let rating = entity.letterboxdRating {
            sentences.append(String(format: "Letterboxd members rate it %.1f out of 5.", rating))
        }

        let text = sentences.map(terminated).joined(separator: " ")
        return .result(value: text, dialog: "\(text)")
    }

    private func lowercasedFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    private func terminated(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?".contains(last) else { return trimmed }
        return trimmed + "."
    }
}

// MARK: - Watched and filters

@AppIntent(.tool)
struct MarkMovieWatchedIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Movie as Watched"
    static let description = IntentDescription(
        "Marks a film as watched so future draws and shortlists skip it. Defaults to tonight's movie."
    )

    @Parameter(title: "Movie", description: "The film the person watched. Leave empty to use tonight's movie.")
    var movie: MovieEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$movie) as watched")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = MovieNightStore.iOSShared
        let resolved: Movie?
        if let movie {
            resolved = store.movie(slug: movie.id)
        } else {
            resolved = store.currentMovie
        }
        guard let resolved else { throw MovieNightIntentError.noPickTonight }

        store.markWatched(resolved)
        return .result(dialog: "Marked \(resolved.displayName) as watched. It won't come up in future draws.")
    }
}

@AppIntent(.tool)
struct UpdateMovieFiltersIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Saved Movie Filters"
    static let description = IntentDescription(
        """
        Changes the filters the app saves for every future draw: which buzz kills to skip, the minimum \
        Letterboxd rating, and whether watched films are excluded. Only the values provided change.
        """
    )

    @Parameter(
        title: "Buzz Kills to Skip",
        description: "Replaces the saved list of film kinds to always skip. Provide an empty list to skip nothing."
    )
    var skip: [BuzzKillOption]?

    @Parameter(title: "Rating Floor", description: "The saved minimum average Letterboxd rating for draws.")
    var ratingFloor: SavedRatingFloorOption?

    @Parameter(title: "Exclude Watched", description: "Whether draws should skip films the person has already watched.")
    var excludeWatched: Bool?

    static var parameterSummary: some ParameterSummary {
        Summary("Update saved movie filters") {
            \.$skip
            \.$ratingFloor
            \.$excludeWatched
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = MovieNightStore.iOSShared
        if let skip {
            store.setExcludedBuzzKillTags(Set(skip.map(\.tag)))
        }
        if let ratingFloor {
            store.setMinimumAverageRating(ratingFloor.minimumAverageRating)
        }
        if let excludeWatched {
            store.setExcludeWatched(excludeWatched)
        }

        let settings = store.session.filterSettings
        let skipped = settings.excludedBuzzKillTags.sorted().map(\.rawValue)
        let skipText = skipped.isEmpty ? "nothing" : ListFormatter.localizedString(byJoining: skipped)
        let watchedText = settings.excludeWatched ? "skip" : "include"
        let ratingText = settings.minimumAverageRating.threshold
            .map { String(format: "need at least %.1f stars", $0) } ?? "have no rating minimum"
        return .result(
            dialog: "Saved. Draws now skip \(skipText), \(ratingText), and \(watchedText) watched films. \(store.eligibleMovies.count) films are in play."
        )
    }
}

// MARK: - Donations

/// Donates intents when the person picks films in the app, so Siri learns which actions they use.
enum MovieNightIntentDonations {
    @MainActor
    static func donate(_ movie: Movie, source: MovieNightStore.SelectionSource) {
        switch source {
        case .draw:
            let intent = DrawTonightsMovieIntent()
            Task { _ = try? await IntentDonationManager.shared.donate(intent: intent) }
        case .chosen:
            var intent = SetTonightsMovieIntent()
            intent.movie = MovieEntity(movie: movie)
            let donation = intent
            Task { _ = try? await IntentDonationManager.shared.donate(intent: donation) }
        }
    }
}
