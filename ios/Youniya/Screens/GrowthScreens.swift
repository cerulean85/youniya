import SwiftUI

// MARK: - 71 Float to the sky

/// 71 하늘에 띄우기 시트 (over 77): what goes out, what never does, two options.
struct FloatNebulaSheet: View {
    @Environment(AppModel.self) private var model
    var onFloat: () -> Void
    var onLater: () -> Void

    @State private var receiveLines = true
    @State private var showQuote = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.md) {
                Text("성운을 하늘에 띄울까요?")
                    .textStyle(.h2).foregroundStyle(Color.textPrimary)
                Text("띄우기 전에, 무엇이 나가고 무엇이 나가지 않는지 먼저 보여 드려요.")
                    .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            listCard("나가는 것", tone: Color.brandPrimaryText, check: true, items: [
                "별의 모양과 빛깔",
                "깊이 분포 (몇 단계에 닿았는지)",
                "성운 이름 — \(model.nebulaName)",
            ])
            listCard("나가지 않는 것", tone: Color.textTertiary, check: false, items: [
                "내가 쓴 글과 날짜",
                "이름과 계정 정보",
            ])

            optionRow("별빛 한 줄 받기", "다른 사람이 짧은 한 줄을 건넬 수 있어요", isOn: $receiveLines)
            optionRow("가린 한 문장 함께 보이기", "직접 골라 가린 한 줄만 보여요", isOn: $showQuote)

            Text("띄운 성운은 보관함에서 언제든 거둘 수 있어요.")
                .textStyle(.caption).foregroundStyle(Color.textTertiary)

            VStack(spacing: Space.md) {
                Button("띄우기") {
                    model.skyShare = NebulaSkyShare(name: model.nebulaName, receiveLines: receiveLines, showQuote: showQuote)
                    onFloat()
                }
                .buttonStyle(.primary)
                Button("다음에", action: onLater).buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.lg)
        .onAppear {
            if let s = model.skyShare { receiveLines = s.receiveLines; showQuote = s.showQuote }
        }
    }

    private func listCard(_ title: String, tone: Color, check: Bool, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).textStyle(.caption).foregroundStyle(tone)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Text(check ? "✓" : "✕")
                        .textStyle(.labelS)
                        .foregroundStyle(check ? Color.textPrimary : Color.textTertiary)
                        .accessibilityHidden(true)
                    Text(item)
                        .textStyle(.bodyS)
                        .foregroundStyle(check ? Color.textPrimary : Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .flatCard(seed: "float-\(title)")
        .accessibilityElement(children: .combine)
    }

    private func optionRow(_ title: String, _ detail: String, isOn: Binding<Bool>) -> some View {
        Button { withAnimation(.snappy(duration: 0.2)) { isOn.wrappedValue.toggle() } } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    Text(detail).textStyle(.caption).foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Capsule()
                    .fill(isOn.wrappedValue ? Color.brandPrimary : Color.borderDefault)
                    .frame(width: 44, height: 26)
                    .overlay(alignment: isOn.wrappedValue ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 20, height: 20).padding(3)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOn.wrappedValue ? "켜짐" : "꺼짐")
        .accessibilityAddTraits(.isToggle)
    }
}

// MARK: - 75 Someone's star

/// 75 다른 이의 별: one anonymous star, its chosen sentence, resonance.
struct GalaxyStarView: View {
    @Environment(AppModel.self) private var model
    var nebula: GalaxyNebula
    var starTitle: String
    var onBack: () -> Void

    private var key: String { "star:\(nebula.name):\(starTitle)" }
    private var resonated: Bool { model.resonated.contains(key) }

