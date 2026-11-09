import SwiftUI

/// 12-7 / 12-8 이을 별 고르기 (453:14363, 455:15104): pick stars already
/// written, many at once, from a searchable, filterable list grouped by month,
/// or from a calendar. The circle on the right picks at once; the row opens
/// 12-9 (the whole star) with 「이 별 고르기」.
struct LinkStarsView: View {
    @Environment(AppModel.self) private var model
    var starID: StarItem.ID
    var onBack: () -> Void
    var onLinked: (Int) -> Void

    private enum Filter: Equatable { case all, lit, unlit, mood(Mood) }

    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var picked: Set<StarItem.ID> = []
    @State private var preview: StarItem?
    @State private var previewHeight: CGFloat = 520
    @State private var saving = false
    /// 12-8
    @State private var byCalendar = DebugScreen.is("12-8")
    @State private var calMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var calDay: Date?

    private var star: StarItem? { model.stars.first { $0.id == starID } }
    private var alreadyLinked: Set<UUID> { Set(star?.linkedIDs ?? []) }

    private var candidates: [StarItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return model.stars.filter { s in
            guard s.id != starID, !alreadyLinked.contains(s.id) else { return false }
            switch filter {
            case .all: break
            case .lit: if !s.isFloated { return false }
            case .unlit: if s.isFloated { return false }
            case .mood(let m): if s.mood != m && !(s.extraMoods ?? []).contains(m) { return false }
            }
            return q.isEmpty || s.title.localizedCaseInsensitiveContains(q) || s.body.localizedCaseInsensitiveContains(q)
        }
        .sorted { ($0.date ?? .now) > ($1.date ?? .now) }
    }

