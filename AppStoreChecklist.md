# App Store Packaging Checklist

- Open the package in Xcode after accepting the Apple SDK license.
- Create a macOS app scheme for `ClaudeCodeHelper`.
- Apply `ClaudeCodeHelper.entitlements` to the app target.
- Ensure App Sandbox and outgoing network client access are enabled.
- Keep `LSUIElement` enabled in the Xcode app target so the app is menu bar-only; the Swift Package runtime also sets `.accessory` for local runs.
- Confirm the app does not request shell, automation, full disk access, or user-selected file permissions.
- Add final app icon, bundle identifier, signing team, privacy nutrition labels, and screenshots before submission.

## Verification

```bash
swift test --scratch-path /private/tmp/ClaudeCodeHelper-build
swift run --scratch-path /private/tmp/ClaudeCodeHelper-build ClaudeCodeHelper
```

If the local toolchain reports an Xcode license error, run this once in Terminal:

```bash
sudo xcodebuild -license
```
