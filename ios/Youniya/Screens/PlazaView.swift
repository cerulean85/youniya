import SwiftUI

/// Another user's nebula as shown in the plaza. Never includes their text.
struct PlazaNebula: Identifiable, Hashable {
    enum Pattern { case a, b }
    var id: String { name }
    var name: String
    /// One line of starlight left by the owner.
    var line: String
    var pattern: Pattern
    /// Depth distribution: deep / clear / warm (sums to ~1).
    var depth: (deep: Double, clear: Double, warm: Double) = (0.41, 0.31, 0.28)
    /// How close it is to the viewer's own tone (0...1), for "나와 결이 비슷한".
    var similarity: Double
    var order: Int
    /// Live: the plaza share id.
    var serverID: String? = nil
    /// Live: the star's shape, mood and depth (1–5) from the plaza.
    var starShape: StarShapeSpec? = nil
    var mood: Mood? = nil
    var depthLevel: Int? = nil
    /// 09-2 row: when it was shared.
    var sharedAt: Date? = nil

    /// 09 card: the server's values, or steady samples from the name.
    var cardShape: StarShapeSpec {
        if let starShape { return starShape }
        var rng = SeededRandom(seed: name)
        let sharp = StarShapeSpec.Sharpness.allCases
        return StarShapeSpec(points: 4 + Int(rng.next(in: 0...3).rounded()),
                             sharpness: sharp[Int(rng.next(in: 0...Double(sharp.count - 1)).rounded())])
    }
    var cardMood: Mood {
        if let mood { return mood }
        var rng = SeededRandom(seed: "mood-" + name)
        return Mood.allCases[Int(rng.next(in: 0...Double(Mood.allCases.count - 1)).rounded())]
    }
    var cardDepth: Int { depthLevel ?? 3 }

    static func == (l: Self, r: Self) -> Bool { l.name == r.name }
    func hash(into h: inout Hasher) { h.combine(name) }

    /// Mock samples from Figma `09-2 우주 광장 · 합친 화면`.
    static let samples: [PlazaNebula] = [
        PlazaNebula(name: "고요한 새벽의 고래자리", line: "그런 마음, 저도 알아요.", pattern: .a, similarity: 0.62, order: 0,
                    sharedAt: .now.addingTimeInterval(-20)),
        PlazaNebula(name: "늦은 밤의 등대자리", line: "오늘도 여기까지 왔어요.", pattern: .b, similarity: 0.91, order: 1,
                    sharedAt: .now.addingTimeInterval(-12 * 60)),
        PlazaNebula(name: "비를 기다리는 나무자리", line: "느려도 괜찮은 밤이에요.", pattern: .b, similarity: 0.78, order: 2,
                    sharedAt: .now.addingTimeInterval(-3600)),
        PlazaNebula(name: "천천히 날아오른 새자리", line: "당신의 별빛이 닿았어요.", pattern: .a, similarity: 0.45, order: 3,
                    sharedAt: .now.addingTimeInterval(-2 * 3600)),
        PlazaNebula(name: "창가에 앉은 고양이자리", line: "잠깐 멈춰도 괜찮다는 말을 들었어요.", pattern: .b, similarity: 0.7, order: 4,
                    sharedAt: .now.addingTimeInterval(-3 * 3600)),
        PlazaNebula(name: "첫눈을 기다리는 사슴자리", line: "말끝을 흐려도 마음은 남아 있었어요.", pattern: .a, similarity: 0.55, order: 5,
                    sharedAt: .now.addingTimeInterval(-5 * 3600)),
    ]
}

/// The plaza's filters (09-3 / 09-4); each tab keeps its own choice.
enum PlazaFilter: String, CaseIterable {
    case newest = "새로 뜬 것", similar = "나와 결이 비슷한", kept = "곁에 둔 것"
}

/// 09-3 / 09-4 우주 광장: two tabs. 별 기록 (default) lists the shared stars;
/// 성운 fills the screen with the nebula field (no page scroll, so its drag
/// and pinch don't fight the scroll). No rankings or comments.
struct PlazaView: View {
    var onOpen: (_ title: String) -> Void
    /// Field → 73
    var onOpenNebula: (GalaxyNebula) -> Void = { _ in }

    /// Tonight's hearts and mine (live `/v1/plaza/tonight`; mock: Figma 69's sample,
    /// with my shared floated stars).
    private var tonight: (count: Int, mine: Int) {
        if model.useLiveAPI { return (model.tonightCount ?? 0, model.tonightMine ?? 0) }
        return (1284, model.stars.filter { $0.isFloated && $0.isShared }.count)
    }

    private enum Segment: String, CaseIterable { case stars = "별 기록", nebula = "성운" }

    @State private var segment: Segment = {
        #if DEBUG
        UserDefaults.standard.string(forKey: "debugRoute") == "plazaNebula" || DebugScreen.is("72") ? .nebula : .stars
        #else
        .stars
        #endif
    }()
    /// Each tab keeps its own filter.
    @State private var starFilter: PlazaFilter = .newest
    @State private var nebulaFilter: PlazaFilter = .newest
    /// "더 보기": rows shown so far.
    @State private var shown = Self.page
    private static let page = 20
    @Environment(AppModel.self) private var model

    private var stars: [PlazaNebula] {
        switch starFilter {
        case .newest: model.plazaStarItems.sorted { $0.order < $1.order }
        case .similar: model.plazaStarItems.sorted { $0.similarity > $1.similarity }
        // Live: the server's beside list (most recently kept first); mock: the
        // stars I left a resonance on.
        case .kept: model.useLiveAPI ? model.plazaStarsBeside
            : model.plazaStarItems.filter { model.resonated.contains($0.id) }.sorted { $0.order < $1.order }
        }
    }

