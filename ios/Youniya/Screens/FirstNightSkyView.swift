import SwiftUI

/// 03 First Night Sky: empty state before the first star.
struct FirstNightSkyView: View {
    var onCompose: () -> Void

    var body: some View {
        VStack(spacing: Space.xl) {
            SkyHeader(subtitle: "첫 별을 기다리고 있어요")

            VStack(spacing: Space.xl) {
                emptySlot

                VStack(spacing: Space.sm) {
                    Text("아직 떠 있는 별이 없어요")
                        .textStyle(.h3)
                        .foregroundStyle(Color.textPrimary)
                    Text("마음에 머무는 이야기를 적으면\n첫 별이 조용히 떠올라요.")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textSecondary)
                }
                .multilineTextAlignment(.center)

                Button("첫 별 만들기", action: onCompose)
                    .buttonStyle(.primary)

                Text("별 띄우기는 하루 한 번 무료예요")
                    .textStyle(.caption)
                    .foregroundStyle(Color.starBright)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xl)
    }

    private var emptySlot: some View {
        Circle()
            .strokeBorder(Color.brandPrimary, style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            .cosmos("empty-slot", in: Circle())
            .frame(width: 160, height: 160)
            .overlay {
                // 8:64: 2s, scale 1↔0.7, opacity 1↔0.3
                Image(.emptySlotStar)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .twinkle(
                        Twinkle(duration: 2, keys: [(0, 1), (0.255, 0.3), (0.63, 1), (1, 0.3)]),
                        scale: StarScale.dim
                    )
            }
            .accessibilityHidden(true)
    }
}

// MARK: - 03-1 Welcome

/// 03-1 첫 로그인 · 환영 안내: shown once over 03, right after sign-up.
struct WelcomeSheet: View {
    @Environment(\.skyTheme) private var theme
    var onCompose: () -> Void
    var onBrowse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("YOUNIYA에 오신 걸 환영해요").textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text("시작하기 전에 세 가지만 알려 드릴게요.").textStyle(.bodyM).foregroundStyle(Color.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Space.lg) {
                point(.iconStar, "쓴 마음은 단 하나뿐인 별이 돼요", "같은 모양의 별은 하나도 없어요.")
                point(.iconLock, "나누는 건 고른 한 문장뿐이에요", "우주 광장에는 익명으로, 내가 고른 한 줄만 올라가요.")
                point(.iconShield, "쓴 글은 AI 학습에 쓰이지 않아요", "언제든 모두 지울 수 있어요. 상담이나 진단을 대신하지는 않아요.")
            }

            VStack(spacing: Space.md) {
                Button("첫 별 만들기", action: onCompose).buttonStyle(.primary)
                Button("먼저 둘러볼게요", action: onBrowse).buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xxl)
    }

    /// Figma `Point`: a 40pt badge (accent tint 16%, 50% ring) and two lines.
    private func point(_ icon: ImageResource, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(icon).renderingMode(.template).resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 40, height: 40)
                .background(theme.accent.tint.opacity(0.16), in: .circle)
                .overlay(Circle().strokeBorder(theme.accent.tint.opacity(0.5), lineWidth: 1))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title)
                    .font(.custom("Pretendard-Medium", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.textPrimary)
                Text(detail).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    FirstNightSkyView(onCompose: {})
        .background(Color.bgCanvas)
}
