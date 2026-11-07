import SwiftUI

/// 08 My Nebula (성운 tab): the user's constellation, stats, and links.
struct NebulaView: View {
    @Environment(AppModel.self) private var model
    var onOpen: (_ title: String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("나의 성운")
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                    // TODO: nebula name and stage come from the backend.
                    Text("\(model.nebulaName) · \(model.stageLabel)")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.starBright)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                NebulaCanvas()
                    .frame(height: 330)
                    .frame(maxWidth: .infinity)
                    .background(Color.bgSurface, in: .rect(cornerRadius: Radius.xl))
                    .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Color.borderDefault, lineWidth: 1))
                    .clipShape(.rect(cornerRadius: Radius.xl))

                HStack(spacing: Space.md) {
                    stat(model.floatedCount, "떠 있는 별")
                    stat(model.deepCount, "깊은 별")
                    stat(model.supernovaCount, "초신성")
                }

                // Tapping the hint opens 86 (the four stages).
                Button { onOpen("성장 단계") } label: {
                    Text(hint)
                        .textStyle(.bodyS)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("성운이 자라는 네 걸음을 봐요")

                HStack(spacing: Space.md) {
                    Button("모두의 은하") { onOpen("모두의 은하") }
                        .buttonStyle(.secondary)
                    Button("자세히 보기") { onOpen("나의 성운 확대") }
                        .buttonStyle(.primary)
                }

                // Figma: chips wrap onto a second line.
                FlowRow(spacing: Space.sm) {
                    linkChip("성운 그리기")
                    linkChip("성운 이야기")
                    linkChip("나의 은하수")
                    linkChip("성운 모음")
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .scrollIndicators(.hidden)
    }

    private var hint: String {
        let need = max(0, AppModel.nextStageDeepStars - model.deepCount)
        return need == 0
            ? "다음 단계로 넘어갈 준비가 되었어요."
            : "다음 단계까지 깊은 별 \(need)개가 더 필요해요. 서두르지 않아도 괜찮아요."
    }

    /// Figma `Stat`: tappable count card with a "›" label row.
    private func stat(_ value: Int, _ label: String) -> some View {
        Button { onOpen(label) } label: {
            VStack(spacing: Space.xs) {
                Text("\(value)")
                    .textStyle(.h2)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 2) {
                    Text(label)
                        .textStyle(.caption)
                        .foregroundStyle(Color.textSecondary)
                    Image(.iconChevronRight)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Space.md)
            .cosmos("stat-\(label)", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func linkChip(_ title: String) -> some View {
        LinkChip(title: title) { onOpen(title) }
    }
}

/// Figma `Nebula Canvas`: stage-2 constellation, laid out on a 342-wide box
/// and centered on wider screens.
private struct NebulaCanvas: View {
    private struct Star {
        var image: ImageResource
        var center: CGPoint
        var size: CGFloat
        var keys: [(Double, Double)]
    }

    private let stars: [Star] = [
        Star(image: .nebulaStar0, center: CGPoint(x: 148, y: 103), size: 58, keys: [(0, 1), (0.08, 0.3), (0.465, 1), (0.85, 0.3), (1, 1)]),
        Star(image: .nebulaStar1, center: CGPoint(x: 192, y: 103), size: 58, keys: [(0, 1), (0.56, 0.3), (1, 1)]),
        Star(image: .nebulaStar2, center: CGPoint(x: 144, y: 173), size: 58, keys: [(0, 1), (0.21, 0.3), (0.805, 1), (1, 0.3)]),
        Star(image: .nebulaStar3, center: CGPoint(x: 196, y: 173), size: 58, keys: [(0, 1), (0.435, 0.3), (0.91, 1), (1, 0.3)]),
        Star(image: .nebulaStar4, center: CGPoint(x: 137, y: 243), size: 58, keys: [(0, 1), (0.175, 0.3), (0.53, 1), (0.885, 0.3), (1, 1)]),
        Star(image: .nebulaStar5, center: CGPoint(x: 203, y: 243), size: 58, keys: [(0, 1), (0.04, 0.3), (0.725, 1), (1, 0.3)]),
        Star(image: .nebulaStar6, center: CGPoint(x: 117, y: 295), size: 56, keys: [(0, 1), (0.355, 0.3), (0.92, 1), (1, 0.3)]),
        Star(image: .nebulaStar7, center: CGPoint(x: 223, y: 295), size: 56, keys: [(0, 1), (0.085, 0.3), (0.535, 1), (0.98, 0.3), (1, 1)]),
    ]

    var body: some View {
        GeometryReader { geo in
            let dx = (geo.size.width - 342) / 2
            ZStack(alignment: .topLeading) {
                Image(.nebulaThread0).resizable().frame(width: 53.9272, height: 244.374).position(x: 143.5, y: 173)
                Image(.nebulaThread1).resizable().frame(width: 53.9272, height: 244.374).position(x: 196.5, y: 173)
                ForEach([134.0, 204.0, 269.0], id: \.self) { y in
                    Image(.nebulaEmptySlot).resizable().frame(width: 14, height: 14).position(x: 170, y: y)
                }
                Image(.nebulaTopStar)
                    .resizable()
                    .frame(width: 20.1, height: 20.1)
                    .twinkle(Twinkle(duration: 2, keys: [(0, 1), (0.325, 0.3), (0.825, 1), (1, 0.3)]), scale: StarScale.dim)
                    .position(x: 170, y: 51)
                ForEach(stars.indices, id: \.self) { i in
                    let s = stars[i]
                    Image(s.image)
                        .resizable()
                        .frame(width: s.size, height: s.size)
                        .twinkle(Twinkle(duration: 2, keys: s.keys), scale: StarScale.dim)
                        .position(s.center)
                }
            }
            .frame(width: 342, height: 330)
            .offset(x: dx)
        }
        .accessibilityElement()
        .accessibilityLabel("나의 성운 별자리")
    }
}

#Preview {
    let model = AppModel()
    model.fillSampleStars()
    return NebulaView(onOpen: { _ in })
        .environment(model)
        .background(Color.bgCanvas)
}
