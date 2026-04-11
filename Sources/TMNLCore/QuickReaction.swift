import Foundation

public struct QuickReaction: Codable, Equatable, Sendable {
    public var movieSlug: String
    public var starRating: Int
    public var quickTake: String
    public var recommendTo: String?
    public var createdAt: Date

    public init(
        movieSlug: String,
        starRating: Int = 0,
        quickTake: String = "",
        recommendTo: String? = nil,
        createdAt: Date = Date()
    ) {
        self.movieSlug = movieSlug
        self.starRating = starRating
        self.quickTake = quickTake
        self.recommendTo = recommendTo
        self.createdAt = createdAt
    }
}
