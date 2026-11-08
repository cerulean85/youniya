import SwiftUI

// MARK: - Model

/// A nebula the user drew (51–55). Saved on the device.
struct DrawnNebula: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// Silhouette raw value, or nil for 직접 그리기.
    var silhouette: String?
    var starIDs: [UUID]
    /// Index pairs into `starIDs` (직접 그리기 only).
    var edges: [[Int]] = []
    /// Titles of guest stars let into empty slots (85).
    var guests: [String] = []
    /// Live: the guests' plaza share ids.
    var guestShareIDs: [String] = []
    var shared = false
    var createdAt = Date.now
    /// Set when the shape was changed (08 shows the latest of updated/created).
    var updatedAt: Date? = nil
    /// Live: the server's nebula id, set once it is saved there.
    var serverID: String? = nil

    var lastTouched: Date { updatedAt ?? createdAt }
    var template: NebulaSilhouette? { silhouette.flatMap(NebulaSilhouette.init(rawValue:)) }
}

/// 84 silhouettes: Figma `Mini` outlines, drawn in their own box.
enum NebulaSilhouette: String, CaseIterable, Identifiable {
    case whale, lighthouse, tree, bird, flower
    /// v1.1 계절 팩 (84-1), members only. Raw values are the server's ids.
    case cherryBlossom = "cherry_blossom", wave, maple, snowflake

    var id: Self { self }

    static let basic: [NebulaSilhouette] = [.whale, .lighthouse, .tree, .bird, .flower]
    static let season: [NebulaSilhouette] = [.cherryBlossom, .wave, .maple, .snowflake]
    var isSeason: Bool { Self.season.contains(self) }

    var name: String {
        switch self {
        case .whale: "고래"
        case .lighthouse: "등대"
        case .tree: "나무"
        case .bird: "새"
        case .flower: "꽃"
        case .cherryBlossom: "벚꽃"
        case .wave: "파도"
        case .maple: "단풍"
        case .snowflake: "눈송이"
        }
    }

    /// Outline points in the Figma box, in drawing order.
    var outline: (points: [CGPoint], closed: Bool, box: CGSize) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        switch self {
        case .whale:
            return ([p(0, 13), p(10, 3), p(26, 0), p(42, 4), p(52, 13), p(40, 21), p(20, 22)], true, CGSize(width: 52, height: 22))
        case .lighthouse:
            return ([p(0, 176), p(80, 176), p(65, 36), p(40, 0), p(15, 36)], true, CGSize(width: 80, height: 176))
        case .tree:
            return ([p(14, 32), p(14, 20), p(0, 18), p(14, 0), p(28, 18), p(14, 20)], false, CGSize(width: 28, height: 32))
        case .bird:
            return ([p(0, 10), p(14, 0), p(26, 8), p(38, 0), p(52, 10)], false, CGSize(width: 52, height: 10))
        case .flower:
            return ([p(13.3, 0), p(26.6, 9.7), p(21.5, 25.3), p(5.1, 25.3), p(0, 9.7)], true, CGSize(width: 26.6, height: 25.3))
        // Figma 84-1 `Mini`. 벚꽃 and 눈송이 are spokes from the middle, drawn
        // middle → tip → middle so the stars line up along each one.
        case .cherryBlossom:
            let c = p(15.2, 15.2)
            return ([c, p(15.2, 0), c, p(30.4, 10.5), c, p(24.6, 27.5), c, p(5.8, 27.5), c, p(0, 10.5)],
                    false, CGSize(width: 30.4, height: 27.5))
        case .wave:
            return ([p(0, 18), p(10, 6), p(20, 14), p(30, 0), p(40, 12), p(52, 4)], false, CGSize(width: 52, height: 18))
        case .maple:
            return ([p(22, 0), p(30, 10), p(44, 8), p(36, 20), p(40, 32), p(22, 26), p(4, 32), p(8, 20), p(0, 8), p(14, 10)],
                    true, CGSize(width: 44, height: 32))
        case .snowflake:
            let c = p(17, 14.7)
            return ([c, p(34, 14.7), c, p(25.5, 29.4), c, p(8.5, 29.4), c, p(0, 14.7), c, p(8.5, 0), c, p(25.5, 0)],
                    false, CGSize(width: 34, height: 29.4))
        }
    }

    /// Places on the outline (Figma 등대: 12 stars + 6 empty).
    static let slotCount = 18

    /// The outline scaled into `rect`, keeping its proportions.
    func fitted(in rect: CGRect) -> [CGPoint] {
        let o = outline
        let s = min(rect.width / o.box.width, rect.height / o.box.height)
        let ox = rect.midX - o.box.width * s / 2, oy = rect.midY - o.box.height * s / 2
        return o.points.map { CGPoint(x: ox + $0.x * s, y: oy + $0.y * s) }
    }

    /// `count` points spread evenly along the outline.
    func slots(in rect: CGRect, count: Int = slotCount) -> [CGPoint] {
        var pts = fitted(in: rect)
        if outline.closed, let first = pts.first { pts.append(first) }
        let segs = zip(pts, pts.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        let total = segs.reduce(0, +)
        guard total > 0 else { return [] }
        let step = outline.closed ? total / CGFloat(count) : total / CGFloat(max(1, count - 1))
        return (0..<count).map { i in
            var d = CGFloat(i) * step
            for (k, len) in segs.enumerated() {
                if d <= len || k == segs.count - 1 {
                    let t = len > 0 ? min(1, d / len) : 0
                    let a = pts[k], b = pts[k + 1]
                    return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                }
                d -= len
            }
            return pts.last!
        }
    }

    func path(in rect: CGRect) -> Path {
        let pts = fitted(in: rect)
        return Path { p in
            guard let first = pts.first else { return }
            p.move(to: first)
            // Figma 나무: the trunk is its own stroke.
            for pt in pts.dropFirst() { p.addLine(to: pt) }
            if outline.closed { p.closeSubpath() }
        }
    }
}

