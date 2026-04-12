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
    public let whyPeopleLikeThis: String?
    public let highlightExcerpts: [String]
    public let appealTags: [String]
    public let themeTags: [String]
    public let spoilerSafeSummary: String?
    public let goodPickIf: String?
    public let maybeSkipIf: String?
    public let confidence: WhyPeopleLikeItConfidence?
    public let sourceCount: Int?
    public let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case summary
        case whyPeopleLikeThis = "why_people_like_this"
        case highlightExcerpts = "highlight_excerpts"
        case appealTags = "appeal_tags"
        case themeTags = "theme_tags"
        case spoilerSafeSummary = "spoiler_safe_summary"
        case goodPickIf = "good_pick_if"
        case maybeSkipIf = "maybe_skip_if"
        case confidence
        case sourceCount = "source_count"
        case generatedAt = "generated_at"
    }

    public init(
        summary: String,
        whyPeopleLikeThis: String? = nil,
        highlightExcerpts: [String] = [],
        appealTags: [String] = [],
        themeTags: [String] = [],
        spoilerSafeSummary: String? = nil,
        goodPickIf: String? = nil,
        maybeSkipIf: String? = nil,
        confidence: WhyPeopleLikeItConfidence? = nil,
        sourceCount: Int? = nil,
        generatedAt: String? = nil
    ) {
        self.summary = summary
        self.whyPeopleLikeThis = whyPeopleLikeThis
        self.highlightExcerpts = highlightExcerpts
        self.appealTags = appealTags
        self.themeTags = themeTags
        self.spoilerSafeSummary = spoilerSafeSummary
        self.goodPickIf = goodPickIf
        self.maybeSkipIf = maybeSkipIf
        self.confidence = confidence
        self.sourceCount = sourceCount
        self.generatedAt = generatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        whyPeopleLikeThis = try container.decodeIfPresent(String.self, forKey: .whyPeopleLikeThis)
        highlightExcerpts = try container.decodeIfPresent([String].self, forKey: .highlightExcerpts) ?? []
        appealTags = try container.decodeIfPresent([String].self, forKey: .appealTags) ?? []
        themeTags = try container.decodeIfPresent([String].self, forKey: .themeTags) ?? []
        spoilerSafeSummary = try container.decodeIfPresent(String.self, forKey: .spoilerSafeSummary)
        goodPickIf = try container.decodeIfPresent(String.self, forKey: .goodPickIf)
        maybeSkipIf = try container.decodeIfPresent(String.self, forKey: .maybeSkipIf)
        confidence = try container.decodeIfPresent(WhyPeopleLikeItConfidence.self, forKey: .confidence)
        sourceCount = try container.decodeIfPresent(Int.self, forKey: .sourceCount)
        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
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
