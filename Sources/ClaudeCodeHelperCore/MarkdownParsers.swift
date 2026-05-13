import Foundation

public struct ParsedContent: Equatable, Sendable {
    public var tips: [TipItem]
    public var updates: [UpdateEntry]

    public init(tips: [TipItem] = [], updates: [UpdateEntry] = []) {
        self.tips = tips
        self.updates = updates
    }
}

public enum MarkdownParsers {
    public static func parse(_ markdown: String, source: SourceItem) -> ParsedContent {
        switch source.parserType {
        case .changelogMarkdown:
            return ChangelogParser.parse(markdown, sourceURL: source.url)
        case .whatsNewMarkdown:
            return WhatsNewParser.parse(markdown, sourceURL: source.url)
        case .commandsMarkdown:
            return CommandParser.parse(markdown, sourceURL: source.url)
        case .keybindingsMarkdown:
            return KeybindingParser.parse(markdown, sourceURL: source.url)
        case .bestPracticesMarkdown:
            return BestPracticeParser.parse(markdown, sourceURL: source.url)
        case .communityMarkdown:
            return CommunityParser.parse(markdown, sourceURL: source.url)
        }
    }
}

enum WhatsNewParser {
    static func parse(_ markdown: String, sourceURL: URL) -> ParsedContent {
        let blocks = updateBlocks(in: markdown)
        var tips: [TipItem] = []
        var updates: [UpdateEntry] = []

        for block in blocks {
            let summary = block.body.meaningfulMarkdownLines()
                .filter { !$0.hasPrefix("Read the ") }
                .joined(separator: " ")
            guard !summary.isEmpty else { continue }

            let digestURL = digestURL(in: block.body, fallback: sourceURL.humanReadableDocsURL)
            let publishedAt = weekStartDate(from: block.description) ?? weekDateFallback(from: block.label)
            let tip = TipItem(
                id: stableID(["whats-new", block.label, block.description, summary]),
                title: block.label,
                body: summary,
                category: "What's New",
                tags: ["whats-new"] + block.tags,
                shortcut: firstActionToken(in: block.body),
                sourceURL: digestURL,
                sourceType: .official,
                version: block.tags.first,
                publishedAt: publishedAt,
                updatedAt: publishedAt ?? Date()
            )
            tips.append(tip)
            updates.append(UpdateEntry(
                id: "whats-new-\(stableID([block.label, block.description]))",
                version: block.tags.first ?? block.label,
                publishedAt: publishedAt,
                sourceURL: digestURL,
                rawSummary: summary,
                generatedTipIDs: [tip.id]
            ))
        }

        return ParsedContent(tips: tips, updates: updates)
    }

