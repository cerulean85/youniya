import SwiftUI

/// Draws a `MonthConstellation` (08-3, 04 card, 70/77): lines in gold when both
/// ends are filled, otherwise faint dashes; filled places as mood-colored stars
/// (lit ones larger and glowing, unlit ones small and faint); empty places as
/// dashed rings; extra stars floating faintly around the figure.
struct ConstellationFigureView: View {
    var constellation: MonthConstellation
    var compact = false
    /// 77: the picked place, ringed.
    var selected: UUID? = nil
    var onTap: ((MonthConstellation.Star) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let pts = constellation.slots.map { CGPoint(x: rect.minX + $0.point.x * rect.width, y: rect.minY + $0.point.y * rect.height) }
            let k: CGFloat = compact ? 0.6 : 1
            ZStack(alignment: .topLeading) {
                // Waiting lines first, then the gold ones over them.
                Path { p in
                    for l in constellation.lines where !constellation.isLit(l) && l.count == 2 && l.allSatisfy({ $0 < pts.count }) {
                        p.move(to: pts[l[0]]); p.addLine(to: pts[l[1]])
                    }
                }
                .stroke(Color.textTertiary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                Path { p in
                    for l in constellation.lines where constellation.isLit(l) {
                        p.move(to: pts[l[0]]); p.addLine(to: pts[l[1]])
                    }
                }
                .stroke(Color.starBright.opacity(0.6), lineWidth: compact ? 0.8 : 1.2)

                ForEach(Array(constellation.extra.enumerated()), id: \.element.id) { i, s in
                    dot(s, k: k * 0.7, faint: true)
                        .position(Self.extraPoint(i, in: rect, month: constellation.month))
                }

                ForEach(pts.indices, id: \.self) { i in
                    Group {
                        if let s = constellation.slots[i].star {
                            dot(s, k: k)
                        } else {
                            Circle()
                                .strokeBorder(Color.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                .frame(width: 9 * k, height: 9 * k)
                        }
                    }
                    .position(pts[i])
                }
            }
        }
    }

    @ViewBuilder private func dot(_ s: MonthConstellation.Star, k: CGFloat, faint: Bool = false) -> some View {
        // Lit stars grow with their starlight; unlit ones stay small and dim.
        let size: CGFloat = s.hasStarlight ? (9 + 6 * min(1, CGFloat(s.starlight ?? 500) / 999)) * k : 7 * k
        let color = s.mood.color
        ZStack {
            if s.id == selected {
                Circle().strokeBorder(Color.starBright, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .frame(width: size * 2.6, height: size * 2.6)
            }
            Circle()
                .fill(color.opacity(faint ? 0.45 : (s.hasStarlight ? 1 : 0.6)))
                .frame(width: size, height: size)
                .shadow(color: color.opacity(s.hasStarlight && !faint ? 0.8 : 0), radius: 6 * k)
        }
        .frame(width: 32, height: 32)
        .contentShape(.circle)
        .onTapGesture { onTap?(s) }
        .allowsHitTesting(onTap != nil)
        .accessibilityElement()
        .accessibilityLabel("\(s.title), \(s.hasStarlight ? "별빛 \(s.starlight ?? 0)" : "별빛 없는 별")")
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }

    /// Extra stars sit on a steady ring around the figure, by month.
    static func extraPoint(_ i: Int, in rect: CGRect, month: String) -> CGPoint {
        var rng = SeededRandom(seed: "extra-\(month)-\(i)")
        let a = rng.next(in: 0...(2 * .pi))
        let r = rng.next(in: 0.42...0.48)
        return CGPoint(x: rect.midX + cos(a) * rect.width * r, y: rect.midY + sin(a) * rect.height * r)
    }
}
