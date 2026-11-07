import SwiftUI

/// 68 우주의 색: the three nebula colors used by `StarField` and `CosmosBackground`.
/// Violet is the default sky; the others come from the Figma theme swatches.
enum SkyTheme: String, CaseIterable, Identifiable, Codable {
    case violet, aurora, ember, ocean, rose

    var id: Self { self }

    /// v1.0: the free skies on 68. The others come with the membership (v1.1).
    static let free: [SkyTheme] = [.violet, .ocean]
    var isFree: Bool { Self.free.contains(self) }

    var name: String {
        switch self {
        case .violet: "보랏빛 별밤"
        case .aurora: "오로라 숲"
        case .ember: "잔불 노을"
        case .ocean: "깊은 바다"
        case .rose: "장미빛 새벽"
        }
    }

    var detail: String {
        switch self {
        case .violet: "차분하고 깊은 기본 밤하늘"
        case .aurora: "맑고 서늘한 초록빛 하늘"
        case .ember: "따뜻하게 식어가는 저녁빛"
        case .ocean: "고요하게 가라앉는 푸른 밤"
        case .rose: "부드럽게 밝아오는 분홍빛"
        }
    }

    /// Main, second and third glow (Figma swatch ellipses, largest first).
    var colors: (Color, Color, Color) {
        switch self {
        case .violet: (.hex(0x8B5CF6), .hex(0xEC4899), .hex(0x33B5D9))
        case .aurora: (.hex(0x10B981), .hex(0x2DD4BF), .hex(0x3B82F6))
        case .ember: (.hex(0xF97316), .hex(0xF43F5E), .hex(0xFBBF24))
        case .ocean: (.hex(0x3B82F6), .hex(0x6366F1), .hex(0x22D3EE))
        case .rose: (.hex(0xEC4899), .hex(0xA855F7), .hex(0xFB923C))
        }
    }
}

/// The theme's accent (Figma "Themes · 우주의 색", values from each 04 Home / 77).
/// The tab bar's gold selection and the card surfaces stay the same in every theme.
struct SkyAccent {
    /// Primary button and FAB gradient, top to bottom.
    var top: Color
    var bottom: Color
    /// Badge fill (at 16%) and the buttons' glow (at 40%).
    var tint: Color
    /// Badge and selected-chip border, 77 lines, the filled zoom button, links.
    var strong: Color
}

extension SkyTheme {
    var accent: SkyAccent {
        switch self {
        case .violet: SkyAccent(top: .hex(0x855ADE), bottom: .hex(0x6630CE), tint: .hex(0x8B5CF6), strong: .hex(0x8555EF))
        case .aurora: SkyAccent(top: .hex(0x008473), bottom: .hex(0x005448), tint: .hex(0x0E9F8E), strong: .hex(0x008475))
        case .ember: SkyAccent(top: .hex(0xC15336), bottom: .hex(0xB82500), tint: .hex(0xE0603E), strong: .hex(0xCA4B29))
        case .ocean: SkyAccent(top: .hex(0x3672D5), bottom: .hex(0x004ED2), tint: .hex(0x3B82F6), strong: .hex(0x2970E3))
        case .rose: SkyAccent(top: .hex(0xC94086), bottom: .hex(0xBD006B), tint: .hex(0xDB3F8C), strong: .hex(0xD13584))
        }
    }
}

extension Color {
    static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

extension EnvironmentValues {
    /// The applied sky (68), injected at the root from `AppSettings.sky`.
    @Entry var skyTheme: SkyTheme = .violet
}
