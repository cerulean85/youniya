import SwiftUI

/// 68 우주의 색: the three nebula colors used by `StarField` and `CosmosBackground`.
/// Violet is the default sky; the others come from the Figma theme swatches.
enum SkyTheme: String, CaseIterable, Identifiable, Codable {
    case violet, aurora, ember, ocean, rose

    var id: Self { self }

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

extension Color {
    static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

extension EnvironmentValues {
    /// The applied sky (68), injected at the root from `AppSettings.sky`.
    @Entry var skyTheme: SkyTheme = .violet
}
