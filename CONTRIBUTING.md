# Contributing

Thanks for helping improve Clawsheet.

## Local setup

```bash
git clone https://github.com/jacquelynyakira2/clawsheet.git
cd clawsheet
swift test
swift run ClaudeCodeHelper
```

## Pull request workflow

1. Fork the repository.
2. Create a focused branch.
3. Make one feature or fix per pull request.
4. Add or update tests when changing parsers, refresh behavior, sorting, persistence, or source import logic.
5. Run `swift test`.
6. Open a pull request and fill out the template.

## Project guardrails

This app should stay user-trust-first and App Store-friendly.

Please open an issue before adding:

- Shell command execution
- Broad filesystem permissions
- Background collection of user data
- Private API integrations
- Network sources that blur official vs community content

Official and community content should remain visibly labeled.

## Good first contribution areas

- Parser fixtures for new Claude Code docs formats
- Better filtering for noisy community imports
- UI polish and accessibility fixes
- Tests for sorting and pinned/read-state behavior
- Documentation improvements

