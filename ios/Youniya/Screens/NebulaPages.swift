import SwiftUI

// MARK: - 89 / 90 Stars of my nebula

/// 89 나의 성운의 별 (and 90, its empty state): stars filtered by kind.
struct NebulaStarsView: View {
    enum Kind: CaseIterable {
        case floated, deep, supernova

        var label: String {
            switch self {
            case .floated: "떠 있는 별"
            case .deep: "깊은 별"
            case .supernova: "초신성"
            }
        }

        var note: String {
            switch self {
            case .floated: "지금 성운에 떠 있는 별이에요. 누르면 그날의 기록이 열려요."
            case .deep: "마음을 깊이 들여다본 별이에요. 누르면 그날의 기록이 열려요."
            case .supernova: "별빛이 900을 넘어 크게 빛난 별이에요."
            }
        }

        var emptyTitle: String {
            switch self {
            case .floated: "아직 떠 있는 별이 없어요"
            case .deep: "아직 깊은 별이 없어요"
            case .supernova: "아직 초신성이 된 별은 없어요"
            }
        }

        var emptyMessage: String {
            switch self {
            case .floated: "오늘의 마음을 별로 띄우면\n이곳에 하나씩 모여요."
            case .deep: "마음을 천천히 들여다본 날의 별이\n깊은 별로 남아요."
            case .supernova: "마음을 깊이 들여다본 날, 별빛이 900을 넘으면\n초신성으로 터져요. 서두르지 않아도 괜찮아요."
            }
        }

        func includes(_ star: StarItem) -> Bool {
            switch self {
            case .floated: star.isFloated
            case .deep: star.analysis?.isDeep == true
            case .supernova: star.analysis?.isSupernova == true
            }
        }
    }

    @Environment(AppModel.self) private var model
    var initial: Kind
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void

    @State private var kind: Kind?

    private var current: Kind { kind ?? initial }

