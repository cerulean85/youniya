import SwiftUI

/// 08 My Nebula (성운 tab): the user's constellation, stats, and links.
struct NebulaView: View {
    @Environment(AppModel.self) private var model
    var onOpen: (_ title: String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("나의 성운")
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                    // 08-1 "{이름} · {실루엣} · {단계}" (직접 그리기: no silhouette);
                    // 08-2 "아직 이름 없는 성운 · {단계}".
                    Text(nameLine)
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.starBright)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Group {
                    if let nebula = model.latestNebula {
                        NebulaArt(nebula: nebula)
                            .overlay(alignment: .topTrailing) {
                                Button("모양 바꾸기") { onOpen("모양 바꾸기") }
                                    .textStyle(.labelS)
                                    .foregroundStyle(Color.textPrimary)
                                    .padding(.horizontal, Space.md)
                                    .padding(.vertical, 6)
                                    .background(Color.bgSurfaceRaised.opacity(0.9), in: .capsule)
                                    .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 1))
                                    .buttonStyle(.plain)
                                    .padding(Space.md)
                            }
                    } else {
                        // 08-2: the floated stars, scattered, before any drawing.
                        StarStage(stars: model.stars.filter(\.isFloated), picked: [], edges: [], interactive: false, moodColors: true)
                            .overlay(alignment: .bottom) {
                                Text("띄운 별 \(model.floatedCount)개가 떠 있어요.\n별을 골라 이으면 나만의 성운이 돼요.")
                                    .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom, Space.lg)
                            }
                    }
                }
                    .frame(height: 330)
                    .frame(maxWidth: .infinity)
                    .background { NebulaGlowBackground() }
                    .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Color.borderDefault, lineWidth: 1))
                    .clipShape(.rect(cornerRadius: Radius.xl))

                HStack(spacing: Space.md) {
                    stat(model.floatedCount, "떠 있는 별")
                    stat(model.deepCount, "깊은 별")
                    stat(model.supernovaCount, "초신성")
                }

                // Tapping the hint opens 86 (the four stages).
                Button { onOpen("성장 단계") } label: {
                    Text(hint)
                        .textStyle(.bodyS)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("성운이 자라는 네 걸음을 봐요")

                HStack(spacing: Space.md) {
                    Button("모두의 은하") { onOpen("모두의 은하") }
                        .buttonStyle(.secondary)
                    if model.latestNebula == nil {
                        Button("성운 그리기") { onOpen("성운 그리기") }
                            .buttonStyle(.primary)
                    } else {
                        Button("자세히 보기") { onOpen("나의 성운 확대") }
                            .buttonStyle(.primary)
                    }
                }

                // Figma: chips wrap onto a second line.
                FlowRow(spacing: Space.sm) {
                    // 08-2: 성운 그리기 is the main button instead.
                    if model.latestNebula != nil { linkChip("성운 그리기") }
                    linkChip("성운 이야기")
                    linkChip("나의 은하수")
                    linkChip("성운 모음")
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .scrollIndicators(.hidden)
    }

    private var nameLine: String {
        let stage = model.stageName ?? model.stageLabel
        guard let n = model.latestNebula else { return "아직 이름 없는 성운 · \(stage)" }
        return [n.name, n.template?.name, stage].compactMap { $0 }.joined(separator: " · ")
    }

    /// What the next stage still needs (the same rules as the server's `next.needs`).
    private var hint: String {
        let calm = "서두르지 않아도 괜찮아요."
        let deep = model.deepCount
        switch model.growthStage {
        case 0:
            let need = max(0, AppModel.firstStageStars - model.stars.count)
            return "첫 걸음까지 별 \(need)개가 더 필요해요. \(calm)"
        case 1 where deep < 6:
            return "다음 단계까지 깊은 별 \(6 - deep)개가 더 필요해요. \(calm)"
        case 2 where deep < AppModel.nextStageDeepStars:
            return "다음 단계까지 깊은 별 \(AppModel.nextStageDeepStars - deep)개가 더 필요해요. \(calm)"
        case 2:
            return "별빛이 한 번 900을 넘으면 다음 단계예요. \(calm)"
        case 3 where deep < 30:
            return "다음 단계까지 깊은 별 \(30 - deep)개가 더 필요해요. \(calm)"
        case 3:
            return "여러 감정의 결이 모이면 온전한 은하수가 돼요. \(calm)"
        default:
            return "나만의 은하수가 완성되었어요."
        }
    }

    /// Figma `Stat`: tappable count card with a "›" label row.
    private func stat(_ value: Int, _ label: String) -> some View {
        Button { onOpen(label) } label: {
            VStack(spacing: Space.xs) {
                Text("\(value)")
                    .textStyle(.h2)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 2) {
                    Text(label)
                        .textStyle(.caption)
                        .foregroundStyle(Color.textSecondary)
                    Image(.iconChevronRight)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Space.md)
            .cosmos("stat-\(label)", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func linkChip(_ title: String) -> some View {
        LinkChip(title: title) { onOpen(title) }
    }
}

/// 08 캔버스 배경 (사용자 시안): soft violet and pink nebula glows with a little
/// star dust behind the nebula.
struct NebulaGlowBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color.bgSurface
                RadialGradient(colors: [Color.hex(0x8B5CF6).opacity(0.38), .clear],
                               center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: max(w, h) * 0.55)
                RadialGradient(colors: [Color.hex(0xEC4899).opacity(0.16), .clear],
                               center: UnitPoint(x: 0.15, y: 0.85), startRadius: 0, endRadius: w * 0.6)
                RadialGradient(colors: [Color.hex(0x33B5D9).opacity(0.1), .clear],
                               center: UnitPoint(x: 0.85, y: 0.2), startRadius: 0, endRadius: w * 0.5)
                ForEach(0..<46, id: \.self) { i in
                    var rng = SeededRandom(seed: "nebula-dust-\(i)")
                    let x = rng.next(in: 0...1), y = rng.next(in: 0...1)
                    let size = rng.next(in: 1...2.2), alpha = rng.next(in: 0.2...0.7)
                    Circle().fill(Color.textPrimary.opacity(alpha))
                        .frame(width: size, height: size)
                        .position(x: x * w, y: y * h)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 08-1 / 70 / 77: the user's own nebula, as in the 사용자 시안. Stars along
/// the silhouette joined by thin gold lines, a gold star at the top, guests
/// with gold rings, and faint places still waiting for stars. Drawn by hand,
/// it shows the picked stars and their lines. 70/77 pass taps and a selection.
struct NebulaArt: View {
    @Environment(AppModel.self) private var model
    var nebula: DrawnNebula
    var selectedStar: StarItem.ID? = nil
    var selectedGuest: String? = nil
    var onTapStar: ((StarItem) -> Void)? = nil
    var onTapGuest: ((GuestStar) -> Void)? = nil

    /// The drawing area inside a canvas of `size` (shared by the drawing and `anchor`).
    static func area(_ size: CGSize) -> CGRect {
        CGRect(origin: .zero, size: size).insetBy(dx: 44, dy: size.height * 0.14)
    }

    /// 77: where a place sits, as a unit point, so zooming keeps it in view.
    static func anchor(slot index: Int, of template: NebulaSilhouette, in size: CGSize) -> UnitPoint {
        let slots = template.slots(in: area(size))
        guard slots.indices.contains(index), size.width > 0, size.height > 0 else { return .center }
        return UnitPoint(x: slots[index].x / size.width, y: slots[index].y / size.height)
    }

    var body: some View {
        let floated = model.stars.filter(\.isFloated)
        if let template = nebula.template {
            let stars = nebula.starIDs.compactMap { id in floated.first { $0.id == id } }
            let guests = model.guestCandidates.filter { nebula.guests.contains($0.title) }
            GeometryReader { geo in
                let rect = Self.area(geo.size)
                let slots = template.slots(in: rect)
                let filled = min(slots.count, stars.count + guests.count)
                let apex = template.fitted(in: rect).min { $0.y < $1.y }
                ZStack(alignment: .topLeading) {
                    // Gold lines through the stars, in order along the outline.
                    if filled > 1 {
                        Path { p in
                            p.move(to: slots[0])
                            for i in 1..<filled { p.addLine(to: slots[i]) }
                        }
                        .stroke(Color.starBright.opacity(0.55), lineWidth: 1)
                    }
                    ForEach(slots.indices, id: \.self) { i in
                        slot(i, stars: stars, guests: guests).position(slots[i])
                    }
                    if let apex {
                        Image(.nebulaTopStar).resizable().frame(width: 22, height: 22)
                            .shadow(color: Color.starBright.opacity(0.7), radius: 6)
                            .position(apex)
                            .allowsHitTesting(false)
                    }
                }
            }
            .accessibilityElement(children: onTapStar == nil ? .ignore : .contain)
            .accessibilityLabel("\(nebula.name), \(template.name) 모양. 내 별 \(stars.count)개, 손님별 \(guests.count)개")
        } else {
            StarStage(stars: floated, picked: nebula.starIDs, edges: nebula.edges, interactive: onTapStar != nil) { star in
                if nebula.starIDs.contains(star.id) { onTapStar?(star) }
            }
        }
    }

    @ViewBuilder private func slot(_ i: Int, stars: [StarItem], guests: [GuestStar]) -> some View {
        if i < stars.count {
            let star = stars[i]
            let size: CGFloat = [8, 10, 9][i % 3]
            ZStack {
                if star.id == selectedStar {
                    // Figma 77 `Target Ring`: dashed, about twice the star, so it
                    // can't be taken for a guest's solid ring.
                    Circle().strokeBorder(Color.starBright, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                        .frame(width: size * 2.4, height: size * 2.4)
                }
                Circle().fill(star.mood.color)
                    .frame(width: size, height: size)
                    .shadow(color: star.mood.color.opacity(0.8), radius: 5)
            }
            .frame(width: 28, height: 28)
            .contentShape(.circle)
            .onTapGesture { onTapStar?(star) }
            .accessibilityElement()
            .accessibilityLabel("내 별 \(star.title)")
            .accessibilityAddTraits(onTapStar == nil ? [] : .isButton)
        } else if i - stars.count < guests.count {
            let guest = guests[i - stars.count]
            ZStack {
                if guest.title == selectedGuest {
                    Circle().strokeBorder(Color.starBright, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                        .frame(width: 26, height: 26)
                }
                Circle().strokeBorder(Color.starBright, lineWidth: 1.2)
                    .frame(width: 16, height: 16)
                Circle().fill(guest.color).frame(width: 8, height: 8)
            }
            .frame(width: 28, height: 28)
            .contentShape(.circle)
            .onTapGesture { onTapGuest?(guest) }
            .accessibilityElement()
            .accessibilityLabel("손님별")
            .accessibilityAddTraits(onTapGuest == nil ? [] : .isButton)
        } else {
            // Places still waiting: faint, so the lit stars lead.
            Circle().strokeBorder(Color.textTertiary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    let model = AppModel()
    model.fillSampleStars()
    return NebulaView(onOpen: { _ in })
        .environment(model)
        .background(Color.bgCanvas)
}
