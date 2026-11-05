import SwiftUI
import CoreText

/// Spacing tokens from the Figma `Spacing` collection.
enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

/// Radius tokens from the Figma `Radius` collection.
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Text styles: Noto Serif KR for headings and journal text (as in Figma),
/// Pretendard in place of Figma's Noto Sans KR for UI text.
/// Each style scales with Dynamic Type via `relativeTo:`.
enum TextStyle {
    case display, metric, h1, h2, h3, journalBody, observation, bodyM, bodyS, labelM, labelS, caption, captionTab

    private var spec: (font: String, size: CGFloat, lineHeight: CGFloat, tracking: CGFloat, relativeTo: Font.TextStyle) {
        switch self {
        case .display: ("NotoSerifKR-SemiBold", 40, 52, 3.2, .largeTitle)
        case .metric: ("Pretendard-Light", 56, 64, -1, .largeTitle)
        case .observation: ("NotoSerifKR-Regular", 15, 24, 0, .callout)
        case .bodyS: ("Pretendard-Regular", 13, 20, 0, .footnote)
        case .h1: ("NotoSerifKR-SemiBold", 28, 38, -0.3, .title)
        case .h2: ("NotoSerifKR-Medium", 22, 32, -0.2, .title2)
        case .h3: ("NotoSerifKR-Medium", 18, 28, 0, .title3)
        case .journalBody: ("NotoSerifKR-Regular", 16, 30, 0, .body)
        case .bodyM: ("Pretendard-Regular", 14, 22, 0, .subheadline)
        case .labelM: ("Pretendard-Medium", 14, 20, 0, .subheadline)
        case .labelS: ("Pretendard-Medium", 12, 16, 0.2, .caption)
        case .caption: ("Pretendard-Regular", 12, 18, 0.2, .caption)
        // Figma `Caption/Tab`: tab bar labels and small notes.
        case .captionTab: ("Pretendard-Regular", 11, 16, 0.2, .caption2)
        }
    }

    var font: Font { .custom(spec.font, size: spec.size, relativeTo: spec.relativeTo) }
    var tracking: CGFloat { spec.tracking }
    /// Pads each font's natural line height up to the Figma line height.
    /// (Pretendard ≈ 1.19em, Noto Serif KR ≈ 1.45em.)
    var lineSpacing: CGFloat {
        let natural = UIFont(name: spec.font, size: spec.size)?.lineHeight ?? spec.size * 1.2
        return max(0, spec.lineHeight - natural)
    }
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}

enum AppFonts {
    /// Registers the bundled Noto KR fonts once at launch.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
