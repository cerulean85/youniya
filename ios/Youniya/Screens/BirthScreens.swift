import SwiftUI

// MARK: - 61–64 Star birth

/// 61–64 별 탄생: a point of light gathers (0s), spreads (0.6s), takes shape
/// (1.2s) and settles (1.7s). Then "별 보기".
struct StarBirthView: View {
    @Environment(\.motionReduced) private var reduceMotion
    /// 별빛 없이 띄운 별: ends as a small, faint star in its mood's color.
    var unlitColor: Color? = nil
    var onShow: () -> Void

    @State private var phase = DebugScreen.is("62") ? 1 : 0

    private static let titles = ["마음을 모으는 중", "빛이 번져요", "별이 모양을 이뤄요", "별이 떴어요"]

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
                // Halo: gold, then violet as it takes shape, then gold again.
                Circle()
                    .fill((phase == 2 ? Color.brandPrimary : Color.starBright).opacity(0.16))
                    .frame(width: [0, 90, 140, 150][phase], height: [0, 90, 140, 150][phase])
                    .shadow(color: (phase == 2 ? Color.brandPrimary : Color.starBright).opacity(phase == 3 ? 0 : 0.45), radius: 14)
                let core = unlitColor ?? Color.starBright
                let sizes: [CGFloat] = unlitColor == nil ? [6, 16, 40, 48] : [6, 12, 20, 22]
                Circle()
                    .fill(core.opacity(phase == 0 ? 0.9 : (unlitColor == nil ? 1 : 0.7)))
                    .frame(width: sizes[phase], height: sizes[phase])
                    .shadow(color: core.opacity(phase == 0 ? 0 : (unlitColor == nil ? 0.5 : 0.25)), radius: 14)
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
            .frame(height: done ? 320 : 320)
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
                return
            }
            // Figma timeline: 0.0s · 0.6s first-light · 1.2s · 1.7s star-birth
            for (i, wait) in [0.6, 0.6, 0.5].enumerated() {
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: i == 2 ? 0.5 : 0.6)) { phase = i + 1 }
            }
            UIAccessibility.post(notification: .announcement, argument: "별이 떴어요")
        }
    }
}

#Preview("61–64") {
    StarBirthView(onShow: {})
}