    /// "2026년 11월" groups, newest first.
    private var groups: [(String, [StarItem])] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        var order: [String] = []
        var by: [String: [StarItem]] = [:]
        for s in candidates {
            let k = f.string(from: s.date ?? .now)
            if by[k] == nil { order.append(k) }
            by[k, default: []].append(s)
        }
        return order.map { ($0, by[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("이을 별 고르기").textStyle(.h1).foregroundStyle(Color.textPrimary)
                        Text("「\(star?.title ?? "")」와 이을 별을 골라 주세요. 여러 개를 고를 수 있어요.")
                            .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("별을 누르면 내용을 볼 수 있어요 · 오른쪽 원을 누르면 바로 골라져요")
                            .textStyle(.caption).foregroundStyle(Color.brandPrimaryText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    segment

                    if byCalendar {
                        calendar
                    } else {
                        search
                        chips
                        list
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottom) { linkButton }
        .animation(.snappy, value: picked.isEmpty)
        .background { StarField() }
        // 12-9 별 내용 미리 보기
        .sheet(item: $preview) { s in
            previewSheet(s)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { previewHeight = $0 }
                .presentationDetents([.height(min(previewHeight, 640))])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.xl)
                .presentationBackground { SheetBackground(seed: "link-preview") }
        }
    }

    @ViewBuilder private var list: some View {
                    if candidates.isEmpty {
                        Text(query.isEmpty ? "이을 수 있는 별이 아직 없어요." : "‘\(query)’이 담긴 별이 없어요.")
                            .textStyle(.bodyM).foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                    ForEach(groups, id: \.0) { month, stars in
                        HStack {
                            Text(month).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("별 \(stars.count)개").textStyle(.caption).foregroundStyle(Color.textTertiary)
                        }
                        ForEach(stars) { row($0) }
                    }
    }

    @ViewBuilder private var linkButton: some View {
        if !picked.isEmpty {
            Button("\(picked.count)개 별 잇기", action: link)
                .buttonStyle(.primary)
                .disabled(saving)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Figma `Segment`: 목록 | 달력.
    private var segment: some View {
        HStack(spacing: Space.xs) {
            ForEach([false, true], id: \.self) { cal in
                let on = byCalendar == cal
                Button { withAnimation(.snappy) { byCalendar = cal } } label: {
                    Text(cal ? "달력" : "목록")
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
        .background(Color.bgSurfaceRaised, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 1))
    }

    // MARK: 12-8 달력

    private var cal: Calendar { Calendar.current }

    private func stars(on day: Date) -> [StarItem] {
        candidates.filter { $0.date.map { cal.isDate($0, inSameDayAs: day) } ?? false }
    }

    @ViewBuilder private var calendar: some View {
        let f = DateFormatter()
        let _ = { f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월" }()
        VStack(spacing: Space.md) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("지난달")
                Spacer()
                Text(f.string(from: calMonth)).textStyle(.h3).foregroundStyle(Color.textPrimary)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("다음 달")
                    .disabled(calMonth >= (cal.dateInterval(of: .month, for: .now)?.start ?? .now))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.textSecondary)

            let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: cols, spacing: Space.sm) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) {
                    Text($0).textStyle(.caption).foregroundStyle(Color.textTertiary)
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 40) }
                }
            }
        }

        if let day = calDay {
            let list = stars(on: day)
            let df = DateFormatter()
            let _ = { df.locale = Locale(identifier: "ko_KR"); df.dateFormat = "M월 d일 EEEE" }()
            HStack {
                Text(df.string(from: day)).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                Spacer()
                Text("별 \(list.count)개").textStyle(.caption).foregroundStyle(Color.textTertiary)
            }
            ForEach(list) { row($0) }
        }
    }

    /// The month's days, with blanks before the 1st.
    private var monthCells: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: calMonth) else { return [] }
        let lead = cal.component(.weekday, from: calMonth) - 1
        return Array(repeating: nil, count: lead) + range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: calMonth) }
    }

    private func dayCell(_ day: Date) -> some View {
        let list = stars(on: day)
        let hasPicked = list.contains { picked.contains($0.id) }
        let isOn = calDay.map { cal.isDate($0, inSameDayAs: day) } ?? false
        return Button { if !list.isEmpty { withAnimation(.snappy) { calDay = day } } } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: day))")
                    .textStyle(.bodyM)
                    .foregroundStyle(list.isEmpty ? Color.textTertiary : Color.textPrimary)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(hasPicked ? Color.brandPrimary : .clear, lineWidth: 1.2))
                Image(systemName: "sparkle")
                    .font(.system(size: 9))
                    .foregroundStyle(list.isEmpty ? .clear : (list.contains(where: \.isFloated) ? Color.brandPrimaryText : Color.textSecondary))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isOn ? Color.tintPrimary : .clear, in: .rect(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(isOn ? Color.brandPrimary : .clear, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(list.isEmpty)
        .accessibilityLabel("\(cal.component(.day, from: day))일, 별 \(list.count)개")
    }

    private func shiftMonth(_ by: Int) {
        guard let next = cal.date(byAdding: .month, value: by, to: calMonth) else { return }
        withAnimation(.snappy) { calMonth = next; calDay = nil }
    }

    private var search: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.textTertiary)
            TextField("", text: $query, prompt: Text("제목이나 내용으로 찾기").foregroundStyle(Color.textTertiary))
                .textStyle(.bodyM).foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Color.borderDefault, lineWidth: 1))
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.sm) {
                DotChip(title: "전체", isSelected: filter == .all) { filter = .all }
                DotChip(title: "띄운 별", isSelected: filter == .lit) { filter = .lit }
                DotChip(title: "별빛 없는 별", isSelected: filter == .unlit) { filter = .unlit }
                ForEach(Mood.allCases) { m in
                    DotChip(title: m.label, isSelected: filter == .mood(m), dot: m.color) {
                        filter = filter == .mood(m) ? .all : .mood(m)
                    }
                }
            }
            .padding(.horizontal, Space.xl)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Space.xl)
    }

    private func row(_ s: StarItem) -> some View {
        let on = picked.contains(s.id)
        return ZStack(alignment: .topTrailing) {
            Button { preview = s } label: {
                StarRow(star: s)
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(on ? Color.brandPrimary : .clear, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            Button { toggle(s.id) } label: {
                ZStack {
                    Circle().fill(on ? Color.brandPrimary : Color.bgSurface)
                    Circle().strokeBorder(on ? Color.brandPrimary : Color.borderDefault, lineWidth: 1.2)
                    if on { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white) }
                }
                .frame(width: 22, height: 22)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .offset(x: 8, y: -12)
            .accessibilityLabel(on ? "\(s.title) 고름" : "\(s.title) 고르기")
            .accessibilityAddTraits(on ? .isSelected : [])
        }
    }

    private func previewSheet(_ s: StarItem) -> some View {
        let linked = model.linkedStars(s.id)
        return VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text(s.longDateText + (s.isFloated ? "" : " · 별빛 없는 별"))
                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    Text(s.title).textStyle(.h2).foregroundStyle(Color.textPrimary)
                    Text(s.body).textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !linked.isEmpty {
                        Text("이미 이어진 별 \(linked.count) · " + linked.map { "「\($0.title)」" }.joined(separator: " "))
                            .textStyle(.caption).foregroundStyle(Color.starBright)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 380)
            VStack(spacing: Space.md) {
                Button(picked.contains(s.id) ? "고르지 않기" : "이 별 고르기") {
                    toggle(s.id)
                    preview = nil
                }
                .buttonStyle(.primary)
                Button("닫기") { preview = nil }.buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }

    private func toggle(_ id: StarItem.ID) {
        withAnimation(.snappy(duration: 0.2)) {
            if picked.contains(id) { picked.remove(id) } else { picked.insert(id) }
        }
    }

    private func link() {
        saving = true
        Task { @MainActor in
            let ok = await model.linkStars(starID, Array(picked))
            saving = false
            if ok { onLinked(picked.count) }
        }
    }
}
