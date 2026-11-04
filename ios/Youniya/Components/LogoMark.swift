import SwiftUI

/// Figma `Logo Mark`: dashed circle with a glowing violet star that breathes.
struct LogoMark: View {
    enum Size { case large, small }
    var size: Size

    var body: some View {
        let d: CGFloat = size == .large ? 112 : 56
        ZStack {
            Circle()
                .strokeBorder(Color.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: d, height: d)
            switch size {
            case .large:
                // Splash star (8:13): 6s, scale 1↔1.08, opacity 1↔0.75
                Image(.logoStarLarge)
                    .resizable()
                    .frame(width: 95.04, height: 95.04)
                    .twinkle(
                        Twinkle(duration: 6, keys: [(0, 1), (0.16667, 0.75), (0.47, 1), (0.77167, 0.75), (1, 1)]),
                        scale: { o in 1 + (1 - o) * 0.32 }
                    )
            case .small:
                // Login star (8:34): 2s, scale 1↔0.7, opacity 1↔0.3
                Image(.logoStarSmall)
                    .resizable()
                    .frame(width: 71.52, height: 71.52)
                    .twinkle(
                        Twinkle(duration: 2, keys: [(0, 1), (0.06, 0.3), (0.55, 1), (1, 0.3)]),
                        scale: StarScale.dim
                    )
            }
        }
        .frame(width: d, height: d)
        .accessibilityHidden(true)
    }
}

enum StarScale {
    /// Figma stars shrink to 0.7 while fading to 0.3 opacity.
    static let dim: (Double) -> Double = { o in 0.7 + (o - 0.3) * (0.3 / 0.7) }
}

#Preview {
    HStack(spacing: 32) {
        LogoMark(size: .large)
        LogoMark(size: .small)
    }
    .padding()
    .background(Color.bgCanvas)
}