/// A star from the plaza this user resonated with (85). Only color and source come along.
/// TODO: From the plaza API.
struct GuestStar: Identifiable, Hashable {
    var title: String
    var source: String
    var day: String
    var color: Color
    /// Live: the plaza share id sent as a guest (85).
    var shareID: String? = nil
    var id: String { shareID ?? title }

    static let candidates: [GuestStar] = [
        GuestStar(title: "고요한 새벽의 별", source: "비 온 뒤 고래자리", day: "11월 2일", color: .starClear),
        GuestStar(title: "비가 그친 오후", source: "이름 없는 성운", day: "10월 30일", color: .starClear),
        GuestStar(title: "오래 머문 별", source: "어느 밤의 성운", day: "10월 21일", color: .emotionSorrow),
        GuestStar(title: "말없이 건넨 별", source: "느린 강자리", day: "10월 15일", color: .emotionCalm),
    ]
    static let maxGuests = 5
}

// MARK: - Flow

/// 51–55, 84, 85 성운 그리기.
/// 51 시작 → 84 모양 고르기 → (틀) 85 손님별 → 54 이름 → 55 완성
///                         → (직접 그리기) 52 별 고르기 → 53 잇기 → 54 → 55
struct NebulaDrawingFlow: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void
    var onHome: () -> Void
    var onShare: () -> Void
    /// 08 「모양 바꾸기」: the nebula being reshaped. The flow starts at 84
    /// with its shape, stars, guests and name already chosen, then saves it
    /// in place (PATCH) and closes.
    var editing: DrawnNebula? = nil

    private enum Step: Hashable { case start, shape, guests, pick, connect, name, done }

    @State private var steps: [Step] = DebugScreen.is("84-1") ? [.start, .shape] : [.start]
    @State private var prefilled = false
    /// Reshape: new stars clear a polished story, so ask once first.
    @State private var confirmClearStory = false
    @State private var silhouette: NebulaSilhouette? = .lighthouse
    /// 84-1: M1 from a locked season silhouette.
    @State private var showMembership = false
    @State private var picked: [UUID] = []
    @State private var edges: [[Int]] = []
    @State private var guests: Set<GuestStar> = []
    @State private var name = ""
    @State private var saved: DrawnNebula?

    private var step: Step { steps.last ?? .start }

    /// Floated stars, oldest first ("띄운 순서대로").
    private var floated: [StarItem] {
        model.stars.filter(\.isFloated).sorted { ($0.date ?? .now) < ($1.date ?? .now) }
    }

    /// Stars that sit on the silhouette (the newest ones if there are too many).
    /// Reshaping: the stars picked again on 52, in their floated order.
    private var placed: [StarItem] {
        if editing != nil { return Array(floated.filter { picked.contains($0.id) }.suffix(NebulaSilhouette.slotCount)) }
        return Array(floated.suffix(NebulaSilhouette.slotCount))
    }
    /// The silhouette that will be saved: nil for 직접 그리기.
    private var chosenTemplate: NebulaSilhouette? {
        if editing != nil { return silhouette }
        return steps.contains(.pick) ? nil : silhouette
    }
    private var emptySlots: Int { max(0, NebulaSilhouette.slotCount - placed.count) }

    var body: some View {
        VStack(spacing: 0) {
            if step != .done {
                TopAppBar(title: editing == nil ? "성운 그리기" : "성운 모양 바꾸기", onBack: back)
            }
            ZStack {
                switch step {
                case .start: startView
                case .shape: shapeView
                case .guests: guestsView
                case .pick: pickView
                case .connect: connectView
                case .name: nameView
                case .done: doneView
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: step)
        }
        .background { StarField() }
        .membershipSheet(isPresented: $showMembership)
        .onAppear {
            // 84 (reshape): the current choices, already selected.
            guard let e = editing, !prefilled else { return }
            prefilled = true
            steps = [.shape]
            silhouette = e.template
            picked = e.starIDs
            edges = e.edges
            name = e.name
        }
        .task {
            await model.loadGuestCandidates()
            if let e = editing { guests = Set(model.guestCandidates.filter { e.guests.contains($0.title) }) }
        }
        .edgeSwipeBack(enabled: step != .done, onBack: back)
    }

    private func go(_ s: Step) { withAnimation(.easeInOut(duration: 0.3)) { steps.append(s) } }

    private func back() {
        if steps.count > 1 {
            withAnimation(.easeInOut(duration: 0.3)) { _ = steps.popLast() }
        } else {
            onClose()
        }
    }

    // MARK: 51

    private var startView: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header("별들을 이어\n성운을 그려볼까요?", "지금까지 띄운 별 중에서 마음에 닿는 별을 골라 이어 보세요. 정답은 없어요.", h1: true)
            StarStage(stars: floated, picked: [], edges: [], interactive: false)
                .frame(maxHeight: .infinity)
            actions {
                Button("시작하기") { go(.shape) }.buttonStyle(.primary)
                    .disabled(floated.isEmpty)
                Button(floated.isEmpty ? "별을 먼저 띄워 주세요" : "나중에", action: onClose).buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl).padding(.top, Space.xl).padding(.bottom, Space.xl)
    }

    // MARK: 84

    private var shapeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let e = editing {
                header("모양을 바꿀까요?",
                       "지금은 \(e.template?.name ?? "직접 그린") 모양이에요. 다른 틀을 고르거나 별을 다시 골라 이을 수 있어요.")
            } else {
                header("어떤 모양으로 모일까요?", "틀을 고르면 별들이 띄운 순서대로 자리를 잡아요.")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.md), count: 3), spacing: Space.md) {
                ForEach(NebulaSilhouette.basic) { s in
                    tile(s.name, selected: silhouette == s) { SilhouetteMini(silhouette: s, selected: silhouette == s) }
                        .onTapGesture { withAnimation(.snappy) { silhouette = s } }
                }
                tile("직접 그리기", selected: silhouette == nil) {
                    Image(.iconPencil).renderingMode(.template).resizable()
                        .frame(width: 24, height: 24).foregroundStyle(Color.textPrimary)
                }
                .onTapGesture { withAnimation(.snappy) { silhouette = nil } }
            }

            // 84-1 (v1.1): the season pack, locked for non-members (→ M1).
            if model.membershipOn {
                Text("계절 팩 · 별지기 멤버십").textStyle(.labelM).foregroundStyle(Color.starBright)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.md), count: 3), spacing: Space.md) {
                    ForEach(NebulaSilhouette.season) { s in
                        tile(s.name, selected: silhouette == s) {
                            SilhouetteMini(silhouette: s, selected: silhouette == s, gold: true)
                        }
                        .overlay(alignment: .topTrailing) {
                            if !model.isMember {
                                Image(.iconLock).resizable().frame(width: 16, height: 16).padding(Space.sm)
                                    .accessibilityLabel("멤버십")
                            }
                        }
                        .onTapGesture {
                            if model.isMember { withAnimation(.snappy) { silhouette = s } } else { showMembership = true }
                        }
                    }
                }
            }

            // 84-1 has no room for the preview: the pack takes its place.
            if !model.membershipOn {
            Group {
                if let silhouette {
                    SilhouettePreview(silhouette: silhouette, stars: placed, guests: [])
                        .overlay(alignment: .topLeading) {
                            Text(silhouette.name).textStyle(.labelS).foregroundStyle(Color.textSecondary).padding(Space.lg)
                        }
                } else {
                    StarStage(stars: floated, picked: [], edges: [], interactive: false)
                        .overlay {
                            Text("마음에 닿는 별을 직접 골라 이어요")
                                .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                        }
                }
            }
            // Figma `Preview`: 236pt
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 236)
            .cosmos("shape-preview", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))

            }

            if silhouette != nil && !model.membershipOn {
                HStack(spacing: Space.lg) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.hex(0x8555EF)).frame(width: 7, height: 7)
                        Text("내 별 \(placed.count)")
                    }
                    HStack(spacing: 6) {
                        Circle().strokeBorder(Color.textTertiary, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: 8, height: 8)
                        Text("빈 자리 \(emptySlots) · 다음 별을 기다려요")
                    }
                }
                .textStyle(.caption)
                .foregroundStyle(Color.textSecondary)
                .accessibilityElement(children: .combine)
            }

            if editing != nil {
                Text("우주 광장에 띄운 성운이면, 광장에서도 새 모양으로 바뀌어요.\n별을 바꾸면 다듬은 성운 이야기는 지워지고, 문장만 엮은 이야기로 돌아가요.")
                    .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            actions {
                if editing != nil {
                    Button("다음 · 별 다시 고르기") { go(.pick) }
                        .buttonStyle(.primary)
                } else {
                    Button(silhouette == nil ? "직접 그리기" : "이 모양으로 그리기") {
                        if silhouette == nil { go(.pick) } else if emptySlots > 0 { go(.guests) } else { go(.name) }
                    }
                    .buttonStyle(.primary)
                }
            }
        }
        .padding(Space.xl)
    }

    private func tile<Icon: View>(_ title: String, selected: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: Space.sm) {
            icon().frame(width: 60, height: 40)
            Text(title)
                .textStyle(.labelS)
                .foregroundStyle(selected ? Color.textPrimary : Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14).padding(.bottom, Space.md)
        .cosmos("tile-\(title)", in: RoundedRectangle(cornerRadius: 14))
        .background(selected ? Color.tintPrimary : Color.bgSurface, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(selected ? Color.hex(0x8555EF) : Color.borderDefault, lineWidth: selected ? 1.5 : 1))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: 85

    private var guestsView: some View {
        let limit = min(GuestStar.maxGuests, emptySlots)
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    header("손님별을 초대할까요?", "광장에서 마음에 닿았던 별을 빈 자리에 들일 수 있어요. 원문 없이 빛깔과 출처만 함께 와요.")
                    HStack {
                        Text("빈 자리 \(emptySlots)")
                            .textStyle(.labelM).foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("손님별 \(guests.count) / \(GuestStar.maxGuests)")
                            .textStyle(.labelS).foregroundStyle(Color.brandPrimaryText)
                            .padding(.horizontal, Space.md).padding(.vertical, Space.xs)
                            .background(Color.tintPrimary, in: .capsule)
                    }
                    if let silhouette {
                        SilhouettePreview(silhouette: silhouette, stars: placed,
                                          guests: model.guestCandidates.filter(guests.contains))
                            .frame(height: 140)
                            .cosmos("guest-preview", in: RoundedRectangle(cornerRadius: Radius.lg))
                            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(model.guestCandidates.enumerated()), id: \.element.id) { i, g in
                            guestRow(g, last: i == model.guestCandidates.count - 1, limit: limit)
                        }
                    }
                    .padding(.horizontal, Space.lg).padding(.vertical, Space.xs)
                    .itemCard(seed: "guests", minHeight: 0)
                    Text("손님별은 최대 5개까지 들일 수 있고, 들인 뒤에도 빛깔과 출처는 그대로 지켜져요.")
                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Space.xl).padding(.top, Space.xl).padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)
            Button(guests.isEmpty ? "손님별 없이 이어 가기" : "빈 자리에 들이기 · \(guests.count)개") { go(.name) }
                .buttonStyle(.primary)
                .padding(.horizontal, Space.xl).padding(.bottom, Space.xl)
        }
    }

    private func guestRow(_ g: GuestStar, last: Bool, limit: Int) -> some View {
        let on = guests.contains(g)
        return Button {
            withAnimation(.snappy) {
                if on { guests.remove(g) } else if guests.count < limit { guests.insert(g) }
            }
        } label: {
            HStack(spacing: Space.md) {
                StarGlyph(floated: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.title).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    Text("\(g.source) · \(g.day)에 공명").textStyle(.caption).foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    if on {
                        Circle().fill(Color.hex(0x8555EF))
                        Image(.iconCheck).resizable().frame(width: 14, height: 14)
                    } else {
                        Circle().strokeBorder(Color.borderDefault, lineWidth: 1.5)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.vertical, Space.md)
            .overlay(alignment: .bottom) {
                if !last { Color.borderDefault.opacity(0.6).frame(height: 1) }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: 52

    private var pickView: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header("별을 골라 주세요", picked.isEmpty ? "몇 개를 골라도 괜찮아요" : "\(picked.count)개 골랐어요 · 몇 개를 골라도 괜찮아요")
            StarStage(stars: floated, picked: picked, edges: [], interactive: true) { star in
                withAnimation(.snappy) {
                    if let i = picked.firstIndex(of: star.id) { picked.remove(at: i) } else { picked.append(star.id) }
                }
            }
            .frame(height: 320)
            Spacer(minLength: 0)
            actions {
                if editing != nil, silhouette != nil {
                    // Reshape onto a silhouette: guests for the empty places, then the name.
                    Button("다음") { if emptySlots > 0 { go(.guests) } else { go(.name) } }
                        .buttonStyle(.primary)
                        .disabled(picked.isEmpty)
                } else {
                    Button("이어 보기") { edges = []; go(.connect) }
                        .buttonStyle(.primary)
                        .disabled(picked.count < 2)
                }
            }
        }
        .padding(Space.xl)
    }

    // MARK: 53

    private var connectView: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header("별과 별을 이어 보세요", "손가락으로 별을 따라 그려요")
            ConnectStage(stars: floated, picked: picked, edges: $edges)
                .frame(height: 320)
            Spacer(minLength: 0)
            actions {
                Button("다시 그리기") { withAnimation(.snappy) { edges = [] } }
                    .buttonStyle(.secondary)
                    .disabled(edges.isEmpty)
                Button("다 이었어요") { go(.name) }
                    .buttonStyle(.primary)
                    .disabled(edges.isEmpty)
            }
        }
        .padding(Space.xl)
    }

    // MARK: 54

    private var nameView: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header("이 성운의 이름은요?", nil)
            drawing.frame(height: 220)
            NameField(text: $name)
            Spacer(minLength: 0)
            actions {
                Button("저장하기") {
                    if let e = editing, model.storyPolished, e.starIDs != newStarIDs {
                        confirmClearStory = true
                    } else {
                        save()
                    }
                }
                .buttonStyle(.primary)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .alert("다듬은 이야기가 지워져요", isPresented: $confirmClearStory) {
                    Button("그대로 두기", role: .cancel) {}
                    Button("바꾸기") { save() }
                } message: {
                    Text("별을 바꾸면 다듬은 성운 이야기는 지워지고, 문장만 엮은 이야기로 돌아가요.")
                }
            }
        }
        .padding(Space.xl)
    }

    // MARK: 55

    private var doneView: some View {
        VStack(spacing: Space.lg) {
            VStack(spacing: Space.lg) {
                Text("성운이 그려졌어요")
                    .textStyle(.h2).foregroundStyle(Color.textPrimary)
                Text("「\(saved?.name ?? name)」\n언제든 다시 이어 볼 수 있어요.")
                    .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            drawing.frame(height: 320)
            Spacer(minLength: 0)
            actions {
                Button("우주 광장에 나누기") {
                    if let s = saved { model.shareDrawnNebula(s.id) }
                    onShare()
                }
                .buttonStyle(.secondary)
                Button("홈으로", action: onHome).buttonStyle(.primary)
            }
        }
        .padding(.horizontal, Space.xl).padding(.top, Space.xl).padding(.bottom, Space.xl)
    }

    // MARK: Shared

    /// What was drawn: the silhouette with its stars, or the picked stars and lines.
    @ViewBuilder private var drawing: some View {
        // After saving, the steps are gone: read the template from the saved nebula.
        let template = saved.map { $0.silhouette.flatMap(NebulaSilhouette.init(rawValue:)) }
            ?? chosenTemplate
        if let template {
            SilhouettePreview(silhouette: template, stars: placed, guests: model.guestCandidates.filter(guests.contains))
        } else {
            StarStage(stars: floated, picked: picked, edges: edges, interactive: false)
        }
    }

    /// The stars the nebula will hold once saved.
    private var newStarIDs: [UUID] { chosenTemplate == nil ? picked : placed.map(\.id) }

    private func save() {
        let template = chosenTemplate
        if var e = editing {
            // 08 「모양 바꾸기」: the same nebula, reshaped.
            e.name = name.trimmingCharacters(in: .whitespaces)
            e.silhouette = template?.rawValue
            e.starIDs = template == nil ? picked : placed.map(\.id)
            e.edges = template == nil ? edges : []
            e.guests = template == nil ? [] : model.guestCandidates.filter(guests.contains).map(\.title)
            e.guestShareIDs = template == nil ? [] : model.guestCandidates.filter(guests.contains).compactMap(\.shareID)
            model.updateDrawnNebula(e)
            onClose()
            return
        }
        let nebula = DrawnNebula(
            name: name.trimmingCharacters(in: .whitespaces),
            silhouette: template?.rawValue,
            starIDs: template == nil ? picked : placed.map(\.id),
            edges: template == nil ? edges : [],
            guests: template == nil ? [] : model.guestCandidates.filter(guests.contains).map(\.title),
            guestShareIDs: template == nil ? [] : model.guestCandidates.filter(guests.contains).compactMap(\.shareID)
        )
        model.saveDrawnNebula(nebula)
        saved = nebula
        withAnimation(.easeInOut(duration: 0.4)) { steps = [.done] }
    }

    private func header(_ title: String, _ sub: String?, h1: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text(title)
                .textStyle(h1 ? .h1 : .h2)
                .foregroundStyle(Color.textPrimary)
            if let sub {
                Text(sub)
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func actions<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: Space.md) { c() }
    }
}

