import ClaudeCodeHelperCore
import Foundation
import Testing

@Suite("Markdown parsers")
struct ParserTests {
    @Test("Changelog parser creates tips for actionable updates and skips plain fixes")
    func changelogTipGeneration() throws {
        let source = SourceItem(
            sourceType: .official,
            url: OfficialSources.changelog,
            parserType: .changelogMarkdown
        )
        let parsed = MarkdownParsers.parse(try fixture("changelog"), source: source)

        #expect(parsed.updates.count == 2)
        #expect(parsed.tips.contains { $0.shortcut == "/goal" })
        #expect(parsed.tips.contains { $0.category == "Keyboard" })
        #expect(!parsed.tips.contains { $0.body.localizedCaseInsensitiveContains("deadlock") })
    }

    @Test("Command parser extracts slash commands")
    func commandParser() throws {
        let source = SourceItem(
            sourceType: .official,
            url: OfficialSources.commands,
            parserType: .commandsMarkdown
        )
        let parsed = MarkdownParsers.parse(try fixture("commands"), source: source)

        #expect(parsed.tips.count == 3)
        #expect(parsed.tips.map(\.shortcut).contains("/plan [description]"))
        #expect(parsed.tips.map(\.shortcut).contains("/model [model]"))
        #expect(parsed.tips.allSatisfy { $0.category == "Commands" })
        #expect(parsed.tips.allSatisfy { $0.sourceType == .official })
    }

    @Test("Keybinding parser extracts keyboard-oriented rows")
    func keybindingParser() throws {
        let source = SourceItem(
            sourceType: .official,
            url: OfficialSources.keybindings,
            parserType: .keybindingsMarkdown
        )
        let parsed = MarkdownParsers.parse(try fixture("keybindings"), source: source)

        #expect(parsed.tips.contains { $0.shortcut?.contains("Ctrl+O") == true })
        #expect(parsed.tips.contains { $0.shortcut?.contains("/keybindings") == true })
        #expect(!parsed.tips.contains { $0.title == "!" || $0.title == "?" })
    }

    @Test("Best practice parser creates guide tips")
    func bestPracticeParser() throws {
        let source = SourceItem(
            sourceType: .official,
            url: OfficialSources.bestPractices,
            parserType: .bestPracticesMarkdown
        )
        let parsed = MarkdownParsers.parse(try fixture("best-practices"), source: source)

        #expect(parsed.tips.count == 4)
        #expect(parsed.tips.contains { $0.title == "Use focused prompts" })
        #expect(parsed.tips.contains { $0.title == "Use subagents for investigation" && $0.body == "Delegate broad research to subagents before implementation." })
        #expect(!parsed.tips.contains { $0.body == "<Tip>" || $0.body == "<Steps>" })
    }

    @Test("What's New parser extracts update cards")
    func whatsNewParser() throws {
        let source = SourceItem(
            sourceType: .official,
            url: OfficialSources.whatsNew,
            parserType: .whatsNewMarkdown
        )
        let parsed = MarkdownParsers.parse(try fixture("whats-new"), source: source)

        #expect(parsed.tips.count == 2)
        #expect(parsed.updates.count == 2)
        #expect(parsed.tips.contains { $0.title == "Week 19" && $0.category == "What's New" })
        #expect(parsed.tips.contains { $0.shortcut == "--plugin-dir" })
        #expect(!parsed.tips.contains { $0.body.localizedCaseInsensitiveContains("Read the Week") })
        #expect(parsed.tips.first { $0.title == "Week 19" }?.sourceURL.absoluteString == "https://code.claude.com/docs/en/whats-new/2026-w19")
        #expect(parsed.tips.first { $0.title == "Week 19" }?.publishedAt != nil)
    }

