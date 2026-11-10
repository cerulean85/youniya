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
    /// 09-3 row: when it was shared.
    var sharedAt: Date? = nil
    /// 75-3: shared with its whole text (from 2026-11-08); older shares are one
    /// sentence only. Title and body come masked (contacts) from the server.
    var fullText = false
    var fullTitle: String? = nil
    var fullBody: String? = nil
    /// 15장: the keeper's name, and the title they gave the star (09-5 row).
    var nickname: String? = nil
    var starTitle: String? = nil
    /// 17.2: shared without starlight (faint, listed last, not in 「나와 결이 비슷한」).
    var hasStarlight = true
    /// 10.1 별빛 한 줄: the owner takes lines, and whether I already left one.
    var receiveLines = true
    var lineLeft = false

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
        PlazaNebula(name: "고요한 새벽의 별", line: "괜찮다는 말 뒤에 숨는 건 이제 그만하고 싶다.", pattern: .a, similarity: 0.62, order: 0,
                    sharedAt: .now.addingTimeInterval(-20), fullText: true, fullTitle: "새벽에 깬 날",
                    fullBody: "새벽 네 시에 눈이 떠졌다. 다시 잠들려고 애쓰다가 그냥 창가에 앉았다. 민지가 보낸 메시지를 몇 번이나 다시 읽었다. 괜찮다는 말 뒤에 숨는 건 이제 그만하고 싶다. 내일은 서울숲에 가서 천천히 걸어 볼 생각이다. 연락은 ●●●로 주면 된다고 적어 두었다.",
                    nickname: "고요한새벽", starTitle: "그 말을 삼킨 저녁"),
        PlazaNebula(name: "늦은 밤의 등대별", line: "오늘도 여기까지 왔어요.", pattern: .b, similarity: 0.91, order: 1,
                    sharedAt: .now.addingTimeInterval(-12 * 60), fullText: true, fullTitle: "퇴근길 버스 창가",
                    fullBody: "아침부터 일이 겹쳐서 점심도 제대로 못 먹었다. 집에 오는 길에 편의점 불빛이 유난히 따뜻해 보였다. 오늘도 여기까지 왔어요. 그걸로 됐다고 말해 주고 싶다.",
                    nickname: "밤바다", starTitle: "퇴근길 버스 창가"),
        PlazaNebula(name: "비를 기다리는 별", line: "느려도 괜찮은 밤이에요.", pattern: .b, similarity: 0.78, order: 2,
                    sharedAt: .now.addingTimeInterval(-3600), nickname: "느린고래", starTitle: "괜찮은 척한 하루"),
        PlazaNebula(name: "천천히 날아오른 별", line: "당신의 별빛이 닿았어요.", pattern: .a, similarity: 0.45, order: 3,
                    sharedAt: .now.addingTimeInterval(-2 * 3600), nickname: "바람결", starTitle: "오랜만에 웃은 날"),
        PlazaNebula(name: "창가에 앉은 별", line: "잠깐 멈춰도 괜찮다는 말을 들었어요.", pattern: .b, similarity: 0.7, order: 4,
                    sharedAt: .now.addingTimeInterval(-3 * 3600), nickname: "창가고양이", starTitle: "잠깐 멈춘 오후",
                    hasStarlight: false),
        PlazaNebula(name: "첫눈을 기다리는 별", line: "말끝을 흐려도 마음은 남아 있었어요.", pattern: .a, similarity: 0.55, order: 5,
                    sharedAt: .now.addingTimeInterval(-5 * 3600), nickname: "첫눈사슴", starTitle: "첫눈 오기 전날",
                    hasStarlight: false),
    ]
}

/// The plaza's filters (09-3 / 09-4); each tab keeps its own choice.
enum PlazaFilter: String, CaseIterable {
    case newest = "새로 뜬 것", similar = "나와 결이 비슷한", kept = "곁에 둔 것"
}

/// 09-5 우주 광장 (428:17651): the stars keepers shared, as one list. Each row
/// shows its 대표 문장, the keeper's name and the star's title; stars without
/// starlight sit below. 새로 뜬 것 / 나와 결이 비슷한 / 곁에 둔 것. No rankings,
/// and others' resonance counts are never shown. A keeper needs a name first.
struct PlazaView: View {
    var onOpen: (_ title: String) -> Void
    /// 21-1 for older accounts.
    var onNickname: () -> Void = {}
    /// 「내가 나눈 별 N개 ›」 → 17/18 나눈 별 (moved here from 설정, 2026-11-10).
    var onShared: () -> Void = {}

    /// Tonight's hearts and mine (live `/v1/plaza/tonight`; mock: Figma 69's sample,
    /// with my shared floated stars).
    private var tonight: (count: Int, mine: Int) {
        if model.useLiveAPI { return (model.tonightCount ?? 0, model.tonightMine ?? 0) }
        return (1284, model.stars.filter { $0.isFloated && $0.isShared }.count)
    }

    @State private var filter: PlazaFilter = .newest
    /// "더 보기": rows shown so far.
    @State private var shown = Self.page
    private static let page = 20
    @Environment(AppModel.self) private var model

