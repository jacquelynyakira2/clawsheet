import ClaudeCodeHelperCore
import AppKit
import SwiftUI

@main
struct ClaudeCodeHelperApp: App {
    @StateObject private var viewModel = AppViewModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(viewModel)
                .frame(width: 460, height: 640)
        } label: {
            Image(systemName: "curlybraces.square.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AnthropicStyle.primary)
                .help("Claude Code Helper")
        }
        .menuBarExtraStyle(.window)
    }
}
