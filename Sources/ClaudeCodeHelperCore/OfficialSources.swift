import Foundation

public enum OfficialSources {
    public static let docsIndex = URL(string: "https://code.claude.com/docs/llms.txt")!
    public static let whatsNew = URL(string: "https://code.claude.com/docs/en/whats-new.md")!
    public static let changelog = URL(string: "https://code.claude.com/docs/en/changelog.md")!
    public static let commands = URL(string: "https://code.claude.com/docs/en/commands.md")!
    public static let interactiveMode = URL(string: "https://code.claude.com/docs/en/interactive-mode.md")!
    public static let keybindings = URL(string: "https://code.claude.com/docs/en/keybindings.md")!
    public static let bestPractices = URL(string: "https://code.claude.com/docs/en/best-practices.md")!

    public static let defaultSources: [SourceItem] = [
        SourceItem(sourceType: .official, url: whatsNew, parserType: .whatsNewMarkdown),
        SourceItem(sourceType: .official, url: changelog, parserType: .changelogMarkdown),
        SourceItem(sourceType: .official, url: commands, parserType: .commandsMarkdown),
        SourceItem(sourceType: .official, url: interactiveMode, parserType: .keybindingsMarkdown),
        SourceItem(sourceType: .official, url: keybindings, parserType: .keybindingsMarkdown),
        SourceItem(sourceType: .official, url: bestPractices, parserType: .bestPracticesMarkdown)
    ]
}
