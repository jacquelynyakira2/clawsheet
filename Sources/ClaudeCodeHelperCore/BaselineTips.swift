import Foundation

public enum BaselineTips {
    public static let defaultPinnedShortcuts = [
        "/plan",
        "/model",
        "/clear",
        "/compact",
        "/context",
        "/diff",
        "/review",
        "/permissions"
    ]

    public static func load() -> [TipItem] {
        guard let url = Bundle.module.url(forResource: "BaselineTips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let tips = try? JSONDecoder.helperDecoder.decode([TipItem].self, from: data) else {
            return []
        }
        return tips
    }

    public static func defaultPinnedTipIDs(in tips: [TipItem]) -> [String] {
        defaultPinnedShortcuts.compactMap { shortcut in
            tips.first {
                $0.shortcut == shortcut || $0.shortcut?.hasPrefix("\(shortcut) ") == true
            }?.id
        }
    }
}

extension JSONDecoder {
    static var helperDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var helperEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
