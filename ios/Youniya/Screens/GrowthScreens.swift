import SwiftUI

// MARK: - 71 Float to the sky

/// 71 하늘에 띄우기 시트 (over 77): what goes out, what never does, two options.
struct FloatNebulaSheet: View {
    @Environment(AppModel.self) private var model
    /// 71-1's height cap (85% of the screen).
    var maxPickerHeight: CGFloat = 700
    var onFloat: () -> Void
    var onLater: () -> Void

    @State private var receiveLines = true
    @State private var showQuote = false
    /// The line picked on 71-1; turning the option on opens the picker.
    @State private var quote: String?
    @State private var pickQuote = DebugScreen.is("71-1")
    @State private var pickerHeight: CGFloat = 480

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
            optionRow("가린 한 문장 함께 보이기", "직접 골라 가린 한 줄만 보여요", isOn: Binding(
                get: { showQuote },
                set: { on in
                    if on { pickQuote = true } else { showQuote = false; quote = nil }
                }))

            Text("띄운 성운은 설정 › 모든 공유 거두기에서 언제든 거둘 수 있어요.")
                .textStyle(.caption).foregroundStyle(Color.textTertiary)

            VStack(spacing: Space.md) {
                Button("띄우기") {
                    model.floatMyNebula(receiveLines: receiveLines, quote: showQuote ? quote : nil)
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
            // The picked line isn't kept, so a float again asks for it again.
            if let s = model.skyShare { receiveLines = s.receiveLines }
        }
        // 71-1 함께 보일 한 줄을 골라요: cancel leaves the option off.
        .sheet(isPresented: $pickQuote) {
            SentencePickerSheet(
                title: "함께 보일 한 줄을 골라요",
                detail: "성운에 모인 별들의 문장 중 하나만 함께 보여요. 이름·연락처·장소는 ●●●로 가려져요.",
                actionTitle: "이 한 줄 함께 보이기",
                options: model.nebulaSentenceOptions(),
                maxHeight: maxPickerHeight,
                onPick: { sentence in
                    quote = sentence
                    withAnimation(.snappy(duration: 0.2)) { showQuote = true }
                    pickQuote = false
                },
                onCancel: { pickQuote = false }
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pickerHeight = $0 }
            .presentationDetents([.height(pickerHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "quote-sheet") }
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

/// 75 다른 이의 별: one anonymous star, its 대표 문장 and (75-3) its whole text,
/// resonance. Opened from a star inside a plaza nebula (73), or from a 별 기록
/// row (09-3); from the plaza there's no owner nebula to open, so 「공명 남기기」
/// is the only action.
struct GalaxyStarView: View {
    @Environment(AppModel.self) private var model
    /// From 73: the nebula and the star's title. From 09-3: the plaza star.
    var nebula: GalaxyNebula? = nil
    var starTitle: String = ""
    var plazaStar: PlazaNebula? = nil
    var onBack: () -> Void
    /// 75-2: back to the previous page with the "차단했어요" toast.
    var onBlocked: () -> Void = {}

    @State private var showMenu = DebugScreen.is("75-1")
    /// Live 75-3: the whole text, from the plaza star's detail.
    @State private var liveText: (title: String, body: String)?

    private var title: String { plazaStar?.name ?? starTitle }
    private var key: String { plazaStar?.id ?? "star:\(nebula?.name ?? ""):\(starTitle)" }
    private var resonated: Bool { model.resonated.contains(key) }
    private var quote: String { plazaStar?.line ?? nebula?.quote ?? "" }
    private var depth: Int { plazaStar?.cardDepth ?? max(1, (nebula?.stage ?? 2) - 1) }
    private var spec: StarShapeSpec {
        plazaStar?.cardShape ?? nebula?.stars.first { $0.title == starTitle }?.spec ?? .init(points: 5, sharpness: .normal)
    }
    /// 75-3: the whole star (title and body, contacts masked by the server).
    private var fullText: (title: String, body: String)? {
        guard let p = plazaStar, p.fullText else { return nil }
        if let liveText { return (liveText.title.isEmpty ? p.name : liveText.title, liveText.body) }
        return p.fullBody.map { (p.fullTitle ?? p.name, $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "다른 이의 별", onBack: onBack, onMore: { showMenu.toggle() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(title)
                        .textStyle(.h2).foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: Space.sm) {
                        Tag(text: "익명의 별지기", tone: .neutral)
                        Tag(text: "깊이 \(depth)단계", tone: .gold)
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
                        ShapeStar(spec: spec, color: .starBright, size: 58, rays: true)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Space.xs) {
                        // The quote is empty while its owner picks a new one (12-3).
                        if !quote.isEmpty {
                            Text("“\(quote)”")
                                .textStyle(.observation).foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(fullText != nil ? "대표 문장이에요. 아래에서 글 전체를 읽을 수 있어요."
                                             : "본인이 고른 한 문장만 나눈 별이에요")
                            .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.lg)
                    .flatCard(seed: "star-quote")

                    if let fullText {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text(fullText.title)
                                .textStyle(.h3).foregroundStyle(Color.textPrimary)
                            // Figma: Serif 15, line height 175%.
                            Text(fullText.body)
                                .font(.custom("NotoSerifKR-Regular", size: 15, relativeTo: .callout))
                                .lineSpacing(15 * 0.75 - 4)
                                .foregroundStyle(Color.textSecondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    actions
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .task {
            if model.useLiveAPI, let p = plazaStar, p.fullText, let id = p.serverID {
                liveText = await model.plazaStarText(id)
            }
        }
        .modifier(PlazaSafetyModifier(showMenu: $showMenu, target: .star, nebulaName: nebula?.name ?? title,
                                       serverID: plazaStar?.serverID ?? nebula?.serverID, onBlocked: onBlocked))
    }

    @ViewBuilder private var actions: some View {
        let resonate = Button(resonated ? "공명했어요" : "공명 남기기") {
            withAnimation(.snappy) { model.toggleResonance(key) }
        }
        if plazaStar != nil {
            // From the plaza: no owner nebula to open (손님별 들이기 left with 2026-11-09).
            resonate.buttonStyle(.primary)
                .accessibilityAddTraits(resonated ? .isSelected : [])
        } else {
            HStack(spacing: Space.md) {
                resonate.buttonStyle(.secondary).frame(width: 140)
                Button("이 사람의 성운 보기", action: onBack)
                    .buttonStyle(.primary)
            }
        }
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
        if let s = byDate.first(where: { !$0.isFloated }), let d = s.date { out.append(.init(title: "처음 별빛 없이 띄웠어요", date: d)) }
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

    private static let ordinals = ["첫 번째", "두 번째", "세 번째", "네 번째"]

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
        // Stage 0 (fewer than 12 stars): the first step is in progress, the rest locked.
        let gathering = current == 0 && s == 1
        let passed = s < current, now = s == current || gathering
        let name = AppModel.stageNames[s - 1]
        let (condition, result): (String, String) = {
            switch s {
            case 1: ("별 \(AppModel.firstStageStars)개가 모였을 때", "점선으로 이어진 맑고 풋풋한 성운이 생겨요.")
            case 2: ("깊은 속마음을 담은 별 6개", "별들 사이에 온화한 금빛 연결선이 이어져요.")
            case 3: ("깊은 별 15개 · 별빛 900 이상 1번", "빛구름이 짙어지고 별이 찬란하게 반짝여요.")
            default: ("여러 감정의 결 · 깊은 별 30개", "나만의 은하수가 완성되고 우주를 내다볼 수 있어요.")
            }
        }()
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                // Figma 86: "첫 번째 걸음 · 지나옴", "두 번째 걸음 · 지금 여기", "세 번째 걸음"
                Text(gathering ? "\(Self.ordinals[0]) 걸음 · 모으는 중"
                     : now ? "\(Self.ordinals[s - 1]) 걸음 · 지금 여기"
                     : passed ? "\(Self.ordinals[s - 1]) 걸음 · 지나옴" : "\(Self.ordinals[s - 1]) 걸음")
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
            if gathering { progress(next: 1) } else if now && s < 4 { progress(next: s + 1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .flatCard(seed: "stage-\(s)")
        .overlay {
            if now { RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.brandPrimary, lineWidth: 1.5) }
        }
        // Stages not reached yet are dimmed.
        .opacity(s > current && !gathering ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    /// "3단계까지": the requirements for the next stage as bars.
    private func progress(next: Int) -> some View {
        let bright = model.stars.filter { ($0.starlightValue ?? 0) >= 900 }.count
        let moods = Set(model.stars.filter(\.isFloated).map(\.mood)).count
        let rows: [(String, Int, Int)] = switch next {
        case 1: [("별", model.stars.count, AppModel.firstStageStars)]
        case 2: [("깊은 별", model.deepCount, 6)]
        case 3: [("깊은 별", model.deepCount, 15), ("별빛 900 이상", bright, 1)]
        default: [("깊은 별", model.deepCount, 30), ("감정의 결", moods, 3)]
        }
        return VStack(alignment: .leading, spacing: Space.sm) {
            // Figma 86: "세 번째 걸음까지"
            Text("\(Self.ordinals[next - 1]) 걸음까지").textStyle(.caption).foregroundStyle(Color.textTertiary)
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
