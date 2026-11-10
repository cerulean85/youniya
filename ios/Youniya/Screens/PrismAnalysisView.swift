import SwiftUI

/// 06 별빛 프리즘 분석 (495:28064): the writing dims behind an orbit loader (three
/// dashed rings turning, a violet four-point star) and three stage chips
/// (별의 깊이 → 빛의 선명함 → 마음의 무게), each checked in turn. Plays once and
/// calls `onFinish`; `.reading` (live) keeps turning until the server answers.
///
/// 06-1 (552:14467): live, after 8 s the copy says it is taking a while and
/// 「그만두기」 appears (when `onStop` is set).
struct PrismAnalysisView: View {
    var analysis: StarAnalysis
    var onFinish: () -> Void
    /// 06-1 그만두기: shown while reading, after `slowAfter` seconds.
    var onStop: (() -> Void)? = nil
    /// Set while the stop is on its way, so it is pressed once.
    var stopping = false

    static let slowAfter: Double = 8

    @Environment(\.motionReduced) private var reduceMotion
    @State private var start = Date.now

    /// Total time on screen before moving on.
    private static let duration: Double = 4.2
    private static let stages = ["별의 깊이", "빛의 선명함", "마음의 무게"]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSince(start)
            content(t: t, slow: slow)
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
            guard analysis != .reading else {
                // 06-1: the slow copy and 그만두기 (the clock keeps running with reduced motion too).
                try? await Task.sleep(for: .seconds(DebugScreen.is("6-1") ? 0 : Self.slowAfter))
                guard !Task.isCancelled, onStop != nil else { return }
                withAnimation(.easeInOut(duration: 0.4)) { slow = true }
                UIAccessibility.post(notification: .announcement, argument: "조금 오래 걸리고 있어요")
                return
            }
            try? await Task.sleep(for: .seconds(reduceMotion ? 1.5 : Self.duration))
            guard !Task.isCancelled else { return }
            onFinish()
        }
    }

    @State private var slow = false

    private func content(t: Double, slow: Bool) -> some View {
        // Which stage is being read: one every 1.3 s (live: keeps cycling).
        let step = analysis == .reading ? Int(t / 1.3) % 3 : min(2, Int(t / 1.3))
        return VStack(spacing: Space.xl) {
            OrbitLoader(angle: reduceMotion ? 0 : t * 24)
                .frame(width: 220, height: 220)
                .accessibilityHidden(true)

            VStack(spacing: Space.md) {
                Text(slow ? "조금 오래 걸리고 있어요" : "별빛 프리즘이 마음의 결을 비추고 있어요")
                    .textStyle(.h3)
                    .foregroundStyle(Color.textPrimary)
                    .contentTransition(.opacity)
                Text(slow ? "기다리지 않아도 괜찮아요. 그만두면 별빛 없이\n띄워 두고, 오늘 무료와 코인은 쓰지 않아요."
                          : "별의 깊이 · 빛의 선명함 · 마음의 무게를\n부드럽게 살펴보는 중이에요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
                    .contentTransition(.opacity)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)

            HStack(spacing: Space.sm) {
                ForEach(Self.stages.indices, id: \.self) { i in
                    stageChip(Self.stages[i], done: i < step, current: i == step)
                }
            }
            .accessibilityHidden(true)

            if slow, let onStop {
                Button("그만두기", action: onStop)
                    .buttonStyle(.ghost)
                    .disabled(stopping)
                    .transition(.opacity)
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

#Preview {
    PrismAnalysisView(analysis: StarItem.samples[0].analysis!, onFinish: {})
}
