import SwiftUI

/// 17.3 별빛 풀이 (07-1, 12-5): "별빛 N은 이렇게 모였어요" — the three scores
/// with their reasons, the overall reading, and how it was read. Parts the
/// server hasn't sent yet are left out.
struct StarlightBreakdown: View {
    var analysis: StarAnalysis
    /// 07-1: rows appear one after another (0.18 s apart) once this turns true.
    var reveal = true

    @Environment(\.motionReduced) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("별빛 \(analysis.starlight)\(Self.particle(analysis.starlight)) 이렇게 모였어요")
                .textStyle(.h3)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            row(0, "별의 깊이", analysis.depthScore, 400, analysis.depthReason, .brandPrimary)
            row(1, "빛의 선명함", analysis.clarityScore, 300, analysis.clarityReason, .starClear)
            row(2, "마음의 무게", analysis.weightScore, 300, analysis.weightReason, .brandWarm)

            if let text = analysis.interpretation {
                Rectangle().fill(Color.borderDefault).frame(height: 1)
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("종합 해석").textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    Text(text)
                        .textStyle(.observation)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appear(reveal, delay: 3 * 0.18, reduceMotion: reduceMotion)
            } else if analysis.prismVersion != nil {
                // 12-11 (516:14415): only the 풀이 call failed; the scores stand.
                Text("이번에는 별빛 풀이를 다 쓰지 못했어요. 별빛과 세 점수는 그대로예요.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .appear(reveal, delay: 3 * 0.18, reduceMotion: reduceMotion)
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("점수는 글을 평가한 것이 아니라, 이 글에서 마음이 어디까지 닿았는지를 별빛으로 옮긴 거예요.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if let version = analysis.prismVersion {
                    Text("\(version) · 2026년 11월 방식으로 읽었어요")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .appear(reveal, delay: 4 * 0.18, reduceMotion: reduceMotion)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.xl)
        .itemCard(seed: "breakdown-\(analysis.starlight)", minHeight: 0)
    }

    private func row(_ i: Int, _ label: String, _ score: Int, _ max: Int, _ reason: String?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text(label).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(score) / \(max)").textStyle(.labelS).foregroundStyle(Color.textSecondary)
            }
            Capsule()
                .fill(Color.borderDefault)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule().fill(color)
                            .frame(width: geo.size.width * min(1, Double(score) / Double(max)))
                    }
                }
            if let reason {
                Text(reason)
                    .textStyle(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(score)점, \(max)점 중. \(reason ?? "")")
        .appear(reveal, delay: Double(i) * 0.18, reduceMotion: reduceMotion)
    }

    /// "742는" / "740은": the topic particle after the number as read aloud.
    static func particle(_ n: Int) -> String {
        // As read: 일 삼 육 칠 팔 십 백 end in a consonant; 이 사 오 구 천 don't.
        let last = n % 10
        if last != 0 { return [1, 3, 6, 7, 8].contains(last) ? "은" : "는" }
        if n % 100 != 0 { return "은" }   // …십
        if n % 1000 != 0 { return "은" }  // …백
        return "는"                       // …천
    }
}

/// 「별빛 풀이 보기 ▾ / 접기 ▴」
struct BreakdownToggle: View {
    @Binding var isOpen: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) { isOpen.toggle() }
        } label: {
            Text(isOpen ? "별빛 풀이 접기 ▴" : "별빛 풀이 보기 ▾")
                .textStyle(.labelM)
                .foregroundStyle(Color.starBright)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOpen ? "펼침" : "접힘")
    }
}

extension View {
    /// 17.4: rises 12pt and brightens over 0.5 s, `delay` after `on` turns true;
    /// at once with reduced motion.
    func appear(_ on: Bool, delay: Double, reduceMotion: Bool) -> some View {
        modifier(AppearModifier(on: on, delay: delay, reduceMotion: reduceMotion))
    }
}

private struct AppearModifier: ViewModifier {
    var on: Bool
    var delay: Double
    var reduceMotion: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        let visible = reduceMotion || shown
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
            .onAppear { start() }
            .onChange(of: on) { _, _ in start() }
    }

    private func start() {
        guard on, !shown, !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.5).delay(delay)) { shown = true }
    }
}
