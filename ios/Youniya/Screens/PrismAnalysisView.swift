import SwiftUI

/// 06 Prism Analysis: light enters the prism and splits into seven emotion beams,
/// then the three axes fill in. Plays once (Figma's 2s timeline, extended so every
/// beam finishes) and calls `onFinish`.
struct PrismAnalysisView: View {
    var analysis: StarAnalysis
    var onFinish: () -> Void

    @Environment(\.motionReduced) private var reduceMotion
    @State private var start = Date.now

    /// Total time on screen before moving to the card.
    private static let duration: Double = 4.2

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            // Progress on the Figma 2s timeline (1.0 = 2s). Beams run past 1.0.
            let p = reduceMotion ? 2 : context.date.timeIntervalSince(start) / 2
            content(p: p, now: context.date.timeIntervalSinceReferenceDate)
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StarField() }
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(reduceMotion ? 1.5 : Self.duration))
            guard !Task.isCancelled else { return }
            onFinish()
        }
    }

    private func content(p: Double, now: Double) -> some View {
        VStack(spacing: Space.xxl) {
            statusChip(now: now)
                .frame(maxWidth: .infinity, alignment: .leading)

            PrismStage(p: p, now: now)
                .fitCanvas(width: 342, height: 300, alignment: .center)
                .accessibilityHidden(true)

            VStack(spacing: Space.sm) {
                Text("별빛 프리즘이 마음의 결을 비추고 있어요")
                    .textStyle(.h3)
                    .foregroundStyle(Color.textPrimary)
                    .rise(Anim.ramp(p, 0.8, 1.0))
                Text("별의 깊이 · 빛의 선명함 · 마음의 무게를\n부드럽게 살펴보는 중이에요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
                    .rise(Anim.ramp(p, 0.95, 1.15))
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            measuring(p: p)

            Text("쓴 글은 암호화되어 안전하게 보존돼요")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
                .rise(Anim.ramp(p, 1.0, 1.2))
        }
    }

    private func statusChip(now: Double) -> some View {
        HStack(spacing: 6) {
            Image(.prismLiveDot)
                .resizable()
                .frame(width: 21, height: 21)
                .frame(width: 7, height: 7)
                .opacity(reduceMotion ? 1 : Twinkle(duration: 2, keys: [(0, 1), (0.4, 0.25), (0.8, 1), (1, 0.25)]).opacity(at: now))
            Text("별빛 프리즘 분석 중")
                .textStyle(.labelS)
                .foregroundStyle(Color.brandPrimaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.tintPrimary, in: .capsule)
        .accessibilityElement(children: .combine)
    }

    private func measuring(p: Double) -> some View {
        let fill = Anim.easeOut(Anim.ramp(p, 1.1, 1.8))
        return VStack(spacing: Space.md) {
            AxisMeter(label: "별의 깊이", value: analysis.depth * fill)
            AxisMeter(label: "빛의 선명함", value: analysis.clarity * fill)
            AxisMeter(label: "마음의 무게", value: analysis.weight * fill)
        }
        .padding(Space.lg)
        .cosmos("measuring", in: RoundedRectangle(cornerRadius: Radius.lg))
        .background(
            LinearGradient(
                stops: [.init(color: .bgSurfaceRaised, location: 0), .init(color: .bgSurface, location: 0.714)],
                startPoint: UnitPoint(x: 0.35, y: 0), endPoint: UnitPoint(x: 0.65, y: 1)
            ),
            in: .rect(cornerRadius: Radius.lg)
        )
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
        .rise(Anim.ramp(p, 1.0, 1.2))
    }
}

/// Timing helpers for the prism timeline.
enum Anim {
    /// 0 before `a`, 1 after `b`, linear in between.
    static func ramp(_ p: Double, _ a: Double, _ b: Double) -> Double {
        min(1, max(0, (p - a) / (b - a)))
    }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    /// Slight overshoot, like Figma's cubic-bezier(0.45, 1.45, 0.8, 1).
    static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

private extension View {
    /// Fade in while rising 14pt, driven by `t` (0...1).
    func rise(_ t: Double) -> some View {
        let e = Anim.easeOut(t)
        return opacity(e).offset(y: 14 * (1 - e))
    }

    /// Reveal from the leading edge, like Figma's path trim.
    func revealLeading(_ t: Double) -> some View {
        mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle().frame(width: geo.size.width * t)
            }
        }
    }
}

/// Figma `Prism Stage` (342×300), positions from the design.
private struct PrismStage: View {
    var p: Double
    var now: Double

    /// One beam per emotion marker, bottom (평온) to top (분노).
    private struct Beam {
        var spectrum: ImageResource, end: ImageResource, ring: ImageResource, glyph: ImageResource, leader: ImageResource
        var spectrumSize: CGSize, nodeSize: CGSize
        var endOrigin: CGPoint
        var markerY: CGFloat
        var leaderNode: CGRect, leaderSize: CGSize
        var label: String
    }

    private let beams: [Beam] = [
        Beam(spectrum: .prismSpectrum0, end: .prismBeamEnd0, ring: .prismRing0, glyph: .prismGlyph0, leader: .prismLeader0,
             spectrumSize: CGSize(width: 85.8285, height: 62.931), nodeSize: CGSize(width: 84.947, height: 61.717),
             endOrigin: CGPoint(x: 256.95, y: 214.72), markerY: 266,
             leaderNode: CGRect(x: 258.95, y: 216.72, width: 35.053, height: 63.283), leaderSize: CGSize(width: 35.7093, height: 63.646), label: "평온"),
        Beam(spectrum: .prismSpectrum1, end: .prismBeamEnd1, ring: .prismRing1, glyph: .prismGlyph1, leader: .prismLeader1,
             spectrumSize: CGSize(width: 89.8399, height: 56.9136), nodeSize: CGSize(width: 89.045, height: 55.642),
             endOrigin: CGPoint(x: 261.05, y: 208.64), markerY: 236,
             leaderNode: CGRect(x: 263.05, y: 210.64, width: 30.955, height: 39.358), leaderSize: CGSize(width: 31.5445, height: 39.8221), label: "슬픔"),
        Beam(spectrum: .prismSpectrum2, end: .prismBeamEnd2, ring: .prismRing2, glyph: .prismGlyph2, leader: .prismLeader2,
             spectrumSize: CGSize(width: 93.4137, height: 50.6189), nodeSize: CGSize(width: 92.709, height: 49.295),
             endOrigin: CGPoint(x: 264.71, y: 202.29), markerY: 206,
             leaderNode: CGRect(x: 266.71, y: 204.29, width: 27.291, height: 15.705), leaderSize: CGSize(width: 27.6646, height: 16.3555), label: "불안"),
        Beam(spectrum: .prismSpectrum3, end: .prismBeamEnd3, ring: .prismRing3, glyph: .prismGlyph3, leader: .prismLeader3,
             spectrumSize: CGSize(width: 96.5324, height: 44.0777), nodeSize: CGSize(width: 95.922, height: 42.707),
             endOrigin: CGPoint(x: 267.92, y: 195.71), markerY: 176,
             leaderNode: CGRect(x: 269.92, y: 190, width: 24.078, height: 7.707), leaderSize: CGSize(width: 24.3064, height: 8.42164), label: "안도"),
        Beam(spectrum: .prismSpectrum4, end: .prismBeamEnd4, ring: .prismRing4, glyph: .prismGlyph4, leader: .prismLeader4,
             spectrumSize: CGSize(width: 99.1808, height: 37.3217), nodeSize: CGSize(width: 98.668, height: 35.912),
             endOrigin: CGPoint(x: 270.67, y: 188.91), markerY: 146,
             leaderNode: CGRect(x: 272.67, y: 160, width: 21.332, height: 30.912), leaderSize: CGSize(width: 21.9496, height: 31.3381), label: "통찰"),
        Beam(spectrum: .prismSpectrum5, end: .prismBeamEnd5, ring: .prismRing5, glyph: .prismGlyph5, leader: .prismLeader5,
             spectrumSize: CGSize(width: 101.346, height: 30.3838), nodeSize: CGSize(width: 100.932, height: 28.942),
             endOrigin: CGPoint(x: 272.93, y: 181.94), markerY: 116,
             leaderNode: CGRect(x: 274.93, y: 130, width: 19.068, height: 53.942), leaderSize: CGSize(width: 19.7746, height: 54.1919), label: "기대"),
        Beam(spectrum: .prismSpectrum6, end: .prismBeamEnd6, ring: .prismRing6, glyph: .prismGlyph6, leader: .prismLeader6,
             spectrumSize: CGSize(width: 103.017, height: 23.2979), nodeSize: CGSize(width: 102.705, height: 21.831),
             endOrigin: CGPoint(x: 274.71, y: 174.83), markerY: 86,
             leaderNode: CGRect(x: 276.71, y: 100, width: 17.295, height: 76.831), leaderSize: CGSize(width: 18.0262, height: 76.9954), label: "분노"),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Bloom: 0 → 0.6 (60%) → 1
            img(.prismBloom, center: CGPoint(x: 148, y: 165), size: CGSize(width: 360, height: 360))
                .opacity(p < 0.6 ? 0.6 * Anim.easeOut(Anim.ramp(p, 0, 0.6)) : 0.6 + 0.4 * Anim.easeInOut(Anim.ramp(p, 0.6, 1)))

            // Incoming beam traces in (0–45%)
            img(.prismBeamIncoming, center: CGPoint(x: 33.75, y: 135), size: CGSize(width: 68.4943, height: 23.3558))
                .revealLeading(Anim.easeOut(Anim.ramp(p, 0, 0.45)))

            // Prism fades in (0–30%) and settles from 0.94 scale (0–40%)
            img(.prismBody, center: CGPoint(x: 118, y: 124.875), size: CGSize(width: 155.885, height: 135.75))
                .opacity(Anim.easeOut(Anim.ramp(p, 0, 0.3)))
                .scaleEffect(0.94 + 0.06 * Anim.easeOut(Anim.ramp(p, 0, 0.4)))

            img(.prismEdge, center: CGPoint(x: 118, y: 125), size: CGSize(width: 0.75, height: 136))
                .opacity(edgeOpacity)

            // Beam inside the prism (40–70%)
            img(.prismBeamInside, center: CGPoint(x: 120.75, y: 150), size: CGSize(width: 106.664, height: 11.7423))
                .revealLeading(Anim.easeOut(Anim.ramp(p, 0.4, 0.7)))

            ForEach(beams.indices, id: \.self) { i in
                beam(beams[i], index: i)
            }
        }
    }

    private var edgeOpacity: Double {
        if p < 0.45 { return 0 }
        if p < 0.7 { return Anim.easeOut(Anim.ramp(p, 0.45, 0.7)) }
        if p < 1 { return 1 - 0.6 * Anim.easeInOut(Anim.ramp(p, 0.7, 1)) }
        return 0.9
    }

    @ViewBuilder
    private func beam(_ b: Beam, index i: Int) -> some View {
        // Each beam starts 80ms (on the 2s timeline) after the previous one.
        let start = 0.5 + 0.08 * Double(i)
        let trace = Anim.easeOut(Anim.ramp(p, start, start + 0.4))
        let arrived = Anim.ramp(p, start + 0.4, start + 0.5)
        let pop = Anim.easeOutBack(arrived)

        img(b.spectrum, center: CGPoint(x: 174 + b.nodeSize.width / 2, y: 155 + b.nodeSize.height / 2), size: b.spectrumSize)
            .revealLeading(trace)
        img(b.end, center: CGPoint(x: b.endOrigin.x + 2, y: b.endOrigin.y + 2), size: CGSize(width: 4, height: 4))
            .opacity(arrived)
        img(b.leader, center: CGPoint(x: b.leaderNode.midX, y: b.leaderNode.midY), size: b.leaderSize)
            .opacity(arrived)

        // Emotion marker: ring (pulses once settled) + glyph
        ZStack {
            Image(b.ring).resizable().frame(width: 28, height: 28)
                .opacity(0.775 + 0.225 * cos(now * .pi))
            Image(b.glyph).resizable().frame(width: 15.2, height: 15.2)
        }
        .scaleEffect(0.85 + 0.15 * pop)
        .opacity(arrived)
        .position(x: 310, y: b.markerY + 14)
    }

    private func img(_ r: ImageResource, center: CGPoint, size: CGSize) -> some View {
        Image(r)
            .resizable()
            .frame(width: size.width, height: size.height)
            .position(center)
    }
}

#Preview {
    PrismAnalysisView(analysis: StarItem.samples[0].analysis!, onFinish: {})
}
