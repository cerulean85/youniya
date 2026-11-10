import SwiftUI

/// 08 캔버스 배경 (사용자 시안): soft violet and pink nebula glows with a little
/// star dust behind the nebula.
struct NebulaGlowBackground: View {
    @Environment(\.skyTheme) private var theme

    var body: some View {
        // 14.7: the glows are the sky's glow/a·b·c.
        let (a, b, c) = theme.colors
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color.bgSurface
                RadialGradient(colors: [a.opacity(0.38), .clear],
                               center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: max(w, h) * 0.55)
                RadialGradient(colors: [b.opacity(0.16), .clear],
                               center: UnitPoint(x: 0.15, y: 0.85), startRadius: 0, endRadius: w * 0.6)
                RadialGradient(colors: [c.opacity(0.1), .clear],
                               center: UnitPoint(x: 0.85, y: 0.2), startRadius: 0, endRadius: w * 0.5)
                ForEach(0..<46, id: \.self) { i in
                    var rng = SeededRandom(seed: "nebula-dust-\(i)")
                    let x = rng.next(in: 0...1), y = rng.next(in: 0...1)
                    let size = rng.next(in: 1...2.2), alpha = rng.next(in: 0.2...0.7)
                    Circle().fill(Color.textPrimary.opacity(alpha))
                        .frame(width: size, height: size)
                        .position(x: x * w, y: y * h)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

