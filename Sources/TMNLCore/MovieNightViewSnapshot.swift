import Foundation

public struct MovieNightFilterPill: Equatable, Sendable, Identifiable {
    public let title: String
    public let isActive: Bool

    public var id: String { title }

    public init(title: String, isActive: Bool) {
        self.title = title
        self.isActive = isActive
    }
}

public struct MovieNightViewSnapshot: Equatable, Sendable {
    public let filterPills: [MovieNightFilterPill]
    public let catalogCount: Int
    public let eligibleCount: Int
    public let watchedCount: Int
    public let historyEntryCount: Int

    public init(
        filterPills: [MovieNightFilterPill],
        catalogCount: Int,
        eligibleCount: Int,
        watchedCount: Int,
        historyEntryCount: Int
    ) {
        self.filterPills = filterPills
        self.catalogCount = catalogCount
        self.eligibleCount = eligibleCount
        self.watchedCount = watchedCount
        self.historyEntryCount = historyEntryCount
    }

    public static func build(
        filterSettings: MovieFilterSettings,
        catalogCount: Int,
        eligibleCount: Int,
        watchedCount: Int,
        historySections: [MovieNightHistorySection]
    ) -> MovieNightViewSnapshot {
        let filterPills = [
            MovieNightFilterPill(
                title: filterSettings.excludeWatched ? "Exclude Watched" : "Watched Allowed",
                isActive: filterSettings.excludeWatched
            ),
            MovieNightFilterPill(
                title: filterSettings.minimumAverageRating.title,
                isActive: filterSettings.minimumAverageRating != .none
            )
        ] + filterSettings.excludedBuzzKillTags.sorted().map {
            MovieNightFilterPill(title: "No \($0.rawValue.capitalized)", isActive: true)
        }

        return MovieNightViewSnapshot(
            filterPills: filterPills,
            catalogCount: catalogCount,
            eligibleCount: eligibleCount,
            watchedCount: watchedCount,
            historyEntryCount: historySections.reduce(0) { $0 + $1.entries.count }
        )
    }
}
