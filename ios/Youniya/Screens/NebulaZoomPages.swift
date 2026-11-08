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

/// Figma `Star Tooltip`: the selected star, its shape, and a link to it.
private struct StarTooltip: View {
    @Environment(\.skyTheme) private var theme
    var star: StarItem
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("내 별 · \(star.title)")
                        .textStyle(.labelM)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text("모양: \(StarShapeSpec(star: star).label) · 별빛 \(star.starlightValue ?? 0)")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("별 보기 ›")
                    .textStyle(.labelM)
                    .foregroundStyle(theme.accent.strong)
            }
            .padding(Space.lg)
            .cosmos("tooltip", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.starBright, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Pinch, drag and the +/− buttons over a fixed-size drawing.
private struct ZoomPanCanvas<Content: View>: View {
    @Binding var level: CGFloat
    var range: ClosedRange<CGFloat>
    @ViewBuilder var content: (_ level: CGFloat) -> Content

    @State private var pan: CGSize = .zero
    @State private var dragStart: CGSize?
    @State private var pinchStart: CGFloat?

    var body: some View {
        content(level)
            .offset(pan)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in
                        let start = dragStart ?? pan
                        dragStart = start
                        pan = CGSize(width: start.width + v.translation.width, height: start.height + v.translation.height)
                    }
                    .onEnded { _ in dragStart = nil }
                    .simultaneously(with: MagnifyGesture()
                        .onChanged { v in
                            let start = pinchStart ?? level
                            pinchStart = start
                            level = min(range.upperBound, max(range.lowerBound, start * v.magnification))
                        }
                        .onEnded { _ in pinchStart = nil })
            )
            .clipped()
    }
}

/// Figma 69 `Stat`: a gold number over a small label.
private struct NebulaInfoTable: View {
    var rows: [(String, String)]