    var body: some View {
        let star = nebula.stars.first { $0.title == starTitle }
        VStack(spacing: 0) {
            TopAppBar(title: "다른 이의 별", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(starTitle)
                        .textStyle(.h2).foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: Space.sm) {
                        Tag(text: "익명의 별지기", tone: .neutral)
                        Tag(text: "\(max(1, nebula.stage - 1))단계", tone: .gold)
                    }

                    // Figma `Hero`: the star in gold, a dotted orbit, four small stars.
                    // Figma: a tilted elliptical orbit (190×120) with two dashed rings.
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Color.starBright.opacity(0.25), .clear],
                                                 center: .center, startRadius: 0, endRadius: 100))
                            .frame(width: 200, height: 200)
                        ForEach([1.0, 0.72], id: \.self) { k in
                            Ellipse()
                                .strokeBorder(Color.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                                .frame(width: 190 * k, height: 120 * k)
                        }
                        ForEach(0..<4, id: \.self) { i in
                            let a = [192.0, 300.0, 15.0, 120.0][i] * .pi / 180
                            Circle().fill([Color.emotionSorrow, .emotionCalm, .brandWarm, .brandPrimary][i])
                                .frame(width: i == 3 ? 7 : 10, height: i == 3 ? 7 : 10)
                                .offset(x: cos(a) * 95, y: sin(a) * 60)
                        }
                        ShapeStar(spec: star?.spec ?? .init(points: 5, sharpness: .normal),
                                  color: .starBright, size: 58, rays: true)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("“\(nebula.quote)”")
                            .textStyle(.observation).foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("본인이 골라 공개한 한 문장이에요. 글 전체는 나가지 않아요.")
                            .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.lg)
                    .flatCard(seed: "star-quote")

                    HStack(spacing: Space.md) {
                        Button("공명 \(nebula.resonance + (resonated ? 1 : 0))") {
                            withAnimation(.snappy) { model.toggleResonance(key) }
                        }
                        .buttonStyle(.secondary)
                        .frame(width: 140)
                        Button("이 사람의 성운 보기", action: onBack)
                            .buttonStyle(.primary)
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }
}

// MARK: - 65 Slowly growing nebula

/// 65 천천히 자라는 성운 (77 "자라는 모습"): the nebula widens as stars gather.
struct NebulaGrowthView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onMoments: () -> Void
    var onDraw: () -> Void

    /// Figma 65 dot colors, in order.
    private static let palette: [Color] = [.starBright, .emotionCalm, .brandWarm, .emotionSorrow, .brandPrimary, .starClear, .emotionInsight]

    /// Figma 65 dot places (342×300), then more as stars gather.
    private static let places: [CGPoint] = [
        CGPoint(x: 76, y: 80), CGPoint(x: 166, y: 130), CGPoint(x: 256, y: 80),
        CGPoint(x: 126, y: 220), CGPoint(x: 236, y: 220),
        CGPoint(x: 40, y: 180), CGPoint(x: 300, y: 170), CGPoint(x: 190, y: 40), CGPoint(x: 180, y: 280),
    ]

    var body: some View {
        let floated = model.stars.filter(\.isFloated)
        // The nebula widens slowly: one more dot for every few stars.
        let shown = Array(floated.prefix(min(Self.places.count, max(1, 3 + floated.count / 4))))
        VStack(spacing: 0) {
            TopAppBar(title: "나의 성운", onBack: onBack)

            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("천천히 자라는 성운").textStyle(.h2).foregroundStyle(Color.textPrimary)
                    Text("별이 모일수록 성운이 넓어져요.").textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { i, star in
                            let p = Self.places[i]
                            // Figma: every dot its own color, in the palette order.
                            let color = Self.palette[i % Self.palette.count]
                            Circle().fill(color)
                                .frame(width: 20, height: 20)
                                .shadow(color: color.opacity(0.5), radius: 8)
                                .position(x: p.x / 342 * geo.size.width, y: p.y / 300 * geo.size.height)
                        }
                    }
                }
                .frame(height: 300)
                .accessibilityElement()
                .accessibilityLabel("별 \(shown.count)개로 이루어진 성운")

                NoticeBanner(message: "별 \(floated.count)개 · 성운 \(model.drawnNebulae.count)개. 빠르게 늘릴 필요는 없어요.")

                LinkChip(title: "지나온 순간 보기 ›", action: onMoments)

                Spacer(minLength: 0)

                Button("성운 그리기", action: onDraw).buttonStyle(.secondary)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }
}

// MARK: - 66 Moments

/// 66 지나온 순간들: firsts and milestones, without comparison.
struct GrowthMomentsView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void

    private struct Moment: Identifiable { var title: String; var date: Date; var id: String { title } }

    private var moments: [Moment] {
        let byDate = model.stars.sorted { ($0.date ?? .now) < ($1.date ?? .now) }
        var out: [Moment] = []
        if let s = byDate.first(where: \.isFloated), let d = s.date { out.append(.init(title: "첫 별을 띄웠어요", date: d)) }
        if let s = byDate.first(where: { !$0.isFloated }), let d = s.date { out.append(.init(title: "처음 조용히 품었어요", date: d)) }
        for n in [10, 30, 50, 100] where byDate.count >= n {
            if let d = byDate[n - 1].date { out.append(.init(title: "별 \(n)개가 모였어요", date: d)) }
        }
        if let s = byDate.first(where: { $0.analysis?.isDeep == true }), let d = s.date {
            out.append(.init(title: "처음 깊은 별이 떴어요", date: d))
        }
        if let n = model.drawnNebulae.first { out.append(.init(title: "첫 성운을 그렸어요", date: n.createdAt)) }
        return out.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "지나온 순간", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("지나온 순간들").textStyle(.h2).foregroundStyle(Color.textPrimary)
                        Text("비교하지 않고, 있었던 일만 담아요.").textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    RecordsHero().frame(height: 130)

                    if moments.isEmpty {
                        Text("첫 별을 띄우면 이곳에 순간이 쌓여요.")
                            .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    } else {
                        VStack(spacing: Space.md) {
                            ForEach(moments) { m in
                                InfoCard(seed: "moment-\(m.title)", title: m.title, detail: Self.day(m.date))
                            }
                        }
                    }
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }

    private static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}

