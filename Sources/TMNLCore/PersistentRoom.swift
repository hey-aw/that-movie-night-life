import Foundation

public enum RoomSelectionMode: String, Codable, CaseIterable, Sendable {
    case random, listOrder
}

public enum NightAvailability: String, Codable, CaseIterable, Sendable {
    case undecided, attending, notTonight, ready, delayed
}

public struct RoomNight: Codable, Equatable, Sendable {
    public var id = UUID()
    public var status: NightAvailability = .undecided
    public var updatedAt: Date
    public var availableAt: Date?

    public init(now: Date = Date()) { updatedAt = now }

    public mutating func respond(_ status: NightAvailability, now: Date = Date(), delay: TimeInterval? = nil) {
        self.status = status
        updatedAt = now
        availableAt = status == .delayed ? delay.map { now.addingTimeInterval($0) } : nil
    }
}

public struct RoomWatch: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public let movieSlug: String
    public let watchedAt: Date
}

/// Local aggregate. Normalize into separate CloudKit-compatible entities before sharing.
public struct PersistentRoom: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var movieSlugs: [String] = []
    public var selectionMode: RoomSelectionMode = .random
    public private(set) var currentMovieSlug: String?
    public private(set) var history: [RoomWatch] = []
    public var night: RoomNight?

    public init(name: String) { self.name = name }

    public mutating func addMovie(_ slug: String) {
        guard !movieSlugs.contains(slug) else { return }
        movieSlugs.append(slug)
    }

    /// An active selection is stable until explicitly watched or cleared.
    @discardableResult
    public mutating func pick(using choose: ([String]) -> String? = { $0.randomElement() }) -> String? {
        if let currentMovieSlug { return currentMovieSlug }
        let watched = Set(history.map(\.movieSlug))
        let candidates = movieSlugs.filter { !watched.contains($0) }
        let selected = selectionMode == .listOrder ? candidates.first : choose(candidates)
        guard let selected, candidates.contains(selected) else { return nil }
        currentMovieSlug = selected
        return selected
    }

    public mutating func clearSelection() { currentMovieSlug = nil }

    public mutating func markWatched(now: Date = Date()) {
        guard let currentMovieSlug else { return }
        history.append(RoomWatch(movieSlug: currentMovieSlug, watchedAt: now))
        self.currentMovieSlug = nil
        night = nil
    }
}
