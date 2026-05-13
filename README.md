# Claude Code Helper

A native macOS menu bar app for quickly searching Claude Code shortcuts, commands, tips, and recent updates.

## What is implemented

- SwiftUI `MenuBarExtra` app with a compact searchable popover.
- Official/community source labeling.
- Copy snippet and open source URL actions.
- Local cache in the app support directory.
- Deterministic refresh pipeline using public Claude Code docs Markdown endpoints.
- Curated community source allowlist.
- Unit-tested parsers and changelog tip generation.

## Run locally

```bash
swift run ClaudeCodeHelper
```

The app is intended to be opened from Xcode for App Store packaging. The included entitlements enable the App Sandbox and outbound network access, with no shell execution or broad filesystem access.

## Test

```bash
swift test
```

## Contributing

Contributions are welcome. Good first areas include parser improvements, UI polish, source integrations, and tests for new documentation formats.

Before opening a pull request:

1. Fork the repo and create a focused branch.
2. Keep changes scoped to one feature or fix.
3. Add or update tests when changing parsers, ordering, persistence, or source import behavior.
4. Run `swift test` locally.
5. Describe what changed, how you tested it, and any source URLs or fixtures involved.

Please avoid adding command execution, shell automation, broad filesystem access, or private API dependencies without opening an issue first. The app is intended to stay App Store-friendly and user-trust-first.

## Roadmap

Possible future features:

- Remove, hide, or mark tips as read.
- AI curation for imported updates and community sources.
- Manual review queues for suggested tips before they enter search.
- Better social-source support through official APIs, RSS bridges, or pasted post URLs.
- Support for additional developer tools such as Codex, Cursor, and other coding agents.
- Sync pinned/read state across devices.
- Export and import custom tip collections.
- More source quality controls, including domain allowlists and duplicate detection.
