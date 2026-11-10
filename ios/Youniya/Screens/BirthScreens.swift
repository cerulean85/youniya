import SwiftUI

// MARK: - 61–64 Star birth

/// 61–64 별 탄생 (478:13896, rule 61-1): a point of light gathers (0s), spreads
/// (0.3s), takes this star's shape, faint in its mood's color (0.8s), and
/// settles clear (1.1–1.7s). Then "별 보기" shows the same star.
/// 별빛 없이 띄운 별: a small light in its mood's color. No shape from the
/// server: the gold light as before. Reduced motion: the last scene only.
struct StarBirthView: View {
    @Environment(\.motionReduced) private var reduceMotion
    /// The server's shape; nil ends on a plain light.
    var shape: StarShapeSpec? = nil
    /// The first mood's color.
    var color: Color = .starBright
    /// 별빛 없이 띄운 별: a small, faint light, no shape.
    var unlit = false
    var onShow: () -> Void

    @State private var phase = DebugScreen.is("62") ? 1 : DebugScreen.is("63") ? 2 : 0

    private static let titles = ["마음을 모으는 중", "빛이 번져요", "별이 모양을 이뤄요", "별이 떴어요"]

    private var shaped: StarShapeSpec? { unlit ? nil : shape }

    var body: some View {
        let done = phase == 3
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0).frame(maxHeight: done ? 24 : 199)

            Text(Self.titles[phase])
                .textStyle(.h2)
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)

            ZStack {
                if let shaped {
                    shapedStar(shaped)
                } else {
                    plainLight
                }
                if done {
                    Circle().fill(Color.starClear).frame(width: 6, height: 6)
                        .shadow(color: Color.starClear.opacity(0.4), radius: 10)
                        .offset(x: -84, y: -82)
                        .transition(.opacity)
                    Circle().fill(Color.brandWarm).frame(width: 5, height: 5)
                        .shadow(color: Color.brandWarm.opacity(0.35), radius: 12)
                        .offset(x: 87, y: 68)
                        .transition(.opacity)
                }
            }
            .frame(height: 320)
            .accessibilityHidden(true)

            Spacer(minLength: 0)

            Button("별 보기", action: onShow)
                .buttonStyle(.primary)
                .opacity(done ? 1 : 0)
                .disabled(!done)
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StarField() }
        .task {
            if reduceMotion {
                phase = 3
                UIAccessibility.post(notification: .announcement, argument: "별이 떴어요")
                return
            }
            guard phase == 0 else { return }
            // Figma 61: 0.0s gathers · 0.3s spreads · 0.8s takes shape · 1.1–1.7s settles.
            for (i, wait) in [0.3, 0.5, 0.3].enumerated() {
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: i == 2 ? 0.6 : 0.4)) { phase = i + 1 }
            }
            UIAccessibility.post(notification: .announcement, argument: "별이 떴어요")
        }
    }

    /// Gold light → violet ring holding the faint shape → the clear shape.
    private func shapedStar(_ spec: StarShapeSpec) -> some View {
        ZStack {
            // 0.3s: a gold light. 0.8s: a violet ring around the forming star.
            Circle()
                .fill((phase == 2 ? Color.brandPrimary : Color.starBright).opacity(phase == 2 ? 0.32 : 0.4))
                .frame(width: [6, 90, 140, 140][phase], height: [6, 90, 140, 140][phase])
                .shadow(color: (phase == 2 ? Color.brandPrimary : Color.starBright).opacity(0.5), radius: 14)
                .opacity(phase == 3 ? 0 : 1)
            if phase == 1 {
                Circle().fill(Color.starBright).frame(width: 16, height: 16)
                    .shadow(color: Color.starBright.opacity(0.6), radius: 10)
                    .transition(.opacity)
            }
            if phase >= 2 {
                ShapeStar(spec: spec, color: color, size: phase == 3 ? 120 : 64, halo: phase == 3)
                    .opacity(phase == 3 ? 1 : 0.55)
                    .shadow(color: color.opacity(phase == 3 ? 0.5 : 0), radius: 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
    }

    /// No shape (older servers): the gold light as before. Unlit: a small,
    /// faint light in its mood's color.
    private var plainLight: some View {
        let core = unlit ? color : Color.starBright
        let sizes: [CGFloat] = unlit ? [6, 12, 20, 22] : [6, 16, 40, 48]
        return ZStack {
            Circle()
                .fill((phase == 2 ? Color.brandPrimary : Color.starBright).opacity(0.16))
                .frame(width: [0, 90, 140, 150][phase], height: [0, 90, 140, 150][phase])
                .shadow(color: (phase == 2 ? Color.brandPrimary : Color.starBright).opacity(phase == 3 ? 0 : 0.45), radius: 14)
            Circle()
                .fill(core.opacity(phase == 0 ? 0.9 : (unlit ? 0.7 : 1)))
                .frame(width: sizes[phase], height: sizes[phase])
                .shadow(color: core.opacity(phase == 0 ? 0 : (unlit ? 0.25 : 0.5)), radius: 14)
        }
    }
}

#Preview("61–64") {
    StarBirthView(onShow: {})
}
