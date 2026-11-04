import SwiftUI

/// 17 Starlight Records (별빛 기록): every star, newest first.
/// Pushed from the menu (with back) or shown as the 기록 tab (without).
struct RecordsView: View {
    @Environment(AppModel.self) private var model
    var onBack: (() -> Void)?
    var onOpenStar: (StarItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
                TopAppBar(title: "별빛 기록", onBack: onBack)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("나의 별빛 기록")
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("쓴 마음이 별이 되어 모이는 곳이에요.")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textSecondary)

                    RecordsHero()

                    if model.stars.isEmpty {
                        Text("아직 기록된 별이 없어요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Space.xl)
                    } else {
                        LazyVStack(spacing: Space.md) {
                            ForEach(model.stars) { star in
                                Button { onOpenStar(star) } label: {
                                    RecordCard(star: star, subtitle: subtitle(star))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, onBack == nil ? Space.lg : Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func subtitle(_ star: StarItem) -> String {
        if let light = star.analysis?.starlight { return "\(star.shortDateText) · 별빛 \(light)" }
        return star.isFloated ? "\(star.shortDateText) · 띄운 별" : "\(star.shortDateText) · 조용히 품음"
    }
}

/// Figma record `Item`: focus border, raised gradient, Cosmos BG, spinning glyph.
struct RecordCard: View {
    var star: StarItem
    var subtitle: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg)
        HStack(spacing: 12) {
            StarGlyph(floated: star.isFloated)
            VStack(alignment: .leading, spacing: 4) {
                Text(star.title)
                    .textStyle(.labelM)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .textStyle(.bodyS)
                    .foregroundStyle(Color.textSecondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.lg)
        .cosmos(star.id.uuidString, in: shape)
        .background(
            LinearGradient(stops: [.init(color: .bgSurfaceRaised, location: 0), .init(color: .bgSurface, location: 0.714)],
                           startPoint: UnitPoint(x: 0.42, y: 0), endPoint: UnitPoint(x: 0.58, y: 1)),
            in: shape
        )
        .overlay(shape.strokeBorder(Color.borderFocus, lineWidth: 1))
        .contentShape(shape)
        .accessibilityElement(children: .combine)
    }
}

/// 17 `Hero`: the twinkling constellation (342×130).
private struct RecordsHero: View {
    private struct S { var image: ImageResource; var center: CGPoint; var size: CGFloat; var keys: [(Double, Double)] }
    private let stars: [S] = [
        S(image: .recordsStar0, center: CGPoint(x: 36, y: 90), size: 66, keys: [(0, 1), (0.12, 0.3), (0.48, 1), (0.84, 0.3), (1, 1)]),
        S(image: .recordsStar1, center: CGPoint(x: 105, y: 45), size: 62, keys: [(0, 1), (0.625, 0.3), (1, 1)]),
        S(image: .recordsStar2, center: CGPoint(x: 178, y: 82), size: 66, keys: [(0, 1), (0.27, 0.3), (0.84, 1), (1, 0.3)]),
        S(image: .recordsStar3, center: CGPoint(x: 250, y: 36), size: 50, keys: [(0, 1), (0.02, 0.3), (0.47, 1), (0.92, 0.3), (1, 1)]),
        S(image: .recordsStar4, center: CGPoint(x: 305, y: 100), size: 68, keys: [(0, 1), (0.205, 0.3), (0.535, 1), (0.865, 0.3), (1, 1)]),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(.recordsLine).resizable().frame(width: 269.652, height: 64.9808).position(x: 170.5, y: 68)
            ForEach(stars.indices, id: \.self) { i in
                let s = stars[i]
                Image(s.image).resizable().frame(width: s.size, height: s.size)
                    .twinkle(Twinkle(duration: 2, keys: s.keys), scale: StarScale.dim)
                    .position(s.center)
            }
        }
        .frame(width: 342, height: 130)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// 18 Kept (보관함 · 조용히 품은 마음): stars kept without analysis.
struct KeptView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void

    private var kept: [StarItem] { model.stars.filter { !$0.isFloated } }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "조용히 품은 마음", onBack: onBack)

            VStack(alignment: .leading, spacing: Space.lg) {
                Text("분석 없이 간직한 글이에요. 언제든 별로 띄울 수 있어요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)

                KeptHero()

                if kept.isEmpty {
                    Text("아직 조용히 품은 마음이 없어요.")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Space.xl)
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Space.md) {
                            ForEach(kept) { star in
                                Button { onOpenStar(star) } label: {
                                    RecordCard(star: star, subtitle: star.shortDateText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    ShareLink(item: exportAll) { Text("모두 내보내기") }
                        .buttonStyle(.ghost)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }

    private var exportAll: String {
        kept.map { [$0.title, $0.longDateText, "", $0.body].joined(separator: "\n") }
            .joined(separator: "\n\n———\n\n")
    }
}

/// 18 `Hero`: small orbit system with a golden star in the middle.
private struct KeptHero: View {
    private struct S { var image: ImageResource; var center: CGPoint; var size: CGFloat; var keys: [(Double, Double)] }
    private let stars: [S] = [
        S(image: .keptStar0, center: CGPoint(x: 171, y: 75), size: 90, keys: [(0, 1), (0.12, 0.3), (0.78, 1), (1, 0.3)]),
        S(image: .keptStar1, center: CGPoint(x: 21, y: 75), size: 58, keys: [(0, 1), (0.405, 0.3), (0.95, 1), (1, 0.3)]),
        S(image: .keptStar2, center: CGPoint(x: 271, y: 56), size: 60, keys: [(0, 1), (0.135, 0.3), (0.56, 1), (0.98, 0.3), (1, 1)]),
        S(image: .keptStar3, center: CGPoint(x: 100, y: 98), size: 48, keys: [(0, 1), (0.27, 0.3), (0.575, 1), (0.88, 0.3), (1, 1)]),
        S(image: .keptStar4, center: CGPoint(x: 221, y: 95), size: 62, keys: [(0, 1), (0.29, 0.3), (0.925, 1), (1, 0.3)]),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(.keptOrbit0).resizable().frame(width: 300, height: 110).opacity(0.35).position(x: 171, y: 75)
            Image(.keptOrbit1).resizable().frame(width: 200, height: 74).opacity(0.4).position(x: 171, y: 75)
            Image(.keptOrbit2).resizable().frame(width: 100, height: 38).position(x: 171, y: 75)
            ForEach(stars.indices, id: \.self) { i in
                let s = stars[i]
                Image(s.image).resizable().frame(width: s.size, height: s.size)
                    .twinkle(Twinkle(duration: 2, keys: s.keys), scale: StarScale.dim)
                    .position(s.center)
            }
        }
        .frame(width: 342, height: 150)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// 19 Share Consent: bottom sheet before sharing a star to the plaza.
struct ShareConsentSheet: View {
    var onShare: () -> Void
    var onReview: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule()
                .fill(Color.borderDefault)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("우주 광장에 나눌까요?")
                    .textStyle(.h3)
                    .foregroundStyle(Color.textPrimary)
                Text("글은 익명으로 올라가고, 다른 사람은 '공명'만 남길 수 있어요. 언제든 거둘 수 있어요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Space.md) {
                Button("익명으로 나누기", action: onShare)
                    .buttonStyle(.primary)
                Button("내용 먼저 확인", action: onReview)
                    .buttonStyle(.secondary)
                Button("나누지 않기", action: onCancel)
                    .buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }
}