// MARK: - Pieces

/// Figma `Stage` (342×320): my stars on a loose grid; picked ones gold.
struct StarStage: View {
    var stars: [StarItem]
    var picked: [UUID]
    var edges: [[Int]]
    var interactive: Bool
    /// 08-2: every star in its mood color (nothing picked yet).
    var moodColors = false
    var onTap: (StarItem) -> Void = { _ in }

    /// Figma 52 star centers in the 342×320 stage, then two extra places.
    static let places: [CGPoint] = [
        CGPoint(x: 60, y: 50), CGPoint(x: 150, y: 90), CGPoint(x: 260, y: 60),
        CGPoint(x: 90, y: 160), CGPoint(x: 200, y: 170), CGPoint(x: 290, y: 150),
        CGPoint(x: 50, y: 250), CGPoint(x: 140, y: 260), CGPoint(x: 240, y: 240),
        CGPoint(x: 300, y: 280), CGPoint(x: 30, y: 110), CGPoint(x: 210, y: 30),
    ]

    static func point(_ i: Int, in size: CGSize) -> CGPoint {
        let p = places[i % places.count]
        return CGPoint(x: p.x / 342 * size.width, y: p.y / 320 * size.height)
    }

    var body: some View {
        GeometryReader { geo in
            let shown = Array(stars.suffix(Self.places.count))
            let index: (UUID) -> Int? = { id in shown.firstIndex { $0.id == id } }
            ZStack(alignment: .topLeading) {
                ForEach(edges.indices, id: \.self) { e in
                    if let a = picked[safe: edges[e][0]].flatMap(index), let b = picked[safe: edges[e][1]].flatMap(index) {
                        Path { p in
                            p.move(to: Self.point(a, in: geo.size))
                            p.addLine(to: Self.point(b, in: geo.size))
                        }
                        .stroke(Color.starClear, lineWidth: 1.5)
                    }
                }
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, star in
                    let on = picked.contains(star.id)
                    Button { onTap(star) } label: {
                        Circle().fill(on ? Color.starBright : moodColors ? star.mood.color : Color.textTertiary)
                            .frame(width: on ? 14 : 8, height: on ? 14 : 8)
                            .shadow(color: on ? Color.starBright.opacity(0.5) : .clear, radius: 14)
                            .frame(width: 44, height: 44)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    // Not `.disabled`: that would dim the stars.
                    .allowsHitTesting(interactive)
                    .position(Self.point(i, in: geo.size))
                    .accessibilityLabel("\(star.title), \(star.shortDateText)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityHidden(!interactive)
                }
            }
        }
    }
}

/// 53: drag from star to star (or tap one, then another) to draw a line.
private struct ConnectStage: View {
    var stars: [StarItem]
    var picked: [UUID]
    @Binding var edges: [[Int]]

