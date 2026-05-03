import Foundation

public enum BundledMovieCatalog {
    public static func load() throws -> [Movie] {
        try load(bundle: ResourceBundleLocator.bundle)
    }

    static func load(bundle: Bundle) throws -> [Movie] {
        let rawMovies: [RawMovieRecord] = try loadJSON(named: "movies.catalog", bundle: bundle)
        let rawTags: [String: [String]] = try loadJSON(named: "movie-tags", bundle: bundle)
        let rawAppeal: [String: MovieAppealSummary] = try loadOptionalJSON(named: "movie-appeal", bundle: bundle) ?? [:]
        let tagMap = rawTags.mapValues { Set($0.map(BuzzKillTag.init(rawValue:))) }

        return rawMovies.map { record in
            let hasPublishedEnrichment = rawAppeal[record.slug] != nil
            let effectiveTitleID = record.titleID ?? "tmnl:\(record.slug)"
            let effectiveAvailabilityFlags = record.availabilityFlags ?? []
            let effectiveCatalogStatus = record.catalogStatus ?? .ready
            let effectiveEnrichmentStatus: TitleEnrichmentStatus = hasPublishedEnrichment ? .ready : (record.enrichmentStatus ?? .pending)
            let effectiveReviewSignalCount = record.reviewSignalCount ?? 0
            let effectiveAppeal = rawAppeal[record.slug]
            return Movie(
                number: record.number,
                slug: record.slug,
                titleID: effectiveTitleID,
                title: record.title,
                year: record.year,
                displayName: record.displayName,
                letterboxdURL: record.letterboxdURL,
                watchURL: record.watchURL,
                posterURL: record.posterURL,
                aggregateRating: record.aggregateRating,
                ratingCount: record.ratingCount,
                genres: record.genres,
                tmdbMovieID: record.tmdbMovieID,
                runtimeMinutes: record.runtimeMinutes,
                certification: record.certification,
                backdropURL: record.backdropURL,
                availabilityFlags: effectiveAvailabilityFlags,
                catalogStatus: effectiveCatalogStatus,
                enrichmentStatus: effectiveEnrichmentStatus,
                reviewSignalCount: effectiveReviewSignalCount,
                lastEnrichedAt: record.lastEnrichedAt,
                overview: record.overview,
                tagline: record.tagline,
                director: record.director,
                cast: record.cast ?? [],
                buzzKillTags: tagMap[record.slug] ?? [],
                whyPeopleLikeIt: effectiveAppeal
            )
        }
    }

    private static func loadJSON<T: Decodable>(named name: String, bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CatalogLoadingError.missingResource(name: name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func loadOptionalJSON<T: Decodable>(named name: String, bundle: Bundle) throws -> T? {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum CatalogLoadingError: Error, Equatable {
    case missingResource(name: String)
}

private struct RawMovieRecord: Codable {
    let number: Int
    let titleID: String?
    let slug: String
    let title: String
    let year: Int?
    let displayName: String
    let letterboxdURL: String
    let watchURL: String
    let posterURL: String?
    let aggregateRating: Double?
    let ratingCount: Int?
    let genres: [String]
    let tmdbMovieID: Int?
    let runtimeMinutes: Int?
    let certification: String?
    let backdropURL: String?
    let availabilityFlags: [String]?
    let catalogStatus: CatalogSpineStatus?
    let enrichmentStatus: TitleEnrichmentStatus?
    let reviewSignalCount: Int?
    let lastEnrichedAt: String?
    let overview: String?
    let tagline: String?
    let director: String?
    let cast: [String]?

    enum CodingKeys: String, CodingKey {
        case number
        case titleID = "title_id"
        case slug
        case title
        case year
        case displayName
        case letterboxdURL
        case watchURL
        case posterURL
        case aggregateRating
        case ratingCount
        case genres
        case tmdbMovieID
        case runtimeMinutes
        case certification
        case backdropURL
        case availabilityFlags = "availability_flags"
        case catalogStatus = "catalog_status"
        case enrichmentStatus = "enrichment_status"
        case reviewSignalCount = "review_signal_count"
        case lastEnrichedAt = "last_enriched_at"
        case overview
        case tagline
        case director
        case cast
    }
}

private enum ResourceBundleLocator {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }
}
