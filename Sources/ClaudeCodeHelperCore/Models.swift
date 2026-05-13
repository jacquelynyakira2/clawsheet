import Foundation

public enum SourceType: String, Codable, CaseIterable, Sendable {
    case official
    case community
}

public enum ParserType: String, Codable, CaseIterable, Sendable {
    case changelogMarkdown
    case whatsNewMarkdown
    case commandsMarkdown
    case keybindingsMarkdown
    case bestPracticesMarkdown
    case communityMarkdown
}

public struct TipItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var category: String
    public var tags: [String]
    public var shortcut: String?
    public var sourceURL: URL
    public var sourceType: SourceType
    public var version: String?
    public var publishedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        category: String,
        tags: [String],
        shortcut: String? = nil,
        sourceURL: URL,
        sourceType: SourceType,
        version: String? = nil,
        publishedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.tags = tags
        self.shortcut = shortcut
        self.sourceURL = sourceURL
        self.sourceType = sourceType
        self.version = version
        self.publishedAt = publishedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SourceItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var sourceType: SourceType
    public var url: URL
    public var parserType: ParserType
    public var isEnabled: Bool
    public var lastFetchedAt: Date?
    public var lastImportCount: Int?
    public var lastError: String?

    public init(
        id: String = UUID().uuidString,
        sourceType: SourceType,
        url: URL,
        parserType: ParserType,
        isEnabled: Bool = true,
        lastFetchedAt: Date? = nil,
        lastImportCount: Int? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.url = url
        self.parserType = parserType
        self.isEnabled = isEnabled
        self.lastFetchedAt = lastFetchedAt
        self.lastImportCount = lastImportCount
        self.lastError = lastError
    }
}

public struct UpdateEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var version: String
    public var publishedAt: Date?
    public var sourceURL: URL
    public var rawSummary: String
    public var generatedTipIDs: [String]

    public init(
        id: String = UUID().uuidString,
        version: String,
        publishedAt: Date?,
        sourceURL: URL,
        rawSummary: String,
        generatedTipIDs: [String]
    ) {
        self.id = id
        self.version = version
        self.publishedAt = publishedAt
        self.sourceURL = sourceURL
        self.rawSummary = rawSummary
        self.generatedTipIDs = generatedTipIDs
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var refreshIntervalHours: Int
    public var lastRefreshAt: Date?
    public var communitySources: [SourceItem]
    public var pinnedTipIDs: [String]
    public var pinSelectionCustomized: Bool

    public init(
        refreshIntervalHours: Int = 24,
        lastRefreshAt: Date? = nil,
        communitySources: [SourceItem] = [],
        pinnedTipIDs: [String] = [],
        pinSelectionCustomized: Bool = false
    ) {
        self.refreshIntervalHours = refreshIntervalHours
        self.lastRefreshAt = lastRefreshAt
        self.communitySources = communitySources
        self.pinnedTipIDs = pinnedTipIDs
        self.pinSelectionCustomized = pinSelectionCustomized
    }

    enum CodingKeys: String, CodingKey {
        case refreshIntervalHours
        case lastRefreshAt
        case communitySources
        case pinnedTipIDs
        case pinSelectionCustomized
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        refreshIntervalHours = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalHours) ?? 24
        lastRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastRefreshAt)
        communitySources = try container.decodeIfPresent([SourceItem].self, forKey: .communitySources) ?? []
        pinnedTipIDs = try container.decodeIfPresent([String].self, forKey: .pinnedTipIDs) ?? []
        pinSelectionCustomized = try container.decodeIfPresent(Bool.self, forKey: .pinSelectionCustomized) ?? false
    }
}

public struct HelperSnapshot: Codable, Equatable, Sendable {
    public var tips: [TipItem]
    public var sources: [SourceItem]
    public var updates: [UpdateEntry]
    public var settings: AppSettings

    public init(
        tips: [TipItem],
        sources: [SourceItem],
        updates: [UpdateEntry],
        settings: AppSettings
    ) {
        self.tips = tips
        self.sources = sources
        self.updates = updates
        self.settings = settings
    }
}
