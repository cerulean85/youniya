import SwiftUI

/// 76-1 별지기 페이지 (428:17845): "{이름}의 밤하늘", only the stars they
/// shared on the plaza. No stats, no starlight numbers, no counts or follows.
/// A blocked keeper's page doesn't open (either way).
struct KeeperPageView: View {
    @Environment(AppModel.self) private var model
    var nickname: String
    var onBack: () -> Void
    var onOpen: (PlazaNebula) -> Void

    @State private var stars: [PlazaNebula]?
    @State private var loaded = false

    private var isMine: Bool { nickname == model.nickname }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "별지기", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("\(nickname)의 밤하늘").textStyle(.h1).foregroundStyle(Color.textPrimary)
                        Text(isMine ? "다른 별지기에게는 이렇게 보여요. 우주 광장에 나눈 별만 보이고, 나누지 않은 기록과 수치는 보이지 않아요."
                                    : "\(nickname)이 우주 광장에 나눈 별이에요. 나누지 않은 기록과 수치는 보이지 않아요.")
                            .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    if let stars {
                        Text("나눈 별 \(stars.count)").textStyle(.h3).foregroundStyle(Color.textPrimary)
                        if stars.isEmpty {
                            Text("아직 나눈 별이 없어요.").textStyle(.bodyM).foregroundStyle(Color.textTertiary)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(stars.enumerated()), id: \.element.id) { i, item in
                                PlazaStarRow(item: item, resonated: model.resonated.contains(item.id),
                                             onOpen: { onOpen(item) })
                                if i < stars.count - 1 {
                                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                                }
                            }
                        }
                    } else if loaded {
                        Text("이 별지기의 밤하늘을 볼 수 없어요.")
                            .textStyle(.bodyM).foregroundStyle(Color.textTertiary)
                    } else {
                        ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .task {
            stars = await model.keeperStars(nickname)
            loaded = true
        }
    }
}
