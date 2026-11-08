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
                        DrawnNebulaCanvas(nebula: nebula)
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
                    .background(Color.bgSurface, in: .rect(cornerRadius: Radius.xl))
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

/// 08-1: the user's own nebula. A silhouette with its stars in mood colors,
/// guests with gold rings and dashed empty places; or, drawn by hand, the
/// picked stars and their lines.
private struct DrawnNebulaCanvas: View {
    @Environment(AppModel.self) private var model
    var nebula: DrawnNebula

    var body: some View {
        let floated = model.stars.filter(\.isFloated)
        if let template = nebula.template {
            let stars = nebula.starIDs.compactMap { id in floated.first { $0.id == id } }
            SilhouettePreview(silhouette: template, stars: stars,
                              guests: model.guestCandidates.filter { nebula.guests.contains($0.title) })
                .padding(.vertical, Space.lg)
        } else {
            StarStage(stars: floated, picked: nebula.starIDs, edges: nebula.edges, interactive: false)
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
