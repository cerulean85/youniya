import SwiftUI

/// Filters on the records tab (115, 118).
enum RecordsFilter: Hashable {
    case all, floated, kept, mood(Mood)
}

/// 115 기록 · 목록 / 116 달력 / 117 검색 / 118 간직한 별 / 119 비어 있음.
struct RecordsView: View {
    @Environment(AppModel.self) private var model
    var onOpenStar: (StarItem) -> Void
    /// "밝기 흐름 보기" → 82
    var onBrightness: () -> Void = {}
    /// 119 "간직할 글 쓰기"
    var onCompose: () -> Void = {}
    @Binding var filter: RecordsFilter

    private enum Mode { case list, calendar }
    @State private var mode: Mode = DebugScreen.is("116") ? .calendar : .list
    @State private var query = DebugScreen.is("117") ? "은하수 아래 고래" : ""
    @FocusState private var searching: Bool
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var day: Date?

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var filtered: [StarItem] {
        model.stars.filter { s in
            switch filter {
            case .all: true
            case .floated: s.isFloated
            case .kept: !s.isFloated
            case .mood(let m): s.mood == m
            }
        }
        .filter { trimmed.isEmpty || $0.title.localizedCaseInsensitiveContains(trimmed) || $0.body.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("기록").textStyle(.h1).foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(filter == .kept
                         ? "분석 없이 조용히 간직한 별 \(model.stars.filter { !$0.isFloated }.count)개"
                         : "지금까지 띄우고 품은 별 \(model.stars.count)개")
                        .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    LinkChip(title: "밝기 흐름 보기 ›", action: onBrightness)
                }

                segment

                if mode == .list {
                    searchBar
                    chips
                    listContent
                } else {
                    calendar
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Segment

    private var segment: some View {
        HStack(spacing: Space.xs) {
            seg("목록", .list)
            seg("달력", .calendar)
        }
        .padding(Space.xs)
        .cosmos("records-seg", in: RoundedRectangle(cornerRadius: Radius.md))
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Color.borderDefault, lineWidth: 1))
    }

