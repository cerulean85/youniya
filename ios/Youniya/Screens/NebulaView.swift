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
                    Button("우주 광장") { onOpen("우주 광장") }
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

/// 08-1 / 70 / 77: the user's own nebula (`NebulaFigureView`): its stars,
/// guests, empty places and lines, nothing decorative. 70/77 pass taps and a
/// selection.
struct NebulaArt: View {
    @Environment(AppModel.self) private var model
    var nebula: DrawnNebula
    var selectedStar: StarItem.ID? = nil
    var selectedGuest: String? = nil
    var compact = false
    var onTapStar: ((StarItem) -> Void)? = nil
    var onTapGuest: ((GuestStar) -> Void)? = nil

    private var stars: [StarItem] {
        let floated = model.stars.filter(\.isFloated)
        return nebula.starIDs.compactMap { id in floated.first { $0.id == id } }
    }
    private var guests: [GuestStar] {
        nebula.template == nil ? [] : model.guestCandidates.filter { nebula.guests.contains($0.title) }
    }

    var figure: NebulaFigure { NebulaFigure(nebula: nebula, stars: stars, guests: guests) }

    /// 77: where a dot sits, as a unit point, so zooming keeps it in view.
    static func anchor(dot index: Int, of figure: NebulaFigure, in size: CGSize) -> UnitPoint {
        let places = figure.places(in: size)
        guard places.indices.contains(index), size.width > 0, size.height > 0 else { return .center }
        return UnitPoint(x: places[index].x / size.width, y: places[index].y / size.height)
    }

    var body: some View {
        let stars = stars, guests = guests
        let selected: Int? = selectedStar.flatMap { id in stars.firstIndex { $0.id == id } }
            ?? selectedGuest.flatMap { t in guests.firstIndex { $0.title == t }.map { stars.count + $0 } }
        NebulaFigureView(figure: NebulaFigure(nebula: nebula, stars: stars, guests: guests),
                         compact: compact, selected: selected,
                         onTap: onTapStar == nil && onTapGuest == nil ? nil : { i in
                             if i < stars.count { onTapStar?(stars[i]) } else { onTapGuest?(guests[i - stars.count]) }
                         })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(nebula.name), \(nebula.template.map { "\($0.name) 모양" } ?? "직접 그린 성운"). 내 별 \(stars.count)개, 손님별 \(guests.count)개")
    }
}

#Preview {
    let model = AppModel()
    model.fillSampleStars()
    return NebulaView(onOpen: { _ in })
        .environment(model)
        .background(Color.bgCanvas)
}
