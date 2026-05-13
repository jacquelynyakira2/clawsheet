import Foundation

public enum TipSearch {
    public static func categories(in tips: [TipItem]) -> [String] {
        ["All"] + Array(Set(tips.map(\.category))).sorted()
    }

    public static func filter(tips: [TipItem], query: String, category: String, pinnedTipIDs: [String] = []) -> [TipItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pinned = Set(pinnedTipIDs)
        return tips
            .filter { category == "All" || $0.category == category }
            .filter { tip in
                guard !trimmed.isEmpty else { return true }
                let haystack = ([tip.title, tip.body, tip.category, tip.shortcut ?? ""] + tip.tags)
                    .joined(separator: " ")
                    .localizedCaseInsensitiveContains(trimmed)
                return haystack
            }
            .sorted { lhs, rhs in
                let lhsPinned = pinned.contains(lhs.id)
                let rhsPinned = pinned.contains(rhs.id)
                if lhsPinned != rhsPinned {
                    return lhsPinned
                }
                if category == "All" {
                    let lhsPriority = categoryPriority(lhs.category)
                    let rhsPriority = categoryPriority(rhs.category)
                    if lhsPriority != rhsPriority {
                        return lhsPriority < rhsPriority
                    }
                }
                if lhs.category == "What's New", rhs.category == "What's New" {
                    return whatsNewSortKey(lhs) > whatsNewSortKey(rhs)
                }
                if lhs.category == "Community", rhs.category == "Community" {
                    return communitySortKey(lhs) > communitySortKey(rhs)
                }
                if lhs.sourceType != rhs.sourceType {
                    return lhs.sourceType == .official
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private static func whatsNewSortKey(_ tip: TipItem) -> TimeInterval {
        if let publishedAt = tip.publishedAt {
            return publishedAt.timeIntervalSince1970
        }
        return Double(weekNumber(in: tip.title) ?? 0)
    }

    private static func weekNumber(in title: String) -> Int? {
        guard let range = title.range(of: #"\d+"#, options: .regularExpression) else {
            return nil
        }
        return Int(title[range])
    }

    private static func communitySortKey(_ tip: TipItem) -> TimeInterval {
        if let publishedAt = tip.publishedAt {
            return publishedAt.timeIntervalSince1970
        }
        if let date = DateExtractor.date(in: tip.title) {
            return date.timeIntervalSince1970
        }
        return tip.updatedAt.timeIntervalSince1970
    }

    private static func categoryPriority(_ category: String) -> Int {
        switch category {
        case "What's New":
            return 0
        case "Best Practice":
            return 1
        case "Commands":
            return 2
        case "Community":
            return 3
        case "Keyboard":
            return 4
        default:
            return 9
        }
    }
}
