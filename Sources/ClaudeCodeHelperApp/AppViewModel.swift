import AppKit
import ClaudeCodeHelperCore
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var snapshot: HelperSnapshot
    @Published var query = ""
    @Published var selectedCategory = "All"
    @Published var isRefreshing = false
    @Published var statusMessage = ""
    @Published var newCommunitySource = ""

    private let store: any HelperStore
    private let refreshService = RefreshService()
    private var settingsWindowController: NSWindowController?

    init() {
        do {
            let store = try SQLiteStore()
            self.store = store
            self.snapshot = try store.load()
        } catch {
            fatalError("Unable to initialize local store: \(error)")
        }
    }

    var filteredTips: [TipItem] {
        TipSearch.filter(
            tips: snapshot.tips,
            query: query,
            category: selectedCategory,
            pinnedTipIDs: snapshot.settings.pinnedTipIDs
        )
    }

    var categories: [String] {
        TipSearch.categories(in: snapshot.tips)
    }

    var lastRefreshText: String {
        guard let date = snapshot.settings.lastRefreshAt else { return "Never refreshed" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    func refreshIfDue() {
        guard !isRefreshing else { return }
        guard let lastRefreshAt = snapshot.settings.lastRefreshAt else {
            refreshNow()
            return
        }
        let interval = TimeInterval(snapshot.settings.refreshIntervalHours * 60 * 60)
        if Date().timeIntervalSince(lastRefreshAt) >= interval {
            refreshNow()
        }
    }

    func refreshNow() {
        guard !isRefreshing else { return }
        isRefreshing = true
        statusMessage = "Refreshing official and curated sources..."
        Task {
            do {
                let (nextSnapshot, result) = try await refreshService.refresh(snapshot: snapshot)
                snapshot = nextSnapshot
                try store.save(nextSnapshot)
                let failures = result.failedSourceCount > 0 ? ", \(result.failedSourceCount) failed" : ""
                statusMessage = "Fetched \(result.fetchedSourceCount) sources, imported \(result.importedTipCount) tips\(failures)."
            } catch {
                statusMessage = "Refresh failed: \(error.localizedDescription)"
            }
            isRefreshing = false
        }
    }

    func copy(_ tip: TipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tip.shortcut ?? tip.body, forType: .string)
        statusMessage = "Copied \(tip.shortcut ?? "tip")"
    }

    func openSource(_ tip: TipItem) {
        NSWorkspace.shared.open(tip.sourceURL.humanReadableDocsURL)
    }

    func isPinned(_ tip: TipItem) -> Bool {
        snapshot.settings.pinnedTipIDs.contains(tip.id)
    }

    func togglePinned(_ tip: TipItem) {
        if snapshot.settings.pinnedTipIDs.contains(tip.id) {
            snapshot.settings.pinnedTipIDs.removeAll { $0 == tip.id }
            snapshot.settings.pinSelectionCustomized = true
            persist("Unpinned \(tip.title).")
        } else {
            snapshot.settings.pinnedTipIDs.insert(tip.id, at: 0)
            snapshot.settings.pinSelectionCustomized = true
            persist("Pinned \(tip.title).")
        }
    }

    func openSettingsWindow() {
        if let settingsWindowController {
            settingsWindowController.window?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView()
            .environmentObject(self)
            .frame(width: 640, height: 500)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Claude Code Helper Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func addCommunitySource() {
        let trimmed = newCommunitySource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https" else {
            statusMessage = "Enter a valid https URL."
            return
        }
        guard !snapshot.settings.communitySources.contains(where: { $0.url == url }) else {
            statusMessage = "That source is already in the allowlist."
            return
        }
        let source = SourceItem(
            sourceType: .community,
            url: url,
            parserType: .communityMarkdown
        )
        snapshot.settings.communitySources.append(source)
        newCommunitySource = ""
        persist("Added community source. Verifying import...")
        refreshSource(source)
    }

    func removeCommunitySource(_ source: SourceItem) {
        snapshot.settings.communitySources.removeAll { $0.id == source.id }
        persist("Removed community source.")
    }

    func refreshSource(_ source: SourceItem) {
        guard !isRefreshing else { return }
        isRefreshing = true
        statusMessage = "Verifying \(source.url.host ?? "source")..."
        var testSnapshot = snapshot
        if source.sourceType == .community {
            testSnapshot.settings.communitySources = [source]
        }
        Task {
            do {
                let (nextSnapshot, result) = try await refreshService.refresh(snapshot: testSnapshot, includeOfficialSources: source.sourceType == .official)
                if source.sourceType == .community,
                   let testedSource = nextSnapshot.sources.first(where: { $0.id == source.id }) {
                    if let index = snapshot.settings.communitySources.firstIndex(where: { $0.id == source.id }) {
                        snapshot.settings.communitySources[index] = testedSource
                    }
                    snapshot.sources.removeAll { $0.id == source.id }
                    snapshot.sources.append(testedSource)
                    try store.save(snapshot)
                    let failures = result.failedSourceCount > 0 ? "failed" : "imported \(testedSource.lastImportCount ?? 0) tips"
                    statusMessage = "Source verification \(failures)."
                } else {
                    snapshot = nextSnapshot
                    try store.save(nextSnapshot)
                    statusMessage = "Source verification imported \(result.importedTipCount) tips."
                }
            } catch {
                statusMessage = "Source verification failed: \(error.localizedDescription)"
            }
            isRefreshing = false
        }
    }

    func setRefreshInterval(_ hours: Int) {
        snapshot.settings.refreshIntervalHours = hours
        persist("Updated refresh interval.")
    }

    func clearCachedContent() {
        do {
            snapshot = try store.reset()
            selectedCategory = "All"
            query = ""
            statusMessage = "Cleared cache and restored baseline tips."
        } catch {
            statusMessage = "Clear failed: \(error.localizedDescription)"
        }
    }

    private func persist(_ message: String) {
        do {
            try store.save(snapshot)
            statusMessage = message
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