    @State private var anchor: Int?    // index into picked
    @State private var finger: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let shown = Array(stars.suffix(StarStage.places.count))
            // Picked stars that are on the stage: (index in picked, point)
            let nodes: [(Int, CGPoint)] = picked.enumerated().compactMap { k, id in
                shown.firstIndex { $0.id == id }.map { (k, StarStage.point($0, in: geo.size)) }
            }
            let hit: (CGPoint) -> Int? = { p in
                nodes.min { hypot($0.1.x - p.x, $0.1.y - p.y) < hypot($1.1.x - p.x, $1.1.y - p.y) }
                    .flatMap { hypot($0.1.x - p.x, $0.1.y - p.y) < 30 ? $0.0 : nil }
            }
            ZStack(alignment: .topLeading) {
                StarStage(stars: stars, picked: picked, edges: edges, interactive: false)
                if let a = anchor, let from = nodes.first(where: { $0.0 == a })?.1 {
                    if let finger {
                        Path { p in p.move(to: from); p.addLine(to: finger) }
                            .stroke(Color.starClear.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                    Circle().strokeBorder(Color.starClear, lineWidth: 1.5)
                        .frame(width: 26, height: 26).position(from)
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if anchor == nil { anchor = hit(v.startLocation) }
                        guard let a = anchor else { return }
                        finger = v.location
                        if let b = hit(v.location), b != a {
                            connect(a, b)
                            anchor = b
                        }
                    }
                    .onEnded { v in
                        finger = nil
                        // A tap on a star keeps it as the start for the next tap.
                        if hypot(v.translation.width, v.translation.height) < 6, let b = hit(v.location) {
                            anchor = b
                        }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("별 잇기. 고른 별 \(nodes.count)개, 이은 선 \(edges.count)개")
            .accessibilityAction(named: "고른 순서대로 잇기") {
                edges = (0..<max(0, nodes.count - 1)).map { [nodes[$0].0, nodes[$0 + 1].0] }
            }
        }
    }

    private func connect(_ a: Int, _ b: Int) {
        let e = [min(a, b), max(a, b)]
        guard !edges.contains(e) else { return }
        withAnimation(.snappy) { edges.append(e) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Figma 84 `Mini`: the silhouette outline with small dots.
private struct SilhouetteMini: View {
    var silhouette: NebulaSilhouette
    var selected: Bool
    /// 84-1 season pack: gold lines and dots.
    var gold = false

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: 4, dy: 4)
            let color = selected ? Color.hex(0x8555EF) : gold ? Color.starBright.opacity(0.6) : Color.textTertiary
            ZStack(alignment: .topLeading) {
                silhouette.path(in: rect).stroke(color, lineWidth: 1)
                ForEach(Array(silhouette.fitted(in: rect).enumerated()), id: \.offset) { i, p in
                    Circle().fill(selected ? Mood.allCases[i % 4].color : gold ? Color.starBright : Color.textSecondary)
                        .frame(width: i % 2 == 0 ? 4 : 3, height: i % 2 == 0 ? 4 : 3)
                        .position(p)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Figma 84 `Preview`: dashed outline, my stars along it in mood colors,
/// guest stars with gold rings, then dashed empty slots.
struct SilhouettePreview: View {
    var silhouette: NebulaSilhouette
    var stars: [StarItem]
    var guests: [GuestStar]

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: 40, dy: geo.size.height * 0.16)
            let slots = silhouette.slots(in: rect)
            ZStack(alignment: .topLeading) {
                silhouette.path(in: rect)
                    .stroke(Color.textTertiary, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                ForEach(slots.indices, id: \.self) { i in
                    slot(i).position(slots[i])
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(silhouette.name) 모양. 내 별 \(stars.count)개, 손님별 \(guests.count)개, 빈 자리 \(max(0, NebulaSilhouette.slotCount - stars.count - guests.count))개")
    }

    @ViewBuilder private func slot(_ i: Int) -> some View {
        if i < stars.count {
            let size: CGFloat = [5, 7, 9][i % 3]
            Circle().fill(stars[i].mood.color)
                .frame(width: size, height: size)
                .shadow(color: Color.hex(0xA68CFF).opacity(0.55), radius: 3)
        } else if i - stars.count < guests.count {
            ZStack {
                Circle().strokeBorder(Color.starBright, lineWidth: 1.2).frame(width: 15, height: 15)
                Circle().fill(guests[i - stars.count].color).frame(width: 7, height: 7)
            }
        } else {
            Circle().strokeBorder(Color.textTertiary, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: 9, height: 9)
        }
    }
}

/// Figma `Text Field` (focused): 48pt, violet border, cyan glow.
private struct NameField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text("예: 느린 저녁의 성운").foregroundStyle(Color.textTertiary))
            .textInputStyle(.bodyM)
            .foregroundStyle(Color.textPrimary)
            .focused($focused)
            .submitLabel(.done)
            .padding(.horizontal, Space.lg)
            .frame(height: 48)
            .cosmos("name-field", in: RoundedRectangle(cornerRadius: Radius.md), intensity: 0.6)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(focused ? Color.borderFocus : Color.borderDefault, lineWidth: 1))
            .shadow(color: focused ? Color.starClear.opacity(0.4) : .clear, radius: 10)
            .onAppear { focused = true }
            .accessibilityLabel("성운 이름")
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

#Preview {
    let model = AppModel()
    model.fillSampleStars()
    return NebulaDrawingFlow(onClose: {}, onHome: {}, onShare: {}).environment(model)
}
