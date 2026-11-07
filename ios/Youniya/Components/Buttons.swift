import SwiftUI

/// Figma `Button` · Style=Primary: vertical violet gradient with a soft glow.
/// Pressed uses the Hover variant gradient.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.skyTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        // 68: the gradient follows the chosen sky; violet keeps its Hover variant.
        let a = theme.accent
        let colors: [Color] = configuration.isPressed
            ? (theme == .violet ? [.primaryHoverGradientStart, .primaryHoverGradientEnd] : [a.bottom, a.bottom])
            : [a.top, a.bottom]
        configuration.label
            .textStyle(.labelM)
            .foregroundStyle(isEnabled ? Color.textOnBrand : Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.md)
            // Figma `Button`: 48pt tall
            .frame(minHeight: 48)
            .background {
                // Figma State=Disabled: flat #334155, no glow.
                if isEnabled {
                    LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                        .clipShape(.rect(cornerRadius: Radius.md))
                } else {
                    RoundedRectangle(cornerRadius: Radius.md).fill(Color.borderDefault)
                }
            }
            // brand/primary-glow: the theme tint @ 40%, blur 24
            .shadow(color: a.tint.opacity(isEnabled ? 0.4 : 0), radius: 12)
            .contentShape(.rect(cornerRadius: Radius.md))
    }
}

/// Figma `Button` · Style=Secondary: violet outline, violet label.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md)
        configuration.label
            .textStyle(.labelM)
            .foregroundStyle(Color.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.md)
            // Figma `Button`: 48pt tall
            .frame(minHeight: 48)
            // Figma: Secondary buttons carry a faint Cosmos BG (about half strength).
            .cosmos("secondary", in: shape, intensity: 0.55)
            .background(configuration.isPressed ? Color.tintPrimary : .clear, in: shape)
            .overlay(shape.strokeBorder(Color.brandPrimary, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(shape)
    }
}

/// Figma `Button` · Style=Ghost: text only, secondary color.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.labelM)
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.md)
            // Figma `Button`: 48pt tall
            .frame(minHeight: 48)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(.rect)
    }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { .init() }
}

/// Top bar used by full-screen flows: "닫기" · centered title · trailing accessory.
struct FlowTopBar<Trailing: View>: View {
    var title: String
    var closeLabel: String = "닫기"
    var onClose: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            Text(title)
                .textStyle(.labelM)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(closeLabel, action: onClose)
                    .textStyle(.labelM)
                    .foregroundStyle(Color.textSecondary)
                    .buttonStyle(.plain)
                Spacer()
                trailing()
            }
        }
        .frame(height: 20)
    }
}

/// Figma `Top App Bar`: back chevron, centered title, empty trailing slot.
struct TopAppBar: View {
    var title: String
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image(.iconBack)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            Text(title)
                .textStyle(.labelM)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Space.md)
        .frame(height: 52)
    }
}

extension FlowTopBar where Trailing == EmptyView {
    init(title: String, closeLabel: String = "닫기", onClose: @escaping () -> Void) {
        self.init(title: title, closeLabel: closeLabel, onClose: onClose) { EmptyView() }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { .init() }
}

/// Figma `Button` · Style=Danger: red gradient (#F98B8B → #E35D5D) with a red glow.
/// For irreversible actions such as "영구 삭제".
struct DangerButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        // Figma Danger (updated): #BC5457 → #A5202A
        let top = Color(red: 0xBC / 255, green: 0x54 / 255, blue: 0x57 / 255)
        let bottom = Color(red: 0xA5 / 255, green: 0x20 / 255, blue: 0x2A / 255)
        configuration.label
            .textStyle(.labelM)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.md)
            .frame(minHeight: 48)
            .background(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom),
                        in: .rect(cornerRadius: Radius.md))
            // #F87171 @ 40%, blur 24
            .shadow(color: Color(red: 0xF8 / 255, green: 0x71 / 255, blue: 0x71 / 255).opacity(0.4), radius: 12)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(.rect(cornerRadius: Radius.md))
    }
}

extension ButtonStyle where Self == DangerButtonStyle {
    static var danger: DangerButtonStyle { .init() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { .init() }
}

/// Figma `Social Button` (Apple · Google).
struct SocialButton: View {
    enum Provider { case apple, google }
    var provider: Provider
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                switch provider {
                case .apple:
                    Image(.logoApple).resizable().frame(width: 20, height: 20)
                    Text("Apple로 계속하기")
                case .google:
                    Image(.logoGoogle).resizable().frame(width: 18, height: 18)
                    Text("Google로 계속하기")
                }
            }
            .textStyle(.labelM)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(SocialButtonStyle(provider: provider))
    }
}

private struct SocialButtonStyle: ButtonStyle {
    var provider: SocialButton.Provider

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md)
        configuration.label
            .foregroundStyle(provider == .apple ? Color.bgCanvas : Color.textPrimary)
            .background {
                if provider == .google { CosmosBackground(seed: "google").clipShape(shape) }
            }
            .background(provider == .apple ? Color.textPrimary : Color.bgSurface, in: shape)
            .overlay {
                if provider == .google { shape.strokeBorder(Color.borderDefault, lineWidth: 1) }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(shape)
    }
}

/// Figma `Menu Button`: 40pt circle with three lines.
struct MenuButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.textSecondary)
                        .frame(width: 16, height: 2)
                }
            }
            .frame(width: 40, height: 40)
            .background(Color.bgSurface, in: .circle)
            .overlay(Circle().strokeBorder(Color.borderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("메뉴")
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("첫 별 만들기") {}.buttonStyle(.primary)
        SocialButton(provider: .apple) {}
        SocialButton(provider: .google) {}
        MenuButton {}
    }
    .padding(24)
    .background(Color.bgCanvas)
}
