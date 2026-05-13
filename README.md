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

