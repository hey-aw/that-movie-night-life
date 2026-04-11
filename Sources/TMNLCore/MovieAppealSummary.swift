import Foundation

public enum WhyPeopleLikeItConfidence: String, Codable, Hashable, Sendable {
    case high
    case medium
    case low
}

public enum MovieAppealPresentation: Equatable, Sendable {
    case summaryOnly
    case full
}

public struct MovieAppealSummary: Codable, Equatable, Hashable, Sendable {
    public let summary: String
    public let appealTags: [String]
    public let goodPickIf: String?
    public let maybeSkipIf: String?
    public let confidence: WhyPeopleLikeItConfidence?

    enum CodingKeys: String, CodingKey {
        case summary
        case appealTags = "appeal_tags"
        case goodPickIf = "good_pick_if"
        case maybeSkipIf = "maybe_skip_if"
        case confidence
    }

    public init(
        summary: String,
        appealTags: [String] = [],
        goodPickIf: String? = nil,
        maybeSkipIf: String? = nil,
        confidence: WhyPeopleLikeItConfidence? = nil
    ) {
        self.summary = summary
        self.appealTags = appealTags
        self.goodPickIf = goodPickIf
        self.maybeSkipIf = maybeSkipIf
        self.confidence = confidence
    }

    public var presentation: MovieAppealPresentation {
        if appealTags.isEmpty,
           goodPickIf?.isEmpty != false,
           maybeSkipIf?.isEmpty != false,
           confidence == nil {
            return .summaryOnly
        }
        return .full
    }

    public var collapsedAppealTags: [String] {
        Array(appealTags.prefix(3))
    }

    public var isExpandable: Bool {
        goodPickIf?.isEmpty == false || maybeSkipIf?.isEmpty == false
    }
}
