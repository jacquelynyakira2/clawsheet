import Foundation

public protocol DocumentFetching: Sendable {
    func fetchText(from url: URL) async throws -> String
}

public struct URLSessionDocumentFetcher: DocumentFetching {
    public init() {}

    public func fetchText(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }
}

public struct RefreshResult: Equatable, Sendable {
    public var fetchedSourceCount: Int
    public var importedTipCount: Int
    public var importedUpdateCount: Int
    public var failedSourceCount: Int
}

public actor RefreshService {
    private let fetcher: DocumentFetching

    public init(fetcher: DocumentFetching = URLSessionDocumentFetcher()) {
        self.fetcher = fetcher
    }

    public func refresh(snapshot: HelperSnapshot, includeOfficialSources: Bool = true) async throws -> (HelperSnapshot, RefreshResult) {
        var next = snapshot
        var allSources = includeOfficialSources ? OfficialSources.defaultSources : []
        allSources.append(contentsOf: snapshot.settings.communitySources)
        allSources = allSources.filter(\.isEnabled)

        var importedTips: [TipItem] = []
        var importedUpdates: [UpdateEntry] = []
        var fetchedSources: [SourceItem] = []

        var failedSourceCount = 0

        for var source in allSources {
            do {
                let markdown = try await fetcher.fetchText(from: source.url)
                let parsed = MarkdownParsers.parse(markdown, source: source)
                importedTips.append(contentsOf: parsed.tips)
                importedUpdates.append(contentsOf: parsed.updates)
                source.lastFetchedAt = Date()
                source.lastImportCount = parsed.tips.count
                source.lastError = nil
                fetchedSources.append(source)
            } catch {
                failedSourceCount += 1
                source.lastFetchedAt = Date()
                source.lastImportCount = 0
                source.lastError = error.localizedDescription
                fetchedSources.append(source)
            }
        }

        next.tips = mergeTips(existing: BaselineTips.load(), imported: importedTips)
        if !next.settings.pinSelectionCustomized {
            next.settings.pinnedTipIDs = BaselineTips.defaultPinnedTipIDs(in: next.tips)
        }
        next.updates = importedUpdates.sorted {
            ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
        }
        next.sources = fetchedSources
        next.settings.communitySources = fetchedSources.filter { $0.sourceType == .community }
        next.settings.lastRefreshAt = Date()

        let result = RefreshResult(
            fetchedSourceCount: fetchedSources.count,
            importedTipCount: importedTips.count,
            importedUpdateCount: importedUpdates.count,
            failedSourceCount: failedSourceCount
        )
        return (next, result)
    }

    private func mergeTips(existing: [TipItem], imported: [TipItem]) -> [TipItem] {
        var byID: [String: TipItem] = [:]
        for tip in existing + imported {
            byID[tip.id] = tip
        }
        return Array(byID.values).sorted {
            if $0.sourceType != $1.sourceType {
                return $0.sourceType == .official
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}