    private func seg(_ title: String, _ m: Mode) -> some View {
        let on = mode == m
        return Button { withAnimation(.snappy) { mode = m; searching = false } } label: {
            Text(title)
                .textStyle(.labelM)
                .foregroundStyle(on ? Color.textPrimary : Color.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background {
                    if on {
                        RoundedRectangle(cornerRadius: Radius.sm).fill(Color.tintPrimary)
                            .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(Color.hex(0x8555EF), lineWidth: 1))
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: List (115, 117, 118, 119)

    private var searchBar: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(searching || !query.isEmpty ? Color.textPrimary : Color.textTertiary)
            TextField("", text: $query, prompt: Text("제목이나 내용으로 찾기").foregroundStyle(Color.textTertiary))
                .textInputStyle(.bodyM)
                .foregroundStyle(Color.textPrimary)
                .focused($searching)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32).contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.leading, 14).padding(.trailing, Space.md)
        .frame(height: 44)
        .cosmos("records-search", in: RoundedRectangle(cornerRadius: Radius.md))
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md)
            .strokeBorder(searching || !query.isEmpty ? Color.hex(0x8555EF) : Color.borderDefault, lineWidth: 1))
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.sm) {
                plainChip("전체", .all)
                plainChip("띄운 별", .floated)
                plainChip("간직한 별", .kept)
                ForEach(Mood.allCases) { m in
                    DotChip(title: m.label, isSelected: filter == .mood(m), dot: m.color) {
                        withAnimation(.snappy) { filter = filter == .mood(m) ? .all : .mood(m) }
                    }
                }
            }
            .padding(.horizontal, Space.xl)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Space.xl)
    }

    private func plainChip(_ title: String, _ f: RecordsFilter) -> some View {
        let on = filter == f
        return Button { withAnimation(.snappy) { filter = f } } label: {
            Text(title)
                .textStyle(.labelS)
                .foregroundStyle(on ? Color.textPrimary : Color.textSecondary)
                .padding(.horizontal, Space.md).padding(.vertical, Space.sm)
                .cosmos("rchip-\(title)", in: Capsule(), intensity: 0.6)
                .background(on ? Color.tintPrimary : Color.bgSurface, in: .capsule)
                .overlay(Capsule().strokeBorder(on ? Color.hex(0x8555EF) : Color.borderDefault, lineWidth: 1))
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder private var listContent: some View {
        let stars = filtered
        if !trimmed.isEmpty {
            // 117 Search results
            HStack {
                Text("‘\(trimmed)’이 담긴 별 \(stars.count)개").textStyle(.labelM).foregroundStyle(Color.textPrimary)
                Spacer()
                Text("제목 · 본문").textStyle(.caption).foregroundStyle(Color.textTertiary)
            }
            if stars.isEmpty {
                empty(title: "‘\(trimmed)’이 담긴 별이 없어요", message: "다른 말로 찾아보거나, 필터를 바꿔 보세요.", action: nil)
            } else {
                rows(stars)
            }
        } else if stars.isEmpty {
            if filter == .kept {
                // 119
                empty(title: "아직 간직한 별이 없어요", message: "분석 없이 조용히 두고 싶은 글은\n여기에 모여요.",
                      action: ("간직할 글 쓰기", onCompose))
            } else {
                empty(title: "아직 별이 없어요", message: "오늘의 마음을 적으면\n이곳에 하나씩 모여요.", action: ("오늘의 별 만들기", onCompose))
            }
        } else {
            // 115: grouped by month, newest first
            ForEach(Self.byMonth(stars), id: \.0) { month, items in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(Self.monthTitle(month)).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text("별 \(items.count)개").textStyle(.caption).foregroundStyle(Color.textTertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    rows(items)
                }
            }
        }
    }

    private func rows(_ stars: [StarItem]) -> some View {
        LazyVStack(spacing: Space.md) {
            ForEach(stars) { star in
                Button { onOpenStar(star) } label: { StarRow(star: star) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func empty(title: String, message: String, action: (String, () -> Void)?) -> some View {
        VStack(spacing: Space.md) {
            StarGlyph(floated: true)
                .scaleEffect(40 / 18.14)
                .frame(width: 40, height: 40)
                .opacity(0.55)
                .padding(.bottom, Space.sm)
            Text(title).textStyle(.h3).foregroundStyle(Color.textPrimary)
            Text(message).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
            if let action {
                Button(action.0, action: action.1)
                    .buttonStyle(.primary)
                    .fixedSize()
                    .padding(.top, Space.sm)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    // MARK: Calendar (116)

    @ViewBuilder private var calendar: some View {
        let cal = Self.cal
        let days = Self.days(in: month)
        let byDay = Dictionary(grouping: model.stars) { cal.startOfDay(for: $0.date ?? .now) }
        VStack(spacing: Space.sm) {
            HStack {
                Button { shift(-1) } label: { navIcon(.iconBack) }.buttonStyle(.plain).accessibilityLabel("이전 달")
                Spacer()
                Text(Self.monthTitle(month)).textStyle(.h3).foregroundStyle(Color.textPrimary)
                Spacer()
                Button { shift(1) } label: { navIcon(.iconChevronRight) }.buttonStyle(.plain).accessibilityLabel("다음 달")
            }
            .frame(height: 28)
            HStack(spacing: 0) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) {
                    Text($0).textStyle(.caption).foregroundStyle(Color.textTertiary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(days.indices, id: \.self) { i in
                    if let d = days[i] {
                        let has = byDay[d] != nil
                        let on = day.map { cal.isDate($0, inSameDayAs: d) } ?? false
                        let future = d > .now
                        Button { withAnimation(.snappy) { day = d } } label: {
                            VStack(spacing: 4) {
                                Text("\(cal.component(.day, from: d))")
                                    .textStyle(.bodyS)
                                    .foregroundStyle(has || on ? Color.textPrimary : future ? Color.textTertiary : Color.textSecondary)
                                if has {
                                    StarGlyph(floated: byDay[d]!.contains(where: \.isFloated)).scaleEffect(14 / 18.14).frame(width: 14, height: 14)
                                } else {
                                    Color.clear.frame(width: 14, height: 14)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background {
                                if on {
                                    RoundedRectangle(cornerRadius: Radius.md).fill(Color.tintPrimary)
                                        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Color.hex(0x8555EF), lineWidth: 1))
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(cal.component(.month, from: d))월 \(cal.component(.day, from: d))일\(has ? ", 별 \(byDay[d]!.count)개" : "")")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    } else {
                        Color.clear.frame(minHeight: 48)
                    }
                }
            }
        }

        if let day {
            let items = byDay[cal.startOfDay(for: day)] ?? []
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(Self.dayTitle(day)).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("별 \(items.count)개").textStyle(.caption).foregroundStyle(Color.textTertiary)
                }
                if items.isEmpty {
                    Text("이날은 쉬어 간 밤이에요.").textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                } else {
                    rows(items)
                }
            }
        }
    }

    private func navIcon(_ image: ImageResource) -> some View {
        Image(image).renderingMode(.template).resizable().frame(width: 24, height: 24)
            .foregroundStyle(Color.textPrimary).frame(width: 40, height: 28).contentShape(.rect)
    }

    private func shift(_ n: Int) {
        withAnimation(.snappy) {
            month = Self.cal.date(byAdding: .month, value: n, to: month)!
            day = nil
        }
    }

    // MARK: Dates

    private static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ko_KR")
        return c
    }

    private static func byMonth(_ stars: [StarItem]) -> [(Date, [StarItem])] {
        let g = Dictionary(grouping: stars) { cal.dateInterval(of: .month, for: $0.date ?? .now)!.start }
        return g.map { ($0.key, $0.value.sorted { ($0.date ?? .now) > ($1.date ?? .now) }) }.sorted { $0.0 > $1.0 }
    }

    /// Sunday-first grid; nil for blanks before the 1st.
    private static func days(in month: Date) -> [Date?] {
        let first = cal.component(.weekday, from: month) - 1
        let count = cal.range(of: .day, in: .month, for: month)!.count
        return Array(repeating: nil, count: first) + (0..<count).map { cal.date(byAdding: .day, value: $0, to: month) }
    }

    private static func monthTitle(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월"
        return f.string(from: d)
    }

    private static func dayTitle(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월 d일 EEEE"
        return f.string(from: d)
    }
}

/// Figma record `Item`: focus border, raised gradient, Cosmos BG, spinning glyph.
struct RecordCard: View {
    var star: StarItem
    var subtitle: String

    var body: some View {
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
        .itemCard(seed: star.id.uuidString)
        .accessibilityElement(children: .combine)
    }
}

/// 17 `Hero`: the twinkling constellation (342×130).
struct RecordsHero: View {
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
        .fitCanvas(width: 342, height: 130)
        .accessibilityHidden(true)
    }
}

/// 18 Kept (조용히 간직한 마음): stars kept without analysis.
struct KeptView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void

    private var kept: [StarItem] { model.stars.filter { !$0.isFloated } }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "조용히 간직한 마음", onBack: onBack)

            VStack(alignment: .leading, spacing: Space.lg) {
                Text("분석 없이 간직한 글이에요. 언제든 별로 띄울 수 있어요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)

                KeptHero()

                if kept.isEmpty {
                    Text("아직 조용히 간직한 마음이 없어요.")
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
struct KeptHero: View {
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
        .fitCanvas(width: 342, height: 150)
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
                Text("고른 한 문장만 익명으로 올라가고, 글 전체는 나가지 않아요. 다른 사람은 '공명'만 남길 수 있고, 언제든 거둘 수 있어요.")
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
