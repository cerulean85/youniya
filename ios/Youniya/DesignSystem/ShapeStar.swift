import SwiftUI

/// The shape a star takes from its writing (Figma `Star Shape`, 76/77, rule 61-1):
/// points and sharpness, plus how it is drawn there. The server decides it
/// with the starlight; the app draws what it gets.
struct StarShapeSpec: Hashable, Codable {
    enum Sharpness: Int, CaseIterable, Codable {
        case soft, normal, sharp

        var label: String {
            switch self {
            case .soft: "둥근"
            case .normal: "보통 뾰족함"
            case .sharp: "아주 뾰족함"
            }
        }

        /// Pull of each curve toward the center (Figma 보통 = 0.418 of the radius).
        var inner: CGFloat {
            switch self {
            case .soft: 0.55
            case .normal: 0.418
            case .sharp: 0.3
            }
        }
    }

    var points: Int
    var sharpness: Sharpness

    /// "꼭짓점 5개 · 보통 뾰족함"
    var label: String { "꼭짓점 \(points)개 · \(sharpness.label)" }

    init(points: Int, sharpness: Sharpness) {
        self.points = points
        self.sharpness = sharpness
    }
}

/// A star with `points` tips whose sides curve inward.
struct CurvedStar: Shape {
    var points: Int
    var inner: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let tips: [CGPoint] = (0..<points).map { i in
            let a = -CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / CGFloat(points)
            return CGPoint(x: cos(a) * r, y: sin(a) * r)
        }
        // Figma: control points = a·(near tip) + 0.085·(far tip), from the center.
        let far: CGFloat = 0.085
        return Path { p in
            p.move(to: CGPoint(x: c.x + tips[0].x, y: c.y + tips[0].y))
            for i in 0..<points {
                let t0 = tips[i], t1 = tips[(i + 1) % points]
                p.addCurve(
                    to: CGPoint(x: c.x + t1.x, y: c.y + t1.y),
                    control1: CGPoint(x: c.x + t0.x * inner + t1.x * far, y: c.y + t0.y * inner + t1.y * far),
                    control2: CGPoint(x: c.x + t1.x * inner + t0.x * far, y: c.y + t1.y * inner + t0.y * far)
                )
            }
            p.closeSubpath()
        }
    }
}

/// Figma `Star Shape`: halo, optional cross rays, gradient body, facet, glowing core.
struct ShapeStar: View {
    var spec: StarShapeSpec
    var color: Color
    var size: CGFloat
    var halo = true
    var rays = false

    var body: some View {
        let light = color.blend(.white, by: 0.8)
        let dark = color.blend(.black, by: 0.28)
        ZStack {
            if halo {
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: color.opacity(0.38), location: 0),
                        .init(color: color.opacity(0.12), location: 0.45),
                        .init(color: color.opacity(0), location: 1),
                    ], center: .center, startRadius: 0, endRadius: size * 1.15))
                    .frame(width: size * 2.3, height: size * 2.3)
            }
            if rays {
                ForEach([0.0, 90.0], id: \.self) { angle in
                    Capsule()
                        .fill(LinearGradient(colors: [light.opacity(0), light.opacity(0.8), light.opacity(0)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: size * 1.5, height: max(0.9, size / 60))
                        .rotationEffect(.degrees(angle))
                }
            }
            CurvedStar(points: spec.points, inner: spec.sharpness.inner)
                .fill(RadialGradient(stops: [
                    .init(color: light, location: 0),
                    .init(color: color, location: 0.5),
                    .init(color: dark, location: 1),
                ], center: .center, startRadius: 0, endRadius: size / 2))
                .overlay(CurvedStar(points: spec.points, inner: spec.sharpness.inner)
                    .stroke(color.blend(.white, by: 0.75).opacity(0.7), lineWidth: max(0.5, size * 0.017)))
                .frame(width: size, height: size)
            CurvedStar(points: spec.points, inner: spec.sharpness.inner)
                .fill(Color.white.opacity(0.2))
                .frame(width: size * 0.38, height: size * 0.38)
                .rotationEffect(.degrees(180 / Double(spec.points)))
            Circle().fill(.white)
                .frame(width: size * 0.16, height: size * 0.16)
                .shadow(color: color.blend(.white, by: 0.5).opacity(0.9), radius: size * 0.11)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 40) {
        ShapeStar(spec: .init(points: 4, sharpness: .normal), color: .emotionAnger, size: 32)
        ShapeStar(spec: .init(points: 5, sharpness: .sharp), color: .brandPrimary, size: 55, rays: true)
        ShapeStar(spec: .init(points: 6, sharpness: .soft), color: .starBright, size: 100, rays: true)
    }
    .padding(60)
    .background(Color.bgCanvas)
}

extension Color {
    /// Linear mix toward `other` (iOS 17 has no `Color.mix`).
    func blend(_ other: Color, by amount: CGFloat) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = min(1, max(0, amount))
        return Color(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t)
    }
}
