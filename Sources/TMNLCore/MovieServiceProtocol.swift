import Foundation

public protocol MovieServiceProtocol: Sendable {
    func fetchRecommendations(count: Int) async throws -> [Movie]
    func fetchMovieDetail(slug: String) async throws -> Movie?
    func generateShortlist(from movies: [Movie], count: Int) async throws -> [Movie]
}

public protocol RoomServiceProtocol: Sendable {
    func fetchRooms() async throws -> [Room]
    func createRoom(name: String) async throws -> Room
    func fetchRoomHistory(roomID: UUID) async throws -> [String]
}

public protocol LetterboxdServiceProtocol: Sendable {
    func importWatchlist() async throws -> Set<String>
    func importFollowedLists() async throws -> [[String]]
}

public protocol AvailabilityServiceProtocol: Sendable {
    func fetchAvailability(for movieSlug: String) async throws -> [String]
    func filterByService(_ movies: [Movie], service: String) async throws -> [Movie]
}

public final class MockMovieService: MovieServiceProtocol, @unchecked Sendable {
    public init() {}

    public func fetchRecommendations(count: Int) async throws -> [Movie] {
        []
    }

    public func fetchMovieDetail(slug: String) async throws -> Movie? {
        nil
    }

    public func generateShortlist(from movies: [Movie], count: Int) async throws -> [Movie] {
        Array(movies.shuffled().prefix(count))
    }
}

public final class MockRoomService: RoomServiceProtocol, @unchecked Sendable {
    public init() {}

    public func fetchRooms() async throws -> [Room] {
        []
    }

    public func createRoom(name: String) async throws -> Room {
        Room(name: name)
    }

    public func fetchRoomHistory(roomID: UUID) async throws -> [String] {
        []
    }
}