    private var stars: [PlazaNebula] {
        let all: [PlazaNebula]
        switch filter {
        case .newest: all = model.plazaStarItems.sorted { $0.order < $1.order }
        // 17.2: stars without starlight can't be compared.
        case .similar: return model.plazaStarItems.filter(\.hasStarlight).sorted { $0.similarity > $1.similarity }
        case .kept: all = model.useLiveAPI ? model.plazaStarsBeside
            : model.plazaStarItems.filter { model.resonated.contains($0.id) }.sorted { $0.order < $1.order }
        }
        // Stars without starlight go below (stable within each group).
        return all.filter(\.hasStarlight) + all.filter { !$0.hasStarlight }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("우주 광장").textStyle(.h1).foregroundStyle(Color.textPrimary)
                    Text("별지기들이 나눈 별이에요. 눌러서 글을 읽고, 마음이 닿으면 공명을 남겨 보세요.")
                        .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                // 09-6 광장 이용 제한 중
                if model.isPlazaRestricted {
                    OperatorBanner(title: "광장 이용이 \(model.restrictedText(withTime: false))까지 멈춰요",
                                   message: "별을 나누거나 공명·곁에 두기·별빛 한 줄을 남길 수 없어요. 내 기록과 별은 그대로이고, 다른 별은 계속 읽을 수 있어요.",
                                   link: "자세히") { model.showPlazaRestricted = true }
                }

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

                // My shared stars live with the plaza, not in 설정 (2026-11-10).
                if model.nickname != nil {
                    Button(action: onShared) {
                        HStack(spacing: 2) {
                            Text("내가 나눈 별 \(model.stars.filter(\.isShared).count)개")
                                .textStyle(.bodyS)
                            Image(.iconChevronRight).renderingMode(.template).resizable()
                                .frame(width: 14, height: 14)
                        }
                        .foregroundStyle(Color.textSecondary)
                        .frame(minHeight: 32)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }

                if model.nickname == nil {
                    nicknameGate
                } else {
                    FlowRow(spacing: Space.sm) {
                        ForEach(PlazaFilter.allCases, id: \.self) { f in
                            DotChip(title: f.rawValue, isSelected: filter == f) {
                                withAnimation(.snappy) { filter = f; shown = Self.page }
                            }
                        }
                    }
                    starList
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .scrollIndicators(.hidden)
        .task {
            await model.loadPlaza()
            await model.loadTonight()
        }
    }

    /// 15.1: older accounts pick a name before using the plaza.
    private var nicknameGate: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("별지기 이름이 필요해요").textStyle(.h3).foregroundStyle(Color.textPrimary)
            Text("우주 광장에서는 나눈 별과 건넨 별빛 한 줄에 별지기 이름이 함께 보여요. 기록 쓰기와 별 띄우기는 이름 없이도 그대로예요.")
                .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("별지기 이름 정하기", action: onNickname).buttonStyle(.primary)
        }
        .padding(Space.lg)
        .itemCard(seed: "nickname-gate", minHeight: 0)
    }

    @ViewBuilder private var starList: some View {
        let stars = self.stars
        if stars.isEmpty {
            Group {
                if filter == .kept {
                    EmptyStateView(title: "곁에 둔 별이 아직 없어요",
                                   message: "마음이 닿은 별에 공명을 남기면\n여기서 다시 모아 볼 수 있어요.",
                                   action: ("새로 뜬 것 둘러보기", .outline, {
                                       withAnimation(.snappy) { filter = .newest }
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

/// 09-5 row thumbnail, also the 75 header's (56pt) so the star you tapped
/// is the one you open: its shape and mood colour on a dark tile.
struct PlazaStarThumb: View {
    var item: PlazaNebula
    var side: CGFloat = 44

    var body: some View {
        let k = side / 44
        // 17.2: a star without starlight is the faint default star.
        ShapeStar(spec: item.hasStarlight ? item.cardShape : StarShapeSpec(points: 4, sharpness: .soft),
                  color: item.cardMood.color.opacity(item.hasStarlight ? 1 : 0.5),
                  size: (item.hasStarlight ? 22 : 14) * k, halo: false)
            .shadow(color: item.cardMood.color.opacity(item.hasStarlight ? 0.75 : 0),
                    radius: (1 + CGFloat(item.cardDepth) * 1.2) * k)
            .frame(width: side, height: side)
            .background(Color.bgSurfaceRaised, in: .rect(cornerRadius: side == 44 ? 12 : 16))
            .accessibilityHidden(true)
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
                PlazaStarThumb(item: item)
                VStack(alignment: .leading, spacing: 3) {
                    Text("“\(item.line)”")
                        .textStyle(.observation)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    // 09-5: "{별지기} 「{제목}」 · {시각 | 별빛 없음}"
                    Text(subtitle)
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

    private var subtitle: String {
        let who = item.nickname.map { "\($0)  「\(item.starTitle ?? item.name)」" } ?? item.name
        let tail = item.hasStarlight ? item.sharedAt.map(Self.when) : "별빛 없음"
        return tail.map { "\(who) · \($0)" } ?? who
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
