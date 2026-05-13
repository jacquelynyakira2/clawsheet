import ClaudeCodeHelperCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        TabView {
            refreshSettings
                .tabItem {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

            communitySettings
                .tabItem {
                    Label("Sources", systemImage: "link")
                }

            cacheSettings
                .tabItem {
                    Label("Cache", systemImage: "externaldrive")
                }
        }
        .padding(20)
        .background(AnthropicStyle.canvas)
    }

    private var refreshSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Refresh")
                .font(AnthropicStyle.displayFont)
                .foregroundStyle(AnthropicStyle.ink)

            Picker("Refresh interval", selection: Binding(
                get: { viewModel.snapshot.settings.refreshIntervalHours },
                set: { viewModel.setRefreshInterval($0) }
            )) {
                Text("Every 12 hours").tag(12)
                Text("Daily").tag(24)
                Text("Weekly").tag(168)
            }
            Text("Last refresh: \(viewModel.lastRefreshText)")
                .font(AnthropicStyle.captionFont)
                .foregroundStyle(AnthropicStyle.muted)

            Button {
                viewModel.refreshNow()
            } label: {
                Label("Refresh Now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(AnthropicStyle.primary)
            .disabled(viewModel.isRefreshing)
            Spacer()
        }
        .padding(20)
        .background(AnthropicStyle.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var communitySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Curated community sources")
                .font(AnthropicStyle.displayFont)
                .foregroundStyle(AnthropicStyle.ink)
            Text("Community tips are imported only from this allowlist and always appear with a Community badge.")
                .font(AnthropicStyle.bodyFont)
                .foregroundStyle(AnthropicStyle.body)
                .fixedSize(horizontal: false, vertical: true)
            Text("Verify a source to confirm how many tips were imported. Markdown bullet lists and article index pages work best; social profile pages often fetch successfully but import 0 tips.")
                .font(AnthropicStyle.captionFont)
                .foregroundStyle(AnthropicStyle.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("https://example.com/claude-code-tips.md", text: $viewModel.newCommunitySource)
                    .textFieldStyle(AnthropicTextFieldStyle())
                Button {
                    viewModel.addCommunitySource()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(AnthropicIconButton())
                .help("Add source")
            }

            List {
                ForEach(viewModel.snapshot.settings.communitySources) { source in
                    SourceStatusRow(source: source)
                        .environmentObject(viewModel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AnthropicStyle.canvas)
        }
        .padding(20)
        .background(AnthropicStyle.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cacheSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local cache")
                .font(AnthropicStyle.displayFont)
                .foregroundStyle(AnthropicStyle.ink)
            Text("Fetched docs, updates, and community tips are stored inside the app container. Clearing cache restores the bundled offline baseline tips.")
                .font(AnthropicStyle.bodyFont)
                .foregroundStyle(AnthropicStyle.body)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                viewModel.clearCachedContent()
            } label: {
                Text("Clear Cached Content")
            }

            Spacer()
        }
        .padding(20)
        .background(AnthropicStyle.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SourceStatusRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let source: SourceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(source.url.absoluteString)
                    .font(AnthropicStyle.bodyFont)
                    .foregroundStyle(AnthropicStyle.ink)
                    .lineLimit(1)
                Spacer()
                Button {
                    viewModel.refreshSource(source)
                } label: {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                }
                .buttonStyle(AnthropicCardActionButton(isActive: (source.lastImportCount ?? 0) > 0 && source.lastError == nil))
                .disabled(viewModel.isRefreshing)
                .help("Verify import")

                Button(role: .destructive) {
                    viewModel.removeCommunitySource(source)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(AnthropicDestructiveIconButton())
            }

            Text(statusText)
                .font(AnthropicStyle.captionFont)
                .foregroundStyle(source.lastError == nil ? AnthropicStyle.muted : AnthropicStyle.error)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        if let error = source.lastError, !error.isEmpty {
            return "Failed: \(error)"
        }
        if let count = source.lastImportCount {
            let fetched = source.lastFetchedAt?.formatted(date: .abbreviated, time: .shortened) ?? "just now"
            return "Verified: imported \(count) tips on \(fetched)"
        }
        return "Not verified yet"
    }

    private var statusIcon: String {
        if source.lastError != nil {
            return "xmark.circle.fill"
        }
        if let count = source.lastImportCount {
            return count > 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        }
        return "checkmark.circle"
    }

    private var statusColor: Color {
        if source.lastError != nil {
            return AnthropicStyle.error
        }
        if let count = source.lastImportCount {
            return count > 0 ? AnthropicStyle.success : AnthropicStyle.warning
        }
        return AnthropicStyle.muted
    }
}
