import SwiftUI

/// Figma `Cosmos BG`: a faint nebula inside a card or sheet. Three soft radial
/// glows (violet, pink, cyan) plus scattered star dust. The layout comes from a
/// seed, so each surface gets its own sky but it never changes between renders.
struct CosmosBackground: View {
    var seed: String
    /// 1 for cards and sheets; Figma uses about half on buttons.
    var intensity: Double = 1

    var body: some View {
        Canvas { ctx, size in
            // Tuned so a 342×76 card matches the Figma render side by side.
            let intensity = intensity * 0.6
            var rng = SeededRandom(seed: seed)
            let w = size.width, h = size.height
            // Each glow covers ~90% of the height; wide shapes stretch horizontally.
            let ry = h * 0.9
            let rx = min(w * 0.9, max(w * 0.32, ry * 1.6))

            // (color, peak alpha × layer opacity) from the Figma fills
            let glows: [(Color, Double, ClosedRange<Double>, ClosedRange<Double>)] = [
                (.brandPrimary, 0.28 * 0.55, 0.2...0.4, 0.25...0.75),                   // violet
                (Color(red: 0xEC / 255, green: 0x48 / 255, blue: 0x99 / 255), 0.14 * 0.4, 0.65...0.9, 0.6...1.0), // pink
                (Color(red: 0x33 / 255, green: 0xB5 / 255, blue: 0xD9 / 255), 0.10 * 0.3, 0.5...0.9, 0.0...0.3),  // cyan
            ]
            for (color, alpha, xr, yr) in glows {
                let c = CGPoint(x: rng.next(in: xr) * w, y: rng.next(in: yr) * h)
                var layer = ctx
                layer.translateBy(x: c.x, y: c.y)
                layer.scaleBy(x: rx / ry, y: 1)
                layer.fill(
                    Path(ellipseIn: CGRect(x: -ry, y: -ry, width: ry * 2, height: ry * 2)),
                    with: .radialGradient(
                        Gradient(colors: [color.opacity(alpha * intensity), color.opacity(0)]),
                        center: .zero, startRadius: 0, endRadius: ry
                    )
                )
            }

            // Star dust: #E2E8F0, r 0.5–0.75, opacity 0.2–0.5 (about one per 900pt²)
            let count = Int((w * h) / 900)
            for _ in 0..<count {
                let r = rng.next(in: 0.5...0.75)
                let p = CGPoint(x: rng.next(in: 0...1) * w, y: rng.next(in: 0...1) * h)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                    with: .color(Color.textPrimary.opacity(rng.next(in: 0.2...0.5) * intensity))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Small deterministic generator (SplitMix64) seeded from a string.
struct SeededRandom {
    private var state: UInt64

    init(seed: String) {
        // FNV-1a hash of the seed
        var h: UInt64 = 0xcbf29ce484222325
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        state = h
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

extension View {
    /// Adds the Figma `Cosmos BG` behind this view, clipped to `shape`.
    func cosmos<S: Shape>(_ seed: String, in shape: S, intensity: Double = 1) -> some View {
        background {
            CosmosBackground(seed: seed, intensity: intensity).clipShape(shape)
        }
    }
}

/// Figma `Bottom Sheet` background: raised surface with a Cosmos BG.
struct SheetBackground: View {
    var seed: String

    var body: some View {
        Color.bgSurfaceRaised
            .overlay { CosmosBackground(seed: seed) }
    }
}

/// Figma `Star Glyph`: list star icon that turns clockwise, one turn per 12s.
/// Floated = violet, Kept = grey.
struct StarGlyph: View {
    var floated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let image = Image(floated ? .glyphFloatedSpin : .glyphKeptSpin)
            .resizable()
            .frame(width: 18.14, height: 18.14)
        Group {
            if reduceMotion {
                image
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // 4-fold symmetric, so 90° wraps seamlessly.
                    image.rotationEffect(.degrees((t * 30).truncatingRemainder(dividingBy: 90)))
                }
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 16) {
        RoundedRectangle(cornerRadius: 16).fill(Color.bgSurface)
            .frame(height: 76)
            .cosmos("a", in: RoundedRectangle(cornerRadius: 16))
        RoundedRectangle(cornerRadius: 24).fill(Color.bgSurfaceRaised)
            .frame(height: 300)
            .cosmos("sheet", in: RoundedRectangle(cornerRadius: 24))
        HStack { StarGlyph(floated: true); StarGlyph(floated: false) }
    }
    .padding()
    .background(Color.bgCanvas)
}
