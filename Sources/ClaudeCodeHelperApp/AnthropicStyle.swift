import SwiftUI

enum AnthropicStyle {
    static let canvas = Color(hex: 0xfaf9f5)
    static let surfaceSoft = Color(hex: 0xf5f0e8)
    static let surfaceCard = Color(hex: 0xefe9de)
    static let surfaceStrong = Color(hex: 0xe8e0d2)
    static let surfaceDark = Color(hex: 0x181715)
    static let hairline = Color(hex: 0xe6dfd8)
    static let ink = Color(hex: 0x141413)
    static let body = Color(hex: 0x3d3d3a)
    static let muted = Color(hex: 0x6c6a64)
    static let mutedSoft = Color(hex: 0x8e8b82)
    static let primary = Color(hex: 0xcc785c)
    static let primaryActive = Color(hex: 0xa9583e)
    static let amber = Color(hex: 0xe8a55a)
    static let success = Color(hex: 0x5db872)
    static let warning = Color(hex: 0xd4a017)
    static let error = Color(hex: 0xc64545)

    static let displayFont = Font.custom("Times New Roman", size: 20)
    static let titleFont = Font.system(size: 15, weight: .semibold)
    static let bodyFont = Font.system(size: 13, weight: .regular)
    static let captionFont = Font.system(size: 12, weight: .medium)
    static let metadataFont = Font.system(size: 12, weight: .medium, design: .monospaced)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

struct AnthropicIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverableIconButton(configuration: configuration)
    }
}

private struct HoverableIconButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(isHovering || configuration.isPressed ? AnthropicStyle.primaryActive : AnthropicStyle.ink)
            .frame(width: 38, height: 38)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovering ? AnthropicStyle.primary.opacity(0.45) : AnthropicStyle.hairline, lineWidth: 1)
            )
            .shadow(color: isHovering ? AnthropicStyle.ink.opacity(0.08) : .clear, radius: 3, x: 0, y: 1)
            .onHover { isHovering = $0 }
    }

    private var background: Color {
        if configuration.isPressed {
            return AnthropicStyle.surfaceStrong
        }
        return isHovering ? AnthropicStyle.canvas : AnthropicStyle.surfaceCard
    }
}

struct AnthropicTabButton: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        HoverableTabButton(configuration: configuration, isSelected: isSelected)
    }
}

private struct HoverableTabButton: View {
    let configuration: ButtonStyle.Configuration
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isSelected ? AnthropicStyle.ink : (isHovering ? AnthropicStyle.primaryActive : AnthropicStyle.muted))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: 88)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected || isHovering ? AnthropicStyle.hairline : Color.clear, lineWidth: 1)
            )
            .onHover { isHovering = $0 }
    }

    private var background: Color {
        if configuration.isPressed {
            return AnthropicStyle.surfaceStrong
        }
        if isSelected {
            return AnthropicStyle.surfaceCard
        }
        return isHovering ? AnthropicStyle.surfaceCard.opacity(0.65) : Color.clear
    }
}

struct AnthropicCardActionButton: ButtonStyle {
    let isActive: Bool

    init(isActive: Bool = false) {
        self.isActive = isActive
    }

    func makeBody(configuration: Configuration) -> some View {
        HoverableCardActionButton(configuration: configuration, isActive: isActive)
    }
}

private struct HoverableCardActionButton: View {
    let configuration: ButtonStyle.Configuration
    let isActive: Bool
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(foreground)
            .frame(width: 30, height: 30)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isActive {
            return AnthropicStyle.primaryActive
        }
        return isHovering || configuration.isPressed ? AnthropicStyle.primaryActive : AnthropicStyle.muted
    }

    private var background: Color {
        if configuration.isPressed {
            return AnthropicStyle.surfaceStrong
        }
        return isHovering || isActive ? AnthropicStyle.primary.opacity(0.12) : Color.clear
    }
}

struct AnthropicDestructiveIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverableDestructiveIconButton(configuration: configuration)
    }
}

private struct HoverableDestructiveIconButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(isHovering || configuration.isPressed ? AnthropicStyle.error : AnthropicStyle.muted)
            .frame(width: 30, height: 30)
            .background(isHovering ? AnthropicStyle.error.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .onHover { isHovering = $0 }
    }
}

struct AnthropicTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(AnthropicStyle.bodyFont)
            .foregroundStyle(AnthropicStyle.ink)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(AnthropicStyle.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AnthropicStyle.hairline, lineWidth: 1)
            )
    }
}
