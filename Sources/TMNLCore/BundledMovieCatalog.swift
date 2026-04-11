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
            Movie(
                number: record.number,
                slug: record.slug,
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
                overview: record.overview,
                tagline: record.tagline,
                director: record.director,
                cast: record.cast ?? [],
                buzzKillTags: tagMap[record.slug] ?? [],
                whyPeopleLikeIt: rawAppeal[record.slug]
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
    let overview: String?
    let tagline: String?
    let director: String?
    let cast: [String]?
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
