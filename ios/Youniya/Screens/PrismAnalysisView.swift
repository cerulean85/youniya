import SwiftUI

/// 06 별빛 프리즘 분석 (495:28064): the writing dims behind an orbit loader (three
/// dashed rings turning, a violet four-point star) and three stage chips
/// (별의 깊이 → 빛의 선명함 → 마음의 무게), each checked in turn. Plays once and
/// calls `onFinish`; `.reading` (live) keeps turning until the server answers.
struct PrismAnalysisView: View {
    var analysis: StarAnalysis
    var onFinish: () -> Void

    @Environment(\.motionReduced) private var reduceMotion
    @State private var start = Date.now

    /// Total time on screen before moving on.
    private static let duration: Double = 4.2
    private static let stages = ["별의 깊이", "빛의 선명함", "마음의 무게"]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSince(start)
            content(t: t)
        }
        .padding(.horizontal, Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                StarField()
                Color.bgCanvas.opacity(0.78).ignoresSafeArea()
            }
        }
        .task {
            start = .now
            guard analysis != .reading else { return }
            try? await Task.sleep(for: .seconds(reduceMotion ? 1.5 : Self.duration))
            guard !Task.isCancelled else { return }
            onFinish()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("별빛 프리즘이 마음의 결을 비추고 있어요")
    }

    private func content(t: Double) -> some View {
        // Which stage is being read: one every 1.3 s (live: keeps cycling).
        let step = analysis == .reading ? Int(t / 1.3) % 3 : min(2, Int(t / 1.3))
        return VStack(spacing: Space.xl) {
            OrbitLoader(angle: reduceMotion ? 0 : t * 24)
                .frame(width: 220, height: 220)
                .accessibilityHidden(true)

            VStack(spacing: Space.md) {
                Text("별빛 프리즘이 마음의 결을 비추고 있어요")
                    .textStyle(.h3)
                    .foregroundStyle(Color.textPrimary)
                Text("별의 깊이 · 빛의 선명함 · 마음의 무게를\n부드럽게 살펴보는 중이에요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.sm) {
                ForEach(Self.stages.indices, id: \.self) { i in
                    stageChip(Self.stages[i], done: i < step, current: i == step)
                }
            }
        }
    }

    /// Done: a check; current: violet; still to come: grey.
    private func stageChip(_ title: String, done: Bool, current: Bool) -> some View {
        HStack(spacing: 6) {
            if done {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.emotionCalm)
            } else {
                Circle().fill(current ? Color.brandPrimaryText : Color.textTertiary).frame(width: 6, height: 6)
            }
            Text(title)
                .textStyle(.labelS)
                .foregroundStyle(current || done ? Color.textPrimary : Color.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(current ? Color.tintPrimary : Color.bgSurface, in: .capsule)
        .overlay(Capsule().strokeBorder(current ? Color.brandPrimary : Color.borderDefault, lineWidth: 1))
        .animation(.easeInOut(duration: 0.3), value: current)
    }
}

/// 06 `Orbit`: three dashed rings (cyan, pink, violet), each with a small
/// body, turning at their own pace around a violet four-point star.
private struct OrbitLoader: View {
    var angle: Double

    var body: some View {
        ZStack {
            ring(1.0, .starClear, dot: .starClear, at: -90, speed: 1)
            ring(0.77, .brandWarm, dot: .brandWarm, at: 0, speed: -1.4)
            ring(0.55, .brandPrimary, dot: .starBright, at: 150, speed: 1.9)
            ShapeStar(spec: StarShapeSpec(points: 4, sharpness: .sharp), color: .brandPrimary, size: 44, halo: false)
                .shadow(color: Color.brandPrimary.opacity(0.6), radius: 10)
        }
    }

    private func ring(_ k: CGFloat, _ color: Color, dot: Color, at start: Double, speed: Double) -> some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2 * k
            let a = (start + angle * speed) * .pi / 180
            ZStack {
                Circle()
                    .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                    .frame(width: r * 2, height: r * 2)
                Circle().fill(dot).frame(width: 9, height: 9)
                    .offset(x: cos(a) * r, y: sin(a) * r)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
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

#Preview {
    PrismAnalysisView(analysis: StarItem.samples[0].analysis!, onFinish: {})
}