    @Test("Search orders What's New by newest date")
    func whatsNewOrdering() {
        let older = TipItem(
            title: "Week 18",
            body: "Older update",
            category: "What's New",
            tags: ["whats-new"],
            sourceURL: OfficialSources.whatsNew,
            sourceType: .official,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = TipItem(
            title: "Week 19",
            body: "Newer update",
            category: "What's New",
            tags: ["whats-new"],
            sourceURL: OfficialSources.whatsNew,
            sourceType: .official,
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let results = TipSearch.filter(tips: [older, newer], query: "", category: "What's New")
        #expect(results.map(\.title) == ["Week 19", "Week 18"])
    }

    @Test("Search orders cached What's New cards by week number when dates are missing")
    func whatsNewCachedOrdering() {
        let week13 = TipItem(
            title: "Week 13",
            body: "Older cached update",
            category: "What's New",
            tags: ["whats-new"],
            sourceURL: OfficialSources.whatsNew,
            sourceType: .official
        )
        let week15 = TipItem(
            title: "Week 15",
            body: "Newer cached update",
            category: "What's New",
            tags: ["whats-new"],
            sourceURL: OfficialSources.whatsNew,
            sourceType: .official
        )

        let results = TipSearch.filter(tips: [week13, week15], query: "", category: "What's New")
        #expect(results.map(\.title) == ["Week 15", "Week 13"])
    }

    @Test("Community parser imports basic HTML links")
    func communityHTMLParser() {
        let source = SourceItem(
            sourceType: .community,
            url: URL(string: "https://www.anthropic.com/engineering")!,
            parserType: .communityMarkdown
        )
        let html = """
        <html><head><title>Engineering \\ Anthropic</title></head>
        <body>
          <a href="/engineering/claude-code-auto-mode">Claude Code auto mode: a safer way to skip permissions</a>
          <a href="#main">Skip to main content</a>
          <a href="#footer">Skip to footer</a>
          <a href="/privacy">Privacy policy</a>
        </body></html>
        """
        let parsed = MarkdownParsers.parse(html, source: source)

        #expect(parsed.tips.contains { $0.title == "Engineering \\ Anthropic" })
        #expect(parsed.tips.contains { $0.title.contains("Claude Code auto mode") })
        #expect(!parsed.tips.contains { $0.title.contains("Privacy") })
        #expect(!parsed.tips.contains { $0.title.localizedCaseInsensitiveContains("Skip to") })
    }

    @Test("Community parser ignores cookie shell title pages")
    func communityCookieShellParser() {
        let source = SourceItem(
            sourceType: .community,
            url: URL(string: "https://x.com/claude_code")!,
            parserType: .communityMarkdown
        )
        let html = "<html><head><title>Cookie Policy</title></head><body></body></html>"
        let parsed = MarkdownParsers.parse(html, source: source)

        #expect(parsed.tips.isEmpty)
    }

    @Test("Community search orders dated article cards newest first")
    func communityOrdering() {
        let older = TipItem(
            title: "Old article",
            body: "Community article",
            category: "Community",
            tags: ["community"],
            sourceURL: URL(string: "https://example.com/old")!,
            sourceType: .community,
            publishedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = TipItem(
            title: "New article",
            body: "Community article",
            category: "Community",
            tags: ["community"],
            sourceURL: URL(string: "https://example.com/new")!,
            sourceType: .community,
            publishedAt: Date(timeIntervalSince1970: 200)
        )

        let results = TipSearch.filter(tips: [older, newer], query: "", category: "Community")
        #expect(results.map(\.title) == ["New article", "Old article"])
    }

    @Test("Search prefers official content before community content")
    func searchOrdering() {
        let now = Date()
        let official = TipItem(
            title: "Use /plan",
            body: "Plan first",
            category: "Commands",
            tags: ["plan"],
            shortcut: "/plan",
            sourceURL: OfficialSources.commands,
            sourceType: .official,
            createdAt: now,
            updatedAt: now
        )
        let community = TipItem(
            title: "Community /plan tip",
            body: "Community plan note",
            category: "Community",
            tags: ["plan"],
            shortcut: "/plan",
            sourceURL: URL(string: "https://example.com/tips.md")!,
            sourceType: .community,
            createdAt: now,
            updatedAt: now.addingTimeInterval(100)
        )

        let results = TipSearch.filter(tips: [community, official], query: "plan", category: "All")
        #expect(results.first?.sourceType == .official)
    }

    @Test("All feed uses stable category priority")
    func allCategoryPriority() {
        let now = Date()
        let keyboard = TipItem(
            title: "Keyboard",
            body: "Shortcut",
            category: "Keyboard",
            tags: [],
            sourceURL: OfficialSources.keybindings,
            sourceType: .official,
            updatedAt: now.addingTimeInterval(100)
        )
        let bestPractice = TipItem(
            title: "Best Practice",
            body: "Guide",
            category: "Best Practice",
            tags: [],
            sourceURL: OfficialSources.bestPractices,
            sourceType: .official,
            updatedAt: now
        )

        let results = TipSearch.filter(tips: [keyboard, bestPractice], query: "", category: "All")
        #expect(results.map(\.category) == ["Best Practice", "Keyboard"])
    }

    @Test("Pinned tips sort above normal category priority")
    func pinnedTipsSortFirst() {
        let pinned = TipItem(
            id: "pin-me",
            title: "Pinned Keyboard",
            body: "Shortcut",
            category: "Keyboard",
            tags: [],
            sourceURL: OfficialSources.keybindings,
            sourceType: .official
        )
        let normal = TipItem(
            id: "normal",
            title: "Normal Best Practice",
            body: "Guide",
            category: "Best Practice",
            tags: [],
            sourceURL: OfficialSources.bestPractices,
            sourceType: .official
        )

        let results = TipSearch.filter(tips: [normal, pinned], query: "", category: "All", pinnedTipIDs: ["pin-me"])
        #expect(results.map(\.id) == ["pin-me", "normal"])
    }

    private func fixture(_ name: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "md"))
        return try String(contentsOf: url, encoding: .utf8)
    }
}