    var body: some View {
        VStack(spacing: Space.sm) {
            ForEach(rows, id: \.0) { k, v in
                HStack {
                    Text(k).textStyle(.bodyS).foregroundStyle(Color.textTertiary)
                    Spacer()
                    Text(v).textStyle(.labelS).foregroundStyle(Color.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Space.lg)
        .itemCard(seed: "nebula-info", minHeight: 0, flatBorder: true)
    }
}

// MARK: - 70 / 77 My nebula, zoomed

/// 70 / 77 나의 성운 (자세히 보기): the nebula from 08, larger. Zoom (1–3.2×),
/// pan and tap a star for its card (77); a guest shows only where it came from.
struct MyNebulaZoomView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void
    /// 모양 바꾸기 · 성운 이야기 · 자라는 모습
    var onOpen: (String) -> Void

    /// Figma 70 opens at 1× on the whole nebula; 77 is the zoomed-in, picked state.
    @State private var level: CGFloat = DebugScreen.is("77") ? 2.4 : 1
    @State private var selectedID: StarItem.ID?
    @State private var selectedGuest: GuestStar?
    @State private var toast: String?
    /// 71 하늘에 띄우기
    @State private var askFloat = DebugScreen.is("71") || DebugScreen.is("71-1")
    @State private var screenHeight: CGFloat = 844
    @State private var floatSheetHeight: CGFloat = 640
    @State private var isShortScreen = false
    /// 112 skeleton while the nebula loads.
    @State private var loaded = false
    private var isLoading: Bool { model.simulateLoading && !loaded }

    private var nebula: DrawnNebula? { model.latestNebula }
    private var stars: [StarItem] {
        guard let nebula else { return [] }
        let floated = model.stars.filter(\.isFloated)
        return nebula.starIDs.compactMap { id in floated.first { $0.id == id } }
    }
    private var guests: [GuestStar] {
        guard let nebula else { return [] }
        return model.guestCandidates.filter { nebula.guests.contains($0.title) }
    }
    private var selected: StarItem? { stars.first { $0.id == selectedID } }

    /// "등대 · 두 번째 걸음" (직접 그리기: the stage only).
    private var tagText: String {
        let stage = model.stageName ?? model.stageLabel
        return [nebula?.template?.name, stage].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "나의 성운", onBack: onBack)

            ScrollView {
                if isLoading {
                    NebulaDetailSkeleton()
                        .padding(.horizontal, Space.xl)
                        .padding(.top, Space.sm)
                } else if let nebula {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(tagText)
                        .textStyle(.labelS)
                        .foregroundStyle(Color.starBright)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.xs)
                        .background(Color.tintGold, in: .capsule)
                    Text(nebula.name)
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    ZStack(alignment: .topTrailing) {
                        ZoomPanCanvas(level: $level, range: 1...3.2) { level in
                            NebulaArt(nebula: nebula, selectedStar: selectedID, selectedGuest: selectedGuest?.title,
                                      onTapStar: { star in
                                          withAnimation(.snappy) { selectedID = star.id; selectedGuest = nil }
                                      },
                                      onTapGuest: { guest in
                                          withAnimation(.snappy) { selectedGuest = guest; selectedID = nil }
                                      })
                                .frame(width: 342, height: isShortScreen ? 200 : 280)
                                // 77: zoom in around the picked star or guest.
                                .scaleEffect(level, anchor: zoomAnchor(nebula))
                        }
                        ZoomControls(level: $level, range: 1...3.2)
                            .padding(.top, 4)
                        Text(selectedID == nil && selectedGuest == nil ? "두 손가락으로 확대 · 별을 눌러 보기" : "별의 모양은 쓴 글의 결로 정해져요")
                            .textStyle(.caption)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    // iPhone SE: a shorter canvas so the 70 info table shows above the buttons.
                    .frame(height: isShortScreen ? 200 : 280)
                    .background { NebulaGlowBackground().clipShape(.rect(cornerRadius: Radius.lg)) }

                    // 70 Info by default; a star shows its card (77); a guest, only its source.
                    if let selected {
                        StarTooltip(star: selected) { onOpenStar(selected) }
                    } else if let guest = selectedGuest {
                        Text("손님별 · \(guest.source)")
                            .textStyle(.labelM)
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Space.lg)
                            .itemCard(seed: "guest-tooltip", minHeight: 0, flatBorder: true)
                    } else {
                        NebulaInfoTable(rows: infoRows(nebula))
                    }

                    HStack(spacing: Space.sm) {
                        LinkChip(title: "모양 바꾸기") { onOpen("모양 바꾸기") }
                        LinkChip(title: "성운 이야기") { onOpen("성운 이야기") }
                        LinkChip(title: "자라는 모습") { onOpen("자라는 모습") }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.lg)
                .transition(.opacity)
                }
            }
            .scrollIndicators(.hidden)
            // Anything left below the fold fades out above the buttons (iPhone SE).
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: Space.lg)
                }
            }

            VStack(spacing: Space.md) {
                Button(model.skyShare == nil ? "하늘에 띄우기" : "하늘에 떠 있어요") { askFloat = true }
                    .buttonStyle(.primary)
                Button("이미지로 저장") { saveImage() }
                    .buttonStyle(.ghost)
            }
            // Figma 112: both disabled until the nebula arrives.
            .disabled(isLoading || nebula == nil)
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .onGeometryChange(for: Bool.self) { $0.size.height < 700 } action: { isShortScreen = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { screenHeight = $0 }
        .onAppear {
            if DebugScreen.is("77") { selectedID = stars.first?.id }
        }
        .background { StarField() }
        .simulatedLoad($loaded)
        .toast($toast)
        .sheet(isPresented: $askFloat) {
            FloatNebulaSheet(
                maxPickerHeight: screenHeight * 0.85,
                onFloat: {
                    askFloat = false
                    toast = "성운을 하늘에 띄웠어요"
                },
                onLater: { askFloat = false }
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { floatSheetHeight = $0 }
            .presentationDetents([.height(floatSheetHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "float-sheet") }
        }
    }

    private func zoomAnchor(_ nebula: DrawnNebula) -> UnitPoint {
        let index: Int?
        if let selectedID { index = stars.firstIndex { $0.id == selectedID } }
        else if let g = selectedGuest, nebula.template != nil { index = guests.firstIndex(of: g).map { stars.count + $0 } }
        else { index = nil }
        guard let index else { return .center }
        let figure = NebulaFigure(nebula: nebula, stars: stars, guests: nebula.template == nil ? [] : guests)
        return NebulaArt.anchor(dot: index, of: figure, in: CGSize(width: 342, height: isShortScreen ? 200 : 280))
    }

    /// Figma 70 `Info`: 내 별 · 빈 자리 (실루엣만) · 평균 깊이 · 빛깔, for this nebula.
    private func infoRows(_ nebula: DrawnNebula) -> [(String, String)] {
        let deep = stars.compactMap { $0.analysis?.depth }
        // Depth 0…1 shown on the 1–5 stage scale.
        let avg = deep.isEmpty ? 0 : 1 + deep.reduce(0, +) / Double(deep.count) * 4
        let moods = Mood.allCases.filter { m in stars.contains { $0.mood == m } }.map(\.label)
        var rows = [("내 별", "\(stars.count)개 · 손님별 \(guests.count)개")]
        if nebula.template != nil {
            let empty = max(0, NebulaSilhouette.slotCount - stars.count - guests.count)
            rows.append(("빈 자리", "\(empty) · 다음 별을 기다려요"))
        }
        rows.append(("평균 깊이", String(format: "%.1f단계", avg)))
        rows.append(("빛깔", moods.isEmpty ? "-" : moods.joined(separator: " · ")))
        return rows
    }

    /// Saves this nebula (as drawn on 08) to Photos, then T2.
    @MainActor
    private func saveImage() {
        guard let nebula else { return }
        let renderer = ImageRenderer(content:
            NebulaArt(nebula: nebula)
                .environment(model)
                .frame(width: 360, height: 360)
                .background { NebulaGlowBackground() }
        )
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        toast = "이미지로 저장했어요"
    }
}

// MARK: - 83 Nebula story

/// 83 성운 이야기: one core sentence per star, oldest first, left as written.
struct NebulaStoryView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onSaved: () -> Void
    var onNeedCoins: () -> Void

    @State private var toast: ToastCardMessage?

    struct Line: Identifiable {
        var star: StarItem
        var sentence: String
        var id: StarItem.ID { star.id }
    }

    /// Live: the server's story for my newest nebula (its stars' key sentences).
    @State private var serverStory: ServerStory?

    /// Live: the server's entries; mock: each floated star's last sentence.
    private var lines: [Line] {
        if let serverStory {
            return serverStory.entries.compactMap { e in
                guard let id = UUID(uuidString: e.starId), let star = model.stars.first(where: { $0.id == id }) else { return nil }
                return Line(star: star, sentence: e.sentence)
            }
        }
        return model.stars
            .filter(\.isFloated)
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

    /// Mock bridging lines shown at ✦ after "서사 다듬기". TODO: Generated by the API.
    private static let bridges = ["그리고 며칠이 흘러,", "조금 더 지나서,", "그 마음이 이어져,", "어느 저녁에는,"]

    var body: some View {
        let lines = self.lines
        let floated = model.stars.filter(\.isFloated)
        let since = floated.compactMap(\.date).min()
        VStack(spacing: 0) {
            TopAppBar(title: "성운 이야기", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("\(model.nebulaName) 이야기")
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
                        tag(model.storyPolished ? "서사 다듬기" : "문장 엮기", gold: false)
                    }

                    if lines.isEmpty {
                        Text("글이 있는 별을 띄우면 이야기가 엮여요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        storyCard(lines)
                    }

                    Text("✦ 표시는 문장 사이를 잇는 자리예요. 서사 다듬기를 켜면 이 자리에만 이어 주는 말이 더해져요.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.xl)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                Button(model.storyPolished ? "서사를 다듬었어요"
                       : model.isPolishFree ? "서사 다듬기 · 첫 1회 무료" : "서사 다듬기 · 코인 \(AppModel.storyPolishCost)") { polish() }
                    .buttonStyle(.primary)
                    .disabled(model.storyPolished || lines.count < 2)
                // Say why it can't be pressed.
                if !model.storyPolished && lines.count < 2 {
                    Text("문장이 두 개 이상 모이면 서사를 다듬을 수 있어요.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                Button("문장만 엮어 두기 · 무료", action: onSaved)
                    .buttonStyle(.ghost)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .toastCard($toast)
        .task {
            if let story = await model.loadStory() {
                serverStory = story
                model.storyPolished = story.polished
            }
        }
    }

    private func storyCard(_ lines: [Line]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                if i > 0 {
                    Group {
                        if model.storyPolished {
                            Text(bridge(i))
                                .textStyle(.bodyS)
                                .foregroundStyle(Color.starBright)
                        } else {
                            Text("✦")
                                .textStyle(.labelS)
                                .foregroundStyle(Color.starBright)
                                .accessibilityHidden(true)
                        }
                    }
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

    /// Mock: spends coins and turns on the bridging lines.
    /// The line shown at the ✦ before sentence `i`: the server's, or a mock one.
    private func bridge(_ i: Int) -> String {
        if let b = serverStory?.bridges, i - 1 < b.count { return b[i - 1] }
        return Self.bridges[(i - 1) % Self.bridges.count]
    }

    private func polish() {
        if model.useLiveAPI && model.storyNebulaID != nil {
            Task { @MainActor in
                do {
                    if let s = try await model.polishStory() {
                        withAnimation(.easeInOut(duration: 0.4)) { serverStory = s }
                    }
                } catch let e as APIError where e.code == "insufficient_coins" {
                    toast = ToastCardMessage(title: "코인이 조금 부족해요", detail: "코인 충전에서 채울 수 있어요")
                    try? await Task.sleep(for: .seconds(1.2))
                    onNeedCoins()
                } catch {
                    model.handle(error)
                }
            }
            return
        }
        if model.isPolishFree {
            model.usedFreePolish = true
            withAnimation(.easeInOut(duration: 0.4)) { model.storyPolished = true }
        } else if model.spendCoins(AppModel.storyPolishCost, for: "서사 다듬기") {
            withAnimation(.easeInOut(duration: 0.4)) { model.storyPolished = true }
        } else {
            toast = ToastCardMessage(title: "코인이 조금 부족해요", detail: "코인 충전에서 채울 수 있어요")
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                onNeedCoins()
            }
        }
    }

    private static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}

#Preview("77") {
    let model = AppModel()
    model.fillSampleStars()
    return MyNebulaZoomView(onBack: {}, onOpenStar: { _ in }, onOpen: { _ in }).environment(model)
}

#Preview("83") {
    let model = AppModel()
    model.fillSampleStars()
    return NebulaStoryView(onBack: {}, onSaved: {}, onNeedCoins: {}).environment(model)
}
