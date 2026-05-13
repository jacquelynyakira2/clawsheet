import Foundation

public protocol HelperStore: Sendable {
    func load() throws -> HelperSnapshot
    func save(_ snapshot: HelperSnapshot) throws
    func reset() throws -> HelperSnapshot
}

public struct JSONFileStore: HelperStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) throws {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = base.appendingPathComponent("ClaudeCodeHelper", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("HelperSnapshot.json")
        }
    }

    public func load() throws -> HelperSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return try reset()
        }
        let data = try Data(contentsOf: fileURL)
        var snapshot = try JSONDecoder.helperDecoder.decode(HelperSnapshot.self, from: data)
        if !snapshot.settings.pinSelectionCustomized {
            snapshot.settings.pinnedTipIDs = BaselineTips.defaultPinnedTipIDs(in: snapshot.tips)
        }
        return snapshot
    }

    public func save(_ snapshot: HelperSnapshot) throws {
        let data = try JSONEncoder.helperEncoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func reset() throws -> HelperSnapshot {
        let snapshot = HelperSnapshot(
            tips: BaselineTips.load(),
            sources: OfficialSources.defaultSources,
            updates: [],
            settings: AppSettings(pinnedTipIDs: BaselineTips.defaultPinnedTipIDs(in: BaselineTips.load()))
        )
        try save(snapshot)
        return snapshot
    }
}
