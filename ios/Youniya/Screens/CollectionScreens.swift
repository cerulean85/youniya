import SwiftUI

/// 79 컬렉션 · 별 / 80 컬렉션 · 성운: everything the user made or kept close.
struct CollectionView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void
    /// 75: someone's star I resonated with (nebula name, star title).
    var onOpenOtherStar: (String, String) -> Void
    var onOpenMyNebula: () -> Void
    var onOpenOtherNebula: (GalaxyNebula) -> Void
    var onDraw: () -> Void
    /// 97 "우주 광장 둘러보기"
    var onPlaza: () -> Void = {}

    private enum Segment: String, CaseIterable { case star = "별", nebula = "성운" }
    private enum Filter { case all, mine, kept }

    @State private var segment: Segment = .star
    @State private var filter: Filter = .all

    /// A tile in 79: my floated star, or someone's star I kept close.
    private enum Tile: Identifiable {
        case mine(StarItem)
        case kept(nebula: GalaxyNebula, title: String, spec: StarShapeSpec, color: Color)

        var id: String {
            switch self {
            case .mine(let s): s.id.uuidString
            case .kept(let n, let t, _, _): "\(n.name)/\(t)"
            }
        }
    }

    private var myStars: [Tile] {
        model.stars.filter(\.isFloated).map { Tile.mine($0) }
    }

    private var keptStars: [Tile] {
        GalaxyNebula.samples.flatMap { n in
            n.stars.compactMap { s in
                model.resonated.contains("star:\(n.name):\(s.title)") ? Tile.kept(nebula: n, title: s.title, spec: s.spec, color: s.color) : nil
            }
        }
    }

    private var keptNebulae: [GalaxyNebula] {
        GalaxyNebula.samples.filter { model.resonated.contains(PlazaNebulaField.key($0)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "컬렉션", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("컬렉션").textStyle(.h1).foregroundStyle(Color.textPrimary)
                        Text(segment == .star
                             ? "쓴 마음이 별이 되어 모여요. 같은 모양의 별은 하나도 없어요."
                             : "별들이 이어져 성운이 돼요. 이름은 직접 지어 줄 수 있어요.")
                            .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    segmentControl

                    if segment == .star { starsTab } else { nebulaTab }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }

    // MARK: 79

    @ViewBuilder private var starsTab: some View {
        let mine = myStars, kept = keptStars
        filters(all: mine.count + kept.count, mine: ("내가 띄운", mine.count), kept: kept.count)
        let tiles = filter == .mine ? mine : filter == .kept ? kept : mine + kept
        if tiles.isEmpty {
            if filter == .kept {
                // 97
                EmptyStateView(title: "곁에 둔 별이 아직 없어요",
                               message: "우주 광장에서 마음이 닿은 별을 곁에 두면\n여기에 모여요.",
                               action: ("우주 광장 둘러보기", .outline, onPlaza))
                    .padding(.top, 72)
            } else {
                EmptyStateView(title: "아직 띄운 별이 없어요", message: "별을 띄우면 이곳에 모여요.")
                    .padding(.top, 72)
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.md), count: 3), spacing: Space.md) {
                ForEach(tiles) { tile in starTile(tile) }
            }
        }
    }

    private func starTile(_ tile: Tile) -> some View {
        let (spec, color, date, kept, label): (StarShapeSpec, Color, String, Bool, String) = {
            switch tile {
            case .mine(let s): (StarShapeSpec(star: s), s.mood.color, Self.short(s.date), false, s.title)
            case .kept(_, let t, let sp, let c): (sp, c, "", true, t)
            }
        }()
        var rng = SeededRandom(seed: tile.id)
        let size = rng.next(in: 40...54)
        return Button {
            switch tile {
            case .mine(let s): onOpenStar(s)
            case .kept(let n, let t, _, _): onOpenOtherStar(n.name, t)
            }
        } label: {
            VStack(spacing: Space.xs) {
                ShapeStar(spec: spec, color: color, size: size, rays: size > 50)
                    .rotationEffect(.degrees(rng.next(in: 0...40)))
                    .frame(width: 70, height: 70)
                Text(kept ? (date.isEmpty ? "곁에 둔" : "\(date) · 곁에 둔") : date)
                    .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Space.md)
            .padding(.bottom, Space.sm)
            .itemCard(seed: "tile-\(tile.id)", minHeight: 0, flatBorder: true)
            // Figma 79: kept stars get a violet border.
            .overlay { if kept { RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.hex(0x8555EF), lineWidth: 1) } }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kept ? "곁에 둔 별, \(label)" : "\(label), \(date)")
    }

    // MARK: 80

    @ViewBuilder private var nebulaTab: some View {
        let drawn = model.drawnNebulae
        let kept = keptNebulae
        // My nebula is always there, drawn or not.
        let mineCount = drawn.count
        filters(all: mineCount + kept.count, mine: ("내가 그린", mineCount), kept: kept.count)
        let showsEmpty = (filter == .mine && drawn.isEmpty) || (filter == .all && drawn.isEmpty && kept.isEmpty)
        if showsEmpty {
            // 96
            EmptyStateView(title: "아직 그린 성운이 없어요",
                           message: "별이 3개 이상 모이면 이어서\n나만의 성운을 그릴 수 있어요.")
                .padding(.top, 72)
        }
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.md), GridItem(.flexible(), spacing: Space.md)], spacing: Space.md) {
            if filter != .kept {
                if drawn.isEmpty {
                    EmptyView()
                } else {
                    ForEach(drawn.reversed()) { n in
                        nebulaCard(name: n.name, detail: "별 \(n.starIDs.count + n.guests.count)개 · \(model.growthStage)단계",
                                   seed: n.id.uuidString, action: onOpenMyNebula)
                    }
                }
            }
            if filter != .mine {
                ForEach(kept) { n in
                    nebulaCard(name: n.name, detail: "곁에 둔 · \(n.stage)단계", seed: n.name, kept: true) { onOpenOtherNebula(n) }
                }
            }
        }
        if filter == .kept && kept.isEmpty {
            empty("광장에서 공명한 성운이 이곳에 곁에 남아요.")
        }
        Button(action: onDraw) {
            Text("＋  새 성운 그리기")
                .textStyle(.labelM).foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(Space.lg)
                .cosmos("new-nebula", in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(Color.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func nebulaCard(name: String, detail: String, seed: String, kept: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.xs) {
                MiniShapeNebula(seed: seed).frame(height: 100)
                Text(name).textStyle(.labelM).foregroundStyle(Color.textPrimary).lineLimit(1)
                Text(detail).textStyle(.caption).foregroundStyle(Color.textTertiary).lineLimit(1)
            }
            .padding(Space.md)
            .itemCard(seed: "neb-\(seed)", minHeight: 0, flatBorder: true)
            .overlay { if kept { RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.hex(0x8555EF), lineWidth: 1) } }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    // MARK: Shared

    private func filters(all: Int, mine: (String, Int), kept: Int) -> some View {
        HStack(spacing: Space.sm) {
            DotChip(title: "전체 \(all)", isSelected: filter == .all) { withAnimation(.snappy) { filter = .all } }
            DotChip(title: "\(mine.0) \(mine.1)", isSelected: filter == .mine) { withAnimation(.snappy) { filter = .mine } }
            DotChip(title: "곁에 둔 \(kept)", isSelected: filter == .kept) { withAnimation(.snappy) { filter = .kept } }
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.xxl)
    }

    /// Figma `Segment` (09 style): pill track, the selected half filled violet.
    private var segmentControl: some View {
        HStack(spacing: Space.xs) {
            ForEach(Segment.allCases, id: \.self) { s in
                let on = segment == s
                Button { withAnimation(.snappy) { segment = s; filter = .all } } label: {
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
        .cosmos("collection-segment", in: Capsule())
        .background(Color.bgSurfaceRaised, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 1))
    }

    private static func short(_ d: Date?) -> String {
        guard let d else { return "" }
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: d)
    }
}

/// Figma 80 `Mini Nebula`: a few star shapes joined by a thin line.
private struct MiniShapeNebula: View {
    var seed: String

    var body: some View {
        GeometryReader { geo in
            var rng = SeededRandom(seed: seed)
            let colors: [Color] = [.starBright, .brandPrimary, .brandWarm, .starClear, .emotionCalm, .emotionSorrow]
            let pts: [CGPoint] = (0..<6).map { _ in
                CGPoint(x: rng.next(in: 0.1...0.9) * geo.size.width, y: rng.next(in: 0.12...0.88) * geo.size.height)
            }
            let sizes = (0..<6).map { _ in rng.next(in: 9...17) }
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: pts[0])
                    for q in pts.dropFirst() { p.addLine(to: q) }
                }
                .stroke(Color.textSecondary.opacity(0.7), lineWidth: 1)
                ForEach(0..<6, id: \.self) { i in
                    ShapeStar(spec: .init(points: 4 + i % 3, sharpness: .normal), color: colors[i], size: sizes[i], halo: false)
                        .position(pts[i])
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let model = AppModel()
    model.fillSampleStars()
    return CollectionView(onBack: {}, onOpenStar: { _ in }, onOpenOtherStar: { _, _ in },
                          onOpenMyNebula: {}, onOpenOtherNebula: { _ in }, onDraw: {}).environment(model)
}
