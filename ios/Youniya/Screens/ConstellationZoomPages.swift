import SwiftUI

// MARK: - Shared pieces (70, 77)

/// Figma `Zoom Controls`: + / level / −, 36pt circles. − is filled violet.
struct ZoomControls: View {
    @Environment(\.skyTheme) private var theme
    @Binding var level: CGFloat
    var range: ClosedRange<CGFloat>

    var body: some View {
        VStack(spacing: Space.xs) {
            // Figma: at 1× the + is filled; once zoomed, the − is.
            let atMin = level <= range.lowerBound + 0.01
            button("+", filled: atMin, label: "확대") { level = min(range.upperBound, level + 0.4) }
            Text(Self.label(level))
                .textStyle(.caption)
                .foregroundStyle(Color.textSecondary)
                .accessibilityHidden(true)
            button("−", filled: !atMin, label: "축소") { level = max(range.lowerBound, level - 0.4) }
        }
    }

    /// "1×", "2.6×"
    static func label(_ level: CGFloat) -> String {
        let r = (level * 10).rounded() / 10
        return r == r.rounded() ? "\(Int(r))×" : String(format: "%.1f×", r)
    }

    private func button(_ glyph: String, filled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Text(glyph)
                .textStyle(.h3)
                .foregroundStyle(filled ? Color.white : Color.textSecondary)
                .frame(width: 36, height: 36)
                .cosmos("zoom-\(glyph)", in: Circle(), intensity: 0.6)
                .background(filled ? theme.accent.strong : Color.bgSurfaceRaised, in: .circle)
                .overlay(Circle().strokeBorder(Color.borderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(String(format: "%.1f배", level))
    }
}

// MARK: - 70 / 77 My nebula, zoomed

// MARK: - 83 Nebula story

/// 83 성운 이야기: one core sentence per star, oldest first, left as written.
struct NebulaStoryView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onSaved: () -> Void
    /// 83 별자리 이야기 (16장): the month whose stars it weaves.
    var month: String = MonthConstellation.monthKey(.now)

    struct Line: Identifiable {
        var star: StarItem
        var sentence: String
        var id: StarItem.ID { star.id }
    }

    /// Live: GET /v1/constellations/{month}/story (each star's key sentence).
    @State private var serverStory: ServerStory?

    /// Live: the server's entries; mock: each floated star's last sentence.
    private var lines: [Line] {
        if let serverStory {
            return serverStory.entries.compactMap { e in
                guard let id = UUID(uuidString: e.starId), let star = model.stars.first(where: { $0.id == id }) else { return nil }
                return Line(star: star, sentence: e.sentence)
            }
        }
        return monthStars
            .sorted { ($0.date ?? .now) < ($1.date ?? .now) }
            .compactMap { star in
                let parts = star.body
                    .components(separatedBy: CharacterSet(charactersIn: ".!?。\n"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                guard let last = parts.last else { return nil }
                let end = star.body.contains(last + ".") ? "." : star.body.contains(last + "?") ? "?" : ""
                return Line(star: star, sentence: last + end)
            }
    }

    /// The month's stars, with or without starlight.
    private var monthStars: [StarItem] {
        model.stars.filter { $0.date.map(MonthConstellation.monthKey) == month }
    }

    var body: some View {
        let lines = self.lines
        let floated = monthStars
        let since = floated.compactMap(\.date).min()
        VStack(spacing: 0) {
            TopAppBar(title: "별자리 이야기", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("\(model.constellation(month).title) 이야기")
                            .textStyle(.h2)
                            .foregroundStyle(Color.textPrimary)
                        Text("별마다 고른 핵심 문장을 시간순으로 엮었어요. 원문 문장은 한 글자도 바꾸지 않아요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    HStack(spacing: Space.sm) {
                        tag(since.map { "별 \(floated.count) · \(Self.day($0))부터" } ?? "별 \(floated.count)", gold: true)
                        tag("문장 엮기", gold: false)
                    }

                    if lines.isEmpty {
                        Text("글이 있는 별을 띄우면 이야기가 엮여요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        storyCard(lines)
                        Text("✦ 표시는 문장 사이를 잇는 자리예요.")
                            .textStyle(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)

            Button("문장만 엮어 두기", action: onSaved)
                .buttonStyle(.primary)
                .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .task {
            if let story = await model.loadConstellationStory(month) { serverStory = story }
        }
    }

    private func storyCard(_ lines: [Line]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                if i > 0 {
                    Text("✦")
                        .textStyle(.labelS)
                        .foregroundStyle(Color.starBright)
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(line.star.shortDateText) · \(line.star.title)")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                    Text("“\(line.sentence)”")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 20)
        .itemCard(seed: "story", minHeight: 0)
    }

    private func tag(_ text: String, gold: Bool) -> some View {
        Text(text)
            .textStyle(.labelS)
            .foregroundStyle(gold ? Color.starBright : Color.textSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(gold ? Color.tintGold : Color.bgSurfaceRaised, in: .capsule)
    }

    private static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}


#Preview("83") {
    let model = AppModel()
    model.fillSampleStars()
    return NebulaStoryView(onBack: {}, onSaved: {}).environment(model)
}
