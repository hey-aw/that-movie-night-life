import CoreGraphics
import Foundation

public struct SelectionHistoryEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let movieSlug: String
    public let number: Int
    public let title: String
    public let displayName: String
    public let timestamp: Date
    public var skipped: Bool

    public var id: String {
        "\(movieSlug)-\(timestamp.timeIntervalSince1970)"
    }
}

public struct DailySelectionState: Codable, Equatable, Sendable {
    public var dayKey: String
    public var currentMovieNumber: Int?
    public var replayMovieNumber: Int?

    public init(
        dayKey: String,
        currentMovieNumber: Int? = nil,
        replayMovieNumber: Int? = nil
    ) {
        self.dayKey = dayKey
        self.currentMovieNumber = currentMovieNumber
        self.replayMovieNumber = replayMovieNumber
    }
}

public struct MovieNightSession: Codable, Equatable, Sendable {
    public var filterSettings: MovieFilterSettings
    public var watchedSlugs: Set<String>
    public var dailySelection: DailySelectionState
    public var historyByDay: [String: [SelectionHistoryEntry]]

    public init(
        filterSettings: MovieFilterSettings,
        watchedSlugs: Set<String>,
        dailySelection: DailySelectionState,
        historyByDay: [String: [SelectionHistoryEntry]]
    ) {
        self.filterSettings = filterSettings
        self.watchedSlugs = watchedSlugs
        self.dailySelection = dailySelection
        self.historyByDay = historyByDay
    }

    public static let empty = MovieNightSession(
        filterSettings: .default,
        watchedSlugs: [],
        dailySelection: DailySelectionState(dayKey: Self.dayKey(for: Date(), calendar: .current)),
        historyByDay: [:]
    )

    public mutating func normalize(on date: Date, calendar: Calendar = .current) {
        let newDayKey = Self.dayKey(for: date, calendar: calendar)
        guard dailySelection.dayKey != newDayKey else {
            return
        }
        dailySelection = DailySelectionState(dayKey: newDayKey)
    }

    public func eligibleMovies(from catalog: [Movie]) -> [Movie] {
        MovieFilterEngine.eligibleMovies(from: catalog, watchedSlugs: watchedSlugs, settings: filterSettings)
    }

    public func currentMovie(in catalog: [Movie]) -> Movie? {
        guard let number = dailySelection.currentMovieNumber else { return nil }
        return catalog.first { $0.number == number }
    }

    public func replayMovie(in catalog: [Movie]) -> Movie? {
        guard let number = dailySelection.replayMovieNumber else { return nil }
        return catalog.first { $0.number == number }
    }

    public mutating func recordSelection(_ movie: Movie, at date: Date, calendar: Calendar = .current) {
        normalize(on: date, calendar: calendar)
        dailySelection.currentMovieNumber = movie.number
        dailySelection.replayMovieNumber = movie.number
        let dayKey = dailySelection.dayKey
        let entry = SelectionHistoryEntry(
            movieSlug: movie.slug,
            number: movie.number,
            title: movie.title,
            displayName: movie.displayName,
            timestamp: date,
            skipped: false
        )
        historyByDay[dayKey, default: []].insert(entry, at: 0)
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

public struct TMNLIOSViewportLayout: Sendable, Equatable {
    public let viewportWidth: CGFloat

    public init(viewportWidth: CGFloat) {
        self.viewportWidth = viewportWidth
    }

    public var isCompact: Bool {
        viewportWidth < 390
    }

    public var isVeryCompact: Bool {
        viewportWidth < 350
    }

    public var horizontalPadding: CGFloat {
        isVeryCompact ? 16 : 20
    }

    public var sectionSpacing: CGFloat {
        isCompact ? 20 : 24
    }

    public var contentMaxWidth: CGFloat {
        min(max(viewportWidth - (horizontalPadding * 2), 0), 680)
    }

    public var metricsColumnCount: Int {
        isCompact ? 2 : 4
    }

    public var stacksControlsVertically: Bool {
        contentMaxWidth < 430
    }

    public var stacksResultVertically: Bool {
        contentMaxWidth < 520
    }

    public var reelDigitWidth: CGFloat {
        if isVeryCompact { return 46 }
        if isCompact { return 52 }
        return 58
    }

    public var reelDigitHeight: CGFloat {
        if isVeryCompact { return 58 }
        if isCompact { return 66 }
        return 72
    }

    public var reelDigitSpacing: CGFloat {
        isVeryCompact ? 6 : 10
    }

    public var reelDigitFontSize: CGFloat {
        if isVeryCompact { return 34 }
        if isCompact { return 38 }
        return 42
    }

    public var posterWidth: CGFloat {
        if stacksResultVertically {
            return min(max(contentMaxWidth * 0.52, 116), 168)
        }
        return 140
    }

    public var posterHeight: CGFloat {
        round(posterWidth * 1.5)
    }
}
