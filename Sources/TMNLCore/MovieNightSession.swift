import CoreGraphics
import Foundation

public struct RouletteUserState: Codable, Equatable, Sendable {
    public var laneID: String
    public var batchIndex: Int
    public var cursorInBatch: Int
    public var seenTitleIDs: [String]

    public init(
        laneID: String,
        batchIndex: Int = 0,
        cursorInBatch: Int = 0,
        seenTitleIDs: [String] = []
    ) {
        self.laneID = laneID
        self.batchIndex = batchIndex
        self.cursorInBatch = cursorInBatch
        self.seenTitleIDs = seenTitleIDs
    }
}

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
    public var rouletteState: RouletteUserState?

    public init(
        filterSettings: MovieFilterSettings,
        watchedSlugs: Set<String>,
        dailySelection: DailySelectionState,
        historyByDay: [String: [SelectionHistoryEntry]],
        rouletteState: RouletteUserState? = nil
    ) {
        self.filterSettings = filterSettings
        self.watchedSlugs = watchedSlugs
        self.dailySelection = dailySelection
        self.historyByDay = historyByDay
        self.rouletteState = rouletteState
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

    public mutating func normalizeRoulette(
        in catalog: [Movie],
        laneCount: Int = 32,
        batchSize: Int = 20
    ) {
        rouletteState = RouletteLanePlanner.normalizedState(
            for: catalog,
            eligibleMovies: eligibleMovies(from: catalog),
            currentState: rouletteState,
            laneCount: laneCount,
            batchSize: batchSize
        )
    }

    public func spinPool(
        in catalog: [Movie],
        laneCount: Int = 32,
        batchSize: Int = 20
    ) -> [Movie] {
        RouletteLanePlanner.spinPool(
            for: catalog,
            eligibleMovies: eligibleMovies(from: catalog),
            currentState: rouletteState,
            laneCount: laneCount,
            batchSize: batchSize
        )
    }

    public mutating func advanceRoulette(
        afterSelecting movie: Movie,
        in catalog: [Movie],
        laneCount: Int = 32,
        batchSize: Int = 20
    ) {
        rouletteState = RouletteLanePlanner.advance(
            afterSelecting: movie,
            in: catalog,
            eligibleMovies: eligibleMovies(from: catalog),
            currentState: rouletteState,
            laneCount: laneCount,
            batchSize: batchSize
        )
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

    enum CodingKeys: String, CodingKey {
        case filterSettings
        case watchedSlugs
        case dailySelection
        case historyByDay
        case rouletteState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        filterSettings = try container.decode(MovieFilterSettings.self, forKey: .filterSettings)
        watchedSlugs = try container.decode(Set<String>.self, forKey: .watchedSlugs)
        dailySelection = try container.decode(DailySelectionState.self, forKey: .dailySelection)
        historyByDay = try container.decode([String: [SelectionHistoryEntry]].self, forKey: .historyByDay)
        rouletteState = try container.decodeIfPresent(RouletteUserState.self, forKey: .rouletteState)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(filterSettings, forKey: .filterSettings)
        try container.encode(watchedSlugs, forKey: .watchedSlugs)
        try container.encode(dailySelection, forKey: .dailySelection)
        try container.encode(historyByDay, forKey: .historyByDay)
        try container.encodeIfPresent(rouletteState, forKey: .rouletteState)
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

struct RouletteLanePlanner {
    static let defaultLaneCount = 32
    static let defaultBatchSize = 20

    private struct Lane {
        let id: String
        let titleIDs: [String]
        let batches: [[String]]
    }

    private struct Resolution {
        let state: RouletteUserState?
        let spinPool: [Movie]
    }

    static func normalizedState(
        for catalog: [Movie],
        eligibleMovies: [Movie],
        currentState: RouletteUserState?,
        laneCount: Int = defaultLaneCount,
        batchSize: Int = defaultBatchSize
    ) -> RouletteUserState? {
        resolve(
            catalog: catalog,
            eligibleMovies: eligibleMovies,
            currentState: currentState,
            laneCount: laneCount,
            batchSize: batchSize
        ).state
    }

    static func spinPool(
        for catalog: [Movie],
        eligibleMovies: [Movie],
        currentState: RouletteUserState?,
        laneCount: Int = defaultLaneCount,
        batchSize: Int = defaultBatchSize
    ) -> [Movie] {
        resolve(
            catalog: catalog,
            eligibleMovies: eligibleMovies,
            currentState: currentState,
            laneCount: laneCount,
            batchSize: batchSize
        ).spinPool
    }

    static func advance(
        afterSelecting movie: Movie,
        in catalog: [Movie],
        eligibleMovies: [Movie],
        currentState: RouletteUserState?,
        laneCount: Int = defaultLaneCount,
        batchSize: Int = defaultBatchSize
    ) -> RouletteUserState? {
        let lanes = buildLanes(from: catalog, laneCount: laneCount, batchSize: batchSize)
        guard !lanes.isEmpty else {
            return nil
        }

        let resolved = resolve(
            catalog: catalog,
            eligibleMovies: eligibleMovies,
            currentState: currentState,
            laneCount: laneCount,
            batchSize: batchSize
        )

        guard var state = resolved.state else {
            return nil
        }

        guard let activeLane = lanes.first(where: { $0.id == state.laneID }) else {
            return resolved.state
        }

        if activeLane.titleIDs.contains(movie.titleID) {
            var seen = Set(state.seenTitleIDs)
            seen.insert(movie.titleID)
            state.seenTitleIDs = Array(seen).sorted()
        }

        return resolve(
            catalog: catalog,
            eligibleMovies: eligibleMovies,
            currentState: state,
            laneCount: laneCount,
            batchSize: batchSize
        ).state
    }

    private static func resolve(
        catalog: [Movie],
        eligibleMovies: [Movie],
        currentState: RouletteUserState?,
        laneCount: Int,
        batchSize: Int
    ) -> Resolution {
        let lanes = buildLanes(from: catalog, laneCount: laneCount, batchSize: batchSize)
        guard let claimedLane = claimedLane(from: lanes, currentState: currentState) else {
            return Resolution(state: nil, spinPool: [])
        }

        let eligibleByTitleID = Dictionary(
            eligibleMovies.map { ($0.titleID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let requestedBatchIndex = max(0, currentState?.batchIndex ?? 0)
        let clampedBatchIndex = min(requestedBatchIndex, max(0, claimedLane.batches.count - 1))
        let seenWithinLane = Set(currentState?.seenTitleIDs ?? []).intersection(claimedLane.titleIDs)

        if let resolvedBatch = firstAvailableBatch(
            in: claimedLane,
            eligibleByTitleID: eligibleByTitleID,
            seenTitleIDs: seenWithinLane,
            startingAt: clampedBatchIndex
        ) {
            return Resolution(
                state: RouletteUserState(
                    laneID: claimedLane.id,
                    batchIndex: resolvedBatch.batchIndex,
                    cursorInBatch: resolvedBatch.cursorInBatch,
                    seenTitleIDs: Array(seenWithinLane).sorted()
                ),
                spinPool: resolvedBatch.movies
            )
        }

        if !seenWithinLane.isEmpty,
           let resetBatch = firstAvailableBatch(
               in: claimedLane,
               eligibleByTitleID: eligibleByTitleID,
               seenTitleIDs: [],
               startingAt: clampedBatchIndex
           )
        {
            return Resolution(
                state: RouletteUserState(
                    laneID: claimedLane.id,
                    batchIndex: resetBatch.batchIndex,
                    cursorInBatch: resetBatch.cursorInBatch,
                    seenTitleIDs: []
                ),
                spinPool: resetBatch.movies
            )
        }

        return Resolution(
            state: RouletteUserState(
                laneID: claimedLane.id,
                batchIndex: clampedBatchIndex,
                cursorInBatch: 0,
                seenTitleIDs: Array(seenWithinLane).sorted()
            ),
            spinPool: []
        )
    }

    private static func claimedLane(from lanes: [Lane], currentState: RouletteUserState?) -> Lane? {
        if let laneID = currentState?.laneID,
           let existingLane = lanes.first(where: { $0.id == laneID })
        {
            return existingLane
        }
        return lanes.first
    }

    private static func buildLanes(from catalog: [Movie], laneCount: Int, batchSize: Int) -> [Lane] {
        let enrichedMovies = catalog
            .filter { $0.whyPeopleLikeIt != nil && $0.enrichmentStatus == .ready }
            .sorted { lhs, rhs in
                if lhs.number == rhs.number {
                    return lhs.titleID < rhs.titleID
                }
                return lhs.number < rhs.number
            }

        guard !enrichedMovies.isEmpty else {
            return []
        }

        let normalizedLaneCount = max(1, min(laneCount, enrichedMovies.count))
        let normalizedBatchSize = max(1, batchSize)
        var laneBuckets = Array(repeating: [String](), count: normalizedLaneCount)

        for (index, movie) in enrichedMovies.enumerated() {
            laneBuckets[index % normalizedLaneCount].append(movie.titleID)
        }

        return laneBuckets.enumerated().compactMap { offset, titleIDs in
            guard !titleIDs.isEmpty else {
                return nil
            }

            let batches = stride(from: 0, to: titleIDs.count, by: normalizedBatchSize).map { start in
                Array(titleIDs[start..<min(start + normalizedBatchSize, titleIDs.count)])
            }

            return Lane(
                id: String(format: "lane-%03d", offset + 1),
                titleIDs: titleIDs,
                batches: batches
            )
        }
    }

    private static func firstAvailableBatch(
        in lane: Lane,
        eligibleByTitleID: [String: Movie],
        seenTitleIDs: Set<String>,
        startingAt batchIndex: Int
    ) -> (batchIndex: Int, cursorInBatch: Int, movies: [Movie])? {
        guard !lane.batches.isEmpty else {
            return nil
        }

        let start = min(max(0, batchIndex), lane.batches.count - 1)
        let orderedBatchIndices = Array(start..<lane.batches.count) + Array(0..<start)

        for candidateBatchIndex in orderedBatchIndices {
            let batchTitleIDs = lane.batches[candidateBatchIndex]
            let availableMovies = batchTitleIDs.compactMap { titleID -> Movie? in
                guard !seenTitleIDs.contains(titleID) else {
                    return nil
                }
                return eligibleByTitleID[titleID]
            }

            guard !availableMovies.isEmpty else {
                continue
            }

            let cursor = batchTitleIDs.firstIndex { titleID in
                !seenTitleIDs.contains(titleID) && eligibleByTitleID[titleID] != nil
            } ?? 0

            return (
                batchIndex: candidateBatchIndex,
                cursorInBatch: cursor,
                movies: availableMovies
            )
        }

        return nil
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
