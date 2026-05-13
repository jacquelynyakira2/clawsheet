import ClaudeCodeHelperCore
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            filters
            results
            footer
        }
        .background(AnthropicStyle.canvas)
        .onAppear {
            viewModel.refreshIfDue()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Text("✣")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AnthropicStyle.ink)
                    Text("Claude Code Helper")
                        .font(AnthropicStyle.displayFont)
                        .foregroundStyle(AnthropicStyle.ink)
                }
                Spacer()
                Button {
                    viewModel.refreshNow()
                } label: {
                    Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .buttonStyle(AnthropicIconButton())
                .disabled(viewModel.isRefreshing)
                .help("Refresh now")

                Button {
                    viewModel.openSettingsWindow()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(AnthropicIconButton())
                .help("Settings")
            }

            TextField("Search commands, keyboard shortcuts, tips, updates...", text: $viewModel.query)
                .textFieldStyle(AnthropicTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(AnthropicStyle.canvas)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories, id: \.self) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        Text(category)
                    }
                    .buttonStyle(AnthropicTabButton(isSelected: viewModel.selectedCategory == category))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .background(AnthropicStyle.canvas)
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.filteredTips.isEmpty {
                    ContentUnavailableView(
                        "No matching tips",
                        systemImage: "magnifyingglass",
                        description: Text("Try another command, keyboard shortcut, or category.")
                    )
                    .padding(.top, 80)
                } else {
                    ForEach(viewModel.filteredTips) { tip in
                        TipCard(tip: tip)
                    }
                }
            }
            .padding(14)
            .padding(.top, 0)
        }
        .background(AnthropicStyle.canvas)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(viewModel.statusMessage.isEmpty ? viewModel.lastRefreshText : viewModel.statusMessage)
                .foregroundStyle(AnthropicStyle.muted)
                .lineLimit(1)
            Spacer()
            Text("\(viewModel.filteredTips.count) results")
                .foregroundStyle(AnthropicStyle.muted)
        }
        .font(AnthropicStyle.captionFont)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AnthropicStyle.canvas)
    }
}

struct TipCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let tip: TipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.title)
                        .font(AnthropicStyle.titleFont)
                        .foregroundStyle(AnthropicStyle.ink)
                        .lineLimit(2)
                    if let detailText {
                        Text(detailText)
                            .font(AnthropicStyle.captionFont)
                            .foregroundStyle(AnthropicStyle.muted)
                    }
                }
                Spacer(minLength: 8)
                SourceBadge(sourceType: tip.sourceType)
            }

            Text(tip.body)
                .font(AnthropicStyle.bodyFont)
                .foregroundStyle(AnthropicStyle.body)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let shortcut = tip.shortcut {
                    Text(shortcut)
                        .font(AnthropicStyle.metadataFont)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(AnthropicStyle.ink)
                        .background(AnthropicStyle.surfaceStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Text(tip.category)
                    .font(AnthropicStyle.metadataFont)
                    .foregroundStyle(AnthropicStyle.muted)

                Spacer()

                Button {
                    viewModel.togglePinned(tip)
                } label: {
                    Image(systemName: viewModel.isPinned(tip) ? "pin.fill" : "pin")
                        .rotationEffect(.degrees(viewModel.isPinned(tip) ? -45 : 0))
                }
                .buttonStyle(AnthropicCardActionButton(isActive: viewModel.isPinned(tip)))
                .help(viewModel.isPinned(tip) ? "Unpin" : "Pin")

                Button {
                    viewModel.copy(tip)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(AnthropicCardActionButton())
                .help("Copy")

                Button {
                    viewModel.openSource(tip)
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(AnthropicCardActionButton())
                .help("Open source")
            }
        }
        .padding(14)
        .background(AnthropicStyle.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AnthropicStyle.hairline, lineWidth: 1)
        )
    }

    private var detailText: String? {
        if tip.category == "What's New", let publishedAt = tip.publishedAt {
            return publishedAt.formatted(date: .abbreviated, time: .omitted)
        }
        if let version = tip.version, !version.isEmpty {
            return version
        }
        return nil
    }
}

struct SourceBadge: View {
    let sourceType: SourceType

    var body: some View {
        Text(sourceType == .official ? "Official" : "Community")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(sourceType == .official ? AnthropicStyle.ink : AnthropicStyle.primaryActive)
            .background(sourceType == .official ? AnthropicStyle.surfaceCard : AnthropicStyle.primary.opacity(0.14))
            .clipShape(Capsule())
    }
}