// MARK: - 86 Four stages

/// 86 성운이 자라는 네 걸음: where the nebula is, and what the next step needs.
struct GrowthStagesView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void

    var body: some View {
        let stage = model.growthStage
        VStack(spacing: 0) {
            TopAppBar(title: "나의 성운", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("성운이 자라는 네 걸음").textStyle(.h2).foregroundStyle(Color.textPrimary)
                        Text("서두르지 않아도 괜찮아요. 마음이 쌓이는 만큼 천천히 자라요.")
                            .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    ForEach(1...4, id: \.self) { s in
                        stageCard(s, current: stage)
                    }
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }

    private func stageCard(_ s: Int, current: Int) -> some View {
        let passed = s < current, now = s == current
        let name = AppModel.stageNames[s - 1]
        let (condition, result): (String, String) = {
            switch s {
            case 1: ("별 \(model.floatedCount)개가 모였을 때", "점선으로 이어진 맑고 풋풋한 성운이 생겨요.")
            case 2: ("깊은 속마음을 담은 별 6개", "별들 사이에 온화한 금빛 연결선이 이어져요.")
            case 3: ("깊은 별 15개 · 별빛 900 이상 1번", "빛구름이 짙어지고 별이 찬란하게 반짝여요.")
            default: ("여러 감정의 결 · 깊은 별 30개", "나만의 은하수가 완성되고 우주를 내다볼 수 있어요.")
            }
        }()
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Text(now ? "\(s)단계 · 지금 여기" : passed ? "\(s)단계 · 지나옴" : "\(s)단계")
                    .textStyle(.labelS)
                    .foregroundStyle(now ? Color.white : Color.textSecondary)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, 6)
                    .background {
                        if now { Capsule().fill(Color.hex(0x8555EF)) }
                        else if passed { Capsule().strokeBorder(Color.borderDefault, lineWidth: 1) }
                    }
                Text(name).textStyle(.labelM).foregroundStyle(Color.textPrimary)
            }
            Text(condition)
                .textStyle(.caption)
                .foregroundStyle(now ? Color.starBright : Color.textTertiary)
            Text(result)
                .textStyle(.bodyS)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if now && s < 4 { progress(next: s + 1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .flatCard(seed: "stage-\(s)")
        .overlay {
            if now { RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.brandPrimary, lineWidth: 1.5) }
        }
        // Stages not reached yet are dimmed.
        .opacity(s > current ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    /// "3단계까지": the requirements for the next stage as bars.
    private func progress(next: Int) -> some View {
        let bright = model.stars.filter { ($0.starlightValue ?? 0) >= 900 }.count
        let moods = Set(model.stars.filter(\.isFloated).map(\.mood)).count
        let rows: [(String, Int, Int)] = switch next {
        case 2: [("깊은 별", model.deepCount, 6)]
        case 3: [("깊은 별", model.deepCount, 15), ("별빛 900 이상", bright, 1)]
        default: [("깊은 별", model.deepCount, 30), ("감정의 결", moods, 3)]
        }
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text("\(next)단계까지").textStyle(.caption).foregroundStyle(Color.textTertiary)
            ForEach(rows, id: \.0) { label, value, goal in
                HStack(spacing: Space.md) {
                    Text(label).textStyle(.caption).foregroundStyle(Color.textSecondary)
                        .frame(width: 84, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.borderDefault.opacity(0.5))
                            Capsule().fill(Color.hex(0x8555EF))
                                .frame(width: geo.size.width * min(1, CGFloat(value) / CGFloat(goal)))
                        }
                    }
                    .frame(height: 4)
                    Text("\(min(value, goal)) / \(goal)").textStyle(.caption).foregroundStyle(Color.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, Space.xs)
    }
}

#Preview("86") {
    let model = AppModel()
    model.fillSampleStars()
    return GrowthStagesView(onBack: {}).environment(model)
}