    var body: some View {
        Group {
            if segment == .stars {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        header
                        starList
                    }
                    .padding(.horizontal, Space.xl)
                    .padding(.vertical, Space.lg)
                }
                .scrollIndicators(.hidden)
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    header
                    PlazaNebulaField(filter: nebulaFilter, fills: true, onOpen: onOpenNebula)
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xl)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .task {
            await model.loadPlaza()
            await model.loadTonight()
        }
    }

    /// Title, the tab's line, tonight's tag, the tabs and the tab's filters.
    private var header: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("우주 광장")
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)
                Text(segment == .stars
                     ? "누군가 골라 나눈 한 문장이에요. 눌러서 읽고, 마음이 닿으면 공명을 남겨 보세요. 순위나 인기는 없어요."
                     : "모인 성운의 모양을 둘러보세요. 순위나 인기는 없어요.")
                    .textStyle(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            // 69 모두의 은하, merged here: tonight's hearts (hidden at 0).
            if tonight.count > 0 {
                Text(tonight.mine > 0
                     ? "오늘 밤, \(tonight.count.formatted())개의 마음이 모였어요 · 내 별 \(tonight.mine)개도 함께 빛나요"
                     : "오늘 밤, \(tonight.count.formatted())개의 마음이 모였어요")
                    .textStyle(.labelS)
                    .foregroundStyle(Color.starBright)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.xs)
                    .background(Color.tintGold, in: .capsule)
                    .fixedSize(horizontal: false, vertical: true)
            }

            segmentControl

            FlowRow(spacing: Space.sm) {
                ForEach(PlazaFilter.allCases, id: \.self) { f in
                    let on = (segment == .stars ? starFilter : nebulaFilter) == f
                    DotChip(title: f.rawValue, isSelected: on) {
                        withAnimation(.snappy) {
                            if segment == .stars { starFilter = f; shown = Self.page } else { nebulaFilter = f }
                        }
                    }
                }
            }
        }
    }

    /// Figma `Segment`: pill track, selected segment filled violet.
    private var segmentControl: some View {
        HStack(spacing: Space.xs) {
            ForEach(Segment.allCases, id: \.self) { s in
                let on = segment == s
                Button { withAnimation(.snappy) { segment = s } } label: {
                    Text(s.rawValue)
                        .textStyle(.labelM)
                        .foregroundStyle(on ? Color.textOnBrand : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                        .background(on ? Color.brandPrimary : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(Space.xs)
        .cosmos("segment", in: Capsule())
        .background(Color.bgSurfaceRaised, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 1))
    }

    /// 별 기록: one row per shared star, thin lines between them.
    @ViewBuilder private var starList: some View {
        let stars = self.stars
        if stars.isEmpty {
            Group {
                if starFilter == .kept {
                    EmptyStateView(title: "곁에 둔 별이 아직 없어요",
                                   message: "마음이 닿은 별에 공명을 남기면\n여기서 다시 모아 볼 수 있어요.",
                                   action: ("새로 뜬 것 둘러보기", .outline, {
                                       withAnimation(.snappy) { starFilter = .newest }
                                   }))
                } else {
                    EmptyStateView(title: "아직 나눠진 별이 없어요", message: "누군가 별을 나누면 여기에 한 문장씩 모여요.")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(stars.prefix(shown).enumerated()), id: \.element.id) { i, item in
                    PlazaStarRow(item: item, resonated: model.resonated.contains(item.id),
                                 onOpen: { onOpen(item.name) })
                    if i < min(shown, stars.count) - 1 {
                        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    }
                }
            }
            if stars.count > shown {
                Button("더 보기") { withAnimation(.snappy) { shown += Self.page } }
                    .buttonStyle(.ghost)
            }
        }
    }
}

/// 09-2 star row: the shared star (shape · mood · depth glow), its one line,
/// "{name} · {when}", and ✦ (filled when I left a resonance). Others' counts
/// are never shown: only the owner sees them.
struct PlazaStarRow: View {
    var item: PlazaNebula
    var resonated: Bool
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ShapeStar(spec: item.cardShape, color: item.cardMood.color, size: 22, halo: false)
                    .shadow(color: item.cardMood.color.opacity(0.75), radius: 1 + CGFloat(item.cardDepth) * 1.2)
                    .frame(width: 44, height: 44)
                    .background(Color.bgSurfaceRaised, in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("“\(item.line)”")
                        .textStyle(.observation)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.sharedAt.map { "\(item.name) · \(Self.when($0))" } ?? item.name)
                        .textStyle(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("✦")
                    .textStyle(.labelM)
                    .foregroundStyle(resonated ? Color.brandPrimaryText : Color.textTertiary.opacity(0.6))
                    .accessibilityLabel(resonated ? "공명했어요" : "공명")
            }
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(resonated ? .isSelected : [])
    }

    /// "방금", "12분 전", "1시간 전", "3일 전".
    static func when(_ d: Date) -> String {
        let s = max(0, Date.now.timeIntervalSince(d))
        switch s {
        case ..<60: return "방금"
        case ..<3600: return "\(Int(s / 60))분 전"
        case ..<86_400: return "\(Int(s / 3600))시간 전"
        default: return "\(Int(s / 86_400))일 전"
        }
    }
}

#Preview {
    PlazaView(onOpen: { _ in })
        .environment(AppModel())
        .background(Color.bgCanvas)
}
