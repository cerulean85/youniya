import SwiftUI

/// 70 / 77 / 77-2 나의 별자리 자세히 보기: the month's constellation large,
/// with zoom (two fingers or + −). Tapping a star picks it: its card replaces
/// the info table, and 「별 보기 ›」 opens it. 「이미지로 저장」 saves the figure.
struct ConstellationDetailView: View {
    @Environment(AppModel.self) private var model
    var month: String
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void
    var onStory: () -> Void

    @State private var level: CGFloat = 1
    @State private var selected: MonthConstellation.Star?
    @State private var toast: ToastCardMessage?

    var body: some View {
        let c = model.constellation(month)
        VStack(spacing: 0) {
            TopAppBar(title: "나의 별자리", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Tag(text: c.isComplete ? "\(c.monthLabel) · 완성 \(c.filled) / \(c.total)"
                                               : "\(c.monthLabel) · 채우는 중 \(c.filled) / \(c.total)", tone: .gold)
                        Text(c.name).textStyle(.h1).foregroundStyle(Color.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    figure(c)

                    Text(selected == nil ? "두 손가락으로 확대 · 별을 눌러 보기" : "별의 모양은 쓴 글의 결로 정해져요")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)

                    if let s = selected {
                        pickedCard(s)
                    } else {
                        infoTable(c)
                    }

                    LinkChip(title: "별자리 이야기", action: onStory)
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            Button("이미지로 저장") { saveImage(c) }
                .buttonStyle(.secondary)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .toastCard($toast)
        .task { await model.loadConstellation(month) }
        .onAppear {
            // 77-2 review: the sample star picked, with its links.
            if DebugScreen.is("77-2"), let s = c.stars.first(where: { !model.linkedStars($0.id).isEmpty }) { selected = s }
        }
    }

    private func figure(_ c: MonthConstellation) -> some View {
        ZStack(alignment: .topTrailing) {
            ConstellationFigureView(constellation: c, selected: selected?.id,
                                    silverLinks: selected.map { model.linkedStars($0.id).map(\.id) } ?? []) { s in
                withAnimation(.snappy) { selected = selected?.id == s.id ? nil : s }
            }
            .padding(Space.lg)
            .scaleEffect(level)
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()
            .gesture(MagnifyGesture().onChanged { v in level = min(2.6, max(1, v.magnification)) })
            ZoomControls(level: $level, range: 1...2.6)
                .padding(.trailing, 4)
        }
    }

    /// 70 `Info`: 채운 자리 · 평균 깊이 · 빛깔 · 가장 밝은 별.
    private func infoTable(_ c: MonthConstellation) -> some View {
        let items = c.stars.compactMap { s in model.stars.first { $0.id == s.id } }
        let lit = items.compactMap(\.analysis)
        let avgDepth = lit.isEmpty ? nil : lit.map { $0.depth * 5 }.reduce(0, +) / Double(lit.count)
        let moods = Mood.allCases.filter { m in c.stars.contains { $0.mood == m } }
        let brightest = c.stars.filter(\.hasStarlight).max { ($0.starlight ?? 0) < ($1.starlight ?? 0) }
        let rows: [(String, String)] = [
            ("채운 자리", "\(c.filled) / \(c.total) · " + (c.isComplete ? "완성" : "\(c.total - c.filled)자리 남음")),
            ("평균 깊이", avgDepth.map { String(format: "%.1f단계", $0) } ?? "별빛을 받은 별이 아직 없어요"),
            ("빛깔", moods.isEmpty ? "아직 없어요" : moods.map(\.label).joined(separator: " · ")),
            ("가장 밝은 별", brightest.map { b in
                (b.createdAt.map { Self.day($0) + " · " } ?? "") + "별빛 \(b.starlight ?? 0)"
            } ?? "아직 없어요"),
        ]
        return VStack(spacing: Space.md) {
            ForEach(rows, id: \.0) { r in
                HStack(alignment: .top) {
                    Text(r.0).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                    Spacer(minLength: Space.md)
                    Text(r.1).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Space.lg)
        .itemCard(seed: "constellation-info", minHeight: 0)
    }

    /// 77-2 `Picked`: "내 별 · {제목}" and 「별 보기 ›」.
    private func pickedCard(_ s: MonthConstellation.Star) -> some View {
        Button {
            if let star = model.stars.first(where: { $0.id == s.id }) { onOpenStar(star) }
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("내 별 · \(s.title)").textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    Text(linkLine(s))
                        .textStyle(.caption).foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text("별 보기 ›").textStyle(.labelM).foregroundStyle(Color.brandPrimaryText)
            }
            .padding(Space.lg)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.starBright, lineWidth: 1.2))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// 77-2: "이어진 별 3 · 이번 달 2개는 은빛 선으로 보여요" (+ the other months).
    private func linkLine(_ s: MonthConstellation.Star) -> String {
        let linked = model.linkedStars(s.id)
        guard !linked.isEmpty else { return s.hasStarlight ? "별빛 \(s.starlight ?? 0)" : "별빛 없는 별" }
        let here = linked.filter { $0.date.map(MonthConstellation.monthKey) == month }.count
        var line = "이어진 별 \(linked.count)"
        if here > 0 { line += " · 이번 달 \(here)개는 은빛 선으로 보여요" }
        if linked.count > here { line += " · 다른 달 \(linked.count - here)개" }
        return line
    }

    @MainActor
    private func saveImage(_ c: MonthConstellation) {
        let renderer = ImageRenderer(content:
            ConstellationFigureView(constellation: c)
                .padding(24)
                .frame(width: 360, height: 320)
                .background { NebulaGlowBackground() }
                .environment(model)
        )
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        toast = ToastCardMessage(title: "이미지로 저장했어요")
    }

    private static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}
