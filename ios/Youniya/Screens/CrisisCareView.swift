import SwiftUI

/// On-device first check for words that may signal a crisis. It only decides
/// whether to show 37 Crisis Care; the entry is always saved as written.
/// TODO: Replace with a reviewed server-side classifier and keyword list.
enum CrisisSignal {
    private static let phrases = [
        "죽고 싶", "죽고싶", "자살", "자해", "사라지고 싶", "사라지고싶", "없어지고 싶", "없어지고싶",
        "살기 싫", "살기싫", "살고 싶지 않", "살고싶지 않", "삶을 끝", "끝내고 싶", "극단적 선택",
        "목숨을 끊", "뛰어내리", "suicide", "kill myself", "want to die", "end my life", "self-harm", "self harm",
    ]

    static func detected(in text: String) -> Bool {
        let t = text.lowercased()
        return phrases.contains { t.contains($0) }
    }
}

/// 37 Crisis Care (위기 돌봄): shown after saving an entry with crisis signals.
/// Offers the 24-hour suicide prevention line (109) without blocking the user.
struct CrisisCareView: View {
    @Environment(\.openURL) private var openURL
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0)

            CrisisHero()

            VStack(spacing: Space.lg) {
                Text("지금 많이 힘드신가요?")
                    .textStyle(.h2)
                    .foregroundStyle(Color.textPrimary)
                Text("혼자 견디지 않아도 괜찮아요.\n전문 상담이 24시간 열려 있어요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            NoticeBanner(message: "자살예방 상담전화 109 (24시간)", tone: .warm)

            VStack(spacing: Space.md) {
                Button("109로 전화하기") {
                    if let url = URL(string: "tel://109") { openURL(url) }
                }
                .buttonStyle(.primary)
                Button("괜찮아요, 계속할게요", action: onContinue)
                    .buttonStyle(.ghost)
            }

            Spacer(minLength: 0)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StarField() }
    }
}

/// 37 `Hero` (120×120): a soft violet orb with a heart, two orbits, two stars.
private struct CrisisHero: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle().strokeBorder(Color.brandPrimary, lineWidth: 1)
                .frame(width: 120, height: 120).opacity(0.3)
            Circle().strokeBorder(Color.brandPrimary, lineWidth: 1)
                .frame(width: 92, height: 92).opacity(0.5)
                .offset(x: 14, y: 14)
            Circle().fill(Color.tintPrimary)
                .overlay(Circle().strokeBorder(Color.borderFocus, lineWidth: 1))
                .frame(width: 64, height: 64)
                .shadow(color: Color.brandPrimary.opacity(0.4), radius: 12)
                .offset(x: 28, y: 28)
            Image(.iconHeart)
                .renderingMode(.template)
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.starBright)
                .offset(x: 45, y: 45)
            Circle().fill(Color.starBright)
                .frame(width: 6, height: 6)
                .shadow(color: Color.starBright.opacity(0.5), radius: 14)
                .offset(x: 97, y: 17)
            Circle().fill(Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255))
                .frame(width: 5, height: 5)
                .shadow(color: Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255).opacity(0.4), radius: 10)
                .offset(x: 12, y: 94)
        }
        .frame(width: 120, height: 120, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

#Preview {
    CrisisCareView(onContinue: {})
}