    private static func updateBlocks(in markdown: String) -> [(label: String, description: String, tags: [String], body: String)] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<Update\s+label="([^"]+)"\s+description="([^"]+)"\s+tags=\{\[([^\]]*)\]\}>([\s\S]*?)</Update>"#,
            options: []
        ) else {
            return []
        }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        return regex.matches(in: markdown, range: range).compactMap { match in
            guard let labelRange = Range(match.range(at: 1), in: markdown),
                  let descriptionRange = Range(match.range(at: 2), in: markdown),
                  let tagsRange = Range(match.range(at: 3), in: markdown),
                  let bodyRange = Range(match.range(at: 4), in: markdown) else {
                return nil
            }
            let tags = markdown[tagsRange]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) }
                .filter { !$0.isEmpty }
            return (
                label: String(markdown[labelRange]),
                description: String(markdown[descriptionRange]),
                tags: tags,
                body: String(markdown[bodyRange])
            )
        }
    }

    private static func digestURL(in body: String, fallback: URL) -> URL {
        guard let regex = try? NSRegularExpression(pattern: #"\]\((/en/whats-new/[^)]+)\)"#),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body)),
              let pathRange = Range(match.range(at: 1), in: body),
              let url = URL(string: "https://code.claude.com/docs\(body[pathRange])") else {
            return fallback
        }
        return url
    }

    private static func weekStartDate(from description: String) -> Date? {
        let normalized = description
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: #"(\d+),\s*(\d{4})"#, with: "$1 $2", options: .regularExpression)
        guard let match = normalized.range(of: #"[A-Za-z]+\s+\d{1,2}"#, options: .regularExpression),
              let yearRange = normalized.range(of: #"\d{4}"#, options: .regularExpression) else {
            return nil
        }
        let candidate = "\(normalized[match]), \(normalized[yearRange])"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.date(from: candidate)
    }

    private static func weekDateFallback(from label: String) -> Date? {
        guard let range = label.range(of: #"\d+"#, options: .regularExpression),
              let week = Int(label[range]) else {
            return nil
        }
        var components = DateComponents()
        components.calendar = Calendar(identifier: .iso8601)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.weekOfYear = week
        components.yearForWeekOfYear = 2026
        components.weekday = 2
        return components.date
    }
}

enum ChangelogParser {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func parse(_ markdown: String, sourceURL: URL) -> ParsedContent {
        let lines = markdown.components(separatedBy: .newlines)
        var tips: [TipItem] = []
        var updates: [UpdateEntry] = []
        var currentVersion: String?
        var currentDate: Date?
        var currentBullets: [String] = []

        func flush() {
            guard let version = currentVersion, !currentBullets.isEmpty else { return }
            let generated = currentBullets.compactMap {
                tip(from: $0, version: version, publishedAt: currentDate, sourceURL: sourceURL)
            }
            tips.append(contentsOf: generated)
            updates.append(UpdateEntry(
                id: "update-\(version)",
                version: version,
                publishedAt: currentDate,
                sourceURL: sourceURL.humanReadableDocsURL,
                rawSummary: currentBullets.joined(separator: "\n"),
                generatedTipIDs: generated.map(\.id)
            ))
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if isVersion(line) {
                flush()
                currentVersion = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                currentDate = nil
                currentBullets = []
            } else if currentVersion != nil, currentDate == nil, let date = dateFormatter.date(from: line) {
                currentDate = date
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                currentBullets.append(String(line.dropFirst(2)).strippingMarkdown)
            }
        }
        flush()

        return ParsedContent(tips: tips, updates: updates)
    }

    private static func isVersion(_ line: String) -> Bool {
        let candidate = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
        return candidate.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil
    }

    private static func tip(from bullet: String, version: String, publishedAt: Date?, sourceURL: URL) -> TipItem? {
        let lower = bullet.lowercased()
        let keywords = ["added", "command", "shortcut", "key", "config", "setting", "hook", "tool", "workflow", "mode", "mcp", "plugin", "env var", "environment"]
        guard keywords.contains(where: { lower.contains($0) }) else { return nil }
        if lower.hasPrefix("fixed ") && !lower.contains("shortcut") && !lower.contains("command") && !lower.contains("setting") {
            return nil
        }

        let shortcut = firstCodeSpan(in: bullet) ?? firstSlashCommand(in: bullet)
        let category: String
        if shortcut?.hasPrefix("/") == true {
            category = "Commands"
        } else if lower.contains("shortcut") || lower.contains("key") || shortcut?.contains("Ctrl") == true || shortcut?.contains("Cmd") == true {
            category = "Keyboard"
        } else if lower.contains("hook") || lower.contains("mcp") || lower.contains("plugin") || lower.contains("env") || lower.contains("setting") || lower.contains("config") {
            category = "Configuration"
        } else {
            category = "Update"
        }

        return TipItem(
            id: stableID(["changelog", version, bullet]),
            title: title(from: bullet),
            body: bullet,
            category: category,
            tags: ["changelog", version, category.lowercased()],
            shortcut: shortcut,
            sourceURL: sourceURL.humanReadableDocsURL,
            sourceType: .official,
            version: version,
            publishedAt: publishedAt,
            createdAt: Date(),
            updatedAt: publishedAt ?? Date()
        )
    }
}

enum CommandParser {
    static func parse(_ markdown: String, sourceURL: URL) -> ParsedContent {
        let tableTips = parseCommandTable(markdown, sourceURL: sourceURL)
        if !tableTips.isEmpty {
            return ParsedContent(tips: tableTips)
        }

        let tips = markdown.headingSections().compactMap { section -> TipItem? in
            guard section.heading.contains("/") else { return nil }
            let command = firstSlashCommand(in: section.heading) ?? firstSlashCommand(in: section.body)
            guard let command else { return nil }
            let body = section.body.firstMeaningfulSentence
            return TipItem(
                id: stableID(["command", command, body]),
                title: command,
                body: body.isEmpty ? "Claude Code command." : body,
                category: "Commands",
                tags: ["command", command.replacingOccurrences(of: "/", with: "")],
                shortcut: command,
                sourceURL: sourceURL.humanReadableDocsURL,
                sourceType: .official
            )
        }
        return ParsedContent(tips: tips)
    }

    private static func parseCommandTable(_ markdown: String, sourceURL: URL) -> [TipItem] {
        markdown.components(separatedBy: .newlines).compactMap { rawLine -> TipItem? in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("| `") else { return nil }
            let cells = markdownTableCells(from: line)
            guard cells.count >= 2 else { return nil }

            let command = cells[0].strippingMarkdownTableSyntax
            guard command.hasPrefix("/") else { return nil }

            let purpose = cells[1].strippingMarkdownTableSyntax
            guard !purpose.isEmpty else { return nil }

            return TipItem(
                id: stableID(["command-table", command, purpose]),
                title: command,
                body: purpose,
                category: "Commands",
                tags: ["command", command.commandTag],
                shortcut: command,
                sourceURL: sourceURL.humanReadableDocsURL,
                sourceType: .official
            )
        }
    }
}

enum KeybindingParser {
    static func parse(_ markdown: String, sourceURL: URL) -> ParsedContent {
        let lines = markdown.components(separatedBy: .newlines)
        var tips: [TipItem] = []
        for line in lines {
            let codeSpans = codeSpans(in: line)
            guard !codeSpans.isEmpty else { continue }
            let shortcutSpans = codeSpans.filter { $0.isLikelyKeyboardShortcut || $0.hasPrefix("/") }
            guard !shortcutSpans.isEmpty else { continue }
            let lower = line.lowercased()
            guard lower.contains("ctrl") || lower.contains("cmd") || lower.contains("shift") || lower.contains("tab") || lower.contains("escape") || lower.contains("key") || lower.contains("shortcut") else {
                continue
            }
            let cleanLine = line.strippingMarkdownTableSyntax
                .replacingOccurrences(of: #"^\|+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\|+$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*\|\s*"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanLine.count > 8, !cleanLine.isMostlyPunctuation else { continue }
            tips.append(TipItem(
                id: stableID(["keybinding", cleanLine]),
                title: shortcutSpans.joined(separator: " / "),
                body: cleanLine,
                category: "Keyboard",
                tags: ["keyboard", "shortcut"],
                shortcut: shortcutSpans.joined(separator: ", "),
                sourceURL: sourceURL.humanReadableDocsURL,
                sourceType: .official
            ))
        }
        return ParsedContent(tips: unique(tips))
    }
}

enum BestPracticeParser {
    static func parse(_ markdown: String, sourceURL: URL) -> ParsedContent {
        let sections = markdown.headingSections()
        let tips = sections
            .filter { !$0.heading.lowercased().contains("best practices") }
            .prefix(20)
            .map { section in
                TipItem(
                    id: stableID(["best-practice", section.heading, section.body.firstMeaningfulSentence]),
                    title: section.heading.strippingMarkdown,
                    body: section.body.firstMeaningfulSentence,
                    category: "Best Practice",
                    tags: ["best-practice"],
                    sourceURL: sourceURL.humanReadableDocsURL,
                    sourceType: .official
                )
            }
            .filter { !$0.body.isEmpty }
        return ParsedContent(tips: Array(tips))
    }
}

enum CommunityParser {
    static func parse(_ markdown: String, sourceURL: URL) -> ParsedContent {
        if markdown.localizedCaseInsensitiveContains("<html") || markdown.localizedCaseInsensitiveContains("<a ") {
            return ParsedContent(tips: parseHTML(markdown, sourceURL: sourceURL))
        }

        let tips = markdown.components(separatedBy: .newlines).compactMap { rawLine -> TipItem? in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("- ") || line.hasPrefix("* ") else { return nil }
            let body = String(line.dropFirst(2)).strippingMarkdown
            guard body.count > 12 else { return nil }
            return TipItem(
                id: stableID(["community", sourceURL.absoluteString, body]),
                title: title(from: body),
                body: body,
                category: "Community",
                tags: ["community"],
                shortcut: firstCodeSpan(in: body) ?? firstSlashCommand(in: body),
                sourceURL: sourceURL,
                sourceType: .community
            )
        }
        return ParsedContent(tips: tips)
    }

    private static func parseHTML(_ html: String, sourceURL: URL) -> [TipItem] {
        var tips: [TipItem] = []
        if let title = html.firstHTMLTitle, !isNoiseLinkTitle(title) {
            tips.append(TipItem(
                id: stableID(["community-html-title", sourceURL.absoluteString, title]),
                title: title,
                body: "Community source page.",
                category: "Community",
                tags: ["community", "html"],
                sourceURL: sourceURL,
                sourceType: .community
            ))
        }

        let links = html.articleLinks(baseURL: sourceURL)
            .filter { !isNoiseLinkTitle($0.title) }
            .prefix(20)

        for link in links {
            let publishedAt = DateExtractor.date(in: link.title)
            tips.append(TipItem(
                id: stableID(["community-html-link", link.url.absoluteString, link.title]),
                title: link.title.removingTrailingDateText,
                body: "Community article from \(sourceURL.host ?? "source").",
                category: "Community",
                tags: ["community", "html"],
                shortcut: firstSlashCommand(in: link.title),
                sourceURL: link.url,
                sourceType: .community,
                publishedAt: publishedAt,
                updatedAt: publishedAt ?? Date()
            ))
        }
        return unique(tips)
    }

    private static func isNoiseLinkTitle(_ title: String) -> Bool {
        let normalized = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let exactNoise = [
            "skip to main content",
            "skip to footer",
            "start building",
            "try claude",
            "developer docs",
            "economic futures",
            "research",
            "news",
            "pricing",
            "availability",
            "privacy policy",
            "cookie policy",
            "terms of service",
            "responsible disclosure policy",
            "consumer health data privacy policy",
            "log in to claude",
            "see open roles"
        ]
        if exactNoise.contains(normalized) {
            return true
        }
        let footerPrefixes = [
            "products",
            "models",
            "solutions",
            "claude platform",
            "resources",
            "help and security",
            "company",
            "terms and policies"
        ]
        return footerPrefixes.contains { normalized == $0 }
    }
}

struct HeadingSection {
    var heading: String
    var body: String
}

extension String {
    var strippingMarkdown: String {
        replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
    }

    var firstMeaningfulSentence: String {
        let cleaned = components(separatedBy: .newlines)
            .map { $0.strippingMarkdownForDisplay.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                !line.isEmpty
                    && !line.hasPrefix("#")
                    && !line.hasPrefix("|")
                    && !line.hasPrefix("---")
                    && !line.isMDXTag
            } ?? ""
        if let period = cleaned.firstIndex(of: "."), cleaned.distance(from: cleaned.startIndex, to: period) > 30 {
            return String(cleaned[...period])
        }
        return cleaned
    }

    var strippingMarkdownForDisplay: String {
        self
            .replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isMDXTag: Bool {
        range(of: #"^</?[A-Z][A-Za-z0-9]*(\s+[^>]*)?>$"#, options: .regularExpression) != nil
    }

    var strippingMarkdownTableSyntax: String {
        self
            .replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: #"\\\|"#, with: "|", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\{/\*.*?\*/\}"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var commandTag: String {
        replacingOccurrences(of: "/", with: "")
            .components(separatedBy: CharacterSet(charactersIn: " <[|"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "command"
    }

    var isLikelyKeyboardShortcut: Bool {
        let lower = lowercased()
        if hasPrefix("/") {
            return true
        }
        if lower.contains("ctrl") || lower.contains("cmd") || lower.contains("shift") || lower.contains("tab") || lower.contains("esc") || lower.contains("enter") || lower.contains("return") {
            return true
        }
        if count == 1 {
            return unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
        }
        return contains("+")
    }

    var isMostlyPunctuation: Bool {
        let scalars = unicodeScalars.filter { !$0.properties.isWhitespace }
        guard !scalars.isEmpty else { return true }
        let punctuationCount = scalars.filter {
            CharacterSet.punctuationCharacters.contains($0) || CharacterSet.symbols.contains($0)
        }.count
        return Double(punctuationCount) / Double(scalars.count) > 0.55
    }

    var firstHTMLTitle: String? {
        guard let regex = try? NSRegularExpression(pattern: #"<title[^>]*>([\s\S]*?)</title>"#, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..<endIndex, in: self)),
              let range = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[range]).decodedHTMLText
    }

    func articleLinks(baseURL: URL) -> [(title: String, url: URL)] {
        guard let regex = try? NSRegularExpression(pattern: #"<a\b[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>"#, options: [.caseInsensitive]) else {
            return []
        }
        let matches = regex.matches(in: self, range: NSRange(startIndex..<endIndex, in: self))
        var seen: Set<String> = []
        return matches.compactMap { match in
            guard let hrefRange = Range(match.range(at: 1), in: self),
                  let titleRange = Range(match.range(at: 2), in: self) else {
                return nil
            }
            let title = String(self[titleRange]).strippingHTML.decodedHTMLText
            guard title.count >= 12 else { return nil }
            guard let url = URL(string: String(self[hrefRange]), relativeTo: baseURL)?.absoluteURL,
                  ["http", "https"].contains(url.scheme?.lowercased()) else {
                return nil
            }
            guard seen.insert(url.absoluteString).inserted else { return nil }
            return (title: title, url: url)
        }
    }

    var strippingHTML: String {
        replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var decodedHTMLText: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var removingTrailingDateText: String {
        replacingOccurrences(
            of: #"\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},\s+\d{4}$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func meaningfulMarkdownLines() -> [String] {
        components(separatedBy: .newlines)
            .map { $0.strippingMarkdownForDisplay }
            .filter { line in
                !line.isEmpty
                    && !line.isMDXTag
                    && !line.hasPrefix("#")
                    && !line.hasPrefix("|")
                    && !line.hasPrefix("---")
            }
    }

    func headingSections() -> [HeadingSection] {
        var sections: [HeadingSection] = []
        var currentHeading: String?
        var body: [String] = []

        func flush() {
            guard let currentHeading else { return }
            sections.append(HeadingSection(heading: currentHeading, body: body.joined(separator: "\n")))
        }

        for line in components(separatedBy: .newlines) {
            if line.hasPrefix("## ") || line.hasPrefix("### ") {
                flush()
                currentHeading = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                body = []
            } else if currentHeading != nil {
                body.append(line)
            }
        }
        flush()
        return sections
    }
}

func codeSpans(in text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: #"`([^`]+)`"#) else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap {
        guard let matchRange = Range($0.range(at: 1), in: text) else { return nil }
        return String(text[matchRange])
    }
}

func firstCodeSpan(in text: String) -> String? {
    codeSpans(in: text).first
}

func firstSlashCommand(in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"/[a-zA-Z][a-zA-Z0-9_-]*"#) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          let swiftRange = Range(match.range, in: text) else {
        return nil
    }
    return String(text[swiftRange])
}

func firstActionToken(in text: String) -> String? {
    let spans = codeSpans(in: text)
    return spans.first { $0.hasPrefix("/") || $0.hasPrefix("--") }
        ?? spans.first { $0.contains(".") }
        ?? firstSlashCommand(in: text)
        ?? spans.first
}

func markdownTableCells(from line: String) -> [String] {
    var cells: [String] = []
    var current = ""
    var previous: Character?
    var isInsideBackticks = false

    for character in line {
        if character == "`", previous != "\\" {
            isInsideBackticks.toggle()
        }

        if character == "|", previous != "\\", !isInsideBackticks {
            cells.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
            current = ""
        } else {
            current.append(character)
        }
        previous = character
    }

    cells.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
    guard cells.count >= 2 else { return [] }
    return Array(cells[1..<(cells.count - 1)])
}

func title(from body: String) -> String {
    let cleaned = body.strippingMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
    if let colon = cleaned.firstIndex(of: ":") {
        return String(cleaned[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let words = cleaned.split(separator: " ").prefix(9)
    return words.joined(separator: " ")
}

func stableID(_ parts: [String]) -> String {
    let joined = parts.joined(separator: "|")
    let scalarTotal = joined.unicodeScalars.reduce(UInt64(5381)) { result, scalar in
        ((result << 5) &+ result) &+ UInt64(scalar.value)
    }
    return String(scalarTotal, radix: 16)
}

func unique(_ tips: [TipItem]) -> [TipItem] {
    var seen: Set<String> = []
    return tips.filter { seen.insert($0.id).inserted }
}

extension URL {
    var humanReadableDocsURL: URL {
        guard absoluteString.hasPrefix("https://code.claude.com/docs/"),
              pathExtension == "md" else {
            return self
        }
        return deletingPathExtension()
    }
}

enum DateExtractor {
    static func date(in text: String) -> Date? {
        guard let range = text.range(
            of: #"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},\s+\d{4}"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }
        let candidate = String(text[range])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in ["MMM d, yyyy", "MMMM d, yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: candidate) {
                return date
            }
        }
        return nil
    }
}