    var body: some View {
        let stars = model.stars.filter(current.includes)
        VStack(spacing: 0) {
            TopAppBar(title: "나의 성운의 별", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    HStack(spacing: Space.sm) {
                        ForEach(Kind.allCases, id: \.self) { k in
                            FilterChip(title: "\(k.label) \(model.stars.filter(k.includes).count)",
                                       isSelected: k == current) {
                                withAnimation(.snappy) { kind = k }
                            }
                        }
                    }

                    Text(current.note)
                        .textStyle(.bodyS)
                        .foregroundStyle(Color.textSecondary)

                    if stars.isEmpty {
                        // 90 Empty State
                        VStack(spacing: Space.md) {
                            StarGlyph(floated: true)
                                .scaleEffect(40 / 18.14)
                                .frame(width: 40, height: 40)
                            Text(current.emptyTitle)
                                .textStyle(.h3)
                                .foregroundStyle(Color.textPrimary)
                            Text(current.emptyMessage)
                                .textStyle(.bodyM)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 96)
                        .accessibilityElement(children: .combine)
                    } else {
                        LazyVStack(spacing: Space.md) {
                            ForEach(stars) { star in
                                Button { onOpenStar(star) } label: { StarRow(star: star) }
                                    .buttonStyle(.plain)
                            }
                        }
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

// MARK: - 82 Brightness flow

/// 82 별빛 기록 · 밝기 흐름: the user's own starlight over time, never compared.
struct BrightnessFlowView: View {
    enum Range: String, CaseIterable { case recent = "최근 별", monthly = "월평균", all = "전체" }

    @Environment(AppModel.self) private var model
    var onBack: () -> Void

    @State private var range: Range = .recent

    /// Floated stars with starlight, oldest first.
    private var points: [(date: Date, value: Int)] {
        model.stars.compactMap { s in
            guard s.isFloated, let v = s.starlightValue else { return nil }
            return (s.date ?? .now, v)
        }
        .sorted { $0.date < $1.date }
    }

    private var monthly: [(month: Date, average: Int)] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: points) { cal.dateInterval(of: .month, for: $0.date)!.start }
        return groups.map { ($0.key, $0.value.map(\.value).reduce(0, +) / $0.value.count) }
            .sorted { $0.month < $1.month }
    }

    private var series: (title: String, values: [Int], labels: [String]) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        switch range {
        case .recent:
            let p = Array(points.suffix(8))
            f.dateFormat = "M/d"
            return ("최근 \(p.count)개의 별", p.map(\.value), p.map { f.string(from: $0.date) })
        case .monthly:
            let m = Array(monthly.suffix(8))
            f.dateFormat = "M월"
            return ("달마다 평균", m.map(\.average), m.map { f.string(from: $0.month) })
        case .all:
            f.dateFormat = "M/d"
            return ("전체 \(points.count)개의 별", points.map(\.value), points.map { f.string(from: $0.date) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "별빛 기록", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("나의 별빛 흐름")
                            .textStyle(.h2)
                            .foregroundStyle(Color.textPrimary)
                        Text("다른 사람과 비교하지 않아요. 지난날의 나와만 나란히 놓아 봐요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    HStack(spacing: Space.sm) {
                        ForEach(Range.allCases, id: \.self) { r in
                            // Figma 82/109: dot chips, like the plaza filters.
                            DotChip(title: r.rawValue, isSelected: r == range) {
                                withAnimation(.snappy) { range = r }
                            }
                        }
                    }

                    if points.count < 3 {
                        // 109
                        EmptyStateView(title: "흐름을 그리기엔 별이 조금 적어요",
                                       message: "지금은 별이 \(points.count)개예요. 별이 더 모이면\n흐름을 선으로 이어 보여 드릴게요.")
                            .padding(.top, Space.xxxl)
                    } else {
                        trendCard
                        if !monthly.isEmpty { monthlyCard }
                    }

                    Text("숫자는 평가가 아니에요. 빛이 머물렀던 자리를 보여줄 뿐이에요.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }

    private var trendCard: some View {
        let s = series
        let average = s.values.isEmpty ? 0 : s.values.reduce(0, +) / s.values.count
        return VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                Text(s.title)
                    .textStyle(.labelM)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !s.values.isEmpty {
                    Text("평균 \(average)")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            if s.values.count < 2 {
                Text("별을 두 개 이상 띄우면 흐름이 그려져요.")
                    .textStyle(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                TrendChart(values: s.values)
                    .frame(height: 170)
                    .accessibilityElement()
                    .accessibilityLabel("\(s.title), 평균 \(average), 마지막 \(s.values.last ?? 0)")
                xLabels(s.labels)
            }
        }
        .padding(Space.lg)
        .itemCard(seed: "trend", minHeight: 0)
    }

    /// Up to four evenly spaced labels under the plot (Figma: 10/6 … 11/3).
    private func xLabels(_ labels: [String]) -> some View {
        let picks: [String] = {
            guard labels.count > 4 else { return labels }
            return (0..<4).map { labels[Int((Double($0) / 3 * Double(labels.count - 1)).rounded())] }
        }()
        return HStack {
            ForEach(picks.indices, id: \.self) { i in
                Text(picks[i])
                if i < picks.count - 1 { Spacer(minLength: 0) }
            }
        }
        .textStyle(.caption)
        .foregroundStyle(Color.textTertiary)
        .padding(.leading, 30)
        .accessibilityHidden(true)
    }

    private var monthlyCard: some View {
        let rows = Array(monthly.suffix(3))
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월"
        let thisMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start
        return VStack(alignment: .leading, spacing: Space.md) {
            Text("월평균 별빛")
                .textStyle(.labelM)
                .foregroundStyle(Color.textPrimary)
            ForEach(rows, id: \.month) { row in
                let current = row.month == thisMonth
                HStack(spacing: Space.md) {
                    Text(f.string(from: row.month))
                        .textStyle(.labelS)
                        .frame(width: 32, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.borderDefault.opacity(0.5))
                            // Figma: 1pt of bar per 5 starlight.
                            Capsule().fill(current ? Color.starBright : Color.hex(0x8555EF))
                                .frame(width: min(geo.size.width, CGFloat(row.average) / 5))
                        }
                    }
                    .frame(height: 6)
                    Text(current ? "\(row.average) · 진행 중" : "\(row.average)")
                        .textStyle(.caption)
                }
                .foregroundStyle(Color.textSecondary)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Space.lg)
        .itemCard(seed: "monthly", minHeight: 0)
    }
}

/// Figma `Plot`: grid at 500/700/900, smooth line with a soft area, the last
/// point gold with its value.
private struct TrendChart: View {
    var values: [Int]

    /// Figma scale: 100 starlight = 25pt, 700 at y 83 of 170.
    private func y(_ v: Int) -> CGFloat { 83 - CGFloat(v - 700) * 0.25 }

    var body: some View {
        GeometryReader { geo in
            let left: CGFloat = 36, right: CGFloat = 6
            let w = geo.size.width - left - right
            let step = values.count > 1 ? w / CGFloat(values.count - 1) : 0
            let pts = values.enumerated().map {
                CGPoint(x: left + CGFloat($0.offset) * step, y: min(166, max(4, y($0.element))))
            }
            ZStack(alignment: .topLeading) {
                ForEach([900, 700, 500], id: \.self) { v in
                    Rectangle().fill(Color.borderDefault.opacity(0.6))
                        .frame(width: geo.size.width - 28, height: 1)
                        .offset(x: 28, y: y(v))
                    Text("\(v)")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .offset(y: y(v) - 9)
                }
                smooth(pts, closed: true, bottom: 159)
                    .fill(Color.hex(0x8555EF).opacity(0.14))
                smooth(pts, closed: false, bottom: 159)
                    .stroke(Color.hex(0x8555EF), lineWidth: 2)
                ForEach(pts.indices.dropLast(), id: \.self) { i in
                    Circle().fill(Color.hex(0x8555EF)).frame(width: 5, height: 5)
                        .position(pts[i])
                }
                if let last = pts.last {
                    Circle().fill(Color.starBright).frame(width: 10, height: 10)
                        .shadow(color: Color.starBright.opacity(0.7), radius: 5)
                        .position(last)
                    Text("\(values.last ?? 0)")
                        .textStyle(.labelS)
                        .foregroundStyle(Color.starBright)
                        .position(x: last.x - 18, y: last.y - 16)
                }
            }
        }
    }

    /// Horizontal-tangent curve through the points, like the Figma path.
    private func smooth(_ p: [CGPoint], closed: Bool, bottom: CGFloat) -> Path {
        Path { path in
            guard let first = p.first else { return }
            path.move(to: first)
            for i in 1..<p.count {
                let a = p[i - 1], b = p[i], mid = (a.x + b.x) / 2
                path.addCurve(to: b, control1: CGPoint(x: mid, y: a.y), control2: CGPoint(x: mid, y: b.y))
            }
            if closed, let last = p.last {
                path.addLine(to: CGPoint(x: last.x, y: bottom))
                path.addLine(to: CGPoint(x: first.x, y: bottom))
                path.closeSubpath()
            }
        }
    }
}

// MARK: - 81 My Milky Way

/// 81 나의 은하수: every star along one river of time, and this month's cards.
struct MilkyWayView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void

    /// Stars oldest first, with a date.
    private var timeline: [(star: StarItem, date: Date)] {
        model.stars.map { ($0, $0.date ?? .now) }.sorted { $0.date < $1.date }
    }

    var body: some View {
        let latestMonth = timeline.last.map { Calendar.current.dateInterval(of: .month, for: $0.date)!.start }
        let album = timeline.reversed().filter { item in
            guard let m = latestMonth else { return false }
            return item.star.isFloated && item.date >= m
        }.map(\.star)

        VStack(spacing: 0) {
            TopAppBar(title: "나의 은하수", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("시간의 길을 따라 흐르는 은하수")
                            .textStyle(.h2)
                            .foregroundStyle(Color.textPrimary)
                        Text("달마다 채운 별자리가 시간순으로 이어져요. 은빛 점선은 서로 다른 달의 별을 이은 별 잇기예요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    GalaxyRiver(timeline: timeline)
                        .frame(height: 300)

                    HStack(spacing: Space.sm) {
                        Text("별 카드 앨범")
                            .textStyle(.labelM)
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let latestMonth {
                            Text("\(Calendar.current.component(.month, from: latestMonth))월 · \(album.count)장")
                                .textStyle(.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }

                    if album.isEmpty {
                        Text("별을 띄우면 이곳에 카드로 모여요.")
                            .textStyle(.bodyS)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 10) {
                                ForEach(album) { star in
                                    Button { onOpenStar(star) } label: { AlbumCard(star: star) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Space.xl)
                        }
                        .scrollIndicators(.hidden)
                        .padding(.horizontal, -Space.xl)
                    }

                    Text("은하수는 별이 쌓일수록 길어져요. 지난 시간을 다시 걷고 싶을 때 천천히 들러 보세요.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }
}

/// Figma `Star Card` (118pt): mood glow, starlight, title (2 lines), date.
private struct AlbumCard: View {
    var star: StarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle().fill(star.mood.color).frame(width: 10, height: 10)
                .shadow(color: Color.hex(0x9980FF).opacity(0.6), radius: 4)
            Text("\(star.starlightValue ?? 0)")
                .textStyle(.h3)
                .foregroundStyle(Color.textPrimary)
            Text(star.title)
                .textStyle(.labelS)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
            Text(star.shortDateText)
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(width: 118 - Space.lg * 2, alignment: .leading)
        .padding(Space.lg)
        .itemCard(seed: "album-\(star.id)", minHeight: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(star.title), 별빛 \(star.starlightValue ?? 0), \(star.shortDateText)")
    }
}

/// Figma `Galaxy Canvas` (342×300): a glowing river from the bottom-left (oldest)
/// to the top-right (now), a dot per star in its mood color, rings at each month.
private struct GalaxyRiver: View {
    var timeline: [(star: StarItem, date: Date)]
    @Environment(\.skyTheme) private var sky

    /// Figma path in the 342×205 box at y 45: M0 205 C80 170 110 105 175 105 C240 105 270 25 342 0.
    private func point(_ t: Double, in size: CGSize) -> CGPoint {
        let sx = size.width / 342, sy: CGFloat = 1, oy: CGFloat = 45
        func bez(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ u: Double) -> CGPoint {
            let a = pow(1 - u, 3), b = 3 * pow(1 - u, 2) * u, c = 3 * (1 - u) * u * u, d = u * u * u
            return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                           y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
        }
        let p = t < 0.5
            ? bez(CGPoint(x: 0, y: 205), CGPoint(x: 80, y: 170), CGPoint(x: 110, y: 105), CGPoint(x: 175, y: 105), t * 2)
            : bez(CGPoint(x: 175, y: 105), CGPoint(x: 240, y: 105), CGPoint(x: 270, y: 25), CGPoint(x: 342, y: 0), t * 2 - 1)
        return CGPoint(x: p.x * sx, y: p.y * sy + oy)
    }

    private func river(in size: CGSize) -> Path {
        let sx = size.width / 342
        func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y + 45) }
        return Path { p in
            p.move(to: q(0, 205))
            p.addCurve(to: q(175, 105), control1: q(80, 170), control2: q(110, 105))
            p.addCurve(to: q(342, 0), control1: q(240, 105), control2: q(270, 25))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // Stars in time order, spread evenly: oldest at 0.04, newest at 0.96.
            let n = timeline.count
            let t: (Int) -> Double = { n > 1 ? 0.04 + 0.92 * Double($0) / Double(n - 1) : 0.96 }
            let months = monthMarks(t)

            ZStack(alignment: .topLeading) {
                river(in: size)
                    .stroke(Color.hex(0x8555EF).opacity(0.3), style: StrokeStyle(lineWidth: 80, lineCap: .round))
                    // Figma layer blur 30 ≈ SwiftUI radius 15.
                    .blur(radius: 15)
                river(in: size)
                    .stroke(Color.starClear.opacity(0.16), style: StrokeStyle(lineWidth: 26, lineCap: .round))
                    .blur(radius: 7)

                // A dot per star, scattered a little around the river.
                ForEach(timeline.indices, id: \.self) { i in
                    let item = timeline[i]
                    var rng = SeededRandom(seed: item.star.id.uuidString)
                    let p = point(t(i), in: size)
                    let d = rng.next(in: 2...5)
                    Circle().fill(item.star.mood.color.opacity(rng.next(in: 0.6...0.95)))
                        .frame(width: d, height: d)
                        .position(x: p.x + rng.next(in: -14...14), y: p.y + rng.next(in: -14...14))
                }

                ForEach(months.indices, id: \.self) { i in
                    let m = months[i]
                    let p = point(m.t, in: size)
                    let now = i == months.count - 1
                    Circle().strokeBorder(now ? Color.starBright : Color.textSecondary.opacity(0.5), lineWidth: 1.2)
                        .frame(width: 18, height: 18)
                        .position(p)
                    Text(m.label)
                        .textStyle(.caption)
                        .foregroundStyle(now ? Color.starBright : Color.textTertiary)
                        .position(x: p.x + 1, y: p.y + 23)
                    // Figma 81: "지금 여기" sits with the last ring, at the end of the path.
                    if now {
                        Text("지금 여기")
                            .textStyle(.caption)
                            .foregroundStyle(Color.starBright)
                            .fixedSize()
                            .position(x: min(size.width - 28, max(28, p.x)), y: p.y - 22)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .cosmos("galaxy", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .clipShape(.rect(cornerRadius: Radius.lg))
        }
        .accessibilityElement()
        .accessibilityLabel("별 \(timeline.count)개가 시간순으로 이어진 은하수")
    }

    /// The first star of each of the last four months.
    private func monthMarks(_ t: (Int) -> Double) -> [(t: Double, label: String)] {
        let cal = Calendar.current
        var seen = Set<Date>()
        var marks: [(Double, String)] = []
        for (i, item) in timeline.enumerated() {
            let m = cal.dateInterval(of: .month, for: item.date)!.start
            if seen.insert(m).inserted {
                marks.append((t(i), "\(cal.component(.month, from: m))월"))
            }
        }
        return Array(marks.suffix(4))
    }
}

#Preview("89") {
    let model = AppModel()
    model.fillSampleStars()
    return NebulaStarsView(initial: .floated, onBack: {}, onOpenStar: { _ in }).environment(model)
}

#Preview("82") {
    let model = AppModel()
    model.fillSampleStars()
    return BrightnessFlowView(onBack: {}).environment(model)
}

#Preview("81") {
    let model = AppModel()
    model.fillSampleStars()
    return MilkyWayView(onBack: {}, onOpenStar: { _ in }).environment(model)
}
